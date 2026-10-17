# 画面管线

更新：2026-10-15。场景从 Blender 到 Godot、怎么换角色、画面参数在哪。手感与音效参数的位置见 [技术说明](TECH.md)。

战斗训练场现在是**写实风格的童话森林**，镜头是**透视镜头**，主角和敌人都换成了**带贴图的写实模型**。
只动了表现层，战斗规则和数值没有改。所有美术仍是可替换的占位，替换方法见下文。

早先的低模玩具风格和樱花林训练场已经放弃：樱花林的场景、模型和生成脚本已删除；
玩具角色不再出现在游戏里，但它们的 `.blend` 仍保留，因为**全套战斗动作是在它们身上做的**，写实模型的动作由此移植而来。

## 现在是什么样

| 部分 | 内容 | 入口 |
|---|---|---|
| 场地 | 童话森林空地（第二版）：花树环绕、草甸花丛、斑驳树影、光柱薄雾、溪水木桥、遗迹石柱 | `game/presentation/rooms/fairy_forest_v2/` |
| 镜头 | 透视，俯角约 33°，滚轮缩放改变的是镜头距离 | `fairy_forest_v2/presentation.tres` |
| 主角 | 写实小熊猫（v008 模型）+ 长剑，11 段动作 | `game/presentation/combat/rigs/red_panda_real_visual.tscn` |
| 敌人 | 弩手、重装、冲锋兵、旗手：豺狼身体 + 各自的动作与道具；斥候和精灵游侠沿用原模型 | `game/presentation/combat/rigs/*_real_visual.tscn` |
| 角色着色 | 标准 PBR，保留贴图，外加受击闪白、前摇泛光、尸体消散、淡轮廓光 | `game/presentation/shared/pbr/` |
| 预警 | 柔边地面提示，随前摇从脚下向外填满，填满即出手 | `game/presentation/combat/fx/telegraph.gdshader` |
| 反馈 | 底部生命条、受伤屏幕闪红、击杀花瓣、闪避尘土、受击抖动、倒地后消散 | `game/presentation/combat/juice/` |

训练面板默认收起，从顶部“界面显示”菜单打开；`combat_training.tscn` 的 `training_panels_visible` 可改回默认展开。

## 场地：从 Blender 到 Godot

当前训练场是**第二版童话森林**（`game/presentation/rooms/fairy_forest_v2/`，导出物 `game/assets/fairy_forest_v2/`，
Blender 文件 `fairy_arena_game_v2.blend`，脚本 `build_game_arena_v2.py`；后者依赖 `build_game_arena.py`，不能删）。第一版已于 2026-10-14 删除。
2026-10-16 试过第三版（舞台灯光、晨光、低角度逆光三种光影），用户都不满意，已删除，恢复第二版。

**场上道具（木箱、矮墙、宝箱）暂时不摆**：`placement_surface.tres` 只留了一个放在场外（z = −40）的摆放点。要恢复，把摆放点换回这五个
（房间坐标，朝向是弧度）：west (-6.6, 0, -1.3) π/2,3π/2；east (6.6, 0, -0.9) π/2,3π/2；southwest (-5.2, 0, 4.0) 0,π；
southeast (5.2, 0, 4.0) 0,π；interior (0, 0, -5.0) 0,π。道具模型还是旧的卡通风格，恢复前最好先换成写实模型。

### 第二版是怎么对齐 Blender 画面的

做法是“同一个场地、同一个机位，Cycles 和 Godot 各拍一张，逐张对比”，而不是凭感觉调：

1. `render_game_views.py` 用 Cycles 渲染 `fairy_arena_game_v2.blend`，机位和游戏镜头完全相同
   （`game` 默认镜头、`far` 拉远、`ruin` 遗迹、`bridge` 小桥、`hero` 低机位美图、`top` 正上方）。输出 `builds/lookdev/<机位>_cycles.png`。
2. `game/tests/fairy_lookdev_capture.gd` 在 Godot 里用同样的机位拍 `builds/lookdev/<机位>_godot.png`（隐藏界面、角色，冻结战斗）。
3. 两边对比亮度分布、颜色和局部区域，再改 Godot 的参数。最终五个机位的平均颜色和亮度分布差别都在几个百分点以内。

`render_game_views_debug.py` 可以只开太阳、只开光束灯或只开天光渲染，用来逐项核对光影；
`fairy_lookdev_capture.gd` 后面可以跟临时开关（不改文件），例如 `fol:grass.001:direct_root=0.4`、`env.volumetric_fog_density=0.01`、`nodes:tree_*:visible=false`，脚本开头有说明。

