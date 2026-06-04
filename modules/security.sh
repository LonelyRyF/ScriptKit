#!/usr/bin/env bash

# Security tools module - registers SSH hardening and Fail2Ban entries
# Parent menu: "security" (defined in menu.sh define_menus)

security_ssh_config_value() {
    local config="$1"
    local key="$2"
    local value=""

    value="$(awk -v key="$key" '$1 == key { print $2 }' "$config" 2>/dev/null | tail -n 1)"
    printf '%s' "$value"
}

security_ssh_ports() {
    local config="$1"
    local ports=""

    ports="$(awk '$1 == "Port" { print $2 }' "$config" 2>/dev/null | awk 'NF')"
    printf '%s' "${ports:-22}"
}

security_count_ssh_connections() {
    local port="$1"

    if command_exists ss; then
        ss -tunH 2>/dev/null | awk -v port="$port" '
            $4 ~ "[:.]" port "$" || $5 ~ "[:.]" port "$" { count++ }
            END { print count + 0 }
        '
    elif command_exists netstat; then
        netstat -tun 2>/dev/null | awk -v port="$port" '
            NR > 2 && ($4 ~ "[:.]" port "$" || $5 ~ "[:.]" port "$") { count++ }
            END { print count + 0 }
        '
    else
        printf 'unknown'
    fi
}

security_firewall_status() {
    if command_exists ufw; then
        printf "ufw: %s\n" "$(ufw status 2>/dev/null | awk -F': ' '/^Status:/ { print $2; exit }')"
    fi
    if command_exists firewall-cmd; then
        if systemctl is-active firewalld >/dev/null 2>&1; then
            printf "firewalld: active\n"
        else
            printf "firewalld: inactive\n"
        fi
    fi
    if command_exists iptables; then
        if iptables -L >/dev/null 2>&1; then
            printf "iptables: available\n"
        else
            printf "iptables: unavailable\n"
        fi
    fi
}

security_ssh_status() {
    local config="${SSHD_CONFIG:-/etc/ssh/sshd_config}"
    local port=""
    local ports=""
    local password_auth=""
    local pubkey_auth=""
    local root_login=""
    local active_service="unknown"
    local enabled_service="unknown"

    scriptkit_draw_current_title "查看 SSH 状态"
    printf "配置文件: %s\n" "$config"
    if [ ! -r "$config" ]; then
        ui_error "无法读取 SSH 配置文件。"
        return 1
    fi

    ports="$(security_ssh_ports "$config")"
    password_auth="$(security_ssh_config_value "$config" "PasswordAuthentication")"
    pubkey_auth="$(security_ssh_config_value "$config" "PubkeyAuthentication")"
    root_login="$(security_ssh_config_value "$config" "PermitRootLogin")"

    if command_exists systemctl; then
        if systemctl status sshd >/dev/null 2>&1; then
            active_service="$(systemctl is-active sshd 2>/dev/null || printf 'unknown')"
            enabled_service="$(systemctl is-enabled sshd 2>/dev/null || printf 'unknown')"
        elif systemctl status ssh >/dev/null 2>&1; then
            active_service="$(systemctl is-active ssh 2>/dev/null || printf 'unknown')"
            enabled_service="$(systemctl is-enabled ssh 2>/dev/null || printf 'unknown')"
        fi
    fi

    printf "服务运行: %s\n" "$active_service"
    printf "开机自启: %s\n" "$enabled_service"
    printf "监听端口: %s\n" "$(printf '%s' "$ports" | tr '\n' ' ')"
    printf "密码认证: %s\n" "${password_auth:-默认/未显式设置}"
    printf "密钥认证: %s\n" "${pubkey_auth:-默认/未显式设置}"
    printf "Root 登录: %s\n" "${root_login:-默认/未显式设置}"

    printf "\n%b连接数:%b\n" "$BOLD" "$PLAIN"
    for port in $ports; do
        printf "  端口 %s: %s\n" "$port" "$(security_count_ssh_connections "$port")"
    done

    printf "\n%b防火墙状态:%b\n" "$BOLD" "$PLAIN"
    security_firewall_status | awk 'NF { print "  " $0; found = 1 } END { if (!found) print "  未检测到常见防火墙命令" }'
}

security_ssh_auth_batch_run() {
    run_standalone_with_env "modules/standalone/change_ssh_auth.sh" "SCRIPTKIT_SSH_AUTH_MODE=batch"
}

security_ssh_auth_disable_password_run() {
    run_standalone_with_env "modules/standalone/change_ssh_auth.sh" "SCRIPTKIT_SSH_AUTH_MODE=disable_password"
}

security_ssh_auth_enable_password_run() {
    run_standalone_with_env "modules/standalone/change_ssh_auth.sh" "SCRIPTKIT_SSH_AUTH_MODE=enable_password"
}

security_ssh_auth_enable_pubkey_run() {
    run_standalone_with_env "modules/standalone/change_ssh_auth.sh" "SCRIPTKIT_SSH_AUTH_MODE=enable_pubkey"
}

security_ssh_auth_disable_root_run() {
    run_standalone_with_env "modules/standalone/change_ssh_auth.sh" "SCRIPTKIT_SSH_AUTH_MODE=disable_root_login"
}

security_ssh_auth_root_key_only_run() {
    run_standalone_with_env "modules/standalone/change_ssh_auth.sh" "SCRIPTKIT_SSH_AUTH_MODE=allow_root_key_only"
}

security_ssh_auth_generate_keypair_run() {
    run_standalone_with_env "modules/standalone/change_ssh_auth.sh" "SCRIPTKIT_SSH_AUTH_MODE=generate_keypair"
}

security_ssh_auth_add_pubkey_run() {
    run_standalone_with_env "modules/standalone/change_ssh_auth.sh" "SCRIPTKIT_SSH_AUTH_MODE=add_pubkey"
}

add_menu "ssh_hardening" "SSH 安全加固" "security"
add_action "ssh_status" "查看 SSH 状态" "ssh_hardening" "security_ssh_status"
add_script "change_ssh_port" "更改 SSH 端口" "ssh_hardening" "modules/standalone/change_ssh_port.sh"
add_menu "change_ssh_auth" "修改 SSH 登录方式" "ssh_hardening"
add_action "change_ssh_auth_disable_password" "禁用密码登录" "change_ssh_auth" "security_ssh_auth_disable_password_run"
add_action "change_ssh_auth_enable_password" "启用密码登录" "change_ssh_auth" "security_ssh_auth_enable_password_run"
add_action "change_ssh_auth_enable_pubkey" "启用密钥认证" "change_ssh_auth" "security_ssh_auth_enable_pubkey_run"
add_action "change_ssh_auth_disable_root" "禁用 root SSH 登录" "change_ssh_auth" "security_ssh_auth_disable_root_run"
add_action "change_ssh_auth_root_key_only" "root 仅允许密钥登录" "change_ssh_auth" "security_ssh_auth_root_key_only_run"
add_action "change_ssh_auth_generate_keypair" "生成 SSH 密钥对" "change_ssh_auth" "security_ssh_auth_generate_keypair_run"
add_action "change_ssh_auth_add_pubkey" "添加公钥到 authorized_keys" "change_ssh_auth" "security_ssh_auth_add_pubkey_run"
add_action "change_ssh_auth_batch" "批量选择模式" "change_ssh_auth" "security_ssh_auth_batch_run"
add_script "rollback_ssh_config" "回滚 SSH 配置" "ssh_hardening" "modules/standalone/rollback_ssh_config.sh"
add_script "install_fail2ban" "安装 Fail2Ban" "security" "modules/standalone/install_fail2ban.sh"
