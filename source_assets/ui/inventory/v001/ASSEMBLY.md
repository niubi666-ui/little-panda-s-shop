# 背包 UI v001 · 分层装配说明

本文件供后续获准接入时参考。本轮仅制作与归档美术，没有实现新的背包面板，也不向其它项目对话框发送接入任务。

## 1. 总体布局

以 [拼装示意](previews/layout_preview.html) 和 [参考图](reference/inventory_reference.png) 为视觉方向：深绿色主面板包住左侧物品区和右侧羊皮纸详情区，金色细边、暖白文字及局部叶饰延续委托板与装修 UI。

建议从以下层次组装，具体节点名称与类名尚未实现：

1. 页面遮罩与输入隔离层。
2. `window_panel.png` 主底板。
3. 标题、`title_bag.svg`、独立 `header_leaf_sprig.png` 和关闭按钮。
4. 全部 / 装备 / 药剂 / 材料四分类页签。
5. 左侧物品格网格与整理按钮。
6. 右侧 `details_parchment.png`、物品大图、名称、说明与两个禁用操作按钮。
7. 底部样例说明。所有文案均为实时控件文字。

HTML 示意使用 5 列 × 3 行排列，空格仅用于确认美术节奏，**不定义背包容量**。本包不引入装备栏、角色纸娃娃、重量、金币数或稀有度体系。

## 2. 透明边距与 AtlasTexture

PNG 保留 image_gen 原始输出，周围透明留白宽度可能不同。先读取 [manifest.json](manifest.json) 中每项的：

| 字段 | 含义 |
| --- | --- |
| `size_px` | 原始 PNG 画布宽高 |
| `alpha_gt_4_bbox_xywh` | alpha 大于 4 的可见范围，用于检查画布占比 |
| `atlas_region_xywh` | 在该范围四周保留最多 8 像素安全边距的建议区域 |
| `center_alpha` | 原画布中心透明度；选中框须为 0 |
| `runtime_path` | `res://` 纹理路径 |

后续可用 `AtlasTexture` 包装原 PNG，把 `atlas_region_xywh` 转成 region，减少各图透明边距对布局的影响。**该区域是静态 alpha 算出的初始建议，不是经过 Godot 校准的最终裁切**：柔和光晕尾部可能低于阈值，运行时要检查是否需要保留更大安全边距。

AtlasTexture 不会修改源 PNG，也不意味着要把全部资源合并为一张大图集。小物品可保留原图或使用各自区域，使用保持长宽比的显示方式，不把剑、药瓶或卷轴强行拉成正方形。

## 3. 九宫格与固定装饰

`window_panel`、`details_parchment`、`slot_regular`、页签和按钮底板适合作为 `StyleBoxTexture` / `NinePatchRect` 的候选。纹理切线、内容边距、最终显示尺寸应写入表现 Resource 并在后续 Godot 中校准，本包不提供声称已验证的固定切线值。

- 先应用 Atlas 区域，再根据这一裁切后的纹理计算切线；不要把原画布边距直接当作九宫格边距。
- 保留四角细边和刻纹，只拉伸中部及边的平直部分；注意过度缩小时两侧装饰重叠。
- 羊皮纸中心纹理被拉伸后需检查质感；必要时固定详情区纵横比或把装饰角与底纹分离。
- 叶枝、物品图、关闭符号、标题图标保持长宽比，不做九宫格拉伸。
- `slot_selected.png` 是中心透明的金边叠加层。按常态格子的实际外框对齐；两张图的 alpha 包围盒可能不同，不应只按同一画布尺寸缩放后假定必然重合。
- 选中框叠加节点与叶饰的鼠标过滤应为 IGNORE，点击由实际 Button 承接。
- 当前仅交付 normal/selected 图，hover、pressed、disabled 和键盘 focus 需由后续 Theme/表现配置补全或调制，不能把缺失状态误报为已生成的 PNG。

## 4. 各组件的装配关系

