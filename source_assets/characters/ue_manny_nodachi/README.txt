UE Manny + Nodachi / 当前战斗主角

替换前恢复点：Git b878540（用户要求先提交，再替换）。

运行时：game/assets/characters/ue_manny_nodachi/manny_nodachi.glb
动作配置：game/presentation/combat/rigs/nodachi_clips.tres
模型场景：game/presentation/combat/rigs/nodachi_visual.tscn
玩法时长：game/data/combat/prototype.json（schema 7）
集成 Blender：blender/manny_nodachi_game.blend

34 段独立动画，原生 Manny 骨架，保留预览中的人形和太刀：
- idle：战斗待机
- walk_* / run_*：各八个方向，按移动相对瞄准方向选取
- attack_1/2/3：Attack01 的前三段，三连击
- heavy：Attack05 第一段，重击
- cast：Attack01 第四段，剑气挥斩
- roll_*：前、右前、右、右后、后、左后、左、左前
- hit/death：同一 Nodachi 包的战斗受击/死亡
- charge：同包持刀格挡循环，用于剑气蓄力占位
- roll_slash：AS_Parry_Counter_L_Seq，翻滚中左键冲斩，原生时长 1.833333 秒

源动作审阅工程保持完整：source_assets/animations/nodachi/review_v001/
八方向翻滚审阅工程：source_assets/animations/nodachi/roll_8dir_v001/
未接入的源动作仍在这些动作库中，可以后续选用。
fbx/ 下补出的 hit/death/charge 来自本机 Nodachi 项目；来源清单见 reactions.json。
翻滚冲斩：fbx/roll_slash.fbx；来源记录 roll_slash.json；UE 导出脚本 scripts/export_roll_slash.py。

导出脚本：scripts/build_runtime.py，Blender 5.2.1 后台运行。
输入源是先前审阅的 Blender 文件，不回写这些文件。
导出统一 60 FPS、8 骨骼影响；去除 armature 对象的 XY 根位移，保留骨骼姿势和垂直运动。
角色移动、碰撞、前冲由游戏 CharacterMotor 执行，避免动画再次移动角色。
WeaponFX_Base/Tip 是刀刃实际端点，元素与刀光使用当前骨骼求解，避免节点更新晚一帧。

攻击保留原生姿势：前摇/挥砍使用配置切点，收招压缩为适合操作的时长，并允许续接。
第三刀现为下劈，判定为前方 100 度扇形；伤害和攻击半径沿用现有配置。
翻滚完整姿势用 0.7 秒，前 0.35 秒移动约 3.4 米，后半段起身。
无敌仍为前 0.2 秒；鼠标移动不改变已开始翻滚的朝向/动作。
走跑方向切换保留步态相位；普通跑步 6.2 米/秒对应原速。

旧 Quaternius 主角运行模型/贴图、动作映射、生成脚本、生成 Blender 文件已删除，可从 Git 恢复点找回。
通用 Quaternius 下载素材库保留在 source_assets/quaternius/，不再被当前主角使用。
店铺小熊猫和敌人资源未列入旧主角清理范围。

验证：game/tests/nodachi_player.gd（实际森林场景、34 动作、八方向、真实刀身挂点、完整动作、暂停、死亡）；
game/tests/combat_rules.gd（包含扇形/直刺解析器独立测试）；离线 JSON/schema/PO 校验。
图形实测截图与报告在 builds/nodachi_review/，不作为源资产提交。

实测：Nodachi 主角 191 项检查通过；combat_rules、combo_feel 通过；图形刀刃挂点与渲染节点误差为 0。
图形场景退出仍出现项目已知的 7 个 Texture RID 警告，未出现脚本错误。

翻滚冲斩规则：dodge.attack_distance_m = 6，attack_duration_sec = 0.24；前摇 0.18 秒、收招 0.5 秒。
上下半身与转向过渡在 nodachi_clips.tres；FBX 原动作保留，Godot 完成分骨骼混合。
同 primary 构筑和冷却通道，每目标每次冲斩命中一次；没有额外无敌，碰撞/受击/控制可截断。
专项验证：roll_slash 96 项、roll_slash_visual 505 项通过；30/60/120Hz 无障碍距离均为 6m。
