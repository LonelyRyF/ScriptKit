#!/usr/bin/env bash
# ============================================================
# ScriptKit 公共函数库
# 用法: source "$(dirname "$0")/lib.sh" 或由 standalone 脚本引用
# 注意: 不要在此文件中使用 set -e / exit
# ============================================================

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
source "$LIB_DIR/runtime.sh"

# --- 消息函数 ---
msg_badge() {
    ui_message "$1" "$2" "$3" "$4"
}

msg_prompt() {
    ui_prompt "$1" "$2"
}

draw_current_title() {
    scriptkit_draw_current_title "$1"
}

draw_step_title() {
    draw_title_bar "$(scriptkit_step_title "$1")"
}

msg_info()  { ui_info "$1"; }
msg_ok()    { ui_ok "$1"; }
msg_warn()  { ui_warn "$1"; }
msg_err()   { ui_error "$1"; }
msg_cancelled() { ui_cancel "操作已取消"; }

detect_os_id() {
    local os_id=""

    if [ -r /etc/os-release ]; then
        os_id="$({
            . /etc/os-release 2>/dev/null
            printf '%s' "${ID:-}"
        } 2>/dev/null)"
    elif command_exists lsb_release; then
        os_id="$(lsb_release -is 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    fi

    printf '%s' "$os_id"
}

install_packages() {
    local os_id=""
    local package=""
    local -a packages=()
    local -A seen=()

    [ "$#" -gt 0 ] || return 0
    require_root_action || return 1

    for package in "$@"; do
        [ -n "$package" ] || continue
        if [ -n "${seen[$package]:-}" ]; then
            continue
        fi
        seen["$package"]=1
        packages+=("$package")
    done

    [ "${#packages[@]}" -gt 0 ] || return 0
    os_id="$(detect_os_id)"

    case "$os_id" in
        debian|ubuntu|linuxmint)
            apt-get update -y >/dev/null 2>&1 || return 1
            DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}" >/dev/null 2>&1 || return 1
            ;;
        centos|rhel|fedora|rocky|almalinux|anolis|opencloudos|openeuler)
            if command_exists dnf; then
                dnf install -y "${packages[@]}" >/dev/null 2>&1 || return 1
            elif command_exists yum; then
                yum install -y "${packages[@]}" >/dev/null 2>&1 || return 1
            else
                return 1
            fi
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm --needed "${packages[@]}" >/dev/null 2>&1 || return 1
            ;;
        opensuse*|suse)
            zypper --non-interactive install "${packages[@]}" >/dev/null 2>&1 || return 1
            ;;
        alpine)
            apk add --no-cache "${packages[@]}" >/dev/null 2>&1 || return 1
            ;;
        openwrt)
            opkg update >/dev/null 2>&1 || return 1
            opkg install "${packages[@]}" >/dev/null 2>&1 || return 1
            ;;
        *)
            msg_err "不支持的发行版，无法自动安装: ${packages[*]}"
            return 1
            ;;
    esac
}

ensure_commands() {
    local spec=""
    local command_name=""
    local package_name=""
    local -a packages=()

    for spec in "$@"; do
        [ -n "$spec" ] || continue
        case "$spec" in
            *:*)
                command_name="${spec%%:*}"
                package_name="${spec#*:}"
                ;;
            *)
                command_name="$spec"
                package_name="$spec"
                ;;
        esac

        if ! command_exists "$command_name"; then
            packages+=("$package_name")
        fi
    done

    if [ "${#packages[@]}" -gt 0 ]; then
        msg_info "正在安装依赖: ${packages[*]}"
        install_packages "${packages[@]}" || {
            msg_err "依赖安装失败: ${packages[*]}"
            return 1
        }
    fi

    for spec in "$@"; do
        [ -n "$spec" ] || continue
        case "$spec" in
            *:*) command_name="${spec%%:*}" ;;
            *) command_name="$spec" ;;
        esac
        if ! command_exists "$command_name"; then
            msg_err "未找到命令: $command_name"
            return 1
        fi
    done
}

# --- 权限检查 ---
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        msg_err "此脚本需要 root 权限运行"
        exit 1
    fi
}

require_root_action() {
    if [ "$(id -u)" -ne 0 ]; then
        msg_err "此操作需要 root 权限"
        return 1
    fi
    return 0
}

# --- SSH 配置公共函数 ---

SSHD_CONFIG="${SSHD_CONFIG:-/etc/ssh/sshd_config}"

# 校验 sshd 配置语法
validate_ssh_config() {
    if ! command -v sshd &>/dev/null; then
        msg_warn "未找到 sshd 命令，跳过配置校验"
        return 0
    fi
    if sshd -t >/dev/null 2>&1; then
        msg_ok "SSH 配置校验通过"
        return 0
    else
        msg_err "SSH 配置校验失败:"
        sshd -t 2>&1 | sed 's/^/    /'
        return 1
    fi
}

# 备份 sshd_config（带轮转，保留最近 5 个）
# 输出备份文件路径到 stdout
backup_ssh_config() {
    local backup="${SSHD_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$SSHD_CONFIG" "$backup" || {
        msg_err "备份失败" >&2
        return 1
    }
    msg_ok "配置已备份到: $backup" >&2
    # 轮转
    find "$(dirname "$SSHD_CONFIG")" -maxdepth 1 -name 'sshd_config.bak.*' -type f 2>/dev/null \
        | sort -r | tail -n +6 | while IFS= read -r old; do
        rm -f "$old"
    done
    printf '%s' "$backup"
}

# 回滚到指定备份
rollback_ssh_config() {
    local backup="$1"
    if [ -z "$backup" ] || [ ! -f "$backup" ]; then
        msg_err "找不到备份文件，无法回滚"
        return 1
    fi
    cp "$backup" "$SSHD_CONFIG" || {
        msg_err "回滚失败"
        return 1
    }
    msg_warn "已回滚到备份: $backup"
}

# 重启 SSH 服务
restart_sshd() {
    if systemctl is-active sshd &>/dev/null; then
        systemctl restart sshd
    elif systemctl is-active ssh &>/dev/null; then
        systemctl restart ssh
    else
        msg_warn "无法确定 SSH 服务名称，请手动重启"
        return 1
    fi
}

# 修改 sshd_config 中的配置项
set_sshd_option() {
    local key="$1"
    local value="$2"
    if grep -qE "^\s*#?\s*${key}\s+" "$SSHD_CONFIG"; then
        sed -i "s|^\s*#\?\s*${key}\s\+.*|${key} ${value}|" "$SSHD_CONFIG"
    else
        printf '%s %s\n' "$key" "$value" >> "$SSHD_CONFIG"
    fi
}

# 获取 sshd_config 中某配置项的当前值
get_sshd_option() {
    local key="$1"
    local val
    val=$(grep -E "^\s*${key}\s+" "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' | tail -n1)
    printf '%s' "$val"
}

# 检测端口是否已被占用
port_in_use() {
    local port="$1"
    if command -v ss &>/dev/null; then
        ss -tuln 2>/dev/null | grep -qE "[:.]${port}[[:space:]]"
    elif command -v netstat &>/dev/null; then
        netstat -tuln 2>/dev/null | grep -qE "[:.]${port}[[:space:]]"
    else
        return 1
    fi
}

# 检测防火墙类型
detect_firewall() {
    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "active"; then
        printf 'ufw'
    elif command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
        printf 'firewalld'
    elif command -v iptables &>/dev/null; then
        printf 'iptables'
    else
        printf 'none'
    fi
}
