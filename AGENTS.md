# AGENTS.md

## Overview

Pure Bash interactive menu framework for Linux toolboxes. No external TUI dependencies — only `bash` (4.0+) and `tput`.

## Key files

- `menu.sh` — main entry point; contains the menu engine, registration API, and demo handlers.
- `modules/*.sh` — source modules auto-loaded by `load_modules`; they call `add_menu`/`add_action`/`add_script` to register entries.
- `modules/standalone/*.sh` — independent scripts executed via `bash`; registered with `add_script`.
- `modules/modules.list` — manifest of relative paths for remote download.

## Architecture

- Mixed module system: lightweight modules are `source`d (share variables/functions); heavy or risky modules run as separate `bash` processes.
- Menu tree uses associative arrays: `MENU_TITLES`, `MENU_CHILDREN`, `MENU_PARENTS`, `ITEM_TYPES`, `ITEM_TARGETS`.
- `load_modules` checks local `$MODULE_DIR` first; if empty, downloads from `$MODULE_BASE_URL` into `$MODULE_CACHE_DIR` (`~/.cache/scriptkit/modules`).
- `SCRIPT_DIR` falls back to `$PWD` when run via `bash <(curl ...)`.

## Validation

Run syntax check after any edit:

```bash
bash -n menu.sh
bash -n modules/example.sh
bash -n modules/standalone/example.sh
```

No test framework exists. `bash -n` is the only automated check. Always run it before considering work done.

## Conventions

- Use `set -u` (unbound variable errors). All variables must be initialized or use `${var:-}`.
- Colors use `\033[...m` escape variables (`RED`, `GREEN`, etc.) printed via `printf '%b'`, never `%s` for colored strings.
- Menu item IDs must be unique across the entire tree (they share global associative arrays).
- Standalone scripts must not assume they are sourced — they run in a child `bash` process.
- Source modules must not use `set -e` or `exit` at top level (they run inside the main process).

## Interaction UX

- Keep standalone script output continuous. Avoid decorative section headings like `--- 配置确认 ---` unless they show useful current state before an action.
- Do not print redundant confirmation summary blocks after the user just entered those values. When a safety confirmation is still necessary, use one concise `yesno_select` prompt with key values inline.
- Use `yesno_select` for every yes/no prompt. Do not hand-roll inline `> 是  否` prompts; the shared selector renders two option lines and writes the selected answer back to the original prompt line.
- Avoid generic outro blocks such as `常用命令`, empty status dumps, or long post-run tips. End with a short success/failure result and only essential next action.
- Reuse values generated during the same run instead of asking the user to paste them back into the script.
- When a function is used in command substitution, keep stdout machine-readable and send human status messages to stderr.

## Registration API

```bash
add_menu  "id" "title" "parent_id"
add_action "id" "title" "parent_id" "function_name"
add_script "id" "title" "parent_id" "relative/path.sh"
```

## Remote module deployment

Default remote base: `https://raw.githubusercontent.com/LonelyRyF/ScriptKit/main/modules`

Override with env vars:
- `MODULE_BASE_URL` — base URL for module files
- `MODULE_MANIFEST_URL` — URL to `modules.list`
- `MODULE_CACHE_DIR` — local cache path
