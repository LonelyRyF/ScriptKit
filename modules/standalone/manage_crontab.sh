#!/usr/bin/env bash
set -u

# Manage current user's crontab with backups.

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

CRONTAB_JOB_LINE_NUMBERS=()
CRONTAB_JOB_LINES=()
CRONTAB_OTHER_LINE_NUMBERS=()
CRONTAB_OTHER_LINES=()
BACKUP_FILES=()

require_crontab() {
    if command_exists crontab; then
        return 0
    fi

    msg_warn "未找到 crontab 命令"
    if ! yesno_select "是否自动安装 crontab？"; then
        msg_err "已取消，crontab 命令不可用。"
        return 1
    fi

    msg_info "正在安装 cron 服务..."
    if command_exists apt-get; then
        apt-get update -qq && apt-get install -y -qq cron 2>/dev/null
    elif command_exists dnf; then
        dnf install -y cronie 2>/dev/null
    elif command_exists yum; then
        yum install -y cronie 2>/dev/null
    elif command_exists apk; then
        apk add --no-cache dcron 2>/dev/null
    else
        msg_err "无法识别的包管理器，请手动安装 cron。"
        return 1
    fi

    if command_exists crontab; then
        msg_ok "crontab 已安装。"
        return 0
    fi

    msg_err "crontab 安装失败。"
    return 1
}

crontab_backup_dir() {
    printf '%s' "${XDG_CACHE_HOME:-${HOME:-.}/.cache}/scriptkit/crontab_backups"
}

read_current_crontab() {
    crontab -l 2>/dev/null || true
}

backup_crontab() {
    local backup_dir=""
    local backup_file=""

    backup_dir="$(crontab_backup_dir)"
    backup_file="${backup_dir}/crontab.$(date +%Y%m%d%H%M%S).${RANDOM}.$$"

    mkdir -p "$backup_dir" || {
        msg_err "无法创建备份目录: $backup_dir"
        return 1
    }

    read_current_crontab > "$backup_file"
    msg_ok "当前 crontab 已备份到: $backup_file"
}

