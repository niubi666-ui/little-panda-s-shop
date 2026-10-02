# 古树圣庭 Blender 场景 v002

2026-09-29。依据用户本轮四张参考图重新组装，待用户对实际渲染评审。v001 保留为历史稿。

## 打开与评审

- 可编辑场景：`blender/grand_forest_sanctuary_v002.blend`。
- `Camera_Panorama`：检查完整庭院的布局，不是未来游戏的默认镜头。
- `Camera_Gameplay`：26 米正交宽度，场景延伸出镜头；小熊猫为从当前游戏资源读取的静态比例参考，高约 1.2 米。
- `Camera_East_Gateway`、`Camera_North_Reverse`、`Camera_Shrine_Detail`：从其他方位检查同一三维场景。
- `previews/` 内为 Blender Cycles 实际渲染。带 `draft_` 的文件是制作过程，不能作为最终版本。

## 本版内容

- 主庭院控制范围 36×32 米、包围范围 1152 平方米，为旧庭院 18×16 米的四倍；转角切除后主铺装轮廓约 1105 平方米（约 3.84 倍），不含外围道路。该面积不是扣除花坛与树根后的可行走面积。
- 西北古树、朝南神龛、东侧双柱之间的道路、西侧两条独立道路、南入口。
- 三处叶纹地面、三组低墙花园、蕨类和白花为主的林缘、苔藓、碎叶、岩石、独立箱桶宝箱。
- 暖日光、凉色环境填充、树冠阴影、灯火与少量体积雾。`Lighting_Gobos` 为美术灯光用的画外叶影几何，不是玩法障碍。
- 新树直接采用 `sunlit_forest_court/tree_foliage_v005` 的模型、UV 与材质，每棵树 29,768 三角面。主树整体缩放摆放；周边树复用网格与材质。

## 来源与归档

- `original/forest_yard_item.blend`：本轮源库只读快照，原始投递文件未覆盖。
- `reference/`：本轮四张批准的概念方位图。全景图控制布局；不同生成方位图有透视/数量差异，不作为精确测量图。
- 模型来源对应 UUID、用量、源文件 SHA256、面积与主角高度：`reports/build_report.json`。
- `textures/`：本轮场景提取的配套贴图，同时打包进 `.blend`。
- 古铜灯复用 `forest_courtyard/v001` 的已批准源资产；石材与林地材质使用 shared 中现有的 Poly Haven CC0 贴图。

## 复现与验证

在独立 Blender 后台进程中运行 `scripts/build_sanctuary.py`，它调用本目录 `assembly.py`、`player_reference.py`、`refinements.py`，并只读取 shared 制作辅助库。原始源文件与 `game/` 不写入。

打开本版 `.blend` 后可用 `scripts/render.py -- panorama` / `gameplay` / `east` / `north` / `detail` 渲染，GPU 渲染应逐个执行。运行 `scripts/validate.py` 检查源文件哈希、贴图、树面数、主角比例与场景尺寸；结果见 `reports/validation.json`。

这是一份高细节 Blender 美术源场景。实例展开后的全场景面数包含大量重复花草，并非已经优化的 Godot 运行资源。未建立碰撞、导航、随机生成、LOD，也未进行游戏帧率验证；概念图里的敌人没有在此轮制作。
