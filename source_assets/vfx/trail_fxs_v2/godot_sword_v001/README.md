# 金色流光 · Godot 战斗集成

2026-09-26。用户认可 Blender 金色破碎流光后，接入真实 Godot 战斗训练，并将玩家三段挥砍改为 160°。

## 现在如何体验

运行 Godot 项目，在店铺按 F6 进入战斗训练；鼠标瞄准、左键三连击、WASD 移动、Shift 闪避。也可以直接运行 `res://rogue/scenes/training_arena.tscn`。

本效果已经是训练场默认刀光，不需要手动切换。家具摆放代码和资源未改动。

训练界面右上角新增“刀光测试”面板：金色破碎流光、清亮弧光、厚重刀光、飞散流光、预设01焰刃、预设06碎光、火焰刀光。点击即可切换，当前项高亮；可在暂停时选择，继续后观察效果。重新训练恢复默认金色流光。选择只存在本次训练界面，不改变160°判定、伤害或存档。

配置入口为 `game/presentation/combat/effect_picker/palette.tres`，按钮仅发送局部信号，由训练 app 验证选项并替换玩家的表现节点。名称来自双语 JSON，生成 PO 不手改。中文与英文截图为 `previews/picker_zh_CN.png` / `picker_en.png`。

- `previews/golden_combat.mp4`：真实 Godot 录屏，包含正常空挥、近景慢放及实际 AI 战斗。
- `previews/opening_slow_sweep.png`：完整挥砍后的近景，便于查看长弧与火星。
- `reports/capture_result.json`：录屏对应的施放、命中、伤害与时间记录。

录制为可重复评审安排自动玩家输入、初始敌人位置及镜头缩放；没有替换训练场灯光/地面/命中特效，没有伪造伤害。玩家技能时间线、移动、命中、击退和敌人 AI 均来自真实战斗模块。近景慢放仅用于评审，游戏默认速度不变。

## 实现与权威参数

| 内容 | 位置 |
| --- | --- |
| 三段攻击 160°，半径 1.9/1.9/2.2 米 | `game/data/combat/prototype.json` |
| 默认效果入口 | `game/presentation/combat/fx/slash_default.tscn` |
| 金色流光、火星数量/寿命/大小 | `game/presentation/combat/fx/golden_trail_v001/golden_slash.tscn` |
| HDR 材质、曝光与透明度 | 同目录 `golden_filaments.tres` |
| 姿态采样/取消收尾 | 同目录 `golden_effect.gd` 与 `game/presentation/combat/actor_view.gd` |
| 烘焙纹理 | `game/assets/vfx/golden_trail_v001/` |

三段角度统一到 160 度。只扩大扇形角度；原有半径、伤害、冷却、时序、敌人参数保持原值。玩家剑尖显示位置从当前技能半径推导，视觉不决定命中。由于当前武器尚未绑定正式挥剑骨骼，剑的持握与身体动作仍需后续动画制作。

运行时效果复用世界空间剑根/剑尖拖尾模块和四帧烘焙材质适配器；新效果在剑姿态更新后采样，取消时在当前姿态结束，避免生成回拉拖影。火星沿剑身发射，收招后自然消散。暂停冻结尾迹、材质时间和粒子。

## 原材质移植

来源是用户提供的 Trail FXs v2 资产，经前轮制作的 `blender/sword_trail_study.blend` 中 `01_Golden_Filaments` 材质。直接用 Blender Cycles 将该材质烘焙为 4 组 1024×256 HDR 发光 EXR 与透明遮罩 PNG，保留金色、破碎光丝与尾端收束；烘焙详情见 `README_TEXTURES.md`。

Godot 对四个噪声时刻插值，是动态材质近似；Blender Geometry Nodes 没有直接进入游戏。跨引擎的色调映射、光晕和实际地面亮度不同，以实机录屏为准。原素材与旧候选演示保留。

## 已验证

- `COMBAT_RULES failures=[]`：每招在平移原点和旋转朝向下，±79°命中、±81°不命中、半径外不命中；同次挥砍同目标只扣一次血。
- `GOLDEN_SWORD_TRAIL failures=[]`：真实 ActorView/Runner 的 ±80°起止姿态、剑尖半径、暂停、消散、取消不回拉、不同挥砍不桥接、材质实例隔离。
- `COMBAT_FEEDBACK failures=[]`：真实受击/击退、闪光、粒子、白色残留血条与死亡尾效。
- `COMBAT_EFFECT_PICKER failures=[]`：7种实际场景切换、单选高亮、切换不改变施放/生命/数值、暂停粒子冻结、真实鼠标点击按钮及面板空白不触发攻击，中英文界面不溢出。114个双语key与生成PO一致。
- 内容 schema/引用校验通过；新纹理导入成功；独立 PCK 在项目目录外以 Forward+ 启动训练场成功。

60 Hz 相邻姿态之间使用弦插值细分，测得拖影补点最大向内偏差约 2.53 厘米；起止端点准确，误差处于采样角距决定的上界内，不影响扇形命中判定。相关日志放在 `reports/`。

本轮验证完成的是训练原型的特效、范围和反馈。正式骨骼挥剑、构筑切换及最终地牢美术仍是后续工作。
