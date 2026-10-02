# 背包 UI 美术包 v001 · 只读接入审计

审计日期：2026-09-26。当前阶段：美术资源拆分，尚未接入游戏。

本报告依据当前工作区代码与数据静态核对；没有启动 Godot、Blender 或浏览器，没有通知“写godot具体代码”或其它项目对话框。本报告不代表新版美术已通过实机验收。资源最终文件路径、尺寸、透明与九宫格约定以本包 README/manifest 为准。

## 1. 当前入口和数据流

| 当前文件 | 已核实职责 |
| --- | --- |
| `game/app/main.gd` | 创建 `FoliageUI`，调用 `configure(registry.get_foliage_preview(), controller.is_interaction_open, style.theme)`；连接 `modal_changed` 来锁定角色输入与隐藏训练按钮。 |
| `game/presentation/foliage/foliage_ui.gd` | `open_page("inventory")` 打开背包；`_inventory()` 创建分类、网格、整理按钮与详情；`select_entry(id)` 更新选中项；`close_page()` 关闭。 |
| `game/data/manifest.json` | `foliage_preview_file` 显式指向 `res://data/shop/foliage_preview.json`。 |
| `game/data/shop/foliage_preview.json` | 独立 UI 样例目录，包含 `inventory`、`decoration`、`orders` 三个节。 |
| `game/content/shop_preview/shop_preview_loader.gd` | 加载与验证目录，发布 Registry。 |
| `game/content/shop_preview/foliage_preview_definition.gd` | 复制目录并将条目、数组、字典设为只读；`entries(section)` 返回对应只读样例。 |

背包快捷键为 InputMap 的 `ui_inventory`，当前物理键值 66 即 B；再次按 B 关闭。Esc 对应 `ui_cancel` 关闭当前页面。快捷键文字应继续从 InputMap 生成，不能烘焙在图片中。

`FoliageUI` 的 modal 根节点阻挡鼠标并关闭滚轮向父级传播。新版只替换美术时，要保留这一输入隔离和 `modal_changed` 生命周期，不能让点击物品或滚动背包穿透到店内移动/镜头操作。

## 2. 六种样例与本包图像的精确映射

以下 ID 只在 `foliage_preview.json.inventory` 的样例目录中成立，不是正式物品 Definition ID，也不是玩家持有的 instance ID。素材 stem 是美术包标识，不要据此重命名业务 ID。源 PNG 约定存于 `source_assets/ui/inventory/v001/exports/items/`；运行时副本约定存于 `game/assets/ui/inventory/v001/items/`。资源制作代理正在完成这些文件，最终可用状态由主任务的 manifest/验收报告确认。

| 样例 ID | 当前分类 | 名称键 / 描述键 | 当前图标 | 本包素材 stem |
| --- | --- | --- | --- | --- |
| `potion` | `potions` | `ui.item.potion` / `ui.item.potion_desc` | `res://assets/ui/foliage/potion.svg` | `potion_red` |
| `sword` | `equipment` | `ui.item.sword` / `ui.item.sword_desc` | `res://assets/ui/foliage/sword.svg` | `sword_iron` |
| `herb` | `materials` | `ui.item.herb` / `ui.item.herb_desc` | `res://assets/ui/foliage/leaf.svg` | `herb_sprig` |
| `crystal` | `materials` | `ui.item.crystal` / `ui.item.crystal_desc` | `res://assets/ui/foliage/crystal.svg` | `crystal_blue` |
| `scroll` | `materials` | `ui.item.scroll` / `ui.item.scroll_desc` | `res://assets/ui/foliage/scroll.svg` | `scroll_parchment` |
| `bag` | `equipment` | `ui.item.bag` / `ui.item.bag_desc` | `res://assets/ui/foliage/bag.svg` | `travel_pouch` |

后续 skin 的 Texture2D 映射路径约定为：

| 样例 ID | 引擎纹理路径 |
| --- | --- |
| `potion` | `res://assets/ui/inventory/v001/items/potion_red.png` |
| `sword` | `res://assets/ui/inventory/v001/items/sword_iron.png` |
| `herb` | `res://assets/ui/inventory/v001/items/herb_sprig.png` |
| `crystal` | `res://assets/ui/inventory/v001/items/crystal_blue.png` |
| `scroll` | `res://assets/ui/inventory/v001/items/scroll_parchment.png` |
| `bag` | `res://assets/ui/inventory/v001/items/travel_pouch.png` |

当前中英文名称分别为：

| ID | 中文 | English |
| --- | --- | --- |
| `potion` | 红色药剂 | Crimson potion |
| `sword` | 旅行短剑 | Traveler’s sword |
| `herb` | 芳香草叶 | Fragrant herbs |
| `crystal` | 蓝色晶簇 | Azure crystal |
| `scroll` | 旧卷轴 | Old scroll |
| `bag` | 旅行布袋 | Travel pouch |

`travel_pouch` 已约定采用棕色厚帆布主体与皮革袋口辅料，以符合当前“旅行布袋”的描述；早期工作名 `leather_pouch` 已撤回。`sword_iron` 的文件名不确立正式武器材质、攻击数值或装备规则；`potion_red` 不确立回血量或可使用能力。

## 3. PNG 图标接入的现有约束

不能只把 `foliage_preview.json` 的 `icon` 改成新 PNG 路径：

- `game/data/schemas/foliage_preview.schema.json` 要求 `^res://assets/ui/foliage/[a-z_]+\.svg$`。
- `game/content/shop_preview/shop_preview_loader.gd` 同时要求路径位于 `res://assets/ui/foliage/`、扩展名为 `.svg`，并校验 `ResourceLoader.exists`。
- `tools/content/build_shop_preview_content.py` 运行上述 schema 并检查文件存在。

