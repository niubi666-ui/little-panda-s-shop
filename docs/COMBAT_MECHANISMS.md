# 穿透、命中爆炸与控制状态 · 当前切片

2026-10-02。已实现的机制样本，非正式职业/平衡设计。Build schema v4，11项测试升级、3组预设；内容权威在 `game/data/builds/prototype.json`，公共入口见 [Build API](BUILD_IMPLEMENTATION_CONTRACT.md)。

## 试玩

双击项目根 `启动机制测试.cmd`，仅启动本地Godot，不导出。也可在Godot打开 `res://app/mechanism_slice.tscn` 按F6运行当前场景；游戏内店铺F6仍进入普通训练。

1. 完成开场三选一，再从左侧机制预设菜单选择一组。
2. **穿透冻结**：剑气/测试箭沿途直接命中的不同敌人分别尝试冻结。
3. **穿透普通爆炸**：每弹首次合法接触爆炸一次，继续穿透只造成直接伤害，不附送冻结。
4. **寒霜爆破**：首次接触的爆炸同时造成范围伤害和冻结，包括存活的中心目标；随后穿透不再爆炸，也不自动直接冻结。
5. T沿角色朝向发箭，左键挥刀发剑气，L切中英文。预设替换本轮Build并清除旧投射物/状态、取消玩家动作，保留当前敌人；重新训练恢复战场并清空Build及抗冻记录。

三组预设都授予剑气与穿透，便于对比。测试独立箭可通过普通三选一取得穿透/分裂，无需剑气卡。普通三选一、“再抽三选一”、减速与冻结延长仍可使用。冻结延长在存在真实直接或范围冻结携带者时才出现；它影响后续施放，不改已发射对象。

## 文件与职责

| 路径（game内） | 职责 |
|---|---|
| combat/builds/projectile_contacts.gd、projectile_pierce.gd | 稳定多目标扫掠与有限接触额度 |
| combat/builds/impact_effects.gd | 接触事实、来源/次数过滤、有限派生请求 |
| combat/effects/area_targets.gd | 范围/阵营/句柄去重/遮挡/稳定排序与目标上限 |
| combat/effects/area_damage.gd、area_payloads.gd | 共用目标筛选；普通伤害及有限复合范围执行计划 |
| combat/effects/damage_executor.gd | 统一提交角色伤害，生命/无敌/死亡由Actor/Health处理 |
| combat/status/status_runtime.gd | 状态、目标响应、控制组抗冻和战斗时钟 |
| combat/builds/build_runtime.gd | 快照、根/队列/预算、处理器和房间代数协调 |
| combat/builds/projectile_capabilities.gd | 同一攻击/来源的兼容性、能力摘要和执行计划检查 |
| presentation/builds/mechanism_{view,style}.* | 爆炸圈、紫色减速圈、蓝色冻结罩，Resource占位表现 |
| app/training_builds.gd、app/session/training_build_session.gd | 训练入口、预设与奖励的隔离提交 |

## 1. 接触、穿透与来源

统一使用 `enemy_contact`：合法接触并去重后保存目标句柄、直接伤害前的脚点位置和伤害快照，再提交直接伤害。无敌造成0实损、致死接触都保留事实；状态只对仍存活且可受控目标生效。近战由 `melee_resolver.enemy_contact` 接入 `BuildRuntime.on_melee_contact`；原confirmed_hit仍只表示有效伤害。

通用来源仅 `direct_melee`、`direct_projectile`、`split_projectile`，每种效果用 `allowed_origins` 选择；爆炸/连锁不是新接触来源。`max_per_parent`、`max_per_root` 按升级独立计数，近战一次施放/每颗投射物各为父对象。次数在生成请求时消耗，队列/预算拒绝也不返还。冻结的逐目标尝试不共用爆炸的首次接触计数。

`pierce` rank为trigger=`enemy_contact`、scope=`linear_projectile`、max_hits；max_hits表示**总合法直接命中目标数**，不是额外次数。样本为4，上限由limits.max_projectile_hits配置；未选穿透的线性执行器只有一次接触。所有穿透/分裂升级在当前全局构筑中对称互斥，候选、提交复验和执行计划都拒绝并用；尚未实现按动作绑定。

