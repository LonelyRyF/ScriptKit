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

ensure_download_tool() {
    if command_exists curl || command_exists wget; then
        return 0
    fi

    ensure_commands curl || ensure_commands wget
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

# --- 通用备份 / 轮转 / 恢复 ---

# 系统级文件（/etc 下等）统一备份到此目录，避免污染配置目录。
SK_SYSTEM_BACKUP_DIR="${SK_SYSTEM_BACKUP_DIR:-/var/backups/scriptkit}"

# 创建备份。
#   $1 源文件   $2 备份目录   $3 标签（文件名前缀，如 fstab、sshd_config）
# 成功时把备份文件完整路径打印到 stdout；人类消息走 stderr。
# cp 失败强制返回 1，调用方不会在备份缺失时继续覆写。
sk_create_backup() {
    local src="$1"
    local dir="$2"
    local label="$3"
    local stamp=""
    local backup=""

    if [ ! -f "$src" ]; then
        msg_err "源文件不存在: $src" >&2
        return 1
    fi
    mkdir -p "$dir" || {
        msg_err "无法创建备份目录: $dir" >&2
        return 1
    }
    # 时间戳到秒，附加 PID 防同秒冲突。
    stamp="$(date +%Y%m%d%H%M%S)"
    backup="${dir}/${label}.bak.${stamp}.$$"
    cp -p "$src" "$backup" || {
        msg_err "备份失败: $src" >&2
        return 1
    }
    msg_ok "已备份到: $backup" >&2
    printf '%s' "$backup"
}

# 轮转：同一 glob 模式只保留最近 N 个（默认 5），其余删除。
#   $1 glob 模式（不加引号传入，需调用方自行 quote 外层）   $2 保留数量
sk_rotate_backups() {
    local pattern="$1"
    local keep="${2:-5}"

    # shellcheck disable=SC2086
    ls -1dt $pattern 2>/dev/null | tail -n +"$((keep + 1))" | while IFS= read -r old; do
        [ -n "$old" ] && rm -f "$old"
    done
}

# 恢复：把备份覆盖回目标。
#   $1 备份文件   $2 目标路径   $3 可选校验函数名（校验失败返回 1，由调用方回退）
sk_restore_backup() {
    local backup="$1"
    local target="$2"
    local validator="${3:-}"

    if [ -z "$backup" ] || [ ! -f "$backup" ]; then
        msg_err "备份文件不存在，无法恢复: $backup"
        return 1
    fi
    cp -p "$backup" "$target" || {
        msg_err "恢复失败: $backup -> $target"
        return 1
    }
    if [ -n "$validator" ] && ! "$validator"; then
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
    local backup=""

    backup="$(sk_create_backup "$SSHD_CONFIG" "$SK_SYSTEM_BACKUP_DIR" sshd_config)" || return 1
    sk_rotate_backups "$SK_SYSTEM_BACKUP_DIR/sshd_config.bak.*"
    printf '%s' "$backup"
}

# 回滚到指定备份
rollback_ssh_config() {
    local backup="$1"

    sk_restore_backup "$backup" "$SSHD_CONFIG" || return 1
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

reboot_system_now() {
    if command_exists systemctl; then
        systemctl reboot
    elif command_exists reboot; then
        reboot
    elif command_exists shutdown; then
        shutdown -r now
    else
        msg_warn "未找到可用的重启命令，请手动重启"
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
