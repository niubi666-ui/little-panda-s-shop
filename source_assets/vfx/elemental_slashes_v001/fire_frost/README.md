# 火焰与冰霜刀光 · Blender 制作 / Godot 烘焙资源

制作日期：2026-09-26。两个独立可选效果，复用项目已验证的拖尾采样与战斗表现接口。

## Blender 查看

- `blender/fire_study.blend`：翻卷火焰，四条流动的高温主纹、独立的短焰舌与细小余烬。
- `blender/frost_study.blend`：冰晶刃，长三角晶片、Voronoi 切面裂纹、冷蓝白碎片。
- `previews/fire_hero.png`、`previews/frost_hero.png`：对应工程实际渲染，160° 弧面用于材质检视。
- 两个工程保留可编辑原生 Shader 节点、UV 弧面、长剑展示、灯光和相机。1–60 帧可查看材质流动。
- `previews/*_baked_contact.png`：四个烘焙时刻的颜色与透明度合成检视。

这里的渲染用于材质与造型检查，不是 Godot 战斗截图。弧面角度不会修改任何伤害判定。

## 制作来源

先检查了用户提供的 Trail FXs v2 材质 15，并在初次渲染发现覆盖过满。因此交付火焰改用本次新建的程序节点：分层曲线焰舌、独立分叉短焰、噪声扰动和热度色阶。冰霜也是本次制作的新节点图，通过尖三角遮罩与切面纹理形成晶体。

最终两款贴图均来自 Blender Cycles 的实际 EMIT 烘焙，没有把供应方缩略图当成运行时纹理。保留源预设探索函数只为说明制作过程，默认构建过程不使用其材质。无需安装插件，也未修改用户原始资产或 live Blender 场景。

## Godot 交付

入口：

- `res://presentation/combat/fx/elemental_slashes_v001/fire/slash.tscn`
- `res://presentation/combat/fx/elemental_slashes_v001/frost/slash.tscn`

每款纹理位于 `game/assets/vfx/elemental_slashes_v001/<名称>/`：四张 1024×256 线性 HDR emission EXR 与四张线性 mask PNG。烘焙结果与 SHA256 见 `bake_manifest.json`。

UV 约定：U=0 尾端、U=1 当前剑刃；V=0 剑尖外缘、V=1 剑根内缘。既有 `baked_trail.gdshader` 负责运行时 V 翻转和四时刻插值。

两款均复用 `golden_effect.gd` / `preset_effect.gd`，保持 `configure_blade`、`sample_current_pose`、`finish_at_current_pose` 等接口；`tip_extension_ratio=0.28`。火焰尾迹 0.31 秒，冰霜尾迹 0.28 秒。每款独立 `.tres` 保存亮度，独立 `.tscn` 保存粒子、拖尾参数。

火焰运行时使用小余烬粒子，冰霜使用四面锥体晶片粒子。Blender 的碎片布景仅展示造型，Godot 使用真实运行时粒子，不烘入背景。

## 重建

1. Blender 后台运行 `scripts/build_and_bake.py`：创建源工程、渲染预览、输出贴图并复制到各自 Godot 资产目录。
2. Python 运行 `scripts/write_runtime.py`：生成两款独立场景与 ShaderMaterial。
3. 主整合者负责训练场选项、中英文名称及 Godot 运行验证。

本子任务不修改 UI、翻译、玩法范围或其他特效资源。整合后的实际攻击半径与 UI 验收由主任务记录。
