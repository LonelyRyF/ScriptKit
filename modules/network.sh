#!/usr/bin/env bash

# Read-only network diagnostics.

network_overview() {
    printf "%b== 网络概览 ========================================%b\n\n" "$BOLD" "$PLAIN"

    if command_exists ip; then
        printf "%b接口地址:%b\n" "$BOLD" "$PLAIN"
        ip -o -4 addr show scope global 2>/dev/null | awk '{ printf "  %-12s IPv4: %s\n", $2, $4 }'
        ip -o -6 addr show scope global 2>/dev/null | awk '{ printf "  %-12s IPv6: %s\n", $2, $4 }'

        printf "\n%b默认路由:%b\n" "$BOLD" "$PLAIN"
        ip route show default 2>/dev/null | awk '{ printf "  网关: %s  接口: %s\n", $3, $5 }'
    else
        ui_warn "未找到 ip 命令。"
    fi

    if [ -r /etc/resolv.conf ]; then
        printf "\n%bDNS:%b\n" "$BOLD" "$PLAIN"
        awk '/^nameserver/ { print "  " $2 }' /etc/resolv.conf
    fi
}

network_connectivity_check() {
    local target
    local -a targets=("1.1.1.1" "8.8.8.8" "github.com" "raw.githubusercontent.com")

    printf "%b== 连通性检查 ========================================%b\n\n" "$BOLD" "$PLAIN"
    if ! command_exists ping; then
        ui_error "未找到 ping。"
        return 1
    fi

    for target in "${targets[@]}"; do
        printf "%-28s" "$target"
        if ping -c 1 -W 2 "$target" >/dev/null 2>&1; then
            printf "%bOK%b\n" "$GREEN" "$PLAIN"
        else
            printf "%bFAIL%b\n" "$RED" "$PLAIN"
        fi
    done
}

network_dns_lookup() {
    local domain=""

    printf '%b' "$(ui_prompt "输入" "请输入要查询的域名（默认 github.com）: ")"
    read -r domain
    domain="${domain:-github.com}"

    printf "\n%b== DNS 查询: %s ========================================%b\n\n" "$BOLD" "$domain" "$PLAIN"
    if command_exists dig; then
        dig +short "$domain" | awk '{ print "  " $0 }'
    elif command_exists nslookup; then
        nslookup "$domain" 2>/dev/null | awk '/^Address: / { print "  " $2 }'
    elif command_exists getent; then
        getent hosts "$domain" | awk '{ print "  " $1 }'
    else
        ui_error "未找到 dig、nslookup 或 getent。"
        return 1
    fi
}

network_listening_ports() {
    printf "%b== 监听端口 ========================================%b\n\n" "$BOLD" "$PLAIN"
    if command_exists ss; then
        ss -tulnH 2>/dev/null | awk '{ printf "协议: %-5s 状态: %-10s 本地地址: %s\n", $1, $2, $5 }'
    elif command_exists netstat; then
        netstat -tuln 2>/dev/null | awk 'NR > 2 { printf "协议: %-5s 本地地址: %-24s 状态: %s\n", $1, $4, $6 }'
    else
        ui_error "未找到 ss 或 netstat。"
        return 1
    fi
}

network_port_lookup() {
    local input=""
    local port=""

    printf '%b' "$(ui_prompt "输入" "请输入要查询的端口号，多个用逗号分隔: ")"
    read -r input
    if [ -z "$input" ]; then
        ui_warn "端口号不能为空。"
        return 1
    fi

    printf "\n%b== 指定端口查询 ========================================%b\n\n" "$BOLD" "$PLAIN"
    input="${input//,/ }"
    for port in $input; do
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
            ui_warn "跳过无效端口: $port"
            continue
        fi

        printf "%b端口 %s:%b\n" "$BOLD" "$port" "$PLAIN"
        if command_exists ss; then
            ss -tulpenH 2>/dev/null | awk -v port="$port" '
                $5 ~ ":" port "$" {
                    process = ($NF == "" ? "-" : $NF)
                    printf "  协议: %-5s 状态: %-10s 本地地址: %-24s 进程: %s\n", $1, $2, $5, process
                    found = 1
                }
                END { if (!found) printf "  未发现监听。\n" }
            '
        elif command_exists netstat; then
            netstat -tulnp 2>/dev/null | awk -v port="$port" '
                NR > 2 && $4 ~ ":" port "$" {
                    process = ($7 == "" ? "-" : $7)
                    printf "  协议: %-5s 状态: %-10s 本地地址: %-24s 进程: %s\n", $1, $6, $4, process
                    found = 1
                }
                END { if (!found) printf "  未发现监听。\n" }
            '
        else
            ui_error "未找到 ss 或 netstat。"
            return 1
        fi
        printf "\n"
    done
}

add_action "network_overview" "网络概览" "network" "network_overview"
add_action "network_connectivity" "连通性检查" "network" "network_connectivity_check"
add_action "network_dns_lookup" "DNS 查询" "network" "network_dns_lookup"
add_action "network_listening_ports" "监听端口" "network" "network_listening_ports"
add_action "network_port_lookup" "指定端口查询" "network" "network_port_lookup"
add_script "network_manage_ports" "端口管理" "network" "modules/standalone/manage_ports.sh"
