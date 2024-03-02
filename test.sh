#!/bin/bash

echo "This script installs multiple tools needed for C/C++ development, writing technical documentation and programming Raspberry Pi Pico."
echo "It also configures the WSL to support filesystem metadata (if run under WSL)."
echo "You can choose what toolsets you want to install."

# while true; do
#     read -p "Do you want to continue? (y/n) " yn
#     case $yn in
#         [Yy]* ) echo -e "[=== Checking requirements ===]\n"; break;;
#         [Nn]* ) echo "Bye!"; exit;;
#         * ) echo "Please answer [y]es or [n]o.";;
#     esac
# done

# ref: https://askubuntu.com/a/30157/8698
# if ! [ $(id -u) = 0 ]; then
#    echo "This script must be run with root privilages." >&2
#    echo -e "Run it with:\n" >&2
#    echo -e "\t'sudo bash $(basename $BASH_SOURCE)'\n" >&2
#    echo -e "You'll need to enter your root password." >&2
#    exit 1
# fi

# not really needed here
# if [ $SUDO_USER ]; then
#     real_user=$SUDO_USER
# else
#     real_user=$(whoami)
# fi

# THe json format is:
#     "Recipes": {
#         "DevTools": {
#             "Name": "DevTools",
#             "Description": "Install basic development tools",
#             "Actions": ["Remove old Cmake", "Install basic dev packages", "Install CMake"]
#         }
#     }

# Install jq if not installed, no output to the terminal
# If already installed upgrade it if needed
printf "Checking for installed tools, please wait..."

if (! command -v jq > /dev/null); then
  echo "Installing jq..."
  sudo apt install --yes --no-install-recommends jq > /dev/null
else
  echo "jq is already installed. Checking for updates..."
  sudo apt-get install --yes --no-install-recommends --only-upgrade jq > /dev/null
fi

# Print options to the user
json_file="test.json"

index=1
recipes=("Exit")

printf "\nPlease select a recipe to run:\n"

for key in $(jq -r '.Recipes | keys[]' "$json_file"); do
  name=$(jq -r --arg key "$key" '.Recipes[$key].Name' "$json_file")
  description=$(jq -r --arg key "$key" '.Recipes[$key].Description' "$json_file")
  echo "$index: $name - $description"
  # Add the recipe's key to the recipes array
  recipes[index]="${key}"
  index=$((index + 1))
done

echo -e "\n0: EXIT\n"

# Ask the user to select a recipe
read -p "Enter the number of the recipe you want to use: " selection

if [ "$selection" -eq 0 ]; then
  echo "Bye!"
  exit
fi

selected_recipe=${recipes[$selection]}

# Get the actions for the selected recipe
readarray actions < <(jq -r --arg selected_recipe "$selected_recipe" '.Recipes[$selected_recipe].Actions[]' "$json_file")

printf "\nActions for %s:\n" "$selected_recipe"

for action in "${actions[@]}"; do
  printf "  * %s" "$action"
done

# Run actions for the selected recipe