# 圣树 3 万面以内 / 叶色提亮 v005

用户允许 3 万面以内并希望叶色参考圣树图更亮。本版本采用更严格的整棵树预算：树干 19032 + 树冠 10736 = **29768 三角面**（不含评审地面）。

## 改动

- 每叶团 4 张弯曲卡片，每张 24 三角面；增加杯状弯曲与扭转。
- 每叶团 20 张独立折弯边缘叶，每张 4 三角面；单模块 176 三角面，61 个实例复用 6 份 mesh。
- 使用 v004 从高模烘焙的颜色/法线图集，独立边缘叶沿用单叶图集。
- 仅在叶材质上提亮中间调并调整绿色，树皮与照明保留，未用发光冒充叶色。参数见 reports/optimization.json。
- 保留 wind_rgba 权重；没有接入风 shader。

## 文件

- blender/sacred_oak_balanced_v005.blend
- previews/tree_hero.png、tree_gameplay_angle.png：真实 Cycles 渲染。
- scripts/build_tree.py：最终重建脚本。
- scripts/revise.py：初次从 v004 派生脚本的历史工具，不要重复执行；最终调色参数以 build_tree.py 为准。
- reports/optimization.json：面数及调色记录。

原始模型和 v001–v004 均保留，未改动 Godot。运行时帧率、透明叠层成本、LOD 切换尚未验证。此版本仍使用卡片，近景和侧视仍可能看出平面层叠，不宣称与原图完全相同。叶色调整目前在 Blender 材质节点中；以后接入 Godot 时需要移植或烘焙该调色。
