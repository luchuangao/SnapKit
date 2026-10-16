# SnapKit 正式图标 · Clear Blue

用户选定 `Concepts/Blue-reference/01-clear-blue.png`（第 1 版）。保留亮蓝底座、蓝色圆形层次、左侧长窗和右侧两窗的比例。

- `SnapKit-ClearBlue-master.png`：内置 ImageGen 从选定稿移除白色展示背景得到的透明底母版，1254 × 1254。
- `production-prompt.txt`：此次背景处理使用的完整提示词。
- `../../Resources/AppIcon.png`：1024 × 1024 透明 PNG，应用资源与尺寸导出的基准。
- `../../Resources/AppIcon.icns`：正式 macOS 图标包。
- `../../Resources/AppIcon.iconset/`：16–1024 像素各倍率资源。

运行 `./Scripts/build-icons.sh` 可从正式 PNG 重新导出全部 macOS 尺寸；`./Scripts/build.sh` 会自动调用它。菜单栏采用同构图的单色三窗标志，在浅色和深色菜单栏中由系统着色。
