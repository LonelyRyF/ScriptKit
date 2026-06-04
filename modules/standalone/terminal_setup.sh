#!/usr/bin/env bash
set -u

# Apply or restore a managed Bash prompt and shell quality-of-life block.

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

MANAGED_START="# >>> ScriptKit terminal setup >>>"
MANAGED_END="# <<< ScriptKit terminal setup <<<"
BACKUP_DIR="${XDG_CACHE_HOME:-${HOME:-.}/.cache}/scriptkit/bashrc_backups"
TARGET_BASHRC="${HOME:-.}/.bashrc"

backup_bashrc() {
    local backup_file=""

    mkdir -p "$BACKUP_DIR" || {
        msg_err "无法创建备份目录: $BACKUP_DIR"
        return 1
    }

    backup_file="$BACKUP_DIR/bashrc.$(date +%Y%m%d%H%M%S)"
    if [ -f "$TARGET_BASHRC" ]; then
        cp "$TARGET_BASHRC" "$backup_file" || {
            msg_err "备份 ~/.bashrc 失败"
            return 1
        }
    else
        : > "$backup_file"
    fi

    msg_ok "已备份到: $backup_file"
}

strip_managed_block() {
    local source_file="$1"
    local tmp_file="$2"

    if [ ! -f "$source_file" ]; then
        : > "$tmp_file"
        return 0
    fi

    awk -v start="$MANAGED_START" -v end="$MANAGED_END" '
        $0 == start { skip = 1; next }
        $0 == end { skip = 0; next }
        !skip { print }
    ' "$source_file" > "$tmp_file"
}

append_managed_block() {
    local target_file="$1"

    cat >> "$target_file" <<'EOF'
# >>> ScriptKit terminal setup >>>
scriptkit_git_branch() {
    local branch=""
    local dirty=""

    command -v git >/dev/null 2>&1 || return 0
    branch="$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)" || return 0
    if ! git diff --no-ext-diff --quiet --exit-code 2>/dev/null || \
        ! git diff --cached --quiet --exit-code 2>/dev/null || \
        [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
        dirty="*"
    fi

    printf ' \[\033[1;93m\](%s%s)\[\033[0m\]' "$branch" "$dirty"
}

scriptkit_update_prompt() {
    local exit_code="$?"
    local status=""

    history -a 2>/dev/null || true
    if [ "$exit_code" -ne 0 ]; then
        status="\[\033[1;31m\][${exit_code}]\[\033[0m\] "
    fi

    PS1="${status}\[\033[1;32m\]\t\[\033[0m\] \[\033[1;97m\]\u@\h\[\033[0m\] \[\033[1;94m\]\w\[\033[0m\]$(scriptkit_git_branch)\n\[\033[1;32m\]➤\[\033[0m\] "
    return "$exit_code"
}

HISTCONTROL=ignoredups:erasedups
HISTSIZE=10000
HISTFILESIZE=20000
HISTTIMEFORMAT='%F %T '
shopt -s histappend 2>/dev/null

if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

alias ll='ls -lh --color=auto'
alias la='ls -lah --color=auto'
alias l='ls -lah --color=auto'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias cls='clear'
alias h='history'

case ";${PROMPT_COMMAND:-};" in
    *";scriptkit_update_prompt;"*) ;;
    "::") PROMPT_COMMAND='scriptkit_update_prompt' ;;
    *) PROMPT_COMMAND="scriptkit_update_prompt;${PROMPT_COMMAND}" ;;
esac
# <<< ScriptKit terminal setup <<<
EOF
}

apply_setup() {
    local tmp_file=""

    backup_bashrc || return 1
    tmp_file="$(mktemp)" || return 1

    strip_managed_block "$TARGET_BASHRC" "$tmp_file" || {
        rm -f "$tmp_file"
        return 1
    }
    printf '\n' >> "$tmp_file"
    append_managed_block "$tmp_file"

    cp "$tmp_file" "$TARGET_BASHRC" || {
        rm -f "$tmp_file"
        msg_err "写入 ~/.bashrc 失败"
        return 1
    }
    rm -f "$tmp_file"
    msg_ok "Bash 优化配置已写入 ~/.bashrc"
    msg_info "新终端会自动生效；当前会话请手动执行: source ~/.bashrc"
}

restore_latest_backup() {
    local latest_backup=""
    local tmp_file=""

    latest_backup="$(ls -1t "$BACKUP_DIR"/bashrc.* 2>/dev/null | awk 'NR == 1 { print; exit }')"
    if [ -n "$latest_backup" ] && [ -f "$latest_backup" ]; then
        cp "$latest_backup" "$TARGET_BASHRC" || {
            msg_err "恢复备份失败"
            return 1
        }
        msg_ok "已恢复最近备份: $latest_backup"
        return 0
    fi

    tmp_file="$(mktemp)" || return 1
    strip_managed_block "$TARGET_BASHRC" "$tmp_file" || {
        rm -f "$tmp_file"
        return 1
    }
    cp "$tmp_file" "$TARGET_BASHRC" || {
        rm -f "$tmp_file"
        msg_err "移除托管配置失败"
        return 1
    }
    rm -f "$tmp_file"
    msg_ok "未找到备份，已仅移除 ScriptKit 托管配置块"
}

main() {
    local selected=0
    local -a menu_labels=(
        "应用 / 更新 Bash 优化"$'\n'"更新 ${TARGET_BASHRC} 中的 ScriptKit 托管配置"
        "恢复最近备份"$'\n'"恢复最近一次 ${TARGET_BASHRC} 备份"
        "退出"
    )

    case "${SCRIPTKIT_TERMINAL_SETUP_MODE:-}" in
        apply)
            draw_current_title "终端优化"
            if yesno_select "确认更新当前用户的 ~/.bashrc 配置？" "y"; then
                apply_setup || exit 1
            else
                msg_info "已取消"
            fi
            return
            ;;
        restore)
            draw_current_title "终端优化"
            if yesno_select "确认恢复最近一次 ~/.bashrc 备份？"; then
                restore_latest_backup || exit 1
            else
                msg_info "已取消"
            fi
            return
            ;;
    esac

    while true; do
        if ! select_menu "$(scriptkit_current_title "终端优化")" menu_labels selected 0; then
            msg_info "已取消"
            exit 0
        fi

        case "$selected" in
            0)
                if yesno_select "确认更新当前用户的 ~/.bashrc 配置？" "y"; then
                    apply_setup || exit 1
                else
                    msg_info "已取消"
                fi
                ;;
            1)
                if yesno_select "确认恢复最近一次 ~/.bashrc 备份？"; then
                    restore_latest_backup || exit 1
                else
                    msg_info "已取消"
                fi
                ;;
            2)
                exit 0
                ;;
            *)
                msg_warn "无效选择"
                ;;
        esac

        printf '\n%b' "$(msg_prompt "提示" "按 Enter 继续...")"
        read -r _
        clear 2>/dev/null || true
    done
}

main