# Crontab 中除了任务，还可能有注释、空行和环境变量。
is_crontab_job_line() {
    local line="$1"
    local trimmed=""

    trimmed="${line#"${line%%[![:space:]]*}"}"
    [ -n "$trimmed" ] || return 1

    case "$trimmed" in
        \#*)
            return 1
            ;;
        @reboot|@reboot[[:space:]]*|@yearly|@yearly[[:space:]]*|@annually|@annually[[:space:]]*|@monthly|@monthly[[:space:]]*|@weekly|@weekly[[:space:]]*|@daily|@daily[[:space:]]*|@midnight|@midnight[[:space:]]*|@hourly|@hourly[[:space:]]*)
            set -- $trimmed
            [ "$#" -ge 2 ]
            return
            ;;
        @*)
            return 1
            ;;
    esac

    if [[ "$trimmed" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
        return 1
    fi

    set -- $trimmed
    [ "$#" -ge 6 ]
}

collect_crontab_entries() {
    local current=""
    local line=""
    local line_no=0

    CRONTAB_JOB_LINE_NUMBERS=()
    CRONTAB_JOB_LINES=()
    CRONTAB_OTHER_LINE_NUMBERS=()
    CRONTAB_OTHER_LINES=()

    current="$(read_current_crontab)"
    [ -n "$current" ] || return 0

    while IFS= read -r line || [ -n "$line" ]; do
        line_no=$((line_no + 1))
        if is_crontab_job_line "$line"; then
            CRONTAB_JOB_LINE_NUMBERS+=("$line_no")
            CRONTAB_JOB_LINES+=("$line")
        else
            CRONTAB_OTHER_LINE_NUMBERS+=("$line_no")
            CRONTAB_OTHER_LINES+=("$line")
        fi
    done <<< "$current"
}

show_crontab() {
    local i=0
    local line_display=""

    collect_crontab_entries
    if [ "${#CRONTAB_JOB_LINES[@]}" -eq 0 ] && [ "${#CRONTAB_OTHER_LINES[@]}" -eq 0 ]; then
        msg_info "当前用户没有 crontab 任务"
        return 0
    fi

    if [ "${#CRONTAB_JOB_LINES[@]}" -gt 0 ]; then
        printf "%b当前任务:%b\n" "$BOLD" "$PLAIN"
        for ((i = 0; i < ${#CRONTAB_JOB_LINES[@]}; i++)); do
            printf "  %02d  [line %s] %s\n" \
                "$((i + 1))" \
                "${CRONTAB_JOB_LINE_NUMBERS[$i]}" \
                "${CRONTAB_JOB_LINES[$i]}"
        done
    else
        msg_info "当前没有可执行任务"
    fi

    if [ "${#CRONTAB_OTHER_LINES[@]}" -gt 0 ]; then
        printf "\n%b其他行（注释 / 变量 / 空行）:%b\n" "$BOLD" "$PLAIN"
        for ((i = 0; i < ${#CRONTAB_OTHER_LINES[@]}; i++)); do
            line_display="${CRONTAB_OTHER_LINES[$i]}"
            [ -n "$line_display" ] || line_display="<空行>"
            printf "  --  [line %s] %s\n" \
                "${CRONTAB_OTHER_LINE_NUMBERS[$i]}" \
                "$line_display"
        done
    fi
}

valid_minute() {
    local minute="$1"
    [[ "$minute" =~ ^[0-9]+$ ]] && [ "$minute" -ge 0 ] && [ "$minute" -le 59 ]
}

valid_hour() {
    local hour="$1"
    [[ "$hour" =~ ^[0-9]+$ ]] && [ "$hour" -ge 0 ] && [ "$hour" -le 23 ]
}

valid_weekday() {
    local weekday="$1"
    [[ "$weekday" =~ ^[0-7]$ ]]
}

valid_monthday() {
    local monthday="$1"
    [[ "$monthday" =~ ^[0-9]+$ ]] && [ "$monthday" -ge 1 ] && [ "$monthday" -le 31 ]
}

valid_cron_schedule() {
    local schedule="$1"
    local -a fields=()

    case "$schedule" in
        @reboot|@yearly|@annually|@monthly|@weekly|@daily|@midnight|@hourly)
            return 0
            ;;
    esac

    read -r -a fields <<< "$schedule"
    [ "${#fields[@]}" -eq 5 ]
}

crontab_has_exact_line() {
    local target="$1"
    local current=""
    local line=""

    current="$(read_current_crontab)"
    [ -n "$current" ] || return 1

    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$line" = "$target" ]; then
            return 0
        fi
    done <<< "$current"

    return 1
}

add_crontab_job() {
    local job_cmd=""
    local schedule_type=""
    local schedule=""
    local minute=""
    local hour=""
    local weekday=""
    local monthday=""
    local current=""
    local job=""

    printf '%b' "$(msg_prompt "输入" "请输入要调度的命令: ")"
    read -r job_cmd
    if [ -z "$job_cmd" ]; then
        msg_warn "命令不能为空"
        return 1
    fi

    printf "\n选择调度类型:\n"
    printf "  1) 每分钟\n"
    printf "  2) 每小时固定分钟\n"
    printf "  3) 每天固定时间\n"
    printf "  4) 每周固定时间\n"
    printf "  5) 每月固定日期时间\n"
    printf "  6) 开机后执行\n"
    printf "  7) 自定义 cron 表达式 / 宏\n"
    printf '%b' "$(msg_prompt "输入" "选择 [1-7]: ")"
    read -r schedule_type

    case "$schedule_type" in
        1)
            schedule="* * * * *"
            ;;
        2)
            printf '%b' "$(msg_prompt "输入" "每小时的第几分钟执行？[0-59]: ")"
            read -r minute
            if ! valid_minute "$minute"; then
                msg_warn "分钟无效"
                return 1
            fi
            schedule="$minute * * * *"
            ;;
        3)
            printf '%b' "$(msg_prompt "输入" "每天几点执行？[0-23]: ")"
            read -r hour
            if ! valid_hour "$hour"; then
                msg_warn "小时无效"
                return 1
            fi

            printf '%b' "$(msg_prompt "输入" "每天第几分钟执行？[0-59]: ")"
            read -r minute
            if ! valid_minute "$minute"; then
                msg_warn "分钟无效"
                return 1
            fi
            schedule="$minute $hour * * *"
            ;;
        4)
            printf '%b' "$(msg_prompt "输入" "星期几执行？[0-7，0/7=星期日]: ")"
            read -r weekday
            if ! valid_weekday "$weekday"; then
                msg_warn "星期值无效"
                return 1
            fi

            printf '%b' "$(msg_prompt "输入" "几点执行？[0-23]: ")"
            read -r hour
            if ! valid_hour "$hour"; then
                msg_warn "小时无效"
                return 1
            fi

            printf '%b' "$(msg_prompt "输入" "第几分钟执行？[0-59]: ")"
            read -r minute
            if ! valid_minute "$minute"; then
                msg_warn "分钟无效"
                return 1
            fi
            schedule="$minute $hour * * $weekday"
            ;;
        5)
            printf '%b' "$(msg_prompt "输入" "每月几号执行？[1-31]: ")"
            read -r monthday
            if ! valid_monthday "$monthday"; then
                msg_warn "日期无效"
                return 1
            fi

            printf '%b' "$(msg_prompt "输入" "几点执行？[0-23]: ")"
            read -r hour
            if ! valid_hour "$hour"; then
                msg_warn "小时无效"
                return 1
            fi

            printf '%b' "$(msg_prompt "输入" "第几分钟执行？[0-59]: ")"
            read -r minute
            if ! valid_minute "$minute"; then
                msg_warn "分钟无效"
                return 1
            fi
            schedule="$minute $hour $monthday * *"
            ;;
        6)
            schedule="@reboot"
            ;;
        7)
            printf '%b' "$(msg_prompt "输入" "请输入 5 段表达式，或 @daily / @reboot 这类宏: ")"
            read -r schedule
            if [ -z "$schedule" ]; then
                msg_warn "cron 表达式不能为空"
                return 1
            fi
            if ! valid_cron_schedule "$schedule"; then
                msg_warn "表达式无效，需为 5 段或标准宏，例如: */5 * * * * / @daily"
                return 1
            fi
            ;;
        *)
            msg_warn "无效选择"
            return 1
            ;;
    esac

    job="$schedule $job_cmd"

    if crontab_has_exact_line "$job"; then
        msg_warn "检测到完全相同的任务已存在"
        if ! yesno_select "仍然继续添加这条重复任务？"; then
            msg_info "已取消添加"
            return 0
        fi
    fi

    printf "\n即将添加:\n  %s\n" "$job"
    if ! yesno_select "确认添加这条 crontab 任务？" "y"; then
        msg_info "已取消添加"
        return 0
    fi

    current="$(read_current_crontab)"
    backup_crontab || return 1
    {
        [ -n "$current" ] && printf '%s\n' "$current"
        printf '%s\n' "$job"
    } | crontab - || {
        msg_err "添加 crontab 任务失败"
        return 1
    }
    msg_ok "crontab 任务已添加"
}

