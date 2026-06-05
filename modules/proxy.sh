#!/usr/bin/env bash

add_menu "proxy" "代理工具" "main"

proxy_toolbox_run() {
    local tool="$1"
    local mode="$2"
    local workdir="${HOME:-/root}/.scriptkit/proxy/$tool"

    shift 2

    run_standalone_with_env "modules/standalone/proxy_toolbox.sh" \
        "SCRIPTKIT_PROXY_TOOL=$tool" \
        "SCRIPTKIT_PROXY_MODE=$mode" \
        "SCRIPTKIT_PROXY_WORKDIR=$workdir" \
        "$@"
}

proxy_prompt_custom_args() {
    local title="$1"
    local prompt="$2"
    local tool="$3"
    local mode="$4"
    local args=""

    scriptkit_draw_current_title "$title"
    printf '%b' "$(ui_prompt "输入" "$prompt")"
    read -r args
    args="${args:-}"

    if [ -z "$args" ]; then
        ui_warn "未输入参数。"
        return 1
    fi

    proxy_toolbox_run "$tool" "$mode" "SCRIPTKIT_PROXY_ARGS=$args"
}

proxy_prompt_value_run() {
    local title="$1"
    local prompt="$2"
    local tool="$3"
    local mode="$4"
    local env_name="$5"
    local value=""

    scriptkit_draw_current_title "$title"
    printf '%b' "$(ui_prompt "输入" "$prompt")"
    read -r value
    value="${value:-}"

    if [ -z "$value" ]; then
        ui_warn "未输入内容。"
        return 1
    fi

    proxy_toolbox_run "$tool" "$mode" "$env_name=$value"
}

proxy_singbox_233box_install_run() {
    proxy_toolbox_run "singbox_233box" "install"
}

proxy_singbox_233box_help_run() {
    proxy_toolbox_run "singbox_233box" "help"
}

proxy_singbox_233box_proxy_run() {
    proxy_prompt_value_run \
        "233box 指定下载代理" \
        "请输入代理地址（例如 http://127.0.0.1:2333 或 socks5://127.0.0.1:2333）: " \
        "singbox_233box" \
        "proxy" \
        "SCRIPTKIT_PROXY_VALUE"
}

proxy_singbox_233box_version_run() {
    proxy_prompt_value_run \
        "233box 指定内核版本" \
        "请输入 sing-box 内核版本（例如 v1.12.0）: " \
        "singbox_233box" \
        "version" \
        "SCRIPTKIT_PROXY_VALUE"
}

proxy_singbox_233box_custom_run() {
    proxy_prompt_custom_args \
        "233box 自定义安装参数" \
        "请输入参数（例如 -p http://127.0.0.1:2333 或 -v v1.12.0）: " \
        "singbox_233box" \
        "custom"
}

proxy_singbox_fscarmen_interactive_run() {
    proxy_toolbox_run "singbox_fscarmen" "interactive"
}

proxy_singbox_fscarmen_quick_cn_run() {
    proxy_toolbox_run "singbox_fscarmen" "quick_cn"
}

proxy_singbox_fscarmen_quick_en_run() {
    proxy_toolbox_run "singbox_fscarmen" "quick_en"
}

proxy_singbox_fscarmen_nodes_run() {
    proxy_toolbox_run "singbox_fscarmen" "nodes"
}

proxy_singbox_fscarmen_edit_run() {
    proxy_toolbox_run "singbox_fscarmen" "edit"
}

proxy_singbox_fscarmen_service_run() {
    proxy_toolbox_run "singbox_fscarmen" "service"
}

proxy_singbox_fscarmen_argo_run() {
    proxy_toolbox_run "singbox_fscarmen" "argo"
}

proxy_singbox_fscarmen_update_run() {
    proxy_toolbox_run "singbox_fscarmen" "update"
}

proxy_singbox_fscarmen_system_run() {
    proxy_toolbox_run "singbox_fscarmen" "system"
}

proxy_singbox_fscarmen_protocols_run() {
    proxy_toolbox_run "singbox_fscarmen" "protocols"
}

proxy_singbox_fscarmen_uninstall_run() {
    proxy_toolbox_run "singbox_fscarmen" "uninstall"
}

proxy_singbox_fscarmen_custom_run() {
    proxy_prompt_custom_args \
        "fscarmen 自定义参数" \
        "请输入参数（例如 -l / -n / -d / -r）: " \
        "singbox_fscarmen" \
        "custom"
}

proxy_3xui_install_run() {
    proxy_toolbox_run "3xui" "install"
}

proxy_3xui_start_run() {
    proxy_toolbox_run "3xui" "start"
}

proxy_3xui_stop_run() {
    proxy_toolbox_run "3xui" "stop"
}

proxy_3xui_restart_run() {
    proxy_toolbox_run "3xui" "restart"
}

proxy_3xui_status_run() {
    proxy_toolbox_run "3xui" "status"
}

proxy_3xui_settings_run() {
    proxy_toolbox_run "3xui" "settings"
}

proxy_3xui_enable_run() {
    proxy_toolbox_run "3xui" "enable"
}

proxy_3xui_disable_run() {
    proxy_toolbox_run "3xui" "disable"
}

proxy_3xui_log_run() {
    proxy_toolbox_run "3xui" "log"
}

proxy_3xui_update_run() {
    proxy_toolbox_run "3xui" "update"
}

