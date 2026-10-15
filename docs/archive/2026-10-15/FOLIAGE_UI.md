# 树叶主题 UI · 首版实机界面

2026-09-25。参考：`source_assets/ui/reference/foliage_v001/` 的五张概念图及README。

## 操作与已实现范围

- 店铺HUD：深绿底、古铜双层边框、叶饰、店名、语言入口和底部功能按钮。金币显示“—”，不虚构当前余额；店铺HUD未接入战斗生命，因此未填入概念图的生命/体力示例值。
- B：背包预览，支持分类、鼠标选中物品、详情、显示排序。2026-09-26已接入独立背包 PNG 皮肤与表现模块，详见[INVENTORY_UI.md](INVENTORY_UI.md)。空格仅演示物品格外观，不代表背包容量。
- J：订单预览，示例委托卡可选0或1个，重复点击可取消选择。2026-09-26已接入分层PNG、人物肖像及金色选中框；接单与自由出发入口提供独立的未开放提示，详情见[COMMISSION_BOARD_UI.md](COMMISSION_BOARD_UI.md)。
- R：主店铺已接入独立摆放原型，可添加、旋转、移动或移除四种样例家具；详见[SHOP_DECORATING.md](SHOP_DECORATING.md)。未注入装修协调器的独立UI预览仍显示旧的样例目录。
- Esc：关闭当前窗口；在店铺无窗口时打开共享 v002 设置菜单。语言、主音量、垂直同步与帧率上限可调；复杂功能明确占位。详见 [SETTINGS_UI.md](SETTINGS_UI.md)。L继续可用。
- F：保留9件家具的交互占位面板，采用新主题。关闭它不会顺便打开设置。
- 窗口打开时阻止角色移动；在目录中滚动不应缩放场景。关闭后恢复操作。

这是UI展示与交互层，尚未实现物品使用、转仓、正式接单、地牢出发、真实金币或持久设置。背包/订单数据是**独立的示例目录**，不代表玩家库存。装修摆放由独立应用协调器处理，使用单独的四种家具目录；布局只保留至离开当前店铺。禁用按钮配有说明；没有将示例数据写入游戏存档。

## 实现与维护

| 文件 | 作用 |
|---|---|
| `game/presentation/foliage/foliage_ui.gd` | HUD与页面接线、筛选/选中/窗口生命周期，本地化刷新 |
| `game/presentation/inventory/` | 独立背包表现、六种 PNG 图标、皮肤 Resource 与准备工厂 |
| `game/presentation/foliage/foliage_theme.tres` | 控件主题、按钮状态、九宫格边框、字体、UI尺寸 |
| `game/assets/ui/foliage/` | 独立SVG叶饰、矢量图标与边框，不包含文字 |
| `game/data/shop/foliage_preview.json` | 仅用于UI验证的样例目录，无价格、战斗参数或库存数量 |
| `game/content/shop_preview/foliage_preview_definition.gd` | 校验后的只读样例Definition |
| `game/data/schemas/foliage_preview.schema.json` | 字段、分类和路径schema |
| `game/data/locales/` | 所有文案与快捷键模板的中英文人工源 |
| `tools/assets/build_foliage_ui.py` | 可重复生成SVG组件及Theme的离线制作工具 |
| `game/tests/foliage_ui.gd` | 实际鼠标/按键输入、双语排版、窗口阻止移动、旧交互回归和实机截图 |

启动顺序：manifest加载 → 内容校验 → Registry发布只读UI Definition → main注入FoliageUI；UI不读存档，不通过全局服务定位器查数据。目录选择只影响UI状态，排序也只改变显示顺序。键位从InputMap读取。

FoliageUI通过局部`modal_changed`信号通知预览控制器阻止移动；通过注入的只读Callable判断原有家具弹窗状态，避免Esc冲突。新页面无需向角色移动脚本追加业务。

装修入口通过注入的 Callable 委托给 `ShopDecoration`；其 `mode_changed` 信号切换原 HUD、训练入口和角色输入。装修规则与布局状态均不进入 FoliageUI。

Theme使用Godot原生控件与StyleBoxTexture九宫格，边框随窗口伸缩，文字保持可翻译。背包、装修和委托板均已接入各自分层美术包；共享 HUD 与旧独立装修预览仍使用 foliage SVG。背包 PNG 由独立 skin 按样例 ID 映射，目录 JSON 和 SVG 白名单未改动。2026-09-26字体改为随项目保存的Noto Serif SC，字体、字重、字号统一由`ui_typography.tres`管理，详见[UI_FONTS.md](UI_FONTS.md)。

## 验证与截图

以下为旧版 UI 的历史验证记录。2026-09-26装修入口已改为真实摆放模块，对应测试断言已更新。后续已通过独立 Godot 进程运行 UI 图形回归，包含装修入口及中英文界面，`FOLIAGE_UI failures: []`；详细记录见[SHOP_DECORATING.md](SHOP_DECORATING.md)。

- 内容构建校验：字段/schema、样例ID重复、图标路径、中英文key/参数一致性、生成PO一致性。
- 保留的控制测试：31项通过。
- 实机验证：B/J/R/Esc/L、鼠标选物、订单单选、装修选物、窗口阻止移动、9处交互机制保留、Esc关闭家具弹窗不打开设置。
- 窗口与按钮在1280×800验证；1920×1200验证双语页面。截图归档至`docs/previews/foliage_*.png`。

复现命令：

```powershell
& builds/content_venv/Scripts/python.exe tools/content/build_shop_preview_content.py --check
& 'E:\GoDot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe' --path game --resolution 1280x800 --script res://tests/foliage_ui.gd
```

进入实际玩法阶段时，将样例目录换成会话提供的ViewModel/命令接口，实际库存、金币、订单仍必须经过会话提交入口；不能直接给当前UI按钮加存档或交易写入。
