# 战斗训练原型

更新：2026-10-02（左右键动作与程序剑姿态）；战斗 schema_version=3，动作绑定构筑的接口见 [Build API](BUILD_IMPLEMENTATION_CONTRACT.md)。本页区分已写入代码与本轮整合验证，验证状态见末节。训练入口已接入森林庭院，敌人模型仍为占位；简易场景保留为回归夹具。

## 操作

店铺按 **F6** 或点击训练按钮进入 `app/combat_training.tscn`；弹窗打开时入口不可用。当前房间及美术接入见 [FOREST_COURTYARD_INTEGRATION.md](FOREST_COURTYARD_INTEGRATION.md)。

- WASD 移动、鼠标瞄准；左键 `primary` 三连击，第一段左→右、第二段右→左、第三段向前刺击。右键 `special` 点击重斩，选择右键剑气形态后改为一次远程施放；Shift 闪避。按键不是构筑身份。
- 清场后仍可移动、普通攻击和右键施放，正在起手/飞行的玩家技能不因胜利取消；遵守原冷却、死亡、受控、暂停和UI门禁。训练 `finish_rewards()` 只结束自动奖励，`finish()` 用于死亡/退出；调试选卡与预设不属于自动奖励。当前路线房间同样保持执行直到退出，正式持久关卡尚未实现。
- 普攻三个阶段均可移动；重斩与剑气使用各自能力配置的移动倍率。起手锁定本次方向，近战区域随角色平移；剑气从逻辑cue发射，完全跳过近战区域及房间物件的近战命中路径。
- 忙碌期间只缓存一个带动作ID的有效攻击意图，后到有效意图替换；同帧固定按闪避→special→primary仲裁。缓冲时长与空闲后的连段重置时长是两个独立配置。special实际起手才重置primary连段。
- 左右键冷却独立，在开始承诺时扣除，取消不返还，切换形态不刷新。能力配置允许的阶段才能被闪避取消；当前重斩/剑气允许起手、恢复取消，生效阶段不允许。cue前取消不会发射剑气。
- 文本或其它可见Control持有GUI焦点时，停止采集移动和新攻击并清空缓冲；点击空白战场的第一下只返回游戏焦点。CombatInput另接受app显式注入的UI阻塞Callable，用于没有Control焦点的PopupMenu；阻塞时同时屏蔽事件与轮询移动。菜单接线、三选一门禁已通过本轮真实场景验证。
- 玩家实际命中扣血时，镜头轻晃约0.12秒；空挥、同段重复接触、无敌拒绝不震动。一次击中多个目标重启同一短脉冲，不累加幅度。震动暂停冻结，结束/离场归零，不影响瞄准。
- 滚轮缩放，Esc 打开共享 v002 设置菜单并暂停，L 中英文；底部按钮可重试、返回店铺。设置菜单内屏蔽底层输入；三选一期间可进入设置并返回继续选择。见 [SETTINGS_UI.md](SETTINGS_UI.md)。
- 开场与第一波清场后三选一；左侧可查看构筑并点击“测试：再抽三选一”。选择期间暂停战斗，L可切语言。详情见 [BUILD_SYSTEM.md](BUILD_SYSTEM.md)。
- 右上角“刀光测试”面板可点击切换12种刀光，包含烈焰、苍蓝闪电、紫金雷霆、碎晶冰霜，以及最新的「焰浪 · 火焰重斩」，当前选择高亮。战斗中和普通暂停时可切换，三选一模态期间不可切换；切换不改变当前攻击的命中形状、伤害或技能时序。重新训练恢复默认金色流光。

