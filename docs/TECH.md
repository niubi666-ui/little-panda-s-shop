# 技术说明

更新：2026-10-18。只写“东西在哪、怎么连、怎么测”。各系统更细的历史接口说明在 `docs/archive/2026-10-15/`（例如 `BUILD_IMPLEMENTATION_CONTRACT.md`、`COMBAT_MECHANISMS.md`、`ELITE_RANGER.md`），代码本身是最终依据。

## 目录

| 目录（`game/` 下） | 内容 |
|---|---|
| `app/` | 场景组装与流程。战斗训练的总装配在 `combat_training.gd`；店铺 `main.gd`；短路线 `run_preview.gd` + `run_room.gd`；`session/` 放训练构筑、掉落、路线的内存会话 |
| `content/` | 各类 JSON 的 Loader（读取+校验）和 Catalog（只读定义） |
| `combat/` | `actors/` 角色、Motor、生命；`abilities/` 技能时间线；`effects/` 近战判定与范围伤害；`status/` 状态；`builds/` 构筑编译与执行；`enemies/` 敌人 AI；`ai/` 近战 AI |
| `rogue/` | `encounters/` 遭遇规划；`rooms/` 房间协议与道具摆放；`run/` 路线与地图生成 |
| `shop/` | 装修规则与会话、店铺场景 |
| `presentation/` | 所有看得见、听得见的东西（见下文） |
| `data/` | 全部玩法 JSON，入口 `manifest.json`，schema 在 `data/schemas/` |
| `tests/` | 测试与截图脚本 |
| `assets/` | 运行时模型、贴图、音效 |

源美术在仓库根的 `source_assets/`，工具脚本在 `tools/`。

## 数据流

```text
data/manifest.json → content/*_loader.gd（严格 JSON → schema → 引用 → 业务校验）
  → 只读 Catalog → app 注入 combat / rogue / presentation
```

- Loader 拒绝未知字段和缺失字段，错误里带文件、ID、字段。**新增 JSON 字段时同时改 schema 和 Loader/Catalog**。
- 每帧不读文件；运行中不热重载，改 JSON 后重开场景。
- 离线检查（含翻译 PO 一致性）：`builds/content_venv/Scripts/python.exe tools/content/build_shop_preview_content.py --check`。改了翻译 JSON 后去掉 `--check` 重新生成 PO。

## 每类配置在哪

### 玩法（JSON，`game/data/`）

| 想调什么 | 文件 |
|---|---|
| 玩家/六种敌人十属性、物/魔/真实伤害规则、AD/AP 公式、派生继承/元素成长、敌人前摇下限 | `combat/attributes.json`（schema 1；`actors`、`linear_profiles`、`derived_profiles`、`effect_profiles`、`upgrade_policies`；详见 [属性规则](COMBAT_ATTRIBUTES.md)） |
| 硬直、霸体与破防；技能前摇/判定/收招、冷却、范围、击退、出招前冲；闪避；受击半径 | `combat/prototype.json`（schema 9；角色用 `attribute_profile_id`，技能用 `damage_profile_id`，不再重复 HP/移速/伤害。闪避 `movement_duration_sec` 为位移段，`duration_sec` 含起身/冲斩输入窗口；`dodge.attack_distance_m` 默认 6 米；`attack_roll_exit_fraction/attack_roll_playback_speed` 控制翻到落地；`attack_carry_speed_mps/attack_carry_distance_ratio` 控制起刀推进） |
| 构筑卡、动作、形态、投射物、状态（冰冻/寒印/减速）、控制抗性、训练预设、预算上限 | `builds/prototype.json`（schema 8；测试箭也用 `damage_profile_id`） |
| 卡牌品质分组、各类房间的奖励品质权重 | `builds/reward_groups.json` |
| 元素状态（层数、持续、灼烧伤害、感电放电、碎甲易伤）与六种反应（伤害、范围、推拉、易伤、减速、熔岩区域） | `builds/elements.json`（字段为 0 / 空字符串表示不用） |
| 敌人角色参数（近战兵的出手名额、绕圈与后撤；弩手射程、冲锋速度、游侠招式……） | `enemies/roles.json`（schema 2；各 `*_damage_profile_id` 引用属性表，不再保存重复伤害和前摇下限） |
| 遭遇阵容、深度预算、冒险 Boss 生命/伤害倍率、训练五波递进 | `rooms/encounters.json` |
| 一局冒险：区域（深度、Boss）、每区地图规则（`map`，与 M 键地图同格式）、元素觉醒（选项数、第二次保证）、选卡相关度权重、各房型奖励与金币、宝箱/事件/休息/商店数值 | `run/forest_run.json` |
| 房间随机道具组合与掉落 | `rooms/props_prototype.json`、`loot/enemies.json` |
| 路线与地图生成规则 | `run/route.json`、`run/map_preview.json` |
| 店铺、装修目录 | `shop/*.json`、`shop/decorating/catalog.json` |
| 中英文文本 | `locales/zh_CN.json`、`locales/en.json`（PO 由工具生成，不手改） |