| 部位 | 图层顺序与用途 |
| --- | --- |
| 标题 | 深绿主面板 → `title_bag.svg` / `header_leaf_sprig.png` → 本地化“背包”标题；叶饰保持独立。 |
| 分类 | `tab_regular.png` 或 `tab_selected.png` → 分类文字；使用同一组点击控件，不把字放进图片。 |
| 物品格 | `slot_regular.png` → 物品透明 PNG → 选中时叠 `slot_selected.png`；空格可用 `empty_slot_mark.svg`。 |
| 详情 | `details_parchment.png` → 物品大图 → 名称/说明 → `divider_ink.svg` → 操作区。 |
| 操作 | `button_primary.png` + `action_use.svg` + “使用”；`button_secondary.png` + `action_store.svg` + “移入仓库”。两者当前保持禁用。 |
| 整理 | 可复用次按钮底与 `action_sort.svg`，行为仍是当前可见样例按名称排序。 |
| 关闭 | `close_socket.png` → `close.svg`；点击区由真实 Button 决定，不使用装饰图的透明轮廓作为唯一命中区。 |
| 分隔线 | 深底用 `divider_gold.svg`，纸底用 `divider_ink.svg`；保持足够的文字间距。 |

`quantity_badge.svg`、`title_coin.svg` 和五色 `marker_*.svg` 是可选素材，本轮布局不应给它们配虚构的数量、价格、金币或稀有度文案。后续真实状态提供数据后，才由 Label 显示。

## 5. 六种物品与现有数据的映射

运行时物品纹理公共目录：`res://assets/ui/inventory/v001/items/`。

| 当前样例 ID | PNG | 分类 | 名称与说明翻译键 |
| --- | --- | --- | --- |
| `potion` | `potion_red.png` | `potions` | `ui.item.potion` / `ui.item.potion_desc` |
| `sword` | `sword_iron.png` | `equipment` | `ui.item.sword` / `ui.item.sword_desc` |
| `bag` | `travel_pouch.png` | `equipment` | `ui.item.bag` / `ui.item.bag_desc` |
| `herb` | `herb_sprig.png` | `materials` | `ui.item.herb` / `ui.item.herb_desc` |
| `crystal` | `crystal_blue.png` | `materials` | `ui.item.crystal` / `ui.item.crystal_desc` |
| `scroll` | `scroll_parchment.png` | `materials` | `ui.item.scroll` / `ui.item.scroll_desc` |

这些不是正式玩家库存 ID。不要把 PNG 文件名写回样例 ID，也不要根据画出来的外观增加效果定义、装备属性或数量。

当前 `foliage_preview.schema.json` 与 `shop_preview_loader.gd` 都限制样例 `icon` 为 `res://assets/ui/foliage/*.svg`。**不能只把 JSON 的路径换成 PNG**。建议后续接入定义独立背包 skin Resource，按上表 ID 持有 Texture2D 强引用，由组装层注入表现，保留当前样例 JSON 和 SVG 白名单；本轮并未创建该 Resource 或对应接口。

完整代码位置、输入生命周期与当前按钮行为见 [integration_audit.md](reports/integration_audit.md)。不要覆盖共享 `game/assets/ui/foliage/` 图标，以免影响 HUD、委托板或其它页面。

## 6. 双语与输入

- 沿用项目 `ui_typography.tres` 与 Noto Serif SC。不要用概念图中的字形代替可翻译文字。
- 人工翻译源仍为 `game/data/locales/zh_CN.json`、`en.json`；生成 PO 不手工编辑。
- 分类键 `ui.all/ui.equipment/ui.potions/ui.materials`；动作键 `ui.sort/ui.use/ui.store`；未开放说明 `ui.unavailable`；样例说明 `ui.sample_note`。
- 保留当前 B 打开/关闭、Esc 关闭与切换语言后重建页面的行为；快捷键通过 InputMap 读取，避免在图片中固定 B 或 Esc。
- 保留 modal 的角色输入锁定与鼠标/滚轮隔离，装饰层不可截获或穿透业务点击。
- 文字区域以中英文最长内容校准，详情支持换行。固定叶饰不要侵入名称、描述和按钮文字区。

## 7. 本轮与后续验证边界

本包的静态数据由 [asset_validation.json](reports/asset_validation.json) 记录：16 张 PNG 的 RGBA 与透明像素、选中框中心透明、源/运行时副本哈希、15 张 SVG XML 格式及文件引用。HTML 预览与资源元数据均为本轮产物。

本轮没有运行浏览器/Godot验证，不能把资源图库或 HTML 拼装示意称为实机画面。后续接入需要在 1280 × 800、1920 × 1200 下检查中英文、透明边缘、九宫格、选中对齐、键鼠输入、Use/Store 禁用和样例语义，并确认其它 UI 页面没有回归。

本轮没有向“写godot具体代码”或其它项目对话框通知/派发接入工作；接入时间由用户后续安排。
