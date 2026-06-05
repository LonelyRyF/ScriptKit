# 贡献指南

## 项目架构

```
menu.sh                          ← 入口 (74行): bootstrap + main()
modules/
├── runtime.sh                   ← 共享 runtime: 颜色、UI helper、选择器
├── menu_core.sh                 ← 框架核心: 注册表、模块加载、dispatch、菜单循环
├── menu_ui.sh                   ← 框架 UI: 渲染、交互选择器、过滤
├── lib.sh                       ← Standalone 门面: source 后提供共享能力
├── scriptkit_admin.sh           ← ScriptKit 自管模块
├── system_info.sh               ← 业务模块示例
├── ...                          ← 其他业务模块
├── modules.list                 ← 模块清单 (控制加载顺序)
└── standalone/
    ├── installnet.sh            ← 独立脚本 (子进程执行)
    └── ...
```

**加载顺序**: `runtime.sh` → `menu_core.sh` → `menu_ui.sh` → `load_modules`(按 `modules.list` 顺序 source 业务模块)

## 模块类型

| 类型 | 文件位置 | 执行方式 | 适用场景 |
|---|---|---|---|
| Source 模块 | `modules/*.sh` | 被 `source` 到主进程 | 轻量操作、需要访问注册表 |
| Standalone 脚本 | `modules/standalone/*.sh` | 独立 `bash` 子进程 | 重量级操作、可能失败/挂起的任务 |

## 新增 Source 模块

### 1. 创建文件

```bash
# modules/my_feature.sh
#!/usr/bin/env bash

# --- 菜单注册 (模块被 source 时立即执行) ---
add_menu "my_feature" "我的功能" "main"
add_action "my_feature_hello" "Hello World" "my_feature" "do_hello"

# --- 动作实现 ---
do_hello() {
    scriptkit_draw_current_title "Hello World"
    ui_ok "Hello from my_feature module!"
}
```

### 2. 更新 modules.list

在 `# Source modules loaded by menu.sh` 分组中添加一行：

```
my_feature.sh
```

**注意**: 行的位置决定了该模块在主菜单中的显示顺序。

### 3. 验证

```bash
bash -n modules/my_feature.sh
# 或一键全部检查:
make check
```

### Source 模块规则

- **不能** 使用 `exit` — 会终止整个主进程
- **不能** 使用 `set -e` — 会影响全局错误处理
- **必须** 兼容 `set -u` — 所有变量必须初始化或用 `${var:-}`
- 顶层代码仅限注册调用 (`add_menu`/`add_action`/`add_script`)
- 函数名和菜单 ID 必须**全局唯一**

## 新增 Standalone 脚本

### 1. 创建文件

```bash
# modules/standalone/my_tool.sh
#!/usr/bin/env bash
set -u

SCRIPT_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_SELF_DIR}/../lib.sh"

# 你的脚本逻辑...
scriptkit_draw_current_title "我的工具"
ui_info "开始执行..."

# 可以安全使用 exit
if ! some_check; then
    ui_error "检查失败"
    exit 1
fi

ui_ok "执行完成"
```

### 2. 在父模块中注册

在某个 source 模块中添加:

```bash
add_script "my_tool" "我的工具" "utility" "standalone/my_tool.sh"
```

### 3. 更新 modules.list

在 `# Standalone scripts` 分组中添加:

```
standalone/my_tool.sh
```

### 4. 验证

```bash
bash -n modules/standalone/my_tool.sh
```

### Standalone 脚本规则

- **可以** 使用 `exit`、`set -e` — 运行在独立子进程
- **必须** `source lib.sh` 获取共享能力
- **不能** 假设自己被 source — 始终以独立进程执行
- 使用 `trap` 处理 cleanup（临时文件等）

## 注册 API

### add_menu

```bash
add_menu "id" "显示标题" "parent_id"
```

注册一个子菜单。`parent_id` 省略时为根菜单（一般只有 `main` 这么用）。

### add_action

```bash
add_action "id" "显示标题" "parent_id" "function_name"
```

注册一个动作项。选中后调用 `function_name()`，在主进程内执行。

### add_script

```bash
add_script "id" "显示标题" "parent_id" "relative/path.sh"
```

注册一个脚本项。选中后以独立 `bash` 子进程执行 `modules/relative/path.sh`。

