#!/usr/bin/env bash

# Phase 2 refactored: registry, module loading, dispatch, menu loop
# Sourced by menu.sh after runtime.sh

set -u

declare -gA MENU_TITLES=()
declare -gA MENU_CHILDREN=()
declare -gA MENU_PARENTS=()
declare -gA ITEM_TITLES=()
declare -gA ITEM_TYPES=()
declare -gA ITEM_TARGETS=()
declare -gA ITEM_PARENTS=()
declare -ga MENU_WARNINGS=()
declare -ga LOADED_MODULES=()

record_menu_warning() {
    MENU_WARNINGS+=("$1")
}

add_menu() {
    local id="$1"
    local title="$2"
    local parent="${3:-}"

    if [ -n "${ITEM_TYPES[$id]:-}" ]; then
        record_menu_warning "重复菜单项 ID: $id"
    fi

    MENU_TITLES["$id"]="$title"
    ITEM_TITLES["$id"]="$title"
    ITEM_TYPES["$id"]="menu"
    ITEM_TARGETS["$id"]="$id"
    ITEM_PARENTS["$id"]="$parent"

    if [ -n "$parent" ]; then
        MENU_CHILDREN["$parent"]="${MENU_CHILDREN[$parent]:-} $id"
        MENU_PARENTS["$id"]="$parent"
    fi
}

add_action() {
    local id="$1"
    local title="$2"
    local parent="$3"
    local handler="$4"

    if [ -n "${ITEM_TYPES[$id]:-}" ]; then
        record_menu_warning "重复菜单项 ID: $id"
    fi

    ITEM_TITLES["$id"]="$title"
    ITEM_TYPES["$id"]="action"
    ITEM_TARGETS["$id"]="$handler"
    ITEM_PARENTS["$id"]="$parent"
    MENU_CHILDREN["$parent"]="${MENU_CHILDREN[$parent]:-} $id"
}

add_script() {
    local id="$1"
    local title="$2"
    local parent="$3"
    local script_path="$4"

    if [ -n "${ITEM_TYPES[$id]:-}" ]; then
        record_menu_warning "重复菜单项 ID: $id"
    fi

    ITEM_TITLES["$id"]="$title"
    ITEM_TYPES["$id"]="script"
    ITEM_TARGETS["$id"]="$script_path"
    ITEM_PARENTS["$id"]="$parent"
    MENU_CHILDREN["$parent"]="${MENU_CHILDREN[$parent]:-} $id"
}

build_menu_path() {
    local menu_id="$1"
    local current="$menu_id"
    local path=""
    local title
    local guard=0

    while [ -n "$current" ] && [ "$guard" -lt 50 ]; do
        title="${MENU_TITLES[$current]:-$current}"
        if [ -n "$path" ]; then
            path="$title / $path"
        else
            path="$title"
        fi

        [ "$current" = "$ROOT_MENU" ] && break
        current="${MENU_PARENTS[$current]:-}"
        guard=$((guard + 1))
    done

    printf '%s' "$path"
}

build_item_path() {
    local item_id="$1"
    local parent="${ITEM_PARENTS[$item_id]:-}"
    local item_title="${ITEM_TITLES[$item_id]:-$item_id}"

    if [ -n "$parent" ]; then
        printf '%s / %s' "$(build_menu_path "$parent")" "$item_title"
    else
        printf '%s' "$item_title"
    fi
}

