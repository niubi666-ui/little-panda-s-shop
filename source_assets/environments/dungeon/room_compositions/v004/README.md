# 森林遗迹四组完整 Blender 母版 v004

用户已认可这四组完整模型，派生资源已替换 Godot 当前随机组合中的 v003 表现。这里保留可编辑 Blender 母版与 Cycles 评审图；Godot 实机图、交互验收和 Release 入口见 `docs/ROOM_PRESETS.md`。

## 打开与编辑

打开 `blender/forest_compositions_review_v004.blend`。文件含四个 Scene，通过 Blender 顶部 Scene 下拉菜单切换：

1. `01 Long wall - barrels and wildflowers`：长矮墙、端柱、前后木桶、墙根花草、墙面及墙顶藤蔓。
2. `02 Broken wall - treasure alcove`：左低右高残墙、右端柱、靠墙宝箱、偏左聚集的花丛。
3. `03 Broken column - supply cache`：断柱与基座、大小木箱、左侧花盆、碎石及攀援植物。
4. `04 L wall - mossy boulder`：L 形残墙、内侧岩石、地被植物与较少的小花、墙顶及岩石苔藓。

每个 Scene 的 `*__complete_prefab` Collection 是完整组合，已标记 Blender Asset；Append 该 Collection 即可复用。选择同名根 Empty 可以整体移动、旋转。宝箱、木桶、木箱保持独立子物体，便于后续分别绑定搜刮和破坏。

`STAGE__not_part_of_prefabs` 只包含拍摄用铺地、灯光、镜头和投影树叶，不属于组合，不应作为随机组合导出。镜头采用斜俯视正交投影；预览为 1600×1300、Cycles 128 samples。

## 本轮处理

- 以参考轮廓重新设置道具与墙柱的比例，取消背包、额外石箱等偏离参考的物件。
- 复用 item2 的有 UV 风化墙、端柱、断柱、木桶、木箱与宝箱，复制材质后调整木材饱和度、表面颗粒和粗糙度。原始 item2 不保存、不改写。
- 补建可编辑的细叶地被、蕨类、白色及少量淡紫小花、花梗、花盆及碎石；叶片有曲面和局部 UV 叶脉，植物分布随组合手工指定。
- 藤蔓叶片投射到真实石材表面；墙顶与岩石苔藓逐顶点贴合支撑面，避免悬空装饰。
- 岩石为本轮独立建模的替换件，包含不规则切面、岩石扫描贴图与苔藓材质，不再使用上一轮简单球形占位。
- 所有使用中的文件贴图打包进 blend。对象来源、源文件 SHA256、对象与基础三角数见 reports。

## 预览

参考原图保存在 `reference/`；以下是实际 Blender 渲染。

![长墙木桶](previews/01_long_wall.png)
![残墙宝箱](previews/02_treasure_wall.png)
![断柱木箱](previews/03_column_crates.png)
![墙角岩石](previews/04_rock_corner.png)

## 工程边界

### 已批准并接入 Godot

用户确认本轮质量。当前 Godot 四组合来自 `forest_compositions_review_v004.blend`，导出到 `game/assets/environments/room_compositions_v004/`，替换旧版组合表现。独立交互道具与静态结构分开导出；拍摄场景不导出。`scripts/export_runtime.py` 烘焙材质，`scripts/install_runtime.py` 发布实测位置与碰撞，`scripts/validate_runtime_export.py` 检查导出范围、贴图嵌入和母版未变。运行验收和实机图见 `docs/ROOM_PRESETS.md`。

以下是最初 Blender 评审阶段的边界记录；当前以以上接入说明为准。

母版仍可继续按美术意见调整，不宣称已达到参考图逐像素一致。叶形、石材纹理与参考有差别，当前镜头和照明用于模型评审。后续接 Godot 前，需要烘焙程序材质/叶脉、检查花草双面与透光表现、评估面数和绘制调用，再以实机重新验收；本轮不修改游戏逻辑、随机种子、碰撞或 Release。

来源：现有 item2 与森林庭院派生地面，项目已有 Poly Haven CC0 岩石贴图，新增 Blender 几何；没有引入新的外部下载资源。构建脚本为 `scripts/build_compositions.py`，只允许隔离的后台 Blender 运行；验证脚本为 `scripts/validate_compositions.py`。
