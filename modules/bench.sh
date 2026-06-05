#!/usr/bin/env bash

# Benchmark tools module.

add_menu "bench" "性能测评" "main"

bench_toolbox_run() {
    local tool="$1"
    local mode="$2"
    local workdir="${HOME:-/root}/.scriptkit/$tool"

    shift 2

    run_standalone_with_env "modules/standalone/test_toolbox.sh" \
        "SCRIPTKIT_TEST_TOOL=$tool" \
        "SCRIPTKIT_TEST_MODE=$mode" \
        "SCRIPTKIT_TEST_WORKDIR=$workdir" \
        "$@"
}

bench_prompt_custom_args() {
    local title="$1"
    local prompt="$2"
    local tool="$3"
    local mode="$4"
    local args=""

    scriptkit_draw_current_title "$title"
    printf '%b' "$(ui_prompt "输入" "$prompt")"
    read -r args
    args="${args:-}"

    if [ -z "$args" ]; then
        ui_warn "未输入参数。"
        return 1
    fi

    bench_toolbox_run "$tool" "$mode" "SCRIPTKIT_TEST_ARGS=$args"
}

bench_prompt_value_run() {
    local title="$1"
    local prompt="$2"
    local tool="$3"
    local mode="$4"
    local env_name="$5"
    local value=""

    scriptkit_draw_current_title "$title"
    printf '%b' "$(ui_prompt "输入" "$prompt")"
    read -r value
    value="${value:-}"

    if [ -z "$value" ]; then
        ui_warn "未输入内容。"
        return 1
    fi

    bench_toolbox_run "$tool" "$mode" "$env_name=$value"
}

bench_yabs_default_run() { bench_toolbox_run "yabs" "default"; }
bench_yabs_reduced_run() { bench_toolbox_run "yabs" "reduced"; }
bench_yabs_system_disk_run() { bench_toolbox_run "yabs" "system_disk"; }
bench_yabs_network_only_run() { bench_toolbox_run "yabs" "network_only"; }
bench_yabs_json_run() { bench_toolbox_run "yabs" "json"; }
bench_yabs_json_file_run() { bench_toolbox_run "yabs" "json_file"; }
bench_yabs_help_run() { bench_toolbox_run "yabs" "help"; }
bench_yabs_gb4_run() { bench_toolbox_run "yabs" "gb4"; }
bench_yabs_gb5_run() { bench_toolbox_run "yabs" "gb5"; }
bench_yabs_gb45_run() { bench_toolbox_run "yabs" "gb45"; }

bench_yabs_custom_run() {
    bench_prompt_custom_args \
        "YABS 自定义参数" \
        "请输入参数（例如 -r -5 -j 或 -w /root/yabs.json）: " \
        "yabs" \
        "custom"
}

bench_nodequality_interactive_run() { bench_toolbox_run "nodequality" "interactive"; }
bench_nodequality_default_run() { bench_toolbox_run "nodequality" "default"; }
bench_nodequality_ipv4_run() { bench_toolbox_run "nodequality" "ipv4_default"; }
bench_nodequality_ipv6_run() { bench_toolbox_run "nodequality" "ipv6_default"; }
bench_nodequality_english_run() { bench_toolbox_run "nodequality" "english_default"; }
bench_nodequality_hardware_run() { bench_toolbox_run "nodequality" "hardware_only"; }
bench_nodequality_hardware_fast_run() { bench_toolbox_run "nodequality" "hardware_fast"; }
bench_nodequality_hardware_verbose_run() { bench_toolbox_run "nodequality" "hardware_verbose"; }
bench_nodequality_ip_run() { bench_toolbox_run "nodequality" "ip_only"; }
bench_nodequality_net_run() { bench_toolbox_run "nodequality" "net_only"; }
bench_nodequality_net_lite_run() { bench_toolbox_run "nodequality" "net_lite"; }
bench_nodequality_trace_run() { bench_toolbox_run "nodequality" "trace_only"; }