**建议下次接入方式：**由独立表现 Resource（例如后续定义的 `InventorySkin`）持有 Texture2D 强引用，以及 `potion/sword/herb/crystal/scroll/bag` 到纹理的显式映射；背包表现消费注入的 skin。这样当前样例 JSON、公共 schema 与 Registry 无需因美术换皮改变。skin 名称与接口在本轮尚未实现。

不要覆盖 `game/assets/ui/foliage/leaf.svg` 或 `bag.svg` 等共享图标以实现背包换皮：同一 SVG 还被 HUD、分类、其它目录或操作按钮使用。若未来统一改成 AssetCatalog 资源 ID，需由整合者同时改契约、schema、运行时解码和内容，不应在本轮美术包里单独修改。

## 4. 按钮、状态与明确未开放的功能

| UI 元素 | 当前真实行为 | 新素材可替换的表现 |
| --- | --- | --- |
| 全部 / 装备 / 药剂 / 材料 | `filter_category()`；分类键精确为 `all/equipment/potions/materials`，自动选择筛选后的首项。 | 页签 normal / selected / hover / focus 外观；分类字样继续由 Label/Button 渲染。 |
| 物品格 | 点击 `select_entry(id)`，更新详情及 `button_pressed`；节点名为 `Item_<id>`，metadata 为 `entry_id`。 | 空格底、选中边框、悬停态与透明物品图分层。 |
| 整理 | `_sort_catalog()` 按当前语言的物品 tooltip 名称排序；只移动可见卡片顺序，不改变数据。 | 整理按钮底与图标。不要宣称自动堆叠、改变库存槽位或保存。 |
| 使用 | 当前 Button 禁用；回调无业务逻辑，tooltip 为 `ui.unavailable`。 | 可提供按钮底与 disabled 调制；仍应禁用。 |
| 移入仓库 | 当前 Button 禁用；没有仓库转移命令。 | 同上。 |
| 关闭 | `close_page()` 清空模式并发出 `modal_changed(false)`。 | 关闭图标与可见键位提示。 |
| 语言切换 | TranslationServer 切换中英后重建页面；保留 `_selected` ID 与分类。 | 不在 PNG 内嵌语言专属文字。 |

当前**未定义/未接入**：真实背包容量、堆叠数量、重量、金币、售价、稀有度、装备栏、拖放转移、拆分、丢弃、收藏、筛选搜索、使用物品、物品持久保存。概念图中的示例数字或彩色边框不能自动变成这些玩法能力。

`_fill_grid()` 在“全部”分类下将网格补足到 Theme 的 `columns × preview_rows`；当前为 5 × 3。空格是排版占位，代码已有明确注释，不等同于 15 格背包容量。素材拆分可提供更多空格图，但不得写死容量或伪造数量。

## 5. 双语与版式继承

- 人工文案源：`game/data/locales/zh_CN.json` 与 `game/data/locales/en.json`；生成文件 `game/generated/locales/*.po` 不手改。
- 现有关键文案：`ui.inventory`、`ui.preview`、`ui.sample_note`、`ui.all`、`ui.equipment`、`ui.potions`、`ui.materials`、`ui.sort`、`ui.use`、`ui.store`、`ui.unavailable`、`ui.empty`、`ui.select_item`、`shop.preview.close`。
- 当前背包底部明确显示 `ui.sample_note`：这些样例不代表已拥有物品。新的美术接入要保留这一语义。
- 字体沿用 `game/presentation/foliage/ui_typography.tres` 与 `res://assets/fonts/NotoSerifSC-VF.ttf`。Theme 通过 `foliage_theme_factory.gd` 复制基础主题后应用统一字体。
- 当前排版参数在 `foliage_theme.tres`：窗口 1000 × 590、详情宽 258、格子 94、网格图标 64、详情图标 110、列数 5、演示行数 3、margin 20。它们是既有表现值，不是对新包强制尺寸，也不是库存规则。
- 保持物品图长宽比；缩小到网格尺寸后仍须看清轮廓。叶饰与精细金边应独立叠加或保持固定角区，避免拉伸变形。
- 分层顺序建议：窗口底板 → 标题/分区底 → 物品格底 → 物品透明图 → hover/selected/focus 框 → 实时文字与数量（数量仅在未来真实状态提供后显示）→ 装饰叶片。叶片不遮挡文字和可点击区域。

## 6. 后续真正接入时的验收清单

本轮仅记录，尚未执行：

1. 在 1280 × 800 与 1920 × 1200 下查看中英文，分类、详情、关闭和禁用说明不截断；图片没有伪透明底、描边白边或九宫格角部拉伸。
2. 六个样例各自显示正确新图；筛选、选中、按本地化名称排序仍有效，切换语言不丢失当前选中 ID。
3. B/Esc、点击 UI、滚轮隔离和角色输入锁定保持；不能干扰委托板、真实装修模块、战斗或 HUD。
4. 使用/移仓保持未开放状态；不增加示例数量、余额、稀有度标签或伪造持久库存。
5. 新 PNG 必须使用引擎项目内的资源强引用；必要的导出资源与 alpha 导入验证在代码接入阶段进行。
6. 适配现有 `game/tests/foliage_ui.gd` 的背包与双语回归。现有测试会点击 `Item_crystal` 并检查 `_selected == "crystal"`，拆独立子面板时要协调更新测试入口。
7. 若只换表现 Resource，无须修改样例业务定义；若确需改 schema/locale/数据字段，先明确写入所有者并同步验证。

## 7. 本轮写入边界与验证说明

本审计任务仅创建本文件。其它项目代码、数据、公共契约、翻译、运行场景均未修改。检查方法为读取当前文件并交叉核对 ID、分类、路径、schema、加载器、按钮回调及翻译；未运行游戏，不宣称新版资源已集成。
