# 三选一与构筑训练切片 · 实现契约

更新：2026-10-02。当前代码为 **schema v5 按动作绑定**；v4全局rank程序不再是生产接口。玩法与入口见[Build概览](BUILD_SYSTEM.md)，爆炸/冻结/范围payload细节见[命中机制](COMBAT_MECHANISMS.md)。本页记录实际接口；测试结果以本轮交付和[验证索引](VALIDATION.md)为准。

## 内容格式 v5

`res://data/builds/prototype.json` 由 manifest 的 `build_prototype_file` 引用。顶层必填：`schema_version`、`offer`、`limits`、`stats`、`actions`、`forms`、`upgrades`、`projectiles`、`test_attacks`、`statuses`、`status_rules`、`test_presets`。数值唯一来源为JSON，不在文档另存数值表。

| 定义 | 字段与约束 |
|---|---|
| actions | `id/name_key/base_form_id/form_ids/test_only`；正式 `primary/special`，隔离夹具 `debug_melee/debug_arrow`。`global`是作用域身份，不能定义为动作。 |
| forms | `id/name_key/executor/ability_ids/projectile_id/presentation_key`；executor仅`melee/projectile`。引用Combat能力ID与Build投射物ID，伤害/时序不重复定义。 |
| upgrades | `id/name_key/description_key/weight/max_rank/requires/excludes/required_tags/granted_tags/effect_type/ranks`，另加`scope/layer/action_ids/test_only`。scope为`action/global`；layer为`form/core/support/synergy`。 |
| offer | `count/pool_ids/fallback_ids/initial_offers/rewards_per_wave/max_queued_offers/target_weighting`；目标绑定当前为显式`uniform`。 |
| stats | `damage_scale_min/max/move_scale_min/max/damage_composition`；当前`additive_then_clamp`。global增伤与本动作增伤先相加再限幅；Actor移速只应用global一次。 |
| limits | `root_effect_budget/requests_per_step/max_queue/max_projectiles/max_chain_jumps/max_split_generation/max_projectiles_per_root/max_projectile_hits/projectiles_survive_source_death`。 |
| projectiles | `id/executor/child_id/speed_mps/radius_m/height_m/lifetime_sec`；仅`linear_contact`。child_id为空禁用分裂，否则引用有效定义。 |
| test_attacks | `id/projectile_id/damage/cooldown_sec/action_id`；动作须为匹配投射物的test_only来源，不为正式动作授予资格。 |
| test_presets | `id/name_key/selections`；选择项为`{upgrade_id,action_id,rank}`。按顺序逐项、逐级经过正式评估路径；基础预设允许空数组。 |

当前14项定义中，旧wave/chain/contact_slow属于测试夹具，不进入正式池。正式形态改造是`form`效果，其每级仅引用`form_id`；数值支持是`damage_scale/move_scale/status_duration`；`status/explosion`占核心，`area_status`占协同，`split/pierce`是支持。global仅允许数值伤害/移速支持。完整每级效果字段由schema定义；范围/状态字段见命中机制，禁止未知字段或配置脚本。

Loader拒绝不支持的schema版本、引用错误、依赖环、等级/预算错误及不对称互斥；穿透/分裂定义必须显式对称排除，但排除现在按动作生效。内容层检查预设的绑定、槽位、实际载体、来源交集和完整有限组合；`TrainingBuilds.configure`还用隔离Session逐一试提交所有预设，通过后才创建UI。内容层不导入combat。

`BuildLoader.load_catalog(manifest_path)->BuildCatalog`，`decode(data:Variant)->BuildCatalog`，错误由`errors:PackedStringArray`返回。load_catalog同时核对Combat能力引用；decode供独立内容测试。

`BuildCatalog`返回递归只读定义：`entries()/upgrade(id)/has_upgrade(id)`、`actions()/action(id)/has_action(id)`、`forms()/form(id)/has_form(id)`、`offer_rules()/limits()/stat_limits()`、`projectile(id)/test_attack(id)`、`status(id)/status_response(actor_id)/control_group(id)`、`test_presets()/test_preset(id)`。复数接口返回数组；未知test_preset返回空字典。

## 构筑解析与战斗 API

权威Build状态：`{selections:Array[{upgrade_id,action_id,rank}], revision:int}`。绑定global时action_id明确为`global`；不能继续用单个upgrade_id作为左右键共用rank键。槽位、当前形态与能力从选择项派生，不保存第二份可变槽位状态。

`combat/builds/build_resolver.gd`是唯一纯选择/编译评估器：

- `configure(catalog)`；`validate_state(state)->Array[String]`返回原因key。
- `resolve(state)->Dictionary`：非法返回空；合法返回递归只读program。
- `legal_operations(state,upgrade_id="")->Array`：只枚举正式池、正式动作/global的合法绑定操作。
- `evaluate(state,operation)->{ok,error_key,state,program,change}`：无随机、无权威写入；替换先移除被替换项，再全量复验所有剩余项，失效依赖拒绝，不删卡退款。
- `valid_program(program)->bool`：从selections/revision重编译并深比较，禁止调用者篡改效果参数或动作计划绕过评估。