delete_crontab_job() {
    local current=""
    local choice=""
    local index=0
    local line_no=""
    local line=""

    collect_crontab_entries
    if [ "${#CRONTAB_JOB_LINES[@]}" -eq 0 ] && [ "${#CRONTAB_OTHER_LINES[@]}" -eq 0 ]; then
        msg_info "当前用户没有 crontab 任务"
        return 0
    fi

    show_crontab
    if [ "${#CRONTAB_JOB_LINES[@]}" -eq 0 ]; then
        msg_warn "当前只有注释、变量或空行，没有可删除任务"
        return 0
    fi

    printf '\n%b' "$(msg_prompt "输入" "请输入要删除的任务编号: ")"
    read -r choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#CRONTAB_JOB_LINES[@]}" ]; then
        msg_warn "编号无效"
        return 1
    fi

    index=$((choice - 1))
    line_no="${CRONTAB_JOB_LINE_NUMBERS[$index]}"
    line="${CRONTAB_JOB_LINES[$index]}"

    printf "\n将删除:\n  %s\n" "$line"
    if ! yesno_select "确认删除这条 crontab 任务？"; then
        msg_info "已取消删除"
        return 0
    fi

    current="$(read_current_crontab)"
    backup_crontab || return 1
    printf '%s\n' "$current" | awk -v n="$line_no" 'NR != n' | crontab - || {
        msg_err "删除 crontab 任务失败"
        return 1
    }
    msg_ok "crontab 任务已删除"
}

