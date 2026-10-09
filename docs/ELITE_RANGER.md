# 精英游侠：训练场战斗切片

更新：2026-10-07。当前已接入连续箭雨、逐光蓄力箭＋残留裂隙、节奏连射与半血组合。规则/集成验证与人工难度验收分开记录。

## 试玩入口

运行 `game/project.godot` → 店铺 **F6** → 完成开场三选一 → 顶部 **训练工具** → **刷新精英游侠**。建议先开玩家无敌观察预警，再关闭无敌测试侧移、Shift、掩体和冻结。

- 首次额外生成一名游侠，再次刷新只替换该按钮管理的存活游侠并清理其旧箭/区域；尸体保留到退出。保留玩家HP、Build、其他敌人及原遭遇计划。
- 人数上限、资产/出生点无效时保留旧实例与随机序号；暂停、模态选择、死亡和切场期间拒绝刷新。清场后仍可召唤与施放玩家技能。
- 游侠继承训练敌人无敌开关；不进入普通遭遇池、不发掉落或三选一、不接永久状态。普通波次清完后仍能与存活游侠战斗。

## 当前招式与反制

| 招式 | 实际行为 | 反制 |
|---|---|---|
| 单发 `fast` | 有限转向，末段锁向；水平飞行，连续扫掠命中/撞墙 | 侧移、闪避、掩体 |
| 扇形齐射 `volley` | 同次发出5箭，按施法ID至多一次有效伤害 | 观察扇形、躲缝隙或掩体 |
| 连续箭雨 `rain` | 连续3次抬弓；每次起手锁定当时玩家所在位置，后续不跟随；有限范围脉冲 | 把圈引向一侧，再离开固定危险区 |
| 蓄力裂隙箭 `charged` | 2.4秒蓄力、末段0.025秒锁向；固定160米/秒、12.5米射程；箭直接命中50，沿实际路径留下6秒裂隙，每0.5秒伤害8；1.65秒后摇 | 观察蓄力提前准备闪避；发射前冻结；实体掩体；离开残留裂隙 |
| 节奏连射 `burst` | 两发普通快箭 → 较长蓄力 → 一发强箭；每发独立前摇/锁向；1.8秒后摇 | 不按等间隔连续闪避，留意第三发延迟 |
| 半血组合 `combo` | HP首次降至50%后可抽到：3轮箭雨发射结束 → 横向蓄力快箭 → 2秒后摇 | 引开箭雨后侧闪强箭，利用后摇近身输出 |

数字仅解释当前配置；唯一来源是 `roles.json`。当前蓄力箭在约8米交战距离飞行约0.05秒；基础步速在末段锁向与最大射程飞行期间不足以移出箭路。它仍是连续扫掠投射物，不按玩家距离动态加速或瞬发伤害。箭不追踪发射后的玩家；弓口高度只有短视觉过渡。

### 蓄力裂隙箭的当前规则与表现

- 复用稳定ID `charged`，连射最后一箭和半血组合最后一箭统一使用本技能。数值唯一来源 `roles.json`，不读取 `source_assets` 内样机JSON。
- 高速箭采用玩家移动前后位置的相对扫掠，接触后不重复命中；可以穿过玩家继续铺设路径，碰世界停止。直接伤害使用既有受击/闪避/训练无敌接口。
- 裂隙只沿已经实际飞过的路径生长。发射后首个0.5秒检查占据，其后每0.5秒一次，6秒端点不再跳伤，共至多11跳；退出不受伤，再进入不重置时钟。每条裂隙独立结算与计时；不同来源/不同次释放可叠加。
- 危险带半宽1.15米；视觉开口有宽窄变化，外侧金线表示规则范围。命中还检查末端截断和横向实体掩体；不隔墙扣血。墙体截断后的光照也收在实际箭路内。
- 冻结取消未发射箭；已发射箭和裂隙继续。来源死亡、训练刷新、退出和玩家死亡清理箭/裂隙与地面开口。暂停不推进逻辑、光雾或声音。正式随机高低差房型还未适配。
- 配置限制最多8个有效裂隙；容量满时不追加强箭，序列进入后摇。独立强箭/连射候选另检查射程；组合允许玩家利用施放期间移动拉开距离。
- 保留认可的宽裂口、非周期崩边、短分叉、内部暗部与向上流动光雾。地面所有层共享16槽轮廓图集，容纳有效区域与有限闭合余辉；多个开口互不覆盖。特效禁用后规则不变，重开表现可恢复当前区域。

