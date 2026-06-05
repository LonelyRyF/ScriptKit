#!/usr/bin/env bash

add_menu "app" "应用部署" "main"

app_napcat_general_run() {
    run_standalone_with_env "modules/standalone/deploy_napcat.sh" "SCRIPTKIT_NAPCAT_MODE=general"
}

app_napcat_visual_run() {
    run_standalone_with_env "modules/standalone/deploy_napcat.sh" "SCRIPTKIT_NAPCAT_MODE=visual"
}

app_napcat_docker_run() {
    run_standalone_with_env "modules/standalone/deploy_napcat.sh" "SCRIPTKIT_NAPCAT_MODE=docker"
}

add_menu "app_napcat" "NapCat" "app"
add_action "app_napcat_general" "通用安装" "app_napcat" "app_napcat_general_run"
add_action "app_napcat_visual" "可视化安装" "app_napcat" "app_napcat_visual_run"
add_action "app_napcat_docker" "Docker 安装" "app_napcat" "app_napcat_docker_run"
