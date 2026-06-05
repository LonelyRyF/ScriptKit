#!/usr/bin/env bash
set -u

# Interactive wrapper for bin456789/reinstall.

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

REMOTE_URL="https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh"
TMP_DIR=""
SYSTEM=""
VERSION=""
PASSWORD="123@@@"
SSH_PORT="22"
IMAGE_URL=""
IMAGE_NAME=""
ISO_URL=""
LANG_CODE=""
UBUNTU_MINIMAL="0"
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
        "ubuntu" "debian" "centos" "alpine" "kali" "almalinux" "rocky"
        "arch" "fedora" "opensuse" "oracle" "redhat" "anolis"
        "opencloudos" "nixos" "openeuler" "fnos" "gentoo" "aosc"
        "windows" "dd" "alpine-live" "netboot.xyz"
    )

    SYSTEM="$(pick_from_options "选择安装模式或系统" "${systems[@]}")" || exit 0
}

select_version() {
    local choice=""
    local -a options=()
    declare -A versions=(
        [ubuntu]="26.04 24.04 22.04 20.04 18.04"
        [debian]="13 12 11 10 9"
        [centos]="10 9"
        [alpine]="3.23 3.22 3.21 3.20"
        [fedora]="44 43"
        [opensuse]="tumbleweed 16.0"
        [almalinux]="10 9 8"
        [rocky]="10 9 8"
        [oracle]="10 9 8"
        [anolis]="23 8 7"
        [opencloudos]="23 9 8"
        [nixos]="25.11"
        [openeuler]="24.03 22.03 20.03"
        [fnos]="1"
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

collect_special_inputs() {
    case "$SYSTEM" in
        dd)
            printf '%b' "$(msg_prompt "输入" "DD 镜像地址: ")"
            read -r IMAGE_URL
            [ -n "$IMAGE_URL" ] || {
                msg_err "DD 模式必须提供镜像地址"
                exit 1
            }
            ;;
        redhat)
            printf '%b' "$(msg_prompt "输入" "Red Hat qcow2 镜像地址: ")"
            read -r IMAGE_URL
            [ -n "$IMAGE_URL" ] || {
                msg_err "Red Hat 模式必须提供 qcow2 镜像地址"
                exit 1
            }
            ;;
        windows)
            printf '%b' "$(msg_prompt "输入" "Windows image-name（例如 Windows 11 Pro）: ")"
            read -r IMAGE_NAME
            [ -n "$IMAGE_NAME" ] || {
                msg_err "Windows 模式必须提供 image-name"
                exit 1
            }
            printf '%b' "$(msg_prompt "输入" "ISO 下载地址（可留空）: ")"
            read -r ISO_URL
            printf '%b' "$(msg_prompt "输入" "语言代码（如 zh-cn，留空默认自动）: ")"
            read -r LANG_CODE
            ;;
        ubuntu)
            if yesno_select "是否使用 Ubuntu minimal 镜像？"; then
                UBUNTU_MINIMAL="1"
            fi
            ;;
    esac
}

collect_login_inputs() {
    case "$SYSTEM" in
        netboot.xyz)
            return 0
            ;;
    esac

    printf '%b' "$(msg_prompt "输入" "root 密码（留空默认 123@@@）: ")"
    read -rs PASSWORD
    printf '\n'
    PASSWORD="${PASSWORD:-123@@@}"
    if [ "$PASSWORD" = "123@@@" ]; then
        msg_warn "未自定义密码，将使用默认密码 123@@@"
    fi

    printf '%b' "$(msg_prompt "输入" "SSH 端口（默认 22）: ")"
    read -r SSH_PORT
    SSH_PORT="${SSH_PORT:-22}"
    if ! validate_port "$SSH_PORT"; then
        msg_err "SSH 端口无效: $SSH_PORT"
        exit 1
    fi
}

build_command_args() {
    COMMAND_ARGS=()

    case "$SYSTEM" in
        dd)
            COMMAND_ARGS=("dd" "--img" "$IMAGE_URL" "--password" "$PASSWORD" "--ssh-port" "$SSH_PORT")
            ;;
        alpine-live)
            COMMAND_ARGS=("alpine" "--password" "$PASSWORD" "--ssh-port" "$SSH_PORT" "--hold=1")
            ;;
        netboot.xyz)
            COMMAND_ARGS=("netboot.xyz")
            ;;
        redhat)
            COMMAND_ARGS=("redhat" "--img" "$IMAGE_URL" "--password" "$PASSWORD" "--ssh-port" "$SSH_PORT")
            ;;
        windows)
            COMMAND_ARGS=("windows" "--image-name" "$IMAGE_NAME")
            [ -n "$ISO_URL" ] && COMMAND_ARGS+=("--iso" "$ISO_URL")
            [ -n "$LANG_CODE" ] && COMMAND_ARGS+=("--lang" "$LANG_CODE")
            COMMAND_ARGS+=("--password" "$PASSWORD" "--ssh-port" "$SSH_PORT")
            ;;
        *)
            COMMAND_ARGS=("$SYSTEM")
            [ -n "$VERSION" ] && COMMAND_ARGS+=("$VERSION")
            if [ "$SYSTEM" = "ubuntu" ] && [ "$UBUNTU_MINIMAL" = "1" ]; then
                COMMAND_ARGS+=("--minimal")
            fi
            COMMAND_ARGS+=("--password" "$PASSWORD" "--ssh-port" "$SSH_PORT")
            ;;
    esac
}

print_summary() {
    local arg=""

    draw_step_title "参数确认"
    printf "系统/模式: %s\n" "$SYSTEM"
    [ -n "$VERSION" ] && printf "版本: %s\n" "$VERSION"
    [ -n "$IMAGE_URL" ] && printf "镜像地址: %s\n" "$IMAGE_URL"
    [ -n "$IMAGE_NAME" ] && printf "Windows image-name: %s\n" "$IMAGE_NAME"
    [ -n "$ISO_URL" ] && printf "ISO 地址: %s\n" "$ISO_URL"
    [ -n "$LANG_CODE" ] && printf "语言代码: %s\n" "$LANG_CODE"
    [ "$SYSTEM" = "ubuntu" ] && [ "$UBUNTU_MINIMAL" = "1" ] && printf "Ubuntu 变体: minimal\n"
    case "$SYSTEM" in
        netboot.xyz) ;;
        *)
            printf "SSH 端口: %s\n" "$SSH_PORT"
            printf "密码: %s\n" "$PASSWORD"
            ;;
    esac

    printf "\n远程脚本: %s\n" "$REMOTE_URL"
    printf "等效参数:"
    for arg in "${COMMAND_ARGS[@]}"; do
        printf ' %q' "$arg"
    done
    printf '\n'
}

run_remote_script() {
    local script_file=""

    TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/scriptkit-reinstall.XXXXXX")" || {
        msg_err "无法创建临时目录"
        exit 1
    }
    script_file="$TMP_DIR/reinstall.sh"

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

    draw_current_title "bin456789 重装系统"
    msg_warn "这是高危操作，执行后会重装系统并清空系统盘数据。"
    select_system

    case "$SYSTEM" in
        dd|windows|redhat|ubuntu) collect_special_inputs ;;
        alpine-live|netboot.xyz) ;;
        *) select_version ;;
    esac

    case "$SYSTEM" in
        redhat) ;;
        *) [ -n "$VERSION" ] || select_version ;;
    esac

    collect_login_inputs
    build_command_args
    print_summary

    if ! yesno_select "确认开始执行系统重装？"; then
        msg_info "已取消"
        exit 0
    fi

    run_remote_script
}

main
