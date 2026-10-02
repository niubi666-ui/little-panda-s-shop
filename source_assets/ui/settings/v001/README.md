# 设置 UI：树叶风格 v001

**已被 v002 完整设置菜单设计取代。** 用户指出本版只像操作帮助页，缺少音量、画面、存档和退出操作。最新入口为 `../v002/README.md`；本版仅保留作为操作指南与素材来源。

## 交付

- 完整设计概念：`reference/settings_concept.png`。
- 独立资源：`exports/chrome/` 下 9 张透明 PNG；`exports/icons/` 下 7 个 SVG。
- 素材浏览：`previews/index.html`；可切换中英文的拼装示意：`previews/layout_preview.html`。
- 引擎副本：`E:/ShopGame/game/assets/ui/settings/v001/`，对应 `res://assets/ui/settings/v001/`。
- 图像尺寸、alpha 范围、Atlas 区域、来源、SHA256：`manifest.json`。
- 实际检查：`reports/asset_validation.json`。

本轮是美术与交接包，没有修改设置菜单逻辑，也没有通知其他对话框。完整概念图由内置 imagegen 生成；无字羊皮纸与键帽分别生成，其他框体复用项目已建立的背包视觉资源；不是从带字概念图直接裁取，因此细节会有差别。原始 PNG 保持字节不变，未重绘或抠图。提示词见 `generation/prompts.json`。

## 元素索引

| 文件 | 用途 |
| --- | --- |
| chrome/window_panel.png | 深森林绿主面板，复用背包 |
| chrome/controls_parchment.png | 新生成的横向操作指南羊皮纸 |
| chrome/keycap.png | 新生成的空白键帽；字母由代码渲染 |
| chrome/tab_regular.png | 未选中的语言选项 |
| chrome/tab_selected.png | 已选中的语言选项 |
| chrome/button_primary.png | 返回游戏主按钮 |
| chrome/button_secondary.png | 后续需要时使用的次级按钮 |
| chrome/close_socket.png | 关闭按钮底板 |
| chrome/header_leaf_sprig.png | 可独立摆放的标题叶饰 |
| icons/close.svg | 关闭符号，复用背包 |
| icons/divider_gold.svg | 深色底上的金色分隔线 |
| icons/divider_ink.svg | 羊皮纸上的墨色分隔线 |
| icons/language.svg | 语言图标 |
| icons/mouse_wheel.svg | 鼠标滚轮图标 |
| icons/control_row.svg | 操作说明行的细边框 |
| icons/focus_ring.svg | 键盘焦点提示，独立叠加 |

## 设计取舍

缩减原菜单的大块空白，用语言选择行和操作指南两级组织。指南使用两列三行：移动、互动、缩放、背包、订单、装修。概念图的六项次序按行读取；实现时由现有 InputMap 获取实际按键，不把图片中的字母当成配置来源。W/A/S/D 作为多个键帽显示。

已读取现有 `game/data/locales/zh_CN.json`：`ui.settings_note` 说明语言设置本次运行后不保存。概念图为了视觉简洁仅显示“立即生效”，实际拼装预览与后续接入应保留完整限制，不暗示已有持久化。没有新增音频、画质、键位重绑定或自动保存能力。

## Godot 拼装交接

1. 背景遮罩使用 ColorRect；不要把商店场景烘焙进设置窗口。
2. 按 `manifest.json` 的 `atlas_region_xywh` 建 AtlasTexture，去掉透明外边距。透明边缘可能有细小半透明像素；显式设置容器内距，不用图片原始画布直接推断点击区域。
3. 主面板、羊皮纸、语言按钮、键帽、文字与图标各用独立节点。复杂角落叶饰不应随九宫格中心拉伸：优先保持面板比例，或把角饰区域保留在固定切片中；切线需在目标分辨率实测，清单没有声称已经验证九宫格参数。
4. 标题、行标题、语言标签、按钮、提示文字全部使用翻译 key。沿用项目 Noto Serif SC 字体和统一主题。英文至少预留 30% 扩展空间。
5. 1200×800 为 HTML 美术预览基准，实际菜单用容器适配屏幕，窄屏时单列/滚动，不能把示意坐标当成固定运行布局。
6. 语言按钮应分别表示简体中文与 English，不用同一个“中文 / EN”文本模糊当前选项。已选中底板、悬停和键盘焦点是不同状态；hover 可温和提亮，focus 用独立虚线环。键帽只是说明，不自动变成重绑定按钮。
7. 关闭与返回游戏沿用已有关闭设置行为，Esc 同步；菜单期间隔离角色输入。不要把装饰图设置为抢占输入的节点。

## 验证边界

9 张 PNG 均为 RGBA 且具有透明像素；7 个 SVG 已通过 XML 解析；源文件与引擎副本哈希一致。没有修改字体或图片像素。

内置浏览器因 file:// 协议安全策略拒绝打开本地 HTML；未采用替代通道绕过。因此 HTML 已生成但没有浏览器视觉/交互验收，也没有 Godot 中的缩放、双语、焦点和输入验证。资源文件存在不代表当前游戏已经换用新 UI。
