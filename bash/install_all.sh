#!/bin/bash

DRY_RUN="--dry-run"

#========= PRELIMINARY CHECKS AND SETUP =========

# ref: https://askubuntu.com/a/30157/8698
if ! [ $(id -u) = 0 ]; then
   echo "This script must be run with root privilages." >&2
   echo -e "Run it with:\n" >&2
   echo -e "\t'sudo bash $(basename $BASH_SOURCE) $*'\n" >&2 
   echo -e "You'll need to enter your root password." >&2
   echo -e "Run with:\n" >&2
   echo -e "\t'sudo bash $(basename $BASH_SOURCE) --help'\n" >&2    
   echo -e "for more information." >&2
   exit 1
fi

if [ $SUDO_USER ]; then
    real_user=$SUDO_USER
else
    real_user=$(whoami)
fi

real_user_home=$( getent passwd "$real_user" | cut -d: -f6 )
real_user_shell=$( getent passwd "$real_user" | cut -d: -f7 )

deps_json="deps.json"

#========= COMMNAD-LINE ARGUMENTS =========

# default values:
# install latest versions of the tools, possibly from sources
latest=false

# all implies dev and pico
all=false
# dev implies cpp, gdb, cmake, ninja
dev=true
# individual tools
pico=false
cpp=false
gdb=false
cmake=false
ninja=false
git=false

help=false

# If help requested on unknown optios passed, display help
# check if valid flags passed
# -l, --latest can be combined with any of the other
# other valid flags are:
# -a, --all
# -d, --dev
# -p, --pico
# -c, --cpp
# -g, --gdb
# -t, --git
# -m, --cmake
# -n, --ninja
# -h, --help

# short flags are single letter and can be combined, e.g. -a -c is equivalent to -ac

# go over options, parsing long flags and short, also combined flags:
while [ "$#" -gt 0 ]; do
    case "$1" in
        -l|--latest) latest=true; shift ;;
        -a|--all) all=true; dev=true; pico=true; shift ;;
        -d|--dev) dev=true; shift ;;
        -p|--pico) pico=true; shift ;;
        -c|--cpp) cpp=true; shift ;;
        -g|--gdb) gdb=true; shift ;;
        -t|--git) git=true; shift ;;
        -m|--cmake) cmake=true; shift ;;
        -n|--ninja) ninja=true; shift ;;
        -h|--help) help=true; shift ;;
        *) echo "Unknown option: $1"; help=true; shift ;;
    esac
done




if [ "$help" = true ]; then
    echo "This script installs C & C++ development toolchains for native and RPi Pico enviroments."
    echo "This script cannot modify the existing installations"

    echo "Usage: sudo bash $(basename "$BASH_SOURCE") [options]"
    echo "Options:"
    echo "  -h, --help    Display this help message."
    echo "  -l  --latest  Install the latest versions of the toolchains from ppa instead of the default channels."
    echo "  -a  -all      Install linux dev tools and RPi pico tools."
    echo "  -d  --dev     Install linux dev tools (default)."
    echo "  -c  --cpp     Install C++ tools."
    echo "  -p  --pico    Install RPi pico tools."
    echo "  -g  --gdb     Install gdb."
    echo "  -t  --git     Install git."
    echo "  -m  --cmake   Install cmake."
    echo "  -n  --ninja   Install ninja."
    exit 1
fi

#if neither dev nor pico is selected, default to dev
if [ "$dev" = false ] && [ "$pico" = false ]; then
    dev=true
fi

# if all is selected, dev and pico are implied
if [ "$all" = true ]; then
    dev=true
    pico=true
fi

if [ "$dev" = true ]; then
    cpp=true
    gdb=true
    cmake=true
    ninja=true
    git=true
fi


#=========== Distro checks =================

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

#=========== PACKAGES TO INSTALL USING apt ============

# apt packages to install, this will be populated based on the options passed
apt_purge=""
apt_install="valgrind build-essential python3 python3-pip python3-venv "

# hooks to run before and after installing a package
declare -a hooks_pre_purge
declare -a hooks_post_purge
declare -a hooks_pre_install
declare -a hooks_post_install

declare -a apt_ppa

#========== FUNCTIONS ============

