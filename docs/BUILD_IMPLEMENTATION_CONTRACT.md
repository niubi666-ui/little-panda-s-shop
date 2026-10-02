# 三选一与构筑训练切片 · 实现契约

文档更新：2026-10-01；**当前 schema v3 投射物/命中机制切片 API**。正式技能名单未定；本页记录已实现字段，扩展目标见 [能力设计](contracts/BUILD_CAPABILITIES.md)。

## 维护边界

当前API按本页维护；具体任务的写入范围由当次协作分配，不沿用历史会话编号。

## 内容格式 v3

文件 `res://data/builds/prototype.json`，从 manifest 的 `build_prototype_file` 读取，由独立 BuildLoader 校验后返回 BuildCatalog。

顶层：`schema_version`、`offer`、`limits`、`stats`、`upgrades`、`projectiles`、`test_attacks`、`statuses`、`status_rules`，全部必填。

- offer：count、pool_ids、fallback_ids、initial_offers、rewards_per_wave、max_queued_offers；数值以JSON为准。
- limits：root_effect_budget、requests_per_step、max_queue、max_projectiles、max_chain_jumps、max_split_generation、max_projectiles_per_root、projectiles_survive_source_death。
- stats：damage_scale_min/max、move_scale_min/max。
- 升级：id、name_key、description_key、weight、max_rank、requires（升级ID数组，至少1级）、excludes（ID数组）、required_tags、granted_tags、effect_type、ranks（完整每级参数数组，长度=max_rank）。
- 原有五种 type 与每级参数：damage_scale/move_scale 使用 bonus；projectile 使用 damage_ratio、projectile_id；chain 使用 damage_ratio、radius_m、jumps、falloff；split 使用 count、spread_deg、damage_ratio、max_generation、trigger、scope。
- 无任意脚本、表达式或未知字段；跨引用/前置循环/互斥对称/非有限数/等级长度/限制冲突需拒绝。分裂不要求剑气ID或projectile标签；改用combat兼容性规则。v1/v2明确拒绝，无静默迁移。

- projectiles：数组；每项 id、executor、child_id、speed_mps、radius_m、height_m、lifetime_sec。唯一支持 executor=`linear_contact`；child_id为空明确禁用分裂，否则必须引用已验证定义；允许自引用，传播由代数和共享预算截断。未知执行器/字段、错误引用、非正运动参数拒绝。
- test_attacks：数组；每项 id、projectile_id、damage、cooldown_sec。只定义测试入口可启用的攻击，普通训练不自动授予；数值均外置。
- split 的 trigger 固定为 `enemy_contact`，scope 固定为 `linear_projectile`，不接受未实现类型。无额外可伪造的“可分裂”标签字段。

新增explosion/status/status_duration及statuses/status_rules的完整字段与固定策略见 [命中机制 API](COMBAT_MECHANISMS.md)，不在本页重复。爆炸/状态不按武器名执行。

BuildCatalog 公共接口：status(id)->Dictionary、status_response(actor_id)->Dictionary、projectile(id)->Dictionary、test_attack(id)->Dictionary、entries()->Array[Dictionary]、upgrade(id)->Dictionary、offer_rules()->Dictionary、limits()->Dictionary、stat_limits()->Dictionary；返回内容递归只读。Loader.load_catalog(manifest_path)->BuildCatalog，errors:PackedStringArray；decode(data:Variant)->BuildCatalog 可独立测试。

## 构筑解析与战斗 API

`combat/builds/build_resolver.gd`：configure(catalog)；resolve(ranks:Dictionary)->Dictionary，输出递归只读 program：damage_scale、move_scale、tags（排序去重）、effects（稳定按升级ID排序，元素为 upgrade_id/type/rank/params）。同组选中顺序不影响结果；等级替换旧级不重复累积，属性clamp来自JSON。

`combat/builds/build_runtime.gd` extends RefCounted：

