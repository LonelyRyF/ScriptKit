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

system_info_overview() {
    local hostname_value="unknown"
    local kernel_value="unknown"
    local uptime_value="unknown"
    local load_value="unknown"

    command_exists hostname && hostname_value="$(hostname 2>/dev/null || printf 'unknown')"
    command_exists uname && kernel_value="$(uname -srmo 2>/dev/null || uname -a 2>/dev/null || printf 'unknown')"
    if command_exists uptime; then
        uptime_value="$(uptime -p 2>/dev/null || uptime 2>/dev/null || printf 'unknown')"
    fi
    if [ -r /proc/loadavg ]; then
        read -r load_value _ < /proc/loadavg || load_value="unknown"
    fi

    printf "%b== 系统概览 ========================================%b\n\n" "$BOLD" "$PLAIN"
    printf "主机名: %s\n" "$hostname_value"
    printf "系统: %s\n" "$(system_info_os_name)"
    printf "内核: %s\n" "$kernel_value"
    printf "运行时间: %s\n" "$uptime_value"
    printf "负载: %s\n" "$load_value"
}

system_info_memory() {
    printf "%b== 内存使用 ========================================%b\n\n" "$BOLD" "$PLAIN"
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
        printf "%b[WARN]%b 未找到 free，也无法读取 /proc/meminfo。\n" "$YELLOW" "$PLAIN"
    fi
}

system_info_disk() {
    printf "%b== 磁盘使用 ========================================%b\n\n" "$BOLD" "$PLAIN"
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
        printf "%b[WARN]%b 未找到 df。\n" "$YELLOW" "$PLAIN"
    fi

    if command_exists lsblk; then
        printf "%b块设备摘要:%b\n" "$BOLD" "$PLAIN"
        lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINTS 2>/dev/null || true
    fi
}

system_info_process_top() {
    printf "%b== 资源占用 TOP ========================================%b\n\n" "$BOLD" "$PLAIN"
    if command_exists ps; then
        ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu 2>/dev/null | awk '
            NR == 1 { printf "%-8s %-12s %-8s %-8s %s\n", "PID", "用户", "CPU%", "MEM%", "命令"; next }
            NR <= 11 { printf "%-8s %-12s %-8s %-8s %s\n", $1, $2, $3, $4, $5 }
        '
    else
        printf "%b[WARN]%b 未找到 ps。\n" "$YELLOW" "$PLAIN"
    fi
}

add_action "system_overview" "系统概览" "system" "system_info_overview"
add_action "system_memory" "内存使用" "system" "system_info_memory"
add_action "system_disk" "磁盘使用" "system" "system_info_disk"
add_action "system_process_top" "资源占用 TOP" "system" "system_info_process_top"
