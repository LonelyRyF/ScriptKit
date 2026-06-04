#!/usr/bin/env bash
set -u

# Manage current user's crontab with backups.

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_crontab() {
    if command_exists crontab; then
        return 0
    fi

    msg_err "未找到 crontab 命令"
    return 1
}

backup_crontab() {
    local backup_dir="${XDG_CACHE_HOME:-${HOME:-.}/.cache}/scriptkit/crontab_backups"
    local backup_file="${backup_dir}/crontab.$(date +%Y%m%d%H%M%S)"

    mkdir -p "$backup_dir" || {
        msg_err "无法创建备份目录: $backup_dir"
        return 1
    }

    crontab -l > "$backup_file" 2>/dev/null || : > "$backup_file"
    msg_ok "当前 crontab 已备份到: $backup_file"
}

show_crontab() {
    local current=""

    current="$(crontab -l 2>/dev/null || true)"
    if [ -z "$current" ]; then
        msg_info "当前用户没有 crontab 任务"
        return 0
    fi

    printf "%b当前 crontab:%b\n" "$BOLD" "$PLAIN"
    printf '%s\n' "$current" | awk '{ printf "  %02d  %s\n", NR, $0 }'
}

valid_hour() {
    local hour="$1"
    [[ "$hour" =~ ^[0-9]+$ ]] && [ "$hour" -ge 0 ] && [ "$hour" -le 23 ]
}

valid_weekday() {
    local weekday="$1"
    [[ "$weekday" =~ ^[0-6]$ ]]
}

valid_cron_schedule() {
    local schedule="$1"
    local -a fields=()

    read -r -a fields <<< "$schedule"
    [ "${#fields[@]}" -eq 5 ]
}

add_crontab_job() {
    local job_cmd=""
    local schedule_type=""
    local schedule=""
    local hour=""
    local weekday=""
    local job=""

    printf '%b' "$(msg_prompt "输入" "请输入要调度的命令: ")"
    read -r job_cmd
    if [ -z "$job_cmd" ]; then
        msg_warn "命令不能为空"
        return 1
    fi

    printf "\n选择调度类型:\n"
    printf "  1) 每分钟\n"
    printf "  2) 每小时\n"
    printf "  3) 每天固定小时\n"
    printf "  4) 每周固定星期\n"
    printf "  5) 自定义 cron 表达式\n"
    printf '%b' "$(msg_prompt "输入" "选择 [1-5]: ")"
    read -r schedule_type

    case "$schedule_type" in
        1)
            schedule="* * * * *"
            ;;
        2)
            schedule="0 * * * *"
            ;;
        3)
            printf '%b' "$(msg_prompt "输入" "每天几点执行？[0-23]: ")"
            read -r hour
            if ! valid_hour "$hour"; then
                msg_warn "小时无效"
                return 1
            fi
            schedule="0 $hour * * *"
            ;;
        4)
            printf '%b' "$(msg_prompt "输入" "星期几执行？[0-6，0=星期日]: ")"
            read -r weekday
            if ! valid_weekday "$weekday"; then
                msg_warn "星期值无效"
                return 1
            fi
            schedule="0 0 * * $weekday"
            ;;
        5)
            printf '%b' "$(msg_prompt "输入" "请输入 5 段 cron 表达式: ")"
            read -r schedule
            if [ -z "$schedule" ]; then
                msg_warn "cron 表达式不能为空"
                return 1
            fi
            if ! valid_cron_schedule "$schedule"; then
                msg_warn "cron 表达式必须包含 5 段，例如: */5 * * * *"
                return 1
            fi
            ;;
        *)
            msg_warn "无效选择"
            return 1
            ;;
    esac

    job="$schedule $job_cmd"
    printf "\n即将添加:\n%s\n" "$job"
    if ! yesno_select "确认添加这条 crontab 任务？" "y"; then
        msg_info "已取消添加"
        return 0
    fi

    backup_crontab || return 1
    (crontab -l 2>/dev/null || true; printf '%s\n' "$job") | crontab - || {
        msg_err "添加 crontab 任务失败"
        return 1
    }
    msg_ok "crontab 任务已添加"
}

delete_crontab_job() {
    local current=""
    local line_no=""
    local line=""

    current="$(crontab -l 2>/dev/null || true)"
    if [ -z "$current" ]; then
        msg_info "当前用户没有 crontab 任务"
        return 0
    fi

    show_crontab
    printf '\n%b' "$(msg_prompt "输入" "请输入要删除的任务编号: ")"
    read -r line_no
    if ! [[ "$line_no" =~ ^[0-9]+$ ]] || [ "$line_no" -lt 1 ]; then
        msg_warn "编号无效"
        return 1
    fi

    line="$(printf '%s\n' "$current" | awk -v n="$line_no" 'NR == n { print; exit }')"
    if [ -z "$line" ]; then
        msg_warn "找不到编号对应的任务"
        return 1
    fi

    printf "\n将删除:\n%s\n" "$line"
    if ! yesno_select "确认删除这条 crontab 任务？"; then
        msg_info "已取消删除"
        return 0
    fi

    backup_crontab || return 1
    printf '%s\n' "$current" | awk -v n="$line_no" 'NR != n' | crontab - || {
        msg_err "删除 crontab 任务失败"
        return 1
    }
    msg_ok "crontab 任务已删除"
}

main() {
    local choice=""

    require_crontab || exit 1
    while true; do
        printf "%b== Crontab 管理 ========================================%b\n\n" "$BOLD" "$PLAIN"
        printf "  1) 查看任务\n"
        printf "  2) 添加任务\n"
        printf "  3) 删除任务\n"
        printf "  0) 退出\n\n"
        printf '%b' "$(msg_prompt "输入" "请选择 [0-3]: ")"
        read -r choice

        case "$choice" in
            1) show_crontab ;;
            2) add_crontab_job ;;
            3) delete_crontab_job ;;
            0) return 0 ;;
            *) msg_warn "无效选择" ;;
        esac

        printf '\n%b' "$(msg_prompt "提示" "按 Enter 继续...")"
        read -r _
        clear 2>/dev/null || true
    done
}

main
