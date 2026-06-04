#!/usr/bin/env bash

# Read-only system information actions.

system_info_os_name() {
    local os_name="unknown"

    if [ -r /etc/os-release ]; then
        os_name="$(
            . /etc/os-release 2>/dev/null
            printf '%s' "${PRETTY_NAME:-unknown}"
        )" || os_name="unknown"
    fi

    printf '%s' "$os_name"
}

system_info_print_time_status() {
    local timezone=""
    local ntp=""
    local synchronized=""
    local local_rtc=""

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

system_info_overview() {
    local hostname_value="unknown"
    local kernel_value="unknown"
    local uptime_value="unknown"
    local load_value="unknown"
    local user_name="unknown"
    local user_id="unknown"
    local group_id="unknown"
    local home_dir="${HOME:-unknown}"
    local shell_name="${SHELL:-unknown}"

    command_exists hostname && hostname_value="$(hostname 2>/dev/null || printf 'unknown')"
    command_exists uname && kernel_value="$(uname -srmo 2>/dev/null || uname -a 2>/dev/null || printf 'unknown')"
    command_exists whoami && user_name="$(whoami 2>/dev/null || printf 'unknown')"
    command_exists id && user_id="$(id -u 2>/dev/null || printf 'unknown')"
    command_exists id && group_id="$(id -g 2>/dev/null || printf 'unknown')"
    if command_exists uptime; then
        uptime_value="$(uptime -p 2>/dev/null || uptime 2>/dev/null || printf 'unknown')"
    fi
    if [ -r /proc/loadavg ]; then
        read -r load_value _ < /proc/loadavg || load_value="unknown"
    fi

    scriptkit_draw_current_title "系统概览"
    printf "主机名: %s\n" "$hostname_value"
    printf "系统: %s\n" "$(system_info_os_name)"
    printf "内核: %s\n" "$kernel_value"
    printf "运行时间: %s\n" "$uptime_value"
    printf "负载: %s\n" "$load_value"
    printf "\n当前用户: %s (UID=%s GID=%s)\n" "$user_name" "$user_id" "$group_id"
    printf "HOME: %s\n" "$home_dir"
    printf "SHELL: %s\n" "$shell_name"
    printf "\n%b时间与时区:%b\n" "$BOLD" "$PLAIN"
    system_info_print_time_status
}

system_info_memory() {
    scriptkit_draw_current_title "内存使用"
    if command_exists free; then
        free -h | awk '
            /^Mem:/ {
                printf "内存总量: %s\n", $2
                printf "已用内存: %s\n", $3
                printf "空闲内存: %s\n", $4
                printf "可用内存: %s\n", $7
            }
            /^Swap:/ {
                printf "\nSwap 总量: %s\n", $2
                printf "Swap 已用: %s\n", $3
                printf "Swap 空闲: %s\n", $4
            }
        '
    elif [ -r /proc/meminfo ]; then
        awk '
            /MemTotal/ { mem_total = $2 }
            /MemFree/ { mem_free = $2 }
            /MemAvailable/ { mem_available = $2 }
            /SwapTotal/ { swap_total = $2 }
            /SwapFree/ { swap_free = $2 }
            END {
                if (mem_total > 0) printf "内存总量: %.1f GiB\n", mem_total / 1024 / 1024
                if (mem_available > 0) {
                    printf "可用内存: %.1f GiB\n", mem_available / 1024 / 1024
                    printf "估算已用: %.1f GiB\n", (mem_total - mem_available) / 1024 / 1024
                } else if (mem_free > 0) {
                    printf "空闲内存: %.1f GiB\n", mem_free / 1024 / 1024
                    printf "估算已用: %.1f GiB\n", (mem_total - mem_free) / 1024 / 1024
                }
                if (swap_total > 0) printf "\nSwap 总量: %.1f GiB\n", swap_total / 1024 / 1024
                if (swap_free > 0) printf "Swap 空闲: %.1f GiB\n", swap_free / 1024 / 1024
            }
        ' /proc/meminfo
    else
        ui_warn "未找到 free，也无法读取 /proc/meminfo。"
    fi
}

system_info_disk() {
    scriptkit_draw_current_title "磁盘使用"
    if command_exists df; then
        df -hT -x tmpfs -x devtmpfs 2>/dev/null | awk '
            NR == 1 { next }
            {
                printf "挂载点: %s\n", $7
                printf "  设备: %s\n", $1
                printf "  类型: %s\n", $2
                printf "  总量: %s  已用: %s  可用: %s  使用率: %s\n\n", $3, $4, $5, $6
            }
        '
    else
        ui_warn "未找到 df。"
    fi

    if command_exists lsblk; then
        printf "%b块设备摘要:%b\n" "$BOLD" "$PLAIN"
        lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINTS 2>/dev/null || true
    fi
}

system_info_process_top() {
    scriptkit_draw_current_title "资源占用 TOP"
    if command_exists ps; then
        ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu 2>/dev/null | awk '
            NR == 1 { printf "%-8s %-12s %-8s %-8s %s\n", "PID", "用户", "CPU%", "MEM%", "命令"; next }
            NR <= 11 { printf "%-8s %-12s %-8s %-8s %s\n", $1, $2, $3, $4, $5 }
        '
    else
        ui_warn "未找到 ps。"
    fi
}

system_info_dir_size() {
    local path=""

    scriptkit_draw_current_title "目录体积统计"
    printf '%b' "$(ui_prompt "输入" "请输入要统计的目录（默认当前目录）: ")"
    read -r path
    path="${path:-.}"

    if [ ! -d "$path" ]; then
        ui_error "目录不存在: $path"
        return 1
    fi
    if ! command_exists du || ! command_exists sort || ! command_exists awk; then
        ui_error "需要 du、sort、awk。"
        return 1
    fi

    printf "\n目录: %s\n\n" "$path"
    du -h --max-depth=1 "$path" 2>/dev/null | sort -hr | awk '
        {
            size = $1
            $1 = ""
            sub(/^ /, "")
            printf "%-8s %s\n", size, $0
        }
    '
}

system_info_tcp_connections() {
    scriptkit_draw_current_title "TCP 连接统计"
    if ! command_exists ss || ! command_exists awk; then
        ui_error "需要 ss 和 awk。"
        return 1
    fi

    ss -antH 2>/dev/null | awk '
        { states[$1]++; total++ }
        END {
            printf "总连接数: %d\n", total + 0
            printf "已建立 ESTAB: %d\n", states["ESTAB"] + 0
            printf "监听 LISTEN: %d\n", states["LISTEN"] + 0
            printf "等待关闭 TIME-WAIT: %d\n", states["TIME-WAIT"] + 0
            printf "同步中 SYN-SENT/SYN-RECV: %d\n", states["SYN-SENT"] + states["SYN-RECV"] + 0
        }
    '
    printf "\nHTTP(S) 已建立连接:\n"
    ss -antH 2>/dev/null | awk '
        $1 == "ESTAB" {
            local_addr = $4
            if (local_addr ~ /:80$/) http++
            if (local_addr ~ /:443$/) https++
        }
        END {
            printf "80 端口已建立连接: %d\n", http + 0
            printf "443 端口已建立连接: %d\n", https + 0
            printf "HTTP(S) 合计: %d\n", http + https + 0
        }
    '
}

add_action "system_overview" "系统概览" "system" "system_info_overview"
add_action "system_memory" "内存使用" "system" "system_info_memory"
add_action "system_disk" "磁盘使用" "system" "system_info_disk"
add_action "system_process_top" "资源占用 TOP" "system" "system_info_process_top"
add_action "system_dir_size" "目录体积统计" "system" "system_info_dir_size"
add_action "system_tcp_connections" "TCP 连接统计" "system" "system_info_tcp_connections"