run_action() {
    local item_id="$1"
    local handler="$2"
    local item_path="$(build_item_path "$item_id")"
    local menu_id="${ITEM_PARENTS[$item_id]:-$CURRENT_MENU}"
    local menu_path="$(build_menu_path "$menu_id")"
    local previous_menu_path="${SCRIPTKIT_CURRENT_MENU_PATH:-}"
    local previous_item_path="${SCRIPTKIT_CURRENT_ITEM_PATH:-}"

    clear 2>/dev/null || true
    SCRIPTKIT_CURRENT_MENU_PATH="$menu_path"
    SCRIPTKIT_CURRENT_ITEM_PATH="$item_path"
    CURRENT_ITEM_PATH="$item_path"
    if declare -F "$handler" >/dev/null 2>&1; then
        "$handler"
    else
        ui_error "处理函数未找到: $handler"
    fi
    SCRIPTKIT_CURRENT_MENU_PATH="$previous_menu_path"
    SCRIPTKIT_CURRENT_ITEM_PATH="$previous_item_path"
    CURRENT_ITEM_PATH="$previous_item_path"
    pause_screen
}

resolve_script_file() {
    local script_path="$1"
    local script_file

    case "$script_path" in
        /*) script_file="$script_path" ;;
        *) script_file="$SCRIPT_DIR/$script_path" ;;
    esac

    if [ ! -f "$script_file" ] && [ -f "$MODULE_CACHE_DIR/$script_path" ]; then
        script_file="$MODULE_CACHE_DIR/$script_path"
    fi

    if [ ! -f "$script_file" ]; then
        local stripped="${script_path#modules/}"
        if [ -f "$MODULE_CACHE_DIR/$stripped" ]; then
            script_file="$MODULE_CACHE_DIR/$stripped"
        fi
    fi

    if [ -f "$script_file" ]; then
        printf '%s' "$script_file"
        return 0
    fi

    return 1
}

run_standalone_with_env() {
    local script_path="$1"
    shift
    local script_file=""
    local -a env_vars=()

    if ! script_file="$(resolve_script_file "$script_path")"; then
        ui_error "脚本未找到: $script_path"
        return 1
    fi

    env_vars+=("SCRIPTKIT_CURRENT_MENU_PATH=${SCRIPTKIT_CURRENT_MENU_PATH:-}")
    env_vars+=("SCRIPTKIT_CURRENT_ITEM_PATH=${SCRIPTKIT_CURRENT_ITEM_PATH:-}")
    while [ "$#" -gt 0 ]; do
        env_vars+=("$1")
        shift
    done

    env "${env_vars[@]}" bash "$script_file"
}

run_script() {
    local item_id="$1"
    local script_path="$2"
    local script_file=""
    local item_path="$(build_item_path "$item_id")"
    local menu_id="${ITEM_PARENTS[$item_id]:-$CURRENT_MENU}"
    local menu_path="$(build_menu_path "$menu_id")"

    clear 2>/dev/null || true
    if script_file="$(resolve_script_file "$script_path")"; then
        SCRIPTKIT_CURRENT_MENU_PATH="$menu_path" SCRIPTKIT_CURRENT_ITEM_PATH="$item_path" bash "$script_file"
    else
        ui_error "脚本未找到: $script_path"
    fi
    pause_screen
}

is_safe_module_path() {
    local path="$1"

    case "$path" in
        "" | /* | *..* | *'//'*) return 1 ;;
        *) return 0 ;;
    esac
}

download_remote_modules() {
    local manifest_file="$MODULE_CACHE_DIR/modules.list"
    local module_path module_url module_file module_parent

    [ -n "$MODULE_MANIFEST_URL" ] || return 1
    mkdir -p "$MODULE_CACHE_DIR" || return 1
    download_file "$MODULE_MANIFEST_URL" "$manifest_file" || return 1

    while IFS= read -r module_path || [ -n "$module_path" ]; do
        module_path="${module_path%%#*}"
        module_path="${module_path//$'\r'/}"
        module_path="${module_path#${module_path%%[![:space:]]*}}"
        module_path="${module_path%${module_path##*[![:space:]]}}"

        is_safe_module_path "$module_path" || continue

        module_url="${MODULE_BASE_URL%/}/$module_path"
        module_file="$MODULE_CACHE_DIR/$module_path"
        module_parent="$(dirname -- "$module_file")"
        mkdir -p "$module_parent" || return 1
        download_file "$module_url" "$module_file" || return 1
    done <"$manifest_file"
}

load_modules() {
    local module
    local name=""
    local loaded="false"

    shopt -s nullglob

    if [ -d "$MODULE_DIR" ]; then
        for module in "$MODULE_DIR"/*.sh; do
            name="$(basename -- "$module")"
            case "$name" in
                lib.sh | runtime.sh | menu_core.sh | menu_ui.sh) continue ;;
            esac
            source "$module"
            LOADED_MODULES+=("$module")
            loaded="true"
        done
    fi

    if [ "$loaded" = "false" ] && [ -n "$MODULE_BASE_URL" ]; then
        if download_remote_modules; then
            for module in "$MODULE_CACHE_DIR"/*.sh; do
                name="$(basename -- "$module")"
                case "$name" in
                    lib.sh | runtime.sh | menu_core.sh | menu_ui.sh) continue ;;
                esac
                source "$module"
                LOADED_MODULES+=("$module")
                loaded="true"
            done
        else
            ui_warn "远程模块下载失败，菜单可能不完整。" >&2
            sleep 2
        fi
    fi

    shopt -u nullglob
}

validate_menu_registry() {
    local id type parent target

    for id in "${!ITEM_TYPES[@]}"; do
        case "$id" in
            __*) continue ;;
        esac

        type="${ITEM_TYPES[$id]:-}"
        parent="${ITEM_PARENTS[$id]:-}"
        target="${ITEM_TARGETS[$id]:-}"

        if [ -n "$parent" ] && [ -z "${MENU_TITLES[$parent]:-}" ]; then
            record_menu_warning "菜单项 $id 的父菜单不存在: $parent"
        fi

        case "$type" in
            action)
                if [ -z "$target" ] || ! declare -F "$target" >/dev/null 2>&1; then
                    record_menu_warning "菜单项 $id 的处理函数不存在: ${target:-<empty>}"
                fi
                ;;
            script)
                if [ -z "$target" ] || ! resolve_script_file "$target" >/dev/null 2>&1; then
                    record_menu_warning "菜单项 $id 的脚本不存在: ${target:-<empty>}"
                fi
                ;;
            menu)
                ;;
            *)
                record_menu_warning "菜单项 $id 的类型未知: ${type:-<empty>}"
                ;;
        esac
    done
}

show_menu() {
    local menu_id="$1"
    local title
    local -a items=()
    local child selected type target

    title="$(build_menu_path "$menu_id")"

    for child in ${MENU_CHILDREN[$menu_id]:-}; do
        items+=("$child")
    done

    if [ "${#items[@]}" -eq 0 ]; then
        ITEM_TITLES["__empty"]="暂无可用功能"
        ITEM_TYPES["__empty"]="empty"
        ITEM_TARGETS["__empty"]=""
        items+=("__empty")
    fi

    if [ "$menu_id" != "$ROOT_MENU" ]; then
        ITEM_TITLES["__back"]="返回"
        ITEM_TYPES["__back"]="back"
        items+=("__back")
    fi

    ITEM_TITLES["__exit"]="退出"
    ITEM_TYPES["__exit"]="exit"
    items+=("__exit")

    select_list "$title" "${items[@]}"
    selected="$SELECT_RESULT"
    type="${ITEM_TYPES[$selected]:-}"
    target="${ITEM_TARGETS[$selected]:-}"

    case "$type" in
        menu)
            CURRENT_MENU="$target"
            ;;
        action)
            run_action "$selected" "$target"
            ;;
        script)
            run_script "$selected" "$target"
            ;;
        back)
            CURRENT_MENU="${MENU_PARENTS[$menu_id]:-$ROOT_MENU}"
            ;;
        exit)
            clear 2>/dev/null || true
            exit 0
            ;;
    esac
}

run_menu() {
    while true; do
        show_menu "$CURRENT_MENU"
    done
}
