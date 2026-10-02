# 背包 UI · 树叶主题美术包 v001

2026-09-26。参考先前确认的背包概念图，拆分为可独立组装的深绿面板、古铜金边、羊皮纸、叶饰和物品缩略图。

**本轮交付为美术资源包，尚未接入游戏。依用户要求，本轮不通知“写godot具体代码”或其它项目对话框。**

## 查看与使用

- [素材图库](previews/index.html)：逐个查看透明组件、物品和 SVG，可切换预览底色。
- [拼装示意](previews/layout_preview.html)：查看 5 列 × 3 行样例网格、分类页签和详情区的组合关系。
- [装配说明](ASSEMBLY.md)：分层、AtlasTexture、九宫格和后续接入边界。
- [资源清单](manifest.json)：原图尺寸、透明范围、建议 Atlas 区域、SHA-256 与引擎路径。
- [静态资源检查](reports/asset_validation.json)：PNG RGBA、选中框中心透明、源/运行时副本哈希、SVG 格式等检查结果。
- [现有代码只读审计](reports/integration_audit.md)：入口、样例 ID、分类、双语和当前未开放功能。

HTML 是资源浏览与拼装示意，**不是 Godot 实机截图**。本轮未运行浏览器或 Godot 验证新版布局，尺寸、九宫格切线及双语排版要在后续接入时校准。

## 保存位置

| 用途 | 项目路径 |
| --- | --- |
| 本包源目录 | `E:/ShopGame/source_assets/ui/inventory/v001/` |
| 独立界面 PNG | `exports/chrome/` |
| 独立物品 PNG | `exports/items/` |
| 辅助矢量图 | `exports/icons/` |
| 原参考图 | [reference/inventory_reference.png](reference/inventory_reference.png) |
| 提示词、生成记录与打包脚本 | `generation/` |
| 预览与报告 | `previews/`、`reports/` |
| 引擎资源副本 | `E:/ShopGame/game/assets/ui/inventory/v001/` |

引擎内资源根路径为 `res://assets/ui/inventory/v001/`，下分 `chrome/`、`items/`、`icons/`。这些文件已经准备在引擎资产目录，**文件存在不代表现有背包代码已经使用它们**。

## 10 个界面 PNG

| 文件（位于 `exports/chrome/`） | 用途 |
| --- | --- |
| `window_panel.png` | 空白深绿背包主面板 |
| `details_parchment.png` | 右侧羊皮纸详情区 |
| `slot_regular.png` | 物品格常态底板 |
| `slot_selected.png` | 金色选中框，中心透明，叠加在物品格上 |
| `tab_regular.png` | 分类页签常态底板 |
| `tab_selected.png` | 分类页签选中底板 |
| `button_primary.png` | 主要操作按钮底板 |
| `button_secondary.png` | 次要操作按钮底板 |
| `close_socket.png` | 关闭按钮底板，与关闭图标分离 |
| `header_leaf_sprig.png` | 独立标题叶饰 |

图片没有烘焙文字、数字、物品数量或价格。PNG 采用真正 RGBA 透明背景；图库的棋盘格是 HTML 检查底色，不属于 PNG 像素。

## 6 个物品 PNG 与样例映射

以下仅对应当前 `foliage_preview.json.inventory` 的 UI 样例，不能当作真实库存或正式 ItemDef。

| 样例 ID | 分类 | 当前名称 | 文件（位于 `exports/items/`） |
| --- | --- | --- | --- |
| `potion` | `potions` | 红色药剂 | `potion_red.png` |
| `sword` | `equipment` | 旅行短剑 | `sword_iron.png` |
| `bag` | `equipment` | 旅行布袋 | `travel_pouch.png` |
| `herb` | `materials` | 芳香草叶 | `herb_sprig.png` |
| `crystal` | `materials` | 蓝色晶簇 | `crystal_blue.png` |
| `scroll` | `materials` | 旧卷轴 | `scroll_parchment.png` |

布袋采用棕色厚帆布主体与皮革辅料。文件名 `sword_iron` 不确立武器材质或攻击规则；药瓶外观不确立药效。物品是为 UI 制作的概念图，并非从游戏中正式物品模型渲染得到的缩略图。

## 15 个辅助 SVG

- 操作：`action_use.svg`、`action_store.svg`、`action_sort.svg`、`close.svg`。
- 无字底板与空态：`quantity_badge.svg`、`empty_slot_mark.svg`。
- 分隔线：`divider_gold.svg`、`divider_ink.svg`。
- 可选色彩标记：`marker_blue.svg`、`marker_green.svg`、`marker_olive.svg`、`marker_amber.svg`、`marker_violet.svg`。
- 从项目既有 SVG 复用：`title_bag.svg`、`title_coin.svg`。

所有 SVG 位于 `exports/icons/`。彩色菱形只是可选美术变体，**没有定义稀有度名称、等级或分配规则**。数量底板、金币图标仅是预留素材；当前样例没有数量和余额，不能因为素材存在就显示虚构数据。

## 当前行为边界

- 分类为“全部 / 装备 / 药剂 / 材料”，对应 `all/equipment/potions/materials`。
- 拼装示意采用 5 列 × 3 行纯美术网格；15 个格子不代表已确定的背包容量。
- 现有背包支持样例筛选、选择、详情与按名称显示排序。
- “使用”和“移入仓库”当前尚未开放，后续换皮仍保持禁用状态与本地化说明。
- 本轮没有新增真实库存、数量、容量、稀有度、装备规则、物品交易或存档。
- 所有文字由代码通过翻译键渲染，沿用项目的 Noto Serif SC 字体与统一字体配置。

## 制作来源与验证

16 张 PNG 使用内置 `image_gen` 按参考风格分别生成/编辑。原始输出按字节保留，打包流程不改写 PNG 像素。提示词和生成记录见 [chrome_prompts.json](generation/chrome_prompts.json)、[items_equipment_prompts.json](generation/items_equipment_prompts.json)、[items_materials_prompts.json](generation/items_materials_prompts.json)。简单 SVG 为本包编写，`title_bag.svg` 与 `title_coin.svg` 复用项目现有矢量资源；来源记录在 manifest。

[build_package.py](generation/build_package.py) 负责生成辅助 SVG、资源清单、报告与 HTML；它检查 alpha、文件路径和副本哈希。最终静态检查结果以 [asset_validation.json](reports/asset_validation.json) 为准。这些检查不替代后续 Godot 中的缩放、九宫格、输入隔离和中英文实机验收。
