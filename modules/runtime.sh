#!/usr/bin/env bash

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

command_exists() {
    command -v "$1" >/dev/null 2>&1
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

validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
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

draw_title_bar() {
    local title="$1"
    printf "%b== %s ========================================%b\n\n" "$BOLD" "$title" "$PLAIN"
}

scriptkit_terminal_columns() {
    local cols=""

    cols=$(tput cols 2>/dev/null || printf '80')
    if ! [[ "$cols" =~ ^[0-9]+$ ]] || [ "$cols" -lt 1 ]; then
        cols=80
    fi

    printf '%s' "$cols"
}

scriptkit_display_width() {
    local text="${1:-}"
    local width=0
    local i=0
    local char=""

    for ((i = 0; i < ${#text}; i++)); do
        char="${text:i:1}"
        if [[ "$char" == [[:ascii:]] ]]; then
            width=$((width + 1))
        else
            width=$((width + 2))
        fi
    done

    printf '%s' "$width"
}

scriptkit_line_wraps() {
    local text="$1"
    local cols="${2:-0}"

    if ! [[ "$cols" =~ ^[0-9]+$ ]] || [ "$cols" -lt 1 ]; then
        cols=$(scriptkit_terminal_columns)
    fi

    [ "$(scriptkit_display_width "$text")" -gt "$cols" ]
}

scriptkit_current_title() {
    local fallback="${1:-}"

    if [ -n "${SCRIPTKIT_CURRENT_ITEM_PATH:-}" ]; then
        printf '%s' "$SCRIPTKIT_CURRENT_ITEM_PATH"
        return 0
    fi

    if [ -n "${CURRENT_ITEM_PATH:-}" ]; then
        printf '%s' "$CURRENT_ITEM_PATH"
        return 0
    fi

    if [ -n "${SCRIPTKIT_CURRENT_MENU_PATH:-}" ]; then
        if [ -n "$fallback" ]; then
            printf '%s / %s' "$SCRIPTKIT_CURRENT_MENU_PATH" "$fallback"
        else
            printf '%s' "$SCRIPTKIT_CURRENT_MENU_PATH"
        fi
        return 0
    fi

    printf '%s' "$fallback"
}

scriptkit_step_title() {
    local step="${1:-}"
    local base=""

    if [ -n "${SCRIPTKIT_CURRENT_ITEM_PATH:-}" ]; then
        base="$SCRIPTKIT_CURRENT_ITEM_PATH"
    elif [ -n "${CURRENT_ITEM_PATH:-}" ]; then
        base="$CURRENT_ITEM_PATH"
    elif [ -n "${SCRIPTKIT_CURRENT_MENU_PATH:-}" ]; then
        base="$SCRIPTKIT_CURRENT_MENU_PATH"
    fi

    if [ -z "$base" ]; then
        printf '%s' "$step"
        return 0
    fi

    if [ -z "$step" ] || [ "$step" = "${base##* / }" ]; then
        printf '%s' "$base"
    else
        printf '%s / %s' "$base" "$step"
    fi
}

scriptkit_draw_current_title() {
    draw_title_bar "$(scriptkit_current_title "$1")"
}

scriptkit_read_key() {
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

yesno_select() {
    local prompt="$1"
    local default="${2:-n}"
    local cursor=1
    local decorated_prompt=""

    [ "$default" = "y" ] && cursor=0
    decorated_prompt="$(ui_prompt "确认" "$prompt")"

    if ! command_exists tput || ! [ -t 0 ] || ! [ -t 1 ] || ! tput cup 0 0 >/dev/null 2>&1; then
        local ans=""
        printf "%b [y/N]: " "$decorated_prompt"
        read -r ans
        ans=$(printf '%s' "${ans:-$default}" | tr '[:upper:]' '[:lower:]')
        [ "$ans" = "y" ] && return 0 || return 1
    fi

    _scriptkit_draw_yesno() {
        tput cuu 2 2>/dev/null || printf '\033[2A'
        tput el 2>/dev/null || printf '\033[K'
        if [ "$cursor" -eq 0 ]; then
            printf "  %b%b> 是%b\n" "$GREEN" "$BOLD" "$PLAIN"
            tput el 2>/dev/null || printf '\033[K'
            printf "    否\n"
        else
            printf "    是\n"
            tput el 2>/dev/null || printf '\033[K'
            printf "  %b%b> 否%b\n" "$RED" "$BOLD" "$PLAIN"
        fi
    }

    tput civis 2>/dev/null || true
    printf "%b\n\n\n" "$decorated_prompt"
    _scriptkit_draw_yesno

    while true; do
        local key
        IFS= read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -rsn2 key
        fi
        case "$key" in
            "[D" | "[A" | "h" | "k") cursor=0 ;;
            "[C" | "[B" | "l" | "j") cursor=1 ;;
            "") break ;;
        esac
        _scriptkit_draw_yesno
    done

    tput cnorm 2>/dev/null || true
    tput cuu 3 2>/dev/null || printf '\033[3A'
    tput el 2>/dev/null || printf '\033[K'
    if [ "$cursor" -eq 0 ]; then
        printf "%b 是\n" "$decorated_prompt"
    else
        printf "%b 否\n" "$decorated_prompt"
    fi
    tput dl1 2>/dev/null || printf '\033[M'
    tput dl1 2>/dev/null || printf '\033[M'
    [ "$cursor" -eq 0 ] && return 0 || return 1
}

multiselect_menu() {
    local title="$1"
    shift
    local -n _labels=$1
    local -n _selected=$2
    local cursor=0
    local count=${#_labels[@]}
    local i

    if ! command_exists tput || ! tput cup 0 0 >/dev/null 2>&1; then
        printf "%b%s%b\n" "$BOLD" "$title" "$PLAIN"
        printf "输入编号切换选中（空格分隔），直接回车确认:\n\n"
        for ((i = 0; i < count; i++)); do
            local mark="[ ]"
            [ "${_selected[$i]}" = "1" ] && mark="[x]"
            printf "  %d) %s %s\n" "$((i + 1))" "$mark" "${_labels[$i]}"
        done
        printf "\n选择（如 1 3 5）: "
        local input=""
        local num=""
        read -r input
        for ((i = 0; i < count; i++)); do _selected[$i]=0; done
        for num in $input; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "$count" ]; then
                _selected[$((num - 1))]=1
            fi
        done
        return 0
    fi

    trap 'tput cnorm 2>/dev/null; tput rmcup 2>/dev/null; exit 130' INT TERM

    tput smcup 2>/dev/null || true
    tput civis 2>/dev/null || true

    _draw_multiselect() {
        tput cup 0 0 2>/dev/null || true
        tput ed 2>/dev/null || true
        draw_title_bar "$title"
        for ((i = 0; i < count; i++)); do
            local mark="[ ]"
            [ "${_selected[$i]}" = "1" ] && mark="${GREEN}[x]${PLAIN}"
            if [ "$i" -eq "$cursor" ]; then
                printf "   %b%b>%b %b %b%s%b\n" "$BLUE" "$BOLD" "$PLAIN" "$mark" "$BOLD" "${_labels[$i]}" "$PLAIN"
            else
                printf "     %b %s\n" "$mark" "${_labels[$i]}"
            fi
        done
        printf "\n%b------------------------------------------------%b\n" "$BOLD" "$PLAIN"
        printf "%bSpace%b 切换选中  %bEnter%b 确认执行  %bq%b 退出\n" "$GREEN" "$PLAIN" "$CYAN" "$PLAIN" "$RED" "$PLAIN"
    }

    _draw_multiselect

    while true; do
        local key
        key="$(scriptkit_read_key)"
        case "$key" in
            "[A" | "k" | "K")
                [ "$cursor" -gt 0 ] && cursor=$((cursor - 1)) ;;
            "[B" | "j" | "J")
                [ "$cursor" -lt $((count - 1)) ] && cursor=$((cursor + 1)) ;;
            " ")
                if [ "${_selected[$cursor]}" = "1" ]; then
                    _selected[$cursor]=0
                else
                    _selected[$cursor]=1
                fi ;;
            "") break ;;
            "q" | "Q")
                for ((i = 0; i < count; i++)); do _selected[$i]=0; done
                break ;;
        esac
        _draw_multiselect
    done

    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true
    trap - INT TERM
}

