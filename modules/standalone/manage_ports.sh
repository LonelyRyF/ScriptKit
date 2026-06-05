#!/usr/bin/env bash
set -u

# Manage listening ports, related processes, and firewall blocks.

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

normalize_ports() {
    local input="$1"
    local port=""

    input="${input//,/ }"
    for port in $input; do
        if validate_port "$port"; then
            printf '%s\n' "$port"
        else
            msg_warn "跳过无效端口: $port" >&2
        fi
    done
}

list_ports() {
    printf "%b== 监听端口 ========================================%b\n\n" "$BOLD" "$PLAIN"
    if command_exists ss; then
        ss -tulpenH 2>/dev/null | awk '
            {
                process = "-"
                for (i = 1; i <= NF; i++) {
                    if ($i ~ /users:/) process = $i
                }
                printf "协议: %-5s 状态: %-10s 本地地址: %-28s 进程: %s\n", $1, $2, $5, process
                found = 1
            }
            END { if (!found) print "未发现监听端口。" }
        '
    elif command_exists netstat; then
        netstat -tulnp 2>/dev/null | awk '
            NR > 2 {
                state = $6
                process = $7
                if ($1 ~ /^udp/) {
                    state = "-"
                    process = $6
                }
                printf "协议: %-5s 状态: %-10s 本地地址: %-28s 进程: %s\n", $1, state, $4, (process == "" ? "-" : process)
                found = 1
            }
            END { if (!found) print "未发现监听端口。" }
        '
    else
        msg_err "未找到 ss 或 netstat"
        return 1
    fi
}

lookup_ports() {
    local input=""
    local ports=""
    local port=""

    printf '%b' "$(msg_prompt "输入" "请输入要查询的端口号，多个用逗号分隔: ")"
    read -r input
    ports="$(normalize_ports "$input")"
    if [ -z "$ports" ]; then
        msg_warn "没有有效端口"
        return 1
    fi

    printf "\n%b== 指定端口查询 ========================================%b\n\n" "$BOLD" "$PLAIN"
    for port in $ports; do
        printf "%b端口 %s:%b\n" "$BOLD" "$port" "$PLAIN"
        if command_exists ss; then
            ss -tulpenH 2>/dev/null | awk -v port="$port" '
                $5 ~ "[:.]" port "$" {
                    process = "-"
                    for (i = 1; i <= NF; i++) if ($i ~ /users:/) process = $i
                    printf "  协议: %-5s 状态: %-10s 本地地址: %-28s 进程: %s\n", $1, $2, $5, process
                    found = 1
                }
                END { if (!found) print "  未发现监听。" }
            '
        elif command_exists netstat; then
            netstat -tulnp 2>/dev/null | awk -v port="$port" '
                NR > 2 && $4 ~ "[:.]" port "$" {
                    state = $6
                    process = $7
                    if ($1 ~ /^udp/) {
                        state = "-"
                        process = $6
                    }
                    printf "  协议: %-5s 状态: %-10s 本地地址: %-28s 进程: %s\n", $1, state, $4, (process == "" ? "-" : process)
                    found = 1
                }
                END { if (!found) print "  未发现监听。" }
            '
        else
            msg_err "未找到 ss 或 netstat"
            return 1
        fi
        printf '\n'
    done
}

find_port_pids() {
    local port="$1"

    if command_exists ss; then
        ss -tulpenH 2>/dev/null | awk -v port="$port" '
            $5 ~ "[:.]" port "$" {
                line = $0
                while (match(line, /pid=[0-9]+/)) {
                    print substr(line, RSTART + 4, RLENGTH - 4)
                    line = substr(line, RSTART + RLENGTH)
                }
            }
        ' | sort -u
    elif command_exists lsof; then
        {
            lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null
            lsof -nP -iUDP:"$port" -t 2>/dev/null
        } | sort -u
    elif command_exists fuser; then
        fuser "${port}/tcp" "${port}/udp" 2>/dev/null | tr ' ' '\n' | awk 'NF' | sort -u
    fi
}

show_processes() {
    local pid=""
    local user=""
    local comm=""
    local args=""

    printf "%b相关进程:%b\n" "$BOLD" "$PLAIN"
    for pid in "$@"; do
        if ! kill -0 "$pid" 2>/dev/null; then
            continue
        fi
        user="$(ps -p "$pid" -o user= 2>/dev/null | awk '{print $1}')"
        comm="$(ps -p "$pid" -o comm= 2>/dev/null | awk '{print $1}')"
        args="$(ps -p "$pid" -o args= 2>/dev/null || true)"
        printf "  PID: %-8s 用户: %-12s 命令: %s\n" "$pid" "${user:--}" "${comm:--}"
        [ -n "$args" ] && printf "    %s\n" "$args"
    done
}

