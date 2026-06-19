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
STACK_MODE=""
IP4_ADDR=""
IP4_MASK=""
IP4_GATE=""
IP4_DNS=""
IP6_ADDR=""
IP6_MASK=""
IP6_GATE=""
IP6_DNS=""
AUTO_REBOOT="0"
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

supports_mirror_override() {
    case "$SYSTEM" in
        ubuntu|windows|dd|netboot.xyz)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

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

    case "$SYSTEM" in
        windows)
            msg_warn "默认 Windows 镜像的最终登录信息固定为 Administrator / Teddysun.com，RDP 端口为 3389"
            return 0
            ;;
        alpine)
            PASSWORD="LeitboGi0ro"
            msg_warn "Alpine 最终密码固定为 LeitboGi0ro，上游脚本会忽略自定义密码"
            ;;
        *)
            printf '%b' "$(msg_prompt "输入" "root 密码（留空默认 LeitboGi0ro）: ")"
            read -rs PASSWORD
            printf '\n'
            PASSWORD="${PASSWORD:-LeitboGi0ro}"
            if [ "$PASSWORD" = "LeitboGi0ro" ]; then
                msg_warn "未自定义密码，将使用默认密码 LeitboGi0ro"
            fi
            ;;
    esac

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
        ubuntu)
            msg_info "Ubuntu 将走上游 cloud image 流程，-mirror 参数不会生效"
            return 0
            ;;
    esac

    if supports_mirror_override; then
        printf '%b' "$(msg_prompt "输入" "自定义镜像源（留空使用默认）: ")"
        read -r MIRROR
    fi
}

collect_network_inputs() {
    local stack_choice=""

    if ! yesno_select "是否自定义网络参数？"; then
        return 0
    fi

    stack_choice="$(pick_from_options "选择网络栈" "自动检测" "双栈" "仅 IPv4" "仅 IPv6")" || exit 0
    case "$stack_choice" in
        双栈) STACK_MODE="dual" ;;
        仅\ IPv4) STACK_MODE="ipv4" ;;
        仅\ IPv6) STACK_MODE="ipv6" ;;
        *) STACK_MODE="auto" ;;
    esac

    if [ "$STACK_MODE" != "ipv6" ]; then
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
    fi

    if [ "$STACK_MODE" != "ipv4" ]; then
        printf '%b' "$(msg_prompt "输入" "IPv6 地址（留空使用自动配置）: ")"
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
    [ -n "$STACK_MODE" ] && [ "$STACK_MODE" != "auto" ] && COMMAND_ARGS+=(--networkstack "$STACK_MODE")

    case "$SYSTEM" in
        netboot.xyz|windows) ;;
        *)
        COMMAND_ARGS+=(-pwd "$PASSWORD" -port "$SSH_PORT")
        ;;
    esac
    [ -n "$MIRROR" ] && COMMAND_ARGS+=(-mirror "$MIRROR")

    if [ -n "$IP4_ADDR" ]; then
        COMMAND_ARGS+=(--ip-addr "$IP4_ADDR" --ip-mask "$IP4_MASK" --ip-gate "$IP4_GATE" --ip-dns "$IP4_DNS")
    fi
    if [ -n "$IP6_ADDR" ]; then
        COMMAND_ARGS+=(--ip6-addr "$IP6_ADDR" --ip6-mask "$IP6_MASK" --ip6-gate "$IP6_GATE" --ip6-dns "$IP6_DNS")
    fi
    if [ "$STACK_MODE" = "ipv4" ]; then
        COMMAND_ARGS+=(--setipv6 0)
    fi
}

print_summary() {
    local arg=""
    local stack_label=""

    clear 2>/dev/null || printf '\033c'
    draw_step_title "参数确认"
    printf "系统: %s\n" "$SYSTEM"
    [ -n "$VERSION" ] && printf "版本: %s\n" "$VERSION"
    [ -n "$ARCH_FLAG" ] && printf "架构: %s\n" "$ARCH_FLAG"
    case "$STACK_MODE" in
        dual) stack_label="双栈" ;;
        ipv4) stack_label="仅 IPv4" ;;
        ipv6) stack_label="仅 IPv6" ;;
        auto) stack_label="自动检测" ;;
        *) stack_label="" ;;
    esac
    [ -n "$stack_label" ] && printf "网络栈: %s\n" "$stack_label"
    case "$SYSTEM" in
        netboot.xyz) ;;
        windows)
            printf "最终登录: Administrator / Teddysun.com\n"
            printf "RDP 端口: 3389\n"
            ;;
        *)
            printf "SSH 端口: %s\n" "$SSH_PORT"
            printf "密码: %s\n" "$PASSWORD"
            ;;
    esac
    [ -n "$MIRROR" ] && printf "镜像源: %s\n" "$MIRROR"
    [ -n "$IMAGE_URL" ] && printf "自定义镜像: %s\n" "$IMAGE_URL"
    if [ "$SYSTEM" = "windows" ]; then
        printf "Windows 语言: %s\n" "${WINDOWS_LANG:-en}"
    fi
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
    local output_file=""
    local status=0

    TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/scriptkit-installnet.XXXXXX")" || {
        msg_err "无法创建临时目录"
        exit 1
    }
    script_file="$TMP_DIR/InstallNET.sh"
    output_file="$TMP_DIR/installnet.out"

    msg_info "正在下载远程重装脚本..."
    download_file "$REMOTE_URL" "$script_file" || {
        msg_err "下载远程脚本失败"
        exit 1
    }

    bash "$script_file" "${COMMAND_ARGS[@]}" 2>&1 | tee "$output_file"
    status=$?

    if [ "$status" -ne 0 ]; then
        if [ "$status" -eq 1 ] && grep -Fq "Input 'reboot' to continue the subsequential installation." "$output_file"; then
            if [ "$AUTO_REBOOT" = "1" ]; then
                msg_warn "远程脚本已完成，正在自动重启以继续 InstallNET 重装..."
                reboot_system_now || return 1
            else
                msg_info "远程脚本已完成，等待手动重启以继续 InstallNET 重装"
            fi
            return 0
        fi
        return "$status"
    fi

    if [ "$AUTO_REBOOT" = "1" ]; then
        msg_warn "远程脚本已完成，正在自动重启以继续 InstallNET 重装..."
        reboot_system_now || return 1
    else
        msg_info "远程脚本已完成，等待手动重启以继续 InstallNET 重装"
    fi
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

    if yesno_select "脚本完成后是否自动重启以继续 InstallNET 重装？" "n"; then
        AUTO_REBOOT="1"
    fi

    run_remote_script
}

main
