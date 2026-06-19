#!/usr/bin/env bash
set -u

# Comprehensive disk manager: mount/format data disks, unmount and clean
# /etc/fstab, manage partitions, and run fsck / filesystem resize.

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

CANDIDATE_DISKS=()
CANDIDATE_LABELS=()
PARTITION_OPTIONS=()
PARTITION_LABELS=()
MOUNTED_DEVICES=()
MOUNTED_DEVICE_LABELS=()
FSTAB_ENTRY_LINES=()
FSTAB_ENTRY_LABELS=()

FSTAB_BACKUP=""
MOUNT_POINT_CREATED=0
MOUNTED_BY_SCRIPT=0
TARGET_MOUNT_POINT=""

# 每次操作前后都清理临时回滚状态，避免后续异常退出误撤销已成功的变更。
reset_mount_state() {
    FSTAB_BACKUP=""
    MOUNT_POINT_CREATED=0
    MOUNTED_BY_SCRIPT=0
    TARGET_MOUNT_POINT=""
}

# 撤销本次挂载操作产生的副作用：卸载、还原 fstab、删除新建挂载点。
rollback_mount_state() {
    if [ "$MOUNTED_BY_SCRIPT" -eq 1 ] && [ -n "${TARGET_MOUNT_POINT:-}" ]; then
        umount "$TARGET_MOUNT_POINT" >/dev/null 2>&1 || true
    fi

    if [ -n "$FSTAB_BACKUP" ] && [ -f "$FSTAB_BACKUP" ]; then
        cp "$FSTAB_BACKUP" /etc/fstab >/dev/null 2>&1 || true
    fi

    if [ "$MOUNT_POINT_CREATED" -eq 1 ] && [ -n "${TARGET_MOUNT_POINT:-}" ] && [ -d "$TARGET_MOUNT_POINT" ]; then
        rmdir "$TARGET_MOUNT_POINT" >/dev/null 2>&1 || true
    fi
}

# 脚本异常退出（如 Ctrl+C）时的兜底回滚。
cleanup_on_error() {
    local exit_code="$?"

    if [ "$exit_code" -eq 0 ]; then
        return 0
    fi

    rollback_mount_state
}

handle_interrupt() {
    printf '\n'
    msg_cancelled
    exit 130
}

trap cleanup_on_error EXIT
trap handle_interrupt INT TERM

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