- 本步距离先由剩余寿命和世界碰撞截断，再收集所有敌人扫掠接触；按距本步起点距离、稳定handle排序，同距墙优先，不能命中墙后目标。
- 每弹持久visited和剩余额度；重叠敌人可依序命中，同一敌人跨帧不重打。合法0实损接触消耗次数，结算前已死亡/失效候选不消耗。
- 每次接触的距离都相对同一步起点，不能重复扣累计飞行时间。本步新生成对象不补入旧候选；回调清房/换房后立刻终止旧根后续接触。
- 同一弹沿途共享施放快照、来源和根预算，不重开施放、不重复增伤。次数耗尽、寿命到期或撞墙结束；死亡/取消遵守既有生命周期。
- 当前先处理本步直接接触，再消费派生队列。大步/小步验证直接接触顺序，不承诺爆炸与其他派生效果的完整时间线跨delta等价。

## 2. 爆炸与寒霜范围payload

`explosion` rank：trigger、allowed_origins、max_per_parent、max_per_root、damage_ratio、radius_m、edge_ratio、max_targets、include_primary、occlusion、sight_height_m，全部必填。样本每弹最多一次爆炸，分裂子体各有父计数；普通爆炸没有隐式状态继承。

`area_status` rank：source_effect_id、status_id、allowed_origins、include_primary、max_targets。source_effect_id必须指向并前置要求一个explosion升级，状态存在，来源与爆炸有交集；每个爆炸源最多一项area_status定义。source_effect_id/status_id/allowed_origins跨等级固定。内容与执行允许上述三类来源；**当前寒霜样本只许可近战和直接投射物，分裂子体仍是普通爆炸**。

Resolver将协同编译进指定 `explosion.params.payloads`：第一个damage，至多再一个apply_status。后者保存协同升级ID/等级、状态ID、编译时长、许可来源和独立主目标/数量策略。未选协同只有damage；不授予全局直接冻结，不开放任意效果图。

- `area_targets`统一XZ范围、阵营、死亡、句柄去重、世界遮挡、按距离/handle稳定排序。伤害和状态各自筛选主目标与目标上限；不能用伤害分支排除主目标的结果代替状态列表。
- 伤害=直接接触伤害快照×damage_ratio，再按距离线性衰减到edge_ratio。子体继承伤害系数一次；不根据目标HP实损缩放。不同爆炸可再伤同一敌人。
- 样本伤害include_primary=false，寒霜状态include_primary=true；先完成范围伤害，再对仍存活目标施加状态。免疫冻结者仍可受伤，0实损者仍可受控，死亡者不复活。
- world_ray从中心/目标脚点加sight_height_m查询；缺查询器拒绝请求。当前为点射线近似，范围只作用于战斗角色，不自动破坏房间道具。表现圆圈显示半径，不裁剪墙后部分。
- 复合范围请求沿用原根、program与有界队列，**一条复合请求计一个根预算单位**；其中有目标上限的状态申请同步调用StatusRuntime，不再次排队/开根。直接状态请求仍每条计一个单位。样本根预算为32，普通合法组合留有余量；保护预算不代替来源/次数限制。
- 范围结算仅发已提交伤害和表现事实，不广播通用enemy_contact，不能再触发爆炸、分裂或连锁。有限payload可供未来主动AOE复用，但本轮未实现主动AOE。

## 3. 状态定义与抗连续冻结

顶层statuses：id、kind、duration_sec、max_duration_sec、move_scale、refresh、control_group。slow为refresh=`longest`、control_group为空、0<move_scale≤1；freeze为refresh=`reject_active`、move_scale=0，并引用同一有效冻结组。

status_rules：default_response_id、actor_responses、responses、control_groups。responses保留immune_kinds、slow_duration_scale、freeze_duration_scale；控制组本切片恰好一项 `{id,kind:freeze,thaw_immunity_sec}`，所有冻结ID共享。样本解冻抗冻窗为0.9秒。角色响应覆盖的ID在manifest加载/离线校验时核对；纯decode只检查Build内部引用。

`status` rank为status_id、trigger、allowed_origins、max_per_parent、max_per_root。`status_duration` rank为status_id、bonus；时长=定义时长×(1+同状态强化之和)，夹到定义上限，再乘目标响应系数。完全免疫由immune_kinds表达；伤害无敌不自动等于控制免疫。

- 减速按状态ID保留最长截止时间，多个减速取最小move_scale，不累乘；移除重算剩余实例。
- 冻结活跃期间拒绝续时，包括不同root、不同卡、不同status_id和直接/范围来源。自然到期后抗冻至原expires_at+窗口，不以处理到期的那一帧重新开始窗口。
- 主动remove冻结使目标立即解冻，并从当前战斗时间起给予完整抗冻窗；clear/死亡/失效目标/换房彻底清理，不保留离房抗冻。
- 根侧按目标handle＋control_group只允许一次申请；活着的目标即使免疫、已冻结或处于抗冻期也消耗本根这次机会。目标侧记录跨根抗冻，两者不以请求预算替代。减速不套冻结去重。
- 状态使用统一推进的绝对战斗时钟，暂停不推进；大delta跨越冻结与抗冻两阶段仍按原截止时间判断。状态清空时，抗冻未结束的记录继续保留；窗口结束再解绑。
- 实例保留定义、expires_at和只读来源值，snapshot派生remaining。目标是弱引用，来源只有source_handle/team/root_id/room_generation/ability_id；不强持失效root。当前状态没有DOT/延迟请求，原根可正常回收；未来周期效果须另订根生命周期。

