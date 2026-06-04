#!/usr/bin/env bash
# ============================================================
# ScriptKit 公共函数库
# 用法: source "$(dirname "$0")/lib.sh" 或由 standalone 脚本引用
# 注意: 不要在此文件中使用 set -e / exit
# ============================================================

# --- 颜色 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
PLAIN='\033[0m'
BG_BLUE='\033[1;44m'
BG_GREEN='\033[1;42m'
BG_YELLOW='\033[1;43m'
BG_RED='\033[1;41m'

# --- 消息函数 ---
msg_badge() {
    local bg="$1"
    local label="$2"
    local fg="$3"
    local message="$4"
    printf '%b %s %b %b%s%b\n' "$bg" "$label" "$PLAIN" "$fg" "$message" "$PLAIN"
}

msg_prompt() {
    local label="$1"
    local message="$2"
    printf '%b %s %b %s' "$BG_BLUE" "$label" "$PLAIN" "$message"
}

draw_title_bar() {
    local title="$1"
    printf "%b== %s ========================================%b\n\n" "$BOLD" "$title" "$PLAIN"
}

msg_info()  { msg_badge "$BG_BLUE" "提示" "$CYAN" "$1"; }
msg_ok()    { msg_badge "$BG_GREEN" "完成" "$GREEN" "$1"; }
msg_warn()  { msg_badge "$BG_YELLOW" "警告" "$YELLOW" "$1"; }
msg_err()   { msg_badge "$BG_RED" "错误" "$RED" "$1"; }
msg_cancelled() { msg_badge "$BG_BLUE" "提示" "$RED" "操作已取消"; }

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

# --- 方向键 是/否 选择器 ---
# 用法: yesno_select "提示文字" [default]
#   default: "y" 或 "n"（默认 n）
#   返回: 0=是, 1=否
yesno_select() {
    local prompt="$1"
    local default="${2:-n}"
    local cursor=1  # 0=是, 1=否
    local decorated_prompt=""
    [ "$default" = "y" ] && cursor=0
    decorated_prompt="$(msg_prompt "确认" "$prompt")"

    # fallback: 无 tput 时用文本输入
    if ! command -v tput &>/dev/null || ! [ -t 0 ] || ! [ -t 1 ] || ! tput cup 0 0 &>/dev/null 2>&1; then
        local ans=""
        printf "%b [y/N]: " "$decorated_prompt"
        read -r ans
        ans=$(printf '%s' "${ans:-$default}" | tr '[:upper:]' '[:lower:]')
        [ "$ans" = "y" ] && return 0 || return 1
    fi

    _draw_yesno() {
        tput cuu 2 2>/dev/null || printf '\033[2A'
        tput el 2>/dev/null || printf '\033[K'
        if [ "$cursor" -eq 0 ]; then
            printf "  %b%b> 是%b\n" "$GREEN" "$BOLD" "$PLAIN"
            tput el 2>/dev/null || printf '\033[K'
            printf "    否\n"
        else
            printf "    是\n"
            tput el 2>/dev/null || printf '\033[K'
            printf "  %b%b> 否%b\n" "$RED" "$BOLD" "$PLAIN"
        fi
    }

    tput civis 2>/dev/null || true
    printf "%b\n\n\n" "$decorated_prompt"
    _draw_yesno

    while true; do
        local key
        IFS= read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -rsn2 key
        fi
        case "$key" in
            "[D" | "[A" | "h" | "k")  cursor=0 ;;
            "[C" | "[B" | "l" | "j")  cursor=1 ;;
            "")  break ;;
        esac
        _draw_yesno
    done

    tput cnorm 2>/dev/null || true
    tput cuu 3 2>/dev/null || printf '\033[3A'
    tput el 2>/dev/null || printf '\033[K'
    if [ "$cursor" -eq 0 ]; then
        printf "%b 是\n" "$decorated_prompt"
    else
        printf "%b 否\n" "$decorated_prompt"
    fi
    tput dl1 2>/dev/null || printf '\033[M'
    tput dl1 2>/dev/null || printf '\033[M'
    [ "$cursor" -eq 0 ] && return 0 || return 1
}

