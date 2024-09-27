#!/bin/bash


if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "This script installs LLVM (stable or candidate release) on Ubuntu"
    echo "Usage: bash install_llvm.sh [stable|candidate]"
    echo "If no argument is provided, the script will install the stable release"
    exit 0
fi

# Check if stable or candidate is provided, do it case-insensitively
if [[ "${1,,}" == "candidate" ]]; then
    echo "Installing candidate release"
    LLVM_VERSION=19
elif [[ "${1,,}" == "stable" ]]; then
    echo "Installing stable release"
    LLVM_VERSION=18
elif [[ -n "$1" ]]; then
    echo "Invalid argument, only stable and candidate are supported"
    exit 1
else
    echo "No argument provided, installing stable release"
    LLVM_VERSION=18
fi


echo "This scipt will install LLVM (version $LLVM_VERSION) on your system, do you want to continue? (y/n)"
read -r response

if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    exit 0
fi

# Check if the script is running as root

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# a map of supported versions and codenames
declare -A supported_versions
supported_versions["22.04"]="jammy"
supported_versions["24.04"]="noble"


# Check if the distro is Ubuntu using lsb_release
DISTRO=$(lsb_release -is)

if [[ "$DISTRO" != "Ubuntu" ]]; then
    echo "This script is only for Ubuntu"
    exit 1
fi

VERSION=$(lsb_release -rs)
# Check if the version is supported
if [[ -z "${supported_versions[$VERSION]}" ]]; then
    echo "This version of Ubuntu is not supported"
    exit 1
fi

CODENAME="${supported_versions[$(lsb_release -rs)]}"

echo "Detected $DISTRO $VERSION ($CODENAME)"
echo "Installing LLVM $LLVM_VERSION"

# Add signing key of the repository
if [[ ! -f /etc/apt/trusted.gpg.d/apt.llvm.org.asc ]]; then
    echo "Adding signing key"
    wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc
fi

if [[ -z "$(apt-key list 2> /dev/null | grep -i llvm)" ]]; then
    echo "Deleting the key in old format"
    apt-key del AF4F7421
fi

# Add the repository

# check if the repository is already added
echo "Adding repository"
apt-add-repository -y "deb http://apt.llvm.org/$CODENAME/ llvm-toolchain-$CODENAME-$LLVM_VERSION main"

apt update
apt upgrade -y

packages=(clang-$LLVM_VERSION clang-tools-$LLVM_VERSION libclang-common-$LLVM_VERSION-dev libclang-$LLVM_VERSION-dev libclang1-$LLVM_VERSION clang-format-$LLVM_VERSION python3-clang-$LLVM_VERSION clangd-$LLVM_VERSION clang-tidy-$LLVM_VERSION llvm-$LLVM_VERSION libc++-$LLVM_VERSION-dev libc++abi-$LLVM_VERSION-dev)

xargs apt install --yes <<< "${packages[*]}"

#========= Include what you use part =============

supported_llvms=("18")

if [[ ! "${supported_llvms[*]}" =~ ${LLVM_VERSION} ]]; then
    echo "include-what-you-use is not supported for LLVM $LLVM_VERSION"
    exit 0
fi

echo "Do you want to install include-what-you-use? (y/n)"

read -r response

if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Bye."
    exit 0
fi


mkdir temp &>/dev/null

echo "temp directory created"

cd temp || { echo "Directory 'temp' couldn't be created."; exit 1; }

apt install -y llvm-$LLVM_VERSION-dev libclang-$LLVM_VERSION-dev clang-$LLVM_VERSION
git clone https://github.com/include-what-you-use/include-what-you-use.git

cd include-what-you-use || { echo "Directory \`include-what-you-use\` not found"; exit 1; }

git checkout clang_$LLVM_VERSION

mkdir build &>/dev/null

echo "build directory created"

cd build || { echo "Directory \`build\` couldn't be created."; exit 1; }

cmake -G "Unix Makefiles" -DCMAKE_PREFIX_PATH=/usr/lib/llvm-$LLVM_VERSION ..
make -j"$(nproc)"
make install
cd ../..
rm -rf temp/include-what-you-use

#final things, where does iwyu expect to find clang? and where is it actually?

iwyu_expected=$(include-what-you-use -print-resource-dir 2>/dev/null | head -n1 | tr -d '\n')
clang_actual=$(clang-"$LLVM_VERSION" --print-resource-dir 2>/dev/null)

iwyu_expected_base="${iwyu_expected%%/clang*}"
clang_actual_base="${clang_actual%%/clang*}"

if [[ -z "$iwyu_expected" || -z "$clang_actual" ]]; then
    echo "Couldn't find iwyu or clang to create a symlink"
    exit 1
fi

mkdir -p "$iwyu_expected_base"
ln -s "${clang_actual_base}/clang" "${iwyu_expected_base}/clang"