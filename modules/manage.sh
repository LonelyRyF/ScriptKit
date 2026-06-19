#!/usr/bin/env bash

# Read-only system management helpers.

add_menu "manage" "系统管理" "main"

manage_require_systemctl() {
    if command_exists systemctl; then
        return 0
    fi

    ui_error "未找到 systemctl。"
    return 1
}

manage_service_status() {
    local service=""
    local description=""
    local load_state=""
    local active_state=""
    local sub_state=""
    local unit_file_state=""
    local main_pid=""

    manage_require_systemctl || return 1
    scriptkit_draw_current_title "查看服务状态"
    printf '%b' "$(ui_prompt "输入" "请输入服务名（例如 ssh、nginx、docker）: ")"
    read -r service
    if [ -z "$service" ]; then
        ui_warn "服务名不能为空。"
        return 1
    fi

    printf "\n服务: %s\n\n" "$service"
    description="$(systemctl show "$service" -p Description --value 2>/dev/null || true)"
    load_state="$(systemctl show "$service" -p LoadState --value 2>/dev/null || true)"
    active_state="$(systemctl show "$service" -p ActiveState --value 2>/dev/null || true)"
    sub_state="$(systemctl show "$service" -p SubState --value 2>/dev/null || true)"
    unit_file_state="$(systemctl show "$service" -p UnitFileState --value 2>/dev/null || true)"
    main_pid="$(systemctl show "$service" -p MainPID --value 2>/dev/null || true)"

    if [ -z "$load_state" ] || [ "$load_state" = "not-found" ]; then
        ui_error "服务不存在或无法读取: $service"
        return 1
    fi

    printf "描述: %s\n" "${description:-unknown}"
    printf "加载状态: %s\n" "$load_state"
    printf "运行状态: %s / %s\n" "${active_state:-unknown}" "${sub_state:-unknown}"
    printf "开机启用: %s\n" "${unit_file_state:-unknown}"
    if [ -n "$main_pid" ] && [ "$main_pid" != "0" ]; then
        printf "主进程 PID: %s\n" "$main_pid"
    fi
}

manage_failed_services() {
    local failed_output=""

    manage_require_systemctl || return 1
    scriptkit_draw_current_title "查看失败服务"

    failed_output="$(systemctl --failed --no-legend --plain 2>/dev/null)" || {
        ui_error "读取失败服务列表失败。"
        return 1
    }

    if [ -z "$failed_output" ]; then
        printf "未发现失败服务。\n"
        return 0
    fi

    printf '%s\n' "$failed_output" | awk '
        {
            desc = ""
            for (i = 5; i <= NF; i++) {
                desc = desc (desc == "" ? "" : " ") $i
            }
            printf "服务: %s\n", $1
            printf "  状态: %s / %s\n", $3, $4
            if (desc != "") printf "  描述: %s\n", desc
            printf "\n"
        }
    '
}

manage_service_logs() {
    local service=""
    local lines=""

    if ! command_exists journalctl; then
        ui_error "未找到 journalctl。"
        return 1
    fi

    scriptkit_draw_current_title "查看服务日志"
    printf '%b' "$(ui_prompt "输入" "请输入服务名（例如 ssh、nginx、docker）: ")"
    read -r service
    if [ -z "$service" ]; then
        ui_warn "服务名不能为空。"
        return 1
    fi

    printf '%b' "$(ui_prompt "输入" "显示最近多少行日志（默认 80）: ")"
    read -r lines
    lines="${lines:-80}"
    if ! [[ "$lines" =~ ^[0-9]+$ ]] || [ "$lines" -lt 1 ]; then
        ui_warn "行数无效，使用默认 80。"
        lines="80"
    fi

    printf "\n服务: %s\n最近行数: %s\n\n" "$service" "$lines"
    journalctl -u "$service" -n "$lines" --no-pager -o short-iso
}

