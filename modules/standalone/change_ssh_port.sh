#!/usr/bin/env bash
set -u

# ============================================================
# 更改 SSH 端口
# 功能：修改 sshd 监听端口，可选更新防火墙、保留旧端口
# ============================================================

# 加载公共库
SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

# --- 防火墙更新 ---
update_firewall() {
    local new_port="$1"
    local old_port="$2"
    local remove_old="$3"
    local fw
    fw=$(detect_firewall)

    case "$fw" in
        ufw)
            msg_info "检测到 ufw，正在更新规则..."
            ufw allow "$new_port"/tcp comment "SSH" >/dev/null 2>&1
            if [ "$remove_old" = "y" ]; then
                ufw delete allow "$old_port"/tcp >/dev/null 2>&1
            fi
            ufw reload >/dev/null 2>&1
            msg_ok "ufw 规则已更新"
            ;;
        firewalld)
            msg_info "检测到 firewalld，正在更新规则..."
            firewall-cmd --permanent --add-port="$new_port"/tcp >/dev/null 2>&1
            if [ "$remove_old" = "y" ]; then
                firewall-cmd --permanent --remove-port="$old_port"/tcp >/dev/null 2>&1
            fi
            firewall-cmd --reload >/dev/null 2>&1
            msg_ok "firewalld 规则已更新"
            ;;
        iptables)
            msg_info "检测到 iptables，正在添加规则..."
            iptables -A INPUT -p tcp --dport "$new_port" -j ACCEPT
            if [ "$remove_old" = "y" ]; then
                iptables -D INPUT -p tcp --dport "$old_port" -j ACCEPT 2>/dev/null
            fi
            msg_ok "iptables 规则已更新（注意：重启后可能失效，请自行持久化）"
            ;;
        none)
            msg_warn "未检测到活动的防火墙，跳过"
            ;;
    esac
}

# --- 端口验证 ---
validate_port() {
    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        return 1
    fi
    return 0
}

get_current_port() {
    local port
    port=$(grep -E '^\s*Port\s+' "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | head -n1)
    printf '%s' "${port:-22}"
}

# --- 主流程 ---
main() {
    check_root

    printf "%b========== 更改 SSH 端口 ==========%b\n\n" "$BOLD" "$PLAIN"

    local current_port
    current_port=$(get_current_port)
    msg_info "当前 SSH 端口: $current_port"
    printf '\n'

    # 输入新端口
    local new_port=""
    while true; do
        printf "请输入新的 SSH 端口号 [1-65535]: "
        read -r new_port
        if ! validate_port "$new_port"; then
            msg_err "无效的端口号，请输入 1-65535 之间的数字"
            continue
        fi
        if [ "$new_port" = "$current_port" ]; then
            msg_warn "新端口与当前端口相同，请输入不同的端口"
            continue
        fi
        if port_in_use "$new_port"; then
            msg_err "端口 $new_port 已被其他服务占用，请换一个"
            continue
        fi
        break
    done

    # 是否保留旧端口
    local keep_old="n"
    if yesno_select "是否保留旧端口 $current_port 同时监听？（双端口过渡）"; then
        keep_old="y"
    fi

    # 是否更新防火墙
    local update_fw="n"
    local fw_type
    fw_type=$(detect_firewall)
    if [ "$fw_type" != "none" ]; then
        if yesno_select "检测到防火墙 ($fw_type)，是否自动更新防火墙规则？" "y"; then
            update_fw="y"
        fi
    fi

    # 备份（带轮转）
    local backup
    backup=$(backup_ssh_config) || exit 1

    # 修改 sshd_config
    sed -i '/^\s*#\?\s*Port\s\+/d' "$SSHD_CONFIG"
    if [ "$keep_old" = "y" ]; then
        sed -i "1i Port $new_port\nPort $current_port" "$SSHD_CONFIG"
    else
        sed -i "1i Port $new_port" "$SSHD_CONFIG"
    fi
    msg_ok "sshd_config 已更新"

    # 校验配置
    if ! validate_ssh_config; then
        rollback_ssh_config "$backup"
        msg_err "操作已中止"
        exit 1
    fi

    # 更新防火墙
    if [ "$update_fw" = "y" ]; then
        local remove_old_fw="n"
        if [ "$keep_old" != "y" ]; then
            remove_old_fw="y"
        fi
        update_firewall "$new_port" "$current_port" "$remove_old_fw"
    fi

    # 重启 sshd
    msg_info "正在重启 SSH 服务..."
    if restart_sshd; then
        msg_ok "SSH 服务已重启"
    else
        rollback_ssh_config "$backup"
        msg_err "SSH 重启失败，已回滚配置"
        restart_sshd 2>/dev/null
        exit 1
    fi

    printf "\n%bSSH 端口修改完成！%b\n" "$GREEN" "$PLAIN"
    printf "新 SSH 端口: %s\n" "$new_port"
    if [ "$keep_old" = "y" ]; then
        printf "旧端口 %s 仍在监听，确认新端口可连接后可手动移除\n" "$current_port"
    fi
    printf "%b请在新终端测试连接，确认可用后再关闭当前会话。%b\n" "$YELLOW" "$PLAIN"
}

main
