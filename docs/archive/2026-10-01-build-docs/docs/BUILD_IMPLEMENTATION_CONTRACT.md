# 三选一与构筑训练切片 · 实现契约

2026-09-26。本轮新增真实构筑运行，正式技能名单尚未确定。数值 JSON、表现 Resource、逻辑时间线与局部事实信号继续遵守 PROJECT_CONTRACT。

## 维护边界

当前API按本页维护；具体任务的写入范围由当次协作分配，不沿用历史会话编号。

## 内容格式 v1

文件 `res://data/builds/prototype.json`，从 manifest 的 `build_prototype_file` 读取，由独立 BuildLoader 校验后返回 BuildCatalog。

顶层：`schema_version`、`offer`、`limits`、`stats`、`upgrades`，全部必填。

- offer：count=3、pool_ids、fallback_ids、initial_offers=1、rewards_per_wave=1、max_queued_offers=4。
- limits：root_effect_budget、requests_per_step、max_queue、max_projectiles、max_chain_jumps、max_split_generation、max_projectiles_per_root、projectiles_survive_source_death。
- stats：damage_scale_min/max、move_scale_min/max。
- 升级：id、name_key、description_key、weight、max_rank、requires（升级ID数组，至少1级）、excludes（ID数组）、required_tags、granted_tags、effect_type、ranks（完整每级参数数组，长度=max_rank）。
- 五种已实现 type 与每级参数：damage_scale/move_scale 使用 bonus；projectile 使用 damage_ratio、speed_mps、radius_m、height_m、lifetime_sec；chain 使用 damage_ratio、radius_m、jumps、falloff；split 使用 count、spread_deg、damage_ratio、max_generation。
- 无任意脚本、表达式或未知字段；跨引用/前置循环/互斥对称/非有限数/等级长度/限制冲突需拒绝。分裂要求 projectile 标签和测试剑气前置。

BuildCatalog 公共接口：entries()->Array[Dictionary]、upgrade(id)->Dictionary、offer_rules()->Dictionary、limits()->Dictionary、stat_limits()->Dictionary；返回内容递归只读。Loader.load_catalog(manifest_path)->BuildCatalog，errors:PackedStringArray；decode(data:Variant)->BuildCatalog 可独立测试。

## 构筑解析与战斗 API

`combat/builds/build_resolver.gd`：configure(catalog)；resolve(ranks:Dictionary)->Dictionary，输出递归只读 program：damage_scale、move_scale、tags（排序去重）、effects（稳定按升级ID排序，元素为 upgrade_id/type/rank/params）。同组选中顺序不影响结果；等级替换旧级不重复累积，属性clamp来自JSON。

`combat/builds/build_runtime.gd` extends RefCounted：

- configure(catalog, player, targets:Callable, wall_query:Callable)。targets 返回当前 Array actors；wall_query(from:Vector3,to:Vector3)->Variant，返回墙体交点Vector3或null。
- set_program(program:Dictionary)。后续升级不得更改既有cast/projectile快照。
- on_committed(cast_id:int,ability_id:String)、on_cue(cast_id:int,ability_id:String) 接玩家Runner局部信号；创建根上下文，cue可挥空发剑气。
- melee_damage(source,base_damage:float)->float，按本次施放快照加成（敌方原样）。
- on_melee_hit(source,target,cast_id:int,ability_id:String,applied_damage:float)；只接受已确认伤害，派生任务排队，禁止递归伤害。
- tick(delta:float)、clear_room()；delta=0不得推进队列/投射物/时钟；清房丢弃全部上下文。
- projectiles()->Array[Dictionary] 只读展示快照，元素 id/position/direction/radius；由表现创建节点，不由规则创建美术。
- diagnostics()->Dictionary 至少含 roots/projectiles/queued/rejected，便于测试预算。
- signal damage_applied(source,target,applied_damage:float,origin:String) 只通知派生已提交伤害；signal chain_emitted(points:PackedVector3Array) 仅表现。

