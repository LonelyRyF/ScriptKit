#!/usr/bin/env bash
set -u

# Download and run Hard Disk Sentinel Linux edition.

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

TMP_DIR=""

cleanup_temp() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

handle_interrupt() {
    printf '\n'
    msg_cancelled
    exit 130
}

trap cleanup_temp EXIT
trap handle_interrupt INT TERM

DISKS=()

collect_disks() {
    local device=""

    DISKS=()
    while IFS= read -r device; do
        [ -n "$device" ] && DISKS+=("$device")
    done < <(lsblk -dnpo NAME,TYPE 2>/dev/null | awk '$2 == "disk" { print $1 }')
}

show_disk_inventory() {
    printf "\n"
    draw_step_title "当前块设备"
    if [ "${#DISKS[@]}" -eq 0 ]; then
        printf "未发现可用块设备。\n"
        return 1
    fi

    lsblk -d -o NAME,TYPE,TRAN,SIZE,MODEL,SERIAL 2>/dev/null || true
    return 0
}

is_likely_virtual_disk_env() {
    lsblk -dn -o MODEL,VENDOR 2>/dev/null | awk '
        /QEMU|Virtio|Virtual|VMware|VBOX|Msft|Google|Amazon|OpenStack|KVM/ {
            found = 1
        }
        END { exit found ? 0 : 1 }
    '
}

install_optional_tool() {
    local package_name="$1"

    install_packages "$package_name" >/dev/null 2>&1 || true
}

smartctl_output_for_device() {
    local device="$1"
    local output=""
    local driver=""

    output="$(smartctl -H -i -A "$device" 2>&1 || true)"
    if [ -n "$output" ] && [[ "$output" != *"Smartctl open device"* ]]; then
        printf '%s' "$output"
        return 0
    fi

    case "$device" in
        /dev/nvme*)
            output="$(smartctl -H -i -A -d nvme "$device" 2>&1 || true)"
            ;;
        /dev/sd*|/dev/vd*|/dev/xvd*)
            for driver in scsi sat; do
                output="$(smartctl -H -i -A -d "$driver" "$device" 2>&1 || true)"
                if [ -n "$output" ] && [[ "$output" != *"Smartctl open device"* ]]; then
                    printf '%s' "$output"
                    return 0
                fi
            done
            ;;
    esac

    if [ -n "$output" ]; then
        printf '%s' "$output"
        return 0
    fi

    return 1
}

nvme_output_for_device() {
    local device="$1"
    local controller=""
    local id_output=""
    local smart_output=""

    case "$device" in
        /dev/nvme*n*) controller="${device%n*}" ;;
        /dev/nvme*) controller="$device" ;;
        *) return 1 ;;
    esac

    id_output="$(nvme id-ctrl "$controller" 2>&1 || true)"
    smart_output="$(nvme smart-log "$device" 2>&1 || true)"
    if [ -z "$id_output" ] && [ -z "$smart_output" ]; then
        return 1
    fi

    [ -n "$id_output" ] && printf '%s\n' "$id_output"
    [ -n "$smart_output" ] && printf '%s\n' "$smart_output"
}

fallback_disk_report() {
    local device=""
    local output=""
    local used_tool=1

    collect_disks
    show_disk_inventory || return 1

    if is_likely_virtual_disk_env; then
        msg_warn "当前环境看起来像虚拟机 / 云主机虚拟磁盘。HDSentinel 经常无法直接识别这类设备，这不是 ScriptKit 没用 root 运行。"
    else
        msg_warn "HDSentinel 未能识别当前磁盘控制器或设备类型，已回退到系统原生健康信息工具。"
    fi

    if ! command_exists smartctl; then
        install_optional_tool smartmontools
    fi
    if ! command_exists nvme; then
        install_optional_tool nvme-cli
    fi

    for device in "${DISKS[@]}"; do
        printf "\n%b设备: %s%b\n" "$BOLD" "$device" "$PLAIN"

        output=""
        if command_exists smartctl; then
            output="$(smartctl_output_for_device "$device" 2>/dev/null || true)"
            if [ -n "$output" ]; then
                printf '%s\n' "$output" | awk '{ print "  " $0 }'
                used_tool=0
                continue
            fi
        fi

        if command_exists nvme; then
            output="$(nvme_output_for_device "$device" 2>/dev/null || true)"
            if [ -n "$output" ]; then
                printf '%s\n' "$output" | awk '{ print "  " $0 }'
                used_tool=0
                continue
            fi
        fi

        msg_warn "未能读取该设备的 SMART / NVMe 健康信息。"
    done

    return "$used_tool"
}

main() {
    local url="https://www.hdsentinel.com/hdslin/hdsentinel-019c-x64.gz"
    local archive=""
    local binary=""
    local arch=""
    local rc=0
    local output=""

    check_root
    ensure_commands mktemp chmod "gunzip:gzip" lsblk awk || exit 1

    arch="$(uname -m 2>/dev/null || true)"
    case "$arch" in
        x86_64|amd64) ;;
        *)
            msg_err "当前架构不受该二进制支持: ${arch:-unknown}"
            exit 1
            ;;
    esac

    TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/scriptkit-disk-test.XXXXXX")" || {
        msg_err "无法创建临时目录"
        exit 1
    }
    archive="$TMP_DIR/hdsentinel.gz"
    binary="$TMP_DIR/hdsentinel"

    msg_info "正在下载 Hard Disk Sentinel..."
    download_file "$url" "$archive" || {
        msg_err "下载失败，请检查网络连接"
        exit 1
    }

    msg_info "正在解压测试程序..."
    gunzip -c "$archive" > "$binary" || {
        msg_err "解压失败"
        exit 1
    }
    chmod 755 "$binary" || {
        msg_err "无法设置执行权限"
        exit 1
    }

    draw_current_title "磁盘健康检测"
    output="$("$binary" 2>&1)"
    rc=$?
    printf '%s\n' "$output"

    if [ "$rc" -eq 0 ]; then
        msg_ok "磁盘检测已完成"
        return 0
    fi

    case "$output" in
        *"No hard disk devices found"*|*"Please run as \"root\""*)
            if fallback_disk_report; then
                msg_ok "已回退到 smartctl / nvme 检测"
                return 0
            fi
            ;;
    esac

    msg_warn "检测程序退出码: $rc"
    return "$rc"
}

main
