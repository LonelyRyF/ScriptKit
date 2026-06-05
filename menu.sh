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

define_menus() {
    add_menu "main" "主菜单"
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
