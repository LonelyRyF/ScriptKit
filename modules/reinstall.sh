#!/usr/bin/env bash

# High-risk system reinstall wrappers.

add_menu "reinstall" "重装系统" "main"

add_script "reinstall_bin456789" "bin456789 重装系统" "reinstall" "modules/standalone/reinstall_system.sh"
add_script "reinstall_installnet" "InstallNET 重装系统" "reinstall" "modules/standalone/installnet.sh"
