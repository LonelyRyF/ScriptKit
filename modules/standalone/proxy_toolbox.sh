#!/usr/bin/env bash
set -u

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

proxy_toolbox_workdir() {
    printf '%s' "${SCRIPTKIT_PROXY_WORKDIR:-${HOME:-/root}/.scriptkit/proxy/${SCRIPTKIT_PROXY_TOOL:-tool}}"
}

proxy_toolbox_prepare_script() {
    local target_file="$1"
    shift
    local remote_url=""

    mkdir -p "$(dirname -- "$target_file")" || return 1

    for remote_url in "$@"; do
        [ -n "$remote_url" ] || continue
        msg_info "正在下载上游脚本..."
        if download_file "$remote_url" "$target_file"; then
            chmod 700 "$target_file" 2>/dev/null || true
            return 0
        fi
    done

    return 1
}

proxy_toolbox_run_script() {
    local workdir="$1"
    local script_file="$2"
    shift 2

    (
        cd "$workdir" || exit 1
        bash "$script_file" "$@"
    )
}

proxy_toolbox_run_custom_args() {
    local workdir="$1"
    local script_file="$2"

    if [ -z "${SCRIPTKIT_PROXY_ARGS:-}" ]; then
        msg_err "未提供自定义参数"
        return 1
    fi

    (
        cd "$workdir" || exit 1
        bash -c 'script_file="$1"; eval "set -- $SCRIPTKIT_PROXY_ARGS"; bash "$script_file" "$@"' _ "$script_file"
    )
}

proxy_toolbox_run_singbox_233box() {
    local workdir="$(proxy_toolbox_workdir)"
    local mode="${SCRIPTKIT_PROXY_MODE:-install}"
    local script_file="$workdir/233box-install.sh"
    local value="${SCRIPTKIT_PROXY_VALUE:-}"

    draw_current_title "233box Sing-box"
    proxy_toolbox_prepare_script \
        "$script_file" \
        "https://raw.githubusercontent.com/233boy/sing-box/main/install.sh" || {
        msg_err "下载 233box 安装脚本失败"
        return 1
    }

    case "$mode" in
        install) proxy_toolbox_run_script "$workdir" "$script_file" ;;
        help) proxy_toolbox_run_script "$workdir" "$script_file" -h ;;
        proxy)
            [ -n "$value" ] || { msg_err "未提供代理地址"; return 1; }
            proxy_toolbox_run_script "$workdir" "$script_file" -p "$value"
            ;;
        version)
            [ -n "$value" ] || { msg_err "未提供内核版本"; return 1; }
            proxy_toolbox_run_script "$workdir" "$script_file" -v "$value"
            ;;
        custom) proxy_toolbox_run_custom_args "$workdir" "$script_file" ;;
        *)
            msg_err "未知 233box 模式: $mode"
            return 1
            ;;
    esac
}

proxy_toolbox_run_singbox_fscarmen() {
    local workdir="$(proxy_toolbox_workdir)"
    local mode="${SCRIPTKIT_PROXY_MODE:-interactive}"
    local script_file="$workdir/fscarmen-sing-box.sh"

    draw_current_title "fscarmen Sing-box"
    proxy_toolbox_prepare_script \
        "$script_file" \
        "https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh" || {
        msg_err "下载 fscarmen 脚本失败"
        return 1
    }

    case "$mode" in
        interactive) proxy_toolbox_run_script "$workdir" "$script_file" ;;
        quick_cn) proxy_toolbox_run_script "$workdir" "$script_file" -l ;;
        quick_en) proxy_toolbox_run_script "$workdir" "$script_file" -k ;;
        nodes) proxy_toolbox_run_script "$workdir" "$script_file" -n ;;
        edit) proxy_toolbox_run_script "$workdir" "$script_file" -d ;;
        service) proxy_toolbox_run_script "$workdir" "$script_file" -s ;;
        argo) proxy_toolbox_run_script "$workdir" "$script_file" -a ;;
        update) proxy_toolbox_run_script "$workdir" "$script_file" -v ;;
        system) proxy_toolbox_run_script "$workdir" "$script_file" -b ;;
        protocols) proxy_toolbox_run_script "$workdir" "$script_file" -r ;;
        uninstall) proxy_toolbox_run_script "$workdir" "$script_file" -u ;;
        custom) proxy_toolbox_run_custom_args "$workdir" "$script_file" ;;
        *)
            msg_err "未知 fscarmen 模式: $mode"
            return 1
            ;;
    esac
}

