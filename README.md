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

## 关联项目

ScriptKit 集成了以下开源工具（排名不分先后）：

| 工具 | 说明 |
|---|---|
| [masonr/yet-another-bench-script](https://github.com/masonr/yet-another-bench-script) | UnixBench + Geekbench + 网络测速 |
| [LloydAsp/NodeQuality](https://github.com/LloydAsp/NodeQuality) | VPS 综合测试（无痕模式） |
| [xykt/IPQuality](https://github.com/xykt/IPQuality) | IP 质量体检 |
| [lmc999/RegionRestrictionCheck](https://github.com/lmc999/RegionRestrictionCheck) | 流媒体解锁检测 |
| [spiritLHLS/ecs](https://github.com/spiritLHLS/ecs) | VPS 融合怪测试 |
| [leitbogioro/Tools](https://github.com/leitbogioro/Tools) | Linux 一键重装 |
| [bin456789/reinstall](https://github.com/bin456789/reinstall) | 系统重装 |
| [233boy/sing-box](https://github.com/233boy/sing-box) | Sing-box 一键管理 |
| [fscarmen/sing-box](https://github.com/fscarmen/sing-box) | Sing-box 一键安装 |
| [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui) | 3x-ui 面板 |
| [zywe03/realm-xwPF](https://github.com/zywe03/realm-xwPF) | Realm 全功能一键中转脚本 |

## 许可证

[MIT](LICENSE)
