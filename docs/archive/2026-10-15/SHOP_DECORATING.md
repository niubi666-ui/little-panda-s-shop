# 店内家具摆放原型

更新：2026-09-28。店内独立装修模块；当前API、临时状态与美术入口如下。

## 当前范围与操作

- 在店铺按 **R** 或点击装修入口，进入摆放模式；角色暂停移动，镜头切换为店铺概览，支持滚轮缩放。
- 目录提供小木桶、卷轴桶、药罐货箱和宝箱，复用店铺已有完整模型组。点击目录生成预览，移动鼠标选择位置，左键确认。
- 默认 **0.25 米网格吸附**；点击“旋转 90°”改变朝向，矩形占格随朝向交换长宽。
- 绿色预览表示当前规则允许，红色表示越界、重叠或阻断必要通路。侧栏显示原因。
- 点击本原型添加的家具可移动、旋转或移除。取消移动保留原位置；右键/Esc 取消预览，再按一次退出；“完成摆放”或 R 退出。
- 新宝箱复制原模型的碰撞和交互点，赋予新的实例身份，退出装修后沿用靠近按 F 的占位交互。
- 界面支持中文、英文，继承项目统一 Theme 和字体配置。

**本轮边界：**原始店铺家具仍是固定陈设；仅新增的四种原型家具可编辑。没有购买、消耗、解锁或装修存档。布局在关闭装修界面后保留，离开当前店铺场景后丢弃。UI 明确显示此限制。当前不支持墙面挂件、桌面叠放、多层楼面和自由角度旋转。

## 模块边界

| 层 | 文件/目录 | 责任 |
|---|---|---|
| 内容 | `game/content/decorating/` | 校验 JSON、创建只读接口的 Catalog/Furniture Definition |
| 规则 | `game/shop/decorating/layout_rules.gd` | 整数网格、旋转占格、越界/重叠、必要通路可达性 |
| 临时状态 | `game/shop/decorating/decoration_session.gd` | 持有本店铺场景的临时布局、实例 ID、修订号，确认时提交隔离候选 |
| 应用协调 | `game/app/shop_decoration.gd` | 连接输入、预览、规则、临时状态、家具实例、交互注册及模式切换 |
| 场景适配 | `game/presentation/decorating/placement_geometry.gd` | 将当前店铺碰撞、玩家尺寸、交互锚点转换为一次性网格快照 |
| 模型适配 | `game/presentation/decorating/furniture_view_factory.gd` | 复制完整模型组、更新变换/实例身份、预览材质、收集交互标记 |
| 界面 | `game/presentation/decorating/decorating_panel.gd` | 目录、操作按钮、原因提示、中英文刷新 |
| 装修皮肤 | `game/presentation/decorating/decorating_ui_skin.gd/.tres` | v001 分层图片、图标、颜色、九宫格样式与布局参数 |
| 皮肤适配 | `game/presentation/decorating/decorating_theme_factory.gd` | 打开界面时创建局部九宫格表现资源，保护原图边角，不修改共享 Theme |

组装由 `main.gd` 注入场景、玩家、相机、控制器、UI 容器与主题。FoliageUI 通过注入的 Callable 打开模块；模块通过局部 `mode_changed` 信号协调移动锁定、HUD 显隐与镜头。不导入战斗模块，不改变战斗动作或输入映射。

规则不读取 JSON、不访问节点、不操作存档。运行时只在初始化读取配置，鼠标预览使用已注入的 Definition 和布局快照。

## 配置权威来源

| 内容 | 唯一来源 |
|---|---|
| 网格尺寸、最多新增数量、家具 ID、占格、资源 ID | `game/data/shop/decorating/catalog.json` |
| 内容结构校验 | `game/data/schemas/decorating.schema.json` |
| 模型来源 NodePath、场景楼面区域、镜头、3D 预览材质 | `game/presentation/decorating/decorating_style.tres` |
| 装修 UI 贴图、九宫格、布局尺寸、配色 | `game/presentation/decorating/decorating_ui_skin.tres`，由上方 style 的 ui_skin 引用 |
| 原模型、碰撞代理、交互标记 | `game/shop/scenes/shop_interior.tscn` |
| 角色通行尺寸 | `game/presentation/red_panda_preview.tscn` 的 Body 胶囊体 |
| 中英文人工文案 | `game/data/locales/decorating/{zh_CN,en}.json` |
| 生成翻译 | `game/generated/locales/decorating/{zh_CN,en}.po`，禁止手改 |

装修目录路径由既有 `shop_preview.json` 的 `decorating_file` 提供。目录经过校验后解码，再注入模块；未修改公共 manifest。家具业务占格来自 JSON，不能以网格模型包围盒或碰撞代理自动替代。更换模型需同时检查其实际尺寸能否被已声明占格容纳。

## 临时布局契约

布局记录由稳定的 `instance_id`、`definition_id`、整数 `cell: Vector2i`、`quarter_turn: int` 组成；运行时加入从 Definition 解码的 `footprint: Vector2i`。`cell` 表示旋转后占格矩形的最小角，模型放在矩形中心；`quarter_turn` 为 0–3。

