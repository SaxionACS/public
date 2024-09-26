#!/bin/bash


if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "This script installs LLVM (candidate release) on Ubuntu"
    echo "Usage: bash install_llvm.sh"
    exit 0
fi

echo "This scipt will install LLVM (candidate release) on your system, do you want to continue? (y/n)"
read -r response

if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    exit 0
fi

# Check if the script is running as root

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

LLVM_VERSION=19

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