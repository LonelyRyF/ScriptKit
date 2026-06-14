#!/usr/bin/env bash
set -u

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

proxy_toolbox_workdir() {
    printf '%s' "${SCRIPTKIT_PROXY_WORKDIR:-${HOME:-/root}/.scriptkit/proxy/${SCRIPTKIT_PROXY_TOOL:-tool}}"
}

proxy_toolbox_prepare_script() {
    local target_file="$1"
    shift
    local remote_url=""

    mkdir -p "$(dirname -- "$target_file")" || return 1

    for remote_url in "$@"; do
        [ -n "$remote_url" ] || continue
        msg_info "正在下载上游脚本..."
        if download_file "$remote_url" "$target_file"; then
            chmod 700 "$target_file" 2>/dev/null || true
            return 0
        fi
    done

    return 1
}

proxy_toolbox_run_script() {
    local workdir="$1"
    local script_file="$2"
    shift 2

    (
        cd "$workdir" || exit 1
        bash "$script_file" "$@"
    )
}

proxy_toolbox_run_custom_args() {
    local workdir="$1"
    local script_file="$2"

    if [ -z "${SCRIPTKIT_PROXY_ARGS:-}" ]; then
        msg_err "未提供自定义参数"
        return 1
    fi

    (
        cd "$workdir" || exit 1
        bash -c 'script_file="$1"; eval "set -- $SCRIPTKIT_PROXY_ARGS"; bash "$script_file" "$@"' _ "$script_file"
    )
}

proxy_toolbox_run_local_script() {
    local script_file="$1"
    shift

    proxy_toolbox_run_script "$(dirname -- "$script_file")" "$script_file" "$@"
}

proxy_toolbox_run_with_answers() {
    local workdir="$1"
    local script_file="$2"
    shift 2
    local -a answers=("$@")

    (
        cd "$workdir" || exit 1
        printf '%s\n' "${answers[@]}" | bash "$script_file"
    )
}

proxy_toolbox_run_singbox_233box() {
    local workdir="$(proxy_toolbox_workdir)"
    local mode="${SCRIPTKIT_PROXY_MODE:-install}"
    local script_file="$workdir/233box-install.sh"
    local value="${SCRIPTKIT_PROXY_VALUE:-}"

    draw_current_title "233box Sing-box"
    proxy_toolbox_prepare_script \
        "$script_file" \
        "https://raw.githubusercontent.com/233boy/sing-box/main/install.sh" || {
        msg_err "下载 233box 安装脚本失败"
        return 1
    }

    case "$mode" in
        install) proxy_toolbox_run_script "$workdir" "$script_file" ;;
        help) proxy_toolbox_run_script "$workdir" "$script_file" -h ;;
        proxy)
            [ -n "$value" ] || { msg_err "未提供代理地址"; return 1; }
            proxy_toolbox_run_script "$workdir" "$script_file" -p "$value"
            ;;
        version)
            [ -n "$value" ] || { msg_err "未提供内核版本"; return 1; }
            proxy_toolbox_run_script "$workdir" "$script_file" -v "$value"
            ;;
        custom) proxy_toolbox_run_custom_args "$workdir" "$script_file" ;;
        *)
            msg_err "未知 233box 模式: $mode"
            return 1
            ;;
    esac
}

