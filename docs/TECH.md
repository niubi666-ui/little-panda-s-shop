# 技术说明

更新：2026-10-15。只写“东西在哪、怎么连、怎么测”。各系统更细的历史接口说明在 `docs/archive/2026-10-15/`（例如 `BUILD_IMPLEMENTATION_CONTRACT.md`、`COMBAT_MECHANISMS.md`、`ELITE_RANGER.md`），代码本身是最终依据。

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
| 玩家/敌人生命、移速、硬直、霸体与破防；技能前摇/判定/收招、冷却、伤害、范围、击退、出招前冲；闪避；受击半径 | `combat/prototype.json`（schema 5） |
| 构筑卡、动作、形态、投射物、状态（冰冻/寒印/减速）、抗性、训练预设、预算上限 | `builds/prototype.json` |
| 卡牌品质分组、各类房间的奖励品质权重 | `builds/reward_groups.json` |
| 元素状态（层数、持续、灼烧伤害、感电放电、碎甲易伤）与六种反应（伤害、范围、推拉、易伤、减速、熔岩区域） | `builds/elements.json`（字段为 0 / 空字符串表示不用） |
| 敌人角色参数（近战兵的出手名额、绕圈与后撤；弩手射程、冲锋速度、游侠招式……） | `enemies/roles.json` |
| 遭遇阵容、深度预算、训练五波递进 | `rooms/encounters.json` |
| 一局冒险：房间数、深度增长、Boss、出口数量、奖励权重、回血/金币数额、祝福用哪个品质来源 | `run/forest_run.json` |
| 房间随机道具组合与掉落 | `rooms/props_prototype.json`、`loot/enemies.json` |
| 路线与地图生成规则 | `run/route.json`、`run/map_preview.json` |
| 店铺、装修目录 | `shop/*.json`、`shop/decorating/catalog.json` |
| 中英文文本 | `locales/zh_CN.json`、`locales/en.json`（PO 由工具生成，不手改） |

### 表现（Resource，`game/presentation/`）

| 想调什么 | 文件 |
|---|---|
| 战斗表现总表（各角色表现、剑姿态、镜头、刀光、以下各项的引用） | `combat/training_style.tres` |
| 角色模型、碰撞体、朝向 | `combat/*_presentation.tres` → `combat/rigs/*_visual.tscn` |
| 动作名映射、攻击动作切点、过渡 | `combat/rigs/*_clips.tres` |
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
| 房间场景、镜头（含透视视角）、渲染分辨率 | `rooms/<房间>/presentation.tres` |

## 战斗的主要链条

```text
输入(presentation/combat/combat_input.gd) → CombatActor.request_action(primary/special/skill) / 闪避
  → AbilityRunner：前摇 → cue（出手）→ 判定 → 收招
  → MeleeResolver 近战判定 / BuildRuntime 投射物与派生效果 → HealthRuntime 扣血
  → 已提交的事实信号 → 表现层（ActorView、CombatJuice、CombatFeel、CombatAudio、特效视图）
```

- `CharacterMotor` 是唯一写移动的地方（自主移动、击退、出招前冲、闪避）。
- 构筑：`BuildResolver` 把选卡编译成每个动作的执行计划（program）；`BuildRuntime` 按计划执行投射物、爆炸、状态、条件增伤；`TrainingBuildSession` 负责三选一、预设和提交；`BuildOfferSampler` 按品质与权重抽候选。
- 接续构筑设计见 [构筑成长](BUILD_PROGRESSION.md)：元素/形态独立、能力前置、单元素与双元素机制、来源与成长供给是待补目标，不是以上接口已完整支持的能力。`projectile_capabilities.gd` 的旧状态摘要、新冰核心与旧卡需要一起适配。
- 状态：`StatusRuntime`（冰冻/减速/寒印/抗冻、同根去重、控制组）。
- 敌人：`EnemyRuntime` 管理各角色 AI（`*_brain.gd`）、敌方投射物和箭雨；近战敌人走同一套 AbilityRunner。近战 AI 在 `combat/ai/melee_brain.gd`：出手名额由 `EnemyRuntime._engaged_melee_others` 统计（逼近、出手、后撤都占名额）。
- 霸体：`CombatActor.armored()`、`receive_hit` 累计伤害到 `poise` 时 `_break_poise()`，发出 `poise_broken` 信号；破防期间受伤乘 `break_damage_scale`，恢复前受击正常硬直。`poise` 为 0 的角色行为与以前相同。
- 房间：场景根挂 `rogue/rooms/authored_room.gd` 协议（`player_spawn()`、`enemy_spawns()`），由 `presentation.tres` 指定；`combat_training.tscn` 的 `room_presentation` 决定训练用哪个房间。

