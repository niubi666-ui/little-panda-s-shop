# 战斗与构筑扩展约定

2026-09-28 从原架构契约拆出。仅在修改本领域接口/规则时读取。

这是扩展时必须保持的语义，不是完成清单。当前原型没有通用 StatusController、DamagePacket 多分量结算、Boss 策略或统一 TimeAuthority。现有精确 API 见 [Build 实现契约](../BUILD_IMPLEMENTATION_CONTRACT.md)。当前弩手/矛兵/旗手采用专用逻辑状态机执行动作，近战/重型沿用 AbilityRunner；不能把下文通用执行器目标误写成已经全部迁移。普通攻击可移动，敌方彼此不碰撞；已实现边界见 [战斗](../COMBAT_PROTOTYPE.md) 与 [敌人](../ENEMY_ROLES_AND_ENCOUNTERS.md)。

## 7. 战斗组件与统一执行通道

角色用组合构建，玩家和敌人共用动作执行能力。避免按元素、皮肤、武器不断继承角色脚本。

~~~text
ActorRoot (CharacterBody3D)
  ActorController / ActorStateMachine
  CharacterMotor
  StatsRuntime + HealthRuntime
  AbilityRunner
  HitDetection / Hurtbox
  StatusController
  BuildRuntime
  IntentSource: PlayerInput 或 EnemyBrain
  ActorPresentation: 模型、AnimationTree、声音/特效挂点
~~~

具体可以有小型 RefCounted 组件，只有需要引擎生命周期、空间或碰撞的部分才做 Node，不为每条数值或每张卡创建常驻节点。

| 部件 | 权威职责 |
|---|---|
| IntentSource | 移动、朝向、攻击/技能/闪避意图，不直接移动或扣血 |
| ActorController | 当前状态允许哪些意图，谁优先 |
| CharacterMotor | 唯一修改角色移动、碰撞响应和朝向的入口 |
| AbilityRunner | 前摇、生效、后摇、资源消耗、冷却、取消与时间点 |
| HitDetector / ProjectileWorld | 收集几何接触，产生命中请求，不扣HP |
| DamageResolver | 校验、去重、伤害/抗性/无敌结算和存活到死亡转换 |
| StatsRuntime / BuildRuntime | 属性计算、词条执行计划、触发资格与计数 |
| StatusController | 燃烧、减速等的叠层、时长和周期 |
| ActorPresentation | 根据状态和结果播放动画、声音、特效、震动 |

首版用3D地面移动、近似同一战斗平面，动画不含根位移。玩家普通攻击的前摇、生效和后摇阶段均可移动，移动速度倍率由能力JSON明确配置。移动输入、导航、冲刺与击退都交给 Motor 仲裁；暂不支持自由跳跃/空战。引入根运动时必须改动明确的Motor适配，不能让动画与脚本同时移动角色。

### 7.1 攻击完整流程

~~~text
意图
→ 状态许可
→ 创建CastInstance（能力、数值与构筑执行计划快照）
→ 前摇
→ 配置的commit时间点：消耗资源、开始冷却
→ 生效时间点：命中形状/投射物/效果
→ 合法性、阵营、无敌与命中去重
→ 伤害包结算并提交
→ 伤害结果/死亡事实
→ 局部队列处理派生效果
→ 表现反馈
→ 后摇结束或取消清理
~~~

消耗/冷却的commit位置、取消前后是否退款由 AbilityDef 明确描述；不能在输入按下、动画轨道和敌人脚本里重复扣费。

配置中的hit_group_id描述命中规则，运行时另分配hit_group_instance_id。去重键包含cast_id + hit_group_instance_id + target_handle。同一次挥砍的多个碰撞形状共享实例ID；不同投射物、不同脉冲默认各有实例ID，避免分裂子弹相互吃掉命中资格。若一组散弹对同一目标只能伤一次，则在数据中显式选择共享组。多段技能按脉冲或规定的再次命中间隔执行。

一份 DamagePacket 可包含物理/火等多个分量，统一提交后只产生一次 DamageApplied，避免每种元素都重复触发整套“命中后”效果。护盾吸收、实际HP伤害、过量伤害、击杀标志分别记录。默认 DamageApplied 触发要求至少实际扣除HP；“命中但无伤”“护盾受击”若要触发，使用明确的其他事件类型。

