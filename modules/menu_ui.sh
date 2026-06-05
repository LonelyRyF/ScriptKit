#!/usr/bin/env bash

# Phase 2 refactored: UI rendering, input, filtering, help, pause
# Sourced by menu.sh after runtime.sh and menu_core.sh

set -u

can_use_tput_menu() {
    command_exists tput && [ -t 0 ] && [ -t 1 ] && tput lines >/dev/null 2>&1 && tput cup 0 0 >/dev/null 2>&1
}

pause_screen() {
    printf '\n%b' "$(ui_prompt "提示" "按 Enter 返回菜单...")"
    read -r _
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
        search) printf '%b[/]%b %s' "$CYAN" "$PLAIN" "$title" ;;
        search_result) printf '%b[>]%b %s' "$YELLOW" "$PLAIN" "$title" ;;
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
        search) printf '回车全局搜索匹配菜单' ;;
        search_result) printf '回车执行%s' "$title" ;;
        choice) printf '回车选择%s' "$title" ;;
        empty) printf '当前菜单暂无可用功能' ;;
        back) printf '回车返回上级菜单' ;;
        exit) printf '回车退出' ;;
        *) printf '回车确认' ;;
    esac
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

            ITEM_TITLES["__global_search"]="全局搜索: $filter_text"
            ITEM_TYPES["__global_search"]="search"
            ITEM_TARGETS["__global_search"]="$filter_text"
            filtered=("__global_search" "${filtered[@]}")

            if [ "${#filtered[@]}" -eq 1 ]; then
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

    item_line_width() {
        local id="$1"
        local type="${ITEM_TYPES[$id]:-}"
        local title="${ITEM_TITLES[$id]:-$id}"
        local width=5

        width=$((width + $(scriptkit_display_width "$title")))
        case "$type" in
            menu | action | script | search | search_result | choice | empty | back | exit)
                width=$((width + 4))
                ;;
        esac

        printf '%s' "$width"
    }

    footer_wraps_for_selection() {
        local selection_index="$1"
        local cols="$2"
        local selected_id="${values[$selection_index]}"
        local tip=""
        local footer_line=""

        tip="$(format_item_tip "$selected_id")"

        scriptkit_line_wraps "------------------------------------------------" "$cols" && return 0
        scriptkit_line_wraps "Enter → $tip  Move Up/Down  Search /  Help ?  Back ←  Quit q" "$cols" && return 0

        if [ -n "$filter_text" ]; then
            footer_line="Filter $filter_text  Powered by rainyfall.dev"
        else
            footer_line="Powered by rainyfall.dev"
        fi
        scriptkit_line_wraps "$footer_line" "$cols" && return 0

        return 1
    }

    should_use_full_redraw() {
        local previous_selected="$1"
        local cols=0
        local end=0
        local i=0
        local id=""

        cols=$(scriptkit_terminal_columns)

        scriptkit_line_wraps "== $title ========================================" "$cols" && return 0

        end=$((start + page_size - 1))
        [ "$end" -ge "${#values[@]}" ] && end=$((${#values[@]} - 1))

        for ((i = start; i <= end; i++)); do
            id="${values[$i]}"
            if [ "$(item_line_width "$id")" -gt "$cols" ]; then
                return 0
            fi
        done

        footer_wraps_for_selection "$previous_selected" "$cols" && return 0
        if [ "$previous_selected" -ne "$selected" ]; then
            footer_wraps_for_selection "$selected" "$cols" && return 0
        fi

        return 1
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
        printf '/            搜索当前菜单，并在顶部提供全局菜单搜索入口\n'
        printf 'Esc          清除当前搜索\n'
        printf 'q            退出 ScriptKit\n'
        printf '\n%b' "$(ui_prompt "提示" "按任意键返回菜单...")"
        scriptkit_read_key >/dev/null
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
        key=$(scriptkit_read_key)
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
                if should_use_full_redraw "$old_selected"; then
                    draw_menu
                else
                    redraw_changed_selection "$old_selected"
                fi
            else
                draw_menu
            fi
        fi
    done

    tput cnorm 2>/dev/null || true
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

        ITEM_TITLES["__global_search"]="全局搜索: $filter_text"
        ITEM_TYPES["__global_search"]="search"
        ITEM_TARGETS["__global_search"]="$filter_text"
        filtered=("__global_search" "${filtered[@]}")

        if [ "${#filtered[@]}" -eq 1 ]; then
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
            printf '输入数字并回车确认，输入 /关键词 搜索，顶部可全局菜单搜索，输入 b 返回上级，输入 q 退出\n'
        else
            printf '输入数字并回车确认，输入 /关键词 搜索，顶部可全局菜单搜索，输入 q 退出\n'
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