select_menu() {
    local title="$1"
    local -n _labels=$2
    local -n _selected=$3
    local cursor="${4:-0}"
    local count=${#_labels[@]}
    local i

    if [ "$count" -le 0 ]; then
        ui_warn "没有可选项" >&2
        return 1
    fi

    if ! [[ "$cursor" =~ ^[0-9]+$ ]] || [ "$cursor" -lt 0 ] || [ "$cursor" -ge "$count" ]; then
        cursor=0
    fi

    cleanup_screen() {
        tput cnorm 1>&2 2>/dev/null || true
        tput rmcup 1>&2 2>/dev/null || true
    }

    render_label_block() {
        local first_prefix="$1"
        local continuation_prefix="$2"
        local highlight="$3"
        local label="$4"
        local line=""
        local first_line="y"

        while IFS= read -r line || [ -n "$line" ]; do
            if [ "$first_line" = "y" ]; then
                if [ "$highlight" = "y" ]; then
                    printf '%b%b%s%b\n' "$first_prefix" "$BOLD" "$line" "$PLAIN" >&2
                else
                    printf '%b%s\n' "$first_prefix" "$line" >&2
                fi
                first_line="n"
            else
                printf '%b%s\n' "$continuation_prefix" "$line" >&2
            fi
        done <<< "$label"
    }

    show_selected_result() {
        local label="$1"
        local first_line="${label%%$'\n'*}"
        local summary_title="${title#选择 }"

        printf '%b %s\n' "$(ui_prompt "已选" "${summary_title}: ")" "$first_line" >&2
    }

    draw_menu() {
        tput cup 0 0 1>&2 2>/dev/null || true
        tput ed 1>&2 2>/dev/null || true
        draw_title_bar "$title" >&2

        for ((i = 0; i < count; i++)); do
            if [ "$i" -eq "$cursor" ]; then
                render_label_block "   ${BLUE}${BOLD}>${PLAIN} " "     " "y" "${_labels[$i]}"
            else
                render_label_block "     " "     " "n" "${_labels[$i]}"
            fi
        done

        printf "\n%b------------------------------------------------%b\n" "$BOLD" "$PLAIN" >&2
        printf "%bUp/Down%b 移动  %bEnter%b 确认  %bq%b 退出\n" "$GREEN" "$PLAIN" "$CYAN" "$PLAIN" "$RED" "$PLAIN" >&2
    }

    if ! command_exists tput || ! [ -t 0 ] || ! [ -t 2 ] || ! tput cup 0 0 >/dev/null 2>&1; then
        local choice=""
        local plain_prefix=""
        local plain_indent=""

        draw_title_bar "$title" >&2
        for ((i = 0; i < count; i++)); do
            printf -v plain_prefix '  %d) ' "$((i + 1))"
            printf -v plain_indent '%*s' "${#plain_prefix}" ''
            render_label_block "$plain_prefix" "$plain_indent" "n" "${_labels[$i]}"
        done
        printf '\n%b' "$(ui_prompt "输入" "请选择 [1-${count}]（默认 $((cursor + 1))）: ")" >&2
        read -r choice
        if [[ "$choice" =~ ^[Qq]$ ]]; then
            return 1
        fi
        choice="${choice:-$((cursor + 1))}"
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$count" ]; then
            ui_warn "输入无效" >&2
            return 1
        fi

        _selected=$((choice - 1))
        show_selected_result "${_labels[$_selected]}"
        return 0
    fi

    tput smcup 1>&2 2>/dev/null || true
    tput civis 1>&2 2>/dev/null || true
    trap 'cleanup_screen; exit 130' INT TERM

    draw_menu
    while true; do
        local key
        key="$(scriptkit_read_key)"
        case "$key" in
            "[A")
                [ "$cursor" -gt 0 ] && cursor=$((cursor - 1)) ;;
            "[B")
                [ "$cursor" -lt $((count - 1)) ] && cursor=$((cursor + 1)) ;;
            "")
                _selected="$cursor"
                cleanup_screen
                show_selected_result "${_labels[$_selected]}"
                trap - INT TERM
                return 0 ;;
            "q" | "Q" | "ESC")
                cleanup_screen
                trap - INT TERM
                return 1 ;;
        esac
        draw_menu
    done
}

pick_from_options() {
    local title="$1"
    shift
    local selected=0
    local -a options=("$@")

    select_menu "$(scriptkit_step_title "$title")" options selected || return 1
    printf '%s' "${options[$selected]}"
}
