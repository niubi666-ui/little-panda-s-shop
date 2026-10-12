# 战斗视觉与手感（2026-10-12）

这一轮只动表现层：场地、光影、角色与敌人的临时模型和动作、预警、受击反馈、战斗生命条。
战斗规则和数值没有改。所有新美术都是**临时占位**，按下面的约定可以逐个替换。

## 现在是什么样

| 部分 | 内容 | 入口 |
|---|---|---|
| 训练场 | 樱花林石坪：逆光、斑驳树影、光柱、落花、石灯 | `game/presentation/rooms/sakura_grove/` |
| 主角 | 临时低模小熊猫，剑在手上，11 段动作 | `game/presentation/combat/rigs/red_panda_temp_visual.tscn` |
| 敌人 | 弩手、重装、冲锋兵、旗手四个临时模型；豺狼斥候和精灵游侠沿用原模型 | `game/presentation/combat/rigs/*_temp_visual.tscn` |
| 着色 | 角色与场景共用一套两段式光照，角色带轮廓光 | `game/presentation/shared/toon/` |
| 预警 | 柔边地面提示，随前摇从脚下向外填满，填满即出手 | `game/presentation/combat/fx/telegraph.gdshader` |
| 反馈 | 底部生命条、受伤屏幕闪红、击杀花瓣、闪避尘土、受击抖动、倒地后消散 | `game/presentation/combat/combat_juice.gd` |

镜头比之前近：正交视野高度从 19 米降到 10 米（滚轮 8–17）。
训练面板默认收起，从顶部“界面显示”菜单打开；`combat_training.tscn` 的 `training_panels_visible` 可改回默认展开。

## 怎么替换一个角色

每个角色由三样东西组成，互不耦合：

1. **模型场景**（`*_visual.tscn`）：根节点挂 `rigs/rigged_actor_visual.gd`，子节点必须叫 `Model`，里面是带 `AnimationPlayer` 的模型。
2. **动作映射**（`*_clips.tres`，脚本 `rigs/actor_clip_set.gd`）：把“待机/移动/受击/死亡/闪避/各技能”对应到模型里的动作名。
3. **表现配置**（`presentation/combat/*_presentation.tres`）：指向模型场景，并给出碰撞体。战斗逻辑只读碰撞体，不读模型。

换模型的步骤：

1. 把新模型导入，复制一份现有的 `*_visual.tscn`，把 `Model` 换成新模型。
2. 复制对应的 `*_clips.tres`，把动作名改成新模型里的名字。
3. 在 `*_presentation.tres` 里把 `visual_scene` 指向新场景。模型朝向不对就改 `visual_yaw_offset_deg`。

几条约定：

- **缺动作不会报错**，会退回待机。可以先接模型，后补动作。
- **攻击动作分三段**。`attack_cuts` 里每个动作有两个时间点（前摇结束、判定结束，单位是动画文件里的秒）。游戏把自己的前摇/判定/收招时长分别映射到这三段，所以调数值不用重做动画。
- **敌人按 AI 状态选动作**：`states` 里写“状态名 → 动作名”。`windup`、`recovery` 按进度播放，其余循环。
- **贴图模型**（比如 AI 生成的）把 `keep_textures` 打开，保留原贴图，只统一光照和轮廓光。
- **主角的刀光**仍由一把不可见的“虚拟剑”驱动（`player_presentation.tres` 的 `virtual_blade`），所以原有的十几种刀光不受模型影响。

## 怎么替换场地

房间由 `presentation/rooms/<名字>/presentation.tres` 描述（场景、镜头、可摆放区域）。
`app/combat_training.tscn` 的 `room_presentation` 指向哪个，训练场就用哪个。旧的森林遗迹和森林庭院都还在，改回去只需改这一处引用。

樱花林的可调项都在 `sakura_grove_room.gd` 的导出属性里：太阳方向、树影在场地中央/边缘的覆盖率、光柱数量与强度、落花数量、石灯亮度。

## 重新生成临时美术

源文件是 Blender 脚本，放在 `source_assets/combat_visual_v1/blender/`，用 Blender 5.2 后台运行：

```powershell
& 'E:\blender\blender.exe' --background --factory-startup --python source_assets/combat_visual_v1/blender/build_sakura_grove.py -- game/assets/combat_v1/arena/sakura_grove.glb
& 'E:\blender\blender.exe' --background --factory-startup --python source_assets/combat_visual_v1/blender/build_panda.py -- game/assets/combat_v1/characters/red_panda_temp.glb
& 'E:\blender\blender.exe' --background --factory-startup --python source_assets/combat_visual_v1/blender/build_enemies.py -- game/assets/combat_v1/characters
```

- 加 `--report` 会逐帧打印武器朝向，调动作时用来核对。
- `build_enemies.py` 可加 `--only=brute` 只生成一个。
- 姿势写法（角度的正负含义）见 `sg_char.py` 开头的注释。
- 对应的 `.blend` 在 `source_assets/combat_visual_v1/blend/`，可以直接打开手调。

生成后运行一次 `godot --headless --path game --import` 让引擎重新导入。

## 截图工具

- `game/tests/visual_pass_capture.gd`：进入训练场截图。模式 `overview` / `combat` / `lineup`。
- `game/tests/visual_pass_poses.gd`：把某个模型的动作按帧排成一张图，用来检查姿势。

两者都要用图形模式运行（不能加 `--headless`），输出在 `builds/visual_pass/`。

## 这一轮顺带改的旧内容

- 前两段普攻的挥砍方向互换：第一刀改为正手（右→左），第二刀反手。只改了 `attack_motions/slash_1.tres` 和 `slash_2.tres` 的表现数据。
- 敌人血条变细，满血时不显示（`hit_feedback.tres` 的 `bar_hide_when_full`）。
- 玩家头顶的“当前/最大生命”文字关闭（`training_style.tres` 的 `player_health_label`）。
- 项目设置里把方向光阴影调到 4096 并提高了柔化质量。
- 修了退出战斗场景时的一条报错（镜头已离开场景树时仍读取其变换）。

## 还没做的

- 临时模型是脚本拼出来的几何体，没有蒙皮和表情，只求读得清、动得对。
- 主角的出招前冲距离仍写在 `combat_training.gd` 里，没有挪进数据。
- 豺狼斥候只统一了光照，造型仍是原来的写实风格；精灵游侠完全没动（套统一材质后贴图发白，已撤回）。两者和临时角色并排会有差别。
- 店铺场景没有动。
