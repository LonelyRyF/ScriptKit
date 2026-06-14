#!/usr/bin/env bash

add_menu "proxy" "代理工具" "main"

proxy_toolbox_run() {
    local tool="$1"
    local mode="$2"
    local workdir="${HOME:-/root}/.scriptkit/proxy/$tool"

    shift 2

    run_standalone_with_env "modules/standalone/proxy_toolbox.sh" \
        "SCRIPTKIT_PROXY_TOOL=$tool" \
        "SCRIPTKIT_PROXY_MODE=$mode" \
        "SCRIPTKIT_PROXY_WORKDIR=$workdir" \
        "$@"
}

proxy_prompt_custom_args() {
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

    proxy_toolbox_run "$tool" "$mode" "SCRIPTKIT_PROXY_ARGS=$args"
}

proxy_prompt_value_run() {
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

    proxy_toolbox_run "$tool" "$mode" "$env_name=$value"
}

proxy_singbox_233box_install_run() {
    proxy_toolbox_run "singbox_233box" "install"
}

proxy_singbox_233box_help_run() {
    proxy_toolbox_run "singbox_233box" "help"
}

proxy_singbox_233box_proxy_run() {
    proxy_prompt_value_run \
        "233box 指定下载代理" \
        "请输入代理地址（例如 http://127.0.0.1:2333 或 socks5://127.0.0.1:2333）: " \
        "singbox_233box" \
        "proxy" \
        "SCRIPTKIT_PROXY_VALUE"
}

proxy_singbox_233box_version_run() {
    proxy_prompt_value_run \
        "233box 指定内核版本" \
        "请输入 sing-box 内核版本（例如 v1.12.0）: " \
        "singbox_233box" \
        "version" \
        "SCRIPTKIT_PROXY_VALUE"
}

proxy_singbox_233box_custom_run() {
    proxy_prompt_custom_args \
        "233box 自定义安装参数" \
        "请输入参数（例如 -p http://127.0.0.1:2333 或 -v v1.12.0）: " \
        "singbox_233box" \
        "custom"
}

proxy_singbox_fscarmen_interactive_run() {
    proxy_toolbox_run "singbox_fscarmen" "interactive"
}

proxy_singbox_fscarmen_quick_cn_run() {
    proxy_toolbox_run "singbox_fscarmen" "quick_cn"
}

proxy_singbox_fscarmen_quick_en_run() {
    proxy_toolbox_run "singbox_fscarmen" "quick_en"
}

proxy_singbox_fscarmen_nodes_run() {
    proxy_toolbox_run "singbox_fscarmen" "nodes"
}

proxy_singbox_fscarmen_edit_run() {
    proxy_toolbox_run "singbox_fscarmen" "edit"
}

proxy_singbox_fscarmen_service_run() {
    proxy_toolbox_run "singbox_fscarmen" "service"
}

proxy_singbox_fscarmen_argo_run() {
    proxy_toolbox_run "singbox_fscarmen" "argo"
}

proxy_singbox_fscarmen_update_run() {
    proxy_toolbox_run "singbox_fscarmen" "update"
}

proxy_singbox_fscarmen_system_run() {
    proxy_toolbox_run "singbox_fscarmen" "system"
}

proxy_singbox_fscarmen_protocols_run() {
    proxy_toolbox_run "singbox_fscarmen" "protocols"
}

proxy_singbox_fscarmen_uninstall_run() {
    proxy_toolbox_run "singbox_fscarmen" "uninstall"
}

proxy_singbox_fscarmen_custom_run() {
    proxy_prompt_custom_args \
        "fscarmen 自定义参数" \
        "请输入参数（例如 -l / -n / -d / -r）: " \
        "singbox_fscarmen" \
        "custom"
}

proxy_singbox_yg_vps_run() {
    proxy_toolbox_run "singbox_yg" "vps"
}