bench_ipquality_default_run() { bench_toolbox_run "ipquality" "default"; }
bench_ipquality_ipv4_run() { bench_toolbox_run "ipquality" "ipv4"; }
bench_ipquality_ipv6_run() { bench_toolbox_run "ipquality" "ipv6"; }
bench_ipquality_fullip_run() { bench_toolbox_run "ipquality" "fullip"; }
bench_ipquality_english_run() { bench_toolbox_run "ipquality" "english"; }
bench_ipquality_json_run() { bench_toolbox_run "ipquality" "json"; }
bench_ipquality_privacy_run() { bench_toolbox_run "ipquality" "privacy"; }
bench_ipquality_ansi_file_run() { bench_toolbox_run "ipquality" "ansi_file"; }
bench_ipquality_json_file_run() { bench_toolbox_run "ipquality" "json_file"; }
bench_ipquality_text_file_run() { bench_toolbox_run "ipquality" "text_file"; }
bench_ipquality_skip_dep_run() { bench_toolbox_run "ipquality" "skip_dep"; }
bench_ipquality_auto_install_run() { bench_toolbox_run "ipquality" "auto_install"; }
bench_ipquality_ipv4_full_run() { bench_toolbox_run "ipquality" "ipv4_full"; }

bench_ipquality_interface_run() {
    bench_prompt_value_run \
        "IPQuality 指定网卡或出口 IP" \
        "请输入网卡名或出口 IP（例如 eth0 或 203.0.113.1）: " \
        "ipquality" \
        "interface" \
        "SCRIPTKIT_TEST_INTERFACE"
}

bench_ipquality_proxy_run() {
    bench_prompt_value_run \
        "IPQuality 指定代理" \
        "请输入代理地址（例如 socks5://user:pass@host:port）: " \
        "ipquality" \
        "proxy" \
        "SCRIPTKIT_TEST_PROXY"
}

bench_ipquality_custom_run() {
    bench_prompt_custom_args \
        "IPQuality 自定义参数" \
        "请输入参数（例如 -4 -f -p 或 -o /root/ipquality.json）: " \
        "ipquality" \
        "custom"
}

bench_regioncheck_interactive_run() { bench_toolbox_run "regioncheck" "interactive"; }
bench_regioncheck_all_run() { bench_toolbox_run "regioncheck" "all"; }
bench_regioncheck_global_run() { bench_toolbox_run "regioncheck" "global"; }
bench_regioncheck_instagram_run() { bench_toolbox_run "regioncheck" "instagram"; }
bench_regioncheck_sport_run() { bench_toolbox_run "regioncheck" "sport"; }
bench_regioncheck_ipv4_all_run() { bench_toolbox_run "regioncheck" "ipv4_all"; }
bench_regioncheck_ipv6_all_run() { bench_toolbox_run "regioncheck" "ipv6_all"; }
bench_regioncheck_english_all_run() { bench_toolbox_run "regioncheck" "english_all"; }

bench_regioncheck_region_run() {
    local region_id="$1"
    bench_toolbox_run "regioncheck" "region" "SCRIPTKIT_TEST_REGION=$region_id"
}

bench_regioncheck_region_tw_run() { bench_regioncheck_region_run "1"; }
bench_regioncheck_region_hk_run() { bench_regioncheck_region_run "2"; }
bench_regioncheck_region_jp_run() { bench_regioncheck_region_run "3"; }
bench_regioncheck_region_na_run() { bench_regioncheck_region_run "4"; }
bench_regioncheck_region_sa_run() { bench_regioncheck_region_run "5"; }
bench_regioncheck_region_eu_run() { bench_regioncheck_region_run "6"; }
bench_regioncheck_region_oa_run() { bench_regioncheck_region_run "7"; }
bench_regioncheck_region_kr_run() { bench_regioncheck_region_run "8"; }
bench_regioncheck_region_sea_run() { bench_regioncheck_region_run "9"; }
bench_regioncheck_region_in_run() { bench_regioncheck_region_run "10"; }
bench_regioncheck_region_af_run() { bench_regioncheck_region_run "11"; }

bench_regioncheck_interface_run() {
    bench_prompt_value_run \
        "RegionRestrictionCheck 指定网卡" \
        "请输入网卡名（例如 eth0）: " \
        "regioncheck" \
        "interface" \
        "SCRIPTKIT_TEST_INTERFACE"
}

bench_regioncheck_proxy_run() {
    bench_prompt_value_run \
        "RegionRestrictionCheck 指定代理" \
        "请输入代理地址（例如 socks5://user:pass@host:port）: " \
        "regioncheck" \
        "proxy" \
        "SCRIPTKIT_TEST_PROXY"
}