proxy_toolbox_run_singbox_yg() {
    local workdir="$(proxy_toolbox_workdir)"
    local mode="${SCRIPTKIT_PROXY_MODE:-vps}"
    local script_file=""
    local use_old_core="${SCRIPTKIT_SINGBOX_YG_USE_OLD_CORE:-0}"
    local use_domain_cert="${SCRIPTKIT_SINGBOX_YG_USE_DOMAIN_CERT:-0}"
    local custom_ports="${SCRIPTKIT_SINGBOX_YG_CUSTOM_PORTS:-0}"
    local allow_ports="${SCRIPTKIT_SINGBOX_YG_ALLOW_PORTS:-1}"
    local core_answer="1"
    local cert_answer="1"
    local port_answer="1"
    local open_answer="1"
    local -a answers=()

    draw_current_title "Sing-box-yg"

    case "$mode" in
        vps)
            script_file="$workdir/sing-box-yg.sh"
            proxy_toolbox_prepare_script \
                "$script_file" \
                "https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh" || {
                msg_err "下载 Sing-box-yg VPS 脚本失败"
                return 1
            }
            proxy_toolbox_run_script "$workdir" "$script_file"
            ;;
        vps_preset)
            script_file="$workdir/sing-box-yg.sh"
            proxy_toolbox_prepare_script \
                "$script_file" \
                "https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh" || {
                msg_err "下载 Sing-box-yg VPS 脚本失败"
                return 1
            }

            [ "$use_old_core" = "1" ] && core_answer="2"
            [ "$use_domain_cert" = "1" ] && cert_answer="2"
            [ "$custom_ports" = "1" ] && port_answer="2"
            [ "$allow_ports" = "0" ] && open_answer="2"

            answers=(
                "1"
                "$open_answer"
                "$core_answer"
                "$cert_answer"
                "$port_answer"
            )

            proxy_toolbox_run_with_answers "$workdir" "$script_file" "${answers[@]}"
            ;;
        serv00)
            script_file="$workdir/sing-box-yg-serv00.sh"
            proxy_toolbox_prepare_script \
                "$script_file" \
                "https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/serv00.sh" || {
                msg_err "下载 Sing-box-yg Serv00 脚本失败"
                return 1
            }
            proxy_toolbox_run_script "$workdir" "$script_file"
            ;;
        *)
            msg_err "未知 Sing-box-yg 模式: $mode"
            return 1
            ;;
    esac
}

proxy_toolbox_run_singbox_fscarmen() {
    local workdir="$(proxy_toolbox_workdir)"
    local mode="${SCRIPTKIT_PROXY_MODE:-interactive}"
    local script_file="$workdir/fscarmen-sing-box.sh"

    draw_current_title "fscarmen Sing-box"
    proxy_toolbox_prepare_script \
        "$script_file" \
        "https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh" || {
        msg_err "下载 fscarmen 脚本失败"
        return 1
    }

    case "$mode" in
        interactive) proxy_toolbox_run_script "$workdir" "$script_file" ;;
        quick_cn) proxy_toolbox_run_script "$workdir" "$script_file" -l ;;
        quick_en) proxy_toolbox_run_script "$workdir" "$script_file" -k ;;
        nodes) proxy_toolbox_run_script "$workdir" "$script_file" -n ;;
        edit) proxy_toolbox_run_script "$workdir" "$script_file" -d ;;
        service) proxy_toolbox_run_script "$workdir" "$script_file" -s ;;
        argo) proxy_toolbox_run_script "$workdir" "$script_file" -a ;;
        update) proxy_toolbox_run_script "$workdir" "$script_file" -v ;;
        system) proxy_toolbox_run_script "$workdir" "$script_file" -b ;;
        protocols) proxy_toolbox_run_script "$workdir" "$script_file" -r ;;
        uninstall) proxy_toolbox_run_script "$workdir" "$script_file" -u ;;
        custom) proxy_toolbox_run_custom_args "$workdir" "$script_file" ;;
        *)
            msg_err "未知 fscarmen 模式: $mode"
            return 1
            ;;
    esac
}

