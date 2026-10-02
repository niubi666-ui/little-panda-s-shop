# 背包 UI v001 · Godot 接入

2026-09-26。美术来源：`source_assets/ui/inventory/v001/`；运行时素材：`game/assets/ui/inventory/v001/`。

## 当前能力

- B 打开/关闭，Esc 关闭，L 切换中英文；关闭按钮使用素材包的方形底座与独立符号。
- 全部、装备、药剂、材料四个分类；鼠标选中物品显示大图、名称和说明。
- 整理按当前语言的名称排列可见样例，保留选中项，不修改目录数据。
- 六个现有样例使用独立 PNG；所有物品保持长宽比。全部分类显示 5 列 × 3 行，九个空格仅为美术占位，不代表库存容量。
- 深绿金边主框、羊皮纸详情、选中金框、页签、按钮与叶饰均接入分层资源；悬停、选中悬停、按下、禁用和键盘焦点有对应样式。
- 模态页面锁定店内移动并拦截鼠标及滚轮；关闭后恢复原有操作。

当前仍是**只读样例目录**，没有实际库存、物品数量、容量、价格、稀有度或余额。使用和移入仓库按钮保持禁用，并展示“功能尚未开放”。没有新增物品使用规则或存档写入。

## 模块与数据流

`Registry → FoliageUI → InventoryPanel`。只读目录通过参数传入；皮肤在 FoliageUI 配置阶段准备一次并注入面板。

| 文件 | 职责 |
|---|---|
| `game/presentation/inventory/inventory_panel.gd` | 背包布局、贴图、详情和本地显示排序 |
| `game/presentation/inventory/inventory_ui_skin.gd` | 表现 Resource 字段声明 |
| `game/presentation/inventory/inventory_ui_skin.tres` | 纹理映射、Atlas 区域、九宫格、状态颜色及尺寸 |
| `game/presentation/inventory/inventory_theme_factory.gd` | 裁切并缩放九宫格纹理，缓存准备结果，返回独立样式实例 |
| `game/presentation/foliage/foliage_ui.gd` | 窗口生命周期、分类与选中 ID、语言刷新和模块接线 |
| `game/tests/inventory_ui.gd` | 实际鼠标/键盘输入、状态、排版、截图和数据不变验证 |

面板发送局部 `category_requested`、`selection_changed`、`sort_requested`、`close_requested` 信号，不访问角色、装修、订单、会话或文件系统。旧背包布局已从 FoliageUI 移除，避免两套实现。

分类和选中 ID 由 FoliageUI 保持，语言切换后重新组装仍保留选择。整理只影响当前可见控件顺序；重建页面后恢复目录顺序，与此前行为一致。

## 后续调整入口

- **换图/换皮肤**：修改 `inventory_ui_skin.tres` 的 `items`、`textures`、`icons`。
- **透明留白**：各 AtlasTexture 的 `region` 使用 manifest 的建议区域；不修改原 PNG。
- **边框与布局**：修改 `styles`、`style_texture_sizes`、`metrics`。九宫格先裁切，再按逻辑 UI 像素缩放，避免把大图的切线直接当作控件边距。
- **字体**：继续使用 `game/presentation/foliage/ui_typography.tres`；背包没有复制字体和字号。
- **文案**：沿用 `game/data/locales/{zh_CN,en}.json` 已有键；生成 PO 不手改。

样例 `foliage_preview.json` 的 ID、SVG `icon` 路径及 schema 保持原状。背包 PNG 通过 skin 按样例 ID 映射，未替换共享 foliage 图标。物品素材不定义实际道具效果。

未来接真实库存时，应由应用层注入只读 ViewModel 与用例接口，使用/转仓经会话提交入口；不能直接在面板中写库存或存档。

## 验证

使用独立 Godot 4.7.2 Forward+ 测试进程，不接管已有编辑器；图形测试结束后自行退出。

2026-09-26 实际结果：

| 检查 | 结果与日志 |
|---|---|
| 店铺启动 / GDScript 加载 | 正常，`builds/inventory_v001_compile.log` |
| 1280×800，中英文 | `INVENTORY_UI failures: []`，`builds/inventory_v001_ui_1280.log` |
| 1920×1200，中英文 | `INVENTORY_UI failures: []`，`builds/inventory_v001_ui_1920.log` |
| 订单、装修入口、设置、家具交互回归 | `FOLIAGE_UI failures: []`，`builds/inventory_v001_foliage.log` |
| 家具摆放集成回归 | `SHOP_DECORATING failures: []`，`builds/inventory_v001_decorating.log` |
| 样例目录、双语键与生成 PO 一致性 | 内容检查通过，119 个双语键；本次未改翻译源 |

已查看实机截图并校正关闭按钮比例、空格标记居中和角落装饰避让；选中页签/格子的悬停样式显式覆盖，避免回退共享主题。测试期间没有修改战斗文件，也没有使用共享 MCP 的运行/停止命令。

复现：

```powershell
& 'E:\GoDot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe' --path game --resolution 1280x800 --max-fps 60 --script res://tests/inventory_ui.gd
& 'E:\GoDot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe' --path game --resolution 1920x1200 --max-fps 60 --script res://tests/inventory_ui.gd
& builds/content_venv/Scripts/python.exe tools/content/build_shop_preview_content.py --check
```

截图保存至 `docs/previews/inventory_v001_{zh_CN,en}_{1280x800,1920x1200}.png`。测试检查真实按键、四分类筛选、排他选中、按翻译名排序、禁用操作、切换语言保留选择、移动锁、滚轮隔离、目录和家具状态不变，以及面板和按钮位于视口内。