bench_regioncheck_xff_run() {
    bench_prompt_value_run \
        "RegionRestrictionCheck 自定义 X-Forwarded-For" \
        "请输入自定义出口 IP（例如 203.0.113.1 或 2001:db8::1）: " \
        "regioncheck" \
        "xff" \
        "SCRIPTKIT_TEST_XFF"
}

bench_regioncheck_custom_run() {
    bench_prompt_custom_args \
        "RegionRestrictionCheck 自定义参数" \
        "请输入参数（例如 -M 4 -R 3 或 -I eth0 -R 66）: " \
        "regioncheck" \
        "custom"
}

bench_ecs_toolbox_run() {
    local mode="$1"
    shift
    local ecs_workdir="${HOME:-/root}/.scriptkit/ecs"

    run_standalone_with_env "modules/standalone/ecs_toolbox.sh" \
        "SCRIPTKIT_ECS_MODE=$mode" \
        "SCRIPTKIT_ECS_WORKDIR=$ecs_workdir" \
        "$@"
}

bench_ecs_interactive_run() { bench_ecs_toolbox_run "interactive"; }
bench_ecs_full_run() { bench_ecs_toolbox_run "full"; }
bench_ecs_base_run() { bench_ecs_toolbox_run "base"; }

bench_ecs_custom_run() {
    local ecs_args=""
    scriptkit_draw_current_title "融合怪自定义参数"
    printf '%b' "$(ui_prompt "输入" "请输入参数（空格分隔，例如 -m 5 1 1 -en）: ")"
    read -r ecs_args
    ecs_args="${ecs_args:-}"
    if [ -z "$ecs_args" ]; then
        ui_warn "未输入参数。"
        return 1
    fi
    bench_ecs_toolbox_run "custom" "SCRIPTKIT_ECS_ARGS=$ecs_args"
}

bench_ecs_ipcheck_run() { bench_ecs_toolbox_run "ipcheck"; }
bench_ecs_custom_ipcheck_run() { bench_ecs_toolbox_run "custom_ipcheck"; }

add_menu "bench_ecs" "ECS / 融合怪" "bench"
add_action "bench_ecs_interactive" "交互执行" "bench_ecs" "bench_ecs_interactive_run"
add_action "bench_ecs_full" "完整测试 (-m 1)" "bench_ecs" "bench_ecs_full_run"
add_action "bench_ecs_base" "基础信息 (-base)" "bench_ecs" "bench_ecs_base_run"
add_action "bench_ecs_custom" "自定义参数" "bench_ecs" "bench_ecs_custom_run"
add_menu "bench_ecs_ip_quality" "IP 质量检测" "bench_ecs"
add_action "bench_ecs_ip_quality_fusion" "融合怪 IP 质量检测" "bench_ecs_ip_quality" "bench_ecs_ipcheck_run"
add_action "bench_ecs_ip_quality_custom" "自定义 IP 质量检测" "bench_ecs_ip_quality" "bench_ecs_custom_ipcheck_run"

add_script "bench_disk_hdsentinel" "磁盘健康检测" "bench" "modules/standalone/disk_test.sh"

add_menu "bench_yabs" "YABS / Yet-Another-Bench-Script" "bench"
add_action "bench_yabs_default" "默认执行" "bench_yabs" "bench_yabs_default_run"
add_action "bench_yabs_reduced" "低流量模式 (-r)" "bench_yabs" "bench_yabs_reduced_run"
add_action "bench_yabs_system_disk" "仅系统+磁盘 (-i)" "bench_yabs" "bench_yabs_system_disk_run"
add_action "bench_yabs_network_only" "仅网络测试 (-fg)" "bench_yabs" "bench_yabs_network_only_run"
add_action "bench_yabs_json" "屏幕输出 JSON (-j)" "bench_yabs" "bench_yabs_json_run"
add_action "bench_yabs_json_file" "写入 JSON 文件 (-w)" "bench_yabs" "bench_yabs_json_file_run"
add_menu "bench_yabs_geekbench" "Geekbench 版本" "bench_yabs"
add_action "bench_yabs_gb4" "Geekbench 4 (-4)" "bench_yabs_geekbench" "bench_yabs_gb4_run"
add_action "bench_yabs_gb5" "Geekbench 5 (-5)" "bench_yabs_geekbench" "bench_yabs_gb5_run"
add_action "bench_yabs_gb45" "Geekbench 4+5 (-9)" "bench_yabs_geekbench" "bench_yabs_gb45_run"
add_action "bench_yabs_help" "帮助信息 (-h)" "bench_yabs" "bench_yabs_help_run"
add_action "bench_yabs_custom" "自定义参数" "bench_yabs" "bench_yabs_custom_run"

