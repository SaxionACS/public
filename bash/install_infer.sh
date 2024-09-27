#!/bin/bash


# Do the root check

if [[ $(id -u) -ne 0 ]]; then
    echo "Please run this script as root."
    exit 1
fi

echo "This script will install the Infer static analyzer on your system."
echo "Do you want to continue? (y/n)"

read -r response

if [[ ! $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Exiting..."
    exit 0
fi

# check of clang-18 and clang++-18 are installed

if [ ! -x "$(command -v clang-18)" ]; then
    echo "clang-18 is not installed. Please install clang-18 and clang++-18."
    exit 1
fi

# check if version was passed as an argument

if [ -z "$1" ]; then
    VERSION=1.2.0
    echo "Defaulting to Infer version $VERSION."
else
    VERSION=$1
    echo "Installing Infer version $VERSION."
fi

# Download the Infer binary archive
echo "Downloading Infer v$VERSION..."
curl -L "https://github.com/facebook/infer/releases/download/v$VERSION/infer-linux-x86_64-v$VERSION.tar.xz" -o infer-linux-x86_64-v$VERSION.tar.xz

# Extract the archive
tar -C /opt -xJf infer-linux-x86_64-v$VERSION.tar.xz
rm -f infer-linux-x86_64-v$VERSION.tar.xz

# Symlink the Infer binary
ln -s /opt/infer-linux-x86_64-v$VERSION/bin/infer /usr/local/bin/infer
