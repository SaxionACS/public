#!/bin/bash

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

# real_user_home=$(sudo -u "$real_user" sh -c 'echo $HOME')
# real_user_home=$(bash -c "cd ~$(printf %q "$real_user") && pwd")
real_user_home=$( getent passwd "$real_user" | cut -d: -f6 )

#========= COMMNAD-LINE ARGUMENTS =========

#default values:
latest=false
dev=false
pico=false
help=false
gdb_latest=false

# If help requested on unknown optios passed, display help
# check if valid flags passed
# valid flags are -h, --help, -a, --all, -d, --dev, -p, --pico. -l, --latest can be combined with any of the other
# check if flags and their combinations are valid:

while [[ $# -gt 0 ]]
    do
    key="$1"
    case $key in
        -l|--latest)
        latest=true
        shift
        ;;
        -a|--all)
        dev=true
        pico=true
        shift
        ;;
        -d|--dev)
        dev=true
        shift
        ;;
        -p|--pico)
        pico=true
        shift
        ;;
        -g|--gdb)
        gdb_latest=true
        shift
        ;;
        -h|--help)
        help=true
        shift
        ;;
        *)
        echo "Invalid option: $1"
        echo "Use -h or --help for help."
        exit 1
        ;;
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
    echo "  -p  --pico    Install RPi pico tools."
    echo "  -g  --gdb     Install gdb from sources."
    exit 1
fi

#if neither dev nor pico is selected, default to dev
if [ "$dev" = false ] && [ "$pico" = false ]; then
    dev=true
fi

#========== FUNCTIONS ============

# toolchains installation:
dev_stable=(gcc-12 g++-12 clang-15 lldb-15 lld-15 clang-tools-15 clang-format-15 clangd-15 clang-tidy-15 libc++-15-dev libc++abi-15-dev)
dev_latest=(gcc-13 g++-13 clang-18 lldb-18 lld-18 clang-tools-18 clang-format-18 clangd-18 clang-tidy-18 libc++-18-dev libc++abi-18-dev)

# install the the toolchains
install_dev_tools() {
    echo -e "[=== Installing toolchains. ===]\n"
    #if argument passed to this function is true, install the latest versions of the toolchains
    if [ "$1" = true ]; then
        apt install --yes software-properties-common
        add-apt-repository ppa:ubuntu-toolchain-r/test --yes

        wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc
        apt-add-repository "deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy-18 main" --yes
        apt -qq -y update

        xargs apt install --yes < <(echo "${dev_latest[@]}")
    else
        xargs apt install --yes < <(echo "${dev_stable[@]}")
    fi
}

# make symbolic links to the compilers
update_links(){
    echo -e "[=== Creating symbollic links to compilers. ===]\n"

    update-alternatives --remove-all gcc --force --quiet
    update-alternatives --remove-all clang --force --quiet

    if [ "$1" = true ]; then
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 90 --slave /usr/bin/g++ g++ /usr/bin/g++-13
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 80 --slave /usr/bin/g++ g++ /usr/bin/g++-11
        update-alternatives --install /usr/bin/clang clang /usr/bin/clang-18 90 --slave /usr/bin/clang++ clang++ /usr/bin/clang++-18
    else
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 90 --slave /usr/bin/g++ g++ /usr/bin/g++-12
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 80 --slave /usr/bin/g++ g++ /usr/bin/g++-11
        update-alternatives --install /usr/bin/clang clang /usr/bin/clang-15 90 --slave /usr/bin/clang++ clang++ /usr/bin/clang++-15
    fi
}

#install vs code plugins (including arm and cortex debug)
install_vscode_plugins() {
    echo -e "[=== Installing VS Code remote server. ===]\n"
    wget -O- https://aka.ms/install-vscode-server/setup.sh | sh

    echo -e "[=== Installing VS Code plugins. ===]\n"
    sudo -u "$real_user" code --install-extension ms-vscode.cpptools
    sudo -u "$real_user" code --install-extension ms-vscode.cmake-tools
    sudo -u "$real_user" code --install-extension ms-vscode.makefile-tools
    sudo -u "$real_user" code --install-extension twxs.cmake
    sudo -u "$real_user" code --install-extension streetsidesoftware.code-spell-checker
    sudo -u "$real_user" code --install-extension ms-python.vscode-pylance
    sudo -u "$real_user" code --install-extension ms-python.python
    sudo -u "$real_user" code --install-extension ms-python.debugpy
    sudo -u "$real_user" code --install-extension yzhang.markdown-all-in-one
    sudo -u "$real_user" code --install-extension marus25.cortex-debug
}


