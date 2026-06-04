#!/usr/bin/env bash
set -u

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

NAPCAT_INSTALLER_URL="https://nclatest.znin.net/NapNeko/NapCat-Installer/main/script/install.sh"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

download_file() {
    local url="$1"
    local output="$2"

    if command_exists curl; then
        curl -fsSL "$url" -o "$output"
    elif command_exists wget; then
        wget -qO "$output" "$url"
    else
        msg_err "需要 curl 或 wget 下载 NapCat 安装脚本"
        return 1
    fi
}

prompt_input() {
    local -n result_ref=$1
    local prompt="$2"
    local default="${3:-}"

    if [ -n "$default" ]; then
        printf '%b' "$(msg_prompt "输入" "$prompt（默认 ${default}）: ")"
    else
        printf '%b' "$(msg_prompt "输入" "$prompt: ")"
    fi

    read -r result_ref
    if [ -n "$default" ] && [ -z "$result_ref" ]; then
        result_ref="$default"
    fi
}

prompt_proxy_value() {
    local -n result_ref=$1
    local max_value="$2"
    local input=""

    while true; do
        printf '%b' "$(msg_prompt "输入" "下载代理序号 [0-${max_value}]（留空使用默认源）: ")"
        read -r input

        if [ -z "$input" ]; then
            result_ref=""
            return 0
        fi

        if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 0 ] && [ "$input" -le "$max_value" ]; then
            result_ref="$input"
            return 0
        fi

        msg_warn "请输入 0-${max_value} 之间的数字，或直接回车跳过。"
    done
}

prompt_qq_value() {
    local -n result_ref=$1

    while true; do
        prompt_input result_ref "请输入 QQ 号"
        if [[ "$result_ref" =~ ^[0-9]+$ ]]; then
            return 0
        fi
        msg_warn "QQ 号只能是数字。"
    done
}

prompt_mode_value() {
    local -n result_ref=$1

    while true; do
        prompt_input result_ref "运行模式" "ws"
        if [[ "$result_ref" =~ ^[A-Za-z0-9_-]+$ ]]; then
            return 0
        fi
        msg_warn "运行模式只能包含字母、数字、下划线或中划线。"
    done
}

show_command_preview() {
    local arg

    printf "\n等效命令:\n"
    printf 'curl -o napcat.sh %q && bash napcat.sh' "$NAPCAT_INSTALLER_URL"
    for arg in "$@"; do
        printf ' %q' "$arg"
    done
    printf '\n\n'
}

run_installer() {
    local tmp_dir="${TMPDIR:-/tmp}"
    local tmp_file=""
    local status=0

    [ -d "$tmp_dir" ] || tmp_dir="."
    tmp_file="${tmp_dir%/}/scriptkit-napcat-installer.$$"

    msg_info "正在下载 NapCat 安装脚本..."
    download_file "$NAPCAT_INSTALLER_URL" "$tmp_file" || {
        rm -f "$tmp_file"
        return 1
    }
    chmod 700 "$tmp_file" 2>/dev/null || true

    bash "$tmp_file" "$@"
    status=$?
    rm -f "$tmp_file"

    if [ "$status" -eq 0 ]; then
        msg_ok "NapCat 安装脚本执行完成"
    else
        msg_err "NapCat 安装脚本执行失败"
    fi
    return "$status"
}

run_general_install() {
    local cli_enabled="n"
    local force_reinstall="n"
    local proxy_value=""
    local -a installer_args=("--docker" "n")

    draw_title_bar "NapCat 通用安装"
    if yesno_select "安装 NapCat TUI-CLI？"; then
        cli_enabled="y"
    fi
    prompt_proxy_value proxy_value 5
    if yesno_select "执行 Shell 强制重装？"; then
        force_reinstall="y"
    fi

    installer_args+=("--cli" "$cli_enabled")
    [ -n "$proxy_value" ] && installer_args+=("--proxy" "$proxy_value")
    [ "$force_reinstall" = "y" ] && installer_args+=("--force")

    show_command_preview "${installer_args[@]}"
    if ! yesno_select "确认执行 NapCat 通用安装？cli=${cli_enabled} proxy=${proxy_value:-default} force=${force_reinstall}" "y"; then
        msg_info "已取消"
        return 0
    fi

    run_installer "${installer_args[@]}"
}

run_visual_install() {
    local proxy_value=""
    local -a installer_args=("--tui")

    draw_title_bar "NapCat 可视化安装"
    prompt_proxy_value proxy_value 5
    [ -n "$proxy_value" ] && installer_args+=("--proxy" "$proxy_value")

    show_command_preview "${installer_args[@]}"
    if ! yesno_select "确认执行 NapCat 可视化安装？proxy=${proxy_value:-default}" "y"; then
        msg_info "已取消"
        return 0
    fi

    run_installer "${installer_args[@]}"
}

run_docker_install() {
    local qq_number=""
    local mode_value=""
    local proxy_value=""
    local -a installer_args=("--docker" "y")

    draw_title_bar "NapCat Docker 安装"
    prompt_qq_value qq_number
    prompt_mode_value mode_value
    prompt_proxy_value proxy_value 7

    installer_args+=("--qq" "$qq_number" "--mode" "$mode_value")
    [ -n "$proxy_value" ] && installer_args+=("--proxy" "$proxy_value")
    installer_args+=("--confirm")

    show_command_preview "${installer_args[@]}"
    if ! yesno_select "确认执行 NapCat Docker 安装？qq=${qq_number} mode=${mode_value} proxy=${proxy_value:-default}" "y"; then
        msg_info "已取消"
        return 0
    fi

    run_installer "${installer_args[@]}"
}

select_install_method() {
    local selected=0
    local -a menu_labels=(
        "通用安装"$'\n'"Shell 直接安装，适合大多数 Linux 服务器"
        "可视化安装"$'\n'"TUI 交互安装，边看边配"
        "Docker 安装"$'\n'"容器化部署，执行前会询问 QQ 号和模式"
    )

    if ! select_menu "NapCat 部署方式" menu_labels selected 0; then
        msg_info "已取消"
        return 0
    fi

    case "$selected" in
        0) run_general_install ;;
        1) run_visual_install ;;
        2) run_docker_install ;;
    esac
}

main() {
    if [ "$(id -u)" -ne 0 ]; then
        msg_warn "建议使用 root 或具备 sudo 权限的用户运行安装脚本。"
    fi
    select_install_method
}

main
