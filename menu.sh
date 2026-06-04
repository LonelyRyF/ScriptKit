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
BG_BLUE='\033[1;44m'
BG_GREEN='\033[1;42m'
BG_YELLOW='\033[1;43m'
BG_RED='\033[1;41m'

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
declare -A ITEM_PARENTS=()
declare -a MENU_WARNINGS=()
declare -a LOADED_MODULES=()

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

ui_label() {
    local color="$1"
    local label="$2"
    printf '%b %s %b' "$color" "$label" "$PLAIN"
}

ui_message() {
    local bg="$1"
    local label="$2"
    local fg="$3"
    local message="$4"
    printf '%b %s %b %b%s%b\n' "$bg" "$label" "$PLAIN" "$fg" "$message" "$PLAIN"
}

ui_info() { ui_message "$BG_BLUE" "提示" "$CYAN" "$1"; }
ui_ok() { ui_message "$BG_GREEN" "完成" "$GREEN" "$1"; }
ui_warn() { ui_message "$BG_YELLOW" "警告" "$YELLOW" "$1"; }
ui_error() { ui_message "$BG_RED" "错误" "$RED" "$1"; }
ui_cancel() { ui_message "$BG_BLUE" "提示" "$RED" "$1"; }

ui_prompt() {
    local label="$1"
    local message="$2"
    printf '%b %s %b %s' "$BG_BLUE" "$label" "$PLAIN" "$message"
}

record_menu_warning() {
    MENU_WARNINGS+=("$1")
}

can_use_tput_menu() {
    command_exists tput && [ -t 0 ] && [ -t 1 ] && tput lines >/dev/null 2>&1 && tput cup 0 0 >/dev/null 2>&1
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

pause_screen() {
    printf '\n%b' "$(ui_prompt "提示" "按 Enter 返回菜单...")"
    read -r _
}

yesno_select() {
    local prompt="$1"
    local default="${2:-n}"
    local prompt_title=""
    local -a values=()

    ITEM_TITLES["__yes"]="是"
    ITEM_TYPES["__yes"]="choice"
    ITEM_TARGETS["__yes"]=""
    ITEM_TITLES["__no"]="否"
    ITEM_TYPES["__no"]="choice"
    ITEM_TARGETS["__no"]=""

    if [ "$default" = "y" ]; then
        values=("__yes" "__no")
    else
        values=("__no" "__yes")
    fi

    prompt_title="$(ui_prompt "确认" "$prompt")"
    select_list "$prompt_title" "${values[@]}"
    [ "$SELECT_RESULT" = "__yes" ]
}

cleanup() {
    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true
    printf '\n'
    ui_cancel "操作已取消"
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
        choice) printf '%b[ ]%b %s' "$CYAN" "$PLAIN" "$title" ;;
        empty) printf '%b[-]%b %s' "$YELLOW" "$PLAIN" "$title" ;;
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
        choice) printf '回车选择%s' "$title" ;;
        empty) printf '当前菜单暂无可用功能' ;;
        back) printf '回车返回上级菜单' ;;
        exit) printf '回车退出' ;;
        *) printf '回车确认' ;;
    esac
}

