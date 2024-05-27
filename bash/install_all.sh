#!/bin/bash

# Functions:

# toolchains installation:

dev_stable=(gcc-12 g++-12 clang-15 lldb-15 lld-15 clang-tools-15 clang-format-15 clangd-15 clang-tidy-15 libc++-15-dev libc++abi-15-dev)
dev_latest=(gcc-13 g++-13 clang-18 lldb-18 lld-18 clang-tools-18 clang-format-18 clangd-18 clang-tidy-18 libc++-18-dev libc++abi-18-dev)

# install the the toolchains
install_dev_tools() {
    echo -e "[=== Installing toolchains. ===]\n"
    #if argument passed to this function is true, install the latest versions of the toolchains
    if [ "$1" = true ]; then
        apt install --yes software-properties-common
        add-apt-repository ppa:ubuntu-toolchain-r/test
        apt update

        wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc
        apt-add-repository "deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy-18 main"
        apt update

        xargs apt install --yes < <(echo "${dev_latest[@]}")
    else
        xargs apt install --yes < <(echo "${dev_stable[@]}")
    fi
}

# make symbolic links to the compilers
update_links(){
    echo -e "[=== Creating symbollic links to compilers. ===]\n"

    update-alternatives --remove-all --force --quiet gcc
    update-alternatives --remove-all --force --quiet clang

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
    echo -e "[=== Installing VS Code plugins. ===]\n"
    code --install-extension ms-vscode.cpptools
    code --install-extension ms-vscode.cmake-tools
    code --install-extension ms-vscode.makefile-tools
    code --install-extension twxs.cmake
    code --install-extension streetsidesoftware.code-spell-checker
    code --install-extension ms-python.vscode-pylance
    code --install-extension ms-python.python
    code --install-extension ms-python.debugpy
    code --install-extension yzhang.markdown-all-in-one
    code --install-extension marus25.cortex-debug
}


# if argument passed to this function is true, install gdb from sources
# else install gdb-multiarch
install_gdb() {
    echo -e "[=== Installing gdb. ===]\n"
    if [ "$1" = true ]; then
        echo -e "[=== Installing gdb from sources. ===]\n"
        apt install --yes build-essential texinfo libmpfr-dev bison flex
        wget -qO- https://ftp.gnu.org/gnu/gdb/gdb-14.2.tar.gz | tar -xvz
        cd gdb-14.2
        ./configure --target=all
        make -j$(nproc) CXXFLAGS="-static-libstdc++"
        make install
        cd ..
        rm -rf gdb-14.2
    else
        apt install --yes gdb-multiarch
    fi
}

# if argument passed to this function is true, install the latest version of cmake using pip
# else install cmake from apt
install_cmake() {
    echo -e "[=== Installing cmake. ===]\n"
    if [ "$1" = true ]; then
        echo -e "[=== Installing cmake from pip. ===]\n"
        apt remove cmake -y
        apt install python3-pip -y
        pip3 install cmake
    else
        echo -e "[=== Installing cmake from apt. ===]\n"
        apt install --yes cmake
    fi
}



install_pico() {
    echo -e "[=== Installing RPi pico tools. ===]\n"

    pico_dir="$real_user_home/pico"
    sudo -u "$real_user" mkdir -p $pico_dir

    apt install --yes automake autoconf build-essential texinfo libtool libftdi-dev libusb-1.0-0-dev

    if [ "$1" = true ]; then
        echo -e "[=== Installing the latest version of RPi pico tools. ===]\n"
        wget -qO - "https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-$(uname -m)-arm-none-eabi.tar.xz" | tar --exclude='*arm-none-eabi-gdb*' --exclude='share' --strip-components=1 -xJC $pico_dir/gcc-arm-none-eabi
        # add the toolchain to the path in bashrc
        echo "export ARM_NONE_EABI_TOOLCHAIN=$pico_dir/gcc-arm-none-eabi" >> ~/.bashrc
        echo "export PATH=\$PATH:\$ARM_NONE_EABI_TOOLCHAIN/bin" >> ~/.bashrc

        source ~/.bashrc 
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
            echo "export $varname=$dest" >> ~/.bashrc
            export "${varname}=$dest"
        fi
    done

    sudo -u "$real_user" source ~/.bashrc

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
            sudo -u "$real_user" cmake ..
            sudo -u "$real_user" make -j$(nproc)
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
    echo "This script installs the 'clang' and 'gcc' toolchains, and some basic dev tools."
    echo "This script cannot modify the existing toolchain installations"

    echo "Usage: bash install_all.sh [OPTIONS...]"
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

# ref: https://askubuntu.com/a/30157/8698
if ! [ $(id -u) = 0 ]; then
   echo "This script must be run with root privilages." >&2
   echo -e "Run it with:\n" >&2
   echo -e "\t'sudo bash $(basename $BASH_SOURCE)'\n" >&2
   echo -e "You'll need to enter your root password." >&2
   exit 1
fi

# not really needed here
if [ $SUDO_USER ]; then
    real_user=$SUDO_USER
else
    real_user=$(whoami)
fi

# real_user_home=$(sudo -u "$real_user" sh -c 'echo $HOME')
# real_user_home=$(bash -c "cd ~$(printf %q "$real_user") && pwd")
real_user_home=$( getent passwd "$real_user" | cut -d: -f6 )

echo -e "[=== Upgrading the system. ===]\n"

apt update
apt upgrade --yes


echo -e "[=== Installing basic tools and build essentials. ===]\n"

apt install --yes  git valgrind build-essential python3 python3-pip
install_gdb $gdb_latest
install_cmake $latest

if [ "$dev" = true ]; then
    install_dev_tools $latest
fi

update_links $dev_latest

#install pico-sdk and tools

if [ "$pico" = true ]; then
    install_pico $latest
fi

echo -e "[=== Configuring WSL. ===]\n"

#if running under wsl, configure it
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
    echo -e "[=== Configuring WSL. ===]\n"
    configure_wsl
fi

#install vs code remote server
wget -O- https://aka.ms/install-vscode-server/setup.sh | sh

#install vscode plugins
if command -v code &> /dev/null; then
    install_vscode_plugins
fi


echo -e "[=== All done. Enjoy! ===]\n"
