#!/usr/bin/env bash
set -u

# Run LinuxMirrors official mirror-changing script through selectable URLs.

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

LINUXMIRRORS_LABELS=(
    "Official"
    "GitHub raw"
    "Gitee raw（国内推荐）"
    "GitCode raw（可能延迟）"
    "jsDelivr CDN"
    "EdgeOne"
)

LINUXMIRRORS_URLS=(
    "https://linuxmirrors.cn/main.sh"
    "https://raw.githubusercontent.com/SuperManito/LinuxMirrors/main/ChangeMirrors.sh"
    "https://gitee.com/SuperManito/LinuxMirrors/raw/main/ChangeMirrors.sh"
    "https://raw.gitcode.com/SuperManito/LinuxMirrors/raw/main/ChangeMirrors.sh"
    "https://cdn.jsdelivr.net/gh/SuperManito/LinuxMirrors@main/ChangeMirrors.sh"
    "https://edgeone.linuxmirrors.cn/main.sh"
)

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

download_file() {
    local url="$1"
    local output="$2"

    if command_exists curl; then
        curl -fsSL "$url" -o "$output"
    elif command_exists wget; then
        wget -qO "$output" "$url"
    else
        msg_err "需要 curl 或 wget 下载 LinuxMirrors 脚本"
        return 1
    fi
}

select_source_url() {
    local selected=2
    local i
    local -a menu_labels=()

    for ((i = 0; i < ${#LINUXMIRRORS_LABELS[@]}; i++)); do
        menu_labels+=("${LINUXMIRRORS_LABELS[$i]}  ${LINUXMIRRORS_URLS[$i]}")
    done

    if ! select_menu "LinuxMirrors 换源" menu_labels selected 2; then
        return 1
    fi

    printf '%s' "${LINUXMIRRORS_URLS[$selected]}"
}

run_linuxmirrors() {
    local url="$1"
    local tmp_dir="${TMPDIR:-/tmp}"
    local tmp_file=""
    local status=0

    [ -d "$tmp_dir" ] || tmp_dir="."
    tmp_file="${tmp_dir%/}/scriptkit-linuxmirrors.$$"

    printf "\n将下载并执行 LinuxMirrors 官方脚本。\n"
    printf "入口 URL: %s\n" "$url"
    printf "说明: 此操作可能修改系统软件源并触发包管理器操作。\n"
    if ! yesno_select "确认继续？"; then
        msg_info "已取消"
        return 0
    fi

    msg_info "正在下载 LinuxMirrors 脚本..."
    download_file "$url" "$tmp_file" || {
        rm -f "$tmp_file"
        return 1
    }
    chmod 700 "$tmp_file" 2>/dev/null || true

    bash "$tmp_file"
    status=$?
    rm -f "$tmp_file"

    if [ "$status" -eq 0 ]; then
        msg_ok "LinuxMirrors 执行完成"
    else
        msg_err "LinuxMirrors 执行失败"
    fi
    return "$status"
}

main() {
    local url=""

    require_root_action || exit 1
    printf "%b== LinuxMirrors 换源 ========================================%b\n\n" "$BOLD" "$PLAIN"
    url="$(select_source_url)" || exit 1
    run_linuxmirrors "$url"
}

main
