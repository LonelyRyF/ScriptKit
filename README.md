# ScriptKit

我们不是脚本制造商，我们只是已有脚本的搬运工。

**一键运行**：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/LonelyRyF/ScriptKit/main/menu.sh)
```

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `MODULE_DIR` | `$SCRIPT_DIR/modules` | 本地模块目录 |
| `MODULE_CACHE_DIR` | `~/.cache/scriptkit/modules` | 远程模块缓存 |
| `MODULE_BASE_URL` | GitHub raw /modules | 模块下载地址 |
| `SCRIPTKIT_LOG_ENABLED` | `1` | 设为 `0` 禁用日志 |

## 模块开发

新建 `modules/my_feature.sh`：

```bash
#!/usr/bin/env bash

add_menu "my_feature" "我的功能" "main"
add_action "my_hello" "Hello" "my_feature" "do_hello"

do_hello() {
    scriptkit_draw_current_title "Hello"
    ui_ok "Hello World!"
}
```

在 `modules/modules.list` 的 Source modules 分组中添加一行 `my_feature.sh` 即可。

详细规范见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

[MIT](LICENSE)
