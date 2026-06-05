#!/usr/bin/env bash

# Small utility actions.

add_menu "utility" "实用工具" "main"

utility_random_password() {
    local length=""
    local password=""

    scriptkit_draw_current_title "生成随机密码"
    printf '%b' "$(ui_prompt "输入" "密码长度（默认 24，范围 8-128）: ")"
    read -r length
    length="${length:-24}"
    if ! [[ "$length" =~ ^[0-9]+$ ]] || [ "$length" -lt 8 ] || [ "$length" -gt 128 ]; then
        ui_warn "长度无效，使用默认 24。"
        length="24"
    fi

    if command_exists openssl && command_exists tr && command_exists head; then
        password="$(openssl rand -base64 256 2>/dev/null | tr -dc 'A-Za-z0-9_@#%+=-' | head -c "$length")"
    elif [ -r /dev/urandom ] && command_exists tr && command_exists head; then
        password="$(LC_ALL=C tr -dc 'A-Za-z0-9_@#%+=-' < /dev/urandom | head -c "$length")"
    else
        ui_error "未找到可用的随机源或处理命令。"
        return 1
    fi

    if [ -z "$password" ]; then
        ui_error "生成密码失败。"
        return 1
    fi

    printf "\n生成的密码:\n%s\n" "$password"
}

utility_crontab_view_run() {
    run_standalone_with_env "modules/standalone/manage_crontab.sh" "SCRIPTKIT_CRONTAB_MODE=view"
}

utility_crontab_add_run() {
    run_standalone_with_env "modules/standalone/manage_crontab.sh" "SCRIPTKIT_CRONTAB_MODE=add"
}

utility_crontab_delete_run() {
    run_standalone_with_env "modules/standalone/manage_crontab.sh" "SCRIPTKIT_CRONTAB_MODE=delete"
}

utility_crontab_backups_run() {
    run_standalone_with_env "modules/standalone/manage_crontab.sh" "SCRIPTKIT_CRONTAB_MODE=backups"
}

utility_crontab_restore_run() {
    run_standalone_with_env "modules/standalone/manage_crontab.sh" "SCRIPTKIT_CRONTAB_MODE=restore"
}

utility_terminal_setup_apply_run() {
    run_standalone_with_env "modules/standalone/terminal_setup.sh" "SCRIPTKIT_TERMINAL_SETUP_MODE=apply"
}

utility_terminal_setup_restore_run() {
    run_standalone_with_env "modules/standalone/terminal_setup.sh" "SCRIPTKIT_TERMINAL_SETUP_MODE=restore"
}

add_action "utility_random_password" "生成随机密码" "utility" "utility_random_password"
add_menu "utility_crontab" "Crontab 管理" "utility"
add_action "utility_crontab_view" "查看任务" "utility_crontab" "utility_crontab_view_run"
add_action "utility_crontab_add" "添加任务" "utility_crontab" "utility_crontab_add_run"
add_action "utility_crontab_delete" "删除任务" "utility_crontab" "utility_crontab_delete_run"
add_action "utility_crontab_backups" "查看备份" "utility_crontab" "utility_crontab_backups_run"
add_action "utility_crontab_restore" "恢复备份" "utility_crontab" "utility_crontab_restore_run"
add_menu "utility_terminal_setup" "终端优化" "utility"
add_action "utility_terminal_setup_apply" "应用 / 更新 Bash 优化" "utility_terminal_setup" "utility_terminal_setup_apply_run"
add_action "utility_terminal_setup_restore" "恢复最近备份" "utility_terminal_setup" "utility_terminal_setup_restore_run"
