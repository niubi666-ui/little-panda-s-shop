# 交给“写godot具体代码”：装修 UI v001

## 目标

将本包树叶主题 UI 美术接入**实际家具摆放界面**，让界面接近用户参考图。用户授权了此接入任务；素材准备完成后由美术任务发消息启动。

- 工程：`E:/ShopGame`，Godot 根：`E:/ShopGame/game`。
- 采用版本：`source_assets/ui/decoration/v001`，运行副本 `game/assets/ui/decoration/v001`。
- 首读：`PROJECT_CONTRACT.md`、本包 `README.md`、`reports/integration_audit.md`、`manifest.json`、`docs/SHOP_DECORATING.md`。
- 预览：本包 `previews/index.html`、`previews/layout_preview.html`；用户参考 `reference/decoration_reference.png`。

## 应实现的表现

1. 左侧目录改为有透明家具缩略图的双列卡片，有清楚的 hover、选中、键盘 focus；显示真实目录名称与当前选中详情。
2. 深绿金边背景、分类页签、独立叶片、顶部模式标题、底部主要 / 次要按钮分层拼装，不使用参考整屏截图作为界面。
3. 四种真实家具映射：`barrel→barrel.png`、`scroll_bin→scroll_bin.png`、`supply_crate→supply_crate.png`、`chest→storage_chest.png`。其他五张是备用美术，不新增可摆放定义。
4. 保留旋转、取消预览、移除、完成的真实语义；通过已有本地信号连接。外观和缩略图路径集中在表现 Resource。选中 ID 从 app 显式注入，包含点击已放家具进入移动的情况。
5. 将浮动提示 / 按钮文案与真实输入保持一致；当前 R 是装修开关，不能伪标成旋转。保持既有映射即可，不必本轮改 project.godot。
6. 保留原型说明：临时布局、没有库存消费 / 保存。不要显示假拥有数量 / 余额，取消预览不叫撤销。没有内容的装饰 / 灯具分类用清楚的空态或禁用状态。
7. 中文 / 英文都正常；Label / Button 实时本地化，不烘焙文本。1280×800 与 1920×1200 可读、不遮住过多场景；空白场景区域可点击摆放和缩放。

## 原接口与边界

现有 `decorating_panel.gd` 的 signals：`furniture_chosen(id)`、`rotate_requested`、`remove_requested`、`cancel_requested`、`done_requested`；`configure(catalog, settings, shared_theme)` 与 `refresh(pending, moving, code, count)`。可以为当前选中 ID 增加明确表现入口并同步调用者，不让 UI 读取 app 私有变量。

不要改旧 foliage 样例页冒充实际接入。不要变更玩法占地、实例上限、场景模型或装修规则，仅用 `catalog.json` 的权威值。

## 写入范围与协作

美术任务本轮只新增 `source_assets/ui/decoration/v001/**`、`game/assets/ui/decoration/v001/**`，并为 `source_assets/ui/README.md` 增加索引。不修改 app、schema、project.godot、根场景、战斗、翻译或共享契约。

交接后美术目录和运行图片结束写入；代码任务可读取并添加表现资源 / 场景引用。推荐代码写入范围：`game/presentation/decorating/**`、必要的 `game/app/shop_decoration.gd`、装修人工翻译 JSON 与对应生成输出、匹配的 UI 测试、`docs/SHOP_DECORATING.md`。若需公共契约或字段变更，由你作为整合者统一更新。

本任务与已完成的刀光切换 UI 无关联。不要修改 `combat_training.gd`、战斗 HUD、`effect_picker`、`combat.fx` 翻译或刀光资源。

本轮未启动 Godot / Blender，也没有持有引擎进程；网页预览仅用于美术审阅。当前其他进程是否运行需接入者自行确认，不要结束用户原有进程。

## 验收

- 素材已由本包脚本检查 RGBA、透明外边缘、选中圈透明中心、源 / 运行副本哈希；最终报告记录在 `reports/asset_validation.json`。
- 接入方执行有关内容 / 翻译生成检查及装修规则 / 场景测试，勿手改 PO。
- Godot 图形实测两种分辨率、中英切换、四种家具选择、已放家具移动、旋转、取消、移除、完成；UI 不穿透，场景区域不被透明装饰阻挡。
- 检查缩略图不拉伸不切边、选中框与卡片对齐、背景九宫格边角不变形；记录真实实机截图。
- 对用户报告已接入部分和原型限制；网页拼装图、PNG 本身不作为玩法功能通过证据。

## 已知限制

家具图是统一画风的 AI 概念缩略图，非模型精确渲染。个别图透明留白不同，以完整等比居中加内边距处理。美术包只提供基础按钮图和独立选中圈，其余状态由 Theme 实现。最终 Godot 布局需要按窗口和语言校准。

网页自动打开被浏览器 URL 安全策略阻止，未通过浏览器截图 / 点击验收；不要将 HTML 示意当成已验证界面，也不要通过替换浏览器或本地服务绕过该安全限制。源 PNG 检查与 Godot 中的实际素材接入是本任务的交付依据，代码方正常开展已授权的 Godot UI 工作即可。