### 表现（Resource，`game/presentation/`）

| 想调什么 | 文件 |
|---|---|
| 战斗表现总表（各角色表现、剑姿态、镜头、刀光、以下各项的引用） | `combat/training_style.tres` |
| 角色模型、碰撞体、朝向 | `combat/*_presentation.tres` → `combat/rigs/*_visual.tscn` |
| 动作名映射、攻击动作切点、过渡 | `combat/rigs/*_clips.tres`；主角为 `nodachi_clips.tres`，另含八方向列表、步行速度、刀刃端点路径、蓄力下肢切换 `charge_move_blend_sec` |
| 转身、受击闪白/抖动、尸体消散、前摇泛光 | `combat/rigs/rig_feedback_*.tres` |
| 顿帧、镜头冲击、镜头跟随 | `combat/feel/combat_feel_style.tres` |
| 受伤闪红、击杀/闪避粒子、底部生命条 | `combat/juice/`（`combat_juice_style.tres`、`vitals_hud_style.tres`、粒子 `.tscn`） |
| 攻击预警外观 | `combat/fx/telegraph_*.tres`；敌人预警颜色宽度 `combat/enemies/enemy_fx_style.tres` |
| 敌人血条、受击闪白 | `combat/hit_feedback.tres` |
| 伤害跳字 | `combat/damage_number_style.tres` |
| 音效（事件 → wav、音量、音高、间隔、技能和敌人映射） | `audio/combat_audio_style.tres` |
| 破防提示文字的样式 | `combat/juice/combat_juice_style.tres`（文字本身在 locales 的 `combat.guard_break`） |
| 构筑特效、机制特效 | `builds/build_effects_style.tres`、`builds/mechanism_style.tres` |
| 元素特效（状态粒子、身体染色、脚下光环与标记、反应爆发/光环/闪光/文字、熔岩地面、电弧）；元素剑气的外观 | `builds/element_style.tres` + `builds/elements/`；剑气在 `build_effects_style.tres` 的 `projectile_scene_rules`；剑身拖尾在 `training_style.tres` 的 `element_blade_scenes` |
| 冒险界面（出口卡片、结算、房间信息条） | `run/run_exit_style.tres` |
| C 角色属性页（字号、颜色、间距、面板） | `attributes/character_sheet_style.tres`；共用现有主题字体 |
| 房间场景、镜头（含透视视角）、渲染分辨率 | `rooms/<房间>/presentation.tres` |

## 战斗的主要链条

```text
输入(presentation/combat/combat_input.gd) → CombatActor.request_action(primary/special/skill) / 闪避
  → AbilityRunner：前摇 → cue（出手）→ 判定 → 收招
  → MeleeResolver / BuildRuntime / EnemyRuntime → DamageExecutor（分量减伤 → 一次护盾/生命提交）
  → 已提交的事实信号 → 表现层（ActorView、CombatJuice、CombatFeel、CombatAudio、特效视图）
```

