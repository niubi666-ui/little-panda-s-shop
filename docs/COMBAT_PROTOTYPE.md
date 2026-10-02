# 战斗训练原型

更新：2026-09-28，内容版本以 manifest 为准，战斗 schema_version=2。用于验证战斗手感，训练入口已接入森林庭院，敌人模型仍为占位；简易场景保留为回归夹具。

## 操作

店铺按 **F6** 或点击训练按钮进入 `app/combat_training.tscn`；弹窗打开时入口不可用。当前房间及美术接入见 [FOREST_COURTYARD_INTEGRATION.md](FOREST_COURTYARD_INTEGRATION.md)。

- WASD 移动，鼠标瞄准，左键三连击：按角色面向，第一段左→右、第二段右→左、第三段向前刺击；Shift 闪避。
- 普攻三个阶段均可移动，当前保持正常移速；起手锁定本次挥砍方向，攻击区域随角色平移。
- 忙碌期间缓存一次攻击意图，超时重置连段；第二段命中将敌人向外击退。
- 玩家实际命中扣血时，镜头轻晃约0.12秒；空挥、同段重复接触、无敌拒绝不震动。一次击中多个目标重启同一短脉冲，不累加幅度。震动暂停冻结，结束/离场归零，不影响瞄准。
- 滚轮缩放，Esc 打开共享 v002 设置菜单并暂停，L 中英文；底部按钮可重试、返回店铺。设置菜单内屏蔽底层输入；三选一期间可进入设置并返回继续选择。见 [SETTINGS_UI.md](SETTINGS_UI.md)。
- 开场与第一波清场后三选一；左侧可查看构筑并点击“测试：再抽三选一”。选择期间暂停战斗，L可切语言。详情见 [BUILD_SYSTEM.md](BUILD_SYSTEM.md)。
- 右上角“刀光测试”面板可点击切换12种刀光，包含烈焰、苍蓝闪电、紫金雷霆、碎晶冰霜，以及最新的「焰浪 · 火焰重斩」，当前选择高亮。战斗中和普通暂停时可切换，三选一模态期间不可切换；切换不改变当前攻击的命中形状、伤害或技能时序。重新训练恢复默认金色流光。

当前为五种敌人的预算随机两波，配置与状态机见 [敌人遭遇](ENEMY_ROLES_AND_ENCOUNTERS.md)。斥候攻击可被打断；重卫攻击抗非致死硬直，但仍可被击退。清场或阵亡后可重试。训练不会改变库存、金币、委托或存档。

## 本次确认的战斗反馈

1. **移动攻击**：每个能力独立配置移动倍率；玩家三段为1，近战敌人的原型挥击为0。冲锋兵的专用位移见敌人模块。受击硬直、闪避与击退仍由角色/Motor仲裁。
2. **交替挥砍与刺击**：前两段保留160°、半径2.5米的扇形；第三段改为前方长2.8米、宽1.0米的矩形，侧面和背后不被刺击命中。剑尖最大美术距离仍为1.9/1.9/2.2米，数值判定不读取模型长度。独立 `attack_motions/*.tres` 控制左右方向、收剑、刺出、回收与轻微身体倾斜，进度来自能力逻辑时间线。第三段剑尖由前摇末端约1.1米迅速刺至2.2米；前两段在生效阶段85%时到达挥砍终点，避免帧率跳过末端。当前是程序化武器姿态，正式骨骼挥剑仍待后续动画资源。
3. **敌人受击**：全部模型网格白色发光、红色外轮廓，周围飞散粒子。暂时覆盖材质后恢复；各实例互不串色。致死命中仍播放反馈，碰撞与攻击则立即停止。
4. **第二段击退**：命中并实际扣血后生效。以攻击者到目标的方向施加线性衰减冲量，重叠位置取施放方向；墙体阻挡，重复冲量替换。当前速度10米/秒、持续0.24秒，无碰撞时约1.2米；来源唯一为JSON。
5. **敌人血条**：红色表示实时生命，被扣掉的部分显示白色，短暂停留后平滑下降。连续命中保留尚未消退的白段并重置短暂停留；死亡归零动画不影响死亡判定。暂停时表现计时也暂停。
6. **命中镜头反馈**：`MeleeResolver.confirmed_hit` 只通知已提交伤害；训练 app 仅对玩家命中敌人触发震动。独立 `HitCameraShake` 输出屏幕平面偏移，由相机的 h_offset/v_offset 显示，幅度(0.045,0.026)米、总位移上限0.065米、持续0.12秒。使用确定性衰减脉冲，不消耗玩法随机数；读取鼠标瞄准前清除显示偏移，随后重新应用，避免反馈改变瞄准。

## 数值与资源入口

