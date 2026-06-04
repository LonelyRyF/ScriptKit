#!/usr/bin/env bash

# Read-only system management helpers.

manage_require_systemctl() {
    if command_exists systemctl; then
        return 0
    fi

    printf "%b[ERROR]%b 未找到 systemctl。\n" "$RED" "$PLAIN"
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
    printf "请输入服务名（例如 ssh、nginx、docker）: "
    read -r service
    if [ -z "$service" ]; then
        printf "%b[WARN]%b 服务名不能为空。\n" "$YELLOW" "$PLAIN"
        return 1
    fi

    printf "\n%b== 服务状态: %s ========================================%b\n\n" "$BOLD" "$service" "$PLAIN"
    description="$(systemctl show "$service" -p Description --value 2>/dev/null || true)"
    load_state="$(systemctl show "$service" -p LoadState --value 2>/dev/null || true)"
    active_state="$(systemctl show "$service" -p ActiveState --value 2>/dev/null || true)"
    sub_state="$(systemctl show "$service" -p SubState --value 2>/dev/null || true)"
    unit_file_state="$(systemctl show "$service" -p UnitFileState --value 2>/dev/null || true)"
    main_pid="$(systemctl show "$service" -p MainPID --value 2>/dev/null || true)"

    if [ -z "$load_state" ] || [ "$load_state" = "not-found" ]; then
        printf "%b[ERROR]%b 服务不存在或无法读取: %s\n" "$RED" "$PLAIN" "$service"
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
    printf "%b== 失败服务 ========================================%b\n\n" "$BOLD" "$PLAIN"

    failed_output="$(systemctl --failed --no-legend --plain 2>/dev/null)" || {
        printf "%b[ERROR]%b 读取失败服务列表失败。\n" "$RED" "$PLAIN"
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
        printf "%b[ERROR]%b 未找到 journalctl。\n" "$RED" "$PLAIN"
        return 1
    fi

    printf "请输入服务名（例如 ssh、nginx、docker）: "
    read -r service
    if [ -z "$service" ]; then
        printf "%b[WARN]%b 服务名不能为空。\n" "$YELLOW" "$PLAIN"
        return 1
    fi

    printf "显示最近多少行日志（默认 80）: "
    read -r lines
    lines="${lines:-80}"
    if ! [[ "$lines" =~ ^[0-9]+$ ]] || [ "$lines" -lt 1 ]; then
        printf "%b[WARN]%b 行数无效，使用默认 80。\n" "$YELLOW" "$PLAIN"
        lines="80"
    fi

    printf "\n%b== 服务日志: %s 最近 %s 行 ========================================%b\n\n" "$BOLD" "$service" "$lines" "$PLAIN"
    journalctl -u "$service" -n "$lines" --no-pager -o short-iso
}

add_action "manage_service_status" "查看服务状态" "manage" "manage_service_status"
add_action "manage_failed_services" "查看失败服务" "manage" "manage_failed_services"
add_action "manage_service_logs" "查看服务日志" "manage" "manage_service_logs"
add_script "manage_hostname" "主机名管理" "manage" "modules/standalone/manage_hostname.sh"
add_script "manage_services" "Systemd 服务管理" "manage" "modules/standalone/manage_services.sh"