- 右键由 `press_skill()` / `release_skill()` 区分点按、持续蓄力和冷却中待开始蓄力。`request_action()` 返回输入是否接受；共用单个动作缓存，后按左键明确取消待发/蓄力技能（即使普攻暂不可用），其它同帧优先级沿用原规则。`wave_cast.buffer_sec` 现为 0.5 秒，复用现有 schema 9 的必填字段、Loader 与 Catalog，无新增配置字段。翻滚内技能缓存暂停老化，冷却须在“剩余翻滚时间 + buffer_sec”内就绪；跨翻滚结束帧只扣结束后的窗口时间。就绪的持有输入可在翻滚中蓄力；冷却等待不算蓄力，提前松键转为普通剑气。冷却归零/翻滚结束当帧尝试接招，若上一招本帧仍有末次判定则结算后下一帧接上；投射物仍由原 `cue` 发射。缓存只消费一次，清输入、受控、死亡、切房和重建构筑会取消。
- `CharacterMotor` 是唯一写移动的地方（自主移动、击退、出招前冲、闪避）。普通翻滚前 `movement_duration_sec` 是固定方向位移，后续起身阶段按当前输入、移速构筑、减速及强制移动执行；跨越分段的一帧按两段时间份额合成速度，松键不继续漂移。翻滚时钟与冲斩输入窗口仍保留到 `duration_sec`。翻滚冲斩由 `CombatActor` 记录当前翻滚年龄、锁定瞄准方向并提交独立的 `roll_slash` 定义副本：本次前摇为剩余翻滚时间 + 配置起刀时间，原始 Ability 不变，沿用完整 primary plan；`BuildRuntime.on_committed` 仅接受 Dodge 配置且确已提交的变体。前次左键冷却被本次冷却替换，翻滚消耗不退还。点击当帧起前摇位移，按配置封顶其距离份额；挥砍位移用 Hermite 曲线承接前摇末速度，末速归零，总位移仍为配置距离。按时间段积分，经 `Motor.travel` 连续碰撞，撞障碍即停；`MeleeResolver` 沿实际位移路径补充判定，仍由每次施放的目标集合去重。`roll_slash.recovery_sec/chain_cancel_sec` 均为 0，`cooldown_sec` 为 0.3、不会超出最短的起刀与判定时长。冲斩期间后按左键的缓存暂停老化，保留到末次扫掠结算，下一物理帧从 `slash.1` 接起；一次点击只接一刀，无输入则恢复移动。伤害判定仍完成整次冲斩，不提前截掉末段。
- 构筑：`BuildResolver` 把选卡编译成每个动作的执行计划（program）；`BuildRuntime` 按计划执行投射物、爆炸、状态、条件增伤；`TrainingBuildSession` 负责三选一、预设和提交；`BuildOfferSampler` 按品质与权重抽候选。
- 卡牌局部动画：`presentation/builds/card_art_motion/library.tres` 用字符串路径索引全部 51 张 Profile，按可见卡加载；单层和双层组合共 58 层，遮罩为 512×384。`BuildCardView` 在原画与渐隐层之间按需创建 `ArtMotion`，禁用时释放效果并保留静态原图。`BuildChoicePanel.set_art_motion_enabled(bool)` 同时作用于当前卡和后续新卡；卡本身另有 `set_art_motion_intensity/paused`。局部时钟只在可见且启用时推进，不使用 Shader TIME，不消费选卡 RNG；实际选卡时 UI 继续播放，Esc 的 SceneTree 暂停冻结 UI。
- 卡牌动画偏好：`presentation/settings/card_animation_preference.gd` 只读写 `user://player_preferences.cfg` 的 `presentation/card_animation_enabled`；默认值由同目录 `player_preferences.tres` 提供，不接玩法存档。`SettingsActions → PauseMenu.card_animation_changed → BuildChoicePanel` 显式信号接线；Panel 初次配置也读取偏好，样板可临时覆盖而不保存。全卡实渲染与生命周期检查为 `tests/card_art_catalog.gd`（526 项通过），设置偏好/暂停专项为 `tests/card_animation_settings.gd`，原图层/奖励输入回归为 `tests/card_art_motion.gd`。全卡画廊与性能脚本在 `ui_lab/card_art_motion/`。
- 接续构筑设计见 [构筑成长](BUILD_PROGRESSION.md)。`projectile_capabilities.gd` 已把新冰核心接到四张基础冰协同；其它旧卡和后期机制仍按范围逐步适配，不代表完整成长设计已实现。
- 状态：`StatusRuntime`（冰冻/减速/寒印/抗冻、同根去重、控制组）。
- 敌人：`EnemyRuntime` 管理各角色 AI（`*_brain.gd`）、敌方投射物和箭雨；近战敌人走同一套 AbilityRunner。近战 AI 在 `combat/ai/melee_brain.gd`：出手名额由 `EnemyRuntime._engaged_melee_others` 统计（逼近、出手、后撤都占名额）。
- 冲锋兵在 `charger_brain.gd` 按配置距离收招，终点使用浮点近似比较；正时间移动步完成后，碰撞或沿冲锋方向无有效前进也会进入收招。先结算末段扫掠命中，再判断退出；暂停不检查无前进，减速不改变冲锋距离。
- 霸体：`CombatActor.armored()`、`commit_damage` 累计非暴击、抗性/护盾之前的 `poise_basis`，达到 `poise` 时 `_break_poise()`，发出 `poise_broken`；土额外失衡单独加一次。护甲不改变霸体阈值。破防易伤由统一执行器乘 `break_damage_scale` 一次。
- 房间：场景根挂 `rogue/rooms/authored_room.gd` 协议（`player_spawn()`、`enemy_spawns()`），由 `presentation.tres` 指定；`combat_training.tscn` 的 `room_presentation` 决定训练用哪个房间。