is_root_device() {
    local device="$1"
    local root_disk=""
    local root_source=""

    root_disk="$(root_disk_path 2>/dev/null || true)"
    root_source="$(findmnt -n -o SOURCE / 2>/dev/null || true)"

    [ -n "$root_disk" ] && [ "$device" = "$root_disk" ] && return 0
    [ -n "$root_source" ] && [ "$device" = "$root_source" ] && return 0

    case "$root_source" in
        /dev/*)
            if [ "$device" = "/dev/$(lsblk -ndo PKNAME "$root_source" 2>/dev/null | awk 'NF { print $1; exit }')" ]; then
                return 0
            fi
            ;;
    esac

    return 1
}

is_system_mountpoint() {
    local mount_point="$1"

    case "$mount_point" in
        ""|"/"|"/boot"|"/boot/"*|"/efi"|"/efi/"*|"/usr"|"/usr/"*|"/var"|"/var/"*|"/etc"|"/etc/"*|"/home"|"/home/"*|"/opt"|"/opt/"*|"/srv"|"/srv/"*|"/root"|"/root/"*|"/tmp"|"/tmp/"*|"/lib"|"/lib/"*|"/lib64"|"/lib64/"*|"/bin"|"/bin/"*|"/sbin"|"/sbin/"*|"/run"|"/run/"*|"/proc"|"/proc/"*|"/sys"|"/sys/"*|"/dev"|"/dev/"*|"/snap"|"/snap/"*|"[SWAP]")
            return 0
            ;;
    esac

    return 1
}

device_has_system_mountpoints() {
    local device="$1"
    local name=""
    local mountpoint=""

    while IFS=$'\t' read -r name mountpoint; do
        [ -n "$mountpoint" ] || continue
        is_system_mountpoint "$mountpoint" && return 0
    done < <(lsblk -nrpo NAME,MOUNTPOINT "$device" 2>/dev/null | awk 'NF >= 2 { print $1 "\t" $2 }')

    return 1
}

device_mountpoints() {
    local device="$1"

    lsblk -nrpo MOUNTPOINTS "$device" 2>/dev/null | awk 'NF { print; exit }'
}

device_filesystem() {
    local device="$1"

    lsblk -nrpo FSTYPE "$device" 2>/dev/null | awk 'NF { print; exit }'
}

device_uuid() {
    local device="$1"

    blkid -s UUID -o value "$device" 2>/dev/null || true
}

device_partlabel() {
    local device="$1"

    blkid -s PARTLABEL -o value "$device" 2>/dev/null || true
}

device_label() {
    local device="$1"

    blkid -s LABEL -o value "$device" 2>/dev/null || true
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
    local transport=""
    local partitions=""
    local fs_summary=""
    local mounted="no"

    size="$(lsblk -dnro SIZE "$disk" 2>/dev/null | awk 'NR == 1 { print; exit }')"
    model="$(lsblk -dnro MODEL "$disk" 2>/dev/null | awk 'NR == 1 { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print; exit }')"
    transport="$(lsblk -dnro TRAN "$disk" 2>/dev/null | awk 'NR == 1 { print; exit }')"
    partitions="$(disk_partition_count "$disk")"
    fs_summary="$(disk_filesystem_summary "$disk")"

    if disk_has_mounted_children "$disk"; then
        mounted="yes"
    fi

    printf '%s  size=%s  partitions=%s  mounted=%s  fs=%s%s%s' \
        "$disk" \
        "${size:-unknown}" \
        "$partitions" \
        "$mounted" \
        "$fs_summary" \
        "$( [ -n "$transport" ] && printf '  tran=%s' "$transport" )" \
        "$( [ -n "$model" ] && printf '  model=%s' "$model" )"
}

partition_menu_label() {
    local partition="$1"
    local size=""
    local filesystem=""
    local mountpoints=""
    local label=""
    local partlabel=""
    local uuid=""

    size="$(lsblk -nrpo SIZE "$partition" 2>/dev/null | awk 'NR == 1 { print; exit }')"
    filesystem="$(device_filesystem "$partition")"
    mountpoints="$(device_mountpoints "$partition")"
    label="$(device_label "$partition")"
    partlabel="$(device_partlabel "$partition")"
    uuid="$(device_uuid "$partition")"

    printf '%s  size=%s  fs=%s  mount=%s%s%s%s' \
        "$partition" \
        "${size:-unknown}" \
        "${filesystem:-none}" \
        "${mountpoints:--}" \
        "$( [ -n "$label" ] && printf '  label=%s' "$label" )" \
        "$( [ -n "$partlabel" ] && printf '  partlabel=%s' "$partlabel" )" \
        "$( [ -n "$uuid" ] && printf '  uuid=%s' "$uuid" )"
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
        is_root_device "$disk" && continue
        device_has_system_mountpoints "$disk" && continue

        CANDIDATE_DISKS+=("$disk")
        CANDIDATE_LABELS+=("$(disk_label "$disk")")
    done < <(lsblk -dnrpo NAME,TYPE 2>/dev/null | awk '$2 == "disk" { print $1 }')
}

collect_partitions_for_disk() {
    local disk="$1"
    local partition=""

    PARTITION_OPTIONS=()
    PARTITION_LABELS=()

    while IFS= read -r partition; do
        [ -n "$partition" ] || continue
        PARTITION_OPTIONS+=("$partition")
        PARTITION_LABELS+=("$(partition_menu_label "$partition")")
    done < <(lsblk -nrpo NAME,TYPE "$disk" 2>/dev/null | awk '$2 == "part" { print $1 }')
}

choose_disk() {
    local selected=0

    [ "${#CANDIDATE_DISKS[@]}" -gt 0 ] || return 1
    select_menu "$(scriptkit_step_title "选择要处理的数据盘")" CANDIDATE_LABELS selected || return 1
    printf '%s' "${CANDIDATE_DISKS[$selected]}"
}

choose_mode() {
    local selected=0
    local -a options=(
        "挂载已有分区（不格式化）"
        "格式化已有分区并挂载"
        "清空整盘后新建单分区并挂载"
    )

    select_menu "$(scriptkit_step_title "选择处理方式")" options selected || return 1
    case "$selected" in
        0) printf 'reuse' ;;
        1) printf 'format-existing' ;;
        2) printf 'repartition' ;;
        *) return 1 ;;
    esac
}

choose_partition() {
    local title="$1"
    local selected=0

    [ "${#PARTITION_OPTIONS[@]}" -gt 0 ] || return 1
    select_menu "$(scriptkit_step_title "$title")" PARTITION_LABELS selected || return 1
    printf '%s' "${PARTITION_OPTIONS[$selected]}"
}

choose_filesystem() {
    local selected=0
    local -a filesystems=("ext4" "xfs" "btrfs")

    select_menu "$(scriptkit_step_title "选择文件系统")" filesystems selected || return 1
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

filesystem_mount_options() {
    local filesystem="$1"

    case "$filesystem" in
        btrfs) printf 'defaults,compress=zstd' ;;
        xfs|ext4|"") printf 'defaults' ;;
        *) printf 'defaults' ;;
    esac
}

filesystem_fstab_options() {
    local filesystem="$1"

    case "$filesystem" in
        btrfs) printf 'defaults,nofail,compress=zstd' ;;
        xfs|ext4|"") printf 'defaults,nofail' ;;
        *) printf 'defaults,nofail' ;;
    esac
}

filesystem_fsck_pass() {
    local filesystem="$1"

    case "$filesystem" in
        ext2|ext3|ext4) printf '2' ;;
        *) printf '0' ;;
    esac
}

backup_fstab() {
    local backup=""

    backup="$(sk_create_backup /etc/fstab "$SK_SYSTEM_BACKUP_DIR" fstab)" || return 1
    FSTAB_BACKUP="$backup"
    sk_rotate_backups "$SK_SYSTEM_BACKUP_DIR/fstab.bak.*"
}

validate_mount_point() {
    local mount_point="$1"

    if [[ "$mount_point" != /* ]]; then
        msg_err "挂载点必须是绝对路径"
        return 1
    fi

    if [ "$mount_point" = "/" ]; then
        msg_err "不允许将数据盘挂载到根目录"
        return 1
    fi

    if findmnt --target "$mount_point" >/dev/null 2>&1; then
        msg_err "挂载点已被占用: $mount_point"
        return 1
    fi

    if [ -e "$mount_point" ] && [ ! -d "$mount_point" ]; then
        msg_err "挂载点已存在且不是目录: $mount_point"
        return 1
    fi

    return 0
}

ensure_mount_point() {
    local mount_point="$1"

    validate_mount_point "$mount_point" || return 1

    if [ -d "$mount_point" ]; then
        if [ -n "$(find "$mount_point" -mindepth 1 -maxdepth 1 2>/dev/null | awk 'NR == 1 { print; exit }')" ]; then
            if ! yesno_select "挂载点 $mount_point 非空，继续后其现有内容会被挂载遮蔽，是否继续？" "n"; then
                return 1
            fi
        fi
        return 0
    fi

    mkdir -p "$mount_point" || {
        msg_err "无法创建挂载点: $mount_point"
        return 1
    }
    MOUNT_POINT_CREATED=1
    return 0
}

write_fstab_entry() {
    local device="$1"
    local mount_point="$2"
    local filesystem="$3"
    local mount_options="$4"
    local uuid=""
    local tmp_file=""
    local fsck_pass=""

    uuid="$(device_uuid "$device")"
    if [ -z "$uuid" ]; then
        msg_err "无法读取设备 UUID: $device"
        return 1
    fi
    fsck_pass="$(filesystem_fsck_pass "$filesystem")"

    tmp_file="$(mktemp)" || return 1
    awk -v uuid="UUID=$uuid" -v mount_point="$mount_point" '
        $1 != uuid && $2 != mount_point { print }
    ' /etc/fstab > "$tmp_file" || {
        rm -f "$tmp_file"
        return 1
    }

    printf 'UUID=%s %s %s %s 0 %s\n' "$uuid" "$mount_point" "$filesystem" "$mount_options" "$fsck_pass" >> "$tmp_file"

    cp "$tmp_file" /etc/fstab || {
        rm -f "$tmp_file"
        return 1
    }
    rm -f "$tmp_file"

    if ! findmnt --fstab --source "UUID=$uuid" --target "$mount_point" >/dev/null 2>&1; then
        msg_err "/etc/fstab 中未找到新写入的挂载配置"
        return 1
    fi
}

format_partition() {
    local partition="$1"
    local filesystem="$2"

    case "$filesystem" in
        ext4) mkfs.ext4 -F "$partition" >/dev/null 2>&1 ;;
        xfs) mkfs.xfs -f "$partition" >/dev/null 2>&1 ;;
        btrfs) mkfs.btrfs -f "$partition" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

wait_for_partition_device() {
    local partition="$1"
    local attempts=10

    while [ "$attempts" -gt 0 ]; do
        [ -b "$partition" ] && return 0
        sleep 1
        attempts=$((attempts - 1))
    done

    return 1
}

show_disk_layout() {
    local disk="$1"

    printf "\n%b当前磁盘布局:%b\n" "$BOLD" "$PLAIN"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$disk" 2>/dev/null || true
}

show_target_details() {
    local device="$1"

    printf "\n%b目标设备详情:%b\n" "$BOLD" "$PLAIN"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,FSVER,LABEL,PARTLABEL,UUID,MOUNTPOINTS "$device" 2>/dev/null || true
}

confirm_repartition() {
    local disk="$1"
    local partition="$2"
    local filesystem="$3"
    local mount_point="$4"
    local existing_summary="$5"

    printf "\n将执行以下操作:\n"
    printf "  模式: 清空整盘后新建单分区\n"
    printf "  磁盘: %s\n" "$disk"
    printf "  新分区: %s\n" "$partition"
    printf "  文件系统: %s\n" "$filesystem"
    printf "  挂载点: %s\n" "$mount_point"
    printf "  当前检测到的文件系统: %s\n" "$existing_summary"
    printf "  风险: 将重建分区表并清空该磁盘上的现有数据\n"

    yesno_select "确认继续执行破坏性重建并挂载该磁盘？" "n"
}

confirm_partition_mount() {
    local mode="$1"
    local device="$2"
    local filesystem="$3"
    local mount_point="$4"
    local current_fs="$5"
    local mount_options="$6"
    local fstab_options="$7"

    printf "\n将执行以下操作:\n"
    if [ "$mode" = "reuse" ]; then
        printf "  模式: 直接挂载已有设备\n"
    else
        printf "  模式: 格式化已有设备后挂载\n"
    fi
    printf "  设备: %s\n" "$device"
    printf "  当前文件系统: %s\n" "${current_fs:-none}"
    printf "  目标文件系统: %s\n" "$filesystem"
    printf "  挂载点: %s\n" "$mount_point"
    printf "  运行时挂载参数: %s\n" "$mount_options"
    printf "  fstab 持久化参数: %s\n" "$fstab_options"
    if [ "$mode" = "format-existing" ]; then
        printf "  风险: 将清空该设备上的现有数据\n"
        yesno_select "确认继续格式化并挂载该设备？" "n"
        return $?
    fi

    yesno_select "确认继续挂载该设备？" "y"
}

mount_partition_and_persist() {
    local device="$1"
    local mount_point="$2"
    local filesystem="$3"
    local mount_options="$4"
    local fstab_options="$5"

    TARGET_MOUNT_POINT="$mount_point"

    ensure_mount_point "$mount_point" || return 1

    msg_info "正在挂载设备..."
    mount -o "$mount_options" "$device" "$mount_point" || {
        msg_err "挂载失败: $device -> $mount_point"
        return 1
    }
    MOUNTED_BY_SCRIPT=1

    write_fstab_entry "$device" "$mount_point" "$filesystem" "$fstab_options" || {
        msg_err "写入 /etc/fstab 失败"
        return 1
    }

    if findmnt --target "$mount_point" >/dev/null 2>&1; then
        msg_ok "设备已挂载到: $mount_point"
        printf "设备: %s\n" "$device"
        printf "文件系统: %s\n" "$filesystem"
        printf "运行时挂载参数: %s\n" "$mount_options"
        printf "fstab 持久化参数: %s\n" "$fstab_options"
        return 0
    fi

    msg_err "挂载验证失败"
    return 1
}

prepare_partition_mount() {
    local disk="$1"
    local mode="$2"
    local device=""
    local filesystem=""
    local mount_point=""
    local current_fs=""
    local mount_options=""
    local fstab_options=""

    collect_partitions_for_disk "$disk"
    if [ "${#PARTITION_OPTIONS[@]}" -eq 0 ]; then
        if [ -n "$(device_mountpoints "$disk")" ]; then
            msg_err "该磁盘当前已挂载，不能直接作为目标设备处理: $disk"
            return 1
        fi

        if [ "$mode" = "reuse" ] && [ -z "$(device_filesystem "$disk")" ]; then
            msg_err "该磁盘没有分区，也没有可识别的整盘文件系统"
            return 1
        fi

        PARTITION_OPTIONS=("$disk")
        PARTITION_LABELS=("$(partition_menu_label "$disk")  no-partition-table")
        msg_warn "该磁盘没有分区表，将直接处理整盘设备。"
    fi

    device="$(choose_partition "选择目标设备")" || return 1
    show_target_details "$device"

    current_fs="$(device_filesystem "$device")"
    if [ -n "$(device_mountpoints "$device")" ]; then
        msg_err "该设备当前已挂载，不能重复处理: $device"
        return 1
    fi

    if [ "$mode" = "reuse" ]; then
        if [ -z "$current_fs" ]; then
            msg_err "所选设备没有可识别的文件系统，不能直接挂载"
            return 1
        fi
        filesystem="$current_fs"
    else
        filesystem="$(choose_filesystem)" || return 1
        ensure_filesystem_tool "$filesystem" || return 1
    fi

    printf '\n%b' "$(msg_prompt "输入" "挂载点（默认 /mnt/$(basename "$device")）: ")"
    read -r mount_point
    mount_point="${mount_point:-/mnt/$(basename "$device")}"

    mount_options="$(filesystem_mount_options "$filesystem")"
    fstab_options="$(filesystem_fstab_options "$filesystem")"
    confirm_partition_mount "$mode" "$device" "$filesystem" "$mount_point" "$current_fs" "$mount_options" "$fstab_options" || return 1

    backup_fstab || return 1

    if [ "$mode" = "format-existing" ]; then
        msg_info "正在格式化设备: $device ($filesystem)"
        format_partition "$device" "$filesystem" || {
            msg_err "格式化失败: $device"
            return 1
        }
    fi

    mount_partition_and_persist "$device" "$mount_point" "$filesystem" "$mount_options" "$fstab_options"
}

prepare_repartition_mount() {
    local disk="$1"
    local filesystem=""
    local mount_point=""
    local partition=""
    local existing_summary=""
    local mount_options=""
    local fstab_options=""

    if disk_has_mounted_children "$disk"; then
        msg_err "该磁盘存在已挂载分区，不能直接整盘重建: $disk"
        return 1
    fi

    filesystem="$(choose_filesystem)" || return 1
    ensure_filesystem_tool "$filesystem" || return 1

    printf '\n%b' "$(msg_prompt "输入" "挂载点（默认 /mnt/$(basename "$disk")）: ")"
    read -r mount_point
    mount_point="${mount_point:-/mnt/$(basename "$disk")}"

    partition="$(partition_path "$disk")"
    existing_summary="$(disk_filesystem_summary "$disk")"
    mount_options="$(filesystem_mount_options "$filesystem")"
    fstab_options="$(filesystem_fstab_options "$filesystem")"

    confirm_repartition "$disk" "$partition" "$filesystem" "$mount_point" "$existing_summary" || return 1

    backup_fstab || return 1

    msg_info "正在重建分区表..."
    parted -s "$disk" mklabel gpt || {
        msg_err "创建 GPT 分区表失败: $disk"
        return 1
    }
    parted -s "$disk" mkpart primary "$filesystem" 0% 100% || {
        msg_err "创建分区失败: $disk"
        return 1
    }
    partprobe "$disk" >/dev/null 2>&1 || true
    if command_exists udevadm; then
        udevadm settle >/dev/null 2>&1 || true
    fi

    if ! wait_for_partition_device "$partition"; then
        msg_err "新分区未出现: $partition"
        return 1
    fi

    msg_info "正在格式化设备: $partition ($filesystem)"
    format_partition "$partition" "$filesystem" || {
        msg_err "格式化失败: $partition"
        return 1
    }

    mount_partition_and_persist "$partition" "$mount_point" "$filesystem" "$mount_options" "$fstab_options"
}

do_mount_data_disk() {
    local disk=""
    local mode=""
    local rc=0

    reset_mount_state

    collect_candidate_disks
    if [ "${#CANDIDATE_DISKS[@]}" -eq 0 ]; then
        msg_err "未找到可处理的数据盘。系统盘已自动排除。"
        return 1
    fi

    msg_info "脚本会自动排除系统盘，并提供已有分区复用或整盘重建两类挂载路径。"
    disk="$(choose_disk)" || return 0
    show_disk_layout "$disk"

    mode="$(choose_mode)" || return 0
    case "$mode" in
        reuse|format-existing)
            prepare_partition_mount "$disk" "$mode" || rc=1
            ;;
        repartition)
            prepare_repartition_mount "$disk" || rc=1
            ;;
        *)
            msg_err "未知处理模式: $mode"
            rc=1
            ;;
    esac

    if [ "$rc" -ne 0 ]; then
        rollback_mount_state
    else
        reset_mount_state
    fi
    return "$rc"
}

# --- 卸载设备 / 清理 fstab ---

# 收集所有非系统盘的已挂载块设备。
collect_mounted_devices() {
    local name=""
    local mountpoint=""
    local fstype=""

    MOUNTED_DEVICES=()
    MOUNTED_DEVICE_LABELS=()

    while IFS=$'\t' read -r name mountpoint fstype; do
        [ -n "$name" ] || continue
        [ -n "$mountpoint" ] || continue

        is_system_mountpoint "$mountpoint" && continue
        is_root_device "$name" && continue
        is_partition_of_root_disk "$name" && continue

        MOUNTED_DEVICES+=("$name")
        MOUNTED_DEVICE_LABELS+=("$name  mount=$mountpoint  fs=${fstype:-unknown}")
    done < <(lsblk -nrpo NAME,MOUNTPOINT,FSTYPE 2>/dev/null | awk -F' ' 'NF >= 2 { print $1 "\t" $2 "\t" $3 }')
}

# 判断设备是否为根磁盘上的分区（保护系统盘的所有子设备）。
is_partition_of_root_disk() {
    local device="$1"
    local root_disk=""
    local parent=""

    root_disk="$(root_disk_path 2>/dev/null || true)"
    [ -n "$root_disk" ] || return 1

    parent="$(lsblk -ndo PKNAME "$device" 2>/dev/null | awk 'NF { print $1; exit }')"
    [ -n "$parent" ] || return 1
    [ "/dev/$parent" = "$root_disk" ]
}

# 解析 fstab 设备规格（UUID=/LABEL=/PARTUUID=/路径）到真实设备路径，解析不出则返回非 0。
resolve_fstab_spec() {
    local spec="$1"

    case "$spec" in
        UUID=*|LABEL=*|PARTUUID=*|PARTLABEL=*)
            if command_exists findfs; then
                findfs "$spec" 2>/dev/null
                return $?
            fi
            return 2
            ;;
        /dev/*)
            [ -b "$spec" ] && { printf '%s' "$spec"; return 0; }
            return 1
            ;;
        *)
            return 2
            ;;
    esac
}

# 收集 fstab 中指向块设备且设备已不存在的失效条目。
collect_stale_fstab_entries() {
    local line=""
    local spec=""
    local mount_point=""
    local fstype=""

    FSTAB_ENTRY_LINES=()
    FSTAB_ENTRY_LABELS=()

    while IFS= read -r line; do
        case "$line" in
            ''|'#'*) continue ;;
        esac

        spec="$(printf '%s' "$line" | awk '{print $1}')"
        mount_point="$(printf '%s' "$line" | awk '{print $2}')"
        fstype="$(printf '%s' "$line" | awk '{print $3}')"

        case "$spec" in
            UUID=*|LABEL=*|PARTUUID=*|PARTLABEL=*|/dev/*) ;;
            *) continue ;;
        esac

        is_system_mountpoint "$mount_point" && continue

        # 只对能确定"设备不存在"的条目判失效；解析工具缺失（返回 2）时保守跳过。
        resolve_fstab_spec "$spec" >/dev/null 2>&1
        [ "$?" -eq 1 ] || continue

        FSTAB_ENTRY_LINES+=("$line")
        FSTAB_ENTRY_LABELS+=("$spec  ->  ${mount_point:-?}  (${fstype:-?})  [设备不存在]")
    done < /etc/fstab
}

# 收集 fstab 中所有指向块设备的条目（用于手动选择移除），排除根/boot 等系统挂载点。
collect_blockdev_fstab_entries() {
    local line=""
    local spec=""
    local mount_point=""
    local fstype=""

    FSTAB_ENTRY_LINES=()
    FSTAB_ENTRY_LABELS=()

    while IFS= read -r line; do
        case "$line" in
            ''|'#'*) continue ;;
        esac

        spec="$(printf '%s' "$line" | awk '{print $1}')"
        mount_point="$(printf '%s' "$line" | awk '{print $2}')"
        fstype="$(printf '%s' "$line" | awk '{print $3}')"

        case "$spec" in
            UUID=*|LABEL=*|PARTUUID=*|PARTLABEL=*|/dev/*) ;;
            *) continue ;;
        esac

        is_system_mountpoint "$mount_point" && continue

        FSTAB_ENTRY_LINES+=("$line")
        FSTAB_ENTRY_LABELS+=("$spec  ->  ${mount_point:-?}  (${fstype:-?})")
    done < /etc/fstab
}

# 从 /etc/fstab 中删除给定的整行（精确匹配），删除前会备份。
remove_fstab_lines() {
    local -n _targets=$1
    local tmp_targets=""
    local tmp_out=""
    local target=""

    [ "${#_targets[@]}" -gt 0 ] || return 0

    backup_fstab || return 1

    tmp_targets="$(mktemp)" || return 1
    tmp_out="$(mktemp)" || { rm -f "$tmp_targets"; return 1; }

    for target in "${_targets[@]}"; do
        printf '%s\n' "$target" >> "$tmp_targets"
    done

    # FNR==NR 先把待删行读入集合，再逐行输出非目标行。
    awk 'FNR==NR { drop[$0]=1; next } !($0 in drop)' "$tmp_targets" /etc/fstab > "$tmp_out" || {
        rm -f "$tmp_targets" "$tmp_out"
        return 1
    }

    cp "$tmp_out" /etc/fstab || {
        rm -f "$tmp_targets" "$tmp_out"
        return 1
    }
    rm -f "$tmp_targets" "$tmp_out"
    return 0
}

do_unmount_or_clean() {
    local -a actions=(
        "卸载已挂载的数据设备"
        "清理失效的 fstab 条目（设备已不存在）"
        "手动选择移除 fstab 条目"
    )
    local selected=0

    if ! select_menu "$(scriptkit_step_title "卸载 / 清理 fstab")" actions selected; then
        return 0
    fi

    case "$selected" in
        0) unmount_device_flow ;;
        1) clean_stale_fstab_flow ;;
        2) manual_remove_fstab_flow ;;
        *) msg_warn "无效选择" ;;
    esac
}

unmount_device_flow() {
    local device=""
    local mount_point=""
    local selected_idx=0

    collect_mounted_devices
    if [ "${#MOUNTED_DEVICES[@]}" -eq 0 ]; then
        msg_warn "未找到可卸载的非系统已挂载设备。"
        return 0
    fi

    if ! select_menu "$(scriptkit_step_title "选择要卸载的设备")" MOUNTED_DEVICE_LABELS selected_idx; then
        return 0
    fi
    device="${MOUNTED_DEVICES[$selected_idx]}"
    mount_point="$(findmnt -n -o TARGET --source "$device" 2>/dev/null | awk 'NR==1{print;exit}')"

    show_target_details "$device"
    if ! yesno_select "确认卸载设备 $device（挂载点 ${mount_point:-未知}）？" "n"; then
        msg_info "已取消"
        return 0
    fi

    if ! umount "$device" >/dev/null 2>&1; then
        msg_err "卸载失败，设备可能正被占用: $device"
        msg_info "可用 'lsof $mount_point' 或 'fuser -m $mount_point' 排查占用进程。"
        return 1
    fi
    msg_ok "已卸载: $device"

    if [ -n "$mount_point" ] && grep -qE "(^|[[:space:]])${mount_point}([[:space:]]|$)" /etc/fstab 2>/dev/null; then
        if yesno_select "是否同时从 /etc/fstab 移除该挂载点的条目？" "n"; then
            remove_fstab_by_mountpoint "$mount_point" && msg_ok "已从 fstab 移除 $mount_point 的条目" \
                || msg_err "移除 fstab 条目失败"
        fi
    fi
}

# 按挂载点（第二列）从 fstab 移除条目。
remove_fstab_by_mountpoint() {
    local mount_point="$1"
    local -a targets=()
    local line=""

    if is_system_mountpoint "$mount_point"; then
        msg_err "拒绝移除系统挂载点的 fstab 条目: $mount_point"
        return 1
    fi

    while IFS= read -r line; do
        case "$line" in
            ''|'#'*) continue ;;
        esac
        if [ "$(printf '%s' "$line" | awk '{print $2}')" = "$mount_point" ]; then
            targets+=("$line")
        fi
    done < /etc/fstab

    remove_fstab_lines targets
}

clean_stale_fstab_flow() {
    local -a chosen=()
    local -a flags=()
    local i=0

    collect_stale_fstab_entries
    if [ "${#FSTAB_ENTRY_LINES[@]}" -eq 0 ]; then
        msg_ok "未发现失效的 fstab 条目。"
        return 0
    fi

    for ((i = 0; i < ${#FSTAB_ENTRY_LINES[@]}; i++)); do
        flags+=("1")
    done

    multiselect_menu "$(scriptkit_step_title "选择要删除的失效条目")" FSTAB_ENTRY_LABELS flags
    for ((i = 0; i < ${#FSTAB_ENTRY_LINES[@]}; i++)); do
        [ "${flags[$i]}" = "1" ] && chosen+=("${FSTAB_ENTRY_LINES[$i]}")
    done

    if [ "${#chosen[@]}" -eq 0 ]; then
        msg_info "未选择任何条目，已取消。"
        return 0
    fi

    printf "\n将从 /etc/fstab 删除以下条目:\n"
    for i in "${chosen[@]}"; do
        printf "  %s\n" "$i"
    done
    if ! yesno_select "确认删除这些 fstab 条目？" "n"; then
        msg_info "已取消"
        return 0
    fi

    remove_fstab_lines chosen && msg_ok "已删除 ${#chosen[@]} 条失效 fstab 条目" \
        || msg_err "删除 fstab 条目失败"
}

manual_remove_fstab_flow() {
    local -a chosen=()
    local -a flags=()
    local i=0

    collect_blockdev_fstab_entries
    if [ "${#FSTAB_ENTRY_LINES[@]}" -eq 0 ]; then
        msg_warn "未发现可移除的块设备 fstab 条目（系统挂载点已排除）。"
        return 0
    fi

    for ((i = 0; i < ${#FSTAB_ENTRY_LINES[@]}; i++)); do
        flags+=("0")
    done

    multiselect_menu "$(scriptkit_step_title "勾选要移除的 fstab 条目")" FSTAB_ENTRY_LABELS flags
    for ((i = 0; i < ${#FSTAB_ENTRY_LINES[@]}; i++)); do
        [ "${flags[$i]}" = "1" ] && chosen+=("${FSTAB_ENTRY_LINES[$i]}")
    done

    if [ "${#chosen[@]}" -eq 0 ]; then
        msg_info "未选择任何条目，已取消。"
        return 0
    fi

    printf "\n将从 /etc/fstab 移除以下条目:\n"
    for i in "${chosen[@]}"; do
        printf "  %s\n" "$i"
    done
    msg_warn "移除后这些挂载点开机将不再自动挂载，请确认不影响系统。"
    if ! yesno_select "确认移除这些 fstab 条目？" "n"; then
        msg_info "已取消"
        return 0
    fi

    remove_fstab_lines chosen && msg_ok "已移除 ${#chosen[@]} 条 fstab 条目" \
        || msg_err "移除 fstab 条目失败"
}

# --- 分区管理 ---

# 选择一块非系统盘（复用候选盘收集逻辑）。
choose_data_disk_for_partition() {
    collect_candidate_disks
    if [ "${#CANDIDATE_DISKS[@]}" -eq 0 ]; then
        msg_err "未找到可操作的数据盘。系统盘已自动排除。" >&2
        return 1
    fi
    choose_disk
}

# 打印某磁盘的分区表（parted print + lsblk 树）。
show_partition_table() {
    local disk="$1"

    printf "\n%bparted 分区表:%b\n" "$BOLD" "$PLAIN"
    parted -s "$disk" unit GiB print 2>/dev/null || msg_warn "无法读取分区表（磁盘可能尚无分区表）。"
    show_disk_layout "$disk"
}

# 收集磁盘上的分区编号与标签，供删除时按编号选择。
collect_partitions_for_disk_with_num() {
    local disk="$1"
    local partition=""

    PARTITION_OPTIONS=()
    PARTITION_LABELS=()

    while IFS= read -r partition; do
        [ -n "$partition" ] || continue
        PARTITION_OPTIONS+=("$partition")
        PARTITION_LABELS+=("$(partition_menu_label "$partition")")
    done < <(lsblk -nrpo NAME,TYPE "$disk" 2>/dev/null | awk '$2 == "part" { print $1 }')
}

# 从分区设备路径提取分区号（用于 parted rm）。
partition_number_of() {
    local partition="$1"

    printf '%s' "$partition" | grep -oE '[0-9]+$'
}

create_partition_flow() {
    local disk="$1"
    local has_table=""
    local start=""
    local end=""
    local fs_hint=""
    local part_type=""

    show_partition_table "$disk"

    has_table="$(parted -s "$disk" print 2>/dev/null | awk '/Partition Table:/ { print $3 }')"
    if [ -z "$has_table" ] || [ "$has_table" = "unknown" ]; then
        msg_warn "该磁盘没有分区表。"
        if ! yesno_select "是否新建 GPT 分区表？这会清空磁盘 $disk 上的全部数据！" "n"; then
            msg_info "已取消"
            return 0
        fi
        if disk_has_mounted_children "$disk"; then
            msg_err "该磁盘存在已挂载分区，不能重建分区表: $disk"
            return 1
        fi
        backup_fstab || return 1
        parted -s "$disk" mklabel gpt || {
            msg_err "创建 GPT 分区表失败: $disk"
            return 1
        }
        msg_ok "已创建 GPT 分区表"
    fi

    printf "\n可用空间参考:\n"
    parted -s "$disk" unit GiB print free 2>/dev/null || true

    printf '\n%b' "$(msg_prompt "输入" "起始位置（如 0% 或 10GiB，默认 0%）: ")"
    read -r start
    start="${start:-0%}"
    printf '%b' "$(msg_prompt "输入" "结束位置（如 100% 或 50GiB，默认 100%）: ")"
    read -r end
    end="${end:-100%}"

    fs_hint="$(choose_filesystem)" || return 0
    part_type="primary"

    printf "\n将在 %s 上新建分区: 起始=%s 结束=%s 类型提示=%s\n" "$disk" "$start" "$end" "$fs_hint"
    if ! yesno_select "确认新建该分区？（仅创建分区，不格式化）" "n"; then
        msg_info "已取消"
        return 0
    fi

    if ! parted -s "$disk" mkpart "$part_type" "$fs_hint" "$start" "$end"; then
        msg_err "创建分区失败: $disk"
        return 1
    fi
    partprobe "$disk" >/dev/null 2>&1 || true
    if command_exists udevadm; then
        udevadm settle >/dev/null 2>&1 || true
    fi
    msg_ok "分区已创建。可在「格式化 / fsck / 扩容」中格式化后使用。"
    show_partition_table "$disk"
}

delete_partition_flow() {
    local disk="$1"
    local partition=""
    local part_num=""
    local mountpoints=""
    local selected_idx=0

    collect_partitions_for_disk_with_num "$disk"
    if [ "${#PARTITION_OPTIONS[@]}" -eq 0 ]; then
        msg_warn "该磁盘没有可删除的分区。"
        return 0
    fi

    if ! select_menu "$(scriptkit_step_title "选择要删除的分区")" PARTITION_LABELS selected_idx; then
        return 0
    fi
    partition="${PARTITION_OPTIONS[$selected_idx]}"

    mountpoints="$(device_mountpoints "$partition")"
    if [ -n "$mountpoints" ]; then
        msg_err "该分区已挂载（$mountpoints），请先卸载再删除: $partition"
        return 1
    fi

    part_num="$(partition_number_of "$partition")"
    if [ -z "$part_num" ]; then
        msg_err "无法解析分区号: $partition"
        return 1
    fi

    show_target_details "$partition"
    msg_warn "删除分区将清空该分区上的全部数据，且不可恢复！"
    if ! yesno_select "确认删除分区 $partition（编号 $part_num）？" "n"; then
        msg_info "已取消"
        return 0
    fi

    if ! parted -s "$disk" rm "$part_num"; then
        msg_err "删除分区失败: $partition"
        return 1
    fi
    partprobe "$disk" >/dev/null 2>&1 || true
    if command_exists udevadm; then
        udevadm settle >/dev/null 2>&1 || true
    fi
    msg_ok "已删除分区: $partition"
    show_partition_table "$disk"
}

do_partition_manage() {
    local disk=""
    local -a actions=(
        "查看分区表"
        "新建分区"
        "删除分区"
    )
    local selected=0

    disk="$(choose_data_disk_for_partition)" || return 0

    if ! select_menu "$(scriptkit_step_title "分区管理 - $disk")" actions selected; then
        return 0
    fi

    case "$selected" in
        0) show_partition_table "$disk" ;;
        1) create_partition_flow "$disk" ;;
        2) delete_partition_flow "$disk" ;;
        *) msg_warn "无效选择" ;;
    esac
}

# --- 格式化 / fsck / 扩容 ---

# 选择目标设备：先选盘，再选其分区；无分区时回退到整盘设备。
choose_target_device() {
    local disk=""
    local device=""

    disk="$(choose_data_disk_for_partition)" || return 1

    collect_partitions_for_disk "$disk"
    if [ "${#PARTITION_OPTIONS[@]}" -eq 0 ]; then
        PARTITION_OPTIONS=("$disk")
        PARTITION_LABELS=("$(partition_menu_label "$disk")  no-partition-table")
    fi

    choose_partition "选择目标设备"
}

# 按需安装 fsck 工具。
ensure_fsck_tool() {
    local filesystem="$1"

    case "$filesystem" in
        ext2|ext3|ext4) ensure_commands "e2fsck:e2fsprogs" ;;
        xfs) ensure_commands "xfs_repair:xfsprogs" ;;
        btrfs) ensure_commands "btrfs:btrfs-progs" ;;
        vfat|fat) ensure_commands "fsck.vfat:dosfstools" ;;
        *)
            msg_err "不支持对该文件系统执行检查: ${filesystem:-未知}"
            return 1
            ;;
    esac
}

# 按需安装扩容工具。
ensure_resize_tool() {
    local filesystem="$1"

    case "$filesystem" in
        ext2|ext3|ext4) ensure_commands "resize2fs:e2fsprogs" ;;
        xfs) ensure_commands "xfs_growfs:xfsprogs" ;;
        btrfs) ensure_commands "btrfs:btrfs-progs" ;;
        *)
            msg_err "不支持对该文件系统扩容: ${filesystem:-未知}"
            return 1
            ;;
    esac
}

format_device_flow() {
    local device="$1"
    local filesystem=""
    local current_fs=""

    if [ -n "$(device_mountpoints "$device")" ]; then
        msg_err "该设备已挂载，请先卸载再格式化: $device"
        return 1
    fi

    current_fs="$(device_filesystem "$device")"
    filesystem="$(choose_filesystem)" || return 0
    ensure_filesystem_tool "$filesystem" || return 1

    show_target_details "$device"
    msg_warn "格式化将清空该设备上的全部数据！当前文件系统: ${current_fs:-none}"
    if ! yesno_select "确认格式化 $device 为 $filesystem？" "n"; then
        msg_info "已取消"
        return 0
    fi

    msg_info "正在格式化: $device ($filesystem)"
    if ! format_partition "$device" "$filesystem"; then
        msg_err "格式化失败: $device"
        return 1
    fi
    msg_ok "已格式化: $device ($filesystem)"
    show_target_details "$device"
}

fsck_device_flow() {
    local device="$1"
    local filesystem=""
    local rc=0

    filesystem="$(device_filesystem "$device")"
    if [ -z "$filesystem" ]; then
        msg_err "无法识别文件系统，无法检查: $device"
        return 1
    fi

    if [ -n "$(device_mountpoints "$device")" ]; then
        msg_err "该设备已挂载，请先卸载再检查: $device"
        return 1
    fi

    ensure_fsck_tool "$filesystem" || return 1

    show_target_details "$device"
    if ! yesno_select "确认对 $device（$filesystem）执行检查/修复？" "n"; then
        msg_info "已取消"
        return 0
    fi

    msg_info "正在检查文件系统: $device ($filesystem)"
    case "$filesystem" in
        ext2|ext3|ext4)
            e2fsck -f -y "$device"
            rc=$?
            ;;
        xfs)
            xfs_repair "$device"
            rc=$?
            ;;
        btrfs)
            # btrfs check 默认只读；--repair 风险高，仅在用户明确选择时使用。
            if yesno_select "btrfs：是否执行 --repair 修复（风险较高，否则只读检查）？" "n"; then
                btrfs check --repair "$device"
            else
                btrfs check "$device"
            fi
            rc=$?
            ;;
        vfat|fat)
            fsck.vfat -y "$device"
            rc=$?
            ;;
        *)
            msg_err "不支持对该文件系统检查: $filesystem"
            return 1
            ;;
    esac

    # e2fsck/fsck 退出码 0/1 表示无错或已修复；其余视为有遗留问题。
    if [ "$rc" -le 1 ]; then
        msg_ok "文件系统检查完成: $device（退出码 $rc）"
        return 0
    fi
    msg_warn "文件系统检查返回退出码 $rc，可能仍有未修复问题，请人工复核。"
    return 1
}

resize_device_flow() {
    local device="$1"
    local filesystem=""
    local mount_point=""

    filesystem="$(device_filesystem "$device")"
    if [ -z "$filesystem" ]; then
        msg_err "无法识别文件系统，无法扩容: $device"
        return 1
    fi

    ensure_resize_tool "$filesystem" || return 1
    mount_point="$(findmnt -n -o TARGET --source "$device" 2>/dev/null | awk 'NR==1{print;exit}')"

    show_target_details "$device"
    msg_info "扩容会把文件系统扩展到所在分区/设备的当前最大尺寸（需已先扩大底层分区）。"

    case "$filesystem" in
        ext2|ext3|ext4)
            if ! yesno_select "确认对 $device（$filesystem）执行扩容（resize2fs）？" "n"; then
                msg_info "已取消"
                return 0
            fi
            if resize2fs "$device"; then
                msg_ok "ext 文件系统已扩容: $device"
                return 0
            fi
            msg_err "扩容失败: $device"
            return 1
            ;;
        xfs)
            if [ -z "$mount_point" ]; then
                msg_err "xfs 扩容要求文件系统处于挂载状态，请先挂载后再操作: $device"
                return 1
            fi
            if ! yesno_select "确认对挂载点 $mount_point（xfs）执行扩容（xfs_growfs）？" "n"; then
                msg_info "已取消"
                return 0
            fi
            if xfs_growfs "$mount_point"; then
                msg_ok "xfs 文件系统已扩容: $mount_point"
                return 0
            fi
            msg_err "扩容失败: $mount_point"
            return 1
            ;;
        btrfs)
            if [ -z "$mount_point" ]; then
                msg_err "btrfs 扩容要求文件系统处于挂载状态，请先挂载后再操作: $device"
                return 1
            fi
            if ! yesno_select "确认对挂载点 $mount_point（btrfs）执行扩容（resize max）？" "n"; then
                msg_info "已取消"
                return 0
            fi
            if btrfs filesystem resize max "$mount_point"; then
                msg_ok "btrfs 文件系统已扩容: $mount_point"
                return 0
            fi
            msg_err "扩容失败: $mount_point"
            return 1
            ;;
        *)
            msg_err "不支持对该文件系统扩容: $filesystem"
            return 1
            ;;
    esac
}

do_format_fsck_resize() {
    local device=""
    local -a actions=(
        "格式化设备"
        "检查 / 修复文件系统（fsck）"
        "扩容文件系统（resize）"
    )
    local selected=0

    device="$(choose_target_device)" || return 0

    if ! select_menu "$(scriptkit_step_title "格式化 / fsck / 扩容 - $device")" actions selected; then
        return 0
    fi

    case "$selected" in
        0) format_device_flow "$device" ;;
        1) fsck_device_flow "$device" ;;
        2) resize_device_flow "$device" ;;
        *) msg_warn "无效选择" ;;
    esac
}

main() {
    local -a menu_labels=(
        "挂载数据盘（复用 / 格式化 / 整盘重建）"
        "卸载设备 / 清理 fstab"
        "分区管理（查看 / 新建 / 删除）"
        "格式化 / fsck 检查 / 扩容文件系统"
    )
    local selected=0

    check_root
    ensure_commands lsblk blkid findmnt mount umount awk mkdir mktemp parted "partprobe:parted" cp find "findfs:util-linux" || exit 1

    while true; do
        draw_current_title "磁盘管理"
        selected=0
        if ! select_menu "$(scriptkit_step_title "选择操作")" menu_labels selected; then
            return 0
        fi

        case "$selected" in
            0) do_mount_data_disk || true ;;
            1) do_unmount_or_clean || true ;;
            2) do_partition_manage || true ;;
            3) do_format_fsck_resize || true ;;
            *) msg_warn "无效选择" ;;
        esac

        reset_mount_state

        printf '\n%b' "$(msg_prompt "提示" "按 Enter 继续...")"
        read -r _
        clear 2>/dev/null || true
    done
}

main