当前为五种敌人的预算随机两波，配置与状态机见 [敌人遭遇](ENEMY_ROLES_AND_ENCOUNTERS.md)。斥候攻击可被打断；重卫攻击抗非致死硬直，但仍可被击退。清场或阵亡后可重试。训练不会改变库存、金币、委托或存档。

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
2. **交替挥砍、刺击与右键姿态**：前两段使用扇形，第三段使用前方矩形，侧面和背后不被刺击命中；范围以能力JSON为准。剑尖美术距离独立配置，数值判定不读取模型长度。`attack_motions/*.tres`控制左右方向、收剑、刺出、回收、剑身俯仰和握持高度，进度来自能力逻辑时间线。右键重斩是抬剑→劈落，剑气是后收→前伸；角色仍播放已有idle/run，没有新增骨骼攻击动画。`sword_primary`表现组按能力ID选三段姿态，special使用施放快照中的表现键。
3. **敌人受击**：全部模型网格白色发光、红色外轮廓，周围飞散粒子。暂时覆盖材质后恢复；各实例互不串色。致死命中仍播放反馈，碰撞与攻击则立即停止。
4. **第二段击退**：命中并实际扣血后生效。以攻击者到目标的方向施加线性衰减冲量，重叠位置取施放方向；墙体阻挡，重复冲量替换。当前速度10米/秒、持续0.24秒，无碰撞时约1.2米；来源唯一为JSON。
5. **敌人血条**：红色表示实时生命，被扣掉的部分显示白色，短暂停留后平滑下降。连续命中保留尚未消退的白段并重置短暂停留；死亡归零动画不影响死亡判定。暂停时表现计时也暂停。
6. **命中镜头反馈**：`MeleeResolver.confirmed_hit` 只通知已提交伤害；训练 app 仅对玩家命中敌人触发震动。独立 `HitCameraShake` 输出屏幕平面偏移，由相机的 h_offset/v_offset 显示，幅度(0.045,0.026)米、总位移上限0.065米、持续0.12秒。使用确定性衰减脉冲，不消耗玩法随机数；读取鼠标瞄准前清除显示偏移，随后重新应用，避免反馈改变瞄准。

## 数值与资源入口

| 调整内容 | 权威文件 |
|---|---|
| 生命、移速、硬直、AI、连段 | `game/data/combat/prototype.json` → actors |
| 伤害、范围、时序、独立动作冷却、攻击移动倍率、击退 | 同文件 → abilities；右键能力为`heavy_slash` / `wave_cast` |
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
| 当前房间地形、灯光、出生点 | `game/presentation/rooms/forest_courtyard_v001/room.tscn`；旧training_arena保留为夹具 |
| 中英文 / 字体 | `game/data/locales/*.json` / `game/presentation/foliage/ui_typography.tres` |

修改JSON后运行 `tools/content/build_shop_preview_content.py`，重新开始训练读取新目录。必填字段没有隐藏默认值；击退速度与时长必须同时为0或同时为正。

schema_version=3继续要求每项能力必填`hit_shape`与`thrust_width_m`：sector必须有正角度、刺击宽度为0；thrust必须角度为0、刺击宽度为正。另必填`buffer_sec`与`dodge_cancel_phases`；后者只允许windup/active/recovery且不得重复，空数组明确表示不能被闪避取消。运行时Loader和Python工具执行同样校验，旧版本不能静默读入。投射物形式仍保留真实能力伤害，由编译计划的executor选择执行路径；不把伤害设为0来伪装禁用近战。

## 动作接口与状态归属

