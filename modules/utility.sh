#!/usr/bin/env bash

# Small utility actions.

add_menu "utility" "实用工具" "main"

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

add_menu "utility_crontab" "Crontab 管理" "utility"
add_action "utility_crontab_view" "查看任务" "utility_crontab" "utility_crontab_view_run"
add_action "utility_crontab_add" "添加任务" "utility_crontab" "utility_crontab_add_run"
add_action "utility_crontab_delete" "删除任务" "utility_crontab" "utility_crontab_delete_run"
add_action "utility_crontab_backups" "查看备份" "utility_crontab" "utility_crontab_backups_run"
add_action "utility_crontab_restore" "恢复备份" "utility_crontab" "utility_crontab_restore_run"
add_menu "utility_terminal_setup" "终端优化" "utility"
add_action "utility_terminal_setup_apply" "应用 / 更新 Bash 优化" "utility_terminal_setup" "utility_terminal_setup_apply_run"
add_action "utility_terminal_setup_restore" "恢复最近备份" "utility_terminal_setup" "utility_terminal_setup_restore_run"