proxy_singbox_yg_vps_preset_run() {
    local use_old_core="0"
    local use_domain_cert="0"
    local custom_ports="0"
    local allow_ports="1"

    scriptkit_draw_current_title "Sing-box-yg 基础交互式安装"

    if yesno_select "使用旧版 sing-box 内核 1.10.7？" "n"; then
        use_old_core="1"
    fi

    if yesno_select "使用已申请的 Acme 域名证书？未申请时会回退到自签证书。" "n"; then
        use_domain_cert="1"
    fi

    if yesno_select "是否自定义协议端口？选择否则自动随机生成。" "n"; then
        custom_ports="1"
    fi

    if ! yesno_select "是否开放端口并关闭防火墙？" "y"; then
        allow_ports="0"
    fi

    proxy_toolbox_run \
        "singbox_yg" \
        "vps_preset" \
        "SCRIPTKIT_SINGBOX_YG_USE_OLD_CORE=$use_old_core" \
        "SCRIPTKIT_SINGBOX_YG_USE_DOMAIN_CERT=$use_domain_cert" \
        "SCRIPTKIT_SINGBOX_YG_CUSTOM_PORTS=$custom_ports" \
        "SCRIPTKIT_SINGBOX_YG_ALLOW_PORTS=$allow_ports"
}

proxy_singbox_yg_serv00_run() {
    proxy_toolbox_run "singbox_yg" "serv00"
}

proxy_3xui_install_run() {
    proxy_toolbox_run "3xui" "install"
}

proxy_3xui_start_run() {
    proxy_toolbox_run "3xui" "start"
}

proxy_3xui_stop_run() {
    proxy_toolbox_run "3xui" "stop"
}

proxy_3xui_restart_run() {
    proxy_toolbox_run "3xui" "restart"
}

proxy_3xui_status_run() {
    proxy_toolbox_run "3xui" "status"
}

proxy_3xui_settings_run() {
    proxy_toolbox_run "3xui" "settings"
}

proxy_3xui_enable_run() {
    proxy_toolbox_run "3xui" "enable"
}

proxy_3xui_disable_run() {
    proxy_toolbox_run "3xui" "disable"
}

proxy_3xui_log_run() {
    proxy_toolbox_run "3xui" "log"
}

proxy_3xui_update_run() {
    proxy_toolbox_run "3xui" "update"
}

proxy_3xui_uninstall_run() {
    proxy_toolbox_run "3xui" "uninstall"
}

proxy_3xui_custom_run() {
    proxy_prompt_custom_args \
        "3x-ui 自定义子命令" \
        "请输入子命令（例如 restart-xray / legacy / settings）: " \
        "3xui" \
        "custom"
}

proxy_realm_xwpf_install_run() {
    proxy_toolbox_run "realm_xwpf" "install"
}

proxy_realm_xwpf_menu_run() {
    proxy_toolbox_run "realm_xwpf" "menu"
}

proxy_realm_xwpf_speedtest_run() {
    proxy_toolbox_run "realm_xwpf" "speedtest"
}

proxy_realm_xwpf_dog_run() {
    proxy_toolbox_run "realm_xwpf" "dog"
}

proxy_realm_xwpf_custom_run() {
    proxy_prompt_custom_args \
        "realm-xwPF 自定义参数" \
        "请输入参数（例如 install / --help 或其他上游参数）: " \
        "realm_xwpf" \
        "custom"
}

proxy_v2ray_agent_install_run() {
    proxy_toolbox_run "v2ray_agent" "install"
}

proxy_v2ray_agent_docker_run() {
    proxy_toolbox_run "v2ray_agent" "docker_reality"
}

proxy_v2ray_agent_docker_help_run() {
    proxy_toolbox_run "v2ray_agent" "docker_reality_help"
}

proxy_v2ray_agent_docker_custom_run() {
    proxy_prompt_custom_args \
        "v2ray-agent Docker Reality 自定义参数" \
        "请输入参数（例如 --non-interactive --install-mode vision --port 443）: " \
        "v2ray_agent" \
        "docker_reality_custom"
}

proxy_hysteria2_install_menu_run() {
    proxy_toolbox_run "hysteria2_install" "menu"
}