proxy_toolbox_run_3xui() {
    local workdir="$(proxy_toolbox_workdir)"
    local mode="${SCRIPTKIT_PROXY_MODE:-install}"
    local script_file=""

    draw_current_title "3x-ui"

    case "$mode" in
        install)
            script_file="$workdir/3x-ui-install.sh"
            proxy_toolbox_prepare_script \
                "$script_file" \
                "https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh" \
                "https://raw.githubusercontent.com/mhsanaei/3x-ui/main/install.sh" || {
                msg_err "下载 3x-ui 安装脚本失败"
                return 1
            }
            proxy_toolbox_run_script "$workdir" "$script_file"
            ;;
        start|stop|restart|status|settings|enable|disable|log|update|uninstall)
            script_file="$workdir/x-ui.sh"
            proxy_toolbox_prepare_script \
                "$script_file" \
                "https://raw.githubusercontent.com/mhsanaei/3x-ui/main/x-ui.sh" \
                "https://raw.githubusercontent.com/mhsanaei/3x-ui/master/x-ui.sh" || {
                msg_err "下载 3x-ui 管理脚本失败"
                return 1
            }
            proxy_toolbox_run_script "$workdir" "$script_file" "$mode"
            ;;
        custom)
            script_file="$workdir/x-ui.sh"
            proxy_toolbox_prepare_script \
                "$script_file" \
                "https://raw.githubusercontent.com/mhsanaei/3x-ui/main/x-ui.sh" \
                "https://raw.githubusercontent.com/mhsanaei/3x-ui/master/x-ui.sh" || {
                msg_err "下载 3x-ui 管理脚本失败"
                return 1
            }
            proxy_toolbox_run_custom_args "$workdir" "$script_file"
            ;;
        *)
            msg_err "未知 3x-ui 模式: $mode"
            return 1
            ;;
    esac
}

proxy_toolbox_run_realm_xwpf() {
    local workdir="$(proxy_toolbox_workdir)"
    local mode="${SCRIPTKIT_PROXY_MODE:-install}"
    local script_file=""

    draw_current_title "realm-xwPF"

    case "$mode" in
        install|menu|custom)
            script_file="$workdir/xwPF.sh"
            proxy_toolbox_prepare_script \
                "$script_file" \
                "https://raw.githubusercontent.com/zywe03/realm-xwPF/main/xwPF.sh" || {
                msg_err "下载 realm-xwPF 主脚本失败"
                return 1
            }
            case "$mode" in
                install) proxy_toolbox_run_script "$workdir" "$script_file" install ;;
                menu) proxy_toolbox_run_script "$workdir" "$script_file" ;;
                custom) proxy_toolbox_run_custom_args "$workdir" "$script_file" ;;
            esac
            ;;
        speedtest)
            script_file="$workdir/speedtest.sh"
            proxy_toolbox_prepare_script \
                "$script_file" \
                "https://raw.githubusercontent.com/zywe03/realm-xwPF/main/speedtest.sh" || {
                msg_err "下载 speedtest 脚本失败"
                return 1
            }
            proxy_toolbox_run_script "$workdir" "$script_file"
            ;;
        dog)
            script_file="$workdir/port-traffic-dog.sh"
            proxy_toolbox_prepare_script \
                "$script_file" \
                "https://raw.githubusercontent.com/zywe03/realm-xwPF/main/port-traffic-dog.sh" || {
                msg_err "下载端口流量狗脚本失败"
                return 1
            }
            proxy_toolbox_run_script "$workdir" "$script_file"
            ;;
        *)
            msg_err "未知 realm-xwPF 模式: $mode"
            return 1
            ;;
    esac
}

proxy_toolbox_run_v2ray_agent() {
    local mode="${SCRIPTKIT_PROXY_MODE:-install}"
    local home_dir="${HOME:-/root}"
    local script_file=""

    draw_current_title "v2ray-agent"

    case "$mode" in
        install)
            if [ -f "/etc/v2ray-agent/install.sh" ]; then
                script_file="/etc/v2ray-agent/install.sh"
            else
                script_file="$home_dir/install.sh"
                proxy_toolbox_prepare_script \
                    "$script_file" \
                    "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" || {
                    msg_err "下载 v2ray-agent 安装脚本失败"
                    return 1
                }
            fi
            proxy_toolbox_run_local_script "$script_file"
            ;;
        docker_reality|docker_reality_help|docker_reality_custom)
            if [ -f "/etc/v2ray-agent/docker_reality.sh" ]; then
                script_file="/etc/v2ray-agent/docker_reality.sh"
            else
                script_file="$home_dir/docker_reality.sh"
                proxy_toolbox_prepare_script \
                    "$script_file" \
                    "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/shell/docker_reality.sh" || {
                    msg_err "下载 v2ray-agent Docker Reality 脚本失败"
                    return 1
                }
            fi

            case "$mode" in
                docker_reality) proxy_toolbox_run_local_script "$script_file" ;;
                docker_reality_help) proxy_toolbox_run_local_script "$script_file" --help ;;
                docker_reality_custom) proxy_toolbox_run_custom_args "$(dirname -- "$script_file")" "$script_file" ;;
            esac
            ;;
        *)
            msg_err "未知 v2ray-agent 模式: $mode"
            return 1
            ;;
    esac
}