### 属性、伤害与 C 页面

- `content/combat/attribute_loader.gd` 从 manifest 读取配置并严格校验，`AttributeCatalog` 深度只读；离线 `tools/content/validate_attributes.py` 检查 7 actor、16 直接攻击、4 派生、17 元素配方、全部 51 卡的覆盖和引用。新增来源需同时更新配置/schema/Loader。
- `CombatActor.attributes` 是 `AttributeSet`：`set_modifier(source, stat, operation, amount)` / `remove_source(source)`；同来源/属性/操作替换，常规 `(base + flat) * (1 + percent) * multiply`，最后按配置限幅。`final` 只读，`sources()` 返回副本；冷却恢复与暴击率仅接受 `flat` 百分点。属性重算只钳制 HP、不治疗。
- `DamageFormula.linear/elemental_growth/mitigation/preview` 是战斗与 UI 共用的纯公式，不消耗 RNG。`Ability.damage` 仅为定义的基础属性推导兼容值，不能当实际最终伤害；提交动作时重新根据最终属性快照。
- `DamageExecutor.request(source, profile_id, basis, root_id, action_id, critical)` → `submit(target, request)`。请求携带真实来源弱引用、team、runtime/room_generation、root/event、动作和 profile、类型分量、暴击及触发权限；过期房间、死亡来源、友军和无敌被拒绝。结果含 `valid_hit`、`components`（basis/raw/after_resistance）、`shield_loss`、`health_loss`、`poise_basis` 和来源信息，成功后深度只读，并只发一次 `damage_received`。
- 物理/魔法各自减伤后合并提交；真实分量跳过普通增减伤/易伤/暴击，仍受盾和无敌约束。有效命中不以掉血为判断：完全吸盾可触发合法 on-hit，无敌拒绝不能挂元素。`BuildRuntime.apply_melee_damage` 返回结果字典；旧 `Damage.apply(float)` 已移除。`receive_hit(float)` 仅为显式物理适配，场景道具通过物理适配入口使用 `damageable_prop_profile` 的零抗定义与原 HP。
- 武器 root 的 `base_damage` 保存暴击、条件追击、目标减伤之前的公式基数。贯穿/回程/分裂沿用该根暴击；爆炸/连锁取父公式基数并应用自己的比例/类型，不使用主目标实际掉血。武器加成只应用一次；元素伤害不继承武器加成或暴击。
- `CombatActor._prepare_ability` 快照攻速后的阶段时间和冷却，`AbilityRunner` 不再重复乘攻速；主动作再攻击间隔随攻速，技能与闪避充能走冷却恢复。敌方 RoleBrain 在提交时快照，遵守属性表的前摇下限。旗手写入来源修改器，不再次加速逻辑时钟。`set_spawn_scaling` 只在生成时使用，HP modifier 和独立伤害倍率各一次。
- `app/character_sheet.gd` 持有属性页暂停与焦点，`presentation/attributes/character_sheet.gd` 只展示。C/Esc 关顶层，L 双语；取消未提交输入，保留已提交动作进度，关闭恢复此前暂停状态。训练/正式战斗场景注入真实 actor/program，店铺注入基础预览 actor。技能区复用 `Formula.preview`，分别标记武器加成、元素和条件追击，不将反应金额混入直击。
- `tests/combat_attributes` 验证公式/混合/真伤/盾/失衡/修改器/严格配置；`attribute_damage_paths` 走实际剑气、测试箭分裂、回旋、爆炸、连锁、持续效果、六反应、四专精和敌方招式；图形 `character_sheet` 验证真实场景的双语、输入、暂停、跨房不回血与店铺预览，并输出 `builds/character_sheet_{zh_CN,en}.png`。