# --- 方向键多选菜单 ---
# 用法: multiselect_menu "标题" labels_array selected_array
#   labels_array:   选项文本数组（nameref）
#   selected_array: 结果数组（nameref），0/1 表示未选/选中
multiselect_menu() {
    local title="$1"
    shift
    local -n _labels=$1
    local -n _selected=$2
    local cursor=0
    local count=${#_labels[@]}
    local i

    # fallback: 无 tput 时用数字输入
    if ! command -v tput &>/dev/null || ! tput cup 0 0 &>/dev/null 2>&1; then
        printf "%b%s%b\n" "$BOLD" "$title" "$PLAIN"
        printf "输入编号切换选中（空格分隔），直接回车确认:\n\n"
        for ((i = 0; i < count; i++)); do
            local mark="[ ]"
            [ "${_selected[$i]}" = "1" ] && mark="[x]"
            printf "  %d) %s %s\n" "$((i + 1))" "$mark" "${_labels[$i]}"
        done
        printf "\n选择（如 1 3 5）: "
        local input=""
        read -r input
        for ((i = 0; i < count; i++)); do _selected[$i]=0; done
        for num in $input; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "$count" ]; then
                _selected[$((num - 1))]=1
            fi
        done
        return
    fi

    # tput 交互模式
    trap 'tput cnorm 2>/dev/null; tput rmcup 2>/dev/null; exit 130' INT TERM

    tput smcup 2>/dev/null || true
    tput civis 2>/dev/null || true

    _draw_multiselect() {
        tput cup 0 0 2>/dev/null || true
        tput ed 2>/dev/null || true
        printf "%b== %s ==========================================%b\n\n" "$BOLD" "$title" "$PLAIN"
        for ((i = 0; i < count; i++)); do
            local mark="[ ]"
            [ "${_selected[$i]}" = "1" ] && mark="${GREEN}[x]${PLAIN}"
            if [ "$i" -eq "$cursor" ]; then
                printf "   %b%b>%b %b %b%s%b\n" "$BLUE" "$BOLD" "$PLAIN" "$mark" "$BOLD" "${_labels[$i]}" "$PLAIN"
            else
                printf "     %b %s\n" "$mark" "${_labels[$i]}"
            fi
        done
        printf "\n%b------------------------------------------------%b\n" "$BOLD" "$PLAIN"
        printf "%bSpace%b 切换选中  %bEnter%b 确认执行  %bq%b 退出\n" "$GREEN" "$PLAIN" "$CYAN" "$PLAIN" "$RED" "$PLAIN"
    }

    _draw_multiselect

    while true; do
        local key
        IFS= read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -rsn2 key
        fi
        case "$key" in
            "[A" | "k" | "K")
                [ "$cursor" -gt 0 ] && cursor=$((cursor - 1)) ;;
            "[B" | "j" | "J")
                [ "$cursor" -lt $((count - 1)) ] && cursor=$((cursor + 1)) ;;
            " ")
                if [ "${_selected[$cursor]}" = "1" ]; then
                    _selected[$cursor]=0
                else
                    _selected[$cursor]=1
                fi ;;
            "")  break ;;
            "q" | "Q")
                for ((i = 0; i < count; i++)); do _selected[$i]=0; done
                break ;;
        esac
        _draw_multiselect
    done

    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true
    trap - INT TERM
}

# --- 方向键单选菜单 ---
# 用法: select_menu "标题" labels_array selected_var [default_index]
#   labels_array:   选项文本数组（nameref）
#   selected_var:   结果索引变量（nameref，0-based）
#   default_index:   默认选中索引（默认 0）
select_menu() {
    local title="$1"
    local -n _labels=$2
    local -n _selected=$3
    local selected="${4:-0}"
    local count=${#_labels[@]}
    local i

    if [ "$count" -le 0 ]; then
        msg_warn "没有可选项" >&2
        return 1
    fi

    if ! [[ "$selected" =~ ^[0-9]+$ ]] || [ "$selected" -lt 0 ] || [ "$selected" -ge "$count" ]; then
        selected=0
    fi

    cleanup_screen() {
        tput cnorm 1>&2 2>/dev/null || true
        tput rmcup 1>&2 2>/dev/null || true
    }

    read_key() {
        local key next
        IFS= read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            key=""
            while IFS= read -rsn1 -t 0.05 next; do
                key+="$next"
                [ "$next" = "~" ] && break
                [ "${#key}" -ge 5 ] && break
            done
            [ -z "$key" ] && key="ESC"
        fi
        printf '%s' "$key"
    }

    draw_menu() {
        tput cup 0 0 1>&2 2>/dev/null || true
        tput ed 1>&2 2>/dev/null || true
        draw_title_bar "$title" >&2

        for ((i = 0; i < count; i++)); do
            if [ "$i" -eq "$selected" ]; then
                printf "   %b%b>%b %b%s%b\n" "$BLUE" "$BOLD" "$PLAIN" "$BOLD" "${_labels[$i]}" "$PLAIN" >&2
            else
                printf "     %s\n" "${_labels[$i]}" >&2
            fi
        done

        printf "\n%b------------------------------------------------%b\n" "$BOLD" "$PLAIN" >&2
        printf "%bUp/Down%b 移动  %bEnter%b 确认  %bq%b 退出\n" "$GREEN" "$PLAIN" "$CYAN" "$PLAIN" "$RED" "$PLAIN" >&2
    }

    # 无法使用 tput 时回退到普通输入
    if ! command -v tput &>/dev/null || ! [ -t 0 ] || ! [ -t 1 ] || ! tput cup 0 0 &>/dev/null 2>&1; then
        local choice=""

        draw_title_bar "$title" >&2
        for ((i = 0; i < count; i++)); do
            printf '  %d) %s\n' "$((i + 1))" "${_labels[$i]}" >&2
        done
        printf '\n%b' "$(msg_prompt "输入" "请选择 [1-${count}]（默认 $((selected + 1))）: ")" >&2
        read -r choice
        if [[ "$choice" =~ ^[Qq]$ ]]; then
            return 1
        fi
        choice="${choice:-$((selected + 1))}"
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$count" ]; then
            msg_warn "输入无效" >&2
            return 1
        fi

        _selected=$((choice - 1))
        return 0
    fi

    tput smcup 1>&2 2>/dev/null || true
    tput civis 1>&2 2>/dev/null || true
    trap 'cleanup_screen; exit 130' INT TERM

    draw_menu
    while true; do
        local key
        key="$(read_key)"
        case "$key" in
            "[A")
                [ "$selected" -gt 0 ] && selected=$((selected - 1))
                ;;
            "[B")
                [ "$selected" -lt $((count - 1)) ] && selected=$((selected + 1))
                ;;
            "")
                _selected="$selected"
                cleanup_screen
                trap - INT TERM
                return 0
                ;;
            "q" | "Q" | "ESC")
                cleanup_screen
                trap - INT TERM
                return 1
                ;;
        esac
        draw_menu
    done
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