- `preview(candidate, moving)` 只返回校验结果，不改变权威布局。
- `apply(candidate, moving, expected_revision)` 再次校验与检查修订号，通过后发布完整隔离副本。新实例 ID 由会话签发；移动必须指向已有实例，不能偷偷替换家具定义。
- `remove(id, expected_revision)` 检查修订号后提交新的布局副本。
- `snapshot()` / `find(id)` 返回深复制；外部不能通过它们修改内部数组。
- 状态码：`ok`、`invalid`、`out_of_bounds`、`blocked`、`occupied`、`access_blocked`、`limit`、`stale`；应用层另返回 `applied` / `removed`。

预览模型没有碰撞和灯光，不影响角色或权威家具。移动期间原件保留，确认后同步布局对应的模型；取消只删除预览。模型层通过已有 `register_target` / `unregister_target` 接口同步交互点。实例元数据重新分配，避免复制宝箱继承原件交互身份。

这个临时 `decoration_session.gd` **不是持久 SessionCoordinator**。未来接入正式家具库存、金币或布局保存时：规则返回候选布局 → app 组织跨模块用例 → 持久会话以隔离候选状态校验库存及保存 → 成功后发布状态并更新表现。不能在按钮或模型工厂内直接写存档，不能保存 Node 引用。

## 通路校验

进入装修时读取当前店铺固定分组的碰撞，分别形成占格阻挡与按角色半径扩展的通行阻挡。地板以及高于角色的碰撞不作为地面障碍；当前适配器只支持固定的 BoxShape3D，未知类型明确报告错误。

保护点包括当前玩家位置、出生点、原有九件可交互家具的接近点，以及柜台的多个接近锚点（含背后和两端）。每次候选摆放将新家具占格按角色净空扩展，以四邻接搜索检查保护点仍可达。必须保留柜台后方通道，不能只验证柜台正面。

该原型使用保守的矩形网格通行近似；不是完整导航烘焙。新增宝箱已注册交互，但还未把每件新增家具独立的使用面纳入专用接近点规则。正式零售柜、门、工作台应配置各自使用面、入口区与通行要求。若当前玩家站在网格近障碍边缘，进入模式可能校验失败，退出并移动至开阔地面后重试。

## 扩展顺序

1. 在已通过基础实机验收的原型上，由玩家体验网格粒度、旋转操作、预览清晰度与通路限制，确定后续调整。
2. 把可移动原始家具迁移为正式家具实例；单独保留固定墙体/附属物。提供有版本的初始布局，避免复制与迁移时重复生成。
3. 为交互家具定义旋转后的使用面与门口净空；再扩展墙面、桌面挂点等不同摆放表面。
4. 接入库存、购买及持久会话提交，再实现布局存档/迁移和保存失败回滚；此时扩大家具目录。

新增同类地面家具通常只需：加入 JSON 定义、资源映射和中英文名称，确认根节点完整携带模型/碰撞/交互，运行内容与几何检查。新增规则字段或摆放表面时应先更新本契约与 schema。

## 装修美术 UI v001 接入

2026-09-26 已把 `source_assets/ui/decoration/v001` 的美术资源接入真正的 `decorating_panel.gd`，由 `ShopDecoration.open()` 创建。运行图片来自 `game/assets/ui/decoration/v001`。旧 FoliageUI 样例目录和战斗 UI 均未修改。

- 左侧双列家具卡片、悬停/键盘焦点/选中描边、名称与占格详情。
- 顶部模式标题与语言入口，底部旋转、取消预览、移除、完成，以及实际状态/按键提示。R 仍是装修开关；快捷键文字从 InputMap 读取。
- 家具分类只包含已实现的四种；装饰、灯具展示未开放空态。未把备用椅子、盆栽、地毯、书架、壁灯图加入玩法目录。
- 无虚构库存、金币、价格或撤销历史；完成退出会取消未提交的预览。原型说明保留，布局仍只属于当前店铺场景。
- 家具图是概念缩略图，并非当前模型的精确渲染。映射为 barrel/scroll_bin/supply_crate/chest，最后一项使用 `storage_chest.png`。

`decorating_style.tres` 通过 `ui_skin` 注入独立皮肤。新增皮肤资源是 UI 纹理、布局尺寸和配色的权威来源；原有 style 仅保留场景/模型/镜头/3D 预览配置。字体和字号继续继承统一 `ui_typography.tres`。源 PNG 不裁写；Chrome 用 AtlasTexture 排除透明外边距，打开时按 Resource 指定尺寸制作局部九宫格纹理；缩略图保持完整等比适应。

表现接口新增 `set_selection(id: String)`，空字符串表示无当前预览。app 在开始添加/场景模型点选/预览刷新时明确注入，取消或提交后清空；UI 不读取 app 私有状态。原五个局部 signals 与 `configure` / `refresh` 语义不变。打开已有临时布局时刷新真实实例计数。

全屏根节点、图片、叶片、文字提示使用鼠标 IGNORE；实际侧栏/按钮处理 GUI 输入，场景区域仍可点击落位。选择未开放分类只切换显示，不创建家具定义。


## 验证

按 [验证索引](VALIDATION.md) 运行装修内容检查、`decorating_rules.gd`、`shop_decorating.gd`，UI改动再运行 `decorating_ui.gd` 和相关店铺回归。历史已覆盖1280×800/1920×1200双语、实际鼠标选择/旋转/落位/移动/取消/移除、输入隔离与通路拒绝。未知任意布局的连续实走、新家具专用使用面与正式存档不在已完成范围。旧逐轮记录在归档。
