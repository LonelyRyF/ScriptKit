#!/usr/bin/env bash
set -u

# Restore sshd_config from ScriptKit-created backups.

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

BACKUPS=()

collect_backups() {
    shopt -s nullglob
    BACKUPS=("${SSHD_CONFIG}".bak.*)
    shopt -u nullglob
}

show_current_config() {
    local port=""
    local password_auth=""
    local pubkey_auth=""
    local root_login=""

    port="$(get_sshd_option "Port")"
    password_auth="$(get_sshd_option "PasswordAuthentication")"
    pubkey_auth="$(get_sshd_option "PubkeyAuthentication")"
    root_login="$(get_sshd_option "PermitRootLogin")"

    printf "%b当前 SSH 配置:%b\n" "$BOLD" "$PLAIN"
    printf "  配置文件: %s\n" "$SSHD_CONFIG"
    printf "  Port: %s\n" "${port:-默认 22}"
    printf "  PasswordAuthentication: %s\n" "${password_auth:-默认/未显式设置}"
    printf "  PubkeyAuthentication: %s\n" "${pubkey_auth:-默认/未显式设置}"
    printf "  PermitRootLogin: %s\n" "${root_login:-默认/未显式设置}"
}

print_backups() {
    local i=0
    local no=1

    printf "\n%b可回滚备份:%b\n" "$BOLD" "$PLAIN"
    for ((i = ${#BACKUPS[@]} - 1; i >= 0; i--)); do
        printf "  %d) %s\n" "$no" "${BACKUPS[$i]}"
        no=$((no + 1))
    done
}

backup_from_selection() {
    local selection="$1"
    local index=0

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#BACKUPS[@]}" ]; then
        return 1
    fi

    index=$((${#BACKUPS[@]} - selection))
    printf '%s' "${BACKUPS[$index]}"
}

restore_backup() {
    local selected_backup="$1"
    local safety_backup=""

    if [ ! -f "$selected_backup" ]; then
        msg_err "备份文件不存在: $selected_backup"
        return 1
    fi

    safety_backup="$(backup_ssh_config)" || return 1
    cp "$selected_backup" "$SSHD_CONFIG" || {
        msg_err "复制备份失败"
        rollback_ssh_config "$safety_backup"
        return 1
    }

    if ! validate_ssh_config; then
        rollback_ssh_config "$safety_backup"
        msg_err "备份配置无效，已恢复回滚前配置"
        return 1
    fi

    msg_info "正在重启 SSH 服务..."
    if restart_sshd; then
        msg_ok "SSH 配置已回滚并重启服务"
        return 0
    fi

    rollback_ssh_config "$safety_backup"
    restart_sshd >/dev/null 2>&1 || true
    msg_err "SSH 服务重启失败，已恢复回滚前配置"
    return 1
}

main() {
    local selection=""
    local selected_backup=""

    require_root_action || exit 1
    printf "%b== 回滚 SSH 配置 ========================================%b\n\n" "$BOLD" "$PLAIN"

    if [ ! -f "$SSHD_CONFIG" ]; then
        msg_err "找不到 SSH 配置文件: $SSHD_CONFIG"
        exit 1
    fi

    collect_backups
    if [ "${#BACKUPS[@]}" -eq 0 ]; then
        msg_warn "未找到备份文件: ${SSHD_CONFIG}.bak.*"
        exit 0
    fi

    show_current_config
    print_backups

    printf "\n选择要回滚的备份编号（默认 1，最新）: "
    read -r selection
    selection="${selection:-1}"
    selected_backup="$(backup_from_selection "$selection")" || {
        msg_warn "备份编号无效"
        exit 1
    }

    printf "\n将回滚到: %s\n" "$selected_backup"
    if ! yesno_select "确认回滚 SSH 配置并重启 SSH 服务？"; then
        msg_info "已取消"
        exit 0
    fi

    restore_backup "$selected_backup"
}

main
