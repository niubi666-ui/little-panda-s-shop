# 森林系列 · 美术源文件

森林系列对应冒险的三个区域：**樱花林**（第一区）→ **古木深林**（第二区）→ **精灵圣殿**（第三区）。
所有森林场景共用一个素材库，每个场景只放自己的地形、摆放和独有模型。

## 文件夹

| 文件夹 | 是什么 |
| --- | --- |
| [kit/](kit/README.md) | **森林素材库**。`forest_kit.blend` 里每个素材是一个集合（`A_<名字>`），已标记为资产，Blender 资产浏览器里按中文目录可找。贴图在 `kit/textures/` |
| [rooms/](rooms/) | **各个场景**，一个场景一个文件夹（见下表） |
| tools/ | 导出、渲染、迁移脚本，所有场景共用 |
| [lookdev/](lookdev/README.md) | 最早的样板间和素材加工过程（高模原件、减面脚本、BlenderKit 下载的原始资产）。只作来源和记录，平时不用打开 |

## 场景

| 场景 | 文件夹 | 区域 | 状态 |
| --- | --- | --- | --- |
| 樱花林空地 | [rooms/sakura_glade](rooms/sakura_glade/README.md) | 第一区 · 战斗 | 已进游戏（训练场现在用的就是它） |
每个场景文件夹的结构：

```
rooms/<场景>/
  <场景>.blend   地形（Ground）、水面（Brook）、瀑布（Waterfall*）、石台（Platform*）、摆放（Layout）、灯光镜头（Lighting）
                 Layout 里的东西全部“链接”自素材库：改素材库，所有场景跟着变
  build_*.py     布景脚本（新场景都是脚本搭的，可重跑；改布局改脚本里的常数和摆放）
  textures/      布景脚本生成的贴图：地面遮罩、落花、石台图案
  concept/       GPT 概念图和修改说明
  README.md
```

## 游戏里对应的位置

| Blender | Godot |
| --- | --- |
| kit/forest_kit.blend | `game/assets/environments/forest/kit/`（整个系列一份：每个素材一个 `assets/<名字>.gltf`，贴图共用 `textures/`，场景只加载自己用到的） |
| rooms/<场景>/<场景>.blend | `game/assets/environments/forest/rooms/<场景>/`（layout.json 摆放表、terrain.glb 地面和水面、terrain/ 地面贴图） |
| — | `game/presentation/rooms/forest/shared/`：所有森林场景共用的接入脚本 `forest_room.gd`、植被/地面/水/花瓣/光束着色器、植被和光束材质 |
| — | `game/presentation/rooms/forest/<场景>/`：`room.tscn`（光照、雾、植被参数、活动范围）、`presentation.tres`（镜头）、地面和水的材质 |

## 常用命令（在本文件夹下运行）

```powershell
# 导出素材库（改了素材库里的模型或材质后）
& 'E:\blender\blender.exe' --background kit/forest_kit.blend --python tools/forest_export.py -- kit E:\ShopGame\game\assets\environments\forest\kit
# 导出某个场景（改了摆放、地形后）
& 'E:\blender\blender.exe' --background rooms/sakura_glade/sakura_glade.blend --python tools/forest_export.py -- room E:\ShopGame\game\assets\environments\forest\rooms\sakura_glade
# 用游戏镜头的机位渲染对照图（和 Godot 截图逐张比）
& 'E:\blender\blender.exe' --background rooms/sakura_glade/sakura_glade.blend --python tools/render_game_views.py -- E:\ShopGame\builds\lookdev game,far 64
```

导出后在 `game` 下跑一次 `godot --headless --import`。Godot 一侧的同机位截图是 `game/tests/fairy_lookdev_capture.gd`。

## 做一个新场景

新场景用布景脚本搭（参照 `rooms/sakura_valley/build_valley.py`）：共用的零件在 `tools/room_build.py`（距离场噪声、地形网格、瀑布、
地面材质、从素材库链接、摆放），地面颜色由脚本生成的遮罩图决定（R 小径泥土、G 溪床、B 草地那一层、A 落花），游戏和 Cycles 用同一张。
一次完整的“重建 → 导出 → 导入 → 截图”见 `docs/ART_PIPELINE.md` 的“森林新场景”一节。

手工做法：

1. 新建 `rooms/<场景>/<场景>.blend`。从素材库链接素材：资产浏览器里把资产库路径指向 `kit/`，拖进来时选“链接”，放进 `Layout` 集合。
2. 地面网格叫 `Ground`，水面叫 `Brook`；场景的自定义属性 `forest_room` 写场地常数（参照 sakura_glade 的写法）。
   地面贴图的来源材质（Forest Floor Moss、Mossy Ground、BrookBedMat）要在文件里，加假用户。
3. 只属于这个场景的模型（瀑布、根拱、石台……）放在场景文件里；以后别的场景也要用，就挪进素材库并标记为资产。
4. 用 `tools/forest_export.py` 导出，在 `game/presentation/rooms/forest/` 下复制 sakura_glade 文件夹改名，改路径和画面参数。
5. 未用到的出口用素材库里的倒木、荆棘、落石堵上（做成可开关的集合）。

## 其他

- `source_assets/environments/dungeon/` 里的 forest_courtyard、sunlit_forest_court、springwater_cloister 等，是更早一代的森林房间（程序建模，2026-09 做的），
  和这套素材库无关。游戏里对应的旧房间（forest_courtyard_v001、forest_ruin_v002）现在只有测试在用，暂时没动。
- 2026-10-18 从 `source_assets/lookdev_forest_v1/` 整理成现在的结构，迁移脚本是 `tools/migrate_v2.py`（只跑一次，留作记录）。
  整理前后游戏画面逐像素对比，差异和同一版本连拍两次的抖动相同。
