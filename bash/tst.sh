#!/bin/bash

# not really needed here
if [ $SUDO_USER ]; then
    echo "SUDO_USER"
    real_user=$SUDO_USER
else
    real_user=$(whoami)
fi


# real_user_home=$(sudo -u "$real_user" sh -c 'echo $HOME')
# real_user_home=$(bash -c "cd ~$(printf %q "$real_user") && pwd")
real_user_home=$( getent passwd "$real_user" | cut -d: -f6 )

echo "real_user: $real_user"
echo "real_user_home: $real_user_home"

repo="blaah"
dest="random/path"

varname="PICO_${repo^^}_PATH"
# echo "export $varname=$dest" >> $real_user_home/.bashrc
export "${varname}=$dest"
sudo -u "$real_user" export "${varname}=$dest"


echo Exported "$varname"

printf "Value: %s\n" "${!varname}"
printenv | grep PICO

echo "=========="

sudo -u "$real_user" printf "Value: %s\n" "${!varname}"
sudo -E -u "$real_user" printenv | grep PICO

echo -e "[=== VS Code path: $(command -v code) ===]\n"
