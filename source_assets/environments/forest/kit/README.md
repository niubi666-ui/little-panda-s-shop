# 森林素材库（forest_kit.blend）

所有森林场景共用的素材。打开文件看到的是 `Preview` 集合：每个素材摆一份实例，按网格排开，方便浏览。
素材原件在 `Kit` 集合里（已从视图排除，都在原点，**不要挪动原件的位置**，场景里的实例以它为准）。

- 在别的 Blender 文件里用：偏好设置 → 文件路径 → 资产库，添加本文件夹；资产浏览器里按目录找，拖进场景时选“链接”。
- 改了素材后，用 `../tools/forest_export.py -- kit` 重新导出给游戏（命令见上级 README）。
- `Kit_helpers` 是素材依赖的辅助集合（樱花叶粒子的实例源等），不是资产，别删。
- 贴图：打包在文件里的是 BlenderKit 原始贴图；`textures/` 里是减面时烘焙的贴图和面片图集，`textures/bled/` 是导出时自动生成的镂空贴图底色修正版。

## 素材清单

面数是三角面。“樱花林空地”一列表示现有场景是否用到。

| 名字 | 中文 | 目录 | 面数 | 樱花林空地 |
| --- | --- | --- | ---: | :---: |
| tree_a | 森林树 A | 树木 | 43,619 | ✓ |
| tree_b | 森林树 B（带樱花叶粒子） | 树木 | 44,621 | |
| tree_c | 松树 | 树木 | 41,451 | ✓ |
| blossom | 开花樱树 | 树木 | 20,287 | ✓ |
| blossom_parts | 樱树花簇零件 | 树木 | 7,008 | |
| fern_big | 大蕨 | 灌木与蕨类 | 48,755 | |
| fern_a | 蕨类 A | 灌木与蕨类 | 679 | ✓ |
| fern_b | 蕨类 B | 灌木与蕨类 | 160 | ✓ |
| bush | 灌木 | 灌木与蕨类 | 14,806 | ✓ |
| shrub | 红叶灌木 | 灌木与蕨类 | 14,384 | ✓ |
| grass_a | 草丛面片 | 草与花 | 8 | ✓ |
| grass_b | 高草丛 | 草与花 | 419 | ✓ |
| flowers_white / violet / pink / gold / blue / red | 白 / 紫 / 粉 / 金 / 蓝 / 红花丛 | 草与花 | 8 | ✓ |
| daisies | 雏菊 | 草与花 | 8 | ✓ |
| poppy | 罂粟（偏风格化，没用） | 草与花 | 4,528 | |
| boulder | 苔藓大石 | 石头 | 5,000 | ✓ |
| rock | 苔石 | 石头 | 1,499 | ✓ |
| moss_stone | 苔藓石 | 石头 | 5,999 | ✓ |
| log_a | 扫描倒木（长 5.5 米） | 倒木与树桩 | 37,694 | |
| log_b | 倒木 | 倒木与树桩 | 5,775 | ✓ |
| stump | 树桩 | 倒木与树桩 | 2,499 | ✓ |
| pillar | 古石柱 | 遗迹与人造物 | 3,999 | ✓ |
| ruin | 石柱遗迹 | 遗迹与人造物 | 79,660 | |
| lantern | 旧提灯 | 遗迹与人造物 | 4,003 | ✓ |
| bridge | 小木桥 | 遗迹与人造物 | 3,556 | ✓（游戏里已隐藏） |
| river_rocks | 溪石 | 水边 | 8,000 | ✓ |
| lily | 睡莲 | 水边 | 1,264 | ✓ |
| toadstool | 毒蝇伞 | 小生物与小物件 | 2,999 | ✓ |
| butterfly | 蝴蝶 | 小生物与小物件 | 2,114 | ✓ |