proxy_toolbox_run_3xui() {
    local workdir="$(proxy_toolbox_workdir)"
    local mode="${SCRIPTKIT_PROXY_MODE:-install}"
    local script_file=""

    draw_current_title "3x-ui"

    case "$mode" in
        install)
            script_file="$workdir/3x-ui-install.sh"
            proxy_toolbox_prepare_script \
                "$script_file" \
                "https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh" \
                "https://raw.githubusercontent.com/mhsanaei/3x-ui/main/install.sh" || {
                msg_err "下载 3x-ui 安装脚本失败"
                return 1
            }
            proxy_toolbox_run_script "$workdir" "$script_file"
            ;;
        start|stop|restart|status|settings|enable|disable|log|update|uninstall)
            script_file="$workdir/x-ui.sh"
            proxy_toolbox_prepare_script \
                "$script_file" \
                "https://raw.githubusercontent.com/mhsanaei/3x-ui/main/x-ui.sh" \
                "https://raw.githubusercontent.com/mhsanaei/3x-ui/master/x-ui.sh" || {
                msg_err "下载 3x-ui 管理脚本失败"
                return 1
            }
            proxy_toolbox_run_script "$workdir" "$script_file" "$mode"
            ;;
        custom)
            script_file="$workdir/x-ui.sh"
            proxy_toolbox_prepare_script \
                "$script_file" \
                "https://raw.githubusercontent.com/mhsanaei/3x-ui/main/x-ui.sh" \
                "https://raw.githubusercontent.com/mhsanaei/3x-ui/master/x-ui.sh" || {
                msg_err "下载 3x-ui 管理脚本失败"
                return 1
            }
            proxy_toolbox_run_custom_args "$workdir" "$script_file"
            ;;
        *)
            msg_err "未知 3x-ui 模式: $mode"
            return 1
            ;;
    esac
}

proxy_toolbox_run_realm_xwpf() {
    local workdir="$(proxy_toolbox_workdir)"
    local mode="${SCRIPTKIT_PROXY_MODE:-install}"
    local script_file=""

    draw_current_title "realm-xwPF"

    case "$mode" in
        install|menu|custom)
            script_file="$workdir/xwPF.sh"
            proxy_toolbox_prepare_script \
                "$script_file" \
                "https://raw.githubusercontent.com/zywe03/realm-xwPF/main/xwPF.sh" || {
                msg_err "下载 realm-xwPF 主脚本失败"
                return 1
            }
            case "$mode" in
                install) proxy_toolbox_run_script "$workdir" "$script_file" install ;;
                menu) proxy_toolbox_run_script "$workdir" "$script_file" ;;
                custom) proxy_toolbox_run_custom_args "$workdir" "$script_file" ;;
            esac
            ;;
        speedtest)
            script_file="$workdir/speedtest.sh"
            proxy_toolbox_prepare_script \
                "$script_file" \
                "https://raw.githubusercontent.com/zywe03/realm-xwPF/main/speedtest.sh" || {
                msg_err "下载 speedtest 脚本失败"
                return 1
            }
            proxy_toolbox_run_script "$workdir" "$script_file"
            ;;
        dog)
            script_file="$workdir/port-traffic-dog.sh"
            proxy_toolbox_prepare_script \
                "$script_file" \
                "https://raw.githubusercontent.com/zywe03/realm-xwPF/main/port-traffic-dog.sh" || {
                msg_err "下载端口流量狗脚本失败"
                return 1
            }
            proxy_toolbox_run_script "$workdir" "$script_file"
            ;;
        *)
            msg_err "未知 realm-xwPF 模式: $mode"
            return 1
            ;;
    esac
}

main() {
    case "${SCRIPTKIT_PROXY_TOOL:-}" in
        singbox_233box) proxy_toolbox_run_singbox_233box ;;
        singbox_fscarmen) proxy_toolbox_run_singbox_fscarmen ;;
        3xui) proxy_toolbox_run_3xui ;;
        realm_xwpf) proxy_toolbox_run_realm_xwpf ;;
        *)
            msg_err "未知代理工具: ${SCRIPTKIT_PROXY_TOOL:-<empty>}"
            return 1
            ;;
    esac
}

main "$@"