### 元素系统

- 冰/雷正式特效目录：`presentation/combat/fx/elemental_enchants_v001/`，已独立归档实验室资源及依赖。`training_style.tres.element_weapon_enchants` 配置常驻附魔；`build_effects_style.tres.element_impact_scenes/element_impact_height` 配置命中场景/高度。`BuildRuntime._apply_direct_damage` 在有效命中后发 `action_presented(event="element_hit")`，携带已提交攻击的元素、落点、目标及动作身份；只新增表现事实，不更改伤害。`BuildEffectsView` 单独处理该事件，不结束仍在播放的施法特效。命中层的 `sync_effect` 与刀身 `tick` 都由战斗显示 delta 驱动，0 时冻结粒子、闪电、冰刺、光源、贴花和 Shader 时钟；事件生命周期读取场景时间表。

- 卡：`builds/prototype.json` 里 `effect_type: "element"` 的核心卡（`fire_core` 等），参数 `element_id`、`stacks_per_hit`、`damage_bonus`（该动作伤害加成，二级用）；核心层，每个动作只能有一个元素。Resolver 仍支持替换，但冒险里元素只从“元素觉醒”拿（抽卡器只出空按键），平时三选一不出元素核心。
- 元素条件：每张卡有 `required_element` + `required_element_actions`（都为空/0 表示无），要求至少 N 个按键带该元素；Resolver、两个 Loader/校验器、预设检查都认。同元素专精卡用 N=2。
- 攻击范围卡：`effect_type: "reach_scale"`（动作卡，`bonus`），编译到动作计划的 `reach_scale`，`MeleeResolver` 乘到近战半径上；`impact_blast` 现在是支援层，不再和元素抢核心槽。
- 定义：`builds/elements.json`，由 `content/builds/elements_loader.gd` 校验，经 `BuildLoader.load_catalog` 挂到 BuildCatalog（`element()`、`reaction_between()`）。
- 执行：`combat/builds/element_effects.gd`，由 `BuildRuntime._apply_direct_damage` 在有效命中后调用；碎甲/超导易伤同步到目标来源修改器，最终只由 DamageExecutor 乘一次。元素造成的伤害调用 `apply_element_damage`，不再触发元素，也不走武器 `damage_applied`（不会重复顿帧和命中音效）。
- 冰寒默认叠满 3 层时调用现有冻结状态（`test_freeze`）；基础持续时间为 2.2 秒，配置在 `builds/prototype.json` 的 `statuses[].duration_sec`。Boss 按自身响应改为同一时长的减速窗口。
- 能力摘要新增 `freeze_window_ids`：汇总真实状态/范围负载的冻结及元素叠层可产生的冻结，供条件追击、霜径、冰衣等查询；`status_ids` 仍只表示直接状态负载，不把叠层伪装成即时冻结，也不误开放尚未适配的旧 `freeze_duration`。冻结成功与来源仍由 `StatusRuntime` 判断，候选与提交共用 Resolver。
- `conditional_damage.provider_scope` 同时限制候选与实际命中的来源：`same_action` 要求较早独立的同动作施放，`other_formal_action` 要求另一正式动作。来源还须匹配 runtime、房间代数、玩家和阵营；分裂/爆炸不能获得追击增伤。同一投射物回程沿用原 root，不会自触发。
- `frost_effects.gd` 复用路径与护盾执行器：路径仅主投射物铺设，受根预算、`max_targets`（现有字段，同时约束路径段总数与每段每步目标数）、时限限制；只施加普通减速。冰衣只在 `_apply_status` 实际成功建立冻结窗口时触发，受盾量/时限/冷却约束。暂停不推进，切房和死亡清理。
- 冰协同的相关度由 `BuildOfferSampler.upgrade_elements()` 通过真实元素的 `freeze_status_id` 与卡的状态/窗口要求推导，不靠卡名或装饰标签。四卡恢复 weight=1，品质沿用 `reward_groups.json`（追击/霜径/冰衣 rare，乘隙斩 epic）；原有两同元素专精门槛不变。
- 冻结中的敌人被其他元素命中：消耗冻结，按冰的满层触发反应（例如土 → 碎冰）。
- 反应的 `required_status_id` / `trigger_element_id` 显式声明前置窗口和触发元素，空字符串表示无此限制；Loader 与离线校验器检查引用和元素关系。碎冰配置为 `test_freeze` + `earth`，只能走有效冻结窗口路径，不能用普通冰附着触发。窗口优先于附着消费，同时清掉残余冰寒，避免一次冻结重复结算。
- 同元素专精：`effect_type: "element_mastery"`（全局卡；`trigger` 为 `full_stacks` 叠满时 / `discharge` 放电时，对周围造成伤害并扩散 `spread_stacks` 层，`consume` 决定是否清掉目标身上的该元素），编译到 `program.global.element_masteries`。扩散出的层数不再触发专精。
- 事实信号 `BuildRuntime.element_presented`（applied / discharge / reaction / mastery / zone_ended / cleared）→ `presentation/builds/element_view.gd` 和 `CombatAudio.element_fact`。
- 被动卡：`effect_type: "element_boost"`（全局卡，`element_id` + `field` + `add`，给元素的某个数值加值，可改的字段见 `elements_loader.gd` 的 `BOOSTABLE`）；双元素卡：`"reaction_boost"`（`reaction_id` + `damage_bonus` + `radius_bonus_m`）。两者编译到 `program.global.element_boosts / reaction_boosts`，`element_effects.gd` 用 `param()` 取“基础值 + 加值”。全局卡要求动作卡时，任意动作上有即满足。
- 当前 `element_boost` / `reaction_boost` 是数值增量接口，不能直接表达新区域、余波、下一次施放消费等机制。灼烧与熔岩保留实际来源/配方，tick 读取当前 program 强化与源属性；失效/死亡来源不回退为玩家。持续时间/区域尺寸保持创建时值。更复杂的多来源融合与新反应拓扑未实现。
- 扩充配置可复用已有状态与反应效果；全新机制须实现对应执行器，同步schema、Loader、能力检查及规则事实。元素定义/卡在 `elements.json`、`prototype.json`；表现入口是 `element_style.tres`、`training_style.tres` 与音效配置。粒子场景可用 `tools/vfx/make_element_fx.gd` 重新生成。

