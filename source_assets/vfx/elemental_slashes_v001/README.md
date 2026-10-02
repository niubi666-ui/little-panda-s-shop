# 四款元素主题刀光与攻击范围修订

日期：2026-09-26。用户要求在 Blender 制作更多刀光加入训练场，并扩大命中范围、保留已认可的现有特效尺寸。

## 试玩与实机对比

店铺按 F6 进入训练场，在右上角「刀光测试」直接选择；共 11 项，默认仍为金色破碎流光。新增四款靠前排列：

| 选项 | 造型 | 稳定 ID | 场景目录 |
|---|---|---|---|
| 烈焰 · 翻卷焰刃 | 流动主焰、分叉短焰舌、余烬 | `element_fire` | `fire/` |
| 闪电 · 苍蓝电弧 | 纤细白蓝硬核、电弧分叉、电丝 | `element_lightning` | `lightning/` |
| 雷霆 · 紫金雷裂 | 粗紫白锯齿、多束交叉、金色支路 | `element_thunder` | `thunder/` |
| 冰霜 · 碎晶寒锋 | 尖锐晶片、切面裂纹、飞散碎冰 | `element_frost` | `frost/` |

场景位于 `game/presentation/combat/fx/elemental_slashes_v001/<目录>/slash.tscn`。

- [24 秒 Godot 实机对比](previews/elemental_combat.mp4)：1280×800、60 fps，每款包含正常挥砍、0.4 倍速近景和真实目标命中。
- 实机截图：[火焰](previews/element_fire.png)、[闪电](previews/element_lightning.png)、[雷霆](previews/element_thunder.png)、[冰霜](previews/element_frost.png)。
- [中文面板](previews/picker_zh_CN.png)、[英文面板](previews/picker_en.png)。

录制使用真实训练场、主角、Ability 时间线、Actor.step、MeleeResolver 和 HUD；为便于比较，敌人 AI 决策暂停，并在每段重建场景恢复初始状态。四次第三段攻击分别在 2.35 米命中，实际扣血 27，目标 HP 46→19；该距离超过旧第三段 2.2 米半径。视频是经过舞台布置的实机测试，不是自由战斗录屏。详见 [录制报告](reports/capture_report.md)。

## Blender 源工程

- [火焰](fire_frost/blender/fire_study.blend)
- [冰霜](fire_frost/blender/frost_study.blend)
- [闪电](lightning_thunder/blender/lightning_slash.blend)
- [雷霆](lightning_thunder/blender/thunder_slash.blend)

均保留可编辑材质/弧面、相机、灯光与展示剑，实际在 Blender 5.2.1 制作、渲染并烘焙。没有安装新插件，也未覆盖用户原始资产。制作过程、重建脚本和各自真实 Blender 渲染见 [火焰／冰霜记录](fire_frost/README.md) 与 [闪电／雷霆记录](lightning_thunder/README.md)。Blender 渲染与 Godot 实机截图分别保存。

每款四帧 1024×256 线性 HDR emission EXR + mask PNG，共 32 张运行时纹理，位于 `game/assets/vfx/elemental_slashes_v001/`。Godot 导入启用 mipmaps 和 VRAM 压缩，保留 HDR；复杂离线节点不进入每帧运行。

运行时复用现有 `golden_effect.gd` 和 `baked_trail.gdshader`，包含世界空间拖尾、四帧材质插值和独立粒子。`.tscn/.tres` 分别配置尾迹与亮度，选项引用集中于 `effect_picker/palette.tres`。原有七套效果资源及贴图没有改动。

## 命中范围修复

原问题：ActorView 曾按 Ability 半径定位剑尖，部分刀光又在剑尖之外延伸。仅加大 JSON 会把剑和刀光同时推远，始终保留漏判间隙。

本次将美术摆放与玩法范围分别配置：

| 三段攻击 | 原命中半径 | 新命中半径 | 保留的剑尖摆放半径 | 全部主刀光最大外缘 |
|---|---:|---:|---:|---:|
| slash.1 | 1.9 m | **2.5 m** | 1.9 m | 2.208 m |
| slash.2 | 1.9 m | **2.5 m** | 1.9 m | 2.208 m |
| slash.3 | 2.2 m | **2.8 m** | 2.2 m | 2.508 m |

- 玩法半径唯一来源：`game/data/combat/prototype.json` 的 `radius_m`；角度仍为 160°。
- 剑尖美术摆放唯一来源：`training_style.tres.weapon_tip_radius_by_ability`。新增玩家能力必须显式配置，缺失即报错。
- 现有刀光的尺寸、延伸量和剑尖姿态不变。判定不会读取选中的特效、材质或粒子，切换按钮不修改战斗能力。
- 当前仍按角色中心判定受击，新范围覆盖主刀光并留约 0.292 m 余量；这不等同于身体圆形碰撞判定。装饰散粒子、屏幕泛光和移动后留在旧位置的尾迹不造成额外伤害。
- 伤害、前摇/生效/后摇、敌人范围与玩法机制保持原配置。

## 实际验证

- 内容构建：118 个中英文 key，通过 schema／引用检查，PO 由 JSON 重新生成。
- `sword_reach_alignment.gd --require-coverage`：11 项×3 招共 33 组合通过；与 [修改前基线](reports/reach_before.json) 比较，原 21 组剑尖及主刀光边界保持不变；真实 Resolver 的扩大区命中、半径外拒绝、±79°命中／±81°拒绝、重复目标去重均通过。[最终报告](reports/reach_after.json) 与 [分析](reports/reach_analysis.md)。旧 GPU 火焰为几何保守上界，其余为实际 CPU 网格测量。
- `combat_rules.gd`、`golden_sword_trail.gd`、`combat_feedback.gd`：全部 `failures=[]`。
- `combat_effect_picker.gd`：11 个选项实际实例化，切换不改施放/生命/范围，暂停冻结粒子，点击面板不穿透触发攻击，中英文 1280×800 布局通过。[报告](reports/picker_validation.json)。
- Godot Vulkan Forward+ 实机录制：12 次施放、4 次范围命中，`capture_result.json failures=[]`。
- Windows PCK 导出成功；从 builds 目录独立加载 `elemental_combat_validation.pck` 进入训练场，启动无错误。此项验证资源打包与启动，不宣称做过完整发布压力测试。

这些名称目前仅为美术主题，尚未实现燃烧、闪电连锁、冰霜减速等技能机制。最终元素和构筑体系仍待后续设计。
