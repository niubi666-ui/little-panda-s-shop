# 可复用房间小景 v004（当前）

用户已认可 Blender 母版 `source_assets/environments/dungeon/room_compositions/v004/blender/forest_compositions_review_v004.blend`，当前 Godot 四组合改用 `game/assets/environments/room_compositions_v004/`。v003及旧试摆已归档；不再使用其花草或额外背包。

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

## 组合、配置与复用

| 稳定ID | 当前组合 |
|---|---|
| long_wall | 长矮墙、端柱、两只可破坏木桶；无旧版背包 |
| treasure_wall | 残墙、端柱与朝外的可搜刮宝箱 |
| column_crates | 断柱、花盆与两个独立可破坏木箱 |
| rock_corner | L形墙角、苔藓岩石与地被，实体不可破坏 |

组合定义 `game/presentation/rooms/compositions/*.tres` 保存成员ID/局部变换及静态装饰。目录 `game/presentation/rooms/props/forest_props.tres` 映射模型/碰撞bounds。规则 `game/data/rooms/props_prototype.json` 选择组合池和数量；房间surface提供落点/朝向。当前庭院5个手工落点含内部落点，目标为宝箱墙加其他两组。

复用时注入同一目录与新模板的独立surface/出生点。新增组合先登记Resource，再加入JSON `composition_ids`/`groups`；改已发布成员或位姿更新content_version。生成与临时事务规则见 [物件模块](ROOM_PROPS_PROTOTYPE.md)。

## 验证与注意

- 历史校验9个GLB来源、内嵌纹理、UV非常量；必须统一UV层名后合并，防止断柱/叶片纹理错误。
- Godot提取的运行贴图是导入依赖，不当作烘焙中间文件移动；原始烘焙输出在源资产 `textures/runtime_bakes/`。
- `room_prop_rules.gd` 曾覆盖40种子、3组/10–13实体与可达性；`room_props_integration.gd` 覆盖搜刮/破坏/绕障/重开；截图脚本为 `room_presets_capture.gd`。改动后按 [验证索引](VALIDATION.md) 重跑相关项。
- 旧v004 Release在归档记录中，它不包含后续敌人全部更新；当前从Godot工程试玩。资源退出警告与性能限制见 [已知问题](KNOWN_ISSUES.md)。