- configure(catalog, player, targets:Callable, wall_query:Callable, attack_ids:Array=[])。targets 返回当前 Array actors；wall_query(from:Vector3,to:Vector3)->Variant，返回墙体交点Vector3或null。
- fire_attack(attack_id:String,direction:Vector3)->bool：只能发射configure显式授予的测试攻击；检查存活、方向及冷却；创建独立根并按当前program取快照。冷却随tick推进，清房重置，不能在选择期间由app调用。
- set_program(program:Dictionary)。后续升级不得更改既有cast/projectile快照。
- on_committed(cast_id:int,ability_id:String)、on_cue(cast_id:int,ability_id:String) 接玩家Runner局部信号；创建根上下文，cue可挥空发剑气。
- melee_damage(source,base_damage:float)->float，按本次施放快照加成（敌方原样）。
- on_melee_contact(source,cast_id,ability_id,target_handle,position,damage)消费合法接触事实（含0实损/致死），通过Impact处理器排队爆炸/状态。statuses为独立StatusRuntime；app在AI前调用其tick，Runtime.tick不重复推进状态时钟。
- on_melee_hit(source,target,cast_id:int,ability_id:String,applied_damage:float)；只接受已确认伤害，派生任务排队，禁止递归伤害。
- tick(delta:float)、clear_room()；delta=0不得推进队列/投射物/时钟；清房丢弃全部上下文。
- projectiles()->Array[Dictionary] 只读展示快照，元素 id/position/direction/radius/definition_id；由表现创建节点，不由规则创建美术。
- diagnostics()->Dictionary 至少含 roots/projectiles/queued/rejected，便于测试预算。
- signal damage_applied(source,target,applied_damage:float,origin:String) 只通知派生已提交伤害；signal chain_emitted(points:PackedVector3Array)、area_emitted(center:Vector3,radius:float)仅表现。

每次cast保存ability基础伤害、伤害倍率和program快照，派生计算倍率一次；同一个根共享效果请求预算（所有子弹/队列共同引用），每步、队列、存活子弹和分裂代数均有界。仅direct_melee/secondary_projectile可以触发chain；chain不能再触发chain/split，分裂不能立刻命中父命中对象。每个chain升级每根最多触发一次。chain按距离再handle排序；根/上下文运行时唯一ID、不复用。墙体与敌人碰撞采用扫掠，墙体必须先截断射线。发射者死亡按显式规则清理；退出、重试、房间更换清理全部临时状态。取消前摇不得发射；已经发射者遵守快照及死亡策略。

## 投射物职责与继承

- `projectile_capabilities.gd`：纯查询 `supports_split(definition,params)`；`summarize(catalog,program,attack_ids,has_melee=false)` 返回只读 `{attack_id,projectile,origin,status_ids}` 数组，保留攻击关联；`eligible(entry,summary)` 查找实际兼容对象；爆炸/状态使用supports_impact，状态时长强化必须有同一status_id的真实授予来源，不能靠标签伪造。已选择合法分裂时摘要包含split_projectile子体来源。当前所有等级使用同一已验证scope/trigger；不是跨攻击标签并集。冷却和场上是否有子弹不影响摘要。
- `projectile_factory.gd`：initial(definition,position,direction,damage) 与 child(definition,parent,direction,damage_ratio,target_handle)。不读取卡ID、不持有预算、不创建Node。初始高度来自定义；子体出生在接触点，速度/半径来自child_id定义，寿命=min(父剩余,子定义寿命)，伤害=父快照伤害×分裂比例；代数+1，排除目标集合继承并加入本次目标。
- `projectile_split.gd`：requests(catalog,limits,program,projectile,target_handle)。候选与执行都调用同一个supports_split。每对象/升级一次，只在敌人接触时触发，即使实损为0；墙体接触不触发。接触后父体结束；子体下个模拟步运动。直接投射物和分裂子体允许再分裂（受代数上限）；chain从不调用该入口。
- 由runtime把请求送回原root队列，继承program、来源、伤害与根预算，不重新套全局伤害加成。子体可以换定义，也可以明确禁用进一步分裂。过期父体不生成子体；没有可达队列/投射物/施放引用后回收根。
- Resource中的projectile_mesh_overrides按definition_id选择占位网格；箭目前是细长方体，未制作正式箭模型/弓动画。