### 一局冒险（原型）

- 场景 `app/forest_run.tscn`：就是战斗训练场开了 `run_mode`；流程在 `app/forest_run.gd`，界面在 `presentation/run/run_exit_panel.gd`。
- 地图：每区用 `rogue/run/map_preview_generator.gd`（与 M 键预览同一个生成器）按 `forest_run.json` 的 `map` 规则生成，种子 `局种子:area:区号`；出口 = 当前节点在地图上的后继（区域入口为第 0 层），走完最后一层进区域 Boss。`app/map_preview.gd` 的 `show_run(plan, progress)` 让 M 键显示本局路线（红圈当前、黄圈可去、走过的变暗）。
- 换房间 = 重新载入同一场景，进度放在 `initial_run_state`（种子、区号、当前节点、走过的节点、房型、生命、构筑选择、金币、觉醒次数）里带过去；战斗房的遭遇在离开时就规划好（`initial_encounter_plan`），Boss 用 `EncounterPlanner.generate_run_boss`。宝箱、休息、事件、商店也会换场景，但不开打（`is_lobby()`），进门后弹面板。
- Boss 波次含角色翻译 `name_key`（经 `EnemyCatalog.actor_name_key()` 从 CombatCatalog 取得）、深度、预算和强化倍率。倍率来自 `encounters.json.depth_bands[].boss_health_multiplier/boss_damage_multiplier`，随深度不递减；生成计划后由 `validate_plan` 重建核验。`combat_training._spawn_wave` 调 `set_spawn_scaling`，不再预乘技能或角色伤害字段；训练仍用独立的 `training_waves`。跨房先重建构筑/最终属性，再恢复并钳制当前 HP。
- 构筑跨房间：`TrainingBuildSession.restore_selections()` 按选择列表重建（多轮尝试，顺序无关），每项仍走 Resolver 评估。
- 奖励：`TrainingBuilds.request_filtered_offer(profile, filter)`，选择提交成功或没有合法候选时发 `offer_finished`。界面不再提供暂时关闭，未选完不会转到房间出口/商店；`BuildChoicePanel` 只发 `choice_requested`。filter（实现在 `rogue/build_offer_sampler.gd`）：
  - `mode: "awakening"`：元素觉醒，候选 = 元素核心在空按键上的新增操作，尽量元素、按键都不重复；`guarantee_same/new` 保证已有元素时至少一个同元素、一个新元素。
  - `mode: "card"`：平时三选一，按品质组抽，只要新增操作、不含元素核心；和已有元素相关的卡乘 `owned_element_scale`，挂在带元素按键上的卡乘 `elemental_action_scale`；同一按键最多 `max_per_action` 张（全局卡不计）。
  - `operation: "rank"`：只出升级；`element` / `per_binding`：旧的按元素过滤（训练用）。