光照单位已经和 Blender 校准过（`game/tests/lookdev_calibration*.gd` 与 Cycles 渲染同一块灰卡）：

- 太阳：Godot `light_energy` = Blender 瓦数 ÷ π；颜色按 sRGB 填（Godot 会自己转线性）。
- 点光、聚光：Godot `light_energy` = Blender 瓦数 ÷ 38.6，衰减用平方反比（`attenuation = 2`）。
- 色调映射：Godot 的 AgX、对比度 1.5、曝光 1.19，等于 Blender 的 “AgX - Medium High Contrast” 加曝光 0.25。

### 第二版改了什么（和已删除的第一版比）

- **天光和雾**：天空用 Blender 的世界颜色；去掉了第一版那层灰白的距离雾和光晕（这是画面“不清透”的主要原因）；
  阴影里的补光用偏暖的环境色（模拟林间草地的反光），不再是一片蓝灰。
- **草和花**：草甸按 Blender 样板间的方式重新铺（成丛的高草 + 单色花丛），导出时修正了草叶贴图透明区域的底色
  （原来远看会变成银灰色）。植被着色器照着 Blender 材质做：正面漫反射、背面透光（逆光下草叶发亮）、草丛内部互相遮挡阳光、
  树冠内部挡天光；每种材质的参数对应 Blender 节点（`room.tscn` 的 `foliage_grades`）。草丛会投影。
- **水**：透过水面看到水底，按菲涅耳混入倒影；倒影在画面里追踪（岸上的石头、草、树都能映出来），追不到的部分用林间暗色、天光和逆光薄雾代替。
- **抗锯齿**：改用 FSR2（自带时域抗锯齿，草叶边缘比 MSAA 稳定得多），并在 1080p 时以约 0.77 倍分辨率渲染再放大。
- **预警**：地上的草有半米高，会把地面预警挡住；预警着色器现在提前做深度测试（`telegraph.gdshader` 的 `depth_pull`），所有房间生效。

### 要调的东西在哪

脚本 `fairy_forest_room.gd` 里不带画面参数的默认值，都在下面这些文件里：

| 想调什么 | 改哪里 |
|---|---|
| 天光、雾、环境补光、色调、太阳颜色和强度、阴影 | `room.tscn` 里的 `Environment`、`Lights/Sun` |
| 太阳方向、光束灯、石灯、风的摆幅、树冠遮挡、每种植被的着色参数 | `room.tscn` 根节点的属性（`foliage_grades` 按材质名列出） |
| 植被的共用参数（镂空阈值、根部压暗、风向风速） | `foliage_material.tres` |
| 地面：苔藓和泥土的比例、明暗、湿痕、水下焦散 | `ground_material.tres` |
| 水：透色、清澈度、波纹、倒影、浮沫 | `water_material.tres` |
| 画面四角压暗、光尘 | `room.tscn` 的 `Vignette/Shade`、`Motes` |
| 渲染分辨率与抗锯齿 | `presentation.tres` 的 `render_height_limit`、`render_scaling_mode` |

地面小径和溪床是着色器按公式画的（`terrain.gdshader`），公式与 `build_game_arena.py` 里的 `path_x` / `stream_y` 相同，**改了一边要同步另一边**。

### 重新导出第二版

```powershell
& 'E:\blender\blender.exe' --background source_assets/lookdev_forest_v1/fairy_forest_opt.blend --python source_assets/lookdev_forest_v1/build_game_arena_v2.py -- E:\ShopGame\game\assets\fairy_forest_v2
& 'E:\blender\blender.exe' --background source_assets/lookdev_forest_v1/fairy_arena_game_v2.blend --python source_assets/lookdev_forest_v1/render_game_views.py -- E:\ShopGame\builds\lookdev
```

第一条重建场地并导出（约 6 分钟），第二条重新渲染对照图（约 5 分钟）。

注意：

- 改了 `library.glb` 后要重新导入：`godot --headless --path game --import`。如果导入失败过一次，Godot 会记住失败、不再重试，这时先删掉 `library.glb.import` 再导入。
  重新导出前最好把 `game/assets/fairy_forest_v2/` 里 `library_` 开头的旧贴图删掉，否则改名的贴图会留下垃圾文件。
- 这个 Godot 版本读不了只含 WebP 贴图的 glTF，导出脚本因此用 PNG/JPEG。

### 性能

