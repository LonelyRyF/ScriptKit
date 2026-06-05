# Phase 2 准备说明

## 目标

Phase 2 只做菜单框架拆分，把 `menu.sh` 从巨型实现文件收敛成真正的入口。

这一步的重点是分层，不是改功能。

## 这一步不要做的事

- 不调整根菜单所有权；这属于 Phase 4。
- 不迁出 `查看运行状态`、`刷新远程模块缓存`、`清理模块缓存`；这属于 Phase 3。
- 不改 standalone 脚本行为。
- 不顺手修改重装脚本、代理脚本或业务提示文案。
- 不在 `menu.sh` 保留长期兼容 wrapper；迁走后就让新文件成为权威实现。

## 建议拆分边界

### 保留在 `menu.sh`

- 环境与路径默认值：`ROOT_MENU`、`CURRENT_MENU`、`SCRIPT_DIR`、`MODULE_DIR`、`MODULE_CACHE_DIR`、`MODULE_BASE_URL`、`MODULE_MANIFEST_URL`
- `bootstrap_download_file`
- `load_runtime`
- `show_scriptkit_status`
- `refresh_remote_module_cache`
- `is_safe_cache_dir`
- `clear_module_cache`
- `define_menus`
- `main`

说明：

- Phase 2 结束后，`menu.sh` 可以继续暂时承载 ScriptKit 自管功能和顶层菜单定义。
- 但它不应再继续承载注册表实现、模块加载实现或菜单 UI 细节。

### 迁入 `modules/menu_ui.sh`

- `can_use_tput_menu`
- `pause_screen`
- `cleanup`
- `format_item_label`
- `format_item_tip`
- `item_matches_filter`
- `interactive_select_list`
- `plain_select_list`
- `select_list`

说明：

- 这里只负责展示、输入、过滤、快捷键、帮助页和暂停返回。
- 不负责模块加载、脚本解析、action dispatch、缓存管理。

### 迁入 `modules/menu_core.sh`

- 注册表数组声明：`MENU_TITLES`、`MENU_CHILDREN`、`MENU_PARENTS`、`ITEM_TITLES`、`ITEM_TYPES`、`ITEM_TARGETS`、`ITEM_PARENTS`、`MENU_WARNINGS`、`LOADED_MODULES`
- `record_menu_warning`
- `add_menu`
- `add_action`
- `add_script`
- `build_menu_path`
- `build_item_path`
- `run_action`
- `resolve_script_file`
- `run_standalone_with_env`
- `run_script`
- `is_safe_module_path`
- `download_remote_modules`
- `load_modules`
- `validate_menu_registry`
- `show_menu`
- `run_menu`

说明：

- `show_menu` 可以调用 UI 层的 `select_list`，但不直接维护绘制细节。
- `download_remote_modules` 和 `load_modules` 仍属于框架核心，不属于 UI。

## 迁移顺序

1. 新建 `modules/menu_ui.sh`，先把纯 UI 函数原样迁过去。
2. 新建 `modules/menu_core.sh`，再迁注册表、模块加载、dispatch 和菜单循环。
3. 在 `menu.sh` 里于 `load_runtime` 成功后 `source` 新文件，只保留 bootstrap、ScriptKit 自管功能、`define_menus`、`main`。
4. 同步更新 `modules/modules.list`，加入 `menu_core.sh` 和 `menu_ui.sh`，否则远程模式下载不到新框架文件。
5. 做最小语法校验和菜单 smoke 验证，再继续 Phase 3。

## 迁移时的硬约束

- 不修改已有菜单 ID。
- 不修改 `SCRIPTKIT_CURRENT_MENU_PATH` / `SCRIPTKIT_CURRENT_ITEM_PATH` 这些现有 env 名。
- 不改变 `?` 帮助、`/` 搜索、`q` 退出、返回上级、plain fallback 这些交互语义。
- 不把 Phase 3 的 ScriptKit 自管功能迁移混进这一步。
- 不把 Phase 4 的根菜单下放混进这一步。

## 最小验收口径

- `menu.sh` 中不再直接保留 `interactive_select_list`、`plain_select_list`、`add_menu`、`load_modules` 这些实现。
- 仓库中只保留一份权威的 `select_list`、`add_menu`、`load_modules` 实现。
- 新增的 `modules/menu_core.sh` 和 `modules/menu_ui.sh` 已加入 `modules/modules.list`。
- 至少通过：

```bash
bash -n menu.sh
bash -n modules/menu_core.sh
bash -n modules/menu_ui.sh
```

- 至少手工确认：

```text
1. 主菜单能正常打开
2. `?` 帮助页能打开并返回
3. `/` 搜索和清空搜索仍正常
4. 返回上级与 `q` 退出仍正常
5. action 项和 script 项都还能执行
6. 远程模块缓存刷新路径未被拆坏
```