# if argument passed to this function is true, install gdb from sources
# else install gdb-multiarch
install_gdb() {
    if [ "$1" = true ]; then
        echo -e "[=== Installing gdb from sources. ===]\n"
        apt install --yes build-essential texinfo libmpfr-dev bison flex
        apt purge gdb --yes
        apt purge gdb-multiarch --yes
        wget -qO- https://ftp.gnu.org/gnu/gdb/gdb-14.2.tar.gz | sudo -u "$real_user" tar -xvz
        cd gdb-14.2
        sudo -u "$real_user" ./configure --target=all
        sudo -u "$real_user" make -j$(nproc) CXXFLAGS="-static-libstdc++"
        sudo -u "$real_user" make install
        cd ..
        sudo -u "$real_user" rm -rf gdb-14.2
    else
        echo -e "[=== Installing gdb. ===]\n"
        apt install --yes gdb-multiarch
    fi
}

# if argument passed to this function is true, install the latest version of cmake using pip
# else install cmake from apt
install_cmake() {
    if [ "$1" = true ]; then
        echo -e "[=== Installing cmake from pip. ===]\n"
        apt purge cmake -y
        apt install python3-pip -y
        sudo -u "$real_user" pip3 install cmake
    else
        echo -e "[=== Installing cmake from apt. ===]\n"
        apt install --yes cmake
    fi
}

install_pico() {
    echo -e "[=== Installing RPi pico tools. ===]\n"

    pico_dir="$real_user_home/pico"
    sudo -u "$real_user" mkdir -p $pico_dir

    apt install --yes automake autoconf build-essential texinfo libtool libftdi-dev libusb-1.0-0-dev pkg-config

    if [ "$1" = true ]; then
        echo -e "[=== Installing the latest version of RPi pico tools. ===]\n"
        sudo -u "$real_user" mkdir -p $pico_dir/gcc-arm-none-eabi
        wget -qO - "https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-$(uname -m)-arm-none-eabi.tar.xz" | sudo -u "$real_user" tar --exclude='*arm-none-eabi-gdb*' --exclude='share' --strip-components=1 -xJC $pico_dir/gcc-arm-none-eabi
        # add the toolchain to the path in bashrc
        echo "export ARM_NONE_EABI_TOOLCHAIN=$pico_dir/gcc-arm-none-eabi" >> $real_user_home/.bashrc
        echo "export PATH=\$PATH:\$ARM_NONE_EABI_TOOLCHAIN/bin" >> $real_user_home/.bashrc
        export "ARM_NONE_EABI_TOOLCHAIN=$pico_dir/gcc-arm-none-eabi"
        export "PATH=$PATH:$ARM_NONE_EABI_TOOLCHAIN/bin"
        export "PICO_TOOLCHAIN_PATH=$ARM_NONE_EABI_TOOLCHAIN"
    else
        echo -e "[=== Installing the stable version of RPi pico tools. ===]\n"
        apt install --yes gcc-arm-none-eabi libnewlib-arm-none-eabi
    fi

    echo -e "[=== Installing the pico-sdk. ===]\n"

    #remember the current directory
    current_dir=$(pwd)
    

    for repo in sdk examples extras playground
    do
        dest="$pico_dir/pico-$repo"

        if [ -d $dest ]; then
            echo "$dest already exists. Skipping $repo."
        else
            url="https://github.com/raspberrypi/pico-${repo}.git"
            cd 
            echo "Cloning $url"
            cd $pico_dir
            sudo -u "$real_user" git clone -b master $url

            # Any submodules
            cd $dest
            sudo -u "$real_user" git submodule update --init
            cd ..

            # Define PICO_SDK_PATH in ~/.bashrc
            varname="PICO_${repo^^}_PATH"
            echo "export $varname=$dest" >> $real_user_home/.bashrc
            export "${varname}=$dest"
        fi
    done


    # install picotool and picoprobe
    echo -e "[=== Installing picotool and picoprobe. ===]\n"
    for repo in picoprobe picotool
    do
        dest="$pico_dir/$repo"

        if [ -d $dest ]; then
            echo "$dest already exists. Skipping $repo."
        else
            url="https://github.com/raspberrypi/$repo.git"
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

configure_wsl(){
    echo -e "[=== Configuring WSL. ===]\n"
    touch /etc/wsl.conf

    #enable automount with metadata and systemd
    echo -e "[automount]\nenabled = true\nnoptions = \"metadata\"" >> /etc/wsl.conf
    echo -e "[boot]\nsystemd = true" >> /etc/wsl.conf
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

apt -qq -y update
apt upgrade --yes --quiet


echo -e "[=== Installing basic tools and build essentials. ===]\n"

apt install --yes  git valgrind build-essential python3 python3-pip
install_gdb $gdb_latest
install_cmake $latest

if [ "$dev" = true ]; then
    install_dev_tools $latest
    update_links $latest
fi


#install pico-sdk and tools

if [ "$pico" = true ]; then
    install_pico $latest
fi


#if running under wsl, configure it
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
    configure_wsl
fi

# check if vs code is accessible from the wsl and install the remote server
if command -v code &> /dev/null; then
    install_vscode_plugins
fi

echo -e "[=== All done. Enjoy! ===]\n"