RTX 4060 笔记本，战斗中的实际画面：1080p 约 71 帧；全屏（2304×1440）约 70 帧。
三维画面最高按 830 像素高渲染（`render_height_limit`），再由 FSR2 放大到窗口，所以全屏和 1080p 差不多快；界面文字始终按窗口分辨率画。

- 最贵的是**阳光阴影**（整片森林和草丛画进四级阴影图）和**草地本身**（层层叠叠的镂空草叶）。
- 草丛投影约占 8 帧，但去掉后草地明显变平，所以保留。
- 还想更快：`presentation.tres` 的 `render_height_limit` 调低（每降 100 约 +5 帧，画面变软），
  或把 `Lights/Sun` 的 `directional_shadow_mode` 降到 2 级（约 +4 帧，近处树影变糊）。
- 显卡更好时可以把 `render_height_limit` 调高（例如 1100），画面更锐利。
- 实时全局光照（SDFGI）试过：画面发灰，没有开。

## 透视镜头

`room_presentation.gd` 新增 `camera_fov`。为 0 时是原来的正交镜头；大于 0 时为透视镜头，此时
`camera_size` 及其上下限不再是视野高度，而是缩放档位：镜头距离 = `camera_offset` 的长度 × 当前档位 ÷ `camera_size`。
其它房间没有设置 `camera_fov`，仍是正交镜头，不受影响。

## 手感与反馈的参数

