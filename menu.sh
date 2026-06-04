#!/usr/bin/env bash

set -u

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
BOLD='\033[1m'
ITALIC='\033[3m'
PLAIN='\033[0m'

ROOT_MENU="main"
CURRENT_MENU="$ROOT_MENU"
SELECT_RESULT=""
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR="$PWD"
MODULE_DIR="${MODULE_DIR:-$SCRIPT_DIR/modules}"
MODULE_CACHE_DIR="${MODULE_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME:-.}/.cache}/scriptkit/modules}"
SCRIPTKIT_RAW_BASE_URL="${SCRIPTKIT_RAW_BASE_URL:-https://raw.githubusercontent.com/LonelyRyF/ScriptKit/main}"
MODULE_BASE_URL="${MODULE_BASE_URL:-$SCRIPTKIT_RAW_BASE_URL/modules}"
MODULE_MANIFEST_URL="${MODULE_MANIFEST_URL:-$MODULE_BASE_URL/modules.list}"

declare -A MENU_TITLES=()
declare -A MENU_CHILDREN=()
declare -A MENU_PARENTS=()
declare -A ITEM_TITLES=()
declare -A ITEM_TYPES=()
declare -A ITEM_TARGETS=()

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

can_use_tput_menu() {
    command_exists tput && [ -t 0 ] && [ -t 1 ] && tput lines >/dev/null 2>&1 && tput cup 0 0 >/dev/null 2>&1
}

add_menu() {
    local id="$1"
    local title="$2"
    local parent="${3:-}"

    MENU_TITLES["$id"]="$title"
    ITEM_TITLES["$id"]="$title"
    ITEM_TYPES["$id"]="menu"
    ITEM_TARGETS["$id"]="$id"

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

    ITEM_TITLES["$id"]="$title"
    ITEM_TYPES["$id"]="action"
    ITEM_TARGETS["$id"]="$handler"
    MENU_CHILDREN["$parent"]="${MENU_CHILDREN[$parent]:-} $id"
}

add_script() {
    local id="$1"
    local title="$2"
    local parent="$3"
    local script_path="$4"

    ITEM_TITLES["$id"]="$title"
    ITEM_TYPES["$id"]="script"
    ITEM_TARGETS["$id"]="$script_path"
    MENU_CHILDREN["$parent"]="${MENU_CHILDREN[$parent]:-} $id"
}

pause_screen() {
    printf "\n%s" "按 Enter 返回菜单..."
    read -r _
}

cleanup() {
    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true
    printf "\n%b操作已取消。%b\n" "$RED" "$PLAIN"
    exit 130
}

format_item_label() {
    local id="$1"
    local type="${ITEM_TYPES[$id]:-}"
    local title="${ITEM_TITLES[$id]:-$id}"

    case "$type" in
        menu) printf '%b[+]%b %s' "$GREEN" "$PLAIN" "$title" ;;
        action) printf '%b[*]%b %s' "$YELLOW" "$PLAIN" "$title" ;;
        script) printf '%b[>]%b %s' "$YELLOW" "$PLAIN" "$title" ;;
        back) printf '%b[<]%b %s' "$CYAN" "$PLAIN" "$title" ;;
        exit) printf '%b[x]%b %s' "$RED" "$PLAIN" "$title" ;;
        *) printf '%s' "$title" ;;
    esac
}

format_item_tip() {
    local id="$1"
    local type="${ITEM_TYPES[$id]:-}"
    local title="${ITEM_TITLES[$id]:-$id}"

    case "$type" in
        menu) printf '回车进入%s菜单' "$title" ;;
        action) printf '回车执行%s' "$title" ;;
        script) printf '回车运行%s' "$title" ;;
        back) printf '回车返回上级菜单' ;;
        exit) printf '回车退出' ;;
        *) printf '回车确认' ;;
    esac
}

draw_title_bar() {
    local title="$1"
    printf "%b== %s ========================================%b\n\n" "$BOLD" "$title" "$PLAIN"
}

