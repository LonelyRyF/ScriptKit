#!/usr/bin/env bash
set -u

# Interactive systemd service manager with guarded destructive actions.

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

SERVICES=()
SERVICE_TYPES=()
SERVICE_ACTIVE=()
SERVICE_ENABLED=()
SERVICE_PATHS=()

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_systemctl() {
    if command_exists systemctl; then
        return 0
    fi

    msg_err "未找到 systemctl，此功能仅适用于 systemd 系统"
    return 1
}

service_fragment_path() {
    local service="$1"
    systemctl show "$service" -p FragmentPath --value 2>/dev/null || true
}

service_type_from_path() {
    local path="$1"

    case "$path" in
        /etc/systemd/system/*|/usr/local/lib/systemd/system/*)
            printf '用户安装'
            ;;
        /run/systemd/system/*)
            printf '运行时'
            ;;
        *)
            printf '系统'
            ;;
    esac
}

list_service_units() {
    systemctl list-unit-files --type=service --no-legend --plain 2>/dev/null || \
        systemctl list-unit-files --type=service --no-legend 2>/dev/null
}

collect_services() {
    local filter="$1"
    local filter_lc="${filter,,}"
    local service=""
    local path=""
    local type=""
    local active=""
    local enabled=""

    SERVICES=()
    SERVICE_TYPES=()
    SERVICE_ACTIVE=()
    SERVICE_ENABLED=()
    SERVICE_PATHS=()

    while IFS= read -r service; do
        [ -n "$service" ] || continue
        if [ -n "$filter_lc" ] && [[ "${service,,}" != *"$filter_lc"* ]]; then
            continue
        fi

        path="$(service_fragment_path "$service")"
        type="$(service_type_from_path "$path")"
        active="$(systemctl is-active "$service" 2>/dev/null || printf 'unknown')"
        enabled="$(systemctl is-enabled "$service" 2>/dev/null || printf 'unknown')"

        SERVICES+=("$service")
        SERVICE_TYPES+=("$type")
        SERVICE_ACTIVE+=("$active")
        SERVICE_ENABLED+=("$enabled")
        SERVICE_PATHS+=("${path:--}")
    done < <(list_service_units | awk '{print $1}' | sort)
}

print_services_table() {
    local i=""

    if [ "${#SERVICES[@]}" -eq 0 ]; then
        msg_warn "未找到匹配服务"
        return 1
    fi

    printf "\n%-4s %-42s %-10s %-10s %-10s %s\n" "No." "Service" "类型" "Active" "Enabled" "Unit"
    printf '%s\n' "----------------------------------------------------------------------------------------------------"
    for ((i = 0; i < ${#SERVICES[@]}; i++)); do
        printf "%-4s %-42.42s %-10s %-10s %-10s %s\n" \
            "$((i + 1))" \
            "${SERVICES[$i]}" \
            "${SERVICE_TYPES[$i]}" \
            "${SERVICE_ACTIVE[$i]}" \
            "${SERVICE_ENABLED[$i]}" \
            "${SERVICE_PATHS[$i]}"
    done
}

read_selected_services() {
    local input="$1"
    local n=""
    local index=""
    local -a selected=()

    for n in $input; do
        if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "${#SERVICES[@]}" ]; then
            msg_warn "跳过无效编号: $n" >&2
            continue
        fi
        index=$((n - 1))
        selected+=("${SERVICES[$index]}")
    done

    if [ "${#selected[@]}" -gt 0 ]; then
        printf '%s\n' "${selected[@]}"
    fi
}

show_service_summary() {
    local service="$1"
    local description=""
    local load_state=""
    local active_state=""
    local sub_state=""
    local unit_file_state=""
    local main_pid=""
    local fragment=""

    description="$(systemctl show "$service" -p Description --value 2>/dev/null || true)"
    load_state="$(systemctl show "$service" -p LoadState --value 2>/dev/null || true)"
    active_state="$(systemctl show "$service" -p ActiveState --value 2>/dev/null || true)"
    sub_state="$(systemctl show "$service" -p SubState --value 2>/dev/null || true)"
    unit_file_state="$(systemctl show "$service" -p UnitFileState --value 2>/dev/null || true)"
    main_pid="$(systemctl show "$service" -p MainPID --value 2>/dev/null || true)"
    fragment="$(service_fragment_path "$service")"

    printf "\n%b服务: %s%b\n" "$BOLD" "$service" "$PLAIN"
    printf "  描述: %s\n" "${description:-unknown}"
    printf "  加载: %s\n" "${load_state:-unknown}"
    printf "  运行: %s / %s\n" "${active_state:-unknown}" "${sub_state:-unknown}"
    printf "  自启: %s\n" "${unit_file_state:-unknown}"
    printf "  主进程 PID: %s\n" "${main_pid:-unknown}"
    printf "  Unit 文件: %s\n" "${fragment:--}"
}

confirm_services() {
    local prompt="$1"
    shift
    local service=""

    printf "\n将处理以下服务:\n"
    for service in "$@"; do
        printf "  - %s\n" "$service"
    done

    yesno_select "$prompt"
}

stop_services() {
    local service=""

    require_root_action || return 1
    confirm_services "确认停止这些服务？" "$@" || {
        msg_info "已取消"
        return 0
    }

    for service in "$@"; do
        if systemctl stop "$service" >/dev/null 2>&1; then
            msg_ok "已停止: $service"
        else
            msg_err "停止失败: $service"
        fi
    done
}

disable_services() {
    local service=""

    require_root_action || return 1
    confirm_services "确认关闭这些服务的开机自启？" "$@" || {
        msg_info "已取消"
        return 0
    }

    for service in "$@"; do
        if systemctl disable "$service" >/dev/null 2>&1; then
            msg_ok "已关闭自启: $service"
        else
            msg_err "关闭自启失败: $service"
        fi
    done
}

generate_service_checklist() {
    local service="$1"
    local base="${service%.service}"
    local checklist_dir="${XDG_CACHE_HOME:-${HOME:-.}/.cache}/scriptkit/service_checklists"
    local checklist="${checklist_dir}/${base}.$(date +%Y%m%d%H%M%S).txt"
    local path=""
    local found="0"

    mkdir -p "$checklist_dir" || return 1

    {
        printf '服务: %s\n' "$service"
        printf '生成时间: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        printf 'Unit 文件候选:\n'
        for path in /etc/systemd/system/"$service" /usr/local/lib/systemd/system/"$service" /lib/systemd/system/"$service" /usr/lib/systemd/system/"$service"; do
            [ -e "$path" ] && printf '  %s\n' "$path"
        done

        printf '\n可能相关配置/数据/日志路径:\n'
        for path in /etc/"$base"* /usr/local/etc/"$base"* /var/lib/"$base"* /var/log/"$base"* /opt/"$base"*; do
            if [ -e "$path" ]; then
                printf '  %s\n' "$path"
                found="1"
            fi
        done
        [ "$found" = "0" ] && printf '  未发现常见残留路径\n'

        printf '\n建议:\n'
        printf '  请人工确认后再删除数据目录；如有重要数据请先备份。\n'
    } > "$checklist"

    msg_ok "残留检查清单: $checklist"
}

backup_unit_file() {
    local service="$1"
    local unit_path="$2"
    local backup_dir="${XDG_CACHE_HOME:-${HOME:-.}/.cache}/scriptkit/service_units"
    local backup="${backup_dir}/${service}.$(date +%Y%m%d%H%M%S)"

    mkdir -p "$backup_dir" || return 1
    cp -a "$unit_path" "$backup" || return 1
    msg_ok "Unit 文件已备份到: $backup"
}

uninstall_user_services() {
    local service=""
    local path=""
    local type=""

    require_root_action || return 1
    confirm_services "确认卸载这些用户安装服务？仅会删除 /etc 或 /usr/local 下的 unit 文件。" "$@" || {
        msg_info "已取消"
        return 0
    }

    for service in "$@"; do
        path="$(service_fragment_path "$service")"
        type="$(service_type_from_path "$path")"
        if [ "$type" != "用户安装" ]; then
            msg_warn "跳过系统服务: $service"
            continue
        fi
        if [ ! -e "$path" ]; then
            msg_warn "找不到 unit 文件: $service"
            generate_service_checklist "$service"
            continue
        fi

        systemctl stop "$service" >/dev/null 2>&1 || true
        systemctl disable "$service" >/dev/null 2>&1 || true
        backup_unit_file "$service" "$path" || msg_warn "Unit 文件备份失败: $path"
        rm -f "$path" || {
            msg_err "删除 unit 文件失败: $path"
            continue
        }
        systemctl daemon-reload >/dev/null 2>&1 || true
        msg_ok "已卸载用户安装服务: $service"
        generate_service_checklist "$service"
    done
}

operate_services() {
    local selection=""
    local action="$1"
    local service=""
    local -a selected=()

    printf '\n%b' "$(msg_prompt "输入" "请输入要操作的服务编号，多个用空格分隔，留空返回: ")"
    read -r selection
    [ -n "$selection" ] || return 0

    while IFS= read -r service; do
        [ -n "$service" ] && selected+=("$service")
    done < <(read_selected_services "$selection")

    if [ "${#selected[@]}" -eq 0 ]; then
        msg_warn "没有有效服务"
        return 1
    fi

    case "$action" in
        summary)
            for service in "${selected[@]}"; do
                show_service_summary "$service"
            done
            ;;
        stop) stop_services "${selected[@]}" ;;
        disable) disable_services "${selected[@]}" ;;
        uninstall) uninstall_user_services "${selected[@]}" ;;
        prompt)
            printf "\n支持的操作:\n"
            printf "  1) 查看状态摘要\n"
            printf "  2) 停止服务\n"
            printf "  3) 关闭开机自启\n"
            printf "  4) 卸载用户安装服务\n"
            printf '%b' "$(msg_prompt "输入" "选择 [1-4]: ")"
            read -r action

            case "$action" in
                1)
                    for service in "${selected[@]}"; do
                        show_service_summary "$service"
                    done
                    ;;
                2) stop_services "${selected[@]}" ;;
                3) disable_services "${selected[@]}" ;;
                4) uninstall_user_services "${selected[@]}" ;;
                *) msg_warn "无效选择" ;;
            esac
            ;;
        *) msg_warn "无效选择" ;;
    esac
}

run_service_operation() {
    local action="$1"
    local filter=""

    require_systemctl || exit 1

    while true; do
        draw_current_title "Systemd 服务管理"
        printf '%b' "$(msg_prompt "输入" "输入关键词过滤服务（回车列全部，q 退出）: ")"
        read -r filter
        case "$filter" in
            q|Q) return 0 ;;
        esac

        msg_info "正在收集服务列表..."
        collect_services "$filter"
        print_services_table || {
            printf '\n%b' "$(msg_prompt "提示" "按 Enter 继续...")"
            read -r _
            clear 2>/dev/null || true
            continue
        }
        operate_services "$action"

        printf '\n%b' "$(msg_prompt "提示" "按 Enter 继续...")"
        read -r _
        clear 2>/dev/null || true
    done
}

main() {
    case "${SCRIPTKIT_MANAGE_SERVICES_MODE:-}" in
        summary)
            run_service_operation "summary"
            ;;
        stop)
            run_service_operation "stop"
            ;;
        disable)
            run_service_operation "disable"
            ;;
        uninstall)
            run_service_operation "uninstall"
            ;;
        *)
            run_service_operation "prompt"
            ;;
    esac
}

main
