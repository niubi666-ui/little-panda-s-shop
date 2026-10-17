八方向战斗翻滚 / NODACHI ROLL 8 DIRECTIONS

空格播放/暂停。时间轴依次：前 → 右前 → 右 → 右后 → 后 → 左后 → 左 → 左前。
1–71 | 前 | roll_forward | 1.167s
102–172 | 右前 | roll_forward_right | 1.167s
203–273 | 右 | roll_right | 1.167s
304–374 | 右后 | roll_back_right | 1.167s
405–475 | 后 | roll_back | 1.167s
506–576 | 左后 | roll_back_left | 1.167s
607–677 | 左 | roll_left | 1.167s
708–778 | 左前 | roll_forward_left | 1.167s

8 个非循环 Action，统一 60 FPS，保持原始速度。NLA 间隔只供预览。
采用源动作包 IP 原地版：Godot 的角色控制器负责翻滚位移与碰撞，动画负责姿势。
不要仅靠动画决定无敌时段、消耗和冷却，数值需由玩法 JSON 配置。
GLB 中仅有角色骨架、预览人形和武器，以及 8 个独立动画，不含预览相机地面灯光。
源骨架为 UE Manny；如目标角色骨架不同，需要先重定向。
本轮未修改 game/ 或接入现有角色。
FBX 源文件见 fbx/；方向与时长清单见 reports/directions.csv。

交付文件：
blender/nodachi_roll_8dir.blend — 独立 Blender 工程，8 个 Action，时间轴 1–778。
godot/nodachi_roll_8dir.glb — 8 个独立、非循环动画；每段 1.166667 秒，8 权重蒙皮导出。
previews/nodachi_roll_8dir_preview.mp4 — 约 13 秒的八方向连续预览。
reports/blender_validation.json — 骨架匹配、蒙皮运动、根节点位移与 GLB 动画检查。
reports/godot_validation.json — Godot 4.7.2 独立加载并逐段播放 8 个动画，检查通过。
尚未验证当前游戏主角的重定向结果及战斗规则衔接。