proxy_hysteria2_install_preset_run() {
    local cert_mode="1"
    local cert_choice=""
    local cert_path=""
    local key_path=""
    local domain_value=""
    local port_mode="random"
    local jump_mode="single"
    local jump_start=""
    local jump_end=""
    local port_value=""
    local password_value=""
    local masquerade_site=""

    scriptkit_draw_current_title "Hysteria 2 交互式安装"

    cert_choice="$(pick_from_options \
        "证书模式" \
        "必应自签证书（默认）" \
        "Acme 自动申请" \
        "自定义证书路径")" || return 1

    case "$cert_choice" in
        "Acme 自动申请")
            cert_mode="2"
            printf '%b' "$(ui_prompt "输入" "请输入申请/复用证书的域名（已有证书时可留空）: ")"
            read -r domain_value
            domain_value="${domain_value:-}"
            ;;
        "自定义证书路径")
            cert_mode="3"

            printf '%b' "$(ui_prompt "输入" "请输入公钥文件 crt 路径: ")"
            read -r cert_path
            cert_path="${cert_path:-}"

            printf '%b' "$(ui_prompt "输入" "请输入私钥文件 key 路径: ")"
            read -r key_path
            key_path="${key_path:-}"

            printf '%b' "$(ui_prompt "输入" "请输入证书域名: ")"
            read -r domain_value
            domain_value="${domain_value:-}"

            if [ -z "$cert_path" ] || [ -z "$key_path" ] || [ -z "$domain_value" ]; then
                ui_warn "自定义证书模式下，crt 路径、key 路径和域名都不能为空。"
                return 1
            fi
            ;;
        *)
            cert_mode="1"
            ;;
    esac

    if yesno_select "是否自定义 Hysteria 2 主端口？" "n"; then
        port_mode="custom"
        printf '%b' "$(ui_prompt "输入" "请输入主端口（1-65535）: ")"
        read -r port_value
        if ! validate_port "${port_value:-}"; then
            ui_warn "端口无效，改为随机端口。"
            port_mode="random"
            port_value=""
        fi
    fi

    if yesno_select "是否启用端口跳跃？" "n"; then
        jump_mode="range"
        printf '%b' "$(ui_prompt "输入" "请输入跳跃起始端口（建议 10000-65535）: ")"
        read -r jump_start
        printf '%b' "$(ui_prompt "输入" "请输入跳跃结束端口（必须大于起始端口）: ")"
        read -r jump_end
        if ! validate_port "${jump_start:-}" || ! validate_port "${jump_end:-}" || [ "$jump_start" -ge "$jump_end" ]; then
            ui_warn "跳跃端口范围无效，改为单端口模式。"
            jump_mode="single"
            jump_start=""
            jump_end=""
        fi
    fi

    printf '%b' "$(ui_prompt "输入" "请输入密码（回车随机生成）: ")"
    read -r password_value
    password_value="${password_value:-}"

    printf '%b' "$(ui_prompt "输入" "请输入伪装网站（回车默认 en.snu.ac.kr）: ")"
    read -r masquerade_site
    masquerade_site="${masquerade_site:-}"

    proxy_toolbox_run \
        "hysteria2_install" \
        "preset_install" \
        "SCRIPTKIT_HY2_CERT_MODE=$cert_mode" \
        "SCRIPTKIT_HY2_PORT_MODE=$port_mode" \
        "SCRIPTKIT_HY2_PORT=$port_value" \
        "SCRIPTKIT_HY2_JUMP_MODE=$jump_mode" \
        "SCRIPTKIT_HY2_JUMP_START=$jump_start" \
        "SCRIPTKIT_HY2_JUMP_END=$jump_end" \
        "SCRIPTKIT_HY2_CERT_PATH=$cert_path" \
        "SCRIPTKIT_HY2_KEY_PATH=$key_path" \
        "SCRIPTKIT_HY2_DOMAIN=$domain_value" \
        "SCRIPTKIT_HY2_PASSWORD=$password_value" \
        "SCRIPTKIT_HY2_SITE=$masquerade_site"
}

proxy_hysteria2_seagullz4_shell_run() {
    proxy_toolbox_run "hysteria2_seagullz4" "shell"
}