| 接口 | 当前语义 |
|---|---|
| `CombatActor.set_action_program(actions, combat_catalog) -> bool` | 注入已校验的primary/special编译计划，复制为只读；完整准备后替换，不刷新任何动作冷却。清缓冲、重置连段，正在执行的施放继续使用旧快照 |
| `request_action(id, input_frame=-1)` | 接受稳定动作ID，默认以渲染帧号仲裁同帧优先级；测试可注入帧号。未知动作、死亡/控制锁定、剩余冷却长于缓冲期的意图不入队 |
| `request_attack()` / `request_special()` / `request_dodge()` | primary、special及闪避的显式意图入口；敌人原单动作调用保留 |
| `clear_intents()` / `cancel(reason)` | 前者只清攻击/闪避请求，后者额外取消Runner、清移动与击退；死亡/控制/离场调用取消路径 |
| `CombatInput.new(player, camera, blocked: Callable = Callable())` | 注入当前app已知菜单的阻塞检查，update/event均执行；不遍历全局UI或搜节点。Control焦点门禁仍独立生效 |
| `AbilityRunner.start(ability, facing, context={})` | 单一身体执行器；开始承诺、锁方向、记录该动作冷却，并深复制只读cast_context。敌人/旧直接Runner夹具的空上下文使用单近战动作入口 |
| `cooldown_for(action_id)` | 查询独立动作冷却；兼容属性cooldown只表示最近一次动作的冷却，不用于左右键共同门禁 |
| `cast_context`及`action_id/form_id/executor/presentation_key` | 同一施放的只读身份/完整编译计划，包含revision；运行中的效果与姿态读取旧快照，不能按当前新Build猜测旧施放 |
| `committed(cast_id, ability_id)` / `cue_reached(...)` | 原签名保留；订阅者同步读取施放上下文。取消后的cue不会恢复生效窗口 |
| `finished(cast_id, ability_id, reason)` | 完成或取消事实；当前原因包括completed/cancelled/dodge/hit/control/death。取消不清已有冷却 |

`MeleeResolver`只处理`runner.executor == "melee"`，角色和房间道具共用该门禁；Build Runtime负责逻辑cue上的投射物发射与后续效果。当前控制锁定沿用既有行为：取消动作并暂停其冷却推进；普通暂停由app停止调用规则step。

## 模块边界与后续替换

- 2026-09-26 武器表现更新：`training_style.tres.weapon_visual_scene` 注入独立长剑 GLB，替换白色 BoxMesh。源模型剑刃单位长度、负Z指向剑尖；按已有 `blade_size.z` 缩放视觉子节点，刀光中点节点不缩放，伤害与施放逻辑不变。源文件与说明见 `source_assets/weapons/longsword/v001/README.md`。

- `AbilityRunner`拥有攻击时序；`CombatActor`决定动作许可；`CharacterMotor`唯一负责移动/碰撞/击退；`MeleeResolver`负责接触去重与受击调用。
- `AttackMotion`只按能力阶段采样武器/身体姿态；`HitCameraShake`只生成镜头偏移。命中事实通过局部信号由app连接，不用表现回调扣血。
- `HitFeedback`和`DamageBarState`只处理已确认结果的显示，不能修改生命。每个血条独立材质；模型原材质引用逐网格保存并恢复。
- 模型替换：改对应 `*_presentation.tres`。目前动画仅映射idle/run；最终挥剑动作由ActorView读取逻辑阶段播放，不能让动画轨道决定伤害。
- 刀光替换：调用 `ActorView.set_weapon_effect(PackedScene)`；显式传null可以关闭剑VFX，姿态和规则继续运行。场景根为Node3D，实现`set_active(bool)`与`set_time_running(bool)`；挂点位于剑身中部。可选`configure_blade(length)`由ActorView注入美术剑长，正Z为剑根、负Z为剑尖。每个AttackMotion另有显式trail_enabled；当前剑气姿态不出近战刀光。切换特效不修改施放或伤害。构筑派生效果使用独立Resource，刀光面板仍只换美术，见[BUILD_SYSTEM.md](BUILD_SYSTEM.md)。
- 训练是无持久状态的独立场景；远程、冲锋、支援AI已接入，正式经济和冒险存档结算尚未接入；平坦内庭随机障碍绕行和临时搜刮已实现，见 ROOM_PROPS_PROTOTYPE.md；训练构筑可组合与升级，重新训练会重置。


- 刀光可选实现 `sample_current_pose()` / `finish_at_current_pose()`：姿态更新后采样，取消/死亡回待机前结束尾迹，避免回拉弧线；死亡后的尾效也服从暂停。正式接口位于ActorView，具体资产制作说明按需读取。

## 验证

### 霜冠天坠表现原型（2026-10-03）

