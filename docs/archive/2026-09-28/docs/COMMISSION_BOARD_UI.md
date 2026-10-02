# 委托板素材接入 · v001

2026-09-26。按`source_assets/ui/commission_board/v001/README.md`接入8张分层PNG。源图保持原样，运行副本位于`game/assets/ui/foliage/commission/`，逐文件SHA-256对比一致。

## 实现

- 复用FoliageUI的J入口、遮罩、Esc关闭、语言切换及角色输入锁定。只有订单页面改用`commission_board.gd`组件，没有创建第二套菜单框架。
- 板体、卡片、人物头像、两个按钮底图通过AtlasTexture裁去透明边距，等比显示。整板在统一设计坐标中等比缩放，画面尺寸变化不改变画像和拱顶比例。
- 选中框与背景卡比例不同：NinePatchRect只伸展透明中部和直线边缘，保留边角和圆章的比例，圆章可伸到卡片下沿。
- 卡片标题、说明、需求、报酬、按钮及反馈全部由Control/本地化文字显示，没有把文字写进PNG。
- 英文标题换行时自动缩小头像可用高度，避免字压住人物。卡片超出一屏宽度时支持水平滚动，未写死顾客总数。
- 中文/英文字体继续统一由`ui_typography.tres`配置；板体、裁切、卡片位置、头像映射、状态覆盖样式集中在`commission_board_style.tres`。

## 操作与范围

- J打开；鼠标点击整张卡、Tab/方向键移动焦点、Enter/Space激活。可选0或1张，再次激活当前卡会取消。
- 未选卡时“接取选中订单”禁用；选卡后可以点击，仅显示未开放提示。
- “不接订单，直接出发”保持独立焦点和独立反馈，也只显示未开放提示。
- 原生Button叠在底图上，保留hover、pressed、disabled和键盘focus状态。
- 人物只是可替换的示例肖像。没有新建正式NPC、顾客故事、材料需求或报酬数值；需求/报酬显示待发布。当前界面不会写库存、金币、订单或存档，也不会启动地牢。

## 维护位置

| 位置 | 负责内容 |
|---|---|
| `game/presentation/foliage/commission_board.gd` | 委托板独立展示组件、选择、焦点与预览反馈 |
| `game/presentation/foliage/commission_board_style.tres` | 所有图片/Atlas区域/布局矩形/头像映射/状态资源 |
| `game/presentation/foliage/foliage_ui.gd` | 原有菜单入口和选中ID；接收局部选择/关闭信号 |
| `game/data/shop/foliage_preview.json` | 经Registry注入的只读示例标题和说明引用 |
| `game/data/locales/` | 动态中英文文案人工源 |

更换肖像只需修改Style资源的`portraits`映射；键为样例目录中的稳定ID。未来正式订单接入应用层时，应替换样例ViewModel并注入命令接口，不能在此展示脚本直接写存档。

## 验证

- 1280×800和1920×1200下检查中文/英文截图、文字与头像不重叠、按钮在视野内。
- `game/tests/foliage_ui.gd`通过：鼠标选卡、Enter取消/重选、未选时接单禁用、两个按钮独立反馈、语言切换、Esc、原有背包/装修/家具交互回归。
- 内容schema/翻译/PO一致性校验通过；PNG源与运行副本校验一致。
- 截图：`docs/previews/commission_board_zh.png`、`commission_board_en.png`。

仍未验证独立导出包和真实订单业务；本次交付为美术素材及UI交互接入。