install_cmake() {
    echo -e "[=== Executing install_cmake ===]\n"

    local latest=$1
    if [ "$latest" = true ]; then

        apt_purge+="$(jq -r '.soft.cmake.latest.apt_purge' $deps_json) "
        apt_install+="$(jq -r '.soft.cmake.latest.apt_install' $deps_json) "

        # locally defiend manuall install function
        cmake_setup_repos() {
            # this is mostly a copy of the cmake install script from the official website
            # see: https://apt.kitware.com/kitware-archive.sh
            echo -e "[=== Setting up the Kitware repository for CMake ===]\n"

            : '
            if [ ! -f /usr/share/doc/kitware-archive-keyring/copyright ]
            then
                apt install -y ca-certificates gpg wget
            fi

            # install the signing key manually
            test -f /usr/share/doc/kitware-archive-keyring/copyright || (wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - > /usr/share/keyrings/kitware-archive-keyring.gpg)

            # add repo
            echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ ${CODENAME} main" > /etc/apt/sources.list.d/kitware.list

            # remove the manually added key, so the one from the kitware repo can be installed
            apt update
            test -f /usr/share/doc/kitware-archive-keyring/copyright || rm /usr/share/keyrings/kitware-archive-keyring.gpg

            apt install -y kitware-archive-keyring
            '

        }

        hooks_post_purge+=("cmake_setup_repos")
        
    else
        # concatenate the package name to the list, the package name is the value of the key "cmake" in the deps.json file
        apt_packages+="$(jq -r '.soft.cmake.stable.apt_install' $deps_json) "
    fi
}


install_git() {
    echo -e "[=== Executing install_git ===]\n"

    local latest=$1
    if [ "$latest" = true ]; then
        apt_purge+="$(jq -r '.soft.git.latest.apt_purge' $deps_json) "
        apt_install+="$(jq -r '.soft.git.latest.apt_install' $deps_json) "
        # Git has a standard ppa, so we can add it directly
        apt_ppa+="$(jq -r '.soft.git.latest.apt_ppa' $deps_json)"

    else
        apt_install+="$(jq -r '.soft.git.stable.apt_install' $deps_json) "
    fi
}

install_gdb() {
    echo -e "[=== Executing install_gdb ===]\n"

    local latest=$1
    if [ "$latest" = true ]; then
        apt_purge+="$(jq -r '.soft.gdb.latest.apt_purge' $deps_json) "
        apt_install+="$(jq -r '.soft.gdb.latest.apt_install' $deps_json) "
        gdb_install_from_sources() {
            echo -e "[=== Installing gdb from sources ===]\n"
            : '           
            wget -qO- "$( jq -r '.soft.gdb.latest.url' $deps_json )" | sudo -u "$real_user" tar -xvz
            cd "$( jq -r '.soft.gdb.latest.dir' $deps_json )"
            sudo -u "$real_user" ./configure "$( jq -r '.soft.gdb.latest.configure' $deps_json )"
            sudo -u "$real_user" make -j$(nproc) "$( jq -r '.soft.gdb.latest.make' $deps_json )"
            make install
            cd ..
            sudo -u "$real_user" rm -rf "$( jq -r '.soft.gdb.latest.dir' $deps_json )"
            '
        }

        hooks_post_install+=("gdb_install_from_sources")

    else
        apt_purge+="$(jq -r '.soft.gdb.stable.apt_purge' $deps_json) "
        apt_install+="$(jq -r '.soft.gdb.stable.apt_install' $deps_json) "
    fi
}

install_ninja() {
    echo -e "[=== Executing install_ninja ===]\n"
    local latest=$1
    if [ "$latest" = true ]; then
        apt_install+="$(jq -r '.soft.ninja.latest.apt_install' $deps_json) "
    else
        apt_install+="$(jq -r '.soft.ninja.stable.apt_install' $deps_json) "
    fi
}

install_llvm(){
    echo -e "[=== Executing install_llvm ===]\n"
    local latest=$1

    local LLVM_VERSION=
    if [ "$latest" = true ]; then
        LLVM_VERSION=$(jq -r ".soft.llvm.latest.\"$CODENAME\".version" $deps_json)
    else
        LLVM_VERSION=$(jq -r ".soft.llvm.stable.\"$CODENAME\".version" $deps_json)
    fi

    echo -e "[=== LLVM_VERSION: $LLVM_VERSION ===]\n"	

    # if latest is true or CODENAME is "jammy", add llvm apt repos:
    if [ "$latest" = true ] || [ "$CODENAME" = "jammy" ]; then
        llvm_add_apt_repo(){

            local LLVM_VERSION=$1

            echo -e "[=== Adding LLVM apt repository for llvm-$LLVM_VERSION ===]\n"

            : '
            wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc
            apt-add-repository -y "deb http://apt.llvm.org/$CODENAME/ llvm-toolchain-$CODENAME-$LLVM_VERSION main"
            '
        }

        hooks_post_purge+=("llvm_add_apt_repo $LLVM_VERSION")
    fi
    

    if [ "$latest" = true ] || [ "$CODENAME" = "jammy" ]; then
        packages="$(jq -r ".soft.llvm.latest.\"$CODENAME\".apt_install" $deps_json | sed "s/LLVM_VERSION/$LLVM_VERSION/g") "
        apt_install+="$packages"
    else
        packages="$(jq -r ".soft.llvm.stable.\"$CODENAME\".apt_install" $deps_json | sed "s/LLVM_VERSION/$LLVM_VERSION/g") "
        apt_install+="$packages"
    fi

    llvm_update_alternatives(){
        local LLVM_VERSION=$1
        echo -e "[=== Setting up llvm alternatives for llvm-$LLVM_VERSION ===]\n"
        : '
        update-alternatives --remove-all clang --force --quiet
        update-alternatives --install /usr/bin/clang clang /usr/bin/clang-$LLVM_VERSION 100
        update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-$LLVM_VERSION 100
        update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-$LLVM_VERSION 100
        update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-$LLVM_VERSION 100
        update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-$LLVM_VERSION 100
        '
    }

    hooks_post_install+=("llvm_update_alternatives $LLVM_VERSION")

}

