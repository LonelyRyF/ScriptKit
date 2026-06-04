#!/usr/bin/env bash

# ECS / 融合怪 entries.

test_ecs_toolbox_run() {
    local mode="$1"
    shift
    local ecs_workdir="${HOME:-/root}/.scriptkit/ecs"

    run_standalone_with_env "modules/standalone/ecs_toolbox.sh" \
        "SCRIPTKIT_ECS_MODE=$mode" \
        "SCRIPTKIT_ECS_WORKDIR=$ecs_workdir" \
        "$@"
}

test_ecs_interactive_run() {
    test_ecs_toolbox_run "interactive"
}

test_ecs_full_run() {
    test_ecs_toolbox_run "full"
}

test_ecs_base_run() {
    test_ecs_toolbox_run "base"
}

test_ecs_custom_run() {
    local ecs_args=""

    scriptkit_draw_current_title "融合怪自定义参数"
    printf '%b' "$(ui_prompt "输入" "请输入参数（空格分隔，例如 -m 5 1 1 -en）: ")"
    read -r ecs_args
    ecs_args="${ecs_args:-}"

    if [ -z "$ecs_args" ]; then
        ui_warn "未输入参数。"
        return 1
    fi

    test_ecs_toolbox_run "custom" "SCRIPTKIT_ECS_ARGS=$ecs_args"
}

test_ecs_ipcheck_run() {
    test_ecs_toolbox_run "ipcheck"
}

test_ecs_custom_ipcheck_run() {
    test_ecs_toolbox_run "custom_ipcheck"
}

add_menu "test_ecs" "ECS / 融合怪" "test"
add_action "test_ecs_interactive" "交互执行" "test_ecs" "test_ecs_interactive_run"
add_action "test_ecs_full" "完整测试 (-m 1)" "test_ecs" "test_ecs_full_run"
add_action "test_ecs_base" "基础信息 (-base)" "test_ecs" "test_ecs_base_run"
add_action "test_ecs_custom" "自定义参数" "test_ecs" "test_ecs_custom_run"
add_menu "test_ecs_ip_quality" "IP 质量检测" "test_ecs"
add_action "test_ecs_ip_quality_fusion" "融合怪 IP 质量检测" "test_ecs_ip_quality" "test_ecs_ipcheck_run"
add_action "test_ecs_ip_quality_custom" "自定义 IP 质量检测" "test_ecs_ip_quality" "test_ecs_custom_ipcheck_run"
