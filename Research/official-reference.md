# Magnet 官方参考调查

调查日期：2026-10-15。仅使用开发者网站、Apple App Store 与 Apple 官方介绍；没有安装、购买或运行 Magnet。本报告用于行为重建，不能作为二进制逆向或像素一致性验证结果。

## 来源

- [Magnet 官网](https://magnet.crowdcafe.com/)
- [官方 FAQ](https://magnet.crowdcafe.com/faq.html)
- [Mac App Store 产品页](https://apps.apple.com/us/app/magnet/id441258766?mt=12)
- [Apple 官方使用介绍：Put windows in their places](https://apps.apple.com/sa/ipad/story/id1467789819)
- [Apple 元数据 API](https://itunes.apple.com/lookup?id=441258766)，核实版本和截图 URL。

## 官方确认的布局与交互

官网描述：通过拖动、可自定义快捷键和菜单栏操作；支持最大化、半屏、四分之一、三分之一，以及最多六台外接显示器。四角触发四分之一；侧边触发水平/垂直半屏；顶边最大化；横屏底边触发三分之一，沿边滑动扩展成三分之二。竖屏改为在侧边创建三分之一，四角及底边提供四分之一和半屏。[来源](https://magnet.crowdcafe.com/)

Apple 官方文章确认：窗口进入热点后先显示目标区域预览，松开鼠标后调整窗口；可以自定义或禁用快捷键；另有跨显示器移动、居中及恢复原位置的命令。[来源](https://apps.apple.com/sa/ipad/story/id1467789819)

## 当前 3.x 功能范围

当前官方展示版本为 3.0.7，发布日期 2025-04-12，最低 macOS 13。产品页列出：可选且可自定义的触发区、快捷键和绿色按钮菜单；可隐藏菜单栏图标；可选 iCloud 同步；自定义命令、布局属性和视觉配置。3.0.1/3.0.2 发布说明提到以 Swift 重写。[来源](https://apps.apple.com/us/app/magnet/id441258766?mt=12)

## 默认快捷键的证据边界

Apple 官方文章直接确认 `Control + Option + →` 把当前窗口放到右半屏。该一手资料没有列出全部默认键位，因此其余映射需要原版设置界面或运行验证，不能把常见第三方列表当成已核实的 3.0.7 默认值。[来源](https://apps.apple.com/sa/ipad/story/id1467789819)

## 官方截图链接

Apple 元数据 API 返回以下 3 张 3.0.7 宣传截图。链接已从 API 核实，尚未完成视觉逐项核对，因此暂不声称每张对应哪个设置页。

1. [3.0.7 官方截图 01](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/f3/77/bd/f377bd7b-83c4-cc4d-4f94-4a3a3826011d/3_0_7_GM_01.png/800x500bb.jpg)
2. [3.0.7 官方截图 02](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/e6/0b/e0/e60be063-1114-c6bc-6136-34bfe478076a/3_0_7_GM_02.png/800x500bb.jpg)
3. [3.0.7 官方截图 03](https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/b4/08/84/b4088488-4202-9236-bee4-8287c7cbcda5/3_0_7_GM_03.png/800x500bb.jpg)

Apple 官方文章还包含两个旧版操作/设置配图，不能用来保证 3.x 设置界面一致：

- [Apple 配图 A](https://is1-ssl.mzstatic.com/image/thumb/Features113/v4/f8/62/d9/f862d90e-1eaf-d75a-791c-2870a17f988e/pr_source.png/1275x797bb-60.jpg)
- [Apple 配图 B](https://is1-ssl.mzstatic.com/image/thumb/Features113/v4/ff/dd/88/ffdd8853-0342-18b6-0d9a-9c5b4af28b15/pr_source.png/1275x717bb-60.jpg)

官网布局示意是 SVG，适合核对触发区方向；它们不是应用截图：

- [四角和半屏示意](https://magnet.crowdcafe.com/imgs/design-4.svg)
- [最大化与三等分示意](https://magnet.crowdcafe.com/imgs/design-5.svg)
- [竖屏示意](https://magnet.crowdcafe.com/imgs/design-6.svg)

## 官方确认的限制

FAQ 表示依赖辅助功能授权；只能调整标准且可缩放的窗口，应用自身最小尺寸可能导致窗口宽于半屏；可操作当前活跃 Space 中的窗口，不能跨不同 Spaces 安排。[来源](https://magnet.crowdcafe.com/faq.html)

## 尚未验证

3.0.7 完整菜单顺序、所有默认快捷键、设置页精确布局、绿色按钮菜单触发方式、拖拽阈值与延迟、窗口间距默认值、重复命令行为、从吸附布局拖走时是否恢复、显示器排序/迁移策略、iCloud 数据结构和同步冲突处理。原版应用或用户截图到位后应逐项补证。

## 主代理补充：已视觉核对

已读取并保存三张官方商店宣传图（`official-01.png` 至 `official-03.png`）。第二张展示图标侧栏、命令列表、目标网格、快捷键和拖拽区域；第三张展示激活区域高亮、轮廓宽度、触发区宽度、绿色按钮延迟和间距等设置。截图中的品牌宣传及颜色处理不代表原版的所有运行状态。

本任务随后按用户明确要求改为参照官网与商店进行公开资料复刻，不要求购买或获取原版安装包。