操作为`{upgrade_id,action_id,operation,rank,replaced,base_revision}`；operation是`add/rank/replace`，rank是目标等级，replaced是完整旧选择项或空字典。旧revision、错误等级、伪造替换对象均拒绝。

program形状：

```text
{revision, selections, global:{damage_scale,move_scale}, actions:{action_id:plan}}
plan = {revision, action_id, form_id, executor, ability_ids, projectile_id,
        presentation_key, damage_scale, move_scale, tags, effects}
effect = {upgrade_id, type, rank, params}
```

选择项/效果按稳定身份排序；同集合不同取得顺序编译结果相同。plan.damage_scale已包含global＋本动作加成，不得再乘global.damage_scale。新等级替换旧等级；area_status只编译到本动作对应explosion的有限payload：一个damage，至多一个apply_status。

`CombatActor.set_action_program(actions,combat_catalog)->bool`注入解码后的正式动作计划。`request_action(id,input_frame=-1)`及`request_attack()/request_special()`提出意图。`AbilityRunner.start(ability,facing,context={})`复制冻结本次plan；`cast_context/action_id/form_id/executor/presentation_key`供规则和表现读取。零前摇能力在`start`内先提交快照，再同步发布一次`cue_reached`，后续tick不重复发cue；提交回调若取消/替换施放，则不发布旧cue。冷却通过`cooldown_for(action_id)`查询；具体缓冲/取消规则见[战斗](COMBAT_PROTOTYPE.md)。

`combat/builds/build_runtime.gd`：

- `configure(catalog,player,targets:Callable,wall_query:Callable,attack_ids:Array=[])`。targets返回当前actors；wall_query返回世界交点Vector3或null。
- `set_program(program)->bool`复用Resolver全程序验证，失败保留旧program；旧cast/子体继续使用原动作、形态、revision、效果与表现键快照。
- `on_committed(cast_id,ability_id)`、`on_cue(cast_id,ability_id)`、`on_finished(cast_id,ability_id,reason)`接Runner局部事实。cue在投射物形态发射；该形态跳过近战及房间道具近战路径，不能用damage=0代替。
- `fire_attack(attack_id,direction)->bool`只接受configure显式授予的调试攻击，使用其debug动作计划、独立冷却和根；不继承primary/special核心。
- `melee_damage(source,base_damage)`、`on_melee_contact(source,cast_id,ability_id,target_handle,position,damage)`、`on_melee_hit(source,target,cast_id,ability_id,applied_damage)`分别负责快照倍率、合法接触和有效伤害派生。
- `tick(delta)`、`clear_room()`；`statuses`是独立StatusRuntime，app在AI前推进其时钟，Runtime不重复tick。delta≤0不推进规则。
- `projectiles()`返回只读表现快照；`diagnostics()`含根/队列/投射物/拒绝计数与预算。

直接伤害、子体和派生队列共享根预算；不重复套倍率。穿透按距离/handle稳定接触，持久visited去重，墙先截断；同距墙优先。有效但0实损的接触可触发状态/爆炸并消耗接触额度，已死候选不消耗。有限范围不重新生成通用接触，不递归爆炸/连锁。首段爆炸、冻结共享抗连控及来源限制继续遵循命中机制；两动作不能绕过同一目标的控制窗口。

## 投射物职责与继承

`projectile_capabilities.gd`提供`supports_split/supports_pierce/supports_impact`、`valid_plan`（编译内部检查）、`valid_program(program,catalog)`（委托Resolver）。`summarize_plan(catalog,plan)`返回带`action_id/attack_id/projectile/origin/status_ids/area_effects/modifiers`的实际载体数组；`eligible(entry,summary)`用于**同一个动作**的摘要。汇总接口`summarize(catalog,program,attack_ids=[],has_melee=false)`保留动作关联，后两个旧参数不再授予能力。

候选、替换、预设和提交都经过Resolver，不直接把跨动作摘要并集交给eligible。标签不能伪造真实执行器；冻结延长必须找到本动作的直接或范围冻结，寒霜必须找到本动作对应爆炸。首版同一动作（含派生载体）禁止穿透＋分裂及分裂＋寒霜；不同动作可分别拥有。

`projectile_factory.gd`构造initial/child；`projectile_split.gd`生成有界请求；`projectile_pierce.gd`决定总命中额度；`projectile_contacts.gd`收集本步接触。它们不按卡名/武器名分支、不创建美术Node。子体继承根动作/Build/预算、伤害与排除集合；定义决定速度/半径/高度，寿命取父剩余与子定义上限的较小值。子体下个模拟步运动；既有旧wave/chain通过明确debug选择夹具复用同一生产编译器，不保留全局v4执行体系。