draw_title_bar() {
    local title="$1"
    printf "%b== %s ========================================%b\n\n" "$BOLD" "$title" "$PLAIN"
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

item_matches_filter() {
    local id="$1"
    local filter="$2"
    local title="${ITEM_TITLES[$id]:-$id}"
    local haystack="${title} ${id}"

    [ -z "$filter" ] && return 0
    [[ "${haystack,,}" == *"${filter,,}"* ]]
}

interactive_select_list() {
    SELECT_RESULT=""
    local title="$1"
    shift
    local -a all_values=("$@")
    local -a values=("${all_values[@]}")
    local selected=0
    local start=0
    local page_size
    local filter_text=""

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

    value_exists() {
        local wanted="$1"
        local value
        for value in "${values[@]}"; do
            [ "$value" = "$wanted" ] && return 0
        done
        return 1
    }

    apply_filter() {
        local value type
        local -a filtered=()
        local -a fixed=()

        if [ -z "$filter_text" ]; then
            values=("${all_values[@]}")
        else
            for value in "${all_values[@]}"; do
                type="${ITEM_TYPES[$value]:-}"
                case "$type" in
                    back | exit)
                        fixed+=("$value")
                        ;;
                    *)
                        if item_matches_filter "$value" "$filter_text"; then
                            filtered+=("$value")
                        fi
                        ;;
                esac
            done

            if [ "${#filtered[@]}" -eq 0 ]; then
                ITEM_TITLES["__no_match"]="没有匹配结果"
                ITEM_TYPES["__no_match"]="empty"
                ITEM_TARGETS["__no_match"]=""
                filtered+=("__no_match")
            fi

            values=("${filtered[@]}" "${fixed[@]}")
        fi

        if [ "$selected" -ge "${#values[@]}" ]; then
            selected=$((${#values[@]} - 1))
        fi
        [ "$selected" -lt 0 ] && selected=0
        keep_selection_visible
    }

    read_key() {
        local key next
        IFS= read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            key=""
            while IFS= read -rsn1 -t 0.05 next; do
                key+="$next"
                [ "$next" = "~" ] && break
                [ "${#key}" -ge 5 ] && break
            done
            [ -z "$key" ] && key="ESC"
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
        printf "%bEnter →%b %s  %bMove%b Up/Down  %bSearch%b /  %bHelp%b ?  %bBack%b ←  %bQuit%b q\n" "$GREEN" "$PLAIN" "$tip" "$CYAN" "$PLAIN" "$YELLOW" "$PLAIN" "$CYAN" "$PLAIN" "$CYAN" "$PLAIN" "$RED" "$PLAIN"
        if [ -n "$filter_text" ]; then
            printf "%bFilter%b %s  " "$YELLOW" "$PLAIN" "$filter_text"
        fi
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
        printf "%bEnter →%b %s  %bMove%b Up/Down  %bSearch%b /  %bHelp%b ?  %bBack%b ←  %bQuit%b q" "$GREEN" "$PLAIN" "$tip" "$CYAN" "$PLAIN" "$YELLOW" "$PLAIN" "$CYAN" "$PLAIN" "$CYAN" "$PLAIN" "$RED" "$PLAIN"
        tput cup "$((footer_line + 2))" 0 2>/dev/null || true
        tput el 2>/dev/null || true
        if [ -n "$filter_text" ]; then
            printf "%bFilter%b %s  " "$YELLOW" "$PLAIN" "$filter_text"
        fi
        printf "%bPowered by %b%s%b" "$ITALIC" "$CYAN" "rainyfall.dev" "$PLAIN"

    }

    draw_help() {
        tput cup 0 0 2>/dev/null || true
        tput ed 2>/dev/null || true
        draw_title_bar "$title / 帮助"
        printf 'Enter/Right  进入菜单或执行当前项\n'
        printf 'Up/Down      上下移动\n'
        printf 'PgUp/PgDn    上下翻页\n'
        printf 'g/G          跳到顶部/底部\n'
        printf 'Left/Bs      返回上级菜单\n'
        printf '/            搜索当前菜单，空输入清除搜索\n'
        printf 'Esc          清除当前搜索\n'
        printf 'q            退出 ScriptKit\n'
        printf '\n%b' "$(ui_prompt "提示" "按任意键返回菜单...")"
        read_key >/dev/null
    }

    prompt_search() {
        tput cnorm 2>/dev/null || true
        printf '\n%b' "$(ui_prompt "输入" "搜索关键词（空则显示全部）: ")"
        IFS= read -r filter_text
        selected=0
        start=0
        apply_filter
        tput civis 2>/dev/null || true
        draw_menu
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
            "[A" | "w" | "W")
                if [ "$selected" -gt 0 ]; then
                    selected=$((selected - 1))
                    [ "$selected" -lt "$start" ] && start=$((start - 1))
                fi
                ;;
            "[B" | "s" | "S")
                if [ "$selected" -lt $((${#values[@]} - 1)) ]; then
                    selected=$((selected + 1))
                    [ "$selected" -ge $((start + page_size)) ] && start=$((start + 1))
                fi
                ;;
            "[5~")
                selected=$((selected - page_size))
                [ "$selected" -lt 0 ] && selected=0
                keep_selection_visible
                ;;
            "[6~")
                selected=$((selected + page_size))
                [ "$selected" -ge "${#values[@]}" ] && selected=$((${#values[@]} - 1))
                keep_selection_visible
                ;;
            "[H" | "[1~" | "OH" | "g")
                selected=0
                start=0
                ;;
            "[F" | "[4~" | "OF" | "G")
                selected=$((${#values[@]} - 1))
                keep_selection_visible
                ;;
            "[D" | $'\x7f' | $'\b')
                if value_exists "__back"; then
                    SELECT_RESULT="__back"
                    break
                fi
                ;;
            "/")
                prompt_search
                continue
                ;;
            "?")
                draw_help
                draw_menu
                continue
                ;;
            "ESC")
                if [ -n "$filter_text" ]; then
                    filter_text=""
                    selected=0
                    start=0
                    apply_filter
                    draw_menu
                    continue
                fi
                ;;
            "[C" | "")
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
    local -a all_values=("$@")
    local -a values=("${all_values[@]}")
    local input id i
    local filter_text=""

    value_exists() {
        local wanted="$1"
        local value
        for value in "${values[@]}"; do
            [ "$value" = "$wanted" ] && return 0
        done
        return 1
    }

    apply_filter() {
        local value type
        local -a filtered=()
        local -a fixed=()

        if [ -z "$filter_text" ]; then
            values=("${all_values[@]}")
            return
        fi

        for value in "${all_values[@]}"; do
            type="${ITEM_TYPES[$value]:-}"
            case "$type" in
                back | exit)
                    fixed+=("$value")
                    ;;
                *)
                    if item_matches_filter "$value" "$filter_text"; then
                        filtered+=("$value")
                    fi
                    ;;
            esac
        done

        if [ "${#filtered[@]}" -eq 0 ]; then
            ITEM_TITLES["__no_match"]="没有匹配结果"
            ITEM_TYPES["__no_match"]="empty"
            ITEM_TARGETS["__no_match"]=""
            filtered+=("__no_match")
        fi

        values=("${filtered[@]}" "${fixed[@]}")
    }

    while true; do
        clear 2>/dev/null || true
        draw_title_bar "$title"
        if [ -n "$filter_text" ]; then
            printf '%b当前搜索:%b %s\n\n' "$YELLOW" "$PLAIN" "$filter_text"
        fi
        for ((i = 0; i < ${#values[@]}; i++)); do
            id="${values[$i]}"
            printf '    %02d  %b\n' "$((i + 1))" "$(format_item_label "$id")"
        done
        printf '\n%b------------------------------------------------%b\n' "$BOLD" "$PLAIN"
        if value_exists "__back"; then
            printf '输入数字并回车确认，输入 /关键词 搜索，输入 b 返回上级，输入 q 退出\n'
        else
            printf '输入数字并回车确认，输入 /关键词 搜索，输入 q 退出\n'
        fi
        printf '%bPowered by %b%s%b\n\n' "$ITALIC" "$CYAN" "rainyfall.dev" "$PLAIN"
        printf '%b' "$(ui_prompt "输入" "请选择 [1-${#values[@]}]: ")"
        read -r input
        if [[ "$input" =~ ^[Qq]$ ]]; then
            SELECT_RESULT="__exit"
            return
        fi
        if [[ "$input" =~ ^[Bb]$ ]] && value_exists "__back"; then
            SELECT_RESULT="__back"
            return
        fi
        if [[ "$input" == /* ]]; then
            filter_text="${input#/}"
            apply_filter
            continue
        fi
        if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le "${#values[@]}" ]; then
            SELECT_RESULT="${values[$((input - 1))]}"
            return
        fi
        ui_error "输入无效。"
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
        ui_error "处理函数未找到: $handler"
    fi
    pause_screen
}

resolve_script_file() {
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

    if [ -f "$script_file" ]; then
        printf '%s' "$script_file"
        return 0
    fi

    return 1
}

run_script() {
    local script_path="$1"
    local script_file=""

    clear 2>/dev/null || true
    if script_file="$(resolve_script_file "$script_path")"; then
        bash "$script_file"
    else
        ui_error "脚本未找到: $script_path"
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
            LOADED_MODULES+=("$module")
            loaded="true"
        done
    fi

    if [ "$loaded" = "false" ] && [ -n "$MODULE_BASE_URL" ]; then
        if download_remote_modules; then
            for module in "$MODULE_CACHE_DIR"/*.sh; do
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

    printf "%b== ScriptKit 状态 ========================================%b\n\n" "$BOLD" "$PLAIN"
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
    printf "%b== 刷新远程模块缓存 ========================================%b\n\n" "$BOLD" "$PLAIN"

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
    printf "%b== 清理模块缓存 ========================================%b\n\n" "$BOLD" "$PLAIN"
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