## 候选与应用提交 API

`rogue/build_offer_sampler.gd`：configure(catalog,compatible:Callable)；compatible(entry,ranks)->bool必须显式注入；sample(ranks:Dictionary, tags:Array, rng:RandomNumberGenerator)->Array[String]；等级/前置/互斥/标签及兼容性过滤后按权重无放回；不足用明确fallback且不重复，仍不足返回较少项（可为空）。

`app/session/training_build_session.gd`：configure(catalog,seed:int,commit:Callable,attack_ids:Array=[],has_melee:bool=false)；capability_summary()->Array；open_offer()->Dictionary；choose(offer_id:String,upgrade_id:String)->Dictionary；snapshot()->Dictionary；program()->Dictionary。

attack_ids在configure时复制冻结，has_melee由app从实际Actor攻击定义注入，当前没有运行时换装备/授予接口；待选期间不能切换配置。app/session调用combat生成摘要并把兼容性回调注入rogue；抽候选和提交复验走同一回调。

返回请求结果 {ok:bool,error:String,offer:Dictionary}；offer含id/candidates/resolved（没有候选时返回空且不冻结）。session状态含 ranks、history、offer、offer_sequence、rng_state（十进制字符串）。open_offer已有待选项时直接返回同一内容，不抽新随机数。choose核对offer/候选/等级并拒绝重复或旧offer。必须构造完全隔离的候选状态及program，commit(candidate:Dictionary)->Error成功后才替换权威状态；失败包括RNG进度均不变。commit读取候选的副本，不能获取权威可变引用。

当前运行于**无持久状态的训练场**，app注入内存提交适配器，重开重置。失败隔离有历史注入验证；正式磁盘接入及本次运行结果不能由此推定。

## UI API 与文案

`presentation/builds/build_choice_panel.gd` extends Control：configure(catalog,shared_theme:Theme)；show_offer(offer:Dictionary,ranks:Dictionary)；dismiss()；refresh_text()。signal choice_requested(offer_id:String,upgrade_id:String)。不直接改Build/读写文件/抽随机数。

卡片Button名称 Upgrade_<id>。点击只发请求，app确认后关面板；失败留原候选，set_error(key:String)。三选一全屏模态拦截点击/滚轮；局部panel自行不接战斗/暂停。窗口缩放自适应1280×800、1920×1200；保留共享字体。描述用 tr(description_key).format(params)；params来自该升级下一级的完整参数，并附 rank/max_rank、bonus_percent、damage_percent、falloff_percent（适用时）。不能宣称未生效能力。

`presentation/builds/build_effects_view.gd`：configure(style Resource)；sync(projectiles:Array,delta:float)；show_chain(points:PackedVector3Array)；clear()。placeholder几何/材质/寿命Resource外置；只表现。

翻译键与测试升级ID以当前JSON为准；内部offer ID仅用于提交/日志，不展示给玩家。

## 训练流程与验收

开场与清波选择次数来自offer配置；调试按钮仅供训练。选择期间停止角色、AI、技能、子弹、派生队列与镜头时间，禁Gameplay输入；L不重抽，Esc不跳过。清波面板在当前战斗步骤完成后打开，不从击杀回调同步打断解析。当前普通/三选一暂停为训练门控，尚非通用嵌套暂停服务。测试fixture可在入树前关闭自动选择以回归基础战斗。

必须验证：内容错误拒绝；固定seed复现/不重复/前置/满级/不足；重复提交/伪造卡/失败状态不变；解析顺序/等级替换；cast快照；剑气挥空发射与扫掠墙阻；chain来源限制/排序；split继承预算/排除父目标；预算压力/清房；真实三选一中英文、点击后生效、暂停无穿透、继续战斗和重试清理。不把美术切换当Build效果。

## 当前验证

当前爆炸/状态专项与回归、图形集成结果统一见 [命中机制验证](COMBAT_MECHANISMS.md#6-本轮验证与边界)。此前schema v2投射物最小切片由用户手动确认“测试通过”；不把该验收扩大到本轮新增机制。