### 7.2 最小战斗事件契约

| 事件 | 含义 | 核心字段 |
|---|---|---|
| AbilityCommitted | 本次施放已越过承诺点 | actor_handle、cast_id、ability_id、snapshot_id |
| AbilityCueReached | 到达slash/release等逻辑时间点 | cast_id、cue_id、position、direction |
| ContactDetected | 几何接触；可能被拒绝 | hit_group_id、source/target、contact_position |
| DamageApplied | 伤害已提交 | event_id、source/credit/target、damage breakdown、effective_hp_damage |
| ActorKilled | 活到死的一次性转换 | victim_handle、credited_actor_id、root_action_id |
| ProjectileImpact | 投射物发生规定的碰撞 | projectile_id、target或environment、position、split_generation |

ActorKilled 只发一次；随后伤害不能再次记奖励。EncounterController同时拥有波次阶段、待生成任务计数和计入遭遇的单位集合；敌人出生时登记，死亡/逃离/取消生成按明确原因解除。只有全部波次结束、待生成任务为零、集合为空时才允许一次性room_cleared。波次间短暂无敌人不能提前发奖；卸载/异常取消不算胜利，也不靠统计剩余Enemy节点判定清场。

## 8. 构筑：数据组合已有机制，代码扩展新的机制

### 8.1 三个不同概念

- AbilityDef：一次动作如何执行，包括近战、主动技能、闪避派生攻击。
- UpgradeDef：一次三选一获得什么，包含属性修正、能力授予、附魔或触发器。
- StatusDef：燃烧、减速等持续状态的规则。

BuildState 只记录已选升级ID、等级、选择历史和需要持久的运行数据。BuildResolver 将它解析为 BuildProgram；战斗读取 BuildProgram，不判断某张卡的名字。

rogue 负责生成候选，UI展示候选，app确认选择；combat/builds负责效果如何运行。这样不会出现rogue与combat各维护半套Buff的循环依赖。

### 8.2 首批有限效果类型

实现有限、经过校验的效果处理器：属性修正、伤害包附加/转换、发射投射物、施加状态、连锁伤害、治疗、授予能力。只实现当前切片实际用到的类型，其余遵循同一入口后补。

JSON提供类型、条件、目标选择与参数，代码中 EffectHandlerCatalog 显式注册处理器。禁止动态eval、按JSON任意加载脚本、任意公式表达式或把完整控制流变成配置语言。

新增火球数值变体通常只改JSON；新增“抓取敌人并甩向墙面”需要新处理器和验证，这是正常代码扩展。

### 8.3 四个例子的明确语义

本节及后文JSON示例用于验证组合架构，不是最终流派清单。伤害类型与玩法标签使用内容目录中的稳定ID；抗性使用按类型ID索引的映射，不在基础敌人类中写死火/冰/毒/雷四个字段或固定元素枚举。缺失抗性项的行为由显式规则配置决定。新增使用现有运算的类型主要增加配置；新增特殊交互仍需对应处理器、schema和验证。表现主题可以替换，触发、叠层、预算与来源契约保留。

| 构筑 | 正确挂点 | 必须明确的组合规则 |
|---|---|---|
| 火焰剑 | 构造符合标签的DamagePacket时附加火分量；合格伤害后施加燃烧 | 附加火伤与转换物理为火是两种操作，不能混写 |
| 挥剑剑气 | AbilityCueReached中的剑刃释放时间点 | 挥空仍发射，不能依赖“先砍中敌人” |
| 投射物分裂 | ProjectileImpact等指定事件 | 子弹继承根动作、快照和预算；代数与数量有限 |
| 连锁闪电 | 合格DamageApplied之后 | 距离、跳数、衰减、重复目标、是否允许二次触发都显式配置 |

标签区分用途与来源：例如 weapon_sword、imbue_eligible 描述适用能力，direct_melee、secondary_projectile、dot、chain、reflected 描述伤害来源。

示例组合语义：若原型采用火焰附魔，它可以作用于带 imbue_eligible 的普通挥砍和剑气；剑气必须显式声明此标签。燃烧与连锁造成的伤害在示例配置中不能再次触发整套直接攻击效果。UI说明必须由同一解析结果生成，不能宣传一个未真正生效的联动。

