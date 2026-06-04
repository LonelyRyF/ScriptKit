#!/usr/bin/env bash
set -u

# ============================================================
# 修改 SSH 登录方式
# 功能：方向键多选菜单 — 禁用密码、启用密钥、禁用root、生成密钥对、添加公钥
# 安全：sshd -t 校验 + 自动回滚 + 备份轮转
# ============================================================

# 加载公共库
SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

GENERATED_PUBLIC_KEY=""
GENERATED_PUBLIC_KEY_USER=""

AUTH_MODE_KEYS=(
    "disable_password"
    "enable_password"
    "enable_pubkey"
    "disable_root_login"
    "allow_root_key_only"
    "generate_keypair"
    "add_pubkey"
)

# --- 操作函数 ---

do_disable_password() {
    msg_info "禁用密码登录..."
    set_sshd_option "PasswordAuthentication" "no"
    set_sshd_option "ChallengeResponseAuthentication" "no"
    msg_ok "密码登录已禁用"
}

do_enable_password() {
    msg_info "启用密码登录..."
    set_sshd_option "PasswordAuthentication" "yes"
    msg_ok "密码登录已启用"
}

do_enable_pubkey() {
    msg_info "启用密钥认证..."
    set_sshd_option "PubkeyAuthentication" "yes"
    set_sshd_option "AuthorizedKeysFile" ".ssh/authorized_keys"
    msg_ok "密钥认证已启用"
}

do_disable_root_login() {
    msg_info "禁用 root SSH 登录..."
    set_sshd_option "PermitRootLogin" "no"
    msg_ok "root 登录已禁用"
}

do_allow_root_key_only() {
    msg_info "设置 root 仅允许密钥登录..."
    set_sshd_option "PermitRootLogin" "prohibit-password"
    msg_ok "root 已设为仅密钥登录"
}

do_generate_keypair() {
    local target_user=""
    printf '%b' "$(msg_prompt "输入" "为哪个用户生成密钥对？（默认当前用户 root）: ")"
    read -r target_user
    target_user="${target_user:-root}"

    local home_dir
    home_dir=$(eval printf '%s' "~${target_user}" 2>/dev/null)
    if [ ! -d "$home_dir" ]; then
        home_dir=$(getent passwd "$target_user" 2>/dev/null | cut -d: -f6)
    fi
    if [ -z "$home_dir" ] || [ ! -d "$home_dir" ]; then
        msg_err "找不到用户 $target_user 的家目录"
        return 1
    fi

    local ssh_dir="${home_dir}/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    local key_type=""
    printf "\n选择密钥类型:\n"
    printf "  1) ed25519（推荐，更安全更快）\n"
    printf "  2) rsa（4096位，兼容性好）\n"
    printf '%b' "$(msg_prompt "输入" "选择 [1/2]（默认 1）: ")"
    read -r key_type
    key_type="${key_type:-1}"

    local key_file=""
    local algo=""
    case "$key_type" in
        2)
            algo="rsa"
            key_file="${ssh_dir}/id_rsa"
            ;;
        *)
            algo="ed25519"
            key_file="${ssh_dir}/id_ed25519"
            ;;
    esac

    if [ -f "$key_file" ] || [ -f "${key_file}.pub" ]; then
        if ! yesno_select "密钥文件 $key_file 已存在，是否覆盖？"; then
            msg_warn "跳过密钥生成"
            return 0
        fi
        rm -f "$key_file" "${key_file}.pub"
    fi

    local comment=""
    printf '%b' "$(msg_prompt "输入" "密钥注释（默认 ${target_user}@$(hostname)）: ")"
    read -r comment
    comment="${comment:-${target_user}@$(hostname)}"

    local passphrase=""
    printf '%b' "$(msg_prompt "输入" "是否设置密钥密码？（直接回车为空密码）: ")"
    read -rs passphrase
    printf '\n'
    passphrase="${passphrase:-}"

    msg_info "正在生成 $algo 密钥..."
    if [ "$algo" = "rsa" ]; then
        ssh-keygen -t rsa -b 4096 -C "$comment" -f "$key_file" -N "$passphrase" -q || return 1
    else
        ssh-keygen -t ed25519 -C "$comment" -f "$key_file" -N "$passphrase" -q || return 1
    fi

    chown -R "$target_user":"$(id -gn "$target_user" 2>/dev/null || printf '%s' "$target_user")" "$ssh_dir"
    chmod 600 "$key_file"
    chmod 644 "${key_file}.pub"

    msg_ok "密钥已生成"
    printf "  私钥: %s\n" "$key_file"
    printf "  公钥: %s\n" "${key_file}.pub"

    GENERATED_PUBLIC_KEY="$(< "${key_file}.pub")"
    GENERATED_PUBLIC_KEY_USER="$target_user"

    printf "\n%b公钥内容:%b\n" "$BOLD" "$PLAIN"
    printf '%s\n' "$GENERATED_PUBLIC_KEY"
    msg_info "已记录此公钥，后续添加 authorized_keys 时无需再次粘贴"
}

