# 写实森林样板间（2026-10-13）

> 2026-10-18：本文件夹从 `source_assets/lookdev_forest_v1/` 搬到这里，作为森林素材库的**来源和加工记录**。
> 现在进游戏的是 `../kit/forest_kit.blend`（素材库）和 `../rooms/sakura_glade/sakura_glade.blend`（樱花林空地），
> 导出用 `../tools/forest_export.py`，说明见 [../README.md](../README.md)。下面的生成脚本保留可重跑，但平时不需要再用。
> 渲染脚本 `render_looks.py`、`render_game_views.py`、`render_game_views_debug.py` 已挪到 `../tools/`。

用来挑画面风格的 Blender 场景，只在 Blender 里，没有接进 Godot。

- `forest_lookdev.blend`：场景本体。资产原件在 `Library` 集合（已从视图层排除），布景在 `Layout` 集合，全是集合实例。
- `build_scene.py`：布景脚本。在**已经下载好资产的那个 Blender 会话里**运行，可重复执行；改树、草、石头的位置和数量都在这里。
- `../tools/render_looks.py`：三种光照方案（`golden` 金色逆光 / `daylight` 明亮白天 / `dusk` 蓝调黄昏），只加灯光、天空、雾和调色，不改布景。
- `renders/`：输出图。

渲染：

```powershell
& 'E:\blender\blender.exe' --background source_assets/environments/forest/lookdev/forest_lookdev.blend --python source_assets/environments/forest/tools/render_looks.py -- source_assets/environments/forest/lookdev/renders golden,daylight,dusk 1920 cycles 160
```

最后两个参数是引擎（`cycles` 或 `eevee`）和采样数。

## 童话森林版（fairy_forest.blend）

在同一套资产上另存的一份，原来的 `forest_lookdev.blend` 没动。

- `build_fairy.py`：布景脚本，同样要在持有资产的 Blender 会话里、打开 `fairy_forest.blend` 运行。
- 新增内容：一条横穿画面的小溪（挖出的河床 + 透明水面 + 溪石 + 睡莲）、小木桥、开花的树、按颜色成片的野花（紫、粉、金、蓝是白花的染色副本）、雏菊、毒蝇伞、蝴蝶、空气里的光尘。
- 光照方案是 `render_looks.py` 里的 `fairy`：保留金色主光束，但阴影被天光提亮成通透的青绿色，雾更薄。
- 渲染命令把文件名换成 `fairy_forest.blend`，光照写 `fairy`，最后再加一个输出前缀参数，例如 `... fairy 1920 cycles 128 fairy`。
- 新增资产（BlenderKit 免费）：Blossoming Tree、Marguerite flowers、poppy、Mushroom II (Amanita muscaria)、Common Blue Butterfly、Wooden Bridge（改成了旧木色）、Sharp River Rocks、Low Poly Water Lily。
- 溪床是单独一条网格（`BrookBed`），用溪石扫描贴图平铺、压暗、调成湿润反光，两岸羽化进苔藓。没有它，透明的水只会透出绿色苔藓，看不出是水。
- 没放进去：罂粟（资产偏风格化，颜色太平，换成了染红的野花）。
- 没放进去：鸟。搜到的免费鸟只有木雕摆件，放进写实场景很假，已去掉。

## 减面优化版（fairy_forest_opt.blend）

为进 Godot 做准备，从 `fairy_forest.blend` 另存。高模原件没删，在 `HighPoly_originals` 集合里。

- `optimize_step1.py`（第一步，已完成）：花树的花簇和密草丛换成贴图面片。做法是把每个资产单独拍正面和顶面两张带透明的照片，拼成一张图集（`textures/blossom_cards.png`、`textures/grass_cards.png`），再用几个交叉平面代替原模型。花簇每个 6 面，草丛每个 8 面。
- 结果：全场景 4802 万面 → 1632 万面。花树单棵 483 万 → 6.2 万（剩下的是树干），草丛单个 1.3 万 → 8。
- 运行：`blender --background fairy_forest.blend --python optimize_step1.py`，每次都从高模文件重新生成优化版。
- `optimize_step2.py`（第二步，已完成）：扫描模型减面加烘焙。对每个扫描件复制一份、塌陷到面数预算、重新展 UV，再把原件的颜色、表面细节（切线空间法线贴图）和粗糙度烘焙到低模上。每个资产输出三张图到 `textures/<名字>_baked_*.png`，材质合并为一个。
  - 苔石 3.7 万 → 1500；溪石 12.1 万 → 8000；大石头 32.7 万 → 5000；苔藓石 13.4 万 → 6000；石柱 5.9 万 → 4000；树桩 7.9 万 → 2500。
  - 毒蝇伞是建模件而不是扫描件，由很多小零件组成，重新展 UV 会碎成渣，所以只做塌陷（12.9 万 → 3000），保留原 UV 和 6 个材质。
  - 展 UV 的窍门：扫描表面凹凸不平，直接投影会碎成几千个小岛。脚本先把同一个网格临时抹平再展开，拓扑不变所以 UV 能原样带回。
  - 结果：全场景 1632 万面 → 924 万面。
  - 运行：`blender --background fairy_forest_opt.blend --python optimize_step2.py`（在第一步的结果上执行；已处理过的资产会跳过）。