proxy_toolbox_run_hysteria2_install() {
    local workdir="$(proxy_toolbox_workdir)"
    local mode="${SCRIPTKIT_PROXY_MODE:-menu}"
    local script_file="$workdir/hysteria2-install.sh"
    local cert_mode="${SCRIPTKIT_HY2_CERT_MODE:-1}"
    local cert_path="${SCRIPTKIT_HY2_CERT_PATH:-}"
    local key_path="${SCRIPTKIT_HY2_KEY_PATH:-}"
    local domain_value="${SCRIPTKIT_HY2_DOMAIN:-}"
    local port_mode="${SCRIPTKIT_HY2_PORT_MODE:-random}"
    local port_value="${SCRIPTKIT_HY2_PORT:-}"
    local jump_mode="${SCRIPTKIT_HY2_JUMP_MODE:-single}"
    local jump_start="${SCRIPTKIT_HY2_JUMP_START:-}"
    local jump_end="${SCRIPTKIT_HY2_JUMP_END:-}"
    local password_value="${SCRIPTKIT_HY2_PASSWORD:-}"
    local masquerade_site="${SCRIPTKIT_HY2_SITE:-}"
    local -a answers=()

    draw_current_title "Hysteria 2"

    proxy_toolbox_prepare_script \
        "$script_file" \
        "https://raw.githubusercontent.com/flame1ce/hysteria2-install/main/hysteria2-install-main/hy2/hysteria.sh" || {
        msg_err "下载 Hysteria 2 安装脚本失败"
        return 1
    }

    case "$mode" in
        menu) proxy_toolbox_run_script "$workdir" "$script_file" ;;
        preset_install)
            case "$cert_mode" in
                1|2|3) ;;
                *) cert_mode="1" ;;
            esac

            answers=("1" "$cert_mode")

            if [ "$cert_mode" = "2" ]; then
                answers+=("$domain_value")
            elif [ "$cert_mode" = "3" ]; then
                answers+=("$cert_path" "$key_path" "$domain_value")
            fi

            if [ "$port_mode" != "custom" ] || [ -z "$port_value" ]; then
                port_value=""
            fi

            answers+=("$port_value")

            if [ "$jump_mode" = "range" ]; then
                answers+=(
                    "2"
                    "$jump_start"
                    "$jump_end"
                )
            else
                answers+=("1")
            fi

            answers+=(
                "$password_value"
                "$masquerade_site"
            )

            proxy_toolbox_run_with_answers "$workdir" "$script_file" "${answers[@]}"
            ;;
        *)
            msg_err "未知 Hysteria 2 模式: $mode"
            return 1
            ;;
    esac
}

proxy_toolbox_random_string() {
    local length="${1:-16}"
    local random_text=""

    if command_exists openssl; then
        random_text="$(openssl rand -hex 32 2>/dev/null | cut -c1-"$length")"
    fi

    if [ -z "$random_text" ] && [ -r /dev/urandom ]; then
        random_text="$(tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c "$length")"
    fi

    if [ -z "$random_text" ]; then
        random_text="$(date +%s 2>/dev/null)$(printf '%s' "$RANDOM")"
        random_text="${random_text:0:$length}"
    fi

    printf '%s' "$random_text"
}

proxy_toolbox_detect_public_ipv4() {
    local ip=""

    if command_exists curl; then
        ip="$(curl -4fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
        [ -n "$ip" ] || ip="$(curl -4fsS --max-time 5 https://ifconfig.me 2>/dev/null || true)"
    elif command_exists wget; then
        ip="$(wget -4qO- --timeout=5 https://api.ipify.org 2>/dev/null || true)"
        [ -n "$ip" ] || ip="$(wget -4qO- --timeout=5 https://ifconfig.me 2>/dev/null || true)"
    fi

    printf '%s' "$ip"
}

