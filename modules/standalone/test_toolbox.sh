#!/usr/bin/env bash
set -u

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

scriptkit_repo_root() {
    cd -- "${SCRIPT_SELF_DIR}/../.." >/dev/null 2>&1 && pwd
}

scriptkit_test_workdir() {
    printf '%s' "${SCRIPTKIT_TEST_WORKDIR:-${HOME:-/root}/.scriptkit/${SCRIPTKIT_TEST_TOOL:-testtool}}"
}

scriptkit_test_timestamp() {
    date +%Y%m%d-%H%M%S
}

scriptkit_prepare_script() {
    local local_dir="$1"
    local local_name="$2"
    local remote_url="$3"
    local target_file="$4"

    mkdir -p "$(dirname -- "$target_file")" || return 1

    if [ -f "$local_dir/$local_name" ]; then
        cp -p "$local_dir/$local_name" "$target_file" || return 1
        return 0
    fi

    msg_info "正在下载资源: $local_name"
    download_file "$remote_url" "$target_file" || return 1
}

scriptkit_patch_nodequality_exit() {
    local target_file="$1"
    local tmp_file="${target_file}.tmp"

    awk '
        /^function post_cleanup\(\)\{/ { in_post_cleanup = 1 }
        in_post_cleanup && !patched && $0 ~ /^[[:space:]]*exit 1[[:space:]]*$/ {
            sub(/exit 1/, "return 0")
            patched = 1
        }
        { print }
        in_post_cleanup && /^}/ { in_post_cleanup = 0 }
    ' "$target_file" > "$tmp_file" || return 1

    mv "$tmp_file" "$target_file" || return 1
}

scriptkit_prepare_current_tool() {
    local tool="${SCRIPTKIT_TEST_TOOL:-}"
    local repo_root="$(scriptkit_repo_root)"
    local workdir="$(scriptkit_test_workdir)"

    case "$tool" in
        yabs)
            scriptkit_prepare_script \
                "$repo_root/yet-another-bench-script" \
                "yabs.sh" \
                "https://raw.githubusercontent.com/masonr/yet-another-bench-script/master/yabs.sh" \
                "$workdir/yabs.sh"
            ;;
        nodequality)
            scriptkit_prepare_script \
                "$repo_root/NodeQuality" \
                "NodeQuality.sh" \
                "https://raw.githubusercontent.com/LloydAsp/NodeQuality/main/NodeQuality.sh" \
                "$workdir/NodeQuality.sh" || return 1
            scriptkit_patch_nodequality_exit "$workdir/NodeQuality.sh"
            ;;
        ipquality)
            scriptkit_prepare_script \
                "$repo_root/IPQuality" \
                "ip.sh" \
                "https://raw.githubusercontent.com/xykt/IPQuality/main/ip.sh" \
                "$workdir/ip.sh"
            ;;
        regioncheck)
            scriptkit_prepare_script \
                "$repo_root/RegionRestrictionCheck" \
                "check.sh" \
                "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh" \
                "$workdir/check.sh"
            ;;
        *)
            msg_err "未知测试工具: $tool"
            return 1
            ;;
    esac
}

scriptkit_run_custom_args() {
    local workdir="$1"
    local script_file="$2"

    if [ -z "${SCRIPTKIT_TEST_ARGS:-}" ]; then
        msg_err "未提供自定义参数"
        return 1
    fi

    (
        cd "$workdir" || exit 1
        bash -c 'script_file="$1"; eval "set -- $SCRIPTKIT_TEST_ARGS"; bash "$script_file" "$@"' _ "$script_file"
    )
}