add_menu "bench_nodequality" "NodeQuality / 无痕综合测试" "bench"
add_action "bench_nodequality_interactive" "交互执行" "bench_nodequality" "bench_nodequality_interactive_run"
add_action "bench_nodequality_default" "默认全量" "bench_nodequality" "bench_nodequality_default_run"
add_action "bench_nodequality_ipv4" "IPv4 默认全量" "bench_nodequality" "bench_nodequality_ipv4_run"
add_action "bench_nodequality_ipv6" "IPv6 默认全量" "bench_nodequality" "bench_nodequality_ipv6_run"
add_action "bench_nodequality_english" "英文默认全量" "bench_nodequality" "bench_nodequality_english_run"
add_menu "bench_nodequality_hardware" "硬件质量" "bench_nodequality"
add_action "bench_nodequality_hardware_only" "仅硬件质量" "bench_nodequality_hardware" "bench_nodequality_hardware_run"
add_action "bench_nodequality_hardware_fast" "硬件质量快速" "bench_nodequality_hardware" "bench_nodequality_hardware_fast_run"
add_action "bench_nodequality_hardware_verbose" "硬件质量深度" "bench_nodequality_hardware" "bench_nodequality_hardware_verbose_run"
add_menu "bench_nodequality_special" "专项测试" "bench_nodequality"
add_action "bench_nodequality_ip_only" "仅 IP 质量" "bench_nodequality_special" "bench_nodequality_ip_run"
add_action "bench_nodequality_net_only" "仅网络质量" "bench_nodequality_special" "bench_nodequality_net_run"
add_action "bench_nodequality_net_lite" "仅网络质量（低流量）" "bench_nodequality_special" "bench_nodequality_net_lite_run"
add_action "bench_nodequality_trace_only" "仅回程追踪" "bench_nodequality_special" "bench_nodequality_trace_run"

add_menu "bench_ipquality" "IPQuality / IP质量体检" "bench"
add_action "bench_ipquality_default" "默认双栈" "bench_ipquality" "bench_ipquality_default_run"
add_action "bench_ipquality_ipv4" "仅 IPv4 (-4)" "bench_ipquality" "bench_ipquality_ipv4_run"
add_action "bench_ipquality_ipv6" "仅 IPv6 (-6)" "bench_ipquality" "bench_ipquality_ipv6_run"
add_action "bench_ipquality_fullip" "完整 IP (-f)" "bench_ipquality" "bench_ipquality_fullip_run"
add_action "bench_ipquality_english" "英文输出 (-E)" "bench_ipquality" "bench_ipquality_english_run"
add_action "bench_ipquality_json" "屏幕输出 JSON (-j)" "bench_ipquality" "bench_ipquality_json_run"
add_action "bench_ipquality_privacy" "隐私模式 (-p)" "bench_ipquality" "bench_ipquality_privacy_run"
add_menu "bench_ipquality_output" "输出到文件" "bench_ipquality"
add_action "bench_ipquality_output_ansi" "ANSI 报告文件" "bench_ipquality_output" "bench_ipquality_ansi_file_run"
add_action "bench_ipquality_output_json" "JSON 报告文件" "bench_ipquality_output" "bench_ipquality_json_file_run"
add_action "bench_ipquality_output_text" "纯文本报告文件" "bench_ipquality_output" "bench_ipquality_text_file_run"
add_menu "bench_ipquality_targeted" "定向检测" "bench_ipquality"
add_action "bench_ipquality_interface" "指定网卡或出口 IP" "bench_ipquality_targeted" "bench_ipquality_interface_run"
add_action "bench_ipquality_proxy" "指定代理" "bench_ipquality_targeted" "bench_ipquality_proxy_run"
add_menu "bench_ipquality_advanced" "高级模式" "bench_ipquality"
add_action "bench_ipquality_skip_dep" "跳过依赖检查 (-n)" "bench_ipquality_advanced" "bench_ipquality_skip_dep_run"
add_action "bench_ipquality_auto_install" "自动安装依赖 (-y)" "bench_ipquality_advanced" "bench_ipquality_auto_install_run"
add_action "bench_ipquality_ipv4_full" "IPv4 + 完整 IP" "bench_ipquality_advanced" "bench_ipquality_ipv4_full_run"
add_action "bench_ipquality_custom" "自定义参数" "bench_ipquality_advanced" "bench_ipquality_custom_run"

