#!/usr/bin/env bash

# ScriptKit self-management module, loaded by load_modules.

add_menu "scriptkit" "ScriptKit 管理" "utility"
add_action "scriptkit_status" "查看运行状态" "scriptkit" "show_scriptkit_status"
add_action "scriptkit_view_log" "查看操作日志" "scriptkit" "show_action_log"
add_action "scriptkit_clear_log" "清理操作日志" "scriptkit" "clear_action_log"
add_action "scriptkit_refresh_modules" "刷新远程模块缓存" "scriptkit" "refresh_remote_module_cache"
add_action "scriptkit_clear_cache" "清理模块缓存" "scriptkit" "clear_module_cache"

show_scriptkit_status() {
    local id type module warning
    local menu_count=0
    local action_count=0
    local script_count=0

    for id in "${!ITEM_TYPES[@]}"; do
        case "$id" in
            __*) continue ;;
        esac
        type="${ITEM_TYPES[$id]:-}"
        case "$type" in
            menu) menu_count=$((menu_count + 1)) ;;
            action) action_count=$((action_count + 1)) ;;
            script) script_count=$((script_count + 1)) ;;
        esac
    done

    scriptkit_draw_current_title "查看运行状态"
    printf "脚本目录: %s\n" "$SCRIPT_DIR"
    printf "本地模块目录: %s\n" "$MODULE_DIR"
    printf "模块缓存目录: %s\n" "$MODULE_CACHE_DIR"
    printf "远程模块地址: %s\n" "$MODULE_BASE_URL"
    printf "远程清单地址: %s\n\n" "$MODULE_MANIFEST_URL"

    printf "菜单: %d  动作: %d  脚本: %d\n\n" "$menu_count" "$action_count" "$script_count"

    printf "%b已加载模块:%b\n" "$BOLD" "$PLAIN"
    if [ "${#LOADED_MODULES[@]}" -eq 0 ]; then
        printf "  无\n"
    else
        for module in "${LOADED_MODULES[@]}"; do
            printf "  %s\n" "$module"
        done
    fi

    printf "\n%b可用命令:%b\n" "$BOLD" "$PLAIN"
    for id in tput curl wget; do
        if command_exists "$id"; then
            printf "  %s: yes\n" "$id"
        else
            printf "  %s: no\n" "$id"
        fi
    done

    printf "\n%b注册检查:%b\n" "$BOLD" "$PLAIN"
    if [ "${#MENU_WARNINGS[@]}" -eq 0 ]; then
        printf "  %b未发现问题%b\n" "$GREEN" "$PLAIN"
    else
        for warning in "${MENU_WARNINGS[@]}"; do
            printf '  '
            ui_warn "$warning"
        done
    fi
}

show_action_log() {
    local line
    local -a recent=()

    scriptkit_draw_current_title "查看操作日志"
    printf "日志文件: %s\n\n" "$SCRIPTKIT_LOG_FILE"

    if [ ! -f "$SCRIPTKIT_LOG_FILE" ]; then
        ui_info "暂无操作记录。"
        return 0
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        recent+=("$line")
        if [ "${#recent[@]}" -gt 20 ]; then
            recent=("${recent[@]:1}")
        fi
    done <"$SCRIPTKIT_LOG_FILE"

    if [ "${#recent[@]}" -eq 0 ]; then
        ui_info "暂无操作记录。"
        return 0
    fi

    printf "%b最近 20 条操作:%b\n\n" "$BOLD" "$PLAIN"
    for line in "${recent[@]}"; do
        printf "  %s\n" "$line"
    done
}

clear_action_log() {
    local line_count=0
    local line

    scriptkit_draw_current_title "清理操作日志"
    printf "日志文件: %s\n" "$SCRIPTKIT_LOG_FILE"

    if [ ! -f "$SCRIPTKIT_LOG_FILE" ]; then
        ui_info "暂无日志文件。"
        return 0
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        line_count=$((line_count + 1))
    done <"$SCRIPTKIT_LOG_FILE"
    printf "记录条数: %s\n\n" "$line_count"

    if yesno_select "确认清理所有操作日志？"; then
        : >"$SCRIPTKIT_LOG_FILE" 2>/dev/null || {
            ui_error "操作日志清理失败。"
            return 1
        }
        ui_ok "操作日志已清理。"
    else
        ui_info "已取消。"
    fi
}

refresh_remote_module_cache() {
    scriptkit_draw_current_title "刷新远程模块缓存"

    if [ -z "$MODULE_BASE_URL" ] || [ -z "$MODULE_MANIFEST_URL" ]; then
        ui_error "未配置远程模块地址。"
        return 1
    fi

    printf "远程清单: %s\n" "$MODULE_MANIFEST_URL"
    printf "缓存目录: %s\n\n" "$MODULE_CACHE_DIR"

    if download_remote_modules; then
        ui_ok "远程模块缓存已刷新。"
        ui_info "当前运行中的菜单不会自动重载，请重新启动 ScriptKit 后生效。"
    else
        ui_error "远程模块缓存刷新失败。"
        return 1
    fi
}

is_safe_cache_dir() {
    local dir="$1"
    local home="${HOME:-}"

    case "$dir" in
        "" | "/" | "." | "..") return 1 ;;
    esac

    if [ -n "$home" ] && { [ "$dir" = "$home" ] || [ "$dir" = "$home/" ]; }; then
        return 1
    fi

    return 0
}

clear_module_cache() {
    scriptkit_draw_current_title "清理模块缓存"
    printf "缓存目录: %s\n\n" "$MODULE_CACHE_DIR"

    if ! is_safe_cache_dir "$MODULE_CACHE_DIR"; then
        ui_error "缓存目录不安全，已拒绝清理。"
        return 1
    fi

    if [ ! -d "$MODULE_CACHE_DIR" ]; then
        ui_info "缓存目录不存在，无需清理。"
        return 0
    fi

    if ! yesno_select "确认清理模块缓存？"; then
        ui_info "已取消清理。"
        return 0
    fi

    if rm -rf -- "$MODULE_CACHE_DIR"; then
        ui_ok "模块缓存已清理。"
    else
        ui_error "模块缓存清理失败。"
        return 1
    fi
}
