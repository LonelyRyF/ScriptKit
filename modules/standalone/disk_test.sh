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

main() {
    local url="https://www.hdsentinel.com/hdslin/hdsentinel-019c-x64.gz"
    local archive=""
    local binary=""
    local arch=""
    local rc=0

    check_root
    ensure_commands mktemp chmod "gunzip:gzip" || exit 1

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

    printf "\n%b== Hard Disk Sentinel ========================================%b\n\n" "$BOLD" "$PLAIN"
    "$binary"
    rc=$?

    if [ "$rc" -eq 0 ]; then
        msg_ok "磁盘检测已完成"
    else
        msg_warn "检测程序退出码: $rc"
    fi

    return "$rc"
}

main
