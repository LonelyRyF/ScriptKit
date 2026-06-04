#!/usr/bin/env bash
set -u

# Partition, format, mount, and persist a non-system data disk.

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

CANDIDATE_DISKS=()
CANDIDATE_LABELS=()

partition_path() {
    local disk="$1"

    case "$disk" in
        *[0-9]) printf '%sp1' "$disk" ;;
        *) printf '%s1' "$disk" ;;
    esac
}

root_disk_path() {
    local root_source=""
    local current=""
    local parent=""
    local type=""

    root_source="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
    [ -n "$root_source" ] || return 1
    [[ "$root_source" == /dev/* ]] || return 1

    current="$root_source"
    while true; do
        type="$(lsblk -ndo TYPE "$current" 2>/dev/null | awk 'NR == 1 { print; exit }')"
        parent="$(lsblk -ndo PKNAME "$current" 2>/dev/null | awk 'NF { print $1; exit }')"

        if [ "$type" = "disk" ] || [ -z "$parent" ]; then
            break
        fi
        current="/dev/$parent"
    done

    if [[ "$current" == /dev/* ]]; then
        printf '%s' "$current"
        return 0
    fi

    return 1
}

disk_has_mounted_children() {
    local disk="$1"

    lsblk -nrpo NAME,MOUNTPOINT "$disk" 2>/dev/null | awk 'NF >= 2 && $2 != "" { found = 1 } END { exit found ? 0 : 1 }'
}

disk_partition_count() {
    local disk="$1"

    lsblk -nrpo TYPE "$disk" 2>/dev/null | awk '$1 == "part" { count++ } END { print count + 0 }'
}

disk_filesystem_summary() {
    local disk="$1"

    lsblk -nrpo NAME,FSTYPE "$disk" 2>/dev/null | awk '
        NF >= 2 && $2 != "" {
            summary = summary (summary == "" ? "" : ", ") $1 ":" $2
        }
        END {
            if (summary == "") {
                print "none"
            } else {
                print summary
            }
        }
    '
}

disk_label() {
    local disk="$1"
    local size=""
    local model=""
    local partitions=""
    local fs_summary=""

    size="$(lsblk -dnro SIZE "$disk" 2>/dev/null | awk 'NR == 1 { print; exit }')"
    model="$(lsblk -dnro MODEL "$disk" 2>/dev/null | awk 'NR == 1 { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print; exit }')"
    partitions="$(disk_partition_count "$disk")"
    fs_summary="$(disk_filesystem_summary "$disk")"

    printf '%s  size=%s  partitions=%s  fs=%s%s' \
        "$disk" \
        "${size:-unknown}" \
        "$partitions" \
        "$fs_summary" \
        "$( [ -n "$model" ] && printf '  model=%s' "$model" )"
}

collect_candidate_disks() {
    local disk=""
    local root_disk=""

    CANDIDATE_DISKS=()
    CANDIDATE_LABELS=()
    root_disk="$(root_disk_path 2>/dev/null || true)"

    while IFS= read -r disk; do
        [ -n "$disk" ] || continue
        [ "$disk" = "$root_disk" ] && continue

        if disk_has_mounted_children "$disk"; then
            continue
        fi

        CANDIDATE_DISKS+=("$disk")
        CANDIDATE_LABELS+=("$(disk_label "$disk")")
    done < <(lsblk -dnrpo NAME,TYPE 2>/dev/null | awk '$2 == "disk" { print $1 }')
}

choose_disk() {
    local selected=0

    [ "${#CANDIDATE_DISKS[@]}" -gt 0 ] || return 1
    select_menu "选择要挂载的数据盘" CANDIDATE_LABELS selected || return 1
    printf '%s' "${CANDIDATE_DISKS[$selected]}"
}

choose_filesystem() {
    local selected=0
    local -a filesystems=("ext4" "xfs" "btrfs")

    select_menu "选择文件系统" filesystems selected || return 1
    printf '%s' "${filesystems[$selected]}"
}

ensure_filesystem_tool() {
    local filesystem="$1"

    case "$filesystem" in
        ext4) ensure_commands "mkfs.ext4:e2fsprogs" ;;
        xfs) ensure_commands "mkfs.xfs:xfsprogs" ;;
        btrfs) ensure_commands "mkfs.btrfs:btrfs-progs" ;;
        *)
            msg_err "不支持的文件系统: $filesystem"
            return 1
            ;;
    esac
}

backup_fstab() {
    local backup="/etc/fstab.scriptkit.bak.$(date +%Y%m%d%H%M%S)"

    cp /etc/fstab "$backup" || {
        msg_err "备份 /etc/fstab 失败"
        return 1
    }
    msg_ok "/etc/fstab 已备份到: $backup"
}

write_fstab_entry() {
    local partition="$1"
    local mount_point="$2"
    local filesystem="$3"
    local uuid=""
    local tmp_file=""

    uuid="$(blkid -s UUID -o value "$partition" 2>/dev/null || true)"
    if [ -z "$uuid" ]; then
        msg_err "无法读取分区 UUID: $partition"
        return 1
    fi

    tmp_file="$(mktemp)" || return 1
    awk -v uuid="UUID=$uuid" -v mount_point="$mount_point" '
        $1 != uuid && $2 != mount_point { print }
    ' /etc/fstab > "$tmp_file" || {
        rm -f "$tmp_file"
        return 1
    }
    printf 'UUID=%s %s %s defaults,nofail 0 2\n' "$uuid" "$mount_point" "$filesystem" >> "$tmp_file"

    cp "$tmp_file" /etc/fstab || {
        rm -f "$tmp_file"
        return 1
    }
    rm -f "$tmp_file"
}

format_partition() {
    local partition="$1"
    local filesystem="$2"

    case "$filesystem" in
        ext4) mkfs.ext4 -F "$partition" >/dev/null 2>&1 ;;
        xfs) mkfs.xfs -f "$partition" >/dev/null 2>&1 ;;
        btrfs) mkfs.btrfs -f "$partition" >/dev/null 2>&1 ;;
    esac
}

show_disk_layout() {
    local disk="$1"

    printf "\n%b当前磁盘布局:%b\n" "$BOLD" "$PLAIN"
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS "$disk" 2>/dev/null || true
}

main() {
    local disk=""
    local filesystem=""
    local mount_point=""
    local partition=""
    local existing_summary=""

    check_root
    ensure_commands lsblk blkid findmnt mount awk mkdir mktemp parted "partprobe:parted" || exit 1

    collect_candidate_disks
    if [ "${#CANDIDATE_DISKS[@]}" -eq 0 ]; then
        msg_err "未找到可安全处理的数据盘。系统盘和已挂载磁盘已自动排除。"
        exit 1
    fi

    msg_info "仅显示非系统盘且当前未挂载的磁盘。"
    disk="$(choose_disk)" || exit 0
    show_disk_layout "$disk"

    filesystem="$(choose_filesystem)" || exit 0
    ensure_filesystem_tool "$filesystem" || exit 1

    printf '\n%b' "$(msg_prompt "输入" "挂载点（默认 /mnt/$(basename "$disk")）: ")"
    read -r mount_point
    mount_point="${mount_point:-/mnt/$(basename "$disk")}"

    if [[ "$mount_point" != /* ]]; then
        msg_err "挂载点必须是绝对路径"
        exit 1
    fi

    partition="$(partition_path "$disk")"
    existing_summary="$(disk_filesystem_summary "$disk")"

    printf "\n将执行以下操作:\n"
    printf "  磁盘: %s\n" "$disk"
    printf "  新分区: %s\n" "$partition"
    printf "  文件系统: %s\n" "$filesystem"
    printf "  挂载点: %s\n" "$mount_point"
    printf "  当前检测到的文件系统: %s\n" "$existing_summary"
    printf "  说明: 将重建分区表并清空该磁盘上的现有数据\n"

    if ! yesno_select "确认继续格式化并挂载该磁盘？"; then
        msg_info "已取消"
        exit 0
    fi

    backup_fstab || exit 1
    mkdir -p "$mount_point" || {
        msg_err "无法创建挂载点: $mount_point"
        exit 1
    }

    msg_info "正在重建分区表..."
    parted -s "$disk" mklabel gpt || {
        msg_err "创建 GPT 分区表失败: $disk"
        exit 1
    }
    parted -s "$disk" mkpart primary "$filesystem" 0% 100% || {
        msg_err "创建分区失败: $disk"
        exit 1
    }
    partprobe "$disk" >/dev/null 2>&1 || true
    if command_exists udevadm; then
        udevadm settle >/dev/null 2>&1 || true
    else
        sleep 2
    fi

    if [ ! -b "$partition" ]; then
        msg_err "新分区未出现: $partition"
        exit 1
    fi

    msg_info "正在格式化分区: $partition ($filesystem)"
    format_partition "$partition" "$filesystem" || {
        msg_err "格式化失败: $partition"
        exit 1
    }

    msg_info "正在挂载分区..."
    mount "$partition" "$mount_point" || {
        msg_err "挂载失败: $partition -> $mount_point"
        exit 1
    }

    write_fstab_entry "$partition" "$mount_point" "$filesystem" || {
        msg_err "写入 /etc/fstab 失败"
        exit 1
    }

    if findmnt --target "$mount_point" >/dev/null 2>&1; then
        msg_ok "磁盘已挂载到: $mount_point"
        printf "分区: %s\n" "$partition"
        printf "文件系统: %s\n" "$filesystem"
    else
        msg_err "挂载验证失败"
        exit 1
    fi
}

main
