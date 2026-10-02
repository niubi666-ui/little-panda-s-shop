# 闪电与雷霆刀光 · Blender 源稿与 Godot 烘焙

## 本轮实际完成

- **闪电**：四束细长白蓝电流，间隔较大的通透负空间、稀疏分叉、细小电屑。
- **雷霆**：三束更粗、折角更大的紫白主电弧，交织金色分叉及断裂横向脉冲，电屑更粗且数量更多。
- 两套均为本轮新制作的路径形态；没有沿用已有刀光贴图再换色，没有使用下载的特效素材。
- Blender 实际建立可编辑节点材质、160° UV 弧面、示意长剑、独立碎电光曲线、灯光与相机；使用 Cycles EMIT 烘焙，使用 EEVEE 渲染样片。
- Godot 侧只提供表现资源：共用项目已有 `golden_effect.gd`、`baked_trail.gdshader`，不新增战斗规则、伤害或属性判定。

## 文件位置

| 用途 | 文件 |
|---|---|
| 闪电 Blender 源稿 | `blender/lightning_slash.blend` |
| 雷霆 Blender 源稿 | `blender/thunder_slash.blend` |
| 实际渲染 | `renders/lightning_hero.png`、`renders/thunder_hero.png` |
| 可重新运行的生成／烘焙程序 | `build_electric_slashes.py` |
| 四阶段路径记录 | `reports/lightning_paths.json`、`reports/thunder_paths.json` |
| 烘焙范围、HDR峰值、哈希记录 | `reports/bake_manifest.json` |
| 源纹理副本 | `textures/lightning/`、`textures/thunder/` |
| 引擎纹理 | `game/assets/vfx/elemental_slashes_v001/lightning/`、`thunder/` |
| 引擎入口 | `res://presentation/combat/fx/elemental_slashes_v001/lightning/slash.tscn`、`thunder/slash.tscn` |

## 编辑方法与来源

`build_electric_slashes.py` 中 `SETTINGS` 控制主线数量、宽度、弯折、分叉数量、颜色与表现参数；`paths_for()` 生成确定性的折线与分叉。输入路径在 UV 空间以数学距离栅格化，分别保存主干、分叉、晕光三个通道。四个阶段输入图像已打包进 `.blend`。

Blender 材质中 `PHASE_SOURCE` 可替换为四张已打包输入图之一。`primary HDR radiance`、`secondary HDR radiance`、`halo HDR radiance` 节点可独立调整三层亮度与颜色。透明覆盖与 HDR 发光分开输出，最终由真正的 Cycles `EMIT` 烘焙生成 Godot 资源。

源稿展示的是独立静态弧面与四阶段材质源，不代表 Blender 骨骼动作已制作。Godot 的实际挥动轨迹、暂停和退场行为仍由现有表现脚本与 ActorView 驱动。

## 输出约定

- 每种效果：4 × 1024×256 场景线性 HDR `emission.exr`，以及对应 4 张线性灰度 `mask.png`。
- 源 UV：U=0 是最老尾迹，U=1 是当前剑身；V=0 是剑尖／外沿，V=1 是剑根／内沿。沿用项目现有 shader 中的 V 翻转。
- `tip_extension_ratio = 0.28`，只扩大可见特效，不能作为命中判定来源。
- 闪电尾迹寿命0.23秒、材质阶段速率13；雷霆尾迹寿命0.30秒、阶段速率10，均配置于各自 `.tscn`。
- 粒子由原圆火星改为细长 `PrismMesh` 电屑，分别设置白蓝与紫金渐变；未修改共有脚本。

## 实际验证

- 使用 Blender 5.2.1 LTS 后台运行成功；两套 `.blend`、两张 hero 图及16个烘焙文件均写出。
- 已查看实际渲染：闪电细线与雷霆粗束／金色叉线在相同弧面、相同镜头下形态不同；剑与刀光朝向一致。
- 四阶段烘焙文件哈希不同；mask 有透明区域且最大值为1；EXR 发光值高于1，保留 HDR。
- Godot 纹理导入及训练场实际运行由整合任务统一进行，本子任务没有启动全项目导入或修改训练场／UI。

复现命令：

```powershell
& 'E:/blender/blender.exe' --background --factory-startup --disable-autoexec --python 'E:/ShopGame/source_assets/vfx/elemental_slashes_v001/lightning_thunder/build_electric_slashes.py'
```

注意：复现会更新本目录生成稿以及两种效果的新 Godot 资源。不要在整合者正在导入这些资源时并行重跑。
