#!/usr/bin/env bash

set -u

ROOT_MENU="main"
CURRENT_MENU="$ROOT_MENU"
CURRENT_ITEM_PATH=""
SELECT_RESULT=""
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR="$PWD"
MODULE_DIR="${MODULE_DIR:-$SCRIPT_DIR/modules}"
MODULE_CACHE_DIR="${MODULE_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME:-.}/.cache}/scriptkit/modules}"
SCRIPTKIT_RAW_BASE_URL="${SCRIPTKIT_RAW_BASE_URL:-https://raw.githubusercontent.com/LonelyRyF/ScriptKit/main}"
MODULE_BASE_URL="${MODULE_BASE_URL:-$SCRIPTKIT_RAW_BASE_URL/modules}"
MODULE_MANIFEST_URL="${MODULE_MANIFEST_URL:-$MODULE_BASE_URL/modules.list}"

bootstrap_download_file() {
    local url="$1"
    local output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$output" "$url"
    else
        return 1
    fi
}

bootstrap_source() {
    local rel_path="$1"
    local local_path="$MODULE_DIR/$rel_path"
    local cache_path="$MODULE_CACHE_DIR/$rel_path"
    local url="${MODULE_BASE_URL%/}/$rel_path"

    if [ -f "$local_path" ]; then
        source "$local_path"
        return 0
    fi
    if [ -f "$cache_path" ]; then
        source "$cache_path"
        return 0
    fi
    mkdir -p "$MODULE_CACHE_DIR" 2>/dev/null
    bootstrap_download_file "$url" "$cache_path" || return 1
    source "$cache_path"
}

load_runtime() {
    local runtime_local="$MODULE_DIR/runtime.sh"
    local runtime_cache="$MODULE_CACHE_DIR/runtime.sh"
    local runtime_url="${MODULE_BASE_URL%/}/runtime.sh"

    if [ -f "$runtime_local" ]; then
        source "$runtime_local"
        return 0
    fi

    if [ -f "$runtime_cache" ]; then
        source "$runtime_cache"
        return 0
    fi

    mkdir -p "$MODULE_CACHE_DIR" || return 1
    bootstrap_download_file "$runtime_url" "$runtime_cache" || return 1
    source "$runtime_cache"
}

if ! load_runtime; then
    printf '无法加载 ScriptKit runtime。\n' >&2
    exit 1
fi

if ! bootstrap_source "menu_core.sh"; then
    printf '无法加载菜单框架核心。\n' >&2
    exit 1
fi

if ! bootstrap_source "menu_ui.sh"; then
    printf '无法加载菜单框架 UI。\n' >&2
    exit 1
fi

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

define_menus() {
    add_menu "main" "主菜单"
    add_menu "system" "系统信息" "main"
    add_menu "test" "测试工具" "main"
    add_menu "reinstall" "重装系统" "main"
    add_menu "manage" "系统管理" "main"
    add_menu "network" "网络工具" "main"
    add_menu "security" "安全工具" "main"
    add_menu "app" "应用部署" "main"
    add_menu "utility" "实用工具" "main"
    add_menu "scriptkit" "ScriptKit 管理" "utility"
    add_action "scriptkit_status" "查看运行状态" "scriptkit" "show_scriptkit_status"
    add_action "scriptkit_refresh_modules" "刷新远程模块缓存" "scriptkit" "refresh_remote_module_cache"
    add_action "scriptkit_clear_cache" "清理模块缓存" "scriptkit" "clear_module_cache"
}

main() {
    define_menus
    load_modules
    validate_menu_registry
    if [ "${#MENU_WARNINGS[@]}" -gt 0 ]; then
        ui_warn "菜单注册发现 ${#MENU_WARNINGS[@]} 个问题，可在 ScriptKit 管理中查看。" >&2
        sleep 2
    fi
    run_menu
}

main "$@"
