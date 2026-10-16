# SnapKit — macOS 分屏复刻工程

依据 [Magnet 官网](https://magnet.crowdcafe.com/) 与 [Apple App Store](https://apps.apple.com/us/app/magnet/id441258766?mt=12) 3.0.7 的公开介绍、演示及截图独立实现。原生 Swift / AppKit / SwiftUI，没有第三方依赖。

## 打开应用

本次构建位于 `dist/SnapKit.app`，可直接双击，或将它拖到 Applications 文件夹后运行。

**首次运行：** 在系统设置 → 隐私与安全性 → 辅助功能中添加并开启 SnapKit。应用内提供跳转按钮。授权后无需重新构建，菜单和快捷键会开始控制窗口。若移动了应用，建议从最终安装位置重新授权。

SnapKit 驻留菜单栏。再次打开应用或按 `⌘,` 进入设置。图标隐藏后，再次打开应用也能找回设置。

## 已实现

- 19 条内置命令：左右/上下半屏、四角、三分之一、三分之二、最大化、居中、恢复、前后显示器。
- 系统菜单栏控制、全局快捷键、快捷键录制、重复键检测及被其他程序占用的提示。
- 拖动窗口到边缘，显示目标预览，停留后放开才吸附；底边滑过相邻三等分区扩展到三分之二；按住 Option 取消吸附。
- 从已吸附窗口拖走时恢复原始尺寸，保存每个窗口首次吸附前的几何信息。
- 多显示器坐标与按比例迁移；竖屏三等分沿长边排列。
- 参照商店截图的图标侧栏、命令列表、24 × 12 布局网格和触发区域编辑器。
- 自定义命令：名称、位置、尺寸、快捷键、拖拽触发区域；内置布局也能修改尺寸。
- 边缘宽度、触发延迟、触发区域高亮、预览透明度/边框、窗口间距、屏幕外边距。
- 忽略应用、暂停、隐藏菜单图标、登录启动；设置保存在本机。
- 可选绿色按钮布局菜单，带悬停延迟设置（实验功能）。

## 与原版的边界

这是一份根据公开资料重建的独立工程，没有获取或反编译 Magnet 的收费安装包，没有复制它的程序代码或图标。公开截图能证实的结构已参考实现，但不能保证未公开细节或每个像素相同。官方来源与截图在 `Research/`。

- **iCloud 同步尚未实现。** 需要有效的 Apple Developer 团队、签名与 iCloud entitlement；本地构建没有配置这些能力。
- 默认快捷键中，官方文字直接证实的是 `⌃⌥→`。其他键位采用常见的 Magnet 兼容方案，完整默认映射未由原版运行核实。
- 绿色按钮入口可能与 macOS 原生窗口菜单重叠，默认关闭。
- 仅调整支持辅助功能的标准窗口；应用的最小尺寸、全屏模式、非标准窗口可能限制调整。不会跨 Spaces 移动窗口。
- 当前机器只有一块显示器，多屏与竖屏通过几何单元测试覆盖，尚未做多屏硬件测试。
- 当前 1.1.2 成品为 Apple Silicon 架构，已使用 Developer ID 签名并通过 Apple 公证，App 附有公证票据。移植到 Intel Mac 可在对应机器重新构建。

## 默认快捷键

以下除跨屏外均使用 Control + Option：

| 功能 | 按键 |
|---|---|
| 左 / 右 / 上 / 下半屏 | ← / → / ↑ / ↓ |
| 左上 / 右上 / 左下 / 右下 | U / I / J / K |
| 左 / 中 / 右三分之一 | D / F / G |
| 左 / 中 / 右三分之二 | E / R / T |
| 最大化 / 居中 / 恢复 | Return / C / Delete |
| 上一个 / 下一个显示器 | Control + Option + Command + ← / → |

## 构建与测试

需要 macOS 13+ 和 Xcode Command Line Tools（当前在 Xcode / Swift 6.3.2 上构建）。

```sh
./Scripts/build.sh
swift test
open dist/SnapKit.app
```

`Package.swift` 可用 Xcode 打开，也可以完全通过 SwiftPM 构建。发布构建写入 `dist/SnapKit.app`。

可选的 AX 集成检查只创建并调整自己的临时窗口，不会修改已有用户窗口：

```sh
dist/SnapKit.app/Contents/MacOS/SnapKit --smoke-test
```

执行前应退出其他 SnapKit 实例。检查结果保存在 `$TMPDIR/snapkit-smoke-test.json`；没有辅助功能权限时会报告 `trusted: false`，不能当作通过。

当前验证结果见 `Research/validation.md`。

## 图标（1.0.1）

正式采用用户选定的 Clear Blue 第 1 版，包含亮蓝底座、圆形蓝色层次和左长右双窗符号。已接入应用图标、“关于”页及菜单栏单色配套标志。

透明 PNG 在 `Resources/AppIcon.png`，macOS `.icns` 在 `Resources/AppIcon.icns`，设计母版与处理提示词在 `Branding/Final/`。

`./Scripts/package.sh` 生成带版本号的安装包和源码包。当前安装包是 `dist/SnapKit-1.1.2-macOS-arm64.dmg`；旧版安装包保留。

## GitHub 发布版 1.1.2

[下载最新版](https://github.com/luchuangao/SnapKit/releases/latest) · [问题反馈](https://github.com/luchuangao/SnapKit/issues) · [English](README.md)

新增真实英文界面，可在设置 → 通用 → 语言中选择简体中文、English 或跟随系统。中英文实际窗口截图分别保存在 `Docs/Screenshots/`。运行 `./Scripts/capture-screenshots.sh` 可重新导出，PNG 附带语言、版本和尺寸元数据。

当前分发包为 1.1.2（构建 5），适用于 Apple Silicon、macOS 13+，已使用 Developer ID 签名并通过 Apple 公证，App 附有可离线验证的公证票据。下载 DMG 后拖入“应用程序”，打开后授予辅助功能权限。没有自动更新器。验证与复现步骤见 [公证说明](Docs/Notarization.md)。