do_add_pubkey() {
    local default_user="${1:-root}"
    local default_pubkey="${2:-}"
    local target_user=""
    printf '%b' "$(msg_prompt "输入" "为哪个用户添加公钥？（默认 ${default_user}）: ")"
    read -r target_user
    target_user="${target_user:-$default_user}"

    local home_dir
    home_dir=$(eval printf '%s' "~${target_user}" 2>/dev/null)
    if [ ! -d "$home_dir" ]; then
        home_dir=$(getent passwd "$target_user" 2>/dev/null | cut -d: -f6)
    fi
    if [ -z "$home_dir" ] || [ ! -d "$home_dir" ]; then
        msg_err "找不到用户 $target_user 的家目录"
        return 1
    fi

    local ssh_dir="${home_dir}/.ssh"
    local auth_keys="${ssh_dir}/authorized_keys"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    local pubkey="$default_pubkey"
    if [ -n "$pubkey" ]; then
        msg_info "使用刚生成的公钥，无需再次粘贴"
    else
        printf "\n请粘贴公钥内容（ssh-rsa/ssh-ed25519 开头的一行）:\n"
        read -r pubkey
    fi

    if [ -z "$pubkey" ]; then
        msg_err "公钥内容不能为空"
        return 1
    fi

    # 简单校验格式
    if ! printf '%s' "$pubkey" | grep -qE '^(ssh-rsa|ssh-ed25519|ecdsa-sha2)'; then
        if ! yesno_select "公钥格式看起来不正确，仍然添加？"; then
            msg_warn "已跳过"
            return 0
        fi
    fi

    # 检查是否已存在
    if [ -f "$auth_keys" ] && grep -qF "$pubkey" "$auth_keys"; then
        msg_warn "此公钥已存在于 authorized_keys 中"
        return 0
    fi

    printf '%s\n' "$pubkey" >> "$auth_keys"
    chmod 600 "$auth_keys"
    chown -R "$target_user":"$(id -gn "$target_user" 2>/dev/null || printf '%s' "$target_user")" "$ssh_dir"

    msg_ok "公钥已添加到 $auth_keys"
}

show_current_status() {
    printf "%b当前 SSH 配置:%b\n" "$BOLD" "$PLAIN"
    local pw_auth pub_auth root_login
    pw_auth=$(get_sshd_option "PasswordAuthentication")
    pub_auth=$(get_sshd_option "PubkeyAuthentication")
    root_login=$(get_sshd_option "PermitRootLogin")
    printf "  PasswordAuthentication: %s\n" "${pw_auth:-（未设置，默认 yes）}"
    printf "  PubkeyAuthentication:   %s\n" "${pub_auth:-（未设置，默认 yes）}"
    printf "  PermitRootLogin:        %s\n" "${root_login:-（未设置，默认 yes）}"
    printf '\n'
}