## 4. 控制执行接口

`StatusRuntime.apply(target,id,duration,source,root_attempts={}) -> bool`；BuildRuntime对同根传同一个可变尝试表。`tick(delta)`、`remove(target,id)`、`clear()`、`snapshot(target)`、`control_snapshot(target)`、`diagnostics()`、`visuals()`。仅活状态产生视觉，抗冻记录不会继续显示冰罩。

Actor.set_control统一向Motor和AbilityRunner下发许可。减速影响自愿移动/冲锋速度，不改攻击前摇、攻速或击退。冻结清空移动/强制位移/击退，取消技能与闪避，禁止新技能；不禁用Node、不用Timer恢复。

| 敌人路径 | 冻结规则 |
|---|---|
| 近战/重型 | 取消Runner及有效命中窗口，包括重型前摇 |
| 弩手 | 取消尚未发出的射击，已发射弩箭继续飞行 |
| 矛兵 | 停冲锋、禁止after_motion命中，解冻重新决策 |
| 旗手 | 暂停移动和光环，解冻后重新计算范围 |

冻结期间不推进该敌人的决策/动作冷却；解冻从idle重新决策，保留未消耗冷却。死亡优先，不因解冻恢复死亡者动作。状态时钟在AI前推进；玩家本步直接命中及有界派生队列在敌人命中窗口前结算，冻结可取消同帧敌人待判定攻击，每步不重复发放预算。三选一/设置暂停同时门控规则和占位表现。

## 5. 能力、候选与预设

combat摘要按实际attack_id/origin保留直接status_ids及 `area_effects[{source_effect_id,status_ids}]`，不合并不同攻击标签伪造能力。寒霜卡必须找到同一实际攻击上的兼容爆炸源；冻结延长也识别该范围源确实携带的状态，无需再买直接冻结卡。目标是否免疫不改变长期候选资格。

rogue通过注入查询抽候选；app/session提交时再次使用同一资格/编译规则。test_presets只存id/name_key/顺序upgrade_ids，加载验证引用、前置、互斥、标签和等级。`apply_test_preset`隔离清空候选ranks/history/offer，逐项合法选择并编译，最后一次提交；失败不改状态/program/RNG，成功保留RNG和offer_sequence防旧令牌复用。训练层仅在成功后清运行状态并更新表现，普通选卡仍走原奖励流程。

## 6. 本轮验证与边界

2026-10-02实际执行结果：

- 内容：mechanism_content 32项通过；18组离线非法配置拒绝；内容/PO检查通过。
- 规则：build_runtime、impact_blast、pierce_runtime、frost_blast、build_choices、projectile_capabilities、mechanism_presets、status_controls、freeze_guard、combat_rules、enemy_roles全部通过；敌人覆盖360个计划。包括多接触/同距墙/寿命/跨帧visited/0实损/致死/旧快照/回调清房、穿透分裂互斥、冻结组抗连控、独立主目标筛选和有限范围payload。
- 时序：mechanism_order实际app循环通过，冻结能取消同帧重型待命中，无冻结对照确实受伤。
- headless集成：mechanism_slice_integration、pierce_frost_integration通过，后者含实际Retry重新加载并清Build/抗冻、普通三选一按钮取得寒霜卡。
- Forward+ 1280×800：pierce_frost_integration三预设、范围/冻结显示、实际Retry与普通三选一取得寒霜卡通过；新面板及寒霜卡中英文截图无裁切。使用Button/Menu信号和Viewport T输入，**不是人工鼠标试玩或主观手感验收**。
- 旧build_training模拟键鼠脚本仍未修，既有7个Texture RID退出警告未解决，见 [当前问题](KNOWN_ISSUES.md)。此前v2用户手动通过不代表本轮新增机制手动验收。
- 未完成：正式动作/模型/音效/特效、平衡、主动AOE、DOT/完整Status、Boss韧性、按动作绑定和正式武器槽、穿透与分裂并用、永久经济/正式存档。

本轮没有生成Release，也没有提交Git；初始化后的提交仍需用户明确要求。