- 训练“技能特效演示”增加第六项「霜冠天坠」。沿用霜冠裂地的冰晶材质、碎冰、寒雾和冰冠：七段落点从近到远推进，每段主锥及两枚侧锥尖端朝下，从空中加速坠落；末端补五枚冰冠锥。落地时触发闪光、扩散环、碎片与寒雾，随后缩退消散。当前仅表现演示，不造成伤害、冻结或地形碰撞。
- 场景 `game/presentation/combat/fx/frostfall_v001/frostfall.tscn`，局部负Z为推进方向。`frostfall_profile.gd` 扩展冰岩表现Resource，`frostfall_effect.gd` 复用既有碎屑、雾、冲击环采样，仅替换冰锥轨迹并增加尾迹/落地闪光。全部层共享局部可暂停时钟，材质和视觉RNG按实例隔离；支持重播、确定性时间采样及显式/自动清理。
- 冰锥的局部+Y尖端沿下降曲线移动，落地后固定在嵌入点；消散时围绕尖端缩小。坠落尾迹只在空中显示，地面碎屑、雾与闪光从落地时刻开始，不能把视觉落地回调用于正式命中判定。
- 表现参数以 `profile.tres` 和材质为权威。初稿生成器 `source_assets/vfx/frostfall_v001/build_resources.py` 重跑会覆盖本组Resource；模型沿用 `game/assets/vfx/elemental_eruptions_v001/models/`，源文件仍在冰岩源素材目录。
- 六选项改为三列两行Grid，列数来自 `skill_vfx_picker/style.tres.option_columns`，按钮恢复16px字号。可收起、重播、清理、3实例上限及既有模态门禁沿用原接口。
- 独立入口 `启动落冰特效演示.cmd` / `game/presentation/combat/frostfall_showcase/showcase.tscn`，支持空格重播、暂停、慢放、循环和L中英切换。复现录制用 `source_assets/vfx/frostfall_v001/preview_tools/capture_frostfall.ps1` 和 `encode_preview.py`。
- 本次实际验证：资源导入通过；专项轨迹/采样29项和训练集成43项headless检查通过，覆盖向下尖端、近到远落点、撞地前无地面碎屑/雾/闪光、倒放采样、材质/RNG隔离、暂停/销毁、真实按钮点击、六选项与HP/Build隔离。默认庭院Forward+中英各6项边界/按钮检查通过，截图已查看；385个双语key与PO一致。完整180帧Shader图形验收及阶段图已检查，修正了尾迹UV边缘负值导致的异常亮斑。庭院退出仍有已知7个Texture RID警告；正式技能规则、主观手感和完整性能尚未验收。
- 实际渲染预览 `source_assets/vfx/frostfall_v001/previews/final/frostfall_godot.mp4` 为1280×720、30fps、6秒；同目录有 `frostfall_timeline.jpg`。采用固定时间采样，录制帧率不代表实时性能。

### 雷霆裁决表现原型（2026-10-03）

- 训练“技能特效演示”增加第五项「雷霆裁决」。短暂聚能后，中心主雷与三道侧雷错开落下；白蓝雷芯、蓝紫辉光、地面电弧、两层扩散环、电火花、飞石和余雾分层收尾。4.2秒自动结束，目前只演示外观，不造成伤害、眩晕或地形变化。
- 独立入口 `启动雷电特效演示.cmd` / `game/presentation/combat/lightning_showcase/showcase.tscn`，沿用冰岩展示台；支持空格重播、暂停、0.35倍慢放、循环及L中英切换。训练场沿用局部负Z朝向、3实例上限和模态门禁，当前六项布局见上方霜冠天坠段落。
- 场景为 `game/presentation/combat/fx/lightning_verdict_v001/lightning_verdict.tscn`。雷光在Godot中预生成交叉面带及分叉，每道雷预备4种形态，运行时只切换可见形态；电火花/石屑使用MultiMesh。沿用已认可的岩石碎块、冲击环和雾Shader，无需新增高模。
- 全部动态层共享可暂停的局部时钟；支持 `set_time_running`、`set_playback_speed`、`restart`、`seek_visual`、`finish`。可变材质按实例复制，视觉RNG独立，采样不消耗随机流。表现参数以 `.tres` 为权威，初稿生成器 `source_assets/vfx/lightning_verdict_v001/build_resources.py` 重跑会覆盖本组Resource。
- 雷电接入时的实际验证：Godot导入及Forward+完整150帧渲染通过；headless专项51项通过，覆盖确定性倒放采样、材质/随机隔离、暂停恢复、自动/显式销毁、实际按钮点击、既有四选项、HP/Build隔离及模态门禁。默认庭院中英各6项检查通过，使用真实Viewport点击雷电按钮并检查房间、刀光、深度面板和底部说明边界；截图已人工查看。当时380个双语key及PO一致。无新增脚本/Shader错误；庭院退出仍有既有7个Texture RID警告。尚未验收正式技能伤害、主观手感和完整战斗性能。
- 预览 `source_assets/vfx/lightning_verdict_v001/previews/final/lightning_verdict_godot.mp4` 为Godot实际渲染，1280×720、30fps、5秒；同目录有 `lightning_timeline.jpg`。录制采用固定时间采样，不能据此声称实时帧率；复现用源素材目录中的 `preview_tools/capture_lightning.ps1` 和 `encode_preview.py`。