见 [技术说明 · 每类配置在哪](TECH.md#每类配置在哪)。

## 怎么替换一个角色

每个角色由三样东西组成，互不耦合：

1. **模型场景**（`*_visual.tscn`）：根节点挂 `rigs/rigged_actor_visual.gd`，子节点必须叫 `Model`，里面是带 `AnimationPlayer` 的模型。
   根节点的 `feedback` 指向一份 `rig_feedback_*.tres`（转身、受击、尸体、前摇泛光），`keep_textures`、`tint` 都要显式填写。
2. **动作映射**（`*_clips.tres`，脚本 `rigs/actor_clip_set.gd`）：把“待机/移动/受击/死亡/闪避/各技能”对应到模型里的动作名。
3. **表现配置**（`presentation/combat/*_presentation.tres`）：指向模型场景，并给出碰撞体。战斗逻辑只读碰撞体，不读模型。

### 人形主角（Quaternius 通用骨骼）

素材在 `source_assets/quaternius/`（UAL1/UAL2 动作库、通用人形角色，均 CC0）。`build_hero.py` 用后台 Blender 生成 `game/assets/combat_real/hero_katana.glb`：导入角色和两个动作库，把“出刀 + 收招”在 NLA 里合成一个动作，生成太刀挂到 `hand_r`，打印每个攻击动作的手速曲线供定切点（切点填在 `rigs/hero_clips.tres`）。同一套骨骼的新角色可以直接复用这些动作。

待机和攻击动作由 `katana_moves.py` 设计：刀是一个控制器（握把中心 + 刀尖方向 + 刃口方向），双手 IK 握刀柄、双脚 IK 踩地，按关键姿势插值（挥砍段线性、走中间关键帧定的弧线），再烘焙成骨骼动画。改动作就改 `MOVES` 里的姿势和帧号；帧号（30 帧/秒）换算成秒后要同步到 `game/data/combat/prototype.json` 对应技能的前摇/判定/收招，并更新 `rigs/hero_clips.tres` 的切点。检查用 `game/tests/hero_moves_capture.gd`。

```
& 'E:lenderlender.exe' --background --factory-startup --python source_assets/quaternius/build_hero.py
```

### 新模型自带全套动作

1. 导入模型，复制一份现有的 `*_real_visual.tscn`，把 `Model` 换成新模型，调好缩放。
2. 复制对应的 `*_clips.tres`，把动作名改成新模型里的名字。
3. 在 `*_presentation.tres` 里把 `visual_scene` 指向新场景。朝向不对就改 `visual_yaw_offset_deg`。

### 新模型只有骨骼，没有战斗动作

用 `source_assets/realistic_chars_v1/` 的移植脚本，把现有动作搬到新骨架上：

```powershell
& 'E:\blender\blender.exe' --background --python source_assets/realistic_chars_v1/build_panda.py -- E:\ShopGame\game\assets\combat_real\red_panda_real.glb E:\ShopGame\source_assets\realistic_chars_v1\blend\red_panda_real.blend
& 'E:\blender\blender.exe' --background --python source_assets/realistic_chars_v1/build_enemies.py -- E:\ShopGame\game\assets\combat_real E:\ShopGame\source_assets\realistic_chars_v1\blend
```

换模型时改脚本开头的 `MODEL`（模型路径）和 `MAPPING`（玩具骨骼名 → 新模型骨骼名）即可。
原理写在 `retarget.py` 开头：两个角色都朝同一方向站好，把“每根骨头相对静止姿势转了多少”原样搬过去；
四肢先做一次固定修正，抵消两个模型静止姿势的差别（一个垂手、一个平举）。
动作名不变，所以 Godot 这边的 `*_clips.tres` 不用改。

几条约定：

- **缺动作不会报错**，会退回待机。可以先接模型，后补动作。
- **攻击动作分三段**。`attack_cuts` 里每个动作有两个时间点（前摇结束、判定结束，单位是动画文件里的秒）。游戏把自己的前摇/判定/收招时长分别映射到这三段，所以调数值不用重做动画。
  `attacks`、`attack_fallback` 里出现的每个动作都必须配切点，缺了会在资源校验时报出动作名，不会悄悄用默认值。
- **出刀节奏**（`attack_shapes`，每个有切点的动作都要写）：`Vector4(前摇缓出指数, 挥砍占判定段比例, 挥砍缓出指数, 收招停顿比例)`。例如 `Vector4(2.5, 0.35, 2.5, 0.3)`：很快拧到蓄力姿势并憋住，判定段头 35%（约 2 帧）就挥完，收招前 30% 停在挥到底的姿势。只改播放方式，不改判定。剑上的刀光由 `attack_motions/*.tres` 的 `active_completion_fraction` 控制，要和这里的挥砍比例一致。逐帧检查用 `tests/swing_capture.gd`（输出 `builds/visual_pass/swing_*.png`）。
- **打击表现**（`presentation/combat/strike/`）：白色月牙刀光、命中尖刺、爆团。形状按技能写在 `strike_style.tres` 的 `arcs`（`strike_arc.gd`：半径、带宽、起止角度、高度、扫出/停留/消散时间），颜色和烟雾在其中的材质参数；按战斗时间走，顿帧时一起停住。
- **`*_clips.tres` 的每个字段都要写**（不用的动作写空名 `&""`、空字典 `{}`）；脚本里没有默认值。
- **敌人按 AI 状态选动作**：`states` 里写“状态名 → 动作名”。`windup`、`recovery` 按进度播放，其余循环。
- **带贴图的模型**把 `keep_textures` 打开。`tint` 可以给整个模型染色：四种敌人共用一个豺狼身体，靠染色、体型和手里的道具区分。
- **主角的刀光**仍由一把不可见的“虚拟剑”驱动（`player_presentation.tres` 的 `virtual_blade`），所以十几种刀光不受模型影响。

## 怎么替换场地

房间由 `presentation/rooms/<名字>/presentation.tres` 描述（场景、镜头、可摆放区域）。
`app/combat_training.tscn` 的 `room_presentation` 指向哪个，训练场就用哪个。旧的森林遗迹和森林庭院都还在，改回去只需改这一处引用。

## 截图与测速工具

画面对照（与 Blender 同机位）见上文“第二版是怎么对齐 Blender 画面的”。下面是日常截图：

`game/tests/visual_pass_capture.gd`，图形模式运行（不能加 `--headless`），输出在 `builds/visual_pass/`：

```powershell
godot --path game --script res://tests/visual_pass_capture.gd -- overview   # 几个站位的全景
godot --path game --script res://tests/visual_pass_capture.gd -- combat     # 一套连招的逐帧序列
godot --path game --script res://tests/visual_pass_capture.gd -- lineup     # 各兵种站成一排
godot --path game --script res://tests/visual_pass_capture.gd -- perf       # 1080p 帧率与绘制量
```

`perf` 后面可以跟试验开关，例如 `env.ssil_enabled=false`、`sun.shadow_enabled=false`、`vp.msaa_3d=0`。

## 还没做的

- 第二版场地暂时不摆随机道具；道具（木箱、矮墙、宝箱）还是旧的卡通模型，恢复前应先换成写实模型。
- 风是程序摆动，只看过静态截图；草和花在动态下的观感还需要在游戏里确认。
- 敌人的道具（弩、锤、长枪、旗）是从玩具模型上拿过来的色块模型，不是写实贴图。
- 移植来的动作只保证方向和节奏对，手指不会握住武器，手腕偶尔有扭转。
- 四种敌人和斥候是同一个身体，只靠染色、体型和道具区分。
- 店铺场景没有动。