proxy_hysteria2_seagullz4_quick_run() {
    local version_mode="latest"
    local version_choice=""
    local version_value=""
    local cert_choice=""
    local cert_mode="selfsigned"
    local cert_domain=""
    local acme_email=""
    local cert_path=""
    local key_path=""
    local server_addr=""
    local port_value="443"
    local node_name="hy2"
    local password_value=""
    local masquerade_url="https://bing.com"
    local brutal_mode="0"
    local obfs_mode="0"
    local obfs_password=""
    local sniff_mode="0"

    scriptkit_draw_current_title "Hysteria 2 轻量交互式安装"

    version_choice="$(pick_from_options "安装版本" "最新版本（默认）" "指定版本")" || return 1
    if [ "$version_choice" = "指定版本" ]; then
        version_mode="custom"
        printf '%b' "$(ui_prompt "输入" "请输入版本号（例如 2.6.0，不要带 v）: ")"
        read -r version_value
        version_value="${version_value:-}"
        if ! [[ "$version_value" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            ui_warn "版本号格式无效。"
            return 1
        fi
    fi

    cert_choice="$(pick_from_options \
        "证书模式" \
        "自签证书（默认）" \
        "Acme 自动申请" \
        "自定义证书路径")" || return 1

    case "$cert_choice" in
        "Acme 自动申请")
            cert_mode="acme"

            printf '%b' "$(ui_prompt "输入" "请输入证书域名: ")"
            read -r cert_domain
            cert_domain="${cert_domain:-}"

            printf '%b' "$(ui_prompt "输入" "请输入 Acme 邮箱: ")"
            read -r acme_email
            acme_email="${acme_email:-}"

            if [ -z "$cert_domain" ] || [ -z "$acme_email" ]; then
                ui_warn "Acme 模式下，域名和邮箱不能为空。"
                return 1
            fi

            server_addr="$cert_domain"
            ;;
        "自定义证书路径")
            cert_mode="custom"

            printf '%b' "$(ui_prompt "输入" "请输入证书域名（SNI）: ")"
            read -r cert_domain
            cert_domain="${cert_domain:-}"

            printf '%b' "$(ui_prompt "输入" "请输入 crt 证书路径: ")"
            read -r cert_path
            cert_path="${cert_path:-}"

            printf '%b' "$(ui_prompt "输入" "请输入 key 私钥路径: ")"
            read -r key_path
            key_path="${key_path:-}"

            printf '%b' "$(ui_prompt "输入" "请输入客户端连接地址（回车默认使用证书域名）: ")"
            read -r server_addr
            server_addr="${server_addr:-$cert_domain}"

            if [ -z "$cert_domain" ] || [ -z "$cert_path" ] || [ -z "$key_path" ]; then
                ui_warn "自定义证书模式下，域名、crt 路径和 key 路径都不能为空。"
                return 1
            fi
            ;;
        *)
            cert_mode="selfsigned"

            printf '%b' "$(ui_prompt "输入" "请输入自签证书域名（回车默认 bing.com）: ")"
            read -r cert_domain
            cert_domain="${cert_domain:-bing.com}"

            printf '%b' "$(ui_prompt "输入" "请输入客户端连接地址（回车自动探测公网 IPv4）: ")"
            read -r server_addr
            server_addr="${server_addr:-}"
            ;;
    esac

    printf '%b' "$(ui_prompt "输入" "请输入监听端口（回车默认 443）: ")"
    read -r port_value
    port_value="${port_value:-443}"
    if ! validate_port "$port_value"; then
        ui_warn "端口无效。"
        return 1
    fi

    printf '%b' "$(ui_prompt "输入" "请输入节点名称（回车默认 hy2）: ")"
    read -r node_name
    node_name="${node_name:-hy2}"

    printf '%b' "$(ui_prompt "输入" "请输入认证密码（回车随机生成）: ")"
    read -r password_value
    password_value="${password_value:-}"

    printf '%b' "$(ui_prompt "输入" "请输入伪装网站（回车默认 https://bing.com）: ")"
    read -r masquerade_url
    masquerade_url="${masquerade_url:-https://bing.com}"

    if yesno_select "是否开启 Brutal 模式？" "n"; then
        brutal_mode="1"
    fi

    if yesno_select "是否开启 Salamander 混淆？" "n"; then
        obfs_mode="1"
        printf '%b' "$(ui_prompt "输入" "请输入混淆密码（回车随机生成）: ")"
        read -r obfs_password
        obfs_password="${obfs_password:-}"
    fi

    if yesno_select "是否开启 Sniff？" "n"; then
        sniff_mode="1"
    fi

    proxy_toolbox_run \
        "hysteria2_seagullz4" \
        "quick_install" \
        "SCRIPTKIT_HY2_SG_VERSION_MODE=$version_mode" \
        "SCRIPTKIT_HY2_SG_VERSION=$version_value" \
        "SCRIPTKIT_HY2_SG_CERT_MODE=$cert_mode" \
        "SCRIPTKIT_HY2_SG_CERT_DOMAIN=$cert_domain" \
        "SCRIPTKIT_HY2_SG_ACME_EMAIL=$acme_email" \
        "SCRIPTKIT_HY2_SG_CERT_PATH=$cert_path" \
        "SCRIPTKIT_HY2_SG_KEY_PATH=$key_path" \
        "SCRIPTKIT_HY2_SG_SERVER_ADDR=$server_addr" \
        "SCRIPTKIT_HY2_SG_PORT=$port_value" \
        "SCRIPTKIT_HY2_SG_NODE_NAME=$node_name" \
        "SCRIPTKIT_HY2_SG_PASSWORD=$password_value" \
        "SCRIPTKIT_HY2_SG_MASQUERADE_URL=$masquerade_url" \
        "SCRIPTKIT_HY2_SG_BRUTAL=$brutal_mode" \
        "SCRIPTKIT_HY2_SG_OBFS=$obfs_mode" \
        "SCRIPTKIT_HY2_SG_OBFS_PASSWORD=$obfs_password" \
        "SCRIPTKIT_HY2_SG_SNIFF=$sniff_mode"
}