### 普通与寒冰剑气表现

- 训练“技能特效演示”现在提供冰晶突进、岩脊冲击、普通剑气、寒冰剑气、雷霆裁决、霜冠天坠六选项；剑气纯视觉样片按固定路径飞行并播放终点爆发，不造成伤害。独立入口为 `启动剑气特效演示.cmd` / `game/presentation/combat/sword_wave_showcase/showcase.tscn`，支持重播、慢放、暂停与中英切换。
- 实战已有的 `sword_wave` 投射物已映射新普通剑气；只有本次施放的已提交快照包含 `contact_freeze` 时选寒冰剑气。美术不会添加冻结；带 `frost_blast` 但不带直接冻结的构筑保持普通飞行外观，沿用既有寒霜范围反馈。规则选择语义见[Build API](BUILD_IMPLEMENTATION_CONTRACT.md)。
- `normal_wave.tscn/frost_wave.tscn` 仅负责局部飞行外观，由 `configure_effect(fact)` 进入外部时钟模式，`sync_effect(fact,delta)` 接受推进；父适配器独占位置、朝向、半径缩放和销毁。`set_time_running(false)` 冻结全部视觉层，局部随机及材质按实例隔离。普通/寒冰弧刃各940三角面，Blender源文件在 `source_assets/vfx/sword_waves_v001/models/sword_wave_models_v001.blend`。
- 普通/寒冰剑气主体及残影刃面保持平行地面，随发射方向只做平面转向；对应profile取消刃面倾斜，源资源生成器同步。粒子仍可上下散落，不改变攻击半径/速度/伤害。2026-10-06 `post_clear_skills.gd` 检查真实节点360方向、跨清场起手、重复空放、暂停、奖励隔离和退出清理；headless及Forward+通过，图形退出仍有已知7个Texture RID警告。路线集成343项、训练工具回归通过。
- 演示的宽弧用于外观评审；真实投射物通过Resource中的 `projectile_unit_scale` 将主体归一到局部宽1，再接受适配器的真实 `2×radius` 宽度。稀薄尾流/柔光不是攻击几何，未修改任何伤害、半径、速度或状态JSON。
- `normal_impact.tscn/frost_impact.tscn` 的完整命中爆发目前用于独立与训练演示；实战仍使用既有命中反馈，未改全局事件TTL。`normal_demo.tscn/frost_demo.tscn` 分别组合发射、飞行、命中及尾流消散，支持 `seek_visual(seconds)` 确定性采样。表现参数以 `.tres` 为权威，初稿生成器 `source_assets/vfx/sword_waves_v001/build_wave_resources.py` 重跑会覆盖手工调参。
- 剑气接入时的历史验证：真实投射物绑定27项、既有 `action_build_vfx.gd` 表现隔离114项、四按钮headless及Forward+各37项通过；当时375个翻译key及PO一致。普通/直接冻结/仅寒霜爆破选型、旧弹Build快照、null关闭、半径缩放和暂停均覆盖。通过真实Viewport右键→Runner cue→Runtime→表现适配器在默认庭院截图；亮刃宽约0.746/0.748m，前尖距中心约0.358/0.360m，原规则半径0.38m未变。中英UI与既有面板/底部说明无交叠。无新增Shader或脚本错误，默认庭院退出仍有已知7个Texture RID警告；完整战斗性能未验收。
- 动态预览 `source_assets/vfx/sword_waves_v001/previews/final/sword_waves_godot.mp4` 为Godot固定时间采样的6秒实际渲染，1280×720、30fps；同目录保存普通/寒冰分片、`sword_wave_comparison.jpg` 和 `sword_wave_timeline.jpg`。采样帧率不代表实时性能。

