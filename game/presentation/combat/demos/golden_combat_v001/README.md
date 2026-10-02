# 真实训练场战斗录制

这是审阅用自动输入入口，不替代正常战斗场景。它实例化 `training_arena.tscn`，保留默认特效、灯光、地面、HUD、角色能力和敌人 AI。

- 玩家输入依次经过 `request_attack`、正常三连击 Runner、Motor、MeleeResolver；命中、伤害、击退和死亡均真实计算。
- 开头 3 秒玩家面向镜头方向原地空挥两次：0.35 秒正常速度一次，1.25 秒进入 0.4 倍近景再挥一次；3 秒恢复正常速度和镜头并自动追击。首波敌人距离为基础摆位的 4 倍，始终可见、正常接近，并不冻结 AI。
- 初始站位和后续波次的出生摆位位于镜头一侧，方便看到挥砍弧面；这些摆位只属于录制入口。
- 整段 16 秒，9 秒后进入实际战斗近景慢放。通过 `Engine.time_scale` 统一慢放物理、角色动作和特效；不改变技能 JSON 或游戏场景参数。
- `opening_empty_swing.png` 显示正常速度空挥；`opening_slow_sweep.png` 取第二次空挥进入后摇的第一帧，保留完整 160° 挥砍终点与拖尾；其他截图来自实际战斗。
- 所有审阅时序、摆位、镜头参数位于同目录 `settings.tres`。

运行场景并在用户参数中传入 `--capture`，到配置时长后保存每次真实施放、命中与截图的报告并退出。

使用 Godot Movie Maker 时，必须在启动进程之前创建 `source_assets/vfx/trail_fxs_v2/godot_sword_v001/previews/`，再将 `--write-movie` 指向其中的 `golden_combat.avi`。引擎在场景 `_ready` 前打开电影输出，运行中创建目录无法补救本次录制。

转码脚本为 `source_assets/vfx/trail_fxs_v2/godot_sword_v001/reports/capture_encode.py`，由 Blender 后台运行。输出是实际 Godot 录像，未合成命中效果。