来源都是 BlenderKit 免费资产（可商用），减面和烘焙过程见 [../lookdev/README.md](../lookdev/README.md)。
没收进素材库的：高模原件（留在 lookdev 文件里）、木雕鸟（风格不符，已否掉）。

## 2026-10-18 新增的素材

当初为樱花溪谷、巨树根洞、神木圣坛准备的。这三个场景已删除（用户不满意，重新来过），素材先留在库里备用，“用在”一列是当时的用途。

| 名字 | 中文 | 目录 | 来源 | 用在 |
| --- | --- | --- | --- | --- |
| cliff_wall | 苔藓岩壁（46 米长的扫描岩壁，用时缩小） | 石头 | BlenderKit Moss Rock Wall，减面到 1.6 万 | 樱花溪谷瀑布 |
| cliff_low | 深色岩块 | 石头 | BlenderKit Rock Cliff Low Poly | 樱花溪谷瀑布两侧 |
| slab | 地衣平石板 | 石头 | BlenderKit Flat Shaped Stone，减面 | 溪谷过溪石板、空地里的平石 |
| flat_rock | 平顶大石 | 石头 | BlenderKit Big Flat Rock，减面 | 暂未使用 |
| flat_stone | 小扁石 | 石头 | BlenderKit Small Flat Stone 2 | 溪谷溪边 |
| ancient_trunk | 古树干（带根盘） | 倒木与树桩 | BlenderKit Ancient Tree Trunk，减面 | 根洞的巨树、空地里的大树桩 |
| buttress_trunk / root_trunk / gnarled_roots | 板根树干 / 露根树干 / 盘结树根 | 倒木与树桩 | BlenderKit 扫描件 | 暂未使用 |
| giant_roots | 铺地树根 | 倒木与树桩 | BlenderKit Gaint Roots Tree | 神木根部 |
| root_arch_a / root_arch_b | 树根拱（大 / 小） | 倒木与树桩 | 程序生成（`tools/make_root_assets.py`），苔藓树皮贴图 | 根洞的两个出口 |
| root_coil | 贴地矮树根 | 倒木与树桩 | 程序生成 | 根洞 |
| fallen_trunk | 粗大倒木（带断根） | 倒木与树桩 | 程序生成 | 根洞空地里的障碍 |
| glow_mushroom | 发光小蘑菇丛（自发光） | 小生物与小物件 | 程序生成 | 根洞 |
| temple_column | 雕花神殿石柱（双柱） | 遗迹与人造物 | BlenderKit Carved Temple Column | 圣坛一圈石柱 |
| archway | 石拱门 | 遗迹与人造物 | BlenderKit Stone Archway | 圣坛两道拱门 |
| banyan_trunk | 古榕树干 | 树木 | BlenderKit Ancient Banyan Trunk，141 万面减到 2.4 万 | 神木的根盘 |
| broken_column | 断柱（矮） | 遗迹与人造物 | 程序生成（`tools/make_ruin_assets.py`），石灰岩贴图 | 圣坛石台上的障碍 |
| column_drum | 倒地柱段 | 遗迹与人造物 | 程序生成 | 圣坛 |

新增的地面材质（场景导出时从这里取贴图）：Clover Ground Cover、Meadow Grass With Daisies（雏菊草地）、Muddy ground with moss（湿泥苔藓）、
Mossy Tree Bark（苔藓树皮，树根拱用）、Natural Eroded Limestone（石灰岩，圣坛石台和断柱用），
以及暂未使用的 Weathered Stone Pavement Tile、Stone floor/paving。

加素材的流程：BlenderKit 下载 → 在开着的 Blender 里跑 `tools/prepare_downloads.py`（合并、减面、原点放到底面中心、贴图打包，写到 `kit/incoming/`）
→ `tools/add_to_kit.py` 收进素材库（顺手修 UV 节点名对不上的问题；收完可以删掉 `kit/incoming/`）→ `tools/preview_assets.py` 渲预览检查 → `tools/forest_export.py -- kit` 导出。
