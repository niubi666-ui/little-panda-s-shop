# 圣树枝叶模块试作 v001

用户提供的 Tripo 树干 + Blender 低模枝叶面片。仅美术原型，未接入 Godot。

## 文件

- `blender/sacred_oak_foliage_v001.blend`：完整树木与独立评审灯光/地面。
- `original/tree_import_snapshot.blend`：从用户 Blender 当前未保存状态捕获的模型副本。磁盘上的原始 tree.blend 未覆盖。
- `textures/oak_branch_atlas_rgba.png`：2048×2048，四种枝叶区域共用一张 RGBA 图集；程序绘制叶形、叶脉和细枝，非高模烘焙。
- `previews/tree_hero.png`、`tree_gameplay_angle.png`：实际 Cycles 渲染，不是概念生成图。
- `previews/tree_sparse_draft.png`：早期稀疏版本留档。
- `reports/build_report.json`：源快照哈希及实际几何统计。
- `scripts/make_atlas.py`：通过 Pillow 从零绘制图集。
- `scripts/build_tree.py`：从源快照重建树冠并渲染，使用独立 Blender 后台进程。

## 编辑

`TREE_CROWN_linked_modules` 中的叶簇复用四份 mesh，每簇 60 个三角面，可逐簇移动、旋转、缩放。`LIBRARY_four_leaf_modules_hidden` 保存隐藏母版；修改母版网格影响对应实例。树干保留原网格，仅缩放为 10 米高供评审，不代表关卡最终比例。

`REVIEW_STAGE_not_game_asset` 是评审地面/灯光/相机，不能当游戏资源导出。树干和树冠分开组织，未添加风动画、碰撞或 LOD。

## 限制

本轮验证制作链与造型，未做 Godot 性能测试；减少几何不代表透明叠层和阴影成本消失。当前 Cycles 材质用透明与表面混合，游戏材质需另外配置 Alpha Scissor 或适合的裁剪方案，不能假定直接导出会一致。树叶近距离细节、透光以及最终疏密待用户评审；图集不是照片级叶材质。没有执行树干高低模法线烘焙。