collect_backup_files() {
    local backup_dir=""
    local file=""
    local nullglob_enabled=0

    BACKUP_FILES=()
    backup_dir="$(crontab_backup_dir)"
    [ -d "$backup_dir" ] || return 0

    if shopt -q nullglob; then
        nullglob_enabled=1
    fi
    shopt -s nullglob

    for file in "$backup_dir"/crontab.*; do
        [ -f "$file" ] && BACKUP_FILES+=("$file")
    done

    if [ "$nullglob_enabled" -eq 0 ]; then
        shopt -u nullglob
    fi
}

show_crontab_backups() {
    local total=0
    local shown=0
    local i=0
    local file=""

    collect_backup_files
    total="${#BACKUP_FILES[@]}"
    if [ "$total" -eq 0 ]; then
        msg_info "暂无 crontab 备份"
        return 0
    fi

    printf "%b备份目录:%b %s\n\n" "$BOLD" "$PLAIN" "$(crontab_backup_dir)"
    printf "%b可用备份（最新在前）:%b\n" "$BOLD" "$PLAIN"
    shown=1
    for ((i = total - 1; i >= 0; i--)); do
        file="${BACKUP_FILES[$i]}"
        printf "  %02d  %s\n" "$shown" "$(basename "$file")"
        shown=$((shown + 1))
    done
}

restore_crontab_backup() {
    local total=0
    local choice=""
    local backup_index=0
    local backup_file=""

    collect_backup_files
    total="${#BACKUP_FILES[@]}"
    if [ "$total" -eq 0 ]; then
        msg_info "暂无 crontab 备份"
        return 0
    fi

    show_crontab_backups
    printf '\n%b' "$(msg_prompt "输入" "请输入要恢复的备份编号: ")"
    read -r choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$total" ]; then
        msg_warn "编号无效"
        return 1
    fi

    backup_index=$((total - choice))
    backup_file="${BACKUP_FILES[$backup_index]}"

    printf "\n%b备份内容预览:%b\n" "$BOLD" "$PLAIN"
    if [ -s "$backup_file" ]; then
        awk '{ printf "  %02d  %s\n", NR, $0 }' "$backup_file"
    else
        printf "  <空 crontab>\n"
    fi

    if ! yesno_select "确认用该备份覆盖当前 crontab？"; then
        msg_info "已取消恢复"
        return 0
    fi

    backup_crontab || return 1
    crontab "$backup_file" || {
        msg_err "恢复 crontab 失败"
        return 1
    }
    msg_ok "crontab 已从备份恢复"
}

main() {
    local choice=""

    require_crontab || exit 1

    case "${SCRIPTKIT_CRONTAB_MODE:-}" in
        view)
            draw_current_title "Crontab 管理"
            show_crontab
            return
            ;;
        add)
            draw_current_title "Crontab 管理"
            add_crontab_job
            return
            ;;
        delete)
            draw_current_title "Crontab 管理"
            delete_crontab_job
            return
            ;;
        backups)
            draw_current_title "Crontab 管理"
            show_crontab_backups
            return
            ;;
        restore)
            draw_current_title "Crontab 管理"
            restore_crontab_backup
            return
            ;;
    esac

    while true; do
        draw_current_title "Crontab 管理"
        printf "  1) 查看任务\n"
        printf "  2) 添加任务\n"
        printf "  3) 删除任务\n"
        printf "  4) 查看备份\n"
        printf "  5) 恢复备份\n"
        printf "  0) 退出\n\n"
        printf '%b' "$(msg_prompt "输入" "请选择 [0-5]: ")"
        read -r choice

        case "$choice" in
            1) show_crontab ;;
            2) add_crontab_job ;;
            3) delete_crontab_job ;;
            4) show_crontab_backups ;;
            5) restore_crontab_backup ;;
            0) return 0 ;;
            *) msg_warn "无效选择" ;;
        esac

        printf '\n%b' "$(msg_prompt "提示" "按 Enter 继续...")"
        read -r _
        clear 2>/dev/null || true
    done
}

main
