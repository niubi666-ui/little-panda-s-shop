# 可复用房间小景 v004（当前）

用户已认可 Blender 母版 `source_assets/environments/dungeon/room_compositions/v004/blender/forest_compositions_review_v004.blend`，当前 Godot 四组合改用 `game/assets/environments/room_compositions_v004/`。下方 v003 记录仅为历史；不再使用其花草或额外背包。

## v004 资源与交互边界

- 保留母版墙柱、苔藓岩石、花盆、碎石、花草与藤蔓。长墙取消旧背包；残墙使用母版本身的端柱；断柱保留花盆及两个独立木箱。
- 静态结构与植物合并导出，物理代理使用 `physics_only.tscn`，不会重复绘制墙体。代理按实际模型测量尺寸分件建立，不用整组大包围框堵住内部。
- 宝箱、木桶、木箱单独导出并由各自 RoomProp 拥有，未包含在静态模型中；1 HP 破坏后独立隐藏并取消碰撞。
- 颜色与法线烘焙，不烘焙评审照明。重复 UV 道具/叶脉使用共享材质贴图；新岩石、石台、花盆、碎石的空间程序材质在实际网格上烘焙。双面叶片保留；Cycles 透光/次表面与实时标准材质仍有差别。
- 母版及 item2 不覆盖。拍摄地面、灯光、镜头与其他场景不导出。保留批准几何，本次未大幅减面，高密度植物后续可做 LOD。
- `scripts/export_runtime.py` 烘焙导出，`reports/runtime_export.json` 记录来源 SHA256/成员位置/尺寸，`scripts/install_runtime.py` 发布组合与表现 Resource，沿用 JSON 的 HP/奖励等配置。这些路径均相对母版的 v004 目录。
- 当前内容版本 `room-presets.4`，schema/generation 仍为 3；旧计划拒绝复用。随机算法、会话事务与战斗机制保持原接口。
- 复用到别的房间仍注入同一目录和各自 PlacementSurface/出生点。当前不支持任意地形自动导航；搜刮仍是训练临时状态，未进入永久库存。

## v004 Godot 实机图

![长墙](previews/presets_v004_long_wall.png)
![宝箱墙](previews/presets_v004_treasure_wall.png)
![断柱](previews/presets_v004_column_crates.png)
![岩石墙角](previews/presets_v004_rock_corner.png)
![布局7](previews/presets_v004_layout_7.png)
![布局91](previews/presets_v004_layout_91.png)

## v004 验证记录

- 母版哈希未变，9 个 GLB 均仅含目标网格、内嵌贴图；所有纹理材质使用的 UV 非常量。导入无错误（`builds/presets_v004_import_final.log`）。Godot 自动提取的运行贴图属于导入依赖，不能当烘焙中间文件移动；原始烘焙输出放在 source_assets 的 `textures/runtime_bakes/`。
- 内容 schema/语义及 208 个中英文 key 通过。`room_prop_rules.gd` 检查 40 个种子：均有 3 组、10–13 个实体，确定性、序列化、四组覆盖、导航连通、临时事务失败隔离与幂等通过。
- `room_props_integration.gd` 的实际 F 搜刮、1 HP 近战破坏/取消碰撞、不可破坏墙、敌人绕障、双语、清场探索、重开保留计划及新布局通过。日志 `builds/presets_v004_integration.log`。
- 四组细节与种子 7/91 已重新在 Godot Forward+ 截图并检查，修复合并时 UV 层名不同导致断柱纹理丢失的问题。截图程序 `tests/room_presets_capture.gd`。
- 图形程序退出仍有此前的 7 个 Texture RID 警告，本次未修复该既有问题。
- Windows Release 导出完成，项目目录外运行 PCK 的相同物理/交互集成测试通过；EXE 无界面启动店铺并以 exit 0 退出。日志：`builds/presets_v004_export_release.log`、`presets_v004_pack_integration.log`、`presets_v004_exe_smoke.log`。这些是功能/导出验证，不是持续战斗帧率基准。

新版试玩目录：`builds/windows-release-room-presets-v004/`。店铺 F6 进入战斗；「新随机布局」重新抽取，「重新训练」保留本次布局。

---

## v003 历史记录（已被替换，不作为当前美术规范）

2026-09-27。当前运行版本替代独立散点生成；四张参考的目标是「有主体、有依附、组间留白」。主体建筑、原始 item2.blend、战斗技能及店铺模块没有修改。

## 四种组合

| ID | 组合与玩法 |
|---|---|
| `long_wall` | 两段矮墙、端柱、两只 1 HP 木桶、可搜刮背包；花草沿墙根两侧生长 |
| `treasure_wall` | 短残墙、侧墙、端柱、朝外的木宝箱；墙脚及转角花草 |
| `column_crates` | 直立断柱、方木箱与长木箱；柱脚花草、柱顶苔藓，两个箱子分别 1 HP |
| `rock_corner` | 两段矮墙组成 L 形、内侧岩石、墙脚花草和墙顶苔藓；均不可破坏 |

`item2` 中未找到独立大岩石，当前 `moss_rock` 是用已有岩石贴图制作的可替换低面占位；其余新增墙、柱、苔藓来自 item2，花/蕨来自已接入的庭院模型。不是参考图的逐像素还原。