### 节奏与中断

- 第一招优先单发，之后从合法招式按独立种子加权抽取；限制重复。第二阶段继续混合独立招式，不会连续重复组合，也不整体提速或放大范围。
- `action_id`是整段招式，`attack_id`是当前子招；`pending_steps`是有限队列。`windup → sequence_gap → 下一次windup`，最后进入完整`recovery`。每个子招有独立`cast_id`，连射不会误用齐射去重。
- 每个子招同时刷新其独立复用冷却；组合内部按自己的节奏执行，组合外不立即重复刚用过的强箭。
- 普通命中仍扣血/闪白，不打断游侠或击退她；冻结取消未发射动作及后续序列，已提交箭/箭雨继续执行。冻结后不补发旧cue；已进入后摇时被冻结，不会缩短剩余后摇。
- 翻滚在4米近身压力持续0.2秒后尝试；比较3/4/5米的全身合法通路和落点，优先拉开距离。冷却3秒，时长0.65秒；不取消已承诺攻击、序列或后摇，滚后须反击并完成恢复才恢复翻滚资格，无额外无敌窗。
- 追击压力在前后摇持续累计；没有路径时限频重试。没有读取玩家输入或预测未来命中的完美闪避；尚未增加附近玩家投射物威胁感知。

### 箭雨安全与时间线

- 当前连续次数与同时容量均为3；schema允许3–5，尚未启用4/5圈的第二阶段版本。
- 容量包含所有游侠的已发射圈（等待/生效）及当前前摇圈，不包含纯视觉消散尾段。
- 每次圈位出现就锁定；0.75秒抬弓后发射，起手后2.2秒首次落箭，随后每0.45秒一次，共3次。伤害只由范围脉冲产生，视觉小箭不重复扣血。
- 起手圈是细红线，第一次伤害脉冲后变成更明显的红色危险环；每次视觉箭落地和冲击消费实际脉冲事实，最后一次后隐藏危险环，余辉有界。
- 新圈位需合法地面，并保留至少一条从玩家位置走出全部圈位的直线退路。当前检查16个方向、玩家完整胶囊的世界扫掠、合法终点，以及基础步速下的预警时间余量；退路不能穿过玩家原本不在其中的已生效圈。不能通过就放弃剩余序列，包含组合后续强箭。
- 独立箭雨仍残留时不再抽取新的齐射/连射等攻击；只有明确的半血组合会接蓄力箭。箭雨可越过低掩体；没有屋顶遮挡。
- 这是当前平地训练房的保守几何准入，不是所有随机房型、动态封路、减速/多敌联合威胁的全局安全证明。未增加跨高低台阶弹道规则。