auth_mode_needs_config_change() {
    case "$1" in
        disable_password|enable_password|enable_pubkey|disable_root_login|allow_root_key_only) return 0 ;;
        *) return 1 ;;
    esac
}

run_auth_mode() {
    case "$1" in
        disable_password) do_disable_password ;;
        enable_password) do_enable_password ;;
        enable_pubkey) do_enable_pubkey ;;
        disable_root_login) do_disable_root_login ;;
        allow_root_key_only) do_allow_root_key_only ;;
        generate_keypair) do_generate_keypair ;;
        add_pubkey) do_add_pubkey "$GENERATED_PUBLIC_KEY_USER" "$GENERATED_PUBLIC_KEY" ;;
        *)
            msg_err "未知 SSH 登录方式操作: $1"
            return 1
            ;;
    esac
}

apply_auth_modes() {
    local mode=""
    local backup=""
    local need_config_change="n"
    local need_restart="n"

    for mode in "$@"; do
        if auth_mode_needs_config_change "$mode"; then
            need_config_change="y"
            break
        fi
    done

    printf '\n'
    if [ "$need_config_change" = "y" ]; then
        backup=$(backup_ssh_config) || return 1
    fi

    for mode in "$@"; do
        run_auth_mode "$mode" || return 1
        if auth_mode_needs_config_change "$mode"; then
            need_restart="y"
        fi
    done

    if [ "$need_restart" = "y" ]; then
        if ! validate_ssh_config; then
            rollback_ssh_config "$backup"
            msg_err "配置无效，已回滚。操作中止"
            return 1
        fi

        if yesno_select "是否立即重启 SSH 服务使配置生效？" "y"; then
            msg_info "正在重启 SSH 服务..."
            if restart_sshd; then
                msg_ok "SSH 服务已重启"
            else
                rollback_ssh_config "$backup"
                msg_err "SSH 重启失败，已回滚配置"
                restart_sshd 2>/dev/null
                return 1
            fi
        else
            msg_warn "配置已修改但未重启，请手动重启 SSH 服务"
        fi
    fi

    printf "\n%bSSH 登录方式修改完成！%b\n" "$GREEN" "$PLAIN"
    printf "%b请在新终端测试连接，确认可用后再关闭当前会话。%b\n" "$YELLOW" "$PLAIN"
}

run_batch_mode() {
    local i=0
    local has_selection="n"
    local -a selected_modes=()

    local -a menu_labels=(
        "禁用密码登录"
        "启用密码登录"
        "启用密钥认证"
        "禁用 root SSH 登录"
        "root 仅允许密钥登录 (prohibit-password)"
        "生成 SSH 密钥对"
        "添加公钥到 authorized_keys"
    )
    local -a menu_selected=(0 0 0 0 0 0 0)

    multiselect_menu "$(scriptkit_step_title "修改 SSH 登录方式（空格选中，回车确认）")" menu_labels menu_selected

    for ((i = 0; i < ${#menu_selected[@]}; i++)); do
        if [ "${menu_selected[$i]}" = "1" ]; then
            has_selection="y"
            selected_modes+=("${AUTH_MODE_KEYS[$i]}")
        fi
    done

    if [ "$has_selection" = "n" ]; then
        msg_info "未选择任何操作，退出"
        return 0
    fi

    apply_auth_modes "${selected_modes[@]}"
}

# --- 主流程 ---
main() {
    check_root

    draw_current_title "修改 SSH 登录方式"

    show_current_status

    case "${SCRIPTKIT_SSH_AUTH_MODE:-}" in
        ""|batch)
            run_batch_mode || exit 1
            ;;
        *)
            apply_auth_modes "$SCRIPTKIT_SSH_AUTH_MODE" || exit 1
            ;;
    esac
}

main