### 元素系统

- 卡：`builds/prototype.json` 里 `effect_type: "element"` 的核心卡（`fire_core` 等），参数 `element_id`、`stacks_per_hit`；核心层，所以每个动作只能有一个元素，新的替换旧的。
- 定义：`builds/elements.json`，由 `content/builds/elements_loader.gd` 校验，经 `BuildLoader.load_catalog` 挂到 BuildCatalog（`element()`、`reaction_between()`）。
- 执行：`combat/builds/element_effects.gd`，由 `BuildRuntime._apply_direct_damage` 在每次直接命中后调用；命中前乘 `incoming_scale`（碎甲、超导易伤）。元素造成的伤害不再触发元素，也不走 `damage_applied`（不会触发顿帧和命中音效）。
- 冰寒叠满时调用现有冻结状态（`test_freeze`），所以 Boss 仍按自身响应改为减速窗口。
- 事实信号 `BuildRuntime.element_presented`（applied / discharge / reaction / zone_ended / cleared）→ `presentation/builds/element_view.gd` 和 `CombatAudio.element_fact`。
- 被动卡：`effect_type: "element_boost"`（全局卡，`element_id` + `field` + `add`，给元素的某个数值加值，可改的字段见 `elements_loader.gd` 的 `BOOSTABLE`）；双元素卡：`"reaction_boost"`（`reaction_id` + `damage_bonus` + `radius_bonus_m`）。两者编译到 `program.global.element_boosts / reaction_boosts`，`element_effects.gd` 用 `param()` 取“基础值 + 加值”。全局卡要求动作卡时，任意动作上有即满足。
- 当前 `element_boost` / `reaction_boost` 是数值增量接口，不能直接表达新区域、余波、下一次施放消费等机制。`param()` 读取当前program；状态/区域快照和派生来源权限仍需按构筑设计补齐，见 [STATUS](STATUS.md)。
- 扩充配置可复用已有状态与反应效果；全新机制须实现对应执行器，同步schema、Loader、能力检查及规则事实。元素定义/卡在 `elements.json`、`prototype.json`；表现入口是 `element_style.tres`、`training_style.tres` 与音效配置。粒子场景可用 `tools/vfx/make_element_fx.gd` 重新生成。

### 一局冒险（原型）

- 场景 `app/forest_run.tscn`：就是战斗训练场开了 `run_mode`；流程在 `app/forest_run.gd`，界面在 `presentation/run/run_exit_panel.gd`。
- 换房间 = 重新载入同一场景，进度放在 `initial_run_state`（种子、第几间、生命、构筑选择、金币、待发奖励）里带过去；下一间的遭遇在离开时就规划好（`initial_encounter_plan`），Boss 房用 `EncounterPlanner.generate_run_boss`。
- 构筑跨房间：`TrainingBuildSession.restore_selections()` 按选择列表重建（多轮尝试，顺序无关），每项仍走 Resolver 评估。
- 奖励：`TrainingBuilds.request_filtered_offer(profile, filter)`，filter 支持 `element`（只出该元素相关的卡）、`per_binding`（同一张卡挂不同按键算不同选项）、`operation: "rank"`（只出升级）；结束时发 `offer_finished`。
- 当前元素过滤仅识别元素核心、元素被动和反应强化，通用贯穿/回旋等没有实际入口；新增武技改造奖励时应复用候选与提交路径，勿伪造元素标签。按已有构筑偏好和成长用途调整候选是待实现设计，不能跳过合法性、品质或前置。
- 测试：图形 `tests/forest_run_flow.gd`（开局→第 1 间→领奖→出口→第 2 间→倒下→再来一局）。
- 测试：`tests/element_reactions.gd`（规则），`tests/element_capture.gd`（截图）。

## 测试

- 无头规则测试：`godot --headless --path game --script res://tests/<名字>.gd`
- 图形/截图测试：去掉 `--headless`，加 `--resolution 1280x800`
- 看输出里的 `failures`、`SCRIPT ERROR`、`ERROR`，不要只看退出码。

| 改了什么 | 跑什么 |
|---|---|
| 战斗基础、连段、反馈 | `combat_rules`；图形 `combo_feel`、`combat_feedback` |
| 敌人、遭遇 | `enemy_roles`、`charger_obstacles`；图形 `enemy_training` |
| 游侠 | `ranger_rules`、`ranger_sequences`、`charged_ranger` |
| 构筑 | `bound_build_policy`、`bound_build_session`、`mechanism_content`、`dual_actions`、`frost_first_batch` |
| 元素 | 图形 `element_reactions`；截图 `element_capture` |
| 一局冒险 | 图形 `forest_run_flow` |
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