玩家受击范围独立于移动胶囊，当前半径0.30米；箭的规则半径仍为0.18米。配置与本次边界验证见[玩家受击半径](COMBAT_PROTOTYPE.md#玩家受击半径)。

## 配置与当前接口

| 文件 / 接口 | 权威职责 |
|---|---|
| `game/data/combat/prototype.json` → `actors.elite_ranger` | HP、基础移速、决策与警戒范围 |
| `game/data/enemies/roles.json` → ranger.config | 当前版本 `enemy-roles.8-charged-rift`；各招伤害/前后摇/冷却/权重、锁向、箭雨序列/容量/逃离余量、半血阈值和翻滚 |
| `game/data/schemas/enemy_roles.schema.json` → `$defs.ranger` | 必填/类型/上限；Loader及Python检查时序、序列冷却、强箭伤害/速度/后摇关系 |
| `game/presentation/combat/enemies/ranger_style.tres` | 动画映射、死亡时长、箭尺寸、预警/危险圈、蓄力光与音效/音量、强箭尾迹倍率 |
| `game/presentation/combat/fx/elite_ranger_v001/profile.tres` | 金色实体箭、尾迹/细丝/光粒、落箭曲线、有限冲击表现 |
| `game/presentation/combat/elite_ranger_presentation.tres` | 身体胶囊、模型、朝向与保留尸体策略 |
| `EnemyRuntime.add(..., ranger_queries)` | ranger必须显式提供`roll_path(actor,motion)`、`ground(point)`、`rain_escape(hazards,settings)`、`seed`；Runtime再注入容量检查与存活雨区查询 |
| `ranger_brain._legal_actions(distance)` | 当前距离、视线、冷却、阶段、残留区域及圈位准入统一候选规则；`_start`为内部/测试强制动作入口，不作外部命令 |
| `EnemyRuntime.projectile_spawned / projectile_finished` | 真实发射/结束事实；普通箭接触结束，charged单次接触后继续前进直到世界阻挡或固定射程 |
| `EnemyRuntime.charged_rifts` | combat局部残留路径集合；started/pulsed/retired事实、固定间隔伤害、来源清理 |
| `game/presentation/combat/fx/charged_arrow_v001/` | 已认可样机的表现Resource/Shader、被动状态适配和多开口渲染；不加载独立样机规则 |
| `forest_surfaces.rift_surfaces()` | 房间显式提供可裁切的地砖/基础/地形/薄水面；材质实例隔离，退出恢复 |
| `EnemyRuntime.rain_started / rain_pulsed` | 已发射锁定区域、实际有限脉冲（含同帧被移除的最后一轮） |
| `EnemyRuntime.remove_actor / actor_attacks_removed / attacks_cleared` | 替换、死亡、退出清理当前来源或全场逻辑和表现 |
| `EnemyPresentation.refresh(display_delta)` | 规则之外的显式显示时钟；暂停传0，尾迹/落箭/蓄力声音同步暂停 |

配置先严格校验，再从只读目录注入；不按帧读JSON、不写隐藏数值默认值。改配置需重启训练。没有接玩家Build派生链。

## 已认可资产与生命周期

- 模型工作源：`source_assets/characters/elf_archer/blender/elite_ranger_v001.blend`；导出器与报告：`source_assets/characters/elf_archer/elite_ranger_v001/`。
- 运行GLB：`game/assets/characters/elf_archer/elite_ranger_v001/elite_ranger.glb`，78骨、身体和弓两个网格、24,178三角形、7张打包图像；本轮未重导角色。
- 当前模型缩放2.4（最初1.6的150%），胶囊半径0.57/高2.55。死亡2.8秒后保持尸体末帧，死亡碰撞关闭，刷新/追加波次保留，退出房间释放。
- 动作：idle/move/draw/aim/release/roll/hit/death/rain/rain_release。逻辑采样，动画不决定伤害；蓄力/连射复用已有拉弓和释放片段，尚非最终复杂混合动画。
- 箭源：`source_assets/vfx/elite_ranger_v001/ranger_arrow_v001.blend`，`build_arrow.py`可重导；运行箭模型292三角形。保留金色HDR尾迹、细丝、碎光、撞击和箭雨石屑/薄尘。
- 箭外观宽0.0525米，规则半径0.18米，地面线取真实直径0.36米。强箭使用已认可的逐光长箭/蓄力光丝/裂隙光雾，直接箭命中半径保持0.18米，裂隙半宽另由规则配置。
- 临时音效：`source_assets/vfx/elite_ranger_v001/build_cues.py`可重建运行`charge.wav / lock.wav`；Resource控制音量与音调。正式弓箭/命中音效仍待美术替换。
- 视觉使用独立随机源，关闭特效不改变伤害或AI随机；按来源清理、有限余辉，暂停不推进动画和声音。

## 翻滚残影（2026-10-07）

- 已接入实际游侠翻滚：金绿半透明身体与弓，快照保留当时骨骼姿态和世界位置，沿路径淡出。纯表现，不改变翻滚规则、碰撞或随机流。
- `presentation/combat/fx/elite_ranger_v001/roll_afterimage.tres`是表现配置权威：间隔0.07秒、寿命0.38秒、最小间距0.25米、池上限6个；颜色/亮度/透明度同处配置。共享原网格与Skin，独立快照骨骼和材质；不复制Actor、动画播放器或碰撞体。
- ActorView更新姿态后，由EnemyPresentation推进。零delta/控制锁停止推进；正常结束自然消退，死亡清空，替换或退出随表现节点释放。
- `ranger_roll_afterimage.gd`测试在headless与Forward+均14项通过，覆盖实际训练入口、生成、世界位置/姿态冻结、身体与弓、无碰撞、零delta、容量、淡出、禁用/死亡、替换释放。最终材质已复跑Forward+并检查[实机截图](previews/elite_ranger/roll/afterimage.png)。未做多游侠性能专项；图形退出仍有既有7 Texture RID / 18 ObjectDB警告。
- 日志：`builds/ranger_roll_headless.log`、`builds/ranger_roll_graphics.log`。

## 蓄力箭接入验证（2026-10-07）

- 内容/schema/双语：388个key与PO检查通过。
- `charged_ranger.gd`：24项，覆盖50/8伤害、首跳、离开/再进入、免伤、世界和横向遮挡、冻结、时限与容量、来源清理。
- `ranger_sequences.gd`：32项；`ranger_rules.gd`：36项；`ranger_vfx.gd`：44项；普通敌人360份遭遇计划回归通过。
- `ranger_charged_integration.gd`：真实店铺F6→森林训练场，19项；实际50/8扣血、双裂隙、暂停、禁用/恢复表现、刷新与退出清理。截图为实际游戏帧，测试脚本强制选招；不等于人工难度验收。
- 日志 `builds/charged_game_{rules,sequences,ranger_regression,vfx,roles_regression,integration}.log`。图形退出仍报告7个Texture RID、18个ObjectDB实例，未做释放专项诊断，见[已知问题](KNOWN_ISSUES.md#res-001图形退出资源警告)。未验收长期多游侠性能。
- 未生成Release、未提交或推送Git。试玩入口沿用本页顶部训练工具。

本次实际游戏截图：[蓄力](previews/elite_ranger/charged_rift/charge.png)、[残留裂隙](previews/elite_ranger/charged_rift/rift.png)。

## 前一轮验证（2026-10-06，历史证据）

以下为前一轮结果，不代替上述本次验证：

- 内容/schema/双语检查通过，388个key，PO一致。
- `ranger_sequences.gd`：32项；固定弹速、末段锁向、墙阻挡、冻结与后摇、连射去重、三圈上限、半血组合及取消。
- `ranger_rules.gd`：36项；保留普通受击免疫、冻结、齐射去重、水平箭和翻滚约束。
- `ranger_vfx.gd`：44项；强箭光/声音/暂停、实际脉冲变更危险环、关闭表现伤害不变、独立视觉RNG、最后脉冲和有界清理。
- `ranger_integration.gd`：真实店铺F6 → Forward+森林训练场，37项；实际按钮、替换失败保留、真实物理拒绝围墙封死的雨区、三圈施放、锁向及后摇、5.0米翻滚、尸体与退出清理。
- 普通敌人`enemy_roles.gd`：360份遭遇计划回归通过。没有全量重跑无关模块。

真实训练截图（脚本驱动逻辑阶段，非人工试玩）：[三圈箭雨](previews/elite_ranger/challenge/rain.png)、[强箭锁向](previews/elite_ranger/challenge/charge.png)、[强箭射出](previews/elite_ranger/challenge/arrow.png)。本轮未制作新视频。

本机日志：`builds/ranger_sequences_new.log`、`ranger_sequences_rules.log`、`ranger_sequences_vfx.log`、`ranger_sequences_roles.log`、`ranger_challenge_integration.log`。无SCRIPT ERROR或ERROR。图形退出仍有既有7个Texture RID及13个ObjectDB泄漏警告，见[KNOWN_ISSUES](KNOWN_ISSUES.md)；未做释放问题专项修复。

主观难度、真实玩家三种Build对抗、长期多游侠性能、全部随机布局/动态封路尚未验收。只保留已有单个训练精英入口，没有新增陷阱/召唤/多血条、正式精英遭遇池或存档。未生成Release，未提交或推送Git。
