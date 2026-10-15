# 战斗训练原型

更新：2026-10-15（出招前冲进入配置）；战斗 schema_version=4，动作绑定构筑的接口见 [Build API](BUILD_IMPLEMENTATION_CONTRACT.md)。本页区分已写入代码与本轮整合验证，验证状态见末节。当前工作区训练入口引用fairy_forest；角色有临时模型/动作及已有斥候、游侠模型，最终美术仍可替换。旧场景保留。

## 操作

店铺按 **F6** 或点击训练按钮进入 `app/combat_training.tscn`；弹窗打开时入口不可用。当前房间及美术接入见 [战斗视觉与替换入口](COMBAT_VISUAL_PASS.md)。

- WASD 移动、鼠标瞄准；左键 `primary` 三连击，前两段交替挥砍（方向由AttackMotion资源控制）、第三段向前刺击。R键 `special` 点击重斩，鼠标右键 `skill` 开局自带瞬发剑气；Shift 闪避。按键不是构筑身份。
- 清场后仍可移动、普通攻击、右键和R施放，正在起手/飞行的玩家技能不因胜利取消；遵守原冷却、死亡、受控、暂停和UI门禁。训练 `finish_rewards()` 只结束自动奖励，`finish()` 用于死亡/退出；调试选卡与预设不属于自动奖励。当前路线房间同样保持执行直到退出，正式持久关卡尚未实现。
- 普攻三个阶段均可移动；重斩与剑气使用各自能力配置的移动倍率。起手锁定本次方向，近战区域随角色平移；剑气从逻辑cue发射，完全跳过近战区域及房间物件的近战命中路径。
- 忙碌期间只缓存一个带动作ID的有效攻击意图，后到有效意图替换；同帧固定按闪避→skill→special→primary仲裁。缓冲时长与空闲后的连段重置时长是两个独立配置。special/skill实际起手才重置primary连段。
- 左键、右键、R冷却独立，在开始承诺时扣除，取消不返还，切换形态不刷新。能力配置允许的阶段才能被闪避取消；当前重斩/剑气允许起手、恢复取消，生效阶段不允许。普通剑气零前摇在接受施放时发射；其提交回调同步取消时不发旧cue，后续取消不撤销已发剑气。
- 文本或其它可见Control持有GUI焦点时，停止采集移动和新攻击并清空缓冲；点击空白战场的第一下只返回游戏焦点。CombatInput另接受app显式注入的UI阻塞Callable，用于没有Control焦点的PopupMenu；阻塞时同时屏蔽事件与轮询移动。菜单接线、三选一门禁已通过本轮真实场景验证。
- 玩家实际命中扣血时，镜头轻晃约0.12秒；空挥、同段重复接触、无敌拒绝不震动。一次击中多个目标重启同一短脉冲，不累加幅度。震动暂停冻结，结束/离场归零，不影响瞄准。
- 滚轮缩放，Esc 打开共享 v002 设置菜单并暂停，L 中英文；底部按钮可重试、返回店铺。设置菜单内屏蔽底层输入；三选一期间可进入设置并返回继续选择。见 [SETTINGS_UI.md](SETTINGS_UI.md)。
- 按Build配置提供开场与波间三选一；左侧可查看构筑并点击“测试：再抽三选一”。选择期间暂停战斗，L可切语言。详情见 [BUILD_SYSTEM.md](BUILD_SYSTEM.md)。
- 右上角“刀光测试”面板可点击切换12种刀光，包含烈焰、苍蓝闪电、紫金雷霆、碎晶冰霜，以及最新的「焰浪 · 火焰重斩」，当前选择高亮。战斗中和普通暂停时可切换，三选一模态期间不可切换；切换不改变当前攻击的命中形状、伤害或技能时序。重新训练恢复默认金色流光。

正常训练为五波逐步强化：前四波从普通兵种合法预算组合抽取，第五波为精灵游侠Boss；`training_waves`控制各波，普通规划/夹具仍保留原`wave_count`，配置与状态机见 [敌人遭遇](ENEMY_ROLES_AND_ENCOUNTERS.md)。斥候攻击可被打断；重卫攻击抗非致死硬直，但仍可被击退。清场或阵亡后可重试。训练不会改变库存、金币、委托或存档。

## 训练工具与界面显示

普通训练和机制测试入口均有顶部「训练工具」按钮，默认收起；点击展开后可使用：