terminate_port_processes() {
    local port=""
    local -a pids=()
    local -a alive=()
    local pid=""

    require_root_action || return 1

    printf '%b' "$(msg_prompt "输入" "请输入要停止占用进程的端口号: ")"
    read -r port
    if ! validate_port "$port"; then
        msg_warn "端口号无效"
        return 1
    fi

    while IFS= read -r pid; do
        [ -n "$pid" ] && pids+=("$pid")
    done < <(find_port_pids "$port")

    if [ "${#pids[@]}" -eq 0 ]; then
        msg_info "未找到占用端口 $port 的监听进程"
        return 0
    fi

    show_processes "${pids[@]}"
    if ! yesno_select "确认向这些进程发送 TERM 信号？"; then
        msg_info "已取消"
        return 0
    fi

    for pid in "${pids[@]}"; do
        kill "$pid" 2>/dev/null || msg_warn "无法停止 PID $pid"
    done
    sleep 1

    for pid in "${pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            alive+=("$pid")
        fi
    done

    if [ "${#alive[@]}" -gt 0 ]; then
        show_processes "${alive[@]}"
        if yesno_select "仍有进程未退出，是否使用 KILL -9 强制终止？"; then
            for pid in "${alive[@]}"; do
                kill -9 "$pid" 2>/dev/null || msg_warn "无法强制终止 PID $pid"
            done
        fi
    fi

    msg_ok "端口 $port 的进程处理完成"
}

block_one_port() {
    local fw="$1"
    local port="$2"

    case "$fw" in
        ufw)
            ufw deny "$port/tcp" >/dev/null 2>&1 && ufw deny "$port/udp" >/dev/null 2>&1
            ;;
        firewalld)
            firewall-cmd --permanent --add-rich-rule="rule port protocol=\"tcp\" port=\"$port\" drop" >/dev/null 2>&1 && \
                firewall-cmd --permanent --add-rich-rule="rule port protocol=\"udp\" port=\"$port\" drop" >/dev/null 2>&1 && \
                firewall-cmd --reload >/dev/null 2>&1
            ;;
        iptables)
            (iptables -C INPUT -p tcp --dport "$port" -j DROP 2>/dev/null || iptables -A INPUT -p tcp --dport "$port" -j DROP) && \
                (iptables -C INPUT -p udp --dport "$port" -j DROP 2>/dev/null || iptables -A INPUT -p udp --dport "$port" -j DROP)
            ;;
        *)
            return 1
            ;;
    esac
}

block_ports_firewall() {
    local input=""
    local ports=""
    local port=""
    local fw=""

    require_root_action || return 1

    printf '%b' "$(msg_prompt "输入" "请输入要封禁的端口号，多个用逗号分隔: ")"
    read -r input
    ports="$(normalize_ports "$input")"
    if [ -z "$ports" ]; then
        msg_warn "没有有效端口"
        return 1
    fi

    fw="$(detect_firewall)"
    if [ "$fw" = "none" ]; then
        msg_warn "未检测到 ufw、firewalld 或 iptables，已跳过"
        return 1
    fi

    printf "将使用防火墙: %s\n" "$fw"
    printf "将封禁端口:\n"
    for port in $ports; do
        printf "  - %s/tcp 和 %s/udp\n" "$port" "$port"
    done
    if ! yesno_select "确认添加封禁规则？"; then
        msg_info "已取消"
        return 0
    fi

    for port in $ports; do
        if block_one_port "$fw" "$port"; then
            msg_ok "已封禁端口 $port (tcp/udp)"
        else
            msg_err "封禁端口失败: $port"
        fi
    done

    if [ "$fw" = "iptables" ]; then
        msg_warn "iptables 规则可能重启后失效，请按系统发行版方式持久化"
    fi
}

main() {
    local selected=0
    local -a menu_labels=(
        "查看所有监听端口"
        "查看指定端口"
        "停止占用指定端口的进程"
        "使用防火墙封禁端口"
        "退出"
    )

    case "${SCRIPTKIT_MANAGE_PORTS_MODE:-}" in
        terminate)
            draw_current_title "端口管理"
            terminate_port_processes
            return
            ;;
        block)
            draw_current_title "端口管理"
            block_ports_firewall
            return
            ;;
    esac

    while true; do
        if ! select_menu "$(scriptkit_current_title "端口管理")" menu_labels selected 0; then
            msg_info "已取消"
            return 0
        fi

        case "$selected" in
            0) list_ports ;;
            1) lookup_ports ;;
            2) terminate_port_processes ;;
            3) block_ports_firewall ;;
            4) return 0 ;;
            *) msg_warn "无效选择" ;;
        esac

        printf '\n%b' "$(msg_prompt "提示" "按 Enter 继续...")"
        read -r _
        clear 2>/dev/null || true
    done
}

main
