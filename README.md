# ScriptKit

纯 Bash 原生交互式 Linux 工具箱菜单框架。

## 特性

- 纯 Bash + `tput`，无外部 TUI 依赖
- 多层菜单，支持逐级返回
- 低闪烁局部刷新，SSH 友好
- 混合模块系统：source 模块 + 独立脚本
- 无本地模块时自动从远程下载
- 不支持 `tput` 时自动降级为数字输入模式

## 快速开始

本地运行：

```bash
bash menu.sh
```

网络运行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/LonelyRyF/ScriptKit/main/menu.sh)
```

## 项目结构

```text
menu.sh                  主菜单入口
modules/
  modules.list           远程模块清单
  example.sh             示例 source 模块
  standalone/
    example.sh           示例独立脚本模块
```

## 模块开发

在 `modules/` 下新建 `.sh` 文件，调用框架提供的注册函数：

```bash
# modules/my_module.sh
add_menu "my_menu" "我的工具" "main"
add_action "my_action" "做点什么" "my_menu" "my_handler"
add_script "my_script" "运行外部脚本" "my_menu" "modules/standalone/my_tool.sh"

my_handler() {
    echo "Hello from source module"
}
```

新模块会被主菜单自动加载，无需修改 `menu.sh`。

## 许可证

[MIT](LICENSE)
