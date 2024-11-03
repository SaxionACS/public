#!/bin/bash

DRY_RUN=""

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

if [ ! -f $deps_json ]; then
    echo "Dependencies file not found. Downloading."

    # Download the deps.json file from the repo, exit if download fails
    wget -q wget -q https://raw.githubusercontent.com/SaxionACS/public/main/bash/deps.json
    if [ $? -ne 0 ]; then
        echo "Failed to download the dependencies file. Exiting."
        exit 1
    fi
fi

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

# The menu function

show_menu() {
    whiptail --title "Installation Menu" --checklist \
    "Choose options to install:" 15 72 6 \
    "latest" "Install the latest versions (from sources or ppa's)" OFF \
    "all" "Install all available tools" ON \
    "pico" "Install Pico development tools" OFF \
    "cpp" "Install C&C++ compiers and tools" OFF \
    "gdb" "Install GDB" OFF \
    "cmake" "Install CMake" OFF \
    "ninja" "Install Ninja build" OFF \
    "git" "Install Git" OFF 2>results.txt

    # Read the selected options into an array
    choices=$(<results.txt)
    rm results.txt

    # Set the variables based on the choices
    latest=false
    all=false
    dev=false
    pico=false
    cpp=false
    gdb=false
    cmake=false
    ninja=false
    git=false

    for choice in $choices; do
        case $choice in
            "\"latest\"") latest=true ;;
            "\"all\"") all=true; dev=true; pico=true ;;
            "\"dev\"") dev=true ;;
            "\"pico\"") pico=true ;;
            "\"cpp\"") cpp=true ;;
            "\"gdb\"") gdb=true ;;
            "\"cmake\"") cmake=true ;;
            "\"ninja\"") ninja=true ;;
            "\"git\"") git=true ;;
        esac
    done
}

# if no arguments are passed, show the menu
if [ "$#" -eq 0 ]; then
    show_menu
else
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
fi


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

if [ "$pico" = true ]; then
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
apt_install="valgrind build-essential make python3 python3-pip python3-venv "

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
        apt_ppa+=("$(jq -r '.soft.git.latest.apt_ppa' $deps_json)")

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
                     
            wget -qO- "$( jq -r '.soft.gdb.latest.url' $deps_json )" | sudo -u "$real_user" tar -xvz
            local configure_opts=$( jq -r '.soft.gdb.latest.configure' $deps_json )
            local make_opts=$( jq -r '.soft.gdb.latest.make' $deps_json )
            cd "$( jq -r '.soft.gdb.latest.dir' $deps_json )"
            sudo -u "$real_user" ./configure "$configure_opts"
            sudo -u "$real_user" make -j$(nproc) "$make_opts"
            make install
            cd ..
            sudo -u "$real_user" rm -rf "$( jq -r '.soft.gdb.latest.dir' $deps_json )"
            
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

            
            wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc
            apt-add-repository -y "deb http://apt.llvm.org/$CODENAME/ llvm-toolchain-$CODENAME-$LLVM_VERSION main"
            
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
        
        update-alternatives --remove-all clang --force --quiet
        update-alternatives --install /usr/bin/clang clang /usr/bin/clang-$LLVM_VERSION 100
        update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-$LLVM_VERSION 100
        update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-$LLVM_VERSION 100
        update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-$LLVM_VERSION 100
        update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-$LLVM_VERSION 100
        
    }

    hooks_post_install+=("llvm_update_alternatives $LLVM_VERSION")

}

install_gcc() {
    echo -e "[=== Executing install_gcc ===]\n"
    local latest=$1
    if [ "$latest" = true ]; then
        apt_ppa+=("$(jq -r ".soft.gcc.latest.\"$CODENAME\".apt_ppa" $deps_json)")
        apt_install+="$(jq -r ".soft.gcc.latest.\"$CODENAME\".apt_install" $deps_json) "
    else
        apt_ppa+=("$(jq -r ".soft.gcc.stable.\"$CODENAME\".apt_ppa" $deps_json)")
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

        echo -e "[=== Setting up gcc alternatives for gcc-$GCC_VERSION ===]\n"
        
        update-alternatives --remove-all gcc --force --quiet
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-$GCC_VERSION 100
        update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-$GCC_VERSION 100
        
    }

    hooks_post_install+=("gcc_update_alternatives $GCC_VERSION")
}