install_gcc() {
    echo -e "[=== Executing install_gcc ===]\n"
    local latest=$1
    if [ "$latest" = true ]; then
        apt_ppa+="$(jq -r ".soft.gcc.latest.\"$CODENAME\".apt_ppa" $deps_json)"
        apt_install+="$(jq -r ".soft.gcc.latest.\"$CODENAME\".apt_install" $deps_json) "
    else
        apt_ppa+="$(jq -r ".soft.gcc.stable.\"$CODENAME\".apt_ppa" $deps_json)"
        apt_install+="$(jq -r ".soft.gcc.stable.\"$CODENAME\".apt_install" $deps_json) "
    fi

    local GCC_VERSION=
    if [ "$latest" = true ]; then
        GCC_VERSION=$(jq -r ".soft.gcc.latest.\"$CODENAME\".version" $deps_json)
    else
        GCC_VERSION=$(jq -r ".soft.gcc.stable.\"$CODENAME\".version" $deps_json)
    fi

    gcc_update_alternatives(){

        local GCC_VERSION=$1

        echo -e "[=== Setting up gcc alternatives for gcc-$GCC_VERSION===]\n"
        : '
        update-alternatives --remove-all gcc --force --quiet
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-$GCC_VERSION 100
        update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-$GCC_VERSION 100
        '
    }

    hooks_post_install+=("gcc_update_alternatives $GCC_VERSION")
}

echo "This script installs the 'clang' and 'gcc' toolchains, and some basic dev tools."
echo "It also configures the wsl to support filesystem metadata."

while true; do
    read -p "Do you want to continue? (y/n) " yn
    case $yn in
        [Yy]* ) echo -e "[=== Checking requirements ===]\n"; break;;
        [Nn]* ) echo "Bye!"; exit;;
        * ) echo "Please answer [y]es or [n]o.";;
    esac
done

echo -e "[=== Upgrading the system. ===]\n"

# apt -qq -y update
# apt upgrade --yes --quiet $DRY_RUN
# apt install -y software-properties-common jq $DRY_RUN

echo -e "[=== Installing basic tools and build essentials. ===]\n"

# install_cmake $latest
# install_git $latest
# install_gdb $latest
install_llvm $latest
install_gcc $latest

echo -e "[=== Pre-purge hooks ===]\n"
for hook in "${hooks_pre_purge[@]}"; do
    eval $hook
done

echo -e "[=== Purging packages: $apt_purge ===]\n"

# repalce all ' null ' values with a single space
apt_purge=$(echo $apt_purge | sed 's/ null / /g')

echo -e "[=== Purging packages: $apt_purge ===]\n"
apt purge -y $apt_purge $DRY_RUN

echo -e "[=== Post-purge hooks ===]\n"
for hook in "${hooks_post_purge[@]}"; do
    eval $hook
done

echo -e "[=== Adding PPAs ===]\n"
for ppa in $apt_ppa; do
    echo "Adding PPA: $ppa"
    add-apt-repository -y $ppa $DRY_RUN
done

echo -e "[=== Upgrading packages ===]\n"
# apt update
# apt upgrade -y $DRY_RUN

echo -e "[=== Pre-install hooks ===]\n"
for hook in "${hooks_pre_install[@]}"; do
    eval $hook
done

echo -e "[=== Installing packages ===]\n"
# apt install -y $apt_install $DRY_RUN

echo -e "[=== Post-install hooks ===]\n"
for hook in "${hooks_post_install[@]}"; do
    eval $hook
done

echo -e "[=== All done. Enjoy! ===]\n"
