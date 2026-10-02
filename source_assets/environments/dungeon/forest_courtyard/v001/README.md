# 森林石庭院：item2 拼装美术场景 v001

2026-09-27。此目录是可编辑的 Blender 美术源场景，依据 `concepts/forest-courtyard-breakdown-v001` 制作。预览均为本场景的实际 Cycles 渲染，不是概念图。

## 打开与预览

- 场景：`blender/forest_courtyard_item2_v001.blend`
- 日照全景：`previews/forest_courtyard_hero.png`（2560 × 1440，192 samples）
- 俯视布置：`previews/forest_courtyard_topdown.png`
- 神龛近景：`previews/forest_courtyard_detail.png`
- 地面与水面近景：`previews/forest_courtyard_material.png`
- 中性光检查：`previews/forest_courtyard_neutral.png`
- 原模型审计小图：`previews/catalog/`；对象与贴图清单见 `reports/source_inventory.json`。

渲染参数与实际耗时见 `reports/render_*.json`。使用 Blender 5.2.1 LTS / Cycles / OPTIX，AgX 色彩管理。场景相机和灯光均可编辑。

## 原模型和补充工作

原文件：`source_assets/characters/red_panda/blender/item2.blend`。原文件未覆盖，SHA256 已核验未改变。

使用其中全部 15 类模型：栏杆、藤叶、花带、花盆、守护者雕像、灯笼、旗帜、破墙、台阶、墙角、神龛、柱子、拱门、高架通道、古树。模型保持原有纹理；统一朝向、底部支点与尺度后，使用共享网格实例拼装。对象保留 `source_object` 和 `asset_role` 等溯源信息。

新增或派生：

- 从高架通道裁出保留 UV 的铺地表面，复用原模型石材；另建通道石板和中央叶纹嵌饰。
- 为古树补充独立叶片，增加低灌木、蕨类、落叶和连续森林地形。
- 设置四处不规则浅水面、局部湿石材、暖日光、冷天空补光、灯笼光与远景薄雾。
- 树影由实际几何投射，浅水使用实际反射材质。

## 布局与组织

1 单位 = 1 米；Z 向上，参考图后方为 +Y。主庭院约 18 × 16 米，中心保持空旷；神龛位于后侧偏左、拱门位于后侧偏右，另有左后方林间通道。场景延伸到森林和前方铺地，避免孤立悬浮底座。

主要集合：Architecture、Ground、Vegetation、Forest、Props、Water、Atmosphere、Lights、Cameras。中央纹章直径约 3.84 米；这是本版美术尺寸，并非已经确认的玩法碰撞参数。

## 贴图与可重复制作

21 张图像已内嵌，同时保存于 `textures/`，文件路径已检查能解析。用户提供的 Tripo 纹理仍来自原模型；辅助石材、林地纹理沿用项目既有 Poly Haven 资源，来源与 CC0 记录见 `../../shared/reports/material_sources.json`。

脚本：

- `scripts/build_courtyard.py`：重新拼装，会覆盖本目录的生成场景。手工修改前请另存版本；勿对手工编辑后的版本直接重建。
- `scripts/render_courtyard.py`：从已保存场景输出指定视角，不保存渲染模式临时修改。
- `scripts/validate_courtyard.py`：检查原文件哈希、15 类素材使用、贴图内嵌及路径、网格有限数值、相机。

构建脚本依赖项目内 `../../shared/scripts/room_kit.py` 和 `room_foliage.py`；打开与渲染已保存的 blend 不需要运行构建脚本。

## 当前验证与边界

`reports/validation.json` 的六项检查均通过。场景含 922 个对象；独立网格合计约 51 万三角面，计入共享网格实例约 1904 万三角面，主要来自背景林木和补充树叶。近景检查后补上神龛背板，并根据神龛网格射线检测校正了两盏供灯的落点。

这是供审阅的 Blender 美术版本，尚未制作 Godot 导出、LOD、碰撞、导航或性能预算。背景树林需按实际游戏镜头裁剪并简化，不能直接把离线渲染复杂度当作游戏运行规格。

已还原核心布局、用户模型、暖冷日照和边缘植被。与概念图相比，远景层次、光束强度、铺地重复度和局部植物材质仍存在差异；不是逐像素一致的复制。主模型原始贴图带有部分明暗信息，近距离材质表现也受生成模型质量影响。

## Godot接入补充 · 2026-09-27

已由独立后台导出接入第一个战斗测试房间，源blend哈希验证未改变。导出脚本 `scripts/export_godot.py`，报告 `reports/godot_export.json`；运行资源位于 `game/assets/environments/forest_courtyard_v001` 和 `game/presentation/rooms/forest_courtyard_v001`。固定碰撞、相机、实时材质/光照及源工程与PCK启动已验证。

上面的“尚未制作Godot导出”描述是美术源版本交付时的状态；当前接入边界以项目 `docs/FOREST_COURTYARD_INTEGRATION.md` 为准。Godot自动生成LOD已启用，仍未制作专门的低配背景版本或导航。本房间不代表未来随机地牢固定使用该模板。

## 运行植被优化 · 2026-09-27 后续

现已制作运行植被派生版：独立叶片8三角形转2三角形，投影烘焙透明轮廓与切线法线，外围古树减面；累计实例三角形约1909万降至616万。545个非目标网格实例的几何、UV、材质、变换核验一致。保存的高模blend未改动。

`exports/forest_courtyard_high_reference.glb` 保存优化前精确导出；贴图在 `textures/runtime_foliage/`，转换参数在 `scripts/foliage_runtime.json`，报告在 `reports/foliage_runtime.json`。必须经项目 `tools/assets/assemble_forest_runtime.py` 合并保护性数据，再通过 `check_forest_foliage.py` 校验，才安装运行GLB；不能以全场景重导出替代这个流程。完整实机对比和重建说明见项目 `docs/FOREST_FOLIAGE_OPTIMIZATION.md`。本次未烘焙场景光照，未实现导航。