| 控件 | 当前行为 |
|---|---|
| 玩家无敌 | 免疫受到的伤害，独立于闪避无敌；关闭后恢复正常受伤 |
| 敌人无敌 | 当前及之后生成的敌人免疫伤害，仍可冻结、减速；只依赖实际扣血的白闪、击退、镜头震动等确认反馈不会伪造 |
| 恢复玩家生命 | 将存活玩家恢复至当前最大生命，不复活已死亡角色 |
| 追加一波敌人 | 按本房锁定深度追加合法阵容，保留场上活敌和当前Build；失败整组不生成。人数/出生检查与奖励隔离见 [敌人遭遇](ENEMY_ROLES_AND_ENCOUNTERS.md#训练追加敌人) |

顶部「界面显示」可分别显示/隐藏构筑与测试预设、训练深度、刀光效果、房间信息、训练状态与操作，也可全部隐藏/全部显示。顶部工具入口保留，避免隐藏后无法恢复；收起面板或隐藏HUD不取消已经启用的无敌。

三选一和设置是模态界面，仍须完成选择或关闭设置，不能通过「界面显示」跳过；模态期间训练工具命令不可用。胜利后可追加敌人继续练习，死亡后须先重新训练。死亡时仍可恢复隐藏的HUD以操作重试。

以上开关、显示偏好和追加记录只属于当前训练，重新训练会重置；不保存到Profile/Run。`app/training_tools.gd`协调命令、只读配置与面板；角色提供`set_damage_immunity(bool)`，表现层不直接修改生命。

## 基础战斗反馈

1. **移动攻击**：每个能力独立配置移动倍率；玩家三段为1，近战敌人的原型挥击为0。冲锋兵的专用位移见敌人模块。受击硬直、闪避与击退仍由角色/Motor仲裁。
2. **交替挥砍、刺击与右键姿态**：前两段使用扇形，第三段使用前方矩形，侧面和背后不被刺击命中；范围以能力JSON为准。剑尖美术距离独立配置，数值判定不读取模型长度。`attack_motions/*.tres`控制左右方向、收剑、刺出、回收、剑身俯仰和握持高度，进度来自能力逻辑时间线。R键重斩是抬剑→劈落，右键剑气直接进入释放姿态；临时角色通过rigs动作映射播放攻击，虚拟剑继续驱动刀光。`sword_primary`表现组按能力ID选三段姿态，special/skill使用施放快照中的表现键。
3. **敌人受击**：全部模型网格白色发光、红色外轮廓，周围飞散粒子。暂时覆盖材质后恢复；各实例互不串色。致死命中仍播放反馈，碰撞与攻击则立即停止。
4. **第二段击退**：命中并实际扣血后生效。以攻击者到目标的方向施加线性衰减冲量，重叠位置取施放方向；墙体阻挡，重复冲量替换。当前速度10米/秒、持续0.24秒，无碰撞时约1.2米；来源唯一为JSON。
5. **敌人血条**：红色表示实时生命，被扣掉的部分显示白色，短暂停留后平滑下降。连续命中保留尚未消退的白段并重置短暂停留；死亡归零动画不影响死亡判定。暂停时表现计时也暂停。
6. **命中镜头反馈**：`MeleeResolver.confirmed_hit` 只通知已提交伤害；训练 app 仅对玩家命中敌人触发震动。独立 `HitCameraShake` 输出屏幕平面偏移，由相机的 h_offset/v_offset 显示，幅度(0.045,0.026)米、总位移上限0.065米、持续0.12秒。使用确定性衰减脉冲，不消耗玩法随机数；读取鼠标瞄准前清除显示偏移，随后重新应用，避免反馈改变瞄准。

## 数值与资源入口

### 伤害跳字（2026-10-11）

玩家和敌人的 `ActorView` 均接入独立 `DamageNumbers` 表现组件，监听 `HealthRuntime.damaged(amount)` 已提交扣血事实。玩家红色、敌人浅金色；显示实际扣除生命（致死时截断到剩余HP），无敌、零伤害和已死亡目标不显示。整数省略小数，非整数最多显示配置的小数位数；不推断暴击或元素类别。

数字保留在受伤时的世界位置，面向镜头、向上飘动并渐隐，连续命中循环错位；每角色有数量上限。使用ActorView注入的表现时间，暂停冻结，致死跳字保留到消退，离开房间随节点清理；不消费玩法随机、不参与伤害裁定。普通训练、构筑训练及短路线共用该适配器。

配置：`game/presentation/combat/damage_number_style.tres`，由 `training_style.tres.damage_numbers` 强引用。字体默认沿用项目主题，可用 `font_override` 单独替换；字号、颜色、描边、起始高度、飘动距离、寿命、淡出及同时显示上限均在此Resource调整。

本次 `tests/damage_numbers.gd` 已在Forward+图形运行通过并检查截图：双方/小数、免疫、致死与过量伤害、暂停、世界锚定、连续命中数量限制、到期与离场清理。未单独进行高密度战斗性能验收。

| 调整内容 | 权威文件 |
|---|---|
| 生命、移速、硬直、AI、连段 | `game/data/combat/prototype.json` → actors |
| 伤害、范围、时序、独立动作冷却、攻击移动倍率、击退 | 同文件 → abilities；R键为`heavy_slash`，右键为`wave_cast` |
| 攻击意图缓冲、允许闪避取消阶段 | 同文件 → abilities.buffer_sec / dodge_cancel_phases |
| 动作基础形式、形式能力序列、执行器及构筑绑定 | `game/data/builds/prototype.json` → actions / forms；详细字段见Build API |
| 扇形/刺击、刺击宽度 | 同文件 → abilities.hit_shape / thrust_width_m；radius_m 对刺击表示前向长度 |
| 闪避充能/无敌/速度 | 同文件 → dodge；waves仅用于旧灰盒夹具 |
| 实际房间波次、深度预算、阵容 | `game/data/rooms/encounters.json` |
| 训练追加人数上限、出生搜索半径与步长 | 同文件 → `training_tools`；结构与业务校验见敌人文档 |
| 模型、碰撞体、动作名、模型朝向 | `game/presentation/combat/*_presentation.tres` |
| 刀光场景引用、镜头、临时剑刃位置 | `game/presentation/combat/training_style.tres` |
| 三段武器动作、重斩抬落、剑气发射姿态 | `game/presentation/combat/attack_motions/{slash_1,slash_2,thrust_3,heavy_slash,wave_cast}.tres`；分组映射在training_style.tres.attack_motion_groups |
| 命中镜头震动幅度、时长、频率、衰减 | `game/presentation/combat/hit_camera_shake_style.tres`，将幅度设为0可关闭 |
| 默认刀光引用 | `game/presentation/combat/fx/slash_default.tscn` → `golden_trail_v001/golden_slash.tscn` |
| 刀光覆盖、尾迹寿命、粒子、平滑采样 | `game/presentation/combat/fx/golden_trail_v001/golden_slash.tscn` |
| 刀光 HDR 纹理、曝光、透明度 | 同目录 `golden_filaments.tres`；纹理位于 `game/assets/vfx/golden_trail_v001/` |
| 训练场刀光测试选项、名称key、按钮布局 | `game/presentation/combat/effect_picker/palette.tres` |
| 烈焰、闪电、雷霆、冰霜的材质、尾迹、粒子 | `game/presentation/combat/fx/elemental_slashes_v001/{fire,lightning,thunder,frost}/` |
| 焰浪重斩的火焰体、热刃、动画粒子、烟与灯光 | `game/presentation/combat/fx/fire_slash_v002/` |
| 冰晶/岩脊地面技能样片的模型、曲线、裂纹、碎屑、雾与灯光 | `game/presentation/combat/fx/elemental_eruptions_v001/{ice,rock}_profile.tres` 与同目录材质 |
| 地面技能演示按钮、实例上限与摆放偏移 | `game/presentation/combat/skill_vfx_picker/style.tres`；仅表现演示 |
| 普通/寒冰剑气的弧刃、尾流、碎片、命中样片与消散 | `game/presentation/combat/fx/sword_waves_v001/{normal,frost}_profile.tres` 与同目录材质 |
| 雷霆裁决的分叉落雷、地面电弧、脉冲、碎屑与余雾 | `game/presentation/combat/fx/lightning_verdict_v001/profile.tres` 与同目录材质 |
| 霜冠天坠的下降轨迹、落地回弹、尾迹及逐段冰冠 | `game/presentation/combat/fx/frostfall_v001/profile.tres` 与同目录材质；复用冰岩模型及碎屑/雾层 |
| 实战剑气默认外观及基于施放快照的寒冰外观选择 | `game/presentation/builds/build_effects_style.tres` → `projectile_scenes/projectile_scene_rules` |
| 白闪时长、血条尺寸/延迟/下降速度、粒子引用 | `game/presentation/combat/hit_feedback.tres` |
| 白色发光、红边颜色/宽度 | `game/presentation/combat/fx/hit_flash.tres` |
| 飞散粒子数量、速度、颜色 | `game/presentation/combat/fx/hit_sparks.tscn` |
| 血条红/白/背景颜色 | `game/presentation/combat/fx/damage_bar.tres` |
| 当前房间地形、灯光、出生点 | `game/app/combat_training.tscn` 的 `room_presentation`；当前工作区指向 `game/presentation/rooms/fairy_forest_v2/presentation.tres` |
| 中英文 / 字体 | `game/data/locales/*.json` / `game/presentation/foliage/ui_typography.tres` |

修改JSON后运行 `tools/content/build_shop_preview_content.py`，重新开始训练读取新目录。必填字段没有隐藏默认值；击退速度与时长必须同时为0或同时为正。

schema_version=4在v3基础上新增每项能力必填的`lunge_speed_mps`与`lunge_duration_sec`（出手瞬间沿出招方向的前冲，二者同为0或同为正；由`CombatActor`在`cue_reached`时交给Motor执行，敌人和不前冲的技能填0）。v3起要求每项能力必填`hit_shape`与`thrust_width_m`：sector必须有正角度、刺击宽度为0；thrust必须角度为0、刺击宽度为正。另必填`buffer_sec`与`dodge_cancel_phases`；后者只允许windup/active/recovery且不得重复，空数组明确表示不能被闪避取消。运行时Loader和Python工具执行同样校验，旧版本不能静默读入。投射物形式仍保留真实能力伤害，由编译计划的executor选择执行路径；不把伤害设为0来伪装禁用近战。

## 动作接口与状态归属

| 接口 | 当前语义 |
|---|---|
| `CombatActor.set_action_program(actions, combat_catalog) -> bool` | 注入已校验的primary/special/skill编译计划，复制为只读；完整准备后替换，不刷新任何动作冷却。清缓冲、重置连段，正在执行的施放继续使用旧快照 |
| `request_action(id, input_frame=-1)` | 接受稳定动作ID，默认以渲染帧号仲裁同帧优先级；测试可注入帧号。未知动作、死亡/控制锁定、剩余冷却长于缓冲期的意图不入队 |
| `request_attack()` / `request_special()/request_skill()` / `request_dodge()` | primary、special及闪避的显式意图入口；敌人原单动作调用保留 |
| `clear_intents()` / `cancel(reason)` | 前者只清攻击/闪避请求，后者额外取消Runner、清移动与击退；死亡/控制/离场调用取消路径 |
| `CombatInput.new(player, camera, blocked: Callable = Callable())` | 注入当前app已知菜单的阻塞检查，update/event均执行；不遍历全局UI或搜节点。Control焦点门禁仍独立生效 |
| `AbilityRunner.start(ability, facing, context={})` | 单一身体执行器；开始承诺、锁方向、记录该动作冷却，并深复制只读cast_context。敌人/旧直接Runner夹具的空上下文使用单近战动作入口 |
| `cooldown_for(action_id)` | 查询独立动作冷却；兼容属性cooldown只表示最近一次动作的冷却，不用于三个动作共同门禁 |
| `cast_context`及`action_id/form_id/executor/presentation_key` | 同一施放的只读身份/完整编译计划，包含revision；运行中的效果与姿态读取旧快照，不能按当前新Build猜测旧施放 |
| `committed(cast_id, ability_id)` / `cue_reached(...)` | 原签名保留；订阅者同步读取施放上下文。取消后的cue不会恢复生效窗口 |
| `finished(cast_id, ability_id, reason)` | 完成或取消事实；当前原因包括completed/cancelled/dodge/hit/control/death。取消不清已有冷却 |

`MeleeResolver`只处理`runner.executor == "melee"`，角色和房间道具共用该门禁；Build Runtime负责逻辑cue上的投射物发射与后续效果。当前控制锁定沿用既有行为：取消动作并暂停其冷却推进；普通暂停由app停止调用规则step。

## 模块边界与后续替换

- 2026-09-26 武器表现更新：`training_style.tres.weapon_visual_scene` 注入独立长剑 GLB，替换白色 BoxMesh。源模型剑刃单位长度、负Z指向剑尖；按已有 `blade_size.z` 缩放视觉子节点，刀光中点节点不缩放，伤害与施放逻辑不变。源文件与说明见 `source_assets/weapons/longsword/v001/README.md`。

- `AbilityRunner`拥有攻击时序；`CombatActor`决定动作许可；`CharacterMotor`唯一负责移动/碰撞/击退；`MeleeResolver`负责接触去重与受击调用。
- `AttackMotion`只按能力阶段采样武器/身体姿态；`HitCameraShake`只生成镜头偏移。命中事实通过局部信号由app连接，不用表现回调扣血。
- `HitFeedback`和`DamageBarState`只处理已确认结果的显示，不能修改生命。每个血条独立材质；模型原材质引用逐网格保存并恢复。
- 模型替换：改对应 `*_presentation.tres`。临时模型、动作映射和替换流程见[战斗视觉](COMBAT_VISUAL_PASS.md)；动作读取逻辑阶段播放，不能让动画轨道决定伤害。
- 刀光替换：调用 `ActorView.set_weapon_effect(PackedScene)`；显式传null可以关闭剑VFX，姿态和规则继续运行。场景根为Node3D，实现`set_active(bool)`与`set_time_running(bool)`；挂点位于剑身中部。可选`configure_blade(length)`由ActorView注入美术剑长，正Z为剑根、负Z为剑尖。每个AttackMotion另有显式trail_enabled；当前剑气姿态不出近战刀光。切换特效不修改施放或伤害。构筑派生效果使用独立Resource，刀光面板仍只换美术，见[BUILD_SYSTEM.md](BUILD_SYSTEM.md)。
- 训练是无持久状态的独立场景；远程、冲锋、支援AI已接入，正式经济和冒险存档结算尚未接入；平坦内庭随机障碍绕行和临时搜刮已实现，见 ROOM_PROPS_PROTOTYPE.md；训练构筑可组合与升级，重新训练会重置。


- 刀光可选实现 `sample_current_pose()` / `finish_at_current_pose()`：姿态更新后采样，取消/死亡回待机前结束尾迹，避免回拉弧线；死亡后的尾效也服从暂停。正式接口位于ActorView，具体资产制作说明按需读取。

## 验证

按改动选择脚本见[验证索引](VALIDATION.md)。旧特效制作与逐轮验证见[历史记录](archive/2026-10-13-doc-cleanup/COMBAT_VALIDATION_HISTORY.md)，不作为当前版本通过声明。

## 玩家受击半径

`game/data/combat/prototype.json` 的必填 `player_hurt_radius_m` 当前为0.30米，由严格schema校验、`CombatCatalog.player_hurt_radius()`只读暴露。训练场与短路线房间均显式注入EnemyRuntime，供敌方箭矢、箭雨边界和冲锋命中使用；移动胶囊仍是0.23米，过门、绕障、出生与翻滚物理检查不扩大。箭雨退路的危险区膨胀使用受击半径，通路的物理扫掠仍使用移动胶囊。普通近战扇形沿用现有判定，本次未改。

2026-10-07验证：内容/schema/388双语key通过；`tests/player_hurt_radius.gd`9项通过，覆盖旧半径擦身未命中、新半径两侧擦身命中、范围外仍未命中、无敌与墙阻挡、两类场景入口脚本编译。未重跑完整图形场景；配置修改后重启训练。

## 剑气瞬发

`abilities[id=wave_cast]`的`windup_sec=0`、`cooldown_sec=1.0`（2026-10-07）；基础动作许可与输入仲裁仍生效，接受施放时立刻触发发射，基础剑气无需等待蓄力；装备charged_wave后按住/松开右键走蓄力流程。保留0.1秒释放/0.3秒收招表现，它们不延迟剑气生成；普通三连击和重斩时序不变。schema允许零前摇，AbilityRunner在提交快照后同步发cue；同一施放不重复发射。冷却从接受施放计，按游戏逻辑时钟推进，暂停不推进。

本次内容检查、action_build_runtime、dual_actions、combat_rules、post_clear_skills 均通过；覆盖同帧发射、1秒冷却、无重复cue、同步取消、清场后空放与普通攻击回归。使用无头场景验证，未做新图形手感验收。

满蓄力剑气已按寒冰演示校准为约3.9米主体宽，实际命中半径同步为1.95米；满蓄力采用原演示整体比例。调参入口为Build JSON的charged_wave.ranks与build_effects_style.tres满蓄力规则。2026-10-12专项验证尺寸、3倍伤害、侧方命中、短按和无隐式冻结；图形手感待用户体验。
