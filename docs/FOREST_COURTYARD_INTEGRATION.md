# 森林庭院 · 第一个战斗房间接入

2026-09-27。当前用于测试的房间模板为 `forest_courtyard.v001`。**它不是正式冒险的固定第一关；现已接入同模板内的种子随机物件，随机房间池仍未启用，详见 [随机物件原型](ROOM_PROPS_PROTOTYPE.md)。**

当前运行GLB为树冠/外围优化版，主体建筑保持；后台加载见 [植被与加载](FOREST_FOLIAGE_OPTIMIZATION.md)。旧导出/早期采样不作为当前版本性能结论。

## 试玩入口

- 店铺按F6或点击训练按钮，进入 `game/app/combat_training.tscn`。
- 开场三选一后正常移动、普攻、闪避；两波遭遇、Build、重试与回店沿用既有流程。
- 滚轮缩放；镜头在庭院附近有限跟随，避免走到边缘时画面只剩场景外部。
- 当前测试范围为主庭院；栏杆、神龛、供奉花盆有简化碰撞，前后出口临时封闭。林间道路和外围树林是背景，不是已经完成的房间切换区域。

## 可替换的房间边界

`combat_training.gd` 通过导出的 `room_presentation` 接受房间Resource，战斗代码不包含森林庭院ID或模型路径。当前宿主场景指定该Resource；未来选择器根据RoomPlan提供其他模板Resource，并沿用同一战斗宿主。

| 文件 | 职责 |
|---|---|
| `game/app/combat_training.tscn` | 可玩的战斗宿主，当前指向庭院表现资源 |
| `game/presentation/rooms/room_presentation.gd` | 房间场景引用、稳定模板ID、镜头范围与抗锯齿配置 |
| `game/presentation/rooms/forest_courtyard_v001/presentation.tres` | 该模板的表现配置 |
| `game/presentation/rooms/forest_courtyard_v001/room.tscn` | 模型实例、光照、环境、碰撞、出生点和ReservedRuntimeProps运行时物件容器 |
| `game/rogue/rooms/authored_room.gd` | `player_spawn()` / `enemy_spawns()`返回世界坐标，不抽随机数或创建敌人 |
| `game/presentation/rooms/forest_courtyard_v001/forest_surfaces.gd` | 对导入材质应用湿石材和水面适配；不处理玩法 |
| 同目录 `wet_paving.gdshader/.tres`、`water.tres` | 对应Blender湿区的材质参数与实时反射表面 |
| `game/assets/environments/forest_courtyard_v001/` | GLB、烘焙颜色贴图及导入描述 |

场景坐标、碰撞形状和美术参数属于 `.tscn/.tres`；伤害、敌人、波次和构筑数值仍从原JSON读取。未来房间池、权重和深度规则需要独立JSON目录，不把这份表现Resource当随机规则表。

原 `rogue/scenes/training_arena.tscn` 保留为轻量战斗规则/动作回归夹具；它不再是店铺的训练入口。未注入房间Resource的夹具继续使用其本地出生点和旧镜头。

## Blender到Godot

源文件：`source_assets/environments/dungeon/forest_courtyard/v001/blender/forest_courtyard_item2_v001.blend`。

- 在独立后台Blender中读取，没有保存或覆盖源文件；导出前后SHA256一致。未操作用户正在打开的另一份Blender工程。
- 导出脚本在源目录 `scripts/export_godot.py`；导出记录 `reports/godot_export.json`。保留模型共享网格、原有图像纹理、主体布置和外围森林；曲线及修改器转为导出几何。
- 程序化表面颜色烘焙成贴图，不烘焙灯光。原模型纹理继续沿用，植物与石材在实时灯光下着色。
- 坐标由Blender Z-up转换为Godot Y-up。灯光和参考相机的矩阵亦转换，并通过同视角截图核对。
- 重建暖色日光、冷色环境补光、局部灯笼光、AgX映射、环境遮蔽、间接屏幕空间补光、体积薄雾、反射探针和湿石材。
- 水面是Godot实时透明反射近似；Cycles的透明/Fresnel混合、植物透光、微表面凹凸和多次间接光不能由glTF逐项原样迁移。当前结果经过参考图对照，但不声称与Cycles逐像素一致。
- 极薄铺地和纹章关闭自投影，仍接收树木/角色阴影与环境遮蔽；用于减少实时阴影伪影。细小树影仍受实时阴影采样精度影响。
- 原场景保留详细几何，导入启用Godot自动LOD。当前主庭院为近似平面战斗，未实现起伏地形控制器或室外探索；平坦内庭绕障现由物件模块提供。

房间进入时应用TAA，离开时恢复原Viewport设置。调整最终品质应在该模板资源中进行，避免影响店铺或所有战斗夹具。


## 验证与扩展

按 [验证索引](VALIDATION.md) 运行 `forest_room.gd` 与受影响的战斗/加载测试。历史验证包含模板注入、出生/栏杆碰撞、镜头、三选一、重开/回店。当前物件规划和预算遭遇已接入，随机模板池与正式路线尚未实现。固定树木/栏杆/铺地不自动成为可破坏物，新增随机资产需独立导出与登记。早期性能/截图/导出记录见归档。
