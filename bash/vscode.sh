#!/bin/bash

# if code is available, then:
if command -v code &> /dev/null; then
    # add code to PATH
    echo -e "[=== Installing VS Code remote server. ===]\n"
    wget -O- https://aka.ms/install-vscode-server/setup.sh | sh

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
fi