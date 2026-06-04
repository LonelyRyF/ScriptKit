#!/usr/bin/env bash
set -u

# Change the system hostname with backups and validation.

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

validate_hostname() {
    local name="$1"
    local label=""
    local old_ifs="$IFS"

    [ -n "$name" ] || return 1
    [ "${#name}" -le 253 ] || return 1
    [[ "$name" != .* ]] || return 1
    [[ "$name" != *. ]] || return 1
    [[ "$name" != *..* ]] || return 1

    IFS='.'
    for label in $name; do
        IFS="$old_ifs"
        [ -n "$label" ] || return 1
        [ "${#label}" -le 63 ] || return 1
        [[ "$label" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]] || return 1
        IFS='.'
    done
    IFS="$old_ifs"
    return 0
}

backup_hostname_files() {
    local backup_dir="${XDG_CACHE_HOME:-${HOME:-.}/.cache}/scriptkit/hostname_backups/$(date +%Y%m%d%H%M%S)"

    mkdir -p "$backup_dir" || {
        msg_err "无法创建备份目录: $backup_dir"
        return 1
    }

    [ -f /etc/hostname ] && cp /etc/hostname "$backup_dir/hostname"
    [ -f /etc/hosts ] && cp /etc/hosts "$backup_dir/hosts"
    [ -f /etc/sysconfig/network ] && cp /etc/sysconfig/network "$backup_dir/sysconfig-network"
    [ -f /etc/HOSTNAME ] && cp /etc/HOSTNAME "$backup_dir/HOSTNAME"
    [ -f /etc/conf.d/hostname ] && cp /etc/conf.d/hostname "$backup_dir/conf.d-hostname"

    msg_ok "相关配置已备份到: $backup_dir"
}

update_hosts_file() {
    local current_hostname="$1"
    local new_hostname="$2"
    local tmp=""

    [ -w /etc/hosts ] || {
        msg_warn "/etc/hosts 不可写，已跳过 hosts 映射更新"
        return 0
    }

    tmp="$(mktemp)" || return 1
    awk -v old="$current_hostname" -v new="$new_hostname" '
        $1 == "127.0.1.1" {
            print "127.0.1.1\t" new
            found = 1
            next
        }
        old != "" {
            for (i = 2; i <= NF; i++) {
                if ($i == old) $i = new
            }
        }
        { print }
        END {
            if (!found) print "127.0.1.1\t" new
        }
    ' /etc/hosts > "$tmp" || {
        rm -f "$tmp"
        return 1
    }

    cp "$tmp" /etc/hosts
    rm -f "$tmp"
}

set_hostname_runtime() {
    local new_hostname="$1"

    if command_exists hostnamectl; then
        hostnamectl set-hostname "$new_hostname"
    elif command_exists hostname; then
        hostname "$new_hostname"
    else
        msg_warn "未找到 hostnamectl 或 hostname，需重启后生效"
        return 0
    fi
}

write_hostname_files() {
    local current_hostname="$1"
    local new_hostname="$2"

    if [ -w /etc/hostname ]; then
        printf '%s\n' "$new_hostname" > /etc/hostname
    else
        msg_warn "/etc/hostname 不可写，已跳过"
    fi

    update_hosts_file "$current_hostname" "$new_hostname" || {
        msg_err "更新 /etc/hosts 失败"
        return 1
    }

    if [ -w /etc/sysconfig/network ]; then
        if grep -q '^HOSTNAME=' /etc/sysconfig/network 2>/dev/null; then
            sed -i "s/^HOSTNAME=.*/HOSTNAME=$new_hostname/" /etc/sysconfig/network
        else
            printf 'HOSTNAME=%s\n' "$new_hostname" >> /etc/sysconfig/network
        fi
    fi

    if [ -w /etc/HOSTNAME ]; then
        printf '%s\n' "$new_hostname" > /etc/HOSTNAME
    fi

    if [ -w /etc/conf.d/hostname ]; then
        if grep -q '^hostname=' /etc/conf.d/hostname 2>/dev/null; then
            sed -i "s/^hostname=.*/hostname=\"$new_hostname\"/" /etc/conf.d/hostname
        else
            printf 'hostname="%s"\n' "$new_hostname" >> /etc/conf.d/hostname
        fi
    fi

    set_hostname_runtime "$new_hostname"
}

main() {
    local current_hostname=""
    local new_hostname=""

    check_root

    printf "%b== 主机名管理 ========================================%b\n\n" "$BOLD" "$PLAIN"
    current_hostname="$(hostname 2>/dev/null || true)"
    printf "当前主机名: %s\n" "${current_hostname:-unknown}"
    printf '%b' "$(msg_prompt "输入" "新的主机名: ")"
    read -r new_hostname

    if ! validate_hostname "$new_hostname"; then
        msg_err "主机名无效。仅支持字母、数字、点号、连字符；每段 1-63 字符，总长度不超过 253。"
        exit 1
    fi

    if [ "$new_hostname" = "$current_hostname" ]; then
        msg_info "主机名没有变化"
        exit 0
    fi

    printf "\n即将修改: %s -> %s\n" "${current_hostname:-unknown}" "$new_hostname"
    if ! yesno_select "确认修改系统主机名？"; then
        msg_info "已取消"
        exit 0
    fi

    backup_hostname_files || exit 1
    write_hostname_files "$current_hostname" "$new_hostname" || exit 1

    printf "\n%b主机名已更新为: %s%b\n" "$GREEN" "$new_hostname" "$PLAIN"
    msg_warn "部分服务可能需要重启后才会读取新主机名"
}

main