scriptkit_run_yabs() {
    local workdir="$(scriptkit_test_workdir)"
    local mode="${SCRIPTKIT_TEST_MODE:-default}"
    local script_file="$workdir/yabs.sh"
    local output_file=""
    local -a script_args=()

    mkdir -p "$workdir" || return 1
    scriptkit_prepare_current_tool || return 1

    case "$mode" in
        default) ;;
        reduced) script_args=(-r) ;;
        system_disk) script_args=(-i) ;;
        network_only) script_args=(-f -g) ;;
        json) script_args=(-j) ;;
        json_file)
            output_file="$workdir/yabs-$(scriptkit_test_timestamp).json"
            script_args=(-w "$output_file")
            ;;
        help) script_args=(-h) ;;
        gb4) script_args=(-4) ;;
        gb5) script_args=(-5) ;;
        gb45) script_args=(-9) ;;
        custom)
            msg_info "YABS 工作目录: $workdir"
            scriptkit_run_custom_args "$workdir" "$script_file"
            return
            ;;
        *)
            msg_err "未知 YABS 模式: $mode"
            return 1
            ;;
    esac

    msg_info "YABS 工作目录: $workdir"
    if [ -n "$output_file" ]; then
        msg_info "YABS JSON 文件: $output_file"
    fi

    (
        cd "$workdir" || exit 1
        bash "$script_file" "${script_args[@]}"
    )
}

scriptkit_run_nodequality() {
    local workdir="$(scriptkit_test_workdir)"
    local mode="${SCRIPTKIT_TEST_MODE:-default}"
    local script_file="$workdir/NodeQuality.sh"
    local -a prompt_answers=()
    local -a script_args=(-D "$workdir")

    require_root_action || return 1
    mkdir -p "$workdir" || return 1
    scriptkit_prepare_current_tool || return 1

    case "$mode" in
        interactive) ;;
        default) prompt_answers=(y y y y) ;;
        ipv4_default)
            script_args=(-4 -D "$workdir")
            prompt_answers=(y y y y)
            ;;
        ipv6_default)
            script_args=(-6 -D "$workdir")
            prompt_answers=(y y y y)
            ;;
        english_default)
            script_args=(-E -D "$workdir")
            prompt_answers=(y y y y)
            ;;
        hardware_only) prompt_answers=(y n n n) ;;
        hardware_fast) prompt_answers=(f n n n) ;;
        hardware_verbose) prompt_answers=(v n n n) ;;
        ip_only) prompt_answers=(n y n n) ;;
        net_only) prompt_answers=(n n y n) ;;
        net_lite) prompt_answers=(n n l n) ;;
        trace_only) prompt_answers=(n n n y) ;;
        *)
            msg_err "未知 NodeQuality 模式: $mode"
            return 1
            ;;
    esac

    msg_info "NodeQuality 工作目录: $workdir"

    (
        cd "$workdir" || exit 1
        if [ "${#prompt_answers[@]}" -gt 0 ]; then
            printf '%s\n' "${prompt_answers[@]}" | bash "$script_file" "${script_args[@]}"
        else
            bash "$script_file" "${script_args[@]}"
        fi
    )
}