proxy_3xui_uninstall_run() {
    proxy_toolbox_run "3xui" "uninstall"
}

proxy_3xui_custom_run() {
    proxy_prompt_custom_args \
        "3x-ui 自定义子命令" \
        "请输入子命令（例如 restart-xray / legacy / settings）: " \
        "3xui" \
        "custom"
}

proxy_realm_xwpf_install_run() {
    proxy_toolbox_run "realm_xwpf" "install"
}

proxy_realm_xwpf_menu_run() {
    proxy_toolbox_run "realm_xwpf" "menu"
}

proxy_realm_xwpf_speedtest_run() {
    proxy_toolbox_run "realm_xwpf" "speedtest"
}

proxy_realm_xwpf_dog_run() {
    proxy_toolbox_run "realm_xwpf" "dog"
}

proxy_realm_xwpf_custom_run() {
    proxy_prompt_custom_args \
        "realm-xwPF 自定义参数" \
        "请输入参数（例如 install / --help 或其他上游参数）: " \
        "realm_xwpf" \
        "custom"
}

add_menu "proxy_singbox" "Sing-box" "proxy"
add_menu "proxy_singbox_233box" "233box" "proxy_singbox"
add_action "proxy_singbox_233box_install" "默认安装" "proxy_singbox_233box" "proxy_singbox_233box_install_run"
add_action "proxy_singbox_233box_proxy" "指定下载代理" "proxy_singbox_233box" "proxy_singbox_233box_proxy_run"
add_action "proxy_singbox_233box_version" "指定内核版本" "proxy_singbox_233box" "proxy_singbox_233box_version_run"
add_action "proxy_singbox_233box_help" "安装器帮助" "proxy_singbox_233box" "proxy_singbox_233box_help_run"
add_action "proxy_singbox_233box_custom" "自定义安装参数" "proxy_singbox_233box" "proxy_singbox_233box_custom_run"

add_menu "proxy_singbox_fscarmen" "fscarmen" "proxy_singbox"
add_action "proxy_singbox_fscarmen_interactive" "交互安装" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_interactive_run"
add_action "proxy_singbox_fscarmen_quick_cn" "极速安装（中文）" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_quick_cn_run"
add_action "proxy_singbox_fscarmen_quick_en" "极速安装（英文）" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_quick_en_run"
add_action "proxy_singbox_fscarmen_nodes" "查看节点 (-n)" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_nodes_run"
add_action "proxy_singbox_fscarmen_edit" "修改参数 (-d)" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_edit_run"
add_action "proxy_singbox_fscarmen_service" "服务开关 (-s)" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_service_run"
add_action "proxy_singbox_fscarmen_argo" "Argo 开关 (-a)" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_argo_run"
add_action "proxy_singbox_fscarmen_update" "更新到最新 (-v)" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_update_run"
add_action "proxy_singbox_fscarmen_system" "系统工具 (-b)" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_system_run"
add_action "proxy_singbox_fscarmen_protocols" "协议管理 (-r)" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_protocols_run"
add_action "proxy_singbox_fscarmen_uninstall" "卸载 (-u)" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_uninstall_run"
add_action "proxy_singbox_fscarmen_custom" "自定义参数" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_custom_run"

add_menu "proxy_3xui" "3x-ui" "proxy"
add_action "proxy_3xui_install" "官方安装脚本" "proxy_3xui" "proxy_3xui_install_run"
add_action "proxy_3xui_start" "启动" "proxy_3xui" "proxy_3xui_start_run"
add_action "proxy_3xui_stop" "停止" "proxy_3xui" "proxy_3xui_stop_run"
add_action "proxy_3xui_restart" "重启" "proxy_3xui" "proxy_3xui_restart_run"
add_action "proxy_3xui_status" "状态" "proxy_3xui" "proxy_3xui_status_run"
add_action "proxy_3xui_settings" "当前设置" "proxy_3xui" "proxy_3xui_settings_run"
add_action "proxy_3xui_enable" "启用开机自启" "proxy_3xui" "proxy_3xui_enable_run"
add_action "proxy_3xui_disable" "关闭开机自启" "proxy_3xui" "proxy_3xui_disable_run"
add_action "proxy_3xui_log" "查看日志" "proxy_3xui" "proxy_3xui_log_run"
add_action "proxy_3xui_update" "更新" "proxy_3xui" "proxy_3xui_update_run"
add_action "proxy_3xui_uninstall" "卸载" "proxy_3xui" "proxy_3xui_uninstall_run"
add_action "proxy_3xui_custom" "自定义子命令" "proxy_3xui" "proxy_3xui_custom_run"

add_menu "proxy_realm_xwpf" "realm-xwPF" "proxy"
add_action "proxy_realm_xwpf_install" "安装 / 初始化" "proxy_realm_xwpf" "proxy_realm_xwpf_install_run"
add_action "proxy_realm_xwpf_menu" "打开管理菜单" "proxy_realm_xwpf" "proxy_realm_xwpf_menu_run"
add_action "proxy_realm_xwpf_speedtest" "网络链路测速" "proxy_realm_xwpf" "proxy_realm_xwpf_speedtest_run"
add_action "proxy_realm_xwpf_dog" "端口流量狗" "proxy_realm_xwpf" "proxy_realm_xwpf_dog_run"
add_action "proxy_realm_xwpf_custom" "自定义参数" "proxy_realm_xwpf" "proxy_realm_xwpf_custom_run"
