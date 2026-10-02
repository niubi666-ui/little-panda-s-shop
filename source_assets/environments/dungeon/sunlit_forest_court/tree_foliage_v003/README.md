# 圣树立体叶团 v003

用户要求改进 v002 的贴图感，并允许增加面数。本次保留原始树干，新建立体叶团版本，v001/v002 均保留，未修改 Godot。

## 改动

- 叶团内部：7 张弯曲交叉枝叶卡，每张 24 三角面。
- 叶团外层：288 张独立短阔叶片卡，每片 12 三角面，具有中脉折线、杯状弯曲、叶尖卷曲，使用真实几何法线。
- 每模块 16 根细枝连接各叶片，提供空间支撑。
- 6 种模块共享网格和两张 RGBA 图集，叶片分别受光、遮挡和投影。
- 新单叶图集用内置 imagegen 生成；提示词见 reports/single_leaf_prompt.md。整树与近景图片均为真实 Cycles 渲染。
- 树干仍采用 10 米高评审尺寸，叶长约 0.16–0.24 米，实例缩放另有变化。

## 交付文件

- blender/sacred_oak_foliage_v003.blend
- previews/tree_hero.png
- previews/tree_gameplay_angle.png
- previews/leaf_cluster_detail.png
- reports/build_report.json：实际实例和三角面统计。
- scripts/build_tree.py + module_geometry.py：重建及渲染脚本。

原始树干来源：../tree_foliage_v001/original/tree_import_snapshot.blend。材质贴图在本版本 textures/，同时打包在 blend 内。隐藏母版位于 LIBRARY_six_modules_hidden，树冠实例在 CROWN_compact_oak_clusters；REVIEW_stage_not_export 不作为游戏资源。

## 当前边界

较高面数版本用于验证圣树的美术效果，不代表适合全场景重复摆放。未制作 LOD、风动画或运行材质，也未测量 Godot 帧率。图集仍含少量表面明暗信息；不能保证与概念图完全一致，原始树干形状和枝条位置也影响结果。原始 Tripo 树干没有重新烘焙或重拓扑。
