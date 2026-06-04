#!/usr/bin/env bash
set -u

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

SCRIPTKIT_ECS_REMOTE_BASE="${SCRIPTKIT_ECS_REMOTE_BASE:-https://raw.githubusercontent.com/spiritLHLS/ecs/main}"

ecs_repo_root() {
    cd -- "${SCRIPT_SELF_DIR}/../.." >/dev/null 2>&1 && pwd
}

ecs_workdir() {
    printf '%s' "${SCRIPTKIT_ECS_WORKDIR:-${HOME:-/root}/.scriptkit/ecs}"
}

ecs_sync_file() {
    local source_file="$1"
    local target_file="$2"

    [ -f "$source_file" ] || return 0
    cp -p "$source_file" "$target_file" || return 1
}

ecs_download_file() {
    local file_name="$1"
    local target_file="$2"

    if [ -f "$target_file" ]; then
        return 0
    fi

    msg_info "正在下载 ECS 资源: $file_name"
    download_file "${SCRIPTKIT_ECS_REMOTE_BASE%/}/$file_name" "$target_file" || return 1
}

ecs_patch_workdir_support() {
    local target_file="$1"
    local tmp_file="${target_file}.tmp"

    if grep -q '^SCRIPTKIT_ECS_WORKDIR=' "$target_file" 2>/dev/null; then
        return 0
    fi

    awk '
        !patched && $0 == "cd /root >/dev/null 2>&1" {
            print "SCRIPTKIT_ECS_WORKDIR=\"${SCRIPTKIT_ECS_WORKDIR:-/root}\""
            print "mkdir -p \"$SCRIPTKIT_ECS_WORKDIR\" >/dev/null 2>&1 || true"
            print "cd \"$SCRIPTKIT_ECS_WORKDIR\" >/dev/null 2>&1 || cd /root >/dev/null 2>&1 || true"
            patched = 1
            next
        }
        { print }
    ' "$target_file" > "$tmp_file" || return 1

    mv "$tmp_file" "$target_file" || return 1
}

ecs_prepare_workspace() {
    local source_dir="$(ecs_repo_root)/ecs"
    local workdir="$(ecs_workdir)"

    mkdir -p "$workdir" || return 1

    if [ -d "$source_dir" ]; then
        ecs_sync_file "$source_dir/ecs.sh" "$workdir/ecs.sh" || return 1
        ecs_sync_file "$source_dir/ipcheck.sh" "$workdir/ipcheck.sh" || return 1
        ecs_sync_file "$source_dir/customizeqzcheck.sh" "$workdir/customizeqzcheck.sh" || return 1
    else
        ecs_download_file "ecs.sh" "$workdir/ecs.sh" || return 1
        ecs_download_file "ipcheck.sh" "$workdir/ipcheck.sh" || return 1
        ecs_download_file "customizeqzcheck.sh" "$workdir/customizeqzcheck.sh" || return 1
    fi

    if [ ! -f "$workdir/ecs.sh" ] && [ ! -f "$workdir/ipcheck.sh" ] && [ ! -f "$workdir/customizeqzcheck.sh" ]; then
        msg_err "找不到 ECS 资源目录: $source_dir"
        return 1
    fi

    ecs_patch_workdir_support "$workdir/ecs.sh" || return 1
    ecs_patch_workdir_support "$workdir/ipcheck.sh" || return 1
}

main() {
    local mode="${SCRIPTKIT_ECS_MODE:-interactive}"
    local workdir="$(ecs_workdir)"
    local script_file=""
    local -a script_args=()

    ecs_prepare_workspace || return 1

    case "$mode" in
        interactive)
            script_file="$workdir/ecs.sh"
            ;;
        full)
            script_file="$workdir/ecs.sh"
            script_args=(-m 1)
            ;;
        base)
            script_file="$workdir/ecs.sh"
            script_args=(-base)
            ;;
        custom)
            script_file="$workdir/ecs.sh"
            if [ -n "${SCRIPTKIT_ECS_ARGS:-}" ]; then
                read -r -a script_args <<< "${SCRIPTKIT_ECS_ARGS}"
            fi
            ;;
        ipcheck)
            script_file="$workdir/ipcheck.sh"
            ;;
        custom_ipcheck)
            script_file="$workdir/customizeqzcheck.sh"
            ;;
        *)
            msg_err "未知 ECS 模式: $mode"
            return 1
            ;;
    esac

    if [ ! -f "$script_file" ]; then
        msg_err "脚本不存在: $script_file"
        return 1
    fi

    msg_info "ECS 工作目录: $workdir"
    export SCRIPTKIT_ECS_WORKDIR="$workdir"
    (
        cd "$workdir" || exit 1
        bash "$script_file" "${script_args[@]}"
    )
}

main "$@"
