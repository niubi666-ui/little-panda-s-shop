# Blender 刀光与火星样片

日期：2026-09-26。状态：Blender 美术验证，尚未接入 Godot，也未匹配小熊猫的攻击动画。

## 交付入口

- `blender/sword_trail_study.blend`：可编辑场景，已打包几何节点仿真缓存。
- `previews/final/01_Golden_Filaments.mp4`：金色破碎流光。
- `previews/final/02_Ember_Brush.mp4`：较厚的焰纹拖尾对照。
- 同名 PNG：第 99 帧的实际 Blender 渲染。

视频均为 1280×720、30 fps、150 帧（5 秒），无音轨。前半段快速挥砍，后半段放慢展示；包含粒子散落及拖尾消散。金色仅用于这次美术验证，不代表已确定技能元素。

## 素材来源与制作内容

使用用户放入 `original/` 的 Trail FXs v2 素材库：

- `TrailFXs_Blades.blend` 的 `Trail_Blade` 几何节点、06 与 14 号程序材质。
- `TrailFXs_Blades_Particles.blend` 的 `Trail_Blade_Particles`。
- 项目现有 `source_assets/weapons/longsword/v001/longsword_v001.blend`。

这些效果是原生 Geometry Nodes 与材质预设，本次不需要另行下载或安装插件。原素材保持不变；节点与程序纹理并非本次从零原创。新增内容包括挥剑运动、剑刃参考线匹配、拖尾透明度收束、粒子参数、长剑姿态、灯光与相机、打包缓存和视频展示。

修复了素材参考线上遗留的 Child Of 约束，避免原演示动作与新动作叠加。重新计算了剑身变换后的面法线。

## Blender 使用

打开正式 blend 后，空格播放 1–150 帧。场景初始停在第 99 帧便于查看。

- `SWING_Control`：剑的展示动作。
- `REFERENCE_Sword_Edge`：独立关键帧参考线，其动作与剑一致；只改剑动作时必须同步参考线。
- `FX_01_Flowing_Blade`：主刀光。修改器的 Material 可在 `01_Golden_Filaments` 与 `02_Ember_Brush` 间切换。
- `FX_02_Scattered_Sparks`：散落火星。

修改运动、参考线、寿命或粒子生成参数后，删除并重新烘焙模拟缓存。仅切换材质无需重烘焙。此场景使用 Blender 5.2.1 的修改器输入接口。

## 验证与边界

重新打开正式文件，在第 15、20、85、95、99、105、135 帧检查几何：拖影最新端包含剑尖位置，测得距离为 0；另渲染快速挥砍、后期拖尾及消散帧进行检查，见 `reports/final_validation.json` 和 `previews/final/check_*.png`。

这验证了样片轨迹与剑刃的匹配，尚不代表玩家角色动作、战斗命中、Godot 性能或运行时效果已验证。Blender 几何节点和材质不能直接作为 Godot 运行时技能；后续需按选定外观重建 Shader、拖尾网格和 GPUParticles3D。

本轮写入仅限本目录；店铺家具逻辑由另一个对话负责。打开样片前，将当时未保存的 Blender 场景另存副本到 `reports/live_before_study.blend`。

## 重建与中间文件

先运行 `reports/build_trail_study_v002.py` 生成修复后的基础场景，再运行 `reports/finalize_study.py -- --video` 输出正式样片。`study_v001`、`study_v002` 与诊断脚本为制作中间版本，不作为交付效果。最终入口以本说明为准。