scriptkit_run_ipquality() {
    local workdir="$(scriptkit_test_workdir)"
    local mode="${SCRIPTKIT_TEST_MODE:-default}"
    local script_file="$workdir/ip.sh"
    local output_file=""
    local -a script_args=()

    mkdir -p "$workdir" || return 1
    scriptkit_prepare_current_tool || return 1

    case "$mode" in
        default) ;;
        ipv4) script_args=(-4) ;;
        ipv6) script_args=(-6) ;;
        fullip) script_args=(-f) ;;
        english) script_args=(-E) ;;
        json) script_args=(-j) ;;
        privacy) script_args=(-p) ;;
        ansi_file)
            output_file="$workdir/ipquality-$(scriptkit_test_timestamp).ansi"
            script_args=(-o "$output_file")
            ;;
        json_file)
            output_file="$workdir/ipquality-$(scriptkit_test_timestamp).json"
            script_args=(-o "$output_file")
            ;;
        text_file)
            output_file="$workdir/ipquality-$(scriptkit_test_timestamp).txt"
            script_args=(-o "$output_file")
            ;;
        skip_dep) script_args=(-n) ;;
        auto_install) script_args=(-y) ;;
        ipv4_full) script_args=(-4 -f) ;;
        interface)
            if [ -z "${SCRIPTKIT_TEST_INTERFACE:-}" ]; then
                msg_err "未提供网卡或出口 IP"
                return 1
            fi
            script_args=(-i "${SCRIPTKIT_TEST_INTERFACE}")
            ;;
        proxy)
            if [ -z "${SCRIPTKIT_TEST_PROXY:-}" ]; then
                msg_err "未提供代理地址"
                return 1
            fi
            script_args=(-x "${SCRIPTKIT_TEST_PROXY}")
            ;;
        custom)
            msg_info "IPQuality 工作目录: $workdir"
            scriptkit_run_custom_args "$workdir" "$script_file"
            return
            ;;
        *)
            msg_err "未知 IPQuality 模式: $mode"
            return 1
            ;;
    esac

    msg_info "IPQuality 工作目录: $workdir"
    if [ -n "$output_file" ]; then
        msg_info "IPQuality 输出文件: $output_file"
    fi

    (
        cd "$workdir" || exit 1
        bash "$script_file" "${script_args[@]}"
    )
}

scriptkit_run_regioncheck() {
    local workdir="$(scriptkit_test_workdir)"
    local mode="${SCRIPTKIT_TEST_MODE:-interactive}"
    local script_file="$workdir/check.sh"
    local -a script_args=()

    mkdir -p "$workdir" || return 1
    scriptkit_prepare_current_tool || return 1

    case "$mode" in
        interactive) ;;
        all) script_args=(-R 66) ;;
        global) script_args=(-R 0) ;;
        instagram) script_args=(-R 88) ;;
        sport) script_args=(-R 99) ;;
        ipv4_all) script_args=(-M 4 -R 66) ;;
        ipv6_all) script_args=(-M 6 -R 66) ;;
        english_all) script_args=(-E en -R 66) ;;
        region)
            if [ -z "${SCRIPTKIT_TEST_REGION:-}" ]; then
                msg_err "未提供地区编号"
                return 1
            fi
            script_args=(-R "${SCRIPTKIT_TEST_REGION}")
            ;;
        interface)
            if [ -z "${SCRIPTKIT_TEST_INTERFACE:-}" ]; then
                msg_err "未提供网卡名称"
                return 1
            fi
            script_args=(-I "${SCRIPTKIT_TEST_INTERFACE}" -R 66)
            ;;
        proxy)
            if [ -z "${SCRIPTKIT_TEST_PROXY:-}" ]; then
                msg_err "未提供代理地址"
                return 1
            fi
            script_args=(-P "${SCRIPTKIT_TEST_PROXY}" -R 66)
            ;;
        xff)
            if [ -z "${SCRIPTKIT_TEST_XFF:-}" ]; then
                msg_err "未提供自定义出口 IP"
                return 1
            fi
            script_args=(-X "${SCRIPTKIT_TEST_XFF}" -R 66)
            ;;
        custom)
            msg_info "RegionRestrictionCheck 工作目录: $workdir"
            scriptkit_run_custom_args "$workdir" "$script_file"
            return
            ;;
        *)
            msg_err "未知 RegionRestrictionCheck 模式: $mode"
            return 1
            ;;
    esac

    msg_info "RegionRestrictionCheck 工作目录: $workdir"

    (
        cd "$workdir" || exit 1
        bash "$script_file" "${script_args[@]}"
    )
}

main() {
    case "${SCRIPTKIT_TEST_TOOL:-}" in
        yabs) scriptkit_run_yabs ;;
        nodequality) scriptkit_run_nodequality ;;
        ipquality) scriptkit_run_ipquality ;;
        regioncheck) scriptkit_run_regioncheck ;;
        *)
            msg_err "未指定测试工具"
            return 1
            ;;
    esac
}

main "$@"