proxy_toolbox_urlencode() {
    local value="${1:-}"
    local encoded=""
    local i=0
    local char=""

    for ((i = 0; i < ${#value}; i++)); do
        char="${value:i:1}"
        case "$char" in
            [a-zA-Z0-9.~_-]) encoded+="$char" ;;
            *) printf -v encoded '%s%%%02X' "$encoded" "'$char" ;;
        esac
    done

    printf '%s' "$encoded"
}

proxy_toolbox_write_hysteria2_quick_config() {
    local cert_mode="$1"
    local cert_domain="$2"
    local acme_email="$3"
    local cert_path="$4"
    local key_path="$5"
    local port_value="$6"
    local password_value="$7"
    local masquerade_url="$8"
    local brutal_mode="$9"
    local obfs_mode="${10}"
    local obfs_password="${11}"
    local sniff_mode="${12}"
    local config_dir="/etc/hysteria"
    local config_file="$config_dir/config.yaml"
    local tls_block=""
    local obfs_block=""
    local sniff_block=""

    mkdir -p "$config_dir" || return 1

    case "$cert_mode" in
        acme)
            tls_block="acme:
  domains:
    - ${cert_domain}
  email: ${acme_email}"
            ;;
        custom)
            tls_block="tls:
  cert: ${cert_path}
  key: ${key_path}"
            ;;
        *)
            tls_block="tls:
  cert: /etc/ssl/private/${cert_domain}.crt
  key: /etc/ssl/private/${cert_domain}.key"
            ;;
    esac

    if [ "$obfs_mode" = "1" ]; then
        obfs_block="
obfs:
  type: salamander
  salamander:
    password: ${obfs_password}"
    fi

    if [ "$sniff_mode" = "1" ]; then
        sniff_block="
sniff:
  enable: true
  timeout: 2s
  rewriteDomain: false
  tcpPorts: 80,443,8000-9000
  udpPorts: all"
    fi

    cat >"$config_file" <<EOF
listen: :${port_value}

${tls_block}

auth:
  type: password
  password: ${password_value}

masquerade:
  type: proxy
  proxy:
    url: ${masquerade_url}
    rewriteHost: true

ignoreClientBandwidth: ${brutal_mode}${obfs_block}${sniff_block}
EOF
}

proxy_toolbox_generate_selfsigned_cert() {
    local cert_domain="$1"
    local cert_dir="/etc/ssl/private"
    local ec_param_file="$cert_dir/ec_param.pem"

    mkdir -p "$cert_dir" || return 1
    openssl ecparam -name prime256v1 -out "$ec_param_file" || return 1
    openssl req -x509 -nodes -newkey "ec:${ec_param_file}" \
        -keyout "$cert_dir/${cert_domain}.key" \
        -out "$cert_dir/${cert_domain}.crt" \
        -subj "/CN=${cert_domain}" \
        -days 36500 || return 1

    chmod 644 "$cert_dir/${cert_domain}.key" "$cert_dir/${cert_domain}.crt" 2>/dev/null || true
    rm -f "$ec_param_file"
}