- `optimize_step3.py`（第三步，已完成）：树、灌木、蕨类、野花和零碎。
  - 树干和枝条：先删掉最细的小枝（按表面积保留最大的 60%），再做适度塌陷。不能直接按面数预算塌陷：树干由几千根独立的管子组成，每根都有面数下限，要求低于下限时所有小枝会变成扁平碎片。
  - 树叶：叶片本来就是面片，删掉一部分、把剩下的放大，保持树冠覆盖率。森林树保留 42% 放大 1.55 倍，松树保留 30% 放大 1.85 倍。
  - 花树：2048 簇花的粒子系统合并成每棵树一个真实的树冠网格（1.2 万面），树干塌陷到 8000 面。Godot 读不了 Blender 粒子，这一步同时解决了导出问题。
  - 野花和雏菊：换成面片，7 个品种共用一张图集 `textures/flower_cards.png`。拍照前把花瓣材质里的白色透光层改成花瓣本色，否则均匀打光下所有颜色都会被冲成粉白。
  - 蕨类、另一种草、灌木枝条、提灯、地面：只塌陷，保留 UV 和材质。
  - 结果：全场景 924 万面 → 约 188 万面（含地面）。
  - 运行：`blender --background fairy_forest_opt.blend --python optimize_step3.py`（在第二步的结果上执行）。
- 三步合计：4802 万面 → 约 188 万面，约为原来的 1/26。剩余的大头是森林树（两种合计约 85 万面）和灌木（27 万面）。

## 游戏版基础脚本（build_game_arena.py）

- 第二版脚本的基础：空地布局（中间 19×16 米平地、遗迹和高树在后方、溪水木桥在近景）、地面网格、材质简化和 glTF 导出都在这里。**不能删**。
- 它单独运行生成的第一版场地（`fairy_arena_game.blend`、`game/assets/fairy_forest/`）已于 2026-10-14 删除。

## 游戏版（fairy_arena_game_v2.blend，当前进游戏的版本）

- `build_game_arena_v2.py`：沿用第一版的空地布局，按样板间的方式在空地里铺草甸（成丛的高草）和单色花丛，边缘的蕨类和高草更密，溪边多两棵花树。
  - 地面换成一个 Cycles 材质，公式和 Godot 的 `terrain.gdshader` 一样，所以这个文件的渲染图就是 Godot 画面的对照目标。
  - 导出时修正镂空贴图透明区域的底色（`textures/bled/`），否则草叶在 Godot 里远看会变成银灰色。
  - 运行：`blender --background fairy_forest_opt.blend --python build_game_arena_v2.py -- E:\ShopGame\game\assets\fairy_forest_v2`，约 6 分钟。
- `../tools/render_game_views.py`：用 Cycles 按游戏镜头的机位渲染对照图（`game` `far` `ruin` `bridge` `hero` `top`），输出到 `builds/lookdev/<机位>_cycles.png`。
  - 运行：`blender --background fairy_arena_game_v2.blend --python render_game_views.py -- E:\ShopGame\builds\lookdev [机位,机位] [采样数]`。
- `../tools/render_game_views_debug.py`：同上，但只开太阳（`sun`）、只开光束灯（`key`）、只开天光（`sky`）或去掉雾（`nofog`），可选隐藏某些资产，用来逐项核对光影。
- Godot 一侧的同机位截图：`game/tests/fairy_lookdev_capture.gd`；对比流程见 `docs/COMBAT_VISUAL_PASS.md`。

## 资产来源

全部来自 BlenderKit 的免费资产（royalty free），贴图文件在 `C:\Users\<用户>\blenderkit_data`，没有打包进 blend：
Forest Tree、Pine Tree、Cinnamon Fern、Fern Plant、Realistic grass clump、High grass clump、Wild White Flower Patch、Bush、Wild Bush with Red Leaf Cluster、3D Scanned tree stump and fallen log、Fallen 3D Scanned tree 5.5m long、Tree Stump with Mushrooms、Ancient Mossy Stone Pillar、Moss Stone、Mossy Boulder Rock、Mossy Rock、Old lantern；材质 Forest Floor Moss、Mossy Ground。

下载了但没用上的：Birch Tree lowpoly（叶子的粒子实例丢失）、Tree Fern Large（太热带）、Old Stone Pillar Ruin Photoscan（贴图偏蓝）、Forest Ground Leaves。

## 注意

- 这是离线渲染（Cycles），画质是上限参考。Godot 实时画面做不到完全一样，体积光、软阴影和植被密度都要打折。
- 样板间原稿（`forest_lookdev.blend`、`fairy_forest.blend`）约 1300 个实例，单棵树 10–20 万面，只用于出图；进游戏的是上面的减面版和游戏版。
