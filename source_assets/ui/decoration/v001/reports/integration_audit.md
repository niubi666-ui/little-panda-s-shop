# 装修 UI 接入审计

日期：2026-09-26。只读检查当前项目文件；本报告未运行 Godot / Blender，未修改游戏代码。实际运行状态应由接入任务复验。以下所有相对路径均相对 `E:/ShopGame/`。

## 1. 应改哪个界面

实际家具摆放 UI 是 `game/presentation/decorating/decorating_panel.gd`，由 `game/app/shop_decoration.gd` 在 `open()` 时创建。它当前只有左侧滚动列表、文字按钮、计数和状态提示，没有家具图片。

`game/presentation/foliage/foliage_ui.gd` 中仍有 `_decoration()` 老样例页面，但主入口由 `attach_decoration(decorating.open)` 接管，走真正的摆放模块。不要只替换旧样例页而遗漏实际运行界面。

相关现有文件：

- 组装：`game/app/main.gd`，注入店铺、玩家、相机、UIRoot 和统一 Theme。
- 应用与输入：`game/app/shop_decoration.gd`。
- UI：`game/presentation/decorating/decorating_panel.gd`。
- 表现设置：`game/presentation/decorating/decorating_style.gd`、`decorating_style.tres`。
- 几何与模型适配：`placement_geometry.gd`、`furniture_view_factory.gd`，同目录。
- 临时布局与规则：`game/shop/decorating/{decoration_session,layout_rules}.gd`。
- 数据：`game/data/shop/decorating/catalog.json`。
- 定义与解码：`game/content/decorating/{decorating_catalog,decorating_loader}.gd`。Furniture 为 catalog 脚本内嵌类，并非独立文件。
- 说明与验收记录：`docs/SHOP_DECORATING.md`。

## 2. 已有家具精确映射

四个家具 ID 均来自实际目录，并非概念 UI 中的样例列表。`asset_id` 当前与 `id` 相同。模型源节点相对 `game/shop/scenes/shop_interior.tscn` 根节点。

| 实际 id / asset_id | 名称 key | 中 / 英名称 | 占格 | 完整模型根节点 |
|---|---|---|---|---|
| `barrel` | `decor.item.barrel` | 小木桶 / Small barrel | 3×3 | `Furnishings/rear_small_barrel` |
| `scroll_bin` | `decor.item.scroll_bin` | 卷轴桶 / Scroll bin | 3×3 | `Furnishings/rear_scroll_bin` |
| `supply_crate` | `decor.item.supply_crate` | 药罐货箱 / Crate with jar | 3×3 | `Furnishings/rear_supply_crate` |
| `chest` | `decor.item.chest` | 宝箱 / Treasure chest | 4×5 | `Furnishings/right_treasure_chest` |

网格为 0.25 米，最多 20 个新增实例，权威来源只有 `catalog.json`。UI 不应重新抄写占格、网格大小或上限。

`supply_crate` 是完整木箱 + 药罐组合，药罐为它的子节点；图标不要画成独立小药瓶。当前工厂复制完整根节点，包含碰撞及宝箱的交互标记。

**建议资产接入表**（实际文件是否完成，以本资产包最终 manifest / README 为准）：

| 实际目录 ID | 本次推荐缩略图名 | 状态含义 |
|---|---|---|
| `barrel` | `barrel.png` | 实际可摆放家具的概念缩略图 |
| `scroll_bin` | `scroll_bin.png` | 同上 |
| `supply_crate` | `supply_crate.png` | 同上 |
| `chest` | `storage_chest.png` | `storage_chest` 仅资产文件名；UI 点击仍发送 `chest` |

其他新图标（如 `chair_oak`、`bookshelf_potions`、`potted_fern`、`rug_crimson`、`wall_lantern`）是美术备用，并没有对应可摆放定义。不要仅因图标存在便给玩家可点击的摆放入口。新增内容需实际模型、占格、规则适配和双语名称一起通过校验。

## 3. 旧概念 UI 的分类不能当作实际目录

`game/data/shop/foliage_preview.json` 的 decoration 数组是样例：

| 样例 id | 样例 category | 旧图标 |
|---|---|---|
| `cabinet` | `furniture` | `res://assets/ui/foliage/cabinet.svg` |
| `chest` | `furniture` | `res://assets/ui/foliage/chest.svg` |
| `herb` | `ornaments` | `res://assets/ui/foliage/leaf.svg` |
| `rug` | `ornaments` | `res://assets/ui/foliage/rug.svg` |
| `lamp` | `lights` | `res://assets/ui/foliage/lamp.svg` |

实际四种家具没有 category、description_key、thumbnail、owned_count 或 price 字段。实际 schema `game/data/schemas/decorating.schema.json` 使用 `additionalProperties: false`；不能直接往 JSON 塞字段而不更新 schema / loader / Definition。

建议第一轮四种实际家具归入“家具”页签；“装饰 / 灯具”页签可有明确空态或暂不开放。纯 UI 图标与分组可由独立表现 Resource 以稳定 ID 映射；若以后分类参与商店/解锁等业务，再由整合者设计内容字段。不要重复建立有数量和价格的伪库存。

## 4. 已有公共表现接口

`decorating_panel.gd` 当前接口：