### ID 规则

- 全局唯一（所有菜单、动作、脚本共享同一命名空间）
- 建议用模块名作前缀：`network_ping`、`manage_hostname`
- 不要以 `__` 开头（保留给内部使用）

## 可用共享 Helper

### 颜色变量 (runtime.sh)

| 变量 | 用途 |
|---|---|
| `RED` | 红色 |
| `GREEN` | 绿色 |
| `YELLOW` | 黄色 |
| `BLUE` | 蓝色 |
| `CYAN` | 青色 |
| `BOLD` | 粗体 |
| `PLAIN` | 重置 |

使用方式：`printf "%b文本%b\n" "$GREEN" "$PLAIN"`

### UI 输出 (runtime.sh)

```bash
ui_info "提示信息"          # 蓝色 [信息]
ui_ok "成功信息"            # 绿色 [完成]
ui_warn "警告信息"          # 黄色 [警告]
ui_error "错误信息"         # 红色 [错误]
```

### 用户输入 (runtime.sh)

```bash
# 文本输入
ui_prompt "请输入用户名" username "默认值"

# 是/否选择
if yesno_select "确认执行？"; then
    echo "用户选了是"
fi

# 从列表选择 (lib.sh, standalone 专用)
choice="$(pick_from_options "选择一项" "选项A" "选项B" "选项C")"
```

### 标题绘制 (runtime.sh)

```bash
scriptkit_draw_current_title "当前操作名称"
```

### 工具函数 (runtime.sh)

```bash
command_exists "curl"        # 检查命令是否存在
download_file "url" "path"   # 下载文件 (curl/wget 自动选择)
```

### Standalone 专用 (lib.sh)

```bash
ensure_download_tool         # 确保 curl 或 wget 可用
msg_cancelled                # 输出 "已取消" 并统一格式
```

## 代码规范

### 通用

- `set -u` 全局生效，所有变量必须初始化或使用 `${var:-default}`
- 颜色输出用 `printf '%b...\n' "$COLOR" "$PLAIN"`，不用 `echo -e`
- 缩进: 4 空格（参见 `.editorconfig`）
- 行尾: LF（参见 `.gitattributes`）

### 交互 UX

- 所有是/否确认使用 `yesno_select`，不要手写 inline 提示
- 避免冗余输出：不要打印装饰性分隔线，不要打印用户刚输入的值的确认摘要
- 结束时只输出简短结果，不要附加"常用命令"或大段提示

### 函数设计

- 在命令替换中使用的函数，stdout 保持机器可读，人类提示发到 stderr
- 危险操作（删除、重装）必须有 `yesno_select` 确认

## modules.list 结构

```
# Framework files (sourced by menu.sh directly)
menu_core.sh
menu_ui.sh

# Source modules loaded by menu.sh
system_info.sh
test.sh
...

# Shared library (sourced by standalone scripts)
runtime.sh
lib.sh

# Standalone scripts used by add_script entries
standalone/change_ssh_port.sh
standalone/installnet.sh
...
```

- Framework files: 只有框架开发者添加
- Source modules: 加载顺序 = 菜单显示顺序
- Standalone scripts: 顺序无关，仅用于远程下载

## 常见问题

### Q: 我的菜单项没有出现

1. 检查 `modules.list` 中是否已添加你的模块文件
2. 检查 parent ID 是否正确（parent 必须在你的模块之前注册）
3. 运行 ScriptKit → 实用工具 → ScriptKit 管理 → 查看运行状态，看注册检查结果

### Q: bash -n 通过但运行时报错

`bash -n` 只做语法检查，不检查运行时错误。常见原因:
- 使用了未初始化的变量（`set -u` 生效）
- 调用了不存在的函数（拼写错误）
- source 路径不对

### Q: 如何决定用 Source 模块还是 Standalone 脚本？

- 如果操作可能失败/挂起/需要长时间运行 → Standalone
- 如果操作需要 root 且可能破坏系统 → Standalone
- 如果只是注册几个菜单项和简单函数 → Source 模块

### Q: 如何本地测试远程模式？

```bash
# 清除本地模块目录，让 ScriptKit 走远程下载路径
MODULE_DIR=/tmp/nonexistent bash menu.sh
```