### 冰晶与岩脊技能表现原型

- 训练场“技能特效演示”可施放冰晶突进/岩脊冲击、剑气及雷电样片；标题右侧↻再次施放、×清理。跟随角色朝向，默认最多3个实例。紧凑面板可收起，位于操作说明之上；房间信息显示时居中，否则停靠右侧。随“界面显示→刀光效果”隐藏恢复。
- 独立入口：根目录 `启动冰岩特效演示.cmd`，场景 `game/presentation/combat/eruption_showcase/showcase.tscn`。支持1/2切换、空格重播、按钮暂停/慢放/循环、L中英切换。只是开发预览入口，不是Release。
- 当前只实现视觉，不产生伤害、冻结状态或地形碰撞。正式技能应由Combat逻辑时间线确认命中后驱动表现，不能从地刺出现、碎石接地或材质时间反推命中。
- 表现由独立 `TrainingSkillVfx` 显式注入；根节点局部负Z为前进方向、Y=0为地面。`set_time_running(bool)` 暂停全部视觉层，`set_playback_speed(float)` 调整预览速度，`restart()` 重播，`seek_visual(seconds)` 确定性采样，`finish()` 清理。到期自动释放；死亡/换房/重试/退出显式清理。
- 模型在独立Blender后台进程生成，源文件 `source_assets/vfx/elemental_eruptions_v001/models/elemental_eruption_models_v001.blend`；运行时8个OBJ在 `game/assets/vfx/elemental_eruptions_v001/models/`。每个主尖176–514三角面，碎块各44三角面。
- 地刺依次冲出、过冲回落、末端外张冠簇、碎片弹跳与缩退、寒雾/扬尘、地裂和扩散环共享局部时钟。碎片使用MultiMesh批次，雾为独立Billboard；视觉随机流独立于玩法RNG，可变材质按实例复制。表现参数以Resource为权威，`source_assets/vfx/elemental_eruptions_v001/build_effect_resources.py` 是初稿生成器；重新运行会覆盖这组美术Resource，保留手工调参前不要运行它。
- 本次实际验证：Godot资源导入通过；训练headless 28项通过；Forward+ 26项通过并检查1280×800中英面板截图，覆盖指针按钮、位置朝向、3实例上限、暂停/模态、HP/Build/RNG隔离和清理。图形验收覆盖Shader、主体/碎屑/雾层及独立展示画面。录制采用固定时间采样，不表示实时帧率；正式战斗性能、手感与伤害判定尚未验收。
- 已检查真实默认庭院的冰/岩1.2秒画面及紧凑面板，房间信息/刀光菜单/底部说明与返回按钮均无交叠，Forward+退出码0；仅有项目既有7个Texture RID退出警告。展示视频 `source_assets/vfx/elemental_eruptions_v001/previews/final/elemental_eruptions_godot.mp4` 为Godot实际渲染，1280×720、30fps、共10秒；同目录有分技能视频和时序对照图。复现用 `preview_tools/capture_eruptions.ps1`、`encode_previews.py`（相对于该源素材目录）。

### 2026-10-02 左右键动作：当前验证