install_pico_tools() {
    local latest=$1


    local  pico_dir="$real_user_home/pico"

    pico_make_dirs() {
        echo -e "[=== Making directories for RPi Pico tools ===]\n"

        local pico_dir=$1
        : '
        sudo -u "$real_user" mkdir -p $pico_dir
        '
    }

    hooks_pre_install+=("pico_make_dirs $pico_dir")

    if [ "$latest" = true ]; then
        apt_install+="$(jq -r '.soft.pico.latest.apt_install' $deps_json) "

        pico_install_toolchain() {
            echo -e "[=== Installing RPi Pico toolchain ===]\n"

            local pico_dir=$1
            local current_dir=$(pwd)
            
            sudo -u "$real_user" mkdir -p $pico_dir/gcc-arm-none-eabi

            wget -qO - "$( jq -r '.soft.pico.latest.url' $deps_json )" | sudo -u "$real_user" tar --exclude='*arm-none-eabi-gdb*' --exclude='share' --strip-components=1 -xJC $pico_dir/gcc-arm-none-eabi
           
            echo "export PICO_TOOLCHAIN_PATH=$pico_dir/gcc-arm-none-eabi" >> $real_user_home/.profile	
            echo "export ARM_NONE_EABI_TOOLCHAIN=$pico_dir/gcc-arm-none-eabi" >> $real_user_home/.profile
            echo "export PATH=\$PATH:\$ARM_NONE_EABI_TOOLCHAIN/bin" >> $real_user_home/.profile
           
            export "ARM_NONE_EABI_TOOLCHAIN=$pico_dir/gcc-arm-none-eabi"
            export "PATH=$PATH:$ARM_NONE_EABI_TOOLCHAIN/bin"
            export "PICO_TOOLCHAIN_PATH=$ARM_NONE_EABI_TOOLCHAIN"
            cd $current_dir
        }

        hooks_post_install+=("pico_install_toolchain $pico_dir")

    else
        apt_install+="$(jq -r '.soft.pico.stable.apt_install' $deps_json) "

    fi

    
    pico_install_sdk(){

        local pico_dir=$1
        local current_dir=$(pwd)

        base_url=$(jq -r '.soft.pico.sdk.base_url' $deps_json)
        repos=$(jq -r '.soft.pico.sdk.repos.[]' $deps_json)


        for repo in $repos; do
            
            dest="$pico_dir/pico-$repo"

            if [ -d $dest ]; then
                echo "$dest already exists. Skipping $repo."
            else
                url=$( sed "s/REPO/$repo/g" <<< $base_url )
                echo "Cloning $url"
                
                cd $pico_dir
                sudo -u "$real_user" git clone -b master $url

                # Any submodules
                cd $dest
                sudo -u "$real_user" git submodule update --init
                cd $pico_dir

                # Define PICO_SDK_PATH in ~/.bashrc
                varname="PICO_${repo^^}_PATH"
                echo "export $varname=$dest" >> $real_user_home/.profile

                export "${varname}=$dest"
                
            fi
        done

        cd $current_dir

    }

    hooks_post_install+=("pico_install_sdk $pico_dir")

    pico_install_debug_tools(){
        echo -e "[=== Installing RPi Pico debug tools ===]\n"

        local pico_dir=$1

        local current_dir=$(pwd)
        base_url=$(jq -r '.soft.pico.probe.base_url' $deps_json)

        for repo in $( jq -r '.soft.pico.probe.repos.[]' $deps_json ); do
            
            dest="$pico_dir/$repo"
            
            if [ -d $dest ]; then
                echo "$dest already exists. Skipping $repo."
            else
                url=$( sed "s/REPO/$repo/g" <<< $base_url )
                echo "Cloning $url"
                
                cd $pico_dir
                sudo -u "$real_user" git clone -b master $url

                # Submodules + build
                cd $dest
                sudo -u "$real_user" git submodule update --init
                sudo -u "$real_user" mkdir -p build
                cd build
                sudo -E -u "$real_user" cmake ..
                sudo -E -u "$real_user" make -j$(nproc)
                if [ $repo == "picotool" ]; then
                    cp picotool /usr/local/bin
                fi
                
            fi
        done

        cd $current_dir
    }

    hooks_post_install+=("pico_install_debug_tools $pico_dir")

}