## 候选与应用提交 API

`BuildOfferSampler.configure(catalog,operations:Callable)`注入Resolver.legal_operations；`sample(state,rng)->Array[Dictionary]`只负责权重与随机。先按upgrade_id无放回抽取，再在该升级的合法绑定中均匀选一个；左右均可绑定不会使该升级权重翻倍，也不会占一轮两格。fallback仍经纯评估，不足返回较少项。

`TrainingBuildSession.configure(catalog,seed,commit:Callable)`；公共接口：`open_offer()`、`choose(offer_id,choice_id)`、`legal_operations(upgrade_id="")`、`submit_operation(operation)`、`apply_test_preset(id)`、`snapshot()`、`program()`。

- session状态为selections、revision、history、offer、offer_sequence、rng_state（十进制字符串）。offer含id/candidates/resolved/base_revision；每个candidate是锁定操作加choice_id。
- UI只提交offer/choice令牌，不提供可更改的动作或等级。已有待选offer直接重用；语言切换不重新抽取。
- choose再次评估锁定操作；`commit(candidate:Dictionary)->Error`收到隔离副本，成功后才发布state/program。错误/重复/过期提交不改变状态或RNG。
- submit_operation是显式训练/测试命令，仍用同一评估和提交路径；正常UI不直接调用它。
- apply_test_preset清空隔离候选的选择/历史/offer，提升revision，再按定义顺序逐项升到指定等级；全成功后只commit一次。空预设也提升revision；RNG与offer_sequence保持不变，旧令牌不会复活。
- 请求结果为`{ok,error,error_key,offer}`。当前commit仅训练内存适配，不代表正式存档已实现。

## UI API 与表现接口

`BuildChoicePanel.configure(catalog,shared_theme)`、`show_offer(offer,selections:Array)`、`dismiss()/refresh_text()/set_error(key)`；signal `choice_requested(offer_id,choice_id)`。按钮名称`Upgrade_<choice_id>`，buttons字典按choice_id索引。卡片显示动作与当前输入绑定、层级/等级、新效果和替换时的旧效果；文案来自JSON翻译，描述参数取目标等级与同动作强化。

`BuildStatusPanel.update_state(selections,program={})`显示当前形态和绑定构筑；预设入口依显式配置启用。三选一是模态，训练时暂停角色/AI/派生与表现时间，UI只发请求，不改状态或抽随机数。当前仍为训练门控，非通用嵌套暂停服务。

Runtime局部表现事实：`action_presented(fact)`、`projectile_presented(fact)`、`area_presented(fact)`。保留原damage/chain/area signals用于现有消费者。fact带动作/ability/cast/root、form/revision/presentation_key及位置方向；投射物另含id/definition_id/generation/radius/event/reason；范围另含effect_id/radius/has_status。

- `BuildEffectsView`消费动作/投射物事件与sync快照；`build_effects_style`映射动作`presentation_key/event`、投射物/拖尾/接触/终止`definition_id`到PackedScene。显式null关闭槽位，未映射投射物使用Resource中配置的占位mesh。
- `projectile_scene_rules` 是按顺序配置的表现变体表，每项含 `definition_id/required_effect_id/scene`，仅在首次创建该投射物ID时按已提交快照的 `effect_ids` 选择；基槽显式null优先关闭，旧弹不跟随新Build变色。当前剑气默认普通版，快照带 `contact_freeze` 时为寒冰版。`frost_blast` 是编译进范围payload的协同，不在投射物顶层effect_ids中；仅有该协同的剑气保持普通版并沿用原寒霜范围反馈。视觉选型不施加任何状态。
- `MechanismView`及`mechanism_style`映射范围/状态表现；规则中不创建特效、不从粒子/刀刃位置推导命中。
- 可选表现实例接口：`configure_effect(fact)`、`sync_effect(fact,delta)`、`set_time_running(enabled)`、`finish(reason)`。暂停/生命周期由适配器调用；自定义场景须遵守该协议。
- 剑姿态使用AttackMotion Resource，角色继续idle/run；逻辑阶段/cue决定挥砍与发射。更換Resource或关闭VFX不改变规则参数。

## 当前验证与边界

本轮测试入口：`bound_build_policy.gd`、`bound_build_session.gd`、`mechanism_content.gd`、`action_build_runtime.gd`及动作/场景集成。本文不把前轮v4通过记录当作v5验收；最终执行结果见[验证索引](VALIDATION.md)与本轮交付。归档v4脚本不再作为当前gate。

尚未接入多武器、蓄力、完整主动技能栏、经济或永久存档；独立[内存路线测试](RUN_PREVIEW.md)已接预装Build跨房保留，尚无跨房选卡奖励；当前训练选卡频率不等于正式冒险奖励节奏。不制作Release，不自动Git提交。
