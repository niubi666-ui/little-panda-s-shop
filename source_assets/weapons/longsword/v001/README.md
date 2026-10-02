# 简洁长剑 v001

2026-09-26。用于替换战斗原型中的白色长方体剑。

- 蓝银色菱形截面剑刃、尖剑头、古铜护手、深色皮革握柄和剑首。
- Blender 源工程：`longsword_v001.blend`，生成脚本：`build_sword.py`。
- 游戏模型：`game/assets/weapons/longsword_v001/longsword.glb`。
- 源模型剑刃为单位长度，沿 Godot 的负 Z 轴指向剑尖，中心为原点；握柄沿正 Z 延伸。ActorView 只对视觉模型按 `blade_size.z` 缩放，刀光挂点保留在未缩放的剑身中心，避免二次放大。
- `training_style.tres` 的 `weapon_visual_scene` 指定模型，可独立替换武器表现；模型不决定碰撞、伤害或攻击阶段。
- 目前角色仍使用原有占位挥剑轨迹；正式手部握持与骨骼攻击动画待后续调整。
- 同步更新了火焰刀光小样的视频和截图：`source_assets/vfx/fire_slash/v001/previews/`。
- Godot Forward+ 实机录制正常，MP4 回读确认 481 帧、1280×800、60 FPS。受击反馈与表现替换检查通过，见 `feedback_validation.log`：`COMBAT_FEEDBACK failures=[]`。