### 8.4 执行上下文与防止无限触发

EffectContext至少包含：

~~~text
run_id / room_generation
event_id / root_action_id / parent_event_id
cast_id / hit_group_id / hit_group_instance_id
source_actor_handle / credited_actor_id / target_actor_handle
ability_id / effect_id / trigger_instance_id
origin / direction / impact_position
ability_tags / damage_origin_tags
source_stat_snapshot / build_program_snapshot
trigger_depth / root_budget_handle / ancestor_trigger_ids
projectile_generation / proc_coefficient
~~~

运行时ActorHandle带entity_id与generation，避免对象池复用后旧事件打到新角色。存档不保存这些临时handle；击杀归属使用稳定的会话角色身份。

来源攻击数值与BuildProgram在创建施放时快照化，派生投射物继承；目标防御在命中时读取。施加持续状态时保存相应来源快照。后续加点不会倒改已飞出的子弹。所有快照在当前run/room生命周期内有效。

派生效果进入 CombatWorld 的有界队列，不同步递归调用伤害结算。单纯限制深度不够，必须同时执行：

1. 事件类别与标签过滤；dot/chain/reflected默认不递归触发。
2. 每触发器冷却、每施放/每目标等明确作用域的次数限制。
3. 同一祖先链上同一个触发器默认不重复进入。
4. 每根动作共享的剩余预算；分支引用同一预算记录，不能各复制一份满额预算。
5. 分裂代数、连锁跳数、目标visited集合和同时存活投射物数量限制。
6. 单物理步处理预算，队列剩余项保序；总体超限要诊断并有确定的拒绝策略。

连锁选目标按距离再按稳定实体ID排序，排除无效/已访问目标。分裂默认不立即命中触发它的同一碰撞对象。施法者死亡后已发射投射物是否保留由能力规则决定；切房后旧room_generation事件必须丢弃。

根预算由其全部存活投射物、持续状态和排队效果共同持有，最后一个持有者释放后才回收，不能随施放后摇结束就销毁。状态tick派生的新效果继续使用原预算，不重置满额预算。预算计数单位在执行器中固定为派生效果执行请求，普通移动帧不计入。

内容限制放JSON，防失控的技术上限放RuntimeLimits资源或明确技术常量。正常合法构筑不应频繁碰上安全上限；压力验证是内容验收的一部分。

首版切房策略：统一取消施放、投射物、排队命中、临时状态和房间触发计数；临时Status的scope只支持room。HP、Build及需要跨房的资源/冷却快照保留，是否恢复或补满由run_rules中的房间过渡策略显式规定，地图与奖励选择阶段不推进战斗冷却。入口存档在清理和过渡规则完成后创建。以后支持跨房诅咒时，需增加run作用域状态及上下文迁移，不能直接携带旧room_generation。

### 8.5 属性、等级与状态叠层

首版明确支持：

~~~text
最终属性 = clamp((基础值 + 固定加值之和)
               × (1 + 同组加算百分比之和)
               × 独立倍率之积,
               配置下限, 配置上限)
~~~

修改器按稳定ID排序计算。每项修正带source_handle，移除时撤销该来源并从基础重算，不在旧结果上反复加减。升级等级替换该词条的执行计划，不同时保留旧rank。伤害构造与派生属性不能把同一倍率计算两次。

状态定义必须包含stack_key、stack_policy、max_stacks、duration_policy、tick_policy与来源快照规则。首版燃烧可用“同来源合并层数、刷新总时长、共享tick时钟”；减速用“取最强、不相乘”作为配置选择。运行中剩余时长在StatusInstance，绝不能写回StatusDef。

主动技能通过授予能力进入 LoadoutState，槽位上限来自配置。满槽时明确替换选择，不能隐藏覆盖。类似“火焰＋冲刺＝火焰突进”的联动由纯粹的SynergyResolver解析获得，规定优先级与互斥；同一组已选词条无论先后获得，都解析为同样结果。首版不做让玩家任意拼接技能节点的编辑器。

### 8.6 三选一抽取与保存

过滤顺序：已解锁池→等级上限→前置条件→互斥→当前能力兼容性→权重抽取。没有任何投射物能力时，纯分裂升级不应变成无效选项；可先由剑气解锁兼容标签。