- 权重为 0 的卡不进抽取，但仍是合法构筑（旧冰卡留给训练预设）。
- 测试：图形 `tests/forest_run_flow.gd`（觉醒→地图出口→战斗选卡→第一区 Boss 第二次觉醒→第二区→宝箱/休息/事件/商店→倒下→再来一局）；无头 `tests/build_awakening.gd`（冰+冰、火+土两条路线从空构筑拿到底，不出替换）；截图 `tests/run_capture.gd`。
- 回归：`tests/adventure_rewards_and_bosses.gd`（不可关闭的觉醒、商店连续买卡/升级隔离、三区实际 Boss 生命/所有伤害参数和 HUD）；`tests/shatter_window.gd`（未冻/已冻/Boss 窗口/过期/反向顺序/重复消费，以及全局强化实时生效）。两者均可无头运行。
- 冰协同：`tests/ice_synergy.gd` 验证单核心前置、四卡与贯穿/回旋/蓄力兼容、实际剑气命中、同根/异动作、Boss、抗冻失败、暂停和生命周期；`tests/ice_synergy_rewards.gd` 用固定选卡流种子 13 通过真实候选令牌取得四卡，随后验证训练 UI、冒险禁用直接授予及跨房重建。奖励测试没有用 `submit_operation` 补缺卡。测试序列为觉醒后按“普通、普通、精英”重复发卡，是奖励接口验证，不宣称该种子对应一条实际地图路线。
- 训练逐卡入口：`BuildStatusPanel.training_upgrade_requested(upgrade_id, action_id)` → `TrainingBuilds.grant_training_upgrade()`，重新查询合法操作后走 `Session.submit_operation()`；仅开启训练预设时可用，不允许替换或领取权重为 0 的旧卡。界面和命令都有训练门禁。此入口只供测试，不作为正常获取的验证证据。本次沿用现有 JSON 字段与 schema，没有新增玩法字段。
- 测试：`tests/element_reactions.gd`（六反应与专精），`tests/element_capture.gd`（截图）。