proxy_hysteria2_seagullz4_python_deps_run() {
    proxy_toolbox_run "hysteria2_seagullz4" "python_deps"
}

proxy_hysteria2_seagullz4_python_menu_run() {
    proxy_toolbox_run "hysteria2_seagullz4" "python_menu"
}

proxy_hysteria2_seagullz4_python_bootstrap_run() {
    proxy_toolbox_run "hysteria2_seagullz4" "python_bootstrap"
}

add_menu "proxy_singbox" "Sing-box" "proxy"
add_menu "proxy_singbox_233box" "233box" "proxy_singbox"
add_action "proxy_singbox_233box_install" "默认安装" "proxy_singbox_233box" "proxy_singbox_233box_install_run"
add_action "proxy_singbox_233box_proxy" "指定下载代理" "proxy_singbox_233box" "proxy_singbox_233box_proxy_run"
add_action "proxy_singbox_233box_version" "指定内核版本" "proxy_singbox_233box" "proxy_singbox_233box_version_run"
add_action "proxy_singbox_233box_help" "安装器帮助" "proxy_singbox_233box" "proxy_singbox_233box_help_run"
add_action "proxy_singbox_233box_custom" "自定义安装参数" "proxy_singbox_233box" "proxy_singbox_233box_custom_run"

add_menu "proxy_singbox_fscarmen" "fscarmen" "proxy_singbox"
add_action "proxy_singbox_fscarmen_interactive" "交互安装" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_interactive_run"
add_action "proxy_singbox_fscarmen_quick_cn" "极速安装（中文）" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_quick_cn_run"
add_action "proxy_singbox_fscarmen_quick_en" "极速安装（英文）" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_quick_en_run"
add_action "proxy_singbox_fscarmen_nodes" "查看节点 (-n)" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_nodes_run"
add_action "proxy_singbox_fscarmen_edit" "修改参数 (-d)" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_edit_run"
add_action "proxy_singbox_fscarmen_service" "服务开关 (-s)" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_service_run"
add_action "proxy_singbox_fscarmen_argo" "Argo 开关 (-a)" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_argo_run"
add_action "proxy_singbox_fscarmen_update" "更新到最新 (-v)" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_update_run"
add_action "proxy_singbox_fscarmen_system" "系统工具 (-b)" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_system_run"
add_action "proxy_singbox_fscarmen_protocols" "协议管理 (-r)" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_protocols_run"
add_action "proxy_singbox_fscarmen_uninstall" "卸载 (-u)" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_uninstall_run"
add_action "proxy_singbox_fscarmen_custom" "自定义参数" "proxy_singbox_fscarmen" "proxy_singbox_fscarmen_custom_run"

add_menu "proxy_singbox_yg" "ygkkk" "proxy_singbox"
add_action "proxy_singbox_yg_vps" "VPS 一键脚本" "proxy_singbox_yg" "proxy_singbox_yg_vps_run"
add_action "proxy_singbox_yg_vps_preset" "基础交互式安装" "proxy_singbox_yg" "proxy_singbox_yg_vps_preset_run"
add_action "proxy_singbox_yg_serv00" "Serv00 / Hostuno 脚本" "proxy_singbox_yg" "proxy_singbox_yg_serv00_run"