offer_count由JSON配置，目标玩法为3。按唯一升级ID无放回抽取；候选不足时使用明确配置的通用补偿候选，仍不足则清楚展示较少选项并记录错误，不能伪造重复卡凑数。发布前校验可达卡池。

OfferState保存offer_id、candidate_ids、随机词缀已滚出的值与resolved状态。在显示卡片之前提交候选；点击卡片以offer_id/candidate_id验证，选择与Build更新一起持久提交。打开/关闭UI、切语言不消耗随机数。

## 9. 敌人状态机：分离“选什么”与“怎样执行”

EnemyBrain读取PerceptionSnapshot，EnemyDecisionPolicy只提出意图。状态机决定意图能否执行，AbilityRunner负责技能实际阶段，Motor负责移动。

~~~mermaid
stateDiagram-v2
    [*] --> Spawning
    Spawning --> Alive
    state Alive {
        [*] --> Idle
        Idle --> Seeking: 发现有效目标
        Seeking --> Repositioning: 距离或视线不满足
        Repositioning --> Seeking: 重新追踪
        Seeking --> Acting: 技能与距离就绪
        Acting --> Seeking: AbilityRunner完成或取消
        Seeking --> Staggered: 受到可生效硬直
        Acting --> Staggered: 当前技能允许打断
        Staggered --> Seeking: 控制结束
        Seeking --> Idle: 丢失目标
    }
    Alive --> Dead: HP归零
    Dead --> Despawned
~~~

Acting内部的Windup/Active/Recovery由AbilityRunner维护，状态机读取它的阶段，不再设置一份独立攻击计时器。AnimationTree也不是敌人决策状态机。

### 9.1 初始策略

- MeleeChasePolicy：接近、检查视线/攻击距离、攻击、必要时重新站位。
- RangedKeepDistancePolicy：保持射程、寻求射线通路、发射技能。
- BossPhasePolicy：根据HP阈值/遭遇条件切换可用动作池和决策参数，复用现有执行器。

不同史莱姆、哥布林和精英主要组合EnemyDef、Ability集合、模型、策略参数。新动作类型新增能力处理器；新决策逻辑新增策略。不要为每个元素换皮新建整套FSM。

### 9.2 必须明确的边界

- 优先级：死亡最高；然后可生效的硬控制；最后普通动作请求。霸体和免疫在配置中决定控制是否生效，死亡不能被霸体阻止。
- cancel(cast_id, reason)统一清理：命中窗口、预警、技能位移、未到达时间点、占用和表现令牌。死亡、眩晕、切房都调用同一清理入口。
- 延迟回调携带施放代数/取消令牌，不能在角色死亡后被旧Timer唤醒继续砍人。
- 技能声明瞄准是起手锁定、持续追踪还是commit时锁定；预警必须和最终攻击一致，不在末帧偷偷转向。
- 目标失效、目标出房、无法到达、导航堵塞都有明确返回/重试路径。感知/寻路更新间隔、站位迟滞与超时来自AI配置。
- Boss阶段转换只提出动作池变更；是否取消正在播放的技能遵守同一中断规则。

### 9.3 动画和时间谁说了算

逻辑时间线是命中的权威。AbilityDef定义动作时间点，表现层通过animation_action_id映射具体动画，并同步播放速度。替换动画不能改变伤害规则。动画轨道可以触发表现标记，不能直接扣血；逻辑不依赖animation_finished作为唯一退出条件。

AnimationTree中的运行参数按实例设置，避免修改共享动画资源导致所有敌人一起变状态。[AnimationTree文档](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html)

TimeAuthority管理嵌套暂停令牌。三选一、菜单和装修模式通过统一入口获取/释放令牌；UI照常交互。首版战斗顿帧由CombatClock统一暂停攻击、移动、状态tick与动画推进；Motor同时停止位移，命中与派生队列也停止消费，物理回调先排队并在恢复时重新验证。

顿帧令牌由独立的不受暂停影响的单调时钟释放，管理节点保持运行；不能用已暂停的CombatClock倒计时恢复自己。顿帧期间可接收一个有期限的动作缓冲，期限随战斗时间推进；菜单/三选一期间禁止Gameplay输入。普通技能计时不用分散的独立Timer。慢动作后续通过同一入口实现，禁止各脚本随意写Engine.time_scale。