proxy_toolbox_run_hysteria2_seagullz4() {
    local workdir="$(proxy_toolbox_workdir)"
    local mode="${SCRIPTKIT_PROXY_MODE:-shell}"
    local shell_script="$workdir/hysteria2-install.sh"
    local python_deps_script="$workdir/hysteria2-python-deps.sh"
    local python_menu_script="$workdir/hysteria2.py"
    local version_mode="${SCRIPTKIT_HY2_SG_VERSION_MODE:-latest}"
    local version_value="${SCRIPTKIT_HY2_SG_VERSION:-}"
    local cert_mode="${SCRIPTKIT_HY2_SG_CERT_MODE:-selfsigned}"
    local cert_domain="${SCRIPTKIT_HY2_SG_CERT_DOMAIN:-bing.com}"
    local acme_email="${SCRIPTKIT_HY2_SG_ACME_EMAIL:-}"
    local cert_path="${SCRIPTKIT_HY2_SG_CERT_PATH:-}"
    local key_path="${SCRIPTKIT_HY2_SG_KEY_PATH:-}"
    local server_addr="${SCRIPTKIT_HY2_SG_SERVER_ADDR:-}"
    local port_value="${SCRIPTKIT_HY2_SG_PORT:-443}"
    local node_name="${SCRIPTKIT_HY2_SG_NODE_NAME:-hy2}"
    local password_value="${SCRIPTKIT_HY2_SG_PASSWORD:-}"
    local masquerade_url="${SCRIPTKIT_HY2_SG_MASQUERADE_URL:-https://bing.com}"
    local brutal_mode="${SCRIPTKIT_HY2_SG_BRUTAL:-0}"
    local obfs_mode="${SCRIPTKIT_HY2_SG_OBFS:-0}"
    local obfs_password="${SCRIPTKIT_HY2_SG_OBFS_PASSWORD:-}"
    local sniff_mode="${SCRIPTKIT_HY2_SG_SNIFF:-0}"
    local insecure_flag="1"
    local link_password=""
    local link_obfs_password=""
    local hy2_link=""

    draw_current_title "Hysteria 2（seagullz4）"

    case "$mode" in
        shell)
            proxy_toolbox_prepare_script \
                "$shell_script" \
                "https://raw.githubusercontent.com/seagullz4/hysteria2/main/install.sh" || {
                msg_err "下载 Hysteria 2 Shell 版脚本失败"
                return 1
            }
            proxy_toolbox_run_script "$workdir" "$shell_script"
            ;;
        python_deps)
            proxy_toolbox_prepare_script \
                "$python_deps_script" \
                "https://raw.githubusercontent.com/seagullz4/hysteria2/main/phy2.sh" || {
                msg_err "下载 Hysteria 2 Python 依赖脚本失败"
                return 1
            }
            proxy_toolbox_run_script "$workdir" "$python_deps_script"
            ;;
        python_menu)
            proxy_toolbox_prepare_script \
                "$python_menu_script" \
                "https://raw.githubusercontent.com/seagullz4/hysteria2/main/hysteria2.py" || {
                msg_err "下载 Hysteria 2 Python 菜单失败"
                return 1
            }
            (
                cd "$workdir" || exit 1
                python3 "$python_menu_script"
            )
            ;;
        python_bootstrap)
            proxy_toolbox_prepare_script \
                "$python_deps_script" \
                "https://raw.githubusercontent.com/seagullz4/hysteria2/main/phy2.sh" || {
                msg_err "下载 Hysteria 2 Python 依赖脚本失败"
                return 1
            }
            proxy_toolbox_prepare_script \
                "$python_menu_script" \
                "https://raw.githubusercontent.com/seagullz4/hysteria2/main/hysteria2.py" || {
                msg_err "下载 Hysteria 2 Python 菜单失败"
                return 1
            }
            proxy_toolbox_run_script "$workdir" "$python_deps_script" || return 1
            (
                cd "$workdir" || exit 1
                python3 "$python_menu_script"
            )
            ;;
        quick_install)
            require_root_action || return 1
            ensure_commands curl openssl || return 1

            if [ -z "$password_value" ]; then
                password_value="$(proxy_toolbox_random_string 16)"
            fi

            if [ "$obfs_mode" = "1" ] && [ -z "$obfs_password" ]; then
                obfs_password="$(proxy_toolbox_random_string 12)"
            fi

            if [ "$version_mode" = "custom" ]; then
                [ -n "$version_value" ] || { msg_err "未提供版本号"; return 1; }
                bash -c "bash <(curl -fsSL https://get.hy2.sh/) --version v${version_value}" || return 1
            else
                bash -c "bash <(curl -fsSL https://get.hy2.sh/)" || return 1
            fi

            case "$cert_mode" in
                acme)
                    [ -n "$cert_domain" ] || { msg_err "Acme 模式缺少证书域名"; return 1; }
                    [ -n "$acme_email" ] || { msg_err "Acme 模式缺少邮箱"; return 1; }
                    insecure_flag="0"
                    ;;
                custom)
                    [ -n "$cert_domain" ] || { msg_err "自定义证书模式缺少证书域名"; return 1; }
                    [ -n "$cert_path" ] || { msg_err "自定义证书模式缺少 crt 路径"; return 1; }
                    [ -n "$key_path" ] || { msg_err "自定义证书模式缺少 key 路径"; return 1; }
                    insecure_flag="0"
                    ;;
                *)
                    cert_mode="selfsigned"
                    cert_domain="${cert_domain:-bing.com}"
                    proxy_toolbox_generate_selfsigned_cert "$cert_domain" || {
                        msg_err "生成自签证书失败"
                        return 1
                    }
                    ;;
            esac

            if [ -z "$server_addr" ]; then
                if [ "$cert_mode" = "selfsigned" ]; then
                    server_addr="$(proxy_toolbox_detect_public_ipv4)"
                    [ -n "$server_addr" ] || { msg_err "自动获取公网 IPv4 失败，请改用手动指定连接地址"; return 1; }
                else
                    server_addr="$cert_domain"
                fi
            fi

            proxy_toolbox_write_hysteria2_quick_config \
                "$cert_mode" \
                "$cert_domain" \
                "$acme_email" \
                "$cert_path" \
                "$key_path" \
                "$port_value" \
                "$password_value" \
                "$masquerade_url" \
                "$brutal_mode" \
                "$obfs_mode" \
                "$obfs_password" \
                "$sniff_mode" || {
                msg_err "写入 Hysteria 2 配置失败"
                return 1
            }

            systemctl enable --now hysteria-server.service >/dev/null 2>&1 || true
            systemctl restart hysteria-server.service || {
                msg_err "Hysteria 2 服务重启失败"
                return 1
            }

            link_password="$(proxy_toolbox_urlencode "$password_value")"
            link_obfs_password="$(proxy_toolbox_urlencode "$obfs_password")"
            hy2_link="hysteria2://${link_password}@${server_addr}:${port_value}?sni=${cert_domain}&insecure=${insecure_flag}"
            if [ "$obfs_mode" = "1" ]; then
                hy2_link="${hy2_link}&obfs=salamander&obfs-password=${link_obfs_password}"
            fi
            hy2_link="${hy2_link}#$(proxy_toolbox_urlencode "$node_name")"

            mkdir -p /etc/hy2config 2>/dev/null || true
            printf '%s\n' "$hy2_link" >/etc/hy2config/hy2_url_scheme.txt 2>/dev/null || true

            msg_ok "Hysteria 2 快速安装完成"
            printf '%b %s\n' "$(msg_prompt "地址" "连接地址: ")" "$server_addr"
            printf '%b %s\n' "$(msg_prompt "端口" "监听端口: ")" "$port_value"
            printf '%b %s\n' "$(msg_prompt "SNI" "证书域名: ")" "$cert_domain"
            printf '%b %s\n' "$(msg_prompt "密码" "认证密码: ")" "$password_value"
            if [ "$obfs_mode" = "1" ]; then
                printf '%b %s\n' "$(msg_prompt "混淆" "Salamander 密码: ")" "$obfs_password"
            fi
            printf '%b %s\n' "$(msg_prompt "链接" "Hy2 链接: ")" "$hy2_link"
            ;;
        *)
            msg_err "未知 Hysteria 2（seagullz4）模式: $mode"
            return 1
            ;;
    esac
}

main() {
    case "${SCRIPTKIT_PROXY_TOOL:-}" in
        singbox_233box) proxy_toolbox_run_singbox_233box ;;
        singbox_fscarmen) proxy_toolbox_run_singbox_fscarmen ;;
        singbox_yg) proxy_toolbox_run_singbox_yg ;;
        3xui) proxy_toolbox_run_3xui ;;
        realm_xwpf) proxy_toolbox_run_realm_xwpf ;;
        v2ray_agent) proxy_toolbox_run_v2ray_agent ;;
        hysteria2_install) proxy_toolbox_run_hysteria2_install ;;
        hysteria2_seagullz4) proxy_toolbox_run_hysteria2_seagullz4 ;;
        *)
            msg_err "未知代理工具: ${SCRIPTKIT_PROXY_TOOL:-<empty>}"
            return 1
            ;;
    esac
}

main "$@"
