#!/usr/bin/env bash
set -u

# Interactive wrapper for leitbogioro/InstallNET.sh.

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

REMOTE_URL="https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh"
TMP_DIR=""
SYSTEM=""
VERSION=""
ARCH_FLAG=""
PASSWORD="LeitboGi0ro"
SSH_PORT="22"
MIRROR=""
WINDOWS_URL=""
IP4_ADDR=""
IP4_MASK=""
IP4_GATE=""
IP4_DNS=""
IP6_ADDR=""
IP6_MASK=""
IP6_GATE=""
IP6_DNS=""
COMMAND_ARGS=()

cleanup_temp() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

handle_interrupt() {
    printf '\n'
    msg_cancelled
    exit 130
}

trap cleanup_temp EXIT
trap handle_interrupt INT TERM

validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

pick_from_options() {
    local title="$1"
    shift
    local selected=0
    local -a options=("$@")

    select_menu "$(scriptkit_step_title "$title")" options selected || return 1
    printf '%s' "${options[$selected]}"
}

ensure_download_tool() {
    if command_exists curl || command_exists wget; then
        return 0
    fi

    ensure_commands curl || ensure_commands wget
}

select_system() {
    local -a systems=(
        "ubuntu" "debian" "centos" "alpine" "kali"
        "almalinux" "rockylinux" "fedora" "windows"
    )

    SYSTEM="$(pick_from_options "选择要安装的系统" "${systems[@]}")" || exit 0
}

select_version() {
    local choice=""
    local -a options=()
    declare -A versions=(
        [ubuntu]="24.04 22.04 20.04"
        [debian]="12 11 10 9 8 7"
        [centos]="10 9 8 7"
        [alpine]="edge 3.21 3.20 3.19 3.18"
        [kali]="rolling"
        [almalinux]="9 8"
        [rockylinux]="9 8"
        [fedora]="39 38"
        [windows]="2022 2019 2016 2012 11 10"
    )

    [ -n "${versions[$SYSTEM]:-}" ] || return 0
    read -r -a options <<< "${versions[$SYSTEM]}"
    options+=("手动输入" "跳过")

    choice="$(pick_from_options "选择 ${SYSTEM} 版本" "${options[@]}")" || exit 0
    case "$choice" in
        手动输入)
            printf '%b' "$(msg_prompt "输入" "请输入版本号（留空则跳过）: ")"
            read -r VERSION
            ;;
        跳过)
            VERSION=""
            ;;
        *)
            VERSION="$choice"
            ;;
    esac
}

select_arch() {
    local choice=""

    [ "$SYSTEM" = "windows" ] && return 0
    choice="$(pick_from_options "选择架构" "自动检测" "64-bit" "32-bit" "arm64")" || exit 0
    case "$choice" in
        64-bit) ARCH_FLAG="64" ;;
        32-bit) ARCH_FLAG="32" ;;
        arm64) ARCH_FLAG="arm64" ;;
        *) ARCH_FLAG="" ;;
    esac
}

collect_auth_inputs() {
    printf '%b' "$(msg_prompt "输入" "root 密码（留空默认 LeitboGi0ro）: ")"
    read -rs PASSWORD
    printf '\n'
    PASSWORD="${PASSWORD:-LeitboGi0ro}"
    if [ "$PASSWORD" = "LeitboGi0ro" ]; then
        msg_warn "未自定义密码，将使用默认密码 LeitboGi0ro"
    fi

    printf '%b' "$(msg_prompt "输入" "SSH 端口（默认 22）: ")"
    read -r SSH_PORT
    SSH_PORT="${SSH_PORT:-22}"
    if ! validate_port "$SSH_PORT"; then
        msg_err "SSH 端口无效: $SSH_PORT"
        exit 1
    fi
}

collect_source_inputs() {
    if [ "$SYSTEM" = "windows" ]; then
        printf '%b' "$(msg_prompt "输入" "Windows 镜像 URL: ")"
        read -r WINDOWS_URL
        [ -n "$WINDOWS_URL" ] || {
            msg_err "Windows 模式必须提供镜像 URL"
            exit 1
        }
        return 0
    fi

    printf '%b' "$(msg_prompt "输入" "自定义镜像源（留空使用默认）: ")"
    read -r MIRROR
}

