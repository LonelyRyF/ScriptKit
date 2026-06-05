#!/usr/bin/env bash
set -u

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

NAPCAT_INSTALLER_URL="https://nclatest.znin.net/NapNeko/NapCat-Installer/main/script/install.sh"

NAPCAT_GITHUB_PROXIES=(
    "https://ghfast.top"
    "https://git.yylx.win/"
    "https://gh-proxy.com"
    "https://ghfile.geekertao.top"
    "https://gh-proxy.net"
    "https://j.1win.ggff.net"
    "https://ghm.078465.xyz"
    "https://gitproxy.127731.xyz"
    "https://jiashu.1win.eu.org"
    "https://github.tbedu.top"
)

NAPCAT_DOCKER_PROXIES=(
    "docker.1ms.run"
    "docker.xuanyuan.me"
    "docker.mybacc.com"
    "dytt.online"
    "lispy.org"
)

prompt_input() {
    local output_name="$1"
    local -n output_ref="$output_name"
    local prompt="$2"
    local default="${3:-}"

    if [ -n "$default" ]; then
        printf '%b' "$(msg_prompt "输入" "$prompt（默认 ${default}）: ")"
    else
        printf '%b' "$(msg_prompt "输入" "$prompt: ")"
    fi

    read -r output_ref
    if [ -n "$default" ] && [ -z "$output_ref" ]; then
        output_ref="$default"
    fi
}

select_github_proxy_value() {
    local output_name="$1"
    local -n output_ref="$output_name"
    local selected=0
    local i
    local -a menu_labels=(
        "自动测速"$'\n'"不传 --proxy，由安装脚本测速后自动选择最快 GitHub 线路"
        "直连官方"$'\n'"传入 --proxy 0，不使用代理，直接访问 GitHub 官方源"
    )

    for ((i = 0; i < ${#NAPCAT_GITHUB_PROXIES[@]}; i++)); do
        menu_labels+=("代理 $((i + 1))"$'\n'"${NAPCAT_GITHUB_PROXIES[$i]}")
    done

    if ! select_menu "$(scriptkit_step_title "选择 GitHub 下载线路")" menu_labels selected 0; then
        msg_info "已取消"
        return 1
    fi

    if [ "$selected" -eq 0 ]; then
        output_ref=""
    elif [ "$selected" -eq 1 ]; then
        output_ref="0"
    else
        output_ref="$((selected - 1))"
    fi
}

select_docker_proxy_value() {
    local output_name="$1"
    local -n output_ref="$output_name"
    local selected=0
    local i
    local -a menu_labels=(
        "自动测速"$'\n'"不传 --proxy，由安装脚本测速后自动选择最快 Docker 镜像线路"
        "直连官方"$'\n'"传入 --proxy 0，不使用代理，直接拉取官方镜像"
    )

    for ((i = 0; i < ${#NAPCAT_DOCKER_PROXIES[@]}; i++)); do
        menu_labels+=("代理 $((i + 1))"$'\n'"${NAPCAT_DOCKER_PROXIES[$i]}")
    done

    if ! select_menu "$(scriptkit_step_title "选择 Docker 镜像线路")" menu_labels selected 0; then
        msg_info "已取消"
        return 1
    fi

    if [ "$selected" -eq 0 ]; then
        output_ref=""
    elif [ "$selected" -eq 1 ]; then
        output_ref="0"
    else
        output_ref="$((selected - 1))"
    fi
}

prompt_qq_value() {
    local output_name="$1"
    local -n output_ref="$output_name"

    while true; do
        prompt_input "$output_name" "请输入 QQ 号"
        if [[ "$output_ref" =~ ^[0-9]+$ ]]; then
            return 0
        fi
        msg_warn "QQ 号只能是数字。"
    done
}

select_mode_value() {
    local output_name="$1"
    local -n output_ref="$output_name"
    local selected=0
    local -a menu_labels=(
        "ws"$'\n'"WebSocket 模式"
        "reverse_ws"$'\n'"反向 WebSocket 模式"
        "reverse_http"$'\n'"反向 HTTP 模式"
    )

    if ! select_menu "$(scriptkit_step_title "选择运行模式")" menu_labels selected 0; then
        msg_info "已取消"
        return 1
    fi

    case "$selected" in
        0)
            output_ref="ws"
            return 0
            ;;
        1)
            output_ref="reverse_ws"
            return 0
            ;;
        2)
            output_ref="reverse_http"
            return 0
            ;;
    esac

    return 1
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

    draw_step_title "通用安装"
    if yesno_select "安装 NapCat TUI-CLI？"; then
        cli_enabled="y"
    fi
    select_github_proxy_value proxy_value || return 0
    if yesno_select "执行 Shell 强制重装？"; then
        force_reinstall="y"
    fi

    installer_args+=("--cli" "$cli_enabled")
    [ -n "$proxy_value" ] && installer_args+=("--proxy" "$proxy_value")
    [ "$force_reinstall" = "y" ] && installer_args+=("--force")

    run_installer "${installer_args[@]}"
}

run_visual_install() {
    local proxy_value=""
    local -a installer_args=("--tui")

    draw_step_title "可视化安装"
    select_github_proxy_value proxy_value || return 0
    [ -n "$proxy_value" ] && installer_args+=("--proxy" "$proxy_value")

    run_installer "${installer_args[@]}"
}

run_docker_install() {
    local qq_number=""
    local mode_value=""
    local proxy_value=""
    local -a installer_args=("--docker" "y")

    draw_step_title "Docker 安装"
    prompt_qq_value qq_number
    select_mode_value mode_value || return 0
    select_docker_proxy_value proxy_value || return 0

    installer_args+=("--qq" "$qq_number" "--mode" "$mode_value")
    [ -n "$proxy_value" ] && installer_args+=("--proxy" "$proxy_value")
    installer_args+=("--confirm")

    run_installer "${installer_args[@]}"
}

select_install_method() {
    local selected=0
    local -a menu_labels=(
        "通用安装"$'\n'"Shell 直接安装，适合大多数 Linux 服务器"
        "可视化安装"$'\n'"TUI 交互安装，边看边配"
        "Docker 安装"$'\n'"容器化部署，执行前会询问 QQ 号和模式"
    )

    if ! select_menu "$(scriptkit_step_title "部署方式")" menu_labels selected 0; then
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

    case "${SCRIPTKIT_NAPCAT_MODE:-}" in
        general)
            run_general_install
            ;;
        visual)
            run_visual_install
            ;;
        docker)
            run_docker_install
            ;;
        *)
            select_install_method
            ;;
    esac
}

main
