# AGENTS.md

## 概述

纯 Bash 交互式菜单框架，用于 Linux 工具箱。无需外部 TUI 依赖 — 仅需 `bash` (4.0+) 和 `tput`。

## 核心文件

- `menu.sh` — 入口点（74 行）：启动 + `main()`
- `modules/runtime.sh` — 共享运行时：颜色、UI 辅助函数、选择器、按键读取
- `modules/menu_core.sh` — 框架核心：注册表、模块加载、分发、菜单循环、SHA256 验证
- `modules/menu_ui.sh` — 框架 UI：渲染、交互式/普通选择器、过滤
- `modules/lib.sh` — 独立门面，被子进程脚本 `source`
- `modules/*.sh` — 源模块，由 `load_modules` 自动加载；通过 `add_menu`/`add_action`/`add_script` 注册
- `modules/standalone/*.sh` — 通过 `bash` 执行的独立脚本；使用 `add_script` 注册
- `modules/modules.list` — 控制加载顺序和远程下载的清单
- `modules/modules.sha256` — SHA256 校验和（由 GitHub Actions 自动生成，请勿本地编辑）
- `CONTRIBUTING.md` — 模块开发指南

## 架构

- 混合模块系统：轻量级模块通过 `source` 加载（共享变量/函数）；重量级或高风险模块作为独立的 `bash` 进程运行。
- 菜单树使用关联数组：`MENU_TITLES`、`MENU_CHILDREN`、`MENU_PARENTS`、`ITEM_TYPES`、`ITEM_TARGETS`。
- 加载顺序：`runtime.sh` → `menu_core.sh` → `menu_ui.sh` → `load_modules`（按 `modules.list` 顺序加载业务模块）。
- `load_modules` 首先检查本地 `$MODULE_DIR`；如果为空，则从 `$MODULE_BASE_URL` 下载到 `$MODULE_CACHE_DIR`（`~/.cache/scriptkit/modules`）。
- SHA256 校验和验证下载的文件；匹配的缓存文件将被跳过，以加快后续启动速度。
- 每个顶级模块注册自己的父菜单（`add_menu "xxx" "标题" "main"`）；`menu.sh` 仅注册 `main`。
- 当通过 `bash <(curl ...)` 运行时，`SCRIPT_DIR` 回退到 `$PWD`。

## 层级职责

- `menu.sh` 应仅保留在运行时加载之前必须存在的引导相关逻辑。
- `modules/menu_core.sh` 应拥有注册表状态、`add_menu`/`add_action`/`add_script`、模块加载、分发、路径构建和注册表验证。
- `modules/menu_ui.sh` 应拥有渲染和选择 UX：标签/提示格式化、过滤、交互式/普通选择器、帮助和暂停行为。
- `modules/runtime.sh` 或 `modules/lib.sh` 已提供的共享原语不得在菜单层文件中重新定义。
- 在 `modules/` 下引入新的源框架文件时，应在同一变更中更新 `modules/modules.list`，以便远程引导仍可下载它们。

## 验证

每次编辑后运行语法检查：

```bash
bash -n menu.sh
bash -n modules/example.sh
bash -n modules/standalone/example.sh
```

不存在测试框架。`bash -n` 是唯一的自动检查。在认为工作完成之前务必运行它。使用 `make check` 可一次性验证所有文件。

如果修改了菜单框架，也要对每个被修改的框架文件进行语法检查。当它们存在时，包括 `modules/menu_core.sh` 和 `modules/menu_ui.sh`。保持交互式选择器路径和普通回退路径的行为一致。

## 约定

### 变量处理

- 使用 `set -u`（未绑定变量错误）。所有变量必须初始化或使用 `${var:-}`。

### 颜色输出

- 颜色使用 `\033[...m` 转义变量（`RED`、`GREEN` 等），通过 `printf '%b'` 打印，永远不要对彩色字符串使用 `%s`。

### 菜单结构

- 菜单项 ID 必须在整个树中唯一（它们共享全局关联数组）。

### 脚本执行

- 独立脚本不得假定它们被 source — 它们在子 `bash` 进程中运行。
- 源模块不得在顶层使用 `set -e` 或 `exit`（它们在主进程内运行）。

## 交互 UX

### 输出风格

- 保持独立脚本输出连续。避免装饰性章节标题如 `--- 配置确认 ---`，除非它们在操作前显示有用的当前状态。
- 不要在用户刚输入这些值后打印冗余的确认摘要块。当仍需要安全确认时，使用一个简洁的 `yesno_select` 提示，内联关键值。
- 避免通用的结尾块，如 `常用命令`、空状态转储或冗长的运行后提示。以简短的成功/失败结果和仅必要的下一步操作结束。

### 用户提示

- 对每个是/否提示使用 `yesno_select`。不要手动编写内联 `> 是  否` 提示；共享选择器渲染两个选项行，并将选定的答案写回原始提示行。
- 重用同一次运行中生成的值，而不是要求用户将它们粘贴回脚本。

### 函数输出

- 当函数用于命令替换时，保持 stdout 机器可读，将人类状态消息发送到 stderr。

## 注册 API

```bash
add_menu  "id" "title" "parent_id"
add_action "id" "title" "parent_id" "function_name"
add_script "id" "title" "parent_id" "relative/path.sh"
```

## 远程模块部署

默认远程基础 URL：`https://raw.githubusercontent.com/LonelyRyF/ScriptKit/main/modules`

### 环境变量

通过环境变量覆盖：

- `MODULE_BASE_URL` — 模块文件的基础 URL
- `MODULE_MANIFEST_URL` — `modules.list` 的 URL
- `MODULE_CACHE_DIR` — 本地缓存路径

## 版本控制规范

### 提交消息

格式：`<type>(<scope>): <subject>`

常用类型：`feat`、`fix`、`docs`、`refactor`、`chore`

**原子化提交**：每个提交应只包含一个逻辑变更

### Pull Request

- 始终推送到新分支，不要直接推送到 `main`/`master`
- PR 标题格式同提交消息，不超过 70 字符