## 测试

- 无头规则测试：`godot --headless --path game --script res://tests/<名字>.gd`
- 图形/截图测试：去掉 `--headless`，加 `--resolution 1280x800`
- 看输出里的 `failures`、`SCRIPT ERROR`、`ERROR`，不要只看退出码。
- `charge_locomotion` 还覆盖真实角色移动中按住技能至蓄满、松开移动键，以及保留正式 34 段动作库。默认不保存截图；需要查看时在命令末尾加 `-- --capture`，图形模式输出到 `builds/charge_locomotion_check/`，可随时删除。
- `skill_input_buffer` 通过真实输入适配器、角色与投射物 cue 检查 30/60/120 Hz 翻滚点按、持续蓄力、冷却边界与重叠、左键/UI/受控/死亡/切房/构筑取消、仅触发一次及上一招末次判定；不生成预览文件。`dual_actions`、`three_actions` 覆盖动作仲裁和原生挥刀时序。

| 改了什么 | 跑什么 |
|---|---|
| 战斗基础、连段、反馈 | `combat_rules`、`roll_slash`（6 米/连续推进/碰撞/元素/增伤/范围/取消，以及 30/60/120 帧步长的冲斩接普攻和末帧命中）、`roll_slash_visual`（八方向 × 三种翻滚时机、原翻滚相位延续、落地后分骨骼混合、冲斩直混普攻；加 `-- --capture` 才保存截图）；主角 `nodachi_player`（图形/无头）、`charge_locomotion`（蓄力八方向走跑、上身保持、暂停/冻结/停止/释放/死亡）、`combo_feel`（已适配 Nodachi 的真实刀刃和下劈第三刀） |
| 敌人、遭遇 | `enemy_roles`、`charger_completion`（远坐标斜向终点、减速、30/60/120 Hz、无进展、暂停与末段命中）、`charger_obstacles`；图形 `enemy_training` |
| 游侠 | `ranger_rules`、`ranger_sequences`、`charged_ranger` |
| 构筑 | `bound_build_policy`、`bound_build_session`、`mechanism_content`、`dual_actions`、`frost_first_batch`；冰协同 `ice_synergy`、`ice_synergy_rewards`、`freeze_followup`、`boss_frost_builds` |
| 元素 | `shatter_window`、`element_reactions`；截图 `element_capture` |
| 一局冒险 | `adventure_rewards_and_bosses`、`forest_run_flow`、`build_awakening`；截图 `run_capture` |
| 状态与冰冻 | `status_controls`、`freeze_guard`、`boss_frost_window` |
| 训练工具、五波 | `training_tools`、`training_five_waves` |
| 路线、地图 | `run_session`、`run_integration`、`map_generation` |
| 店铺、装修、界面 | `shop_preview_controls`、`shop_decorating`、`settings_menu` |
| 画面截图 | `visual_pass_capture`（`overview` / `combat` / `lineup` / `perf`），输出 `builds/visual_pass/` |

## 工具与坑

- 音效：`tools/audio/make_sfx.py` 纯 Python 合成全部战斗音效到 `game/assets/audio/sfx/`，改参数重跑即可；也可以直接换成素材 wav。
- Blender 5.2.1：`E:/blender/blender.exe`，界面是中文，脚本里按节点 `type` 找节点，不按名字。
- 改了 GLB 后要重新导入：`godot --headless --path game --import`。导入失败过一次 Godot 会记住、不再重试，先删掉对应 `.import` 文件。这个 Godot 版本读不了只含 WebP 贴图的 glTF。
- `--script` 运行的场景不会自动重新导入资源；改了贴图/模型先跑一次 `--import`。
- Python：系统没有可用的 `python`，用 `builds/content_venv/Scripts/python.exe`。
