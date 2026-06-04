#!/usr/bin/env bash

# Security tools module - registers SSH hardening and Fail2Ban entries
# Parent menu: "security" (defined in menu.sh define_menus)

add_menu "ssh_hardening" "SSH 安全加固" "security"
add_script "change_ssh_port" "更改 SSH 端口" "ssh_hardening" "modules/standalone/change_ssh_port.sh"
add_script "change_ssh_auth" "修改 SSH 登录方式" "ssh_hardening" "modules/standalone/change_ssh_auth.sh"
add_script "install_fail2ban" "安装 Fail2Ban" "security" "modules/standalone/install_fail2ban.sh"