add_menu "proxy_3xui" "3x-ui" "proxy"
add_action "proxy_3xui_install" "官方安装脚本" "proxy_3xui" "proxy_3xui_install_run"
add_action "proxy_3xui_start" "启动" "proxy_3xui" "proxy_3xui_start_run"
add_action "proxy_3xui_stop" "停止" "proxy_3xui" "proxy_3xui_stop_run"
add_action "proxy_3xui_restart" "重启" "proxy_3xui" "proxy_3xui_restart_run"
add_action "proxy_3xui_status" "状态" "proxy_3xui" "proxy_3xui_status_run"
add_action "proxy_3xui_settings" "当前设置" "proxy_3xui" "proxy_3xui_settings_run"
add_action "proxy_3xui_enable" "启用开机自启" "proxy_3xui" "proxy_3xui_enable_run"
add_action "proxy_3xui_disable" "关闭开机自启" "proxy_3xui" "proxy_3xui_disable_run"
add_action "proxy_3xui_log" "查看日志" "proxy_3xui" "proxy_3xui_log_run"
add_action "proxy_3xui_update" "更新" "proxy_3xui" "proxy_3xui_update_run"
add_action "proxy_3xui_uninstall" "卸载" "proxy_3xui" "proxy_3xui_uninstall_run"
add_action "proxy_3xui_custom" "自定义子命令" "proxy_3xui" "proxy_3xui_custom_run"

add_menu "proxy_realm_xwpf" "realm-xwPF" "proxy"
add_action "proxy_realm_xwpf_install" "安装 / 初始化" "proxy_realm_xwpf" "proxy_realm_xwpf_install_run"
add_action "proxy_realm_xwpf_menu" "打开管理菜单" "proxy_realm_xwpf" "proxy_realm_xwpf_menu_run"
add_action "proxy_realm_xwpf_speedtest" "网络链路测速" "proxy_realm_xwpf" "proxy_realm_xwpf_speedtest_run"
add_action "proxy_realm_xwpf_dog" "端口流量狗" "proxy_realm_xwpf" "proxy_realm_xwpf_dog_run"
add_action "proxy_realm_xwpf_custom" "自定义参数" "proxy_realm_xwpf" "proxy_realm_xwpf_custom_run"

add_menu "proxy_v2ray_agent" "v2ray-agent" "proxy"
add_action "proxy_v2ray_agent_install" "安装 / 管理菜单" "proxy_v2ray_agent" "proxy_v2ray_agent_install_run"
add_menu "proxy_v2ray_agent_docker" "Docker Reality" "proxy_v2ray_agent"
add_action "proxy_v2ray_agent_docker_menu" "安装 / 管理菜单" "proxy_v2ray_agent_docker" "proxy_v2ray_agent_docker_run"
add_action "proxy_v2ray_agent_docker_help" "帮助信息" "proxy_v2ray_agent_docker" "proxy_v2ray_agent_docker_help_run"
add_action "proxy_v2ray_agent_docker_custom" "自定义参数" "proxy_v2ray_agent_docker" "proxy_v2ray_agent_docker_custom_run"

add_menu "proxy_hysteria2" "Hysteria 2" "proxy"

add_menu "proxy_hysteria2_install" "flame1ce / hysteria2-install" "proxy_hysteria2"
add_action "proxy_hysteria2_install_menu" "安装 / 管理菜单" "proxy_hysteria2_install" "proxy_hysteria2_install_menu_run"
add_action "proxy_hysteria2_install_preset" "交互式安装" "proxy_hysteria2_install" "proxy_hysteria2_install_preset_run"

add_menu "proxy_hysteria2_seagullz4" "seagullz4 / hysteria2" "proxy_hysteria2"
add_action "proxy_hysteria2_seagullz4_shell" "Shell 版菜单" "proxy_hysteria2_seagullz4" "proxy_hysteria2_seagullz4_shell_run"
add_action "proxy_hysteria2_seagullz4_quick" "轻量交互式安装" "proxy_hysteria2_seagullz4" "proxy_hysteria2_seagullz4_quick_run"
add_action "proxy_hysteria2_seagullz4_python_deps" "Python 版安装依赖" "proxy_hysteria2_seagullz4" "proxy_hysteria2_seagullz4_python_deps_run"
add_action "proxy_hysteria2_seagullz4_python_menu" "Python 版菜单" "proxy_hysteria2_seagullz4" "proxy_hysteria2_seagullz4_python_menu_run"
add_action "proxy_hysteria2_seagullz4_python_bootstrap" "Python 版依赖 + 菜单" "proxy_hysteria2_seagullz4" "proxy_hysteria2_seagullz4_python_bootstrap_run"
