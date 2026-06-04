#!/usr/bin/env bash

# Small utility actions.

utility_public_ip() {
    local ip=""

    printf "%b== 公网 IP ========================================%b\n\n" "$BOLD" "$PLAIN"
    if command_exists curl; then
        ip="$(curl -fsSL --max-time 8 https://api.ipify.org 2>/dev/null || true)"
        [ -z "$ip" ] && ip="$(curl -fsSL --max-time 8 https://ifconfig.me 2>/dev/null || true)"
    elif command_exists wget; then
        ip="$(wget -qO- --timeout=8 https://api.ipify.org 2>/dev/null || true)"
        [ -z "$ip" ] && ip="$(wget -qO- --timeout=8 https://ifconfig.me 2>/dev/null || true)"
    else
        ui_error "未找到 curl 或 wget。"
        return 1
    fi

    if [ -n "$ip" ]; then
        printf "公网 IP: %s\n" "$ip"
    else
        ui_error "获取公网 IP 失败。"
        return 1
    fi
}

utility_random_password() {
    local length=""
    local password=""

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

utility_time_status() {
    local timezone=""
    local ntp=""
    local synchronized=""
    local local_rtc=""

    printf "%b== 时间与时区 ========================================%b\n\n" "$BOLD" "$PLAIN"
    if command_exists date; then
        printf "当前时间: %s\n" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    fi

    if command_exists timedatectl; then
        timezone="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
        ntp="$(timedatectl show -p NTP --value 2>/dev/null || true)"
        synchronized="$(timedatectl show -p NTPSynchronized --value 2>/dev/null || true)"
        local_rtc="$(timedatectl show -p LocalRTC --value 2>/dev/null || true)"

        printf "时区: %s\n" "${timezone:-unknown}"
        printf "NTP 启用: %s\n" "${ntp:-unknown}"
        printf "时间已同步: %s\n" "${synchronized:-unknown}"
        printf "硬件时钟使用本地时间: %s\n" "${local_rtc:-unknown}"
    fi
}

add_action "utility_public_ip" "查看公网 IP" "utility" "utility_public_ip"
add_action "utility_random_password" "生成随机密码" "utility" "utility_random_password"
add_action "utility_time_status" "时间与时区" "utility" "utility_time_status"
add_script "utility_crontab" "Crontab 管理" "utility" "modules/standalone/manage_crontab.sh"
add_script "utility_terminal_setup" "终端优化" "utility" "modules/standalone/terminal_setup.sh"