```gdscript
signal furniture_chosen(id: String)
signal rotate_requested
signal remove_requested
signal cancel_requested
signal done_requested

func configure(catalog, settings, shared_theme: Theme) -> void
func refresh(pending: bool, moving: bool, code: String, count: int) -> void
```

应用层分别连接到 `_begin_add`、`_rotate`、`_remove`、`_cancel_preview`、`close`。重做图片 UI 应保留这些信号含义。

`refresh()` 没有传入当前家具 ID，UI 目前也不显示选中详情。若需持续高亮卡片和显示详情，建议应用层通过明确的方法或新增参数注入选中 ID；尤其点击已放置模型进入移动时，也应刷新选中家具。不让 UI 通过父级或节点路径读取 app 的 `_pending`。

现有按钮使能规则：

- 旋转、取消：只有 pending 时启用。
- 移除：只有正在移动已放置实例时启用。
- 完成：退出装修模式，并取消未提交预览。

状态 `code` 对应 `decor.<code>` 翻译：idle、ok、invalid、out_of_bounds、blocked、occupied、access_blocked、limit、stale、applied、removed、scene_unavailable。

## 5. 参考图与现有能力的差异

- 参考图的“拥有 2”、金币“1,280”没有可用权威数据。当前家具无限试摆，只有总实例上限；不要把概念数字显示成真实拥有数量或余额。
- 参考图的“撤销”尚未实现。`cancel_requested` 只取消当前预览，不能撤回已提交摆放。可复用相应按钮外观，但文本应为“取消预览”；若要真正撤销，需单独实现状态历史与规则校验。
- 参考图的“R 旋转”与现有键位冲突：`game/project.godot` 的 `ui_decoration` 为 R，当前进入/退出装修；旋转仅由 UI 按钮触发。不得在图里烘焙 R 旋转提示。若接入者改变键位，需协调 InputMap、帮助文本和相关测试。
- 原始店铺陈设仍固定；仅本模块新增的 4 种实例可移动/移除。
- 不支持墙面挂件、桌面叠放、多层楼面和任意角度旋转；壁灯与地毯的额外摆放规则不能仅靠更换缩略图实现。
- 当前布局仅保留到离开店铺场景，不写磁盘、不消耗库存。必须保留用户可见的原型说明。
- UI 皮肤不应修改战斗 HUD、刀光切换、战斗输入；本任务与已完成的 combat effect_picker 无交叉。

## 6. 图片布局与输入注意点

- 背板、树叶、按钮、卡片、图标应独立；所有文本和数值由 Godot Label / Button 绘制，使用翻译 key。不要使用参考整屏图作为底图。
- 大背景、叶片和边框 TextureRect 的 mouse_filter 应为 IGNORE。当前 app 的 `_ui_hovered()` 用 `gui_get_hovered_control() != null` 判断，若全屏透明 Control 拦鼠标，会导致无法在地面摆放。
- 只有侧栏、实际按钮等交互区截获鼠标；滚动列表要保留滚轮行为，场景空白处仍可缩放镜头。
- 页签 / 可伸缩底板宜采用九宫格；角落叶片不要随长边拉伸。图标建议完整适应矩形，保持比例与透明边距。
- 现有 sidebar_width=300、margin=16、gap=10 存于 decorating_style.tres，属于可调整表现参数。新尺寸、颜色、贴图引用仍由 Resource 管理，不把布局常量散入逻辑。
- 英文长度通常更长；1280×800 下需实际检查双栏卡片、底部按钮与提示是否截断。

## 7. 双语与字体

人工源：`game/data/locales/decorating/zh_CN.json` 和 `en.json`，目前 24 对 key。生成输出：`game/generated/locales/decorating/{zh_CN,en}.po`，不能手工修改。

已有通用分类 key 在 `game/data/locales/{zh_CN,en}.json`：`ui.all`、`ui.furniture`、`ui.ornaments`、`ui.lights`、`ui.decoration`。可按语义复用；新提示/空态请添加人工源并运行生成器。

字体沿用 `game/presentation/foliage/ui_typography.tres` 与 `res://assets/fonts/NotoSerifSC-VF.ttf`。当前正文/按钮 19，标题 29，详情标题 22，辅助 16；这些是表现配置，接入时按版式验证，不将图片中的拟造文字当字体资产。

## 8. 最少验证建议

现有 `docs/SHOP_DECORATING.md` 记录旧实现已通过的验证，本次仅静态审计，不能据此声称新 UI 已通过。

接入任务应运行：

1. `tools/content/build_shop_preview_content.py --check` 与 `tools/content/build_decorating_content.py --check`（由项目 Python 环境执行）。
2. `game/tests/shop_decorating.gd`：四种家具、模式隔离、移动/旋转/取消/移除、宝箱交互身份、双语。现有测试读取 `_panel._status`；若 UI 重构该字段，要合理更新测试观察点。
3. `game/tests/foliage_ui.gd` 回归背包/委托/装修入口，确认旧页面未误替换。
4. 图形实机：1280×800 与至少一套更宽窗口；中英文；点击卡片、地面、旋转、取消、移除、完成；非 UI 区域仍能摆放，UI 区域不穿透。
5. 验证纹理存在、alpha 正确、导入无丢图；缩略图全显示且比例不变，选中/悬停/禁用状态可辨认。

本审计只新增此报告。未改游戏代码、内容、共享契约、project.godot；未启动引擎进程。