interactive_select_list() {
    SELECT_RESULT=""
    local title="$1"
    shift
    local -a values=("$@")
    local selected=0
    local start=0
    local page_size

    update_page_size() {
        page_size=$(($(tput lines 2>/dev/null || printf '20') - 4))
        [ "$page_size" -lt 5 ] && page_size=5
    }

    keep_selection_visible() {
        if [ "$selected" -lt "$start" ]; then
            start="$selected"
        elif [ "$selected" -ge $((start + page_size)) ]; then
            start=$((selected - page_size + 1))
        fi
        [ "$start" -lt 0 ] && start=0
    }

    read_key() {
        local key
        IFS= read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -rsn2 key
        fi
        printf '%s' "$key"
    }

    draw_menu() {
        local i end label id selected_id tip
        tput cup 0 0 2>/dev/null || true
        tput ed 2>/dev/null || true
        draw_title_bar "$title"

        end=$((start + page_size - 1))
        [ "$end" -ge "${#values[@]}" ] && end=$((${#values[@]} - 1))

        for ((i = start; i <= end; i++)); do
            id="${values[$i]}"
            label="$(format_item_label "$id")"
            if [ "$i" -eq "$selected" ]; then
                printf "%b\n" "   ${BLUE}${BOLD}>${PLAIN} ${BOLD}${label}${PLAIN}"
            else
                printf '     %b\n' "$label"
            fi
        done

        selected_id="${values[$selected]}"
        tip="$(format_item_tip "$selected_id")"
        printf "\n%b------------------------------------------------%b\n" "$BOLD" "$PLAIN"
        printf "%bEnter%b %s  %bMove%b Up/Down j/k  %bQuit%b q\n" "$GREEN" "$PLAIN" "$tip" "$CYAN" "$PLAIN" "$RED" "$PLAIN"
        printf "%bPowered by %b%s%b\n" "$ITALIC" "$CYAN" "rainyfall.dev" "$PLAIN"

    }

    visible_end() {
        local end=$((start + page_size - 1))
        [ "$end" -ge "${#values[@]}" ] && end=$((${#values[@]} - 1))
        printf '%s' "$end"
    }

    draw_item_line() {
        local index="$1"
        local line=$((2 + index - start))
        local id="${values[$index]}"
        local label

        label="$(format_item_label "$id")"
        tput cup "$line" 0 2>/dev/null || true
        tput el 2>/dev/null || true
        if [ "$index" -eq "$selected" ]; then
            printf "%b" "   ${BLUE}${BOLD}>${PLAIN} ${BOLD}${label}${PLAIN}"
        else
            printf '     %b' "$label"
        fi
    }

    draw_footer() {
        local end footer_line selected_id tip
        end="$(visible_end)"
        footer_line=$((2 + end - start + 2))
        selected_id="${values[$selected]}"
        tip="$(format_item_tip "$selected_id")"

        tput cup "$footer_line" 0 2>/dev/null || true
        tput el 2>/dev/null || true
        printf "%b------------------------------------------------%b" "$BOLD" "$PLAIN"
        tput cup "$((footer_line + 1))" 0 2>/dev/null || true
        tput el 2>/dev/null || true
        printf "%bEnter%b %s  %bMove%b Up/Down j/k  %bQuit%b q" "$GREEN" "$PLAIN" "$tip" "$CYAN" "$PLAIN" "$RED" "$PLAIN"
        tput cup "$((footer_line + 2))" 0 2>/dev/null || true
        tput el 2>/dev/null || true
        printf "%bPowered by %b%s%b" "$ITALIC" "$CYAN" "rainyfall.dev" "$PLAIN"

    }

    redraw_changed_selection() {
        local old_selected="$1"
        draw_item_line "$old_selected"
        draw_item_line "$selected"
        draw_footer
    }

    handle_resize() {
        update_page_size
        keep_selection_visible
        draw_menu
    }

    update_page_size

    tput smcup 2>/dev/null || true
    tput civis 2>/dev/null || true
    trap cleanup INT TERM
    trap handle_resize WINCH

    draw_menu
    while true; do
        local key
        local old_selected="$selected"
        local old_start="$start"
        key=$(read_key)
        case "$key" in
            "[A" | "w" | "W" | "k" | "K")
                if [ "$selected" -gt 0 ]; then
                    selected=$((selected - 1))
                    [ "$selected" -lt "$start" ] && start=$((start - 1))
                fi
                ;;
            "[B" | "s" | "S" | "j" | "J")
                if [ "$selected" -lt $((${#values[@]} - 1)) ]; then
                    selected=$((selected + 1))
                    [ "$selected" -ge $((start + page_size)) ] && start=$((start + 1))
                fi
                ;;
            "")
                SELECT_RESULT="${values[$selected]}"
                break
                ;;
            "q" | "Q")
                SELECT_RESULT="__exit"
                break
                ;;
        esac
        if [ "$old_selected" -ne "$selected" ] || [ "$old_start" -ne "$start" ]; then
            if [ "$old_start" -eq "$start" ]; then
                redraw_changed_selection "$old_selected"
            else
                draw_menu
            fi
        fi
    done

    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true
    trap - INT TERM WINCH
}

plain_select_list() {
    SELECT_RESULT=""
    local title="$1"
    shift
    local -a values=("$@")
    local input id i

    while true; do
        clear 2>/dev/null || true
        draw_title_bar "$title"
        for ((i = 0; i < ${#values[@]}; i++)); do
            id="${values[$i]}"
            printf '    %02d  %b\n' "$((i + 1))" "$(format_item_label "$id")"
        done
        printf '\n%b------------------------------------------------%b\n' "$BOLD" "$PLAIN"
        printf '输入数字并回车确认，输入 q 退出\n'
        printf '%bPowered by %b%s%b\n\n' "$ITALIC" "$CYAN" "rainyfall.dev" "$PLAIN"
        printf '请选择 [1-%d]: ' "${#values[@]}"
        read -r input
        if [[ "$input" =~ ^[Qq]$ ]]; then
            SELECT_RESULT="__exit"
            return
        fi
        if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le "${#values[@]}" ]; then
            SELECT_RESULT="${values[$((input - 1))]}"
            return
        fi
        printf "%b输入无效。%b\n" "$RED" "$PLAIN"
        sleep 1
    done
}

select_list() {
    if can_use_tput_menu; then
        interactive_select_list "$@"
    else
        plain_select_list "$@"
    fi
}

run_action() {
    local handler="$1"

    clear 2>/dev/null || true
    if declare -F "$handler" >/dev/null 2>&1; then
        "$handler"
    else
        printf "%b[ERROR]%b 处理函数未找到: %s\n" "$RED" "$PLAIN" "$handler"
    fi
    pause_screen
}

run_script() {
    local script_path="$1"
    local script_file

    case "$script_path" in
        /*) script_file="$script_path" ;;
        *) script_file="$SCRIPT_DIR/$script_path" ;;
    esac

    # Fallback to cache directory for remote-downloaded scripts
    if [ ! -f "$script_file" ] && [ -f "$MODULE_CACHE_DIR/$script_path" ]; then
        script_file="$MODULE_CACHE_DIR/$script_path"
    fi

    # Try stripping "modules/" prefix for cache lookup
    if [ ! -f "$script_file" ]; then
        local stripped="${script_path#modules/}"
        if [ -f "$MODULE_CACHE_DIR/$stripped" ]; then
            script_file="$MODULE_CACHE_DIR/$stripped"
        fi
    fi

    clear 2>/dev/null || true
    if [ -f "$script_file" ]; then
        bash "$script_file"
    else
        printf "%b[ERROR]%b 脚本未找到: %s\n" "$RED" "$PLAIN" "$script_path"
    fi
    pause_screen
}

download_file() {
    local url="$1"
    local output="$2"

    if command_exists curl; then
        curl -fsSL "$url" -o "$output"
    elif command_exists wget; then
        wget -qO "$output" "$url"
    else
        return 1
    fi
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
    local loaded="false"

    shopt -s nullglob

    if [ -d "$MODULE_DIR" ]; then
        for module in "$MODULE_DIR"/*.sh; do
            # Source modules register menus/actions by calling add_menu/add_action/add_script.
            source "$module"
            loaded="true"
        done
    fi

    if [ "$loaded" = "false" ] && [ -n "$MODULE_BASE_URL" ]; then
        if download_remote_modules; then
            for module in "$MODULE_CACHE_DIR"/*.sh; do
                source "$module"
                loaded="true"
            done
        else
            printf "%b[WARN]%b 远程模块下载失败，菜单可能不完整。\n" "$YELLOW" "$PLAIN" >&2
            sleep 2
        fi
    fi

    shopt -u nullglob
}

show_menu() {
    local menu_id="$1"
    local title="${MENU_TITLES[$menu_id]:-$menu_id}"
    local -a items=()
    local child selected type target

    for child in ${MENU_CHILDREN[$menu_id]:-}; do
        items+=("$child")
    done

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
            run_action "$target"
            ;;
        script)
            run_script "$target"
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
}

main() {
    define_menus
    load_modules
    run_menu
}

main "$@"
