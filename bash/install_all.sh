#!/bin/bash

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

echo -e "[=== Upgrading the system. ===]\n"

apt update
apt upgrade --yes

echo -e "[=== Installing basic tools and build essentials. ===]\n"

apt install --yes cmake git gdb valgrind build-essential

echo -e "[=== Installing toolchains. This might take a while. ===]\n"

apt install --yes gcc-12 g++-12 clang-14

echo -e "[=== Creating symbollic links to compilers. ===]\n"

update-alternatives --remove-all gcc
update-alternatives --remove-all clang

update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 90 --slave /usr/bin/g++ g++ /usr/bin/g++-12
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 80 --slave /usr/bin/g++ g++ /usr/bin/g++-11
update-alternatives --install /usr/bin/clang clang /usr/bin/clang-14 90 --slave /usr/bin/clang++ clang++ /usr/bin/clang++-14

echo -e "[=== Configuring WSL. ===]\n"

touch /etc/wsl.conf

cat > /etc/wsl.conf << EOF
[automount]
enabled = true
options = "metadata"
EOF

echo -e "[=== All done. Enjoy! ===]\n"