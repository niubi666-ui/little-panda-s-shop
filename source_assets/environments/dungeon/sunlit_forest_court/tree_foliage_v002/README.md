# 圣树树冠重制 v002

用户否定 v001 的叶形和整体风格。本版本以本轮圣树参考图为方向重新制作，保留原始树干网格，未修改 Godot。

## 参考分析与改动

- 参考是短阔、圆裂片的小橡树叶；v001 的长条羽状排列和过大叶片不符合目标。
- 参考树冠是多个枝梢团簇组成，粗枝之间有明显空隙；v001 在过多内部枝面铺叶，轮廓单一。
- 新图集为四种不规则分叉短枝簇，共享 RGBA，图像由内置 imagegen 根据用户参考制作；不是高模烘焙或实拍扫描。提示词见 reports/atlas_prompt.md。
- 六种可复用立体模块，每模块 30 张小弯折枝簇面片、240 三角面；局部球形自定义法线用于减弱整片受光痕迹。
- 沿树枝外缘分布，保留中心粗枝，补充侧面低处叶团；降低高光，采用接近参考的中性暖灰摄影环境。

## 交付

- blender/sacred_oak_foliage_v002.blend：独立保存的工作文件。
- textures/oak_compact_sprays_rgba.png：生成的透明图集，实际尺寸见 reports/build_report.json。
- previews/tree_hero.png：实际 Blender Cycles 正面渲染。
- previews/tree_gameplay_angle.png：实际 Blender Cycles 斜俯视渲染。
- previews/tree_draft_cards.png：重制过程草稿，不是最终版本。
- scripts/build_tree.py：独立后台 Blender 可重建脚本。

## 编辑与限制

树冠在 CROWN_compact_oak_clusters；六份母版在隐藏集合 LIBRARY_six_modules_hidden。实例共享 mesh，修改母版会同步影响实例。REVIEW_stage_not_export 是评审用相机灯光和地面。

原始导入副本仍在 ../tree_foliage_v001/original/tree_import_snapshot.blend，v001 完整保留。树干按 10 米高展示；不是关卡最终尺寸。树干原有轮廓和细节仍受 Tripo 结果限制。

本版本用于美术评审，未承诺与参考完全一致。未制作风动画、LOD，未进行 Godot 导入及运行性能验证；运行时透明裁剪、法线和背面受光需要引擎材质配置。透明叠层仍有成本，三角面统计不代表帧率。
