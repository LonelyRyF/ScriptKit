#!/usr/bin/env bash

# Test tools module.

test_toolbox_run() {
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

test_prompt_custom_args() {
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

    test_toolbox_run "$tool" "$mode" "SCRIPTKIT_TEST_ARGS=$args"
}

test_prompt_value_run() {
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

    test_toolbox_run "$tool" "$mode" "$env_name=$value"
}

test_yabs_default_run() { test_toolbox_run "yabs" "default"; }
test_yabs_reduced_run() { test_toolbox_run "yabs" "reduced"; }
test_yabs_system_disk_run() { test_toolbox_run "yabs" "system_disk"; }
test_yabs_network_only_run() { test_toolbox_run "yabs" "network_only"; }
test_yabs_json_run() { test_toolbox_run "yabs" "json"; }
test_yabs_json_file_run() { test_toolbox_run "yabs" "json_file"; }
test_yabs_help_run() { test_toolbox_run "yabs" "help"; }
test_yabs_gb4_run() { test_toolbox_run "yabs" "gb4"; }
test_yabs_gb5_run() { test_toolbox_run "yabs" "gb5"; }
test_yabs_gb45_run() { test_toolbox_run "yabs" "gb45"; }

test_yabs_custom_run() {
    test_prompt_custom_args \
        "YABS 自定义参数" \
        "请输入参数（例如 -r -5 -j 或 -w /root/yabs.json）: " \
        "yabs" \
        "custom"
}

test_nodequality_interactive_run() { test_toolbox_run "nodequality" "interactive"; }
test_nodequality_default_run() { test_toolbox_run "nodequality" "default"; }
test_nodequality_ipv4_run() { test_toolbox_run "nodequality" "ipv4_default"; }
test_nodequality_ipv6_run() { test_toolbox_run "nodequality" "ipv6_default"; }
test_nodequality_english_run() { test_toolbox_run "nodequality" "english_default"; }
test_nodequality_hardware_run() { test_toolbox_run "nodequality" "hardware_only"; }
test_nodequality_hardware_fast_run() { test_toolbox_run "nodequality" "hardware_fast"; }
test_nodequality_hardware_verbose_run() { test_toolbox_run "nodequality" "hardware_verbose"; }
test_nodequality_ip_run() { test_toolbox_run "nodequality" "ip_only"; }
test_nodequality_net_run() { test_toolbox_run "nodequality" "net_only"; }
test_nodequality_net_lite_run() { test_toolbox_run "nodequality" "net_lite"; }
test_nodequality_trace_run() { test_toolbox_run "nodequality" "trace_only"; }

test_ipquality_default_run() { test_toolbox_run "ipquality" "default"; }
test_ipquality_ipv4_run() { test_toolbox_run "ipquality" "ipv4"; }
test_ipquality_ipv6_run() { test_toolbox_run "ipquality" "ipv6"; }
test_ipquality_fullip_run() { test_toolbox_run "ipquality" "fullip"; }
test_ipquality_english_run() { test_toolbox_run "ipquality" "english"; }
test_ipquality_json_run() { test_toolbox_run "ipquality" "json"; }
test_ipquality_privacy_run() { test_toolbox_run "ipquality" "privacy"; }
test_ipquality_ansi_file_run() { test_toolbox_run "ipquality" "ansi_file"; }
test_ipquality_json_file_run() { test_toolbox_run "ipquality" "json_file"; }
test_ipquality_text_file_run() { test_toolbox_run "ipquality" "text_file"; }
test_ipquality_skip_dep_run() { test_toolbox_run "ipquality" "skip_dep"; }
test_ipquality_auto_install_run() { test_toolbox_run "ipquality" "auto_install"; }
test_ipquality_ipv4_full_run() { test_toolbox_run "ipquality" "ipv4_full"; }

test_ipquality_interface_run() {
    test_prompt_value_run \
        "IPQuality 指定网卡或出口 IP" \
        "请输入网卡名或出口 IP（例如 eth0 或 203.0.113.1）: " \
        "ipquality" \
        "interface" \
        "SCRIPTKIT_TEST_INTERFACE"
}

test_ipquality_proxy_run() {
    test_prompt_value_run \
        "IPQuality 指定代理" \
        "请输入代理地址（例如 socks5://user:pass@host:port）: " \
        "ipquality" \
        "proxy" \
        "SCRIPTKIT_TEST_PROXY"
}

test_ipquality_custom_run() {
    test_prompt_custom_args \
        "IPQuality 自定义参数" \
        "请输入参数（例如 -4 -f -p 或 -o /root/ipquality.json）: " \
        "ipquality" \
        "custom"
}

test_regioncheck_interactive_run() { test_toolbox_run "regioncheck" "interactive"; }
test_regioncheck_all_run() { test_toolbox_run "regioncheck" "all"; }
test_regioncheck_global_run() { test_toolbox_run "regioncheck" "global"; }
test_regioncheck_instagram_run() { test_toolbox_run "regioncheck" "instagram"; }
test_regioncheck_sport_run() { test_toolbox_run "regioncheck" "sport"; }
test_regioncheck_ipv4_all_run() { test_toolbox_run "regioncheck" "ipv4_all"; }
test_regioncheck_ipv6_all_run() { test_toolbox_run "regioncheck" "ipv6_all"; }
test_regioncheck_english_all_run() { test_toolbox_run "regioncheck" "english_all"; }

test_regioncheck_region_run() {
    local region_id="$1"
    test_toolbox_run "regioncheck" "region" "SCRIPTKIT_TEST_REGION=$region_id"
}

test_regioncheck_region_tw_run() { test_regioncheck_region_run "1"; }
test_regioncheck_region_hk_run() { test_regioncheck_region_run "2"; }
test_regioncheck_region_jp_run() { test_regioncheck_region_run "3"; }
test_regioncheck_region_na_run() { test_regioncheck_region_run "4"; }
test_regioncheck_region_sa_run() { test_regioncheck_region_run "5"; }
test_regioncheck_region_eu_run() { test_regioncheck_region_run "6"; }
test_regioncheck_region_oa_run() { test_regioncheck_region_run "7"; }
test_regioncheck_region_kr_run() { test_regioncheck_region_run "8"; }
test_regioncheck_region_sea_run() { test_regioncheck_region_run "9"; }
test_regioncheck_region_in_run() { test_regioncheck_region_run "10"; }
test_regioncheck_region_af_run() { test_regioncheck_region_run "11"; }

test_regioncheck_interface_run() {
    test_prompt_value_run \
        "RegionRestrictionCheck 指定网卡" \
        "请输入网卡名（例如 eth0）: " \
        "regioncheck" \
        "interface" \
        "SCRIPTKIT_TEST_INTERFACE"
}

test_regioncheck_proxy_run() {
    test_prompt_value_run \
        "RegionRestrictionCheck 指定代理" \
        "请输入代理地址（例如 socks5://user:pass@host:port）: " \
        "regioncheck" \
        "proxy" \
        "SCRIPTKIT_TEST_PROXY"
}

test_regioncheck_xff_run() {
    test_prompt_value_run \
        "RegionRestrictionCheck 自定义 X-Forwarded-For" \
        "请输入自定义出口 IP（例如 203.0.113.1 或 2001:db8::1）: " \
        "regioncheck" \
        "xff" \
        "SCRIPTKIT_TEST_XFF"
}

test_regioncheck_custom_run() {
    test_prompt_custom_args \
        "RegionRestrictionCheck 自定义参数" \
        "请输入参数（例如 -M 4 -R 3 或 -I eth0 -R 66）: " \
        "regioncheck" \
        "custom"
}

add_script "test_disk_hdsentinel" "磁盘健康检测" "test" "modules/standalone/disk_test.sh"

add_menu "test_yabs" "YABS / Yet-Another-Bench-Script" "test"
add_action "test_yabs_default" "默认执行" "test_yabs" "test_yabs_default_run"
add_action "test_yabs_reduced" "低流量模式 (-r)" "test_yabs" "test_yabs_reduced_run"
add_action "test_yabs_system_disk" "仅系统+磁盘 (-i)" "test_yabs" "test_yabs_system_disk_run"
add_action "test_yabs_network_only" "仅网络测试 (-fg)" "test_yabs" "test_yabs_network_only_run"
add_action "test_yabs_json" "屏幕输出 JSON (-j)" "test_yabs" "test_yabs_json_run"
add_action "test_yabs_json_file" "写入 JSON 文件 (-w)" "test_yabs" "test_yabs_json_file_run"
add_menu "test_yabs_geekbench" "Geekbench 版本" "test_yabs"
add_action "test_yabs_gb4" "Geekbench 4 (-4)" "test_yabs_geekbench" "test_yabs_gb4_run"
add_action "test_yabs_gb5" "Geekbench 5 (-5)" "test_yabs_geekbench" "test_yabs_gb5_run"
add_action "test_yabs_gb45" "Geekbench 4+5 (-9)" "test_yabs_geekbench" "test_yabs_gb45_run"
add_action "test_yabs_help" "帮助信息 (-h)" "test_yabs" "test_yabs_help_run"
add_action "test_yabs_custom" "自定义参数" "test_yabs" "test_yabs_custom_run"

add_menu "test_nodequality" "NodeQuality / 无痕综合测试" "test"
add_action "test_nodequality_interactive" "交互执行" "test_nodequality" "test_nodequality_interactive_run"
add_action "test_nodequality_default" "默认全量" "test_nodequality" "test_nodequality_default_run"
add_action "test_nodequality_ipv4" "IPv4 默认全量" "test_nodequality" "test_nodequality_ipv4_run"
add_action "test_nodequality_ipv6" "IPv6 默认全量" "test_nodequality" "test_nodequality_ipv6_run"
add_action "test_nodequality_english" "英文默认全量" "test_nodequality" "test_nodequality_english_run"
add_menu "test_nodequality_hardware" "硬件质量" "test_nodequality"
add_action "test_nodequality_hardware_only" "仅硬件质量" "test_nodequality_hardware" "test_nodequality_hardware_run"
add_action "test_nodequality_hardware_fast" "硬件质量快速" "test_nodequality_hardware" "test_nodequality_hardware_fast_run"
add_action "test_nodequality_hardware_verbose" "硬件质量深度" "test_nodequality_hardware" "test_nodequality_hardware_verbose_run"
add_menu "test_nodequality_special" "专项测试" "test_nodequality"
add_action "test_nodequality_ip_only" "仅 IP 质量" "test_nodequality_special" "test_nodequality_ip_run"
add_action "test_nodequality_net_only" "仅网络质量" "test_nodequality_special" "test_nodequality_net_run"
add_action "test_nodequality_net_lite" "仅网络质量（低流量）" "test_nodequality_special" "test_nodequality_net_lite_run"
add_action "test_nodequality_trace_only" "仅回程追踪" "test_nodequality_special" "test_nodequality_trace_run"

add_menu "test_ipquality" "IPQuality / IP质量体检" "test"
add_action "test_ipquality_default" "默认双栈" "test_ipquality" "test_ipquality_default_run"
add_action "test_ipquality_ipv4" "仅 IPv4 (-4)" "test_ipquality" "test_ipquality_ipv4_run"
add_action "test_ipquality_ipv6" "仅 IPv6 (-6)" "test_ipquality" "test_ipquality_ipv6_run"
add_action "test_ipquality_fullip" "完整 IP (-f)" "test_ipquality" "test_ipquality_fullip_run"
add_action "test_ipquality_english" "英文输出 (-E)" "test_ipquality" "test_ipquality_english_run"
add_action "test_ipquality_json" "屏幕输出 JSON (-j)" "test_ipquality" "test_ipquality_json_run"
add_action "test_ipquality_privacy" "隐私模式 (-p)" "test_ipquality" "test_ipquality_privacy_run"
add_menu "test_ipquality_output" "输出到文件" "test_ipquality"
add_action "test_ipquality_output_ansi" "ANSI 报告文件" "test_ipquality_output" "test_ipquality_ansi_file_run"
add_action "test_ipquality_output_json" "JSON 报告文件" "test_ipquality_output" "test_ipquality_json_file_run"
add_action "test_ipquality_output_text" "纯文本报告文件" "test_ipquality_output" "test_ipquality_text_file_run"
add_menu "test_ipquality_targeted" "定向检测" "test_ipquality"
add_action "test_ipquality_interface" "指定网卡或出口 IP" "test_ipquality_targeted" "test_ipquality_interface_run"
add_action "test_ipquality_proxy" "指定代理" "test_ipquality_targeted" "test_ipquality_proxy_run"
add_menu "test_ipquality_advanced" "高级模式" "test_ipquality"
add_action "test_ipquality_skip_dep" "跳过依赖检查 (-n)" "test_ipquality_advanced" "test_ipquality_skip_dep_run"
add_action "test_ipquality_auto_install" "自动安装依赖 (-y)" "test_ipquality_advanced" "test_ipquality_auto_install_run"
add_action "test_ipquality_ipv4_full" "IPv4 + 完整 IP" "test_ipquality_advanced" "test_ipquality_ipv4_full_run"
add_action "test_ipquality_custom" "自定义参数" "test_ipquality_advanced" "test_ipquality_custom_run"

add_menu "test_regioncheck" "RegionRestrictionCheck / 流媒体解锁" "test"
add_action "test_regioncheck_interactive" "交互选区" "test_regioncheck" "test_regioncheck_interactive_run"
add_action "test_regioncheck_all" "全部平台 (-R 66)" "test_regioncheck" "test_regioncheck_all_run"
add_action "test_regioncheck_global" "仅跨国平台 (-R 0)" "test_regioncheck" "test_regioncheck_global_run"
add_action "test_regioncheck_instagram" "Instagram 音乐 (-R 88)" "test_regioncheck" "test_regioncheck_instagram_run"
add_action "test_regioncheck_sport" "体育直播平台 (-R 99)" "test_regioncheck" "test_regioncheck_sport_run"
add_action "test_regioncheck_ipv4_all" "仅 IPv4 全平台" "test_regioncheck" "test_regioncheck_ipv4_all_run"
add_action "test_regioncheck_ipv6_all" "仅 IPv6 全平台" "test_regioncheck" "test_regioncheck_ipv6_all_run"
add_action "test_regioncheck_english_all" "英文全平台" "test_regioncheck" "test_regioncheck_english_all_run"
add_menu "test_regioncheck_regions" "地区分组" "test_regioncheck"
add_action "test_regioncheck_region_tw" "台湾分组 (1)" "test_regioncheck_regions" "test_regioncheck_region_tw_run"
add_action "test_regioncheck_region_hk" "香港分组 (2)" "test_regioncheck_regions" "test_regioncheck_region_hk_run"
add_action "test_regioncheck_region_jp" "日本分组 (3)" "test_regioncheck_regions" "test_regioncheck_region_jp_run"
add_action "test_regioncheck_region_na" "北美分组 (4)" "test_regioncheck_regions" "test_regioncheck_region_na_run"
add_action "test_regioncheck_region_sa" "南美分组 (5)" "test_regioncheck_regions" "test_regioncheck_region_sa_run"
add_action "test_regioncheck_region_eu" "欧洲分组 (6)" "test_regioncheck_regions" "test_regioncheck_region_eu_run"
add_action "test_regioncheck_region_oa" "大洋洲分组 (7)" "test_regioncheck_regions" "test_regioncheck_region_oa_run"
add_action "test_regioncheck_region_kr" "韩国分组 (8)" "test_regioncheck_regions" "test_regioncheck_region_kr_run"
add_action "test_regioncheck_region_sea" "东南亚分组 (9)" "test_regioncheck_regions" "test_regioncheck_region_sea_run"
add_action "test_regioncheck_region_in" "印度分组 (10)" "test_regioncheck_regions" "test_regioncheck_region_in_run"
add_action "test_regioncheck_region_af" "非洲分组 (11)" "test_regioncheck_regions" "test_regioncheck_region_af_run"
add_menu "test_regioncheck_targeted" "定向检测" "test_regioncheck"
add_action "test_regioncheck_interface" "指定网卡" "test_regioncheck_targeted" "test_regioncheck_interface_run"
add_action "test_regioncheck_proxy" "指定代理" "test_regioncheck_targeted" "test_regioncheck_proxy_run"
add_action "test_regioncheck_xff" "自定义 X-Forwarded-For" "test_regioncheck_targeted" "test_regioncheck_xff_run"
add_action "test_regioncheck_custom" "自定义参数" "test_regioncheck" "test_regioncheck_custom_run"