manage_linux_mirrors_official_run() {
    run_standalone_with_env "modules/standalone/change_linux_mirrors.sh" "SCRIPTKIT_LINUXMIRRORS_SOURCE_INDEX=0"
}

manage_linux_mirrors_github_run() {
    run_standalone_with_env "modules/standalone/change_linux_mirrors.sh" "SCRIPTKIT_LINUXMIRRORS_SOURCE_INDEX=1"
}

manage_linux_mirrors_gitee_run() {
    run_standalone_with_env "modules/standalone/change_linux_mirrors.sh" "SCRIPTKIT_LINUXMIRRORS_SOURCE_INDEX=2"
}

manage_linux_mirrors_gitcode_run() {
    run_standalone_with_env "modules/standalone/change_linux_mirrors.sh" "SCRIPTKIT_LINUXMIRRORS_SOURCE_INDEX=3"
}

manage_linux_mirrors_jsdelivr_run() {
    run_standalone_with_env "modules/standalone/change_linux_mirrors.sh" "SCRIPTKIT_LINUXMIRRORS_SOURCE_INDEX=4"
}

manage_linux_mirrors_edgeone_run() {
    run_standalone_with_env "modules/standalone/change_linux_mirrors.sh" "SCRIPTKIT_LINUXMIRRORS_SOURCE_INDEX=5"
}

manage_services_summary_run() {
    run_standalone_with_env "modules/standalone/manage_services.sh" "SCRIPTKIT_MANAGE_SERVICES_MODE=summary"
}

manage_services_stop_run() {
    run_standalone_with_env "modules/standalone/manage_services.sh" "SCRIPTKIT_MANAGE_SERVICES_MODE=stop"
}

manage_services_disable_run() {
    run_standalone_with_env "modules/standalone/manage_services.sh" "SCRIPTKIT_MANAGE_SERVICES_MODE=disable"
}

manage_services_uninstall_run() {
    run_standalone_with_env "modules/standalone/manage_services.sh" "SCRIPTKIT_MANAGE_SERVICES_MODE=uninstall"
}

add_action "manage_service_status" "查看服务状态" "manage" "manage_service_status"
add_action "manage_service_logs" "查看服务日志" "manage" "manage_service_logs"
add_script "manage_hostname" "主机名管理" "manage" "modules/standalone/manage_hostname.sh"
add_menu "manage_services" "Systemd 服务管理" "manage"
add_action "manage_services_summary" "查看状态摘要" "manage_services" "manage_services_summary_run"
add_action "manage_services_failed" "查看失败服务" "manage_services" "manage_failed_services"
add_action "manage_services_stop" "停止服务" "manage_services" "manage_services_stop_run"
add_action "manage_services_disable" "关闭开机自启" "manage_services" "manage_services_disable_run"
add_action "manage_services_uninstall" "卸载用户安装服务" "manage_services" "manage_services_uninstall_run"
add_menu "manage_linux_mirrors" "LinuxMirror Docker 换源工具" "manage"
add_action "manage_linux_mirrors_official" "Official" "manage_linux_mirrors" "manage_linux_mirrors_official_run"
add_action "manage_linux_mirrors_github" "GitHub raw" "manage_linux_mirrors" "manage_linux_mirrors_github_run"
add_action "manage_linux_mirrors_gitee" "Gitee raw（国内推荐）" "manage_linux_mirrors" "manage_linux_mirrors_gitee_run"
add_action "manage_linux_mirrors_gitcode" "GitCode raw（可能延迟）" "manage_linux_mirrors" "manage_linux_mirrors_gitcode_run"
add_action "manage_linux_mirrors_jsdelivr" "jsDelivr CDN" "manage_linux_mirrors" "manage_linux_mirrors_jsdelivr_run"
add_action "manage_linux_mirrors_edgeone" "EdgeOne" "manage_linux_mirrors" "manage_linux_mirrors_edgeone_run"
add_script "manage_disk" "磁盘管理" "manage" "modules/standalone/manage_disk.sh"