| 调整内容 | 权威文件 |
|---|---|
| 生命、移速、硬直、AI、连段 | `game/data/combat/prototype.json` → actors |
| 伤害、范围、时序、攻击移动倍率、击退 | 同文件 → abilities |
| 扇形/刺击、刺击宽度 | 同文件 → abilities.hit_shape / thrust_width_m；radius_m 对刺击表示前向长度 |
| 闪避充能/无敌/速度 | 同文件 → dodge；waves仅用于旧灰盒夹具 |
| 实际房间波次、深度预算、阵容 | `game/data/rooms/encounters.json` |
| 模型、碰撞体、动作名、模型朝向 | `game/presentation/combat/*_presentation.tres` |
| 刀光场景引用、镜头、临时剑刃位置 | `game/presentation/combat/training_style.tres` |
| 三段武器动作和轻微身体倾斜 | `game/presentation/combat/attack_motions/{slash_1,slash_2,thrust_3}.tres` |
| 命中镜头震动幅度、时长、频率、衰减 | `game/presentation/combat/hit_camera_shake_style.tres`，将幅度设为0可关闭 |
| 默认刀光引用 | `game/presentation/combat/fx/slash_default.tscn` → `golden_trail_v001/golden_slash.tscn` |
| 刀光覆盖、尾迹寿命、粒子、平滑采样 | `game/presentation/combat/fx/golden_trail_v001/golden_slash.tscn` |
| 刀光 HDR 纹理、曝光、透明度 | 同目录 `golden_filaments.tres`；纹理位于 `game/assets/vfx/golden_trail_v001/` |
| 训练场刀光测试选项、名称key、按钮布局 | `game/presentation/combat/effect_picker/palette.tres` |
| 烈焰、闪电、雷霆、冰霜的材质、尾迹、粒子 | `game/presentation/combat/fx/elemental_slashes_v001/{fire,lightning,thunder,frost}/` |
| 焰浪重斩的火焰体、热刃、动画粒子、烟与灯光 | `game/presentation/combat/fx/fire_slash_v002/` |
| 白闪时长、血条尺寸/延迟/下降速度、粒子引用 | `game/presentation/combat/hit_feedback.tres` |
| 白色发光、红边颜色/宽度 | `game/presentation/combat/fx/hit_flash.tres` |
| 飞散粒子数量、速度、颜色 | `game/presentation/combat/fx/hit_sparks.tscn` |
| 血条红/白/背景颜色 | `game/presentation/combat/fx/damage_bar.tres` |
| 当前房间地形、灯光、出生点 | `game/presentation/rooms/forest_courtyard_v001/room.tscn`；旧training_arena保留为夹具 |
| 中英文 / 字体 | `game/data/locales/*.json` / `game/presentation/foliage/ui_typography.tres` |

修改JSON后运行 `tools/content/build_shop_preview_content.py`，重新开始训练读取新目录。必填字段没有隐藏默认值；击退速度与时长必须同时为0或同时为正。

schema_version=2要求每项能力必填 `hit_shape` 与 `thrust_width_m`：sector 必须有正角度、刺击宽度为0；thrust 必须角度为0、刺击宽度为正。运行时与构建工具执行同样校验，旧版本不能静默读入。

## 模块边界与后续替换

- 2026-09-26 武器表现更新：`training_style.tres.weapon_visual_scene` 注入独立长剑 GLB，替换白色 BoxMesh。源模型剑刃单位长度、负Z指向剑尖；按已有 `blade_size.z` 缩放视觉子节点，刀光中点节点不缩放，伤害与施放逻辑不变。源文件与说明见 `source_assets/weapons/longsword/v001/README.md`。

- `AbilityRunner`拥有攻击时序；`CombatActor`决定动作许可；`CharacterMotor`唯一负责移动/碰撞/击退；`MeleeResolver`负责接触去重与受击调用。
- `AttackMotion`只按能力阶段采样武器/身体姿态；`HitCameraShake`只生成镜头偏移。命中事实通过局部信号由app连接，不用表现回调扣血。
- `HitFeedback`和`DamageBarState`只处理已确认结果的显示，不能修改生命。每个血条独立材质；模型原材质引用逐网格保存并恢复。
- 模型替换：改对应 `*_presentation.tres`。目前动画仅映射idle/run；最终挥剑动作由ActorView读取逻辑阶段播放，不能让动画轨道决定伤害。
- 刀光替换：调用 `ActorView.set_weapon_effect(PackedScene)`。场景根为Node3D，实现 `set_active(bool)` 与 `set_time_running(bool)`；挂点自动位于剑身中部。v002额外实现可选的 `configure_blade(length)`，由ActorView注入临时剑的实际长度，正Z为剑根、负Z为剑尖。切换特效不会修改施放或伤害。三选一和真实构筑已接入，见 [BUILD_SYSTEM.md](BUILD_SYSTEM.md)；目前构筑派生效果使用独立表现资源，刀光面板仍只换美术。
- 训练是无持久状态的独立场景；远程、冲锋、支援AI已接入，正式经济和冒险存档结算尚未接入；平坦内庭随机障碍绕行和临时搜刮已实现，见 ROOM_PROPS_PROTOTYPE.md；训练构筑可组合与升级，重新训练会重置。


- 刀光可选实现 `sample_current_pose()` / `finish_at_current_pose()`：姿态更新后采样，取消/死亡回待机前结束尾迹，避免回拉弧线；死亡后的尾效也服从暂停。正式接口位于ActorView，具体资产制作说明按需读取。

## 验证

按 [验证索引](VALIDATION.md) 运行战斗、反馈、连段/镜头与对应刀光测试。历史包含规则、真实移动攻击、剑尖轨迹、暂停/取消、双语/重试及美术切换隔离；旧截图/数量/逐轮日志在归档，不作为本次全量通过声明。性能未解决项见 [KNOWN_ISSUES](KNOWN_ISSUES.md)。
