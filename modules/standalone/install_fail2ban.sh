#!/usr/bin/env bash
set -u

# ============================================================
# 安装并配置 Fail2Ban
# 功能：安装 Fail2Ban，配置 SSH jail，可自定义参数
# ============================================================

# 加载公共库
SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

JAIL_LOCAL="/etc/fail2ban/jail.local"

# --- 包管理 ---
detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then
        printf 'apt'
    elif command -v dnf &>/dev/null; then
        printf 'dnf'
    elif command -v yum &>/dev/null; then
        printf 'yum'
    elif command -v pacman &>/dev/null; then
        printf 'pacman'
    else
        printf 'unknown'
    fi
}

install_fail2ban() {
    local pkg_mgr="$1"
    msg_info "正在安装 Fail2Ban..."
    case "$pkg_mgr" in
        apt)
            apt-get update -qq >/dev/null 2>&1
            apt-get install -y -qq fail2ban >/dev/null 2>&1
            ;;
        dnf)
            dnf install -y -q fail2ban >/dev/null 2>&1
            ;;
        yum)
            yum install -y -q epel-release >/dev/null 2>&1
            yum install -y -q fail2ban >/dev/null 2>&1
            ;;
        pacman)
            pacman -Sy --noconfirm fail2ban >/dev/null 2>&1
            ;;
        *)
            msg_err "不支持的包管理器，请手动安装 fail2ban"
            exit 1
            ;;
    esac

    if command -v fail2ban-client &>/dev/null; then
        msg_ok "Fail2Ban 安装成功"
    else
        msg_err "Fail2Ban 安装失败"
        exit 1
    fi
}

get_ssh_port() {
    local port
    port=$(grep -E '^\s*Port\s+' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -n1)
    printf '%s' "${port:-22}"
}

# --- 主流程 ---
main() {
    check_root

    draw_current_title "安装 Fail2Ban"

    # 检查是否已安装
    if command -v fail2ban-client &>/dev/null; then
        local version
        version=$(fail2ban-client version 2>/dev/null || printf 'unknown')
        msg_info "Fail2Ban 已安装 (版本: $version)"
        if ! yesno_select "是否重新配置？" "y"; then
            msg_info "退出"
            exit 0
        fi
    else
        local pkg_mgr
        pkg_mgr=$(detect_pkg_manager)
        msg_info "包管理器: $pkg_mgr"
        install_fail2ban "$pkg_mgr"
    fi

    # 获取当前 SSH 端口
    local ssh_port
    ssh_port=$(get_ssh_port)
    msg_info "当前 SSH 端口: $ssh_port"
    printf '\n'

    # --- 参数配置 ---
    printf '%b' "$(msg_prompt "输入" "设置封禁时长 （默认 3600 秒，-1 为永久）: ")"
    read -r input_bantime
    local bantime="${input_bantime:-3600}"

    printf '%b' "$(msg_prompt "输入" "设置检测时间窗口（默认 600 秒）: ")"
    read -r input_findtime
    local findtime="${input_findtime:-600}"

    printf '%b' "$(msg_prompt "输入" "设置最大重试次数（默认 5 次）: ")"
    read -r input_maxretry
    local maxretry="${input_maxretry:-5}"

    # 是否启用邮件通知
    local enable_mail="n"
    local dest_email=""
    local sender_email=""
    if yesno_select "是否启用封禁邮件通知？"; then
        enable_mail="y"
        printf '%b' "$(msg_prompt "输入" "接收通知的邮箱: ")"
        read -r dest_email
        printf '%b' "$(msg_prompt "输入" "发件人邮箱（默认 fail2ban@localhost）: ")"
        read -r sender_email
        sender_email="${sender_email:-fail2ban@localhost}"
    fi

    # 是否监控 nginx
    local enable_nginx="n"
    if command -v nginx &>/dev/null; then
        if yesno_select "检测到 nginx，是否启用 nginx 防护？"; then
            enable_nginx="y"
        fi
    fi

    # 备份旧配置
    if [ -f "$JAIL_LOCAL" ]; then
        sk_create_backup "$JAIL_LOCAL" "$SK_SYSTEM_BACKUP_DIR" "jail.local" >/dev/null || return 1
        sk_rotate_backups "$SK_SYSTEM_BACKUP_DIR/jail.local.bak.*"
    fi

    # 写入 jail.local
    {
        printf '[DEFAULT]\n'
        printf 'bantime = %s\n' "$bantime"
        printf 'findtime = %s\n' "$findtime"
        printf 'maxretry = %s\n' "$maxretry"
        printf 'banaction = iptables-multiport\n'
        if [ "$enable_mail" = "y" ]; then
            printf 'destemail = %s\n' "$dest_email"
            printf 'sender = %s\n' "$sender_email"
            printf 'mta = sendmail\n'
            printf 'action = %%(action_mwl)s\n'
        fi
        printf '\n[sshd]\n'
        printf 'enabled = true\n'
        printf 'port = %s\n' "$ssh_port"
        printf 'filter = sshd\n'
        printf 'logpath = /var/log/auth.log\n'
        printf 'maxretry = %s\n' "$maxretry"
        if [ "$enable_nginx" = "y" ]; then
            printf '\n[nginx-http-auth]\n'
            printf 'enabled = true\n'
            printf 'port = http,https\n'
            printf 'filter = nginx-http-auth\n'
            printf 'logpath = /var/log/nginx/error.log\n'
            printf 'maxretry = %s\n' "$maxretry"
        fi
    } > "$JAIL_LOCAL"

    msg_ok "配置已写入: $JAIL_LOCAL"

    # 处理日志路径兼容性
    if [ ! -f /var/log/auth.log ] && [ -f /var/log/secure ]; then
        sed -i 's|/var/log/auth.log|/var/log/secure|g' "$JAIL_LOCAL"
        msg_info "日志路径已调整为 /var/log/secure"
    fi

    # 启动服务
    msg_info "正在启动 Fail2Ban..."
    systemctl enable fail2ban >/dev/null 2>&1
    systemctl restart fail2ban

    if systemctl is-active fail2ban &>/dev/null; then
        msg_ok "Fail2Ban 已启动"
    else
        msg_err "Fail2Ban 启动失败，请检查日志: journalctl -u fail2ban"
        exit 1
    fi

    printf "\n%bFail2Ban 安装完成！%b\n" "$GREEN" "$PLAIN"
}

main