每次cast保存ability基础伤害、伤害倍率和program快照，派生计算倍率一次；同一个根共享效果请求预算（所有子弹/队列共同引用），每步、队列、存活子弹和分裂代数均有界。仅direct_melee/secondary_projectile可以触发chain；chain不能再触发chain/split，分裂不能立刻命中父命中对象。每个chain升级每根最多触发一次。chain按距离再handle排序；根/上下文运行时唯一ID、不复用。墙体与敌人碰撞采用扫掠，墙体必须先截断射线。发射者死亡按显式规则清理；退出、重试、房间更换清理全部临时状态。取消前摇不得发射；已经发射者遵守快照及死亡策略。

## 候选与应用提交 API

`rogue/build_offer_sampler.gd`：configure(catalog)；sample(ranks:Dictionary, tags:Array, rng:RandomNumberGenerator)->Array[String]；等级/前置/互斥/标签过滤后按权重无放回；不足用明确fallback且不重复，仍不足返回较少项（可为空）。

`app/session/training_build_session.gd`：configure(catalog,seed:int,commit:Callable)；open_offer()->Dictionary；choose(offer_id:String,upgrade_id:String)->Dictionary；snapshot()->Dictionary；program()->Dictionary。

返回请求结果 {ok:bool,error:String,offer:Dictionary}；offer含id/candidates/resolved（没有候选时返回空且不冻结）。session状态含 ranks、history、offer、offer_sequence、rng_state（十进制字符串）。open_offer已有待选项时直接返回同一内容，不抽新随机数。choose核对offer/候选/等级并拒绝重复或旧offer。必须构造完全隔离的候选状态及program，commit(candidate:Dictionary)->Error成功后才替换权威状态；失败包括RNG进度均不变。commit读取候选的副本，不能获取权威可变引用。

本轮运行于**无持久状态的训练场**，app注入内存提交适配器，重开重置，不声称接入正式冒险存档。此接口支持以后替换持久提交适配器；保存失败路径本轮用注入失败验证。

## UI API 与文案

`presentation/builds/build_choice_panel.gd` extends Control：configure(catalog,shared_theme:Theme)；show_offer(offer:Dictionary,ranks:Dictionary)；dismiss()；refresh_text()。signal choice_requested(offer_id:String,upgrade_id:String)。不直接改Build/读写文件/抽随机数。

卡片Button名称 Upgrade_<id>。点击只发请求，app确认后关面板；失败留原候选，set_error(key:String)。三选一全屏模态拦截点击/滚轮；局部panel自行不接战斗/暂停。窗口缩放自适应1280×800、1920×1200；保留共享字体。描述用 tr(description_key).format(params)；params来自该升级下一级的完整参数，并附 rank/max_rank、bonus_percent、damage_percent、falloff_percent（适用时）。不能宣称未生效能力。

`presentation/builds/build_effects_view.gd`：configure(style Resource)；sync(projectiles:Array,delta:float)；show_chain(points:PackedVector3Array)；clear()。placeholder几何/材质/寿命Resource外置；只表现。

公共翻译键 build.title/subtitle/choose/rank/owned/empty/error/test_offer/next/no_candidates、combat.choosing，以及每个测试升级 build.test.<id>.name/.description；rank带rank/max_rank，next带rank。内部offer ID仅用于提交/日志，不展示给玩家。UI选项为 power/agility/wave/chain/split。

## 训练流程与验收

开场1次选择，每个非最终波次完成后选择1次；调试按钮可再打开一组三选一（明确训练专用）。选择期间停止角色、AI、技能、子弹、派生队列与镜头时间，禁Gameplay输入；L翻译不重抽，Esc不绕过选择。UI与Build列表可查看当前等级。测试fixture可在入树前显式关闭自动选择，以回归原战斗动作。

必须验证：内容错误拒绝；固定seed复现/不重复/前置/满级/不足；重复提交/伪造卡/失败状态不变；解析顺序/等级替换；cast快照；剑气挥空发射与扫掠墙阻；chain来源限制/排序；split继承预算/排除父目标；预算压力/清房；真实三选一中英文、点击后生效、暂停无穿透、继续战斗和重试清理。不把美术切换当Build效果。
