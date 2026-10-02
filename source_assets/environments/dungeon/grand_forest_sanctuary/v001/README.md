# 古树圣庭 · Blender 美术工程 v001

**最新评审：用户未认可本版视觉效果，已暂停继续制作。下一步先确认 `concepts/combat_rooms/grand_forest_sanctuary_review_v002/` 的概念参考，再决定重做方案；本版不作为已通过的画质基准。**

2026-09-27。根据 `concepts/combat_rooms/large_scale_v001/01-grand-forest-sanctuary.png`，使用用户 `forest_yard_item.blend` 资源拼装。预览为真实 Blender Cycles 渲染。此目录不包含 Godot 接入或玩法实现。

## 打开与查看

- **主工程**：`blender/grand_forest_sanctuary_v001.blend`
- **主视角成片**：`previews/sanctuary_hero.png`，2560×1440，Cycles / OPTIX，160 samples，降噪。
- **尺度检查俯视图**：`previews/sanctuary_topdown.png`。金色实线表示 36×32 米主庭院；青色虚线仅对比旧版 18×16 米占地；白线表示主视角在地面上的覆盖范围。为查看地面，俯视检查临时隐藏树木、薄雾与架空横梁；主工程保留完整模型。
- **神龛局部**：`previews/sanctuary_detail.png`。
- **原资源缩略图**：`previews/catalog_0.jpg`、`previews/catalog_20.jpg`；单件图位于 `previews/catalog/`，编号对应 `reports/source_inventory.json`。
- `reference/` 保留这次的概念目标。概念图不等于 Blender 成片，成片以 `previews/sanctuary_hero.png` 为准。

## 面积与人物比例

| 项目 | 尺寸 / 含义 |
|---|---|
| Blender 单位 | 1 unit = 1 m |
| 上版主庭院 | 18×16 m = 288 m² |
| 本版主庭院 | 36×32 m = 1152 m²，4 倍占地 |
| 主庭院范围 | X: −18…18 m；Y: −16…16 m |
| 小熊猫 | 读取当前游戏 `red_panda_v008.glb` 的 idle，沿用现有 1.20058629 缩放；测量身高约 1.20 m |
| 主视角 | `Camera_Gameplay_Hero`，高位斜俯视；房间延伸到画面外 |
| 整体检查 | `Camera_Whole_Room_Topdown`，仅用于布局审核，不是游戏缩放建议 |

围绕主庭院的地面延续和外圈森林不计入上述 1152 m²。小熊猫和剑是本工程中的静态比例参照；未修改角色绑定、动画源文件或 Godot 文件。模型导出里带有的辅助 Icosphere 已在展示副本中排除。

## 分层与后续可编辑性

| Collection | 内容 |
|---|---|
| Architecture | 神龛、雕像背衬、开放柱廊、台阶、分散的残墙及矮柱 |
| Ground | 主庭院基底、保留原 UV 的石板地面、四组六叶纹章 |
| Ground_Details | 苔藓、落叶；可整体调整密度 |
| Trees | 左侧古树、外圈树木、独立补充叶片及树影用高处叶枝 |
| Vegetation / Flora | 原模型花草、藤蔓与补充的几何蕨叶、野花 |
| Decor | 悬旗、铜灯、岩石、花盆等 |
| Interactive_Props | 木箱、木桶、宝箱，分别保留对象；尚未添加游戏交互 |
| Water | 边缘薄积水反射面 |
| Lighting / Atmosphere | 暖太阳、冷天空补光、局部灯光、稀薄体积雾 |
| Scale_Reference | 1.20 米小熊猫及现有长剑的静态展示副本 |
| Cameras | 主视角、全景俯视、神龛和古树细节视角 |
| Layout_Review_Guides | 尺度检查辅助线，正常显示和渲染时隐藏 |

重复物件共享 Mesh 数据，位移、缩放、旋转按实例保留。大树增高树冠以减轻遮挡；不会把整个场景连同人物一同放大。

## 原文件归档与来源

- 用户原路径保留：`source_assets/characters/red_panda/blender/forest_yard_item.blend`。
- 本次制作时的完整原库快照：`original/forest_yard_item.blend`。源文件与快照 SHA256 核对见 `reports/validation.json`。
- 新场景中所有原库物件保留 `source_file`、`source_object` 或派生说明；对应表见 `reports/asset_manifest.json`。
- 铜灯和独立旗帜复用已认可第一庭院 `forest_courtyard/v001/blender/forest_courtyard_item2_v001.blend` 的对象，以 append 形式写入新工程，无外部 link 依赖。
- 石板地面沿用第一庭院的方法：从本次原库的石桥中央裁出表面，保留 UV 并去掉两侧高边，避免新整块地砖重复出现明显的大网格边线。用户提供的新铺地块完整保留在原库归档中。
- 新建内容：柱廊横梁、神龛背衬、地基、补充叶片 / 蕨类 / 野花、薄积水、灯光、相机和尺度辅助线。
- 图像已抽取到 `textures/` 并重新打包进 `.blend`，解决 Tripo 素材残留的 `D:/Temp/…` 路径。主场景无需依赖这些临时路径。

## 验证与交付边界

`reports/validation.json` 记录重新加载后的面积、角色高度、角色画面占比、房间延伸出镜头、图像完整性、外部 link、面数和源文件哈希检查。渲染时间和采样信息位于 `reports/render_*.json`。

本轮只创建 Blender 美术源工程、归档和预览；未接入碰撞、导航、随机房间生成、可破坏逻辑或 Godot 材质 / 灯光。主视角截图只验证此固定相机，角色移动后的树冠遮挡与引擎性能仍需接入阶段验证。

## 复现

使用独立的 Blender background 进程：先运行 `scripts/build_sanctuary.py`，再运行 `scripts/finalize_sanctuary.py`，随后运行 `scripts/validate_sanctuary.py` 和 `scripts/render_sanctuary.py -- hero` 等。不要在用户正在编辑的工程里运行重建脚本。

构建脚本依赖本项目 `dungeon/shared/scripts/room_kit.py`、`room_foliage.py`、原库快照以及文中已注明的第一庭院和角色 / 武器源文件；**打开、编辑、渲染交付的 `.blend` 无需重跑构建脚本**。