## 随机方式

- JSON 当前目标为一组宝箱墙，加上另三种组合中的两种，不重复抽取。每房目标 3 组。
- 庭院提供 5 个手工落点和各自允许朝向，包含一个内部落点。选择整个小景的落点与朝向，不拆散内部成员，不再使用连续任意角度散点、中央件数配额或聚簇半径。
- 成员碰撞矩形膨胀后检查出生点、房间边界、不同组合重叠与通路连通。宝箱需要可达且无遮挡的站位。内部成员可按设计紧贴；导航按成员并集，不用整组外包框封死小景内部。
- 候选不合格就换下一个；全部不合格可少放一整组，不强塞、不将余下成员散落。当前验收的 40 个种子均放入 3 组、10–14 个实体成员。
- 花草纯表现，无碰撞，也不参与玩法随机流；岩石不是花草，具有实体碰撞。
- 计划保存种子、版本、组合 ID/落点/实际位姿、每个成员稳定 ID/实际位姿/预滚奖励。重开复用计划；新布局重新取种子。版本为 schema=3、generation=3、content=`room-presets.3`，旧计划明确拒绝。

## 修改与复用入口

| 文件/目录（相对 game） | 唯一职责 |
|---|---|
| `presentation/rooms/compositions/*.tres` | 组合成员、局部位置与朝向；完整组合的权威定义 |
| `presentation/rooms/compositions/*_flora.tscn` | 每种组合的花草/苔藓表现 |
| `presentation/rooms/compositions/assets/` | 共用花草网格，独立于评审场景 |
| `presentation/rooms/props/forest_props.tres` | 模型、碰撞尺寸、组合资源目录 |
| `presentation/rooms/forest_courtyard_v001/placement_surface.tres` | 当前房间可行走矩形、落点、允许朝向 |
| `data/rooms/props_prototype.json` | 组合候选/数量、实体类别/HP、交互距离、测试掉落、通行余量等玩法参数 |
| `rogue/rooms/prop_planner.gd` | 纯计划生成与校验；没有庭院模型路径 |
| `app/training_room_props.gd` | 注入资源，实例化装饰与实体、接入临时会话和绕障 |

其他房间复用：RoomPresentation 注入同一 `prop_visuals` 和该模板独立的 PlacementSurface。按实际平坦可行走区域标注 bounds、安全落点/朝向及出生点，再运行布局和真实物理验证。**目前不支持任意不规则地形自动识别；跨模板随机房间池也尚未实现。**

新增组合：增加成员 Resource 与纯装饰场景，在表现目录登记；JSON `composition_ids` 和 `groups` 显式启用；新实体先添加类别/翻译/模型尺寸，再校验。更换岩石只需替换模型及相应 bounds，组合和交互逻辑不用重写。已发布内容改变成员或位姿时需更新内容版本。

导出脚本：`source_assets/environments/dungeon/shared/scripts/export_composition_parts.py`。只复制源网格、归一化导出，不保存源 blend；`assets/environments/room_compositions_v003/provenance.json` 记录源 SHA256 与对象名。断柱原网格横放，导出副本转正。

## 实机预览

以下为 Godot 真实场景截图，保留房间灯光/镜头角度；细节图拉近镜头，布局图隐藏测试 HUD 和敌人以看清摆放。

![长墙木桶](previews/presets_long_wall.png)
![残墙宝箱](previews/presets_treasure_wall.png)
![断柱木箱](previews/presets_column_crates.png)
![墙角岩石](previews/presets_rock_corner.png)
![种子7](previews/presets_layout_7.png)
![种子91](previews/presets_layout_91.png)

## 验证与边界

- 内容 schema、语义和 208 个中英文 key 校验通过。
- `tests/room_prop_rules.gd`：40 种子、重复生成、实际计划 JSON 往返、完整成员位姿保留、四种组合覆盖、导航连通、搜刮/破坏事务失败隔离与幂等。
- `tests/room_props_integration.gd`：真实 F 搜刮、物理无遮挡站位、1 HP 近战破坏及取消碰撞、墙不可破坏、敌人真实绕障、中英文提示、清场探索、重开保留计划、新布局切换。
- `tests/room_presets_capture.gd`：四种细节及两个种子完整布局实机截图。
- Windows Release 导出成功；导出 PCK 在项目目录外运行同一物理/搜刮/重开集成测试通过，EXE 独立无界面启动商店并正常退出（exit 0）。日志为 `builds/presets_pack_integration.log`、`presets_exe_smoke.log`、`presets_export_release.log`。
- 临时训练搜刮不加入永久库存；正式存档、跨房间结算、敌人随机池仍未接入。可搜刮类型继续支持 chest1/chest2/forest_bag，但不要求每房三类齐全，当前四组合未用 chest2。
- 图形退出仍有此前的 7 个 Texture RID 警告；本次不宣称修复该既有问题。

试玩：`builds/windows-release-room-presets/LittlePandasShop.exe`，与同目录 PCK 一起使用。店铺 F6 进入战斗；右下「新随机布局」比较新布局，「重新训练」保留本次布局。
