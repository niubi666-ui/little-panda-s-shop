# 命中爆炸与控制状态 · 当前最小切片

2026-10-01。已实现的机制样本，非正式元素/职业/平衡设计。Build schema v3；字段权威在 `game/data/builds/prototype.json`，公共入口见 [Build API](BUILD_IMPLEMENTATION_CONTRACT.md)。

## 试玩

关闭旧测试窗口后，双击项目根的 `启动机制测试.cmd`；它仅启动本地Godot场景，不编译或导出。引擎路径按本机安装目录填写；Godot内也可打开 `res://app/mechanism_slice.tscn` 按F6运行当前场景。

- 左键仍为近战，T沿角色朝向发射测试箭；使用现有三选一/“再抽三选一”获得测试卡。
- 先测“命中爆炸＋投射物分裂”；箭不需要剑气升级。命中后橙色圈表示实际爆炸半径。
- 单独选择“接触减速”，观察紫色脚圈与移动速度；重新训练后选“接触冻结”，观察蓝色罩和动作停止。减速与冻结并存时优先显示冻结。
- “冻结延长”只有在已有能附加冻结的攻击后进入候选池；无需场上已经冻住敌人。它作用于后续施放，已飞出的箭保留原时长。
- L切换中英文；重试清空临时Build，保留该测试入口。数值改JSON后重启。当前Build摘要可滚动，避免测试卡增多把下方按钮挤出屏幕。

## 1. 文件与职责

| 路径（game内） | 职责 |
|---|---|
| combat/builds/impact_effects.gd | 合法接触事实 → 来源/次数过滤 → 爆炸或状态请求 |
| combat/effects/area_damage.gd | 同平面范围、距离衰减、去重、阵营、遮挡和稳定目标顺序 |
| combat/effects/damage_executor.gd | 统一提交角色伤害；最终生命/无敌/死亡仍由Actor/Health处理 |
| combat/status/status_runtime.gd | 状态实例、目标响应、刷新、移除、独立战斗时钟 |
| combat/builds/build_runtime.gd | 原有根/队列/预算协调；调用独立处理器，不承载各机制算法 |
| combat/builds/projectile_capabilities.gd | 候选与执行共用来源兼容性；按攻击保留状态授予关联 |
| presentation/builds/mechanism_{view,style}.* | 橙圈/紫圈/蓝罩，占位Resource；不裁定伤害或状态 |
| app/training_builds.gd、app/combat_training.gd | 接线、选择门控、状态时钟在AI前推进、爆炸后重算光环 |

## 2. 触发与来源

新效果统一使用 `enemy_contact`：攻击形状/投射物与合法敌人接触并去重后，先保存目标句柄、接触前目标脚点位置、本次攻击伤害快照，再提交直接伤害并发布事实。无敌造成0实损和致死命中均保留接触事实；不是击杀事件，也不是有效伤害事件。状态只对仍活着且可接受该状态的目标生效。

`melee_resolver.enemy_contact(source,cast_id,ability_id,target_handle,position,damage)` 接入 `BuildRuntime.on_melee_contact`；原confirmed_hit继续供连锁/反馈使用，不改变其有效伤害语义。剑气/测试箭/分裂子体通过同一个impact处理器。

允许来源为 `direct_melee`、`direct_projectile`、`split_projectile`，由每级完整params的 `allowed_origins` 显式选择。爆炸、连锁不能写入来源白名单，加载时拒绝。`max_per_parent`、`max_per_root` 都必须配置，前者不能大于后者，后者不超过根请求预算；按升级独立计数。一次近战施放是一个父对象，每颗投射物是一个父对象。次数在请求生成时计入，即使预算随后拒绝也不返还次数。

同一升级的status_id/allowed_origins在各等级保持一致并校验；候选因此不会用上一等级范围误判下一等级。无武器名字分支，不使用全局事件总线。

## 3. 爆炸配置与结算

`effect_type=explosion` 的rank字段：trigger、allowed_origins、max_per_parent、max_per_root、damage_ratio、radius_m、edge_ratio、max_targets、include_primary、occlusion、sight_height_m，全部必填。

- 样本当前不包含直击目标（include_primary=false）；可显式启用，启用后存活直击目标会另吃一次范围伤害。死亡目标始终不重复结算。
- 半径在XZ平面判定，使用角色中心受击点；当前范围只伤战斗角色，不自动破坏房间道具。中心伤害=该次攻击快照×damage_ratio，向边缘线性衰减至edge_ratio；不是按HP实损计算。子体先继承父伤害×分裂比例，再算爆炸比例，不重新应用全局增伤。
- 单次爆炸按句柄去重，过滤己方/死亡/范围外对象；按距离再句柄排序，最多max_targets个。不同爆炸是独立命中实例，可能再次伤害同一敌人；不是全根只伤一次。
- occlusion支持world_ray/none。world_ray从中心和目标脚点各加sight_height_m后查询世界遮挡，缺少查询适配器时拒绝请求，不默认穿墙。当前是点射线近似，不是体积可见性或导航可达性。
- 默认允许分裂子体爆炸。所有请求仍借用原root、归属、program和共同预算。爆炸仅结算范围伤害并发area_emitted(center,radius)，**不再触发爆炸、连锁或状态**；预算之外还有明确的来源禁止规则。
- 橙圈外径按半径字段缩放；视效时间/颜色来自Resource。圆圈不裁剪为遮挡形状；圈内被墙挡住者不受伤。