- 内容/PO、Combat schema3与Build v5通过；dual_actions规则测试通过，覆盖仲裁、连段、冷却、缓冲、取消、快照、姿态/空VFX、Control焦点与Popup阻塞。
- action_build_runtime通过；action_build_vfx的114项表现隔离检查通过。实际动作快照、旧弹体、默认/关闭/替换表现、暂停取消清房有针对性验证。
- action_build_integration通过headless和Forward+1280×800：真实卡片指针、右键、预设菜单信号、三预设、普通选择/替换说明、双语和真实重试。截图已检查，长描述可滚动。
- 本轮training_tools、training_damage_override及控制/真实时序回归通过。仍有7个Texture RID图形退出警告；主观手感、完整性能与人工输入法未验收。详细列表见[验证索引](VALIDATION.md)。
### 2026-10-02 训练工具

- 已通过：`training_damage_override.gd`，覆盖伤害无敌、实损反馈、闪避独立、无敌目标接触冻结、恢复生命不复活。
- 已通过：`training_tools_content.gd`39项运行时内容检查、`combat_rules.gd`及`enemy_roles.gd`（360个遭遇计划）核心回归。
- 已通过：`training_tools.gd`机制入口无头与Forward+1280×800集成，以及`-- --ordinary`普通训练无头完整路径。覆盖Viewport实际按钮点击、模态门禁、新旧及自然下一波敌人继承无敌、追加保留Build/锁定计划、人数与出生空间约束、整组失败隔离、显示恢复、奖励/掉落不重复、胜利后续练、死亡与真实场景重试。
- 内容Python校验与PO一致性通过，共266个双语key；专项31项配置校验通过，27个非法样本拒绝。
- 已检查中英文工具面板截图`builds/training_tools_{zh_CN,en}.png`及边界；显示菜单通过PopupMenu信号验证。图形退出仍有既有7个Texture RID警告，本轮无SCRIPT ERROR。人工鼠标试玩、主观手感与性能验收尚未完成。未生成Release，未新增Git提交。

按 [验证索引](VALIDATION.md) 运行战斗、反馈、连段/镜头与对应刀光测试。历史包含规则、真实移动攻击、剑尖轨迹、暂停/取消、双语/重试及美术切换隔离；旧截图/数量/逐轮日志在归档，不作为本次全量通过声明。性能未解决项见 [KNOWN_ISSUES](KNOWN_ISSUES.md)。

## 玩家受击半径

`game/data/combat/prototype.json` 的必填 `player_hurt_radius_m` 当前为0.30米，由严格schema校验、`CombatCatalog.player_hurt_radius()`只读暴露。训练场与短路线房间均显式注入EnemyRuntime，供敌方箭矢、箭雨边界和冲锋命中使用；移动胶囊仍是0.23米，过门、绕障、出生与翻滚物理检查不扩大。箭雨退路的危险区膨胀使用受击半径，通路的物理扫掠仍使用移动胶囊。普通近战扇形沿用现有判定，本次未改。

2026-10-07验证：内容/schema/388双语key通过；`tests/player_hurt_radius.gd`9项通过，覆盖旧半径擦身未命中、新半径两侧擦身命中、范围外仍未命中、无敌与墙阻挡、两类场景入口脚本编译。未重跑完整图形场景；配置修改后重启训练。

## 剑气瞬发

`abilities[id=wave_cast]`的`windup_sec=0`、`cooldown_sec=1.0`（2026-10-07）；形态许可与输入仲裁仍生效，接受施放时立刻触发发射，无需等待蓄力。保留0.1秒释放/0.3秒收招表现，它们不延迟剑气生成；普通三连击和重斩时序不变。schema允许零前摇，AbilityRunner在提交快照后同步发cue；同一施放不重复发射。冷却从接受施放计，按游戏逻辑时钟推进，暂停不推进。

本次内容检查、action_build_runtime、dual_actions、combat_rules、post_clear_skills 均通过；覆盖同帧发射、1秒冷却、无重复cue、同步取消、清场后空放与普通攻击回归。使用无头场景验证，未做新图形手感验收。
