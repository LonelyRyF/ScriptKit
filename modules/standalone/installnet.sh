#!/usr/bin/env bash
set -u

# Interactive wrapper for remote InstallNET.sh.

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
IMAGE_URL=""
WINDOWS_LANG=""
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

select_system() {
    local -a systems=(
        "ubuntu" "debian" "kali" "alpine" "centos"
        "rockylinux" "almalinux" "fedora" "windows" "dd" "netboot.xyz"
    )

    SYSTEM="$(pick_from_options "选择要安装的系统" "${systems[@]}")" || exit 0
}

select_version() {
    local choice=""
    local -a options=()
    declare -A versions=(
        [ubuntu]="24.04 22.04 20.04"
        [debian]="13 12 11 10 9 8 7"
        [centos]="10 9 8 7"
        [alpine]="edge 3.22 3.21 3.20 3.19 3.18 3.17 3.16"
        [kali]="rolling"
        [almalinux]="10 9 8"
        [rockylinux]="10 9 8"
        [fedora]="43 42 41 40 39 38"
        [windows]="2022 2019 2016 2012 11 10"
    )

    [ -n "${versions[$SYSTEM]:-}" ] || return 0

    while true; do
        read -r -a options <<< "${versions[$SYSTEM]}"
        options+=("手动输入")

        choice="$(pick_from_options "选择 ${SYSTEM} 版本" "${options[@]}")" || exit 0
        case "$choice" in
            手动输入)
                printf '%b' "$(msg_prompt "输入" "请输入版本号（不可留空）: ")"
                read -r VERSION
                VERSION="${VERSION:-}"
                if [ -n "$VERSION" ]; then
                    return 0
                fi
                msg_warn "版本不能为空。"
                ;;
            *)
                VERSION="$choice"
                return 0
                ;;
        esac
    done
}

require_version() {
    if [ -n "$VERSION" ]; then
        return 0
    fi

    msg_err "系统 $SYSTEM 需要指定版本。"
    exit 1
}

select_arch() {
    local choice=""

    [ "$SYSTEM" = "windows" ] && return 0
    [ "$SYSTEM" = "netboot.xyz" ] && return 0
    choice="$(pick_from_options "选择架构" "自动检测" "64-bit" "32-bit" "arm64")" || exit 0
    case "$choice" in
        64-bit) ARCH_FLAG="64" ;;
        32-bit) ARCH_FLAG="32" ;;
        arm64) ARCH_FLAG="arm64" ;;
        *) ARCH_FLAG="" ;;
    esac
}

collect_auth_inputs() {
    [ "$SYSTEM" = "netboot.xyz" ] && return 0

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
    case "$SYSTEM" in
        windows)
            printf '%b' "$(msg_prompt "输入" "Windows 语言（en/zh/jp，留空默认 en）: ")"
            read -r WINDOWS_LANG
            return 0
            ;;
        dd)
            printf '%b' "$(msg_prompt "输入" "自定义镜像 URL: ")"
            read -r IMAGE_URL
            [ -n "$IMAGE_URL" ] || {
                msg_err "DD 模式必须提供镜像 URL"
                exit 1
            }
            return 0
            ;;
        netboot.xyz)
            return 0
            ;;
    esac

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

    case "$SYSTEM" in
        ubuntu)
            require_version
            COMMAND_ARGS=(-ubuntu "$VERSION")
            ;;
        debian)
            require_version
            COMMAND_ARGS=(-debian "$VERSION")
            ;;
        kali)
            require_version
            COMMAND_ARGS=(-kali "$VERSION")
            ;;
        alpine)
            require_version
            COMMAND_ARGS=(-alpine "$VERSION")
            ;;
        centos)
            require_version
            COMMAND_ARGS=(-centos "$VERSION")
            ;;
        rockylinux)
            require_version
            COMMAND_ARGS=(-rockylinux "$VERSION")
            ;;
        almalinux)
            require_version
            COMMAND_ARGS=(-almalinux "$VERSION")
            ;;
        fedora)
            require_version
            COMMAND_ARGS=(-fedora "$VERSION")
            ;;
        windows)
            require_version
            COMMAND_ARGS=(-windows "$VERSION")
            [ -n "$WINDOWS_LANG" ] && COMMAND_ARGS+=(-lang "$WINDOWS_LANG")
            ;;
        dd) COMMAND_ARGS=(-dd "$IMAGE_URL") ;;
        netboot.xyz) COMMAND_ARGS=(-netbootxyz) ;;
    esac

    [ -n "$ARCH_FLAG" ] && COMMAND_ARGS+=(-architecture "$ARCH_FLAG")

    if [ "$SYSTEM" != "netboot.xyz" ]; then
        COMMAND_ARGS+=(-pwd "$PASSWORD" -port "$SSH_PORT")
    fi
    [ -n "$MIRROR" ] && COMMAND_ARGS+=(-mirror "$MIRROR")

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
    [ "$SYSTEM" != "netboot.xyz" ] && printf "SSH 端口: %s\n" "$SSH_PORT"
    [ "$SYSTEM" != "netboot.xyz" ] && printf "密码: %s\n" "$PASSWORD"
    [ -n "$MIRROR" ] && printf "镜像源: %s\n" "$MIRROR"
    [ -n "$IMAGE_URL" ] && printf "自定义镜像: %s\n" "$IMAGE_URL"
    [ -n "$WINDOWS_LANG" ] && printf "Windows 语言: %s\n" "$WINDOWS_LANG"
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
    [ "$SYSTEM" != "dd" ] && [ "$SYSTEM" != "netboot.xyz" ] && select_version
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
