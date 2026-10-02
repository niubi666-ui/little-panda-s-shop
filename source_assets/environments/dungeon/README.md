# 战斗房间 · Blender 美术源场景

本次制作依据用户选中的两张概念图：**日照林庭**与**清泉回廊**。目标是还原宽阔战斗空间、石建筑、植物层次和自然光氛围，保留可编辑构件，方便继续精修以及替换复杂雕塑。

## 工程入口

2026-09-27 新增：使用用户更新后的 `item2.blend` 模型拼装的第一战斗场景，见 [森林石庭院 v001](forest_courtyard/v001/README.md)。其依据为 `concepts/forest-courtyard-breakdown-v001`，与下列早期程序建模版本分别保存。

| 房间 | 说明 | Blender 原生工程 |
| --- | --- | --- |
| 日照林庭 | [资源与替换说明](sunlit_forest_court/README.md) | [sunlit_forest_court_art_v001.blend](sunlit_forest_court/blender/sunlit_forest_court_art_v001.blend) |
| 清泉回廊 | [资源与替换说明](springwater_cloister/README.md) | [springwater_cloister_art_v001.blend](springwater_cloister/blender/springwater_cloister_art_v001.blend) |

概念原图分别为 [01_sunlit_forest_court.png](../../../concepts/combat_rooms/v003/01_sunlit_forest_court.png) 与 [02_springwater_cloister.png](../../../concepts/combat_rooms/v003/02_springwater_cloister.png)。每个房间的 `reference/` 另存对应制作参考；原概念图不等同于 Blender 渲染或 Godot 实机截图。

## 已建立的内容与编辑方式

- 日照林庭：大石板庭院、叶纹圆章、两条延伸通路、石拱门、栏杆方柱、台阶神龛、旗帜灯笼、浅水反光及边缘林地。
- 清泉回廊：高拱廊、柱脚檐线、圆形铺地、通路台阶、后侧和右侧水渠、狮首壁泉、石碗、落水/溢流、荷叶及林地植物。
- 两场景均使用独立的建筑、地板、装饰、植物、灯光、相机、气氛与替换物件集合。植物为可编辑几何；地面向视野外延伸，不采用漂浮展示底座。
- 打开 `.blend` 可直接调整物件尺寸、摆放、材质、光源与相机。`scripts/` 保留可复现的生成脚本；重新运行脚本会重新生成场景，手动精修前应另存新版本。

## 预览与验证记录

以下四张 Blender 正式渲染已输出，并已核对图片尺寸。带 `_draft` 的图是中间构图检查，不替代正式预览。

| 房间 | 全景 · 1920 × 1080 | 细节 · 1600 × 1000 |
| --- | --- | --- |
| 日照林庭 | [sunlit_forest_court_v001.png](sunlit_forest_court/previews/sunlit_forest_court_v001.png) | [sunlit_forest_court_v001_detail.png](sunlit_forest_court/previews/sunlit_forest_court_v001_detail.png) |
| 清泉回廊 | [springwater_cloister_v001.png](springwater_cloister/previews/springwater_cloister_v001.png) | [springwater_cloister_v001_detail.png](springwater_cloister/previews/springwater_cloister_v001_detail.png) |

两个 `.blend` 均已重新打开，文件、几何和贴图检查未报告失败。检查记录入口：[日照林庭验证](sunlit_forest_court/reports/validation_v001.json)、[清泉回廊验证](springwater_cloister/reports/validation_v001.json)。构建日志、布局说明和源工程统计分别保留在各房间 `reports/`，本文不重复抄写易变化的测试数量。

## 复杂模型替换

两类雕塑均在 `Replacement_Props` 中，使用 `REPLACE_ANCHOR_...` 空物体作为替换锚点：

- 日照林庭：披风林地守护者，`prop.forest_keeper_statue`。
- 清泉回廊：狮首泉雕，`lion_head_fountain`。

当前雕塑已经具备可辨识形体，但尚未雕刻到概念图的细节精度。后续可用 Tripo 生成或手工雕刻模型替换锚点下的对应物件，保留锚点变换和周围建筑。水束、神龛、壁泉底座等独立构件不需要随雕像一起替换。

## 材质来源与打包

石面采用 Poly Haven 的 **worn_rock_natural_01**，外围地表采用 **leafy_grass**；均为 2K、CC0 素材。来源链接、下载文件与校验记录见 [material_sources.json](shared/reports/material_sources.json)。原始图片保留在 `shared/textures/`。

每个 `.blend` 已打包两套材质使用的共六张图片——基础色、粗糙度、OpenGL 法线各一张——可在房间构建和验证报告中复核。源目录另外保留的高度图不代表场景已使用位移。

## 交付边界

这是 **Blender 可编辑美术源场景**。程序材质、叶片透光、水面、落水表现、体积雾及光照需要在 Godot 中重建，或按选定流程烘焙后再制作运行材质。此次没有导出运行模型、没有接入引擎，也没有确认游戏运行性能。

正式做成游戏房间前，仍需制作和验证碰撞、导航、出口连接、遮挡处理、模块切分、LOD/实例化与材质预算。场景中的美术布局标记不是玩法配置或可用的寻路数据。