add_menu "bench_regioncheck" "RegionRestrictionCheck / 流媒体解锁" "bench"
add_action "bench_regioncheck_interactive" "交互选区" "bench_regioncheck" "bench_regioncheck_interactive_run"
add_action "bench_regioncheck_all" "全部平台 (-R 66)" "bench_regioncheck" "bench_regioncheck_all_run"
add_action "bench_regioncheck_global" "仅跨国平台 (-R 0)" "bench_regioncheck" "bench_regioncheck_global_run"
add_action "bench_regioncheck_instagram" "Instagram 音乐 (-R 88)" "bench_regioncheck" "bench_regioncheck_instagram_run"
add_action "bench_regioncheck_sport" "体育直播平台 (-R 99)" "bench_regioncheck" "bench_regioncheck_sport_run"
add_action "bench_regioncheck_ipv4_all" "仅 IPv4 全平台" "bench_regioncheck" "bench_regioncheck_ipv4_all_run"
add_action "bench_regioncheck_ipv6_all" "仅 IPv6 全平台" "bench_regioncheck" "bench_regioncheck_ipv6_all_run"
add_action "bench_regioncheck_english_all" "英文全平台" "bench_regioncheck" "bench_regioncheck_english_all_run"
add_menu "bench_regioncheck_regions" "地区分组" "bench_regioncheck"
add_action "bench_regioncheck_region_tw" "台湾分组 (1)" "bench_regioncheck_regions" "bench_regioncheck_region_tw_run"
add_action "bench_regioncheck_region_hk" "香港分组 (2)" "bench_regioncheck_regions" "bench_regioncheck_region_hk_run"
add_action "bench_regioncheck_region_jp" "日本分组 (3)" "bench_regioncheck_regions" "bench_regioncheck_region_jp_run"
add_action "bench_regioncheck_region_na" "北美分组 (4)" "bench_regioncheck_regions" "bench_regioncheck_region_na_run"
add_action "bench_regioncheck_region_sa" "南美分组 (5)" "bench_regioncheck_regions" "bench_regioncheck_region_sa_run"
add_action "bench_regioncheck_region_eu" "欧洲分组 (6)" "bench_regioncheck_regions" "bench_regioncheck_region_eu_run"
add_action "bench_regioncheck_region_oa" "大洋洲分组 (7)" "bench_regioncheck_regions" "bench_regioncheck_region_oa_run"
add_action "bench_regioncheck_region_kr" "韩国分组 (8)" "bench_regioncheck_regions" "bench_regioncheck_region_kr_run"
add_action "bench_regioncheck_region_sea" "东南亚分组 (9)" "bench_regioncheck_regions" "bench_regioncheck_region_sea_run"
add_action "bench_regioncheck_region_in" "印度分组 (10)" "bench_regioncheck_regions" "bench_regioncheck_region_in_run"
add_action "bench_regioncheck_region_af" "非洲分组 (11)" "bench_regioncheck_regions" "bench_regioncheck_region_af_run"
add_menu "bench_regioncheck_targeted" "定向检测" "bench_regioncheck"
add_action "bench_regioncheck_interface" "指定网卡" "bench_regioncheck_targeted" "bench_regioncheck_interface_run"
add_action "bench_regioncheck_proxy" "指定代理" "bench_regioncheck_targeted" "bench_regioncheck_proxy_run"
add_action "bench_regioncheck_xff" "自定义 X-Forwarded-For" "bench_regioncheck_targeted" "bench_regioncheck_xff_run"
add_action "bench_regioncheck_custom" "自定义参数" "bench_regioncheck" "bench_regioncheck_custom_run"
