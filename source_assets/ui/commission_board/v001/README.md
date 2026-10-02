# 委托板 UI 分层美术素材 v001

2026-09-26接入记录：已通过Godot实机尺寸与交互检查，运行副本与源PNG一致；实现、功能边界和截图见[`docs/COMMISSION_BOARD_UI.md`](../../../../docs/COMMISSION_BOARD_UI.md)。下文保留素材交付时的说明。

依据 [第一版树叶风格的订单概念图](../../../../concepts/ui/v001/03_orders.png)独立生成。**这是供 Godot 拼装的候选图片素材，尚未接入游戏，也未通过实机尺寸验收。** 原始文件保留于 Codex 生成目录；此处为项目内副本。

## 文件与用途

| 文件 | 原图尺寸 | 建议放置层 |
|---|---:|---|
| [board.png](board.png) | 1536×1024 | 最底层委托板；深绿主体、古铜边、绿叶和底部羊皮纸条，内部完全留白 |
| [card.png](card.png) | 1122×1402 | 三张委托共用的空白羊皮纸卡背景 |
| [selected.png](selected.png) | 1122×1402 | 叠在选中卡外的金色边框，中心透明，底部含勾选圆章 |
| [primary_button.png](primary_button.png) | 1881×836 | 接取按钮的空白深绿底图 |
| [secondary_button.png](secondary_button.png) | 1870×841 | 不接单直接出发按钮的空白羊皮纸底图 |
| [herbalist.png](herbalist.png) | 1218×1292 | 草药师头像，透明背景 |
| [guard.png](guard.png) | 1159×1357 | 巡卫头像，透明背景 |
| [traveler.png](traveler.png) | 1199×1312 | 旅人头像，透明背景 |

全部为 RGBA PNG。读图检查：所有图左上角 alpha 为 0；`selected.png` 中心 alpha 为 0。较大透明边距是生成图的一部分，在 Godot 中可用 AtlasTexture region 或 TextureRect 裁切显示区域，不必改写原 PNG。

## 透明像素的建议可视区域

这些是以 alpha > 4 扫描得到的矩形，坐标格式为 `x, y, width, height`。保留几像素额外空隙即可避免截断柔和边缘。

| 文件 | 可视区域 |
|---|---|
| board.png | `0, 5, 1536, 975` |
| card.png | `109, 53, 905, 1279` |
| selected.png | `53, 39, 1020, 1334` |
| primary_button.png | `56, 250, 1769, 333` |
| secondary_button.png | `57, 245, 1757, 343` |
| herbalist.png | `16, 24, 1195, 1250` |
| guard.png | `26, 53, 1122, 1269` |
| traveler.png | `33, 43, 1147, 1250` |

## 给 Astra 的拼装规则

1. 将这组图片复制到 `game/assets/ui/foliage/commission/` 后用 Godot 导入；源图留在本目录。请先读 `PROJECT_CONTRACT.md` 和 `docs/FOLIAGE_UI.md`，复用现有 FoliageUI/Theme，不建立第二套菜单框架。
2. 层级：场景暗化遮罩 → board → 三份 card → 各卡头像 → 动态标题/说明/需求/报酬 → selected（只用于被选中卡，注意透明边距与卡片对齐）→ 动态按钮标签/焦点提示。按钮图位于 board 底部羊皮纸条之上。
3. 文字、报酬、材料图标、顾客数量和选中状态都由 Godot 控件与运行数据生成；图中没有烘焙文字。UI 的中文/英文使用本地化 key，已配置的字体见 `docs/UI_FONTS.md`。
4. 两个按钮要保留不同的语义与独立焦点：接取选中订单、直接出发。选择订单仍限制为 0 或 1 张。键盘与鼠标都能操作。
5. 头像作为可替换的 NPC 展示图。此处三位人物只是视觉示例，未建立正式 NPC/订单内容定义，名称和故事不要从概念图硬编码。
6. 大图不是万能九宫格：板的拱顶与叶片、卡的边角以及人物头像应尽量等比缩放。若需要改变板宽/卡宽，先在目标 1280×800 与 1920×1200 实机验证是否拉伸，再考虑单独制作九宫格切片。
7. 这是静态 regular 状态底图；hover、pressed、disabled、键盘 focus 仍需按现有 Theme/StyleBox 实现，不能仅用一个 PNG 代表全部状态。

完整生成提示词见 [prompts.json](prompts.json)。使用内置 image_gen，各素材单独生成。没有生成材料图标，依照用户本轮要求留待后续。