collect_network_inputs() {
    if ! yesno_select "是否自定义网络参数？"; then
        return 0
    fi

    printf '%b' "$(msg_prompt "输入" "IPv4 地址（留空使用 DHCP）: ")"
    read -r IP4_ADDR
    if [ -n "$IP4_ADDR" ]; then
        printf '%b' "$(msg_prompt "输入" "IPv4 子网掩码: ")"
        read -r IP4_MASK
        printf '%b' "$(msg_prompt "输入" "IPv4 网关: ")"
        read -r IP4_GATE
        printf '%b' "$(msg_prompt "输入" "IPv4 DNS（默认 8.8.8.8 1.1.1.1）: ")"
        read -r IP4_DNS
        IP4_DNS="${IP4_DNS:-8.8.8.8 1.1.1.1}"
    fi

    printf '%b' "$(msg_prompt "输入" "IPv6 地址（留空则禁用静态 IPv6）: ")"
    read -r IP6_ADDR
    if [ -n "$IP6_ADDR" ]; then
        printf '%b' "$(msg_prompt "输入" "IPv6 前缀长度: ")"
        read -r IP6_MASK
        printf '%b' "$(msg_prompt "输入" "IPv6 网关: ")"
        read -r IP6_GATE
        printf '%b' "$(msg_prompt "输入" "IPv6 DNS（默认 2001:4860:4860::8888 2606:4700:4700::1111）: ")"
        read -r IP6_DNS
        IP6_DNS="${IP6_DNS:-2001:4860:4860::8888 2606:4700:4700::1111}"
    fi
}

build_command_args() {
    COMMAND_ARGS=()

    if [ "$SYSTEM" = "windows" ]; then
        COMMAND_ARGS=(-dd "$WINDOWS_URL")
    else
        COMMAND_ARGS=("-$SYSTEM")
        [ -n "$VERSION" ] && COMMAND_ARGS+=("$VERSION")
        [ -n "$ARCH_FLAG" ] && COMMAND_ARGS+=(-v "$ARCH_FLAG")
    fi

    COMMAND_ARGS+=(-pwd "$PASSWORD" -port "$SSH_PORT")
    [ -n "$MIRROR" ] && COMMAND_ARGS+=(--mirror "$MIRROR")

    if [ -n "$IP4_ADDR" ]; then
        COMMAND_ARGS+=(--ip-addr "$IP4_ADDR" --ip-mask "$IP4_MASK" --ip-gate "$IP4_GATE" --ip-dns "$IP4_DNS")
    fi
    if [ -n "$IP6_ADDR" ]; then
        COMMAND_ARGS+=(--ip6-addr "$IP6_ADDR" --ip6-mask "$IP6_MASK" --ip6-gate "$IP6_GATE" --ip6-dns "$IP6_DNS")
    elif [ -n "$IP4_ADDR" ]; then
        COMMAND_ARGS+=(--setipv6 0)
    fi
}

print_summary() {
    local arg=""

    draw_step_title "参数确认"
    printf "系统: %s\n" "$SYSTEM"
    [ -n "$VERSION" ] && printf "版本: %s\n" "$VERSION"
    [ -n "$ARCH_FLAG" ] && printf "架构: %s\n" "$ARCH_FLAG"
    printf "SSH 端口: %s\n" "$SSH_PORT"
    printf "密码: %s\n" "$PASSWORD"
    [ -n "$MIRROR" ] && printf "镜像源: %s\n" "$MIRROR"
    [ -n "$WINDOWS_URL" ] && printf "Windows 镜像: %s\n" "$WINDOWS_URL"
    [ -n "$IP4_ADDR" ] && printf "IPv4: %s / %s via %s  DNS=%s\n" "$IP4_ADDR" "$IP4_MASK" "$IP4_GATE" "$IP4_DNS"
    [ -n "$IP6_ADDR" ] && printf "IPv6: %s / %s via %s  DNS=%s\n" "$IP6_ADDR" "$IP6_MASK" "$IP6_GATE" "$IP6_DNS"

    printf "\n远程脚本: %s\n" "$REMOTE_URL"
    printf "等效参数:"
    for arg in "${COMMAND_ARGS[@]}"; do
        printf ' %q' "$arg"
    done
    printf '\n'
}

run_remote_script() {
    local script_file=""

    TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/scriptkit-installnet.XXXXXX")" || {
        msg_err "无法创建临时目录"
        exit 1
    }
    script_file="$TMP_DIR/InstallNET.sh"

    msg_info "正在下载远程重装脚本..."
    download_file "$REMOTE_URL" "$script_file" || {
        msg_err "下载远程脚本失败"
        exit 1
    }

    bash "$script_file" "${COMMAND_ARGS[@]}"
}

main() {
    check_root
    ensure_commands mktemp bash || exit 1
    ensure_download_tool || {
        msg_err "无法准备下载工具"
        exit 1
    }

    draw_current_title "InstallNET 重装系统"
    msg_warn "这是高危操作，执行后会格式化系统盘并重装系统。"
    select_system
    select_version
    select_arch
    collect_auth_inputs
    collect_source_inputs
    collect_network_inputs
    build_command_args
    print_summary

    if ! yesno_select "确认开始执行 InstallNET 重装？"; then
        msg_info "已取消"
        exit 0
    fi

    run_remote_script
}

main