echo -e "This script will install the following tools:\n\n"

test "$pico" = true && echo "* RPi Pico development tools and SDK (installed to $real_user_home/pico)"
test "$cpp" = true && echo "* C & C++ compilers and tools (including clang and gcc)"
test "$gdb" = true && echo "* GDB debugger"
test "$cmake" = true && echo "* CMake build configuration system"
test "$ninja" = true && echo "* Ninja build system"
test "$git" = true && echo "* Git version control system"
echo "* Generic tools like make, valgrind, python3, and python3-venv."
#echo -e "\nIt also configures the wsl to support filesystem metadata.\n"

test "$latest"  = true && echo -e "\nThe latest versions of the tools will be installed, either form sources or using PPA's.\n"

while true; do
    read -p "Do you want to continue? (y/n) " yn
    case $yn in
        [Yy]* ) echo -e "[=== Checking requirements ===]\n"; break;;
        [Nn]* ) echo "Bye!"; exit;;
        * ) echo "Please answer [y]es or [n]o.";;
    esac
done

. "$real_user_home/.profile"

echo -e "[=== Upgrading the system. ===]\n"

apt -qq -y update
apt upgrade --yes --quiet $DRY_RUN
apt install -y software-properties-common jq $DRY_RUN

echo -e "[=== Setting up installs. ===]\n"

if [ "$cmake" = true ]; then
    install_cmake $latest
fi

if [ "$git" = true ]; then
    install_git $latest
fi

if [ "$ninja" = true ]; then
    install_ninja $latest
fi

if [ "$gdb" = true ]; then
    install_gdb $latest
fi

if [ "$dev" = true ]; then
    install_llvm $latest
    install_gcc $latest
fi

if [ "$pico" = true ]; then
    install_pico_tools $latest
fi

echo -e "[=== Pre-purge hooks ===]\n"
for hook in "${hooks_pre_purge[@]}"; do
    eval $hook
done

echo -e "[=== Purging packages: $apt_purge ===]\n"

# repalce all ' null ' values with a single space
apt_purge=$(echo $apt_purge | sed 's/\<null\>//g')

echo -e "[=== Purging packages: $apt_purge ===]\n"
apt purge -y $apt_purge $DRY_RUN

echo -e "[=== Post-purge hooks ===]\n"
for hook in "${hooks_post_purge[@]}"; do
    eval $hook
done

echo -e "[=== Adding PPAs ===]\n"
for ppa in "${apt_ppa[@]}"; do
    echo "Adding PPA: $ppa"
    add-apt-repository -y $ppa $DRY_RUN
done

echo -e "[=== Upgrading packages ===]\n"
apt update
apt upgrade -y $DRY_RUN

echo -e "[=== Pre-install hooks ===]\n"
for hook in "${hooks_pre_install[@]}"; do
    eval $hook
done

echo -e "[=== Installing packages ===]\n"
apt install -y $apt_install $DRY_RUN

echo -e "[=== Post-install hooks ===]\n"
for hook in "${hooks_post_install[@]}"; do
    eval $hook
done

echo -e "[=== All done. Enjoy! ===]\n"