## 4. 状态定义、响应与实例

顶层statuses每项：id、kind、duration_sec、max_duration_sec、move_scale、refresh。kind仅slow/freeze，refresh仅longest。slow的move_scale须>0且≤1，freeze须为0；持续时间为正且不超最大时长。

`effect_type=status` rank：status_id、trigger、allowed_origins、max_per_parent、max_per_root。Resolver从状态定义编译duration_sec到施放快照；卡片展示相同定义/已选修正，不另设时长默认值。

`effect_type=status_duration` rank：status_id、bonus；只强化已授予且存在合法携带攻击的同一状态。倍率=1+同状态bonus之和，最终时长夹到状态定义上限。样本仅一张冻结延长卡。状态授予卡不要求预先拥有自身。

status_rules：default_response_id、actor_responses、responses。responses每项id、immune_kinds（slow/freeze）、slow_duration_scale、freeze_duration_scale。默认响应显式配置；actor_responses按角色稳定ID覆盖。默认所有当前角色使用normal；immune和resistant为可选测试响应，可例如将brute映射到immune。加载manifest/离线校验会核对覆盖角色ID；纯decode只检查Build内部引用。

- 目标响应与来源兼容性分开：能携带冻结的箭仍不能冻结免疫目标。持续时间先按定义上限截断，再乘目标对应duration_scale（0–1，不含0）；完全免疫使用immune_kinds。
- stack_key固定为状态定义ID，每个目标/定义最多一份实例；重复施加取新旧剩余时长的最大值，不累计时长或层数。较长新实例更新来源，较短实例保留原来源。
- 多个减速取最小move_scale，不连续相乘；移除后从剩余实例重算。冻结优先，解冻时仍可保留减速；不恢复一份陈旧的基础速度或光环倍率。
- 实例保留只读定义、remaining及来源值（source_handle/team/root_id/room_generation/ability_id）。只使用弱目标引用；死亡立即清除/解绑，过期和换房清除。
- 状态本身不产生周期/延迟伤害和新请求，所以实例只保留来源记录，原根在最后一个施放/投射物/队列引用结束后可回收。以后增加周期效果必须另行扩根生命周期，不能用过期来源ID领取新预算。

## 5. 控制接入和取消

StatusRuntime.apply(target,id,duration,source)->bool、tick(delta)、remove(target,id)、clear()、snapshot(target)、visuals()。apply只响应存活和明确目标策略；伤害无敌不自动等价于控制免疫。

Actor.set_control向Motor和AbilityRunner下发许可。减速只影响自愿移动/冲锋速度，不改攻击前摇、攻速或击退。冻结清空移动/强制位移/击退，取消当前技能与闪避，禁止新技能；不禁用Node或全局物理，不使用Timer恢复。

| 敌人路径 | 冻结规则 |
|---|---|
| 近战/重型 | 取消AbilityRunner，包括重型原本不可被普通受击打断的前摇；清空有效命中窗口 |
| 弩手 | 专用状态机立即取消尚未发出的射击；已发射弩箭继续原轨迹/寿命 |
| 矛兵 | 立即停止冲锋并禁止after_motion命中；解冻重新决策，不续冲 |
| 旗手 | 停止移动并暂停光环；解冻后按范围重新计算。其他已开招者的攻速快照沿用旧规则 |

冻结期间不推进该敌人的决策/动作冷却；解冻后从idle重新决策，保留未消耗冷却。死亡高于控制；已死者不会被状态过期重新允许动作。玩家直接命中及本步有界派生队列在敌人命中窗口之前结算，冻结可取消同帧敌方待判定攻击；每步只推进一次派生队列，不重复发放每步预算。状态时钟在AI之前由app统一推进，三选一/设置暂停不推进状态或占位表现；切房、重试、训练结束清除状态。

## 6. 本轮验证与边界

- A：内容校验、impact_blast规则通过：三种来源、0实损/致死事实、范围去重/阵营/稳定顺序/遮挡、主目标配置、衰减/目标数、父/根次数、子体共享预算、禁止爆炸递归/连锁。
- B：status_controls通过：重复刷新/移除、多个减速、免疫/抗性、冻结取消各兵种动作/光环、已发箭继续、暂停/死亡/清房、冻结强化资格、施放时长快照、非法内容。
- 时序：mechanism_order通过真实app循环验证冻结取消同帧重型命中；无冻结对照确实受伤。
- 回归：build_choices、build_runtime、projectile_capabilities、combat_rules、enemy_roles通过；最后一项覆盖360个遭遇计划及五类敌人。此前投射物切片已由用户手动验收，该历史验收不扩展为本轮新增机制验收。
- 集成：mechanism_slice_integration在headless与Forward+实际庭院通过；Button信号选择、Viewport T输入、实际世界射线、状态/爆炸表现、选卡暂停及双语参数。图形截图位于builds/mechanism_slice.png及mechanism_cards_*.png。自动集成不等于用户主观手感验收。
- 未完成：正式模型/特效/音效、平衡调参、完整Status/DOT、Boss控制系统、冻结碎裂、元素反应、完整职业/装备授予事务、永久经济和正式存档；没有生成Release。
- 旧模拟键鼠脚本失败、既有7个Texture RID退出警告仍见KNOWN_ISSUES，未宣称解决。
