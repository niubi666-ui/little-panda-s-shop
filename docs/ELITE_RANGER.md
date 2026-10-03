# 精英游侠：训练场战斗切片

2026-10-03。已接入当前工程，完成最新资源导入、针对性规则验证和真实森林训练场集成验证；主观难度与动作衔接仍待玩家试玩。数值唯一来源为下方 JSON / Resource。

## 试玩入口

运行 `game/project.godot` → 店铺 **F6** → 完成开场三选一 → 顶部 **训练工具** → **刷新精英游侠**（Spawn Elite Ranger）。可先启用玩家无敌观察动作。

首次额外生成一名游侠；再次点击只替换该按钮管理的游侠，并清理她的旧箭/箭雨。保留玩家生命、Build、其他敌人和原遭遇计划。达到人数上限、资源无效或找不到合法出生点时保留旧实例、效果及追加随机序号。清场后仍能召唤；玩家死亡、暂停、模态选择和场景切换期间拒绝刷新。

游侠继承训练敌人无敌设置，不进入普通波次必杀计数，不发掉落或三选一，不加入普通遭遇组合、路线或永久状态。普通波次清完时，存活游侠仍能战斗。

## 已实现行为

| 动作 | 当前规则 |
|---|---|
| 高速直射 `fast` | 有限转向瞄准，最后阶段锁向；单支飞行箭，连续扫掠命中，世界碰撞阻挡 |
| 扇形齐射 `volley` | 按配置数量/角度同时发箭；同次齐射对玩家至多一次有效伤害，预警方向与扇形一致 |
| 定点箭雨 `rain` | 起手锁定合法地面区域；抬弓放箭后，在原地执行有限脉冲，玩家离开区域可避开；视觉小箭不独立扣血 |
| 翻滚 | 近距可见威胁累计反应时间后才尝试；检查完整胶囊通路/落点，优先完整距离，再尝试较短的配置距离；方向候选包括两侧、斜后方和正后方；身体真实翻转，Motor唯一控制位移 |
| 恢复与调整 | 不以翻滚取消攻击前摇/后摇；滚后必须承诺攻击并结束正常或中断恢复，才能重新取得翻滚资格；冷却独立限制次数。移动调整有时间上限及停顿 |

- 第一招优先直射；之后按独立种子随机流从合法招式加权选择，有其他合法招式时限制连续重复。贴身优先直射或一次合法翻滚，不持续后退而不攻击。
- 普通受击硬直与冻结可取消尚未发射的动作；解冻经过中断恢复，不补发旧 cue。已提交的箭/箭雨不因施法者冻结而消失。
- 游侠死亡、被替换、训练结束或退出时清理她的攻击；暂停同时停止规则和动画。玩家闪避/训练无敌统一经过现有伤害许可。
- 箭雨允许越过低掩体，只选房间合法地面；本切片未实现室内屋顶遮挡。游侠翻滚没有额外无敌窗，也没有读取玩家按键或预测未来命中的完美闪避。
- 当前只用接近威胁触发翻滚，尚未增加附近玩家投射物的威胁感知。旗手可影响基础移动；游侠三招时长与翻滚时长不随旗手攻速缩短。

## 配置与接口

路径均相对项目根：

| 文件 / 接口 | 权威职责 |
|---|---|
| `game/data/combat/prototype.json` → `actors.elite_ranger` | HP、基础移速、硬直、决策间隔、警戒范围 |
| `game/data/enemies/roles.json` → `profiles[actor_id=elite_ranger].config` | 三招伤害/前后摇/冷却/权重、箭尺寸/弹速/出生偏移、锁向时间、箭雨范围/脉冲、翻滚与站位规则 |
| `game/data/schemas/enemy_roles.schema.json` → `$defs.ranger` | 严格必填字段、数值界限；Python内容检查与Godot Loader检查距离/时序顺序 |
| `game/data/rooms/encounters.json` → `training_tools` | 共用训练存活上限与有限出生搜索参数 |
| `game/presentation/combat/elite_ranger_presentation.tres` | 模型场景、朝向、身体胶囊 |
| `game/presentation/combat/enemies/ranger_style.tres` | 动画ID映射、取箭阶段比例、死亡展示时长、箭和预警的颜色/尺寸/视觉数量 |
| `game/combat/enemies/ranger_brain.gd` | 有限状态、合法招式抽样、锁向/锁区、翻滚资格；不读取模型节点 |
| `EnemyRuntime.add(..., ranger_queries)` | ranger分支要求显式注入 `roll_path(actor,motion)`、`ground(point)`、`seed`；其他兵种沿用原调用 |
| `EnemyRuntime.remove_actor(actor)` | 移除该实例brain/control hook以及其在途箭/区域；不发布击杀或奖励 |
| `CombatTraining._refresh_ranger() -> bool` | 校验后替换受管训练实例，成功后才推进序号；失败由原训练面板显示原因 |
| `ranger_visual.bind_brain / refresh_actor` | 采样逻辑阶段映射的骨骼动画；不从动画事件施加伤害 |

角色目录沿用 schema 1，行为内容版本为 `enemy-roles.3-ranger-scale-roll`。所有 ranger 参数必须显式提供；`rain_delay_sec` 从前摇开始计，必须大于 `rain_windup_sec`，差值为发箭后到首次落箭的延迟。各招冷却不得短于前摇加后摇；瞄准锁定时长不大于前摇。`roll_min_distance_m` 不得大于 `roll_distance_m`。修改配置需重新开始训练。

预警线共用缓存网格，箭/箭雨视图按运行实例ID管理。齐射以施法者句柄＋递增施法ID去重；箭雨每次有限循环，死亡回调后的结束立即退出。敌方攻击没有接玩家Build派生链。

## 资产与动画

- 桌面原件仍在 `D:/Users/陈旭辉/Desktop/final/保留文件/`；归档副本在 `source_assets/characters/elf_archer/original/desktop_final_v001/`，此前逐文件SHA256一致。
- 工作副本：`source_assets/characters/elf_archer/blender/elite_ranger_v001.blend`。
- 可复现导出：`source_assets/characters/elf_archer/elite_ranger_v001/export_runtime.py`；报告同目录 `export_report.json`。
- 运行文件：`game/assets/characters/elf_archer/elite_ranger_v001/elite_ranger.glb`。从源展示阵列选择一个身体和一张长弓，导出单骨架78骨、两个网格，共24,178三角形，7张图像打包；运行不依赖桌面路径。
- 10段动作：idle / move / draw / aim / release / roll / hit / death / rain / rain_release。父骨空间正确转换后烘焙，包含弓弦变形；移除翻滚水平根位移，保留身体起伏/翻转。
- 箭雨原包没有专用动作，本轮在工作副本中制作上半身抬弓及收弓适配。逻辑阶段采样动作，冻结保持姿态，死亡允许播放短尾段。
- 箭矢当前是简化发光条形网格；没有制作最终箭头、拖尾、命中音效或复杂动作混合。技能时序正确不等于动画衔接已经达到最终美术品质。

## 体型与翻滚调整（2026-10-03）

按用户要求，可见模型由1.6缩放调整为4.8，正好为上一版3倍；身体胶囊、血条高度和出箭位置同步校准。翻滚优先6米，路径受限时尝试4米，时长0.65秒；所有候选仍须通过身体扫掠与落点检查，无合法路线就不翻滚。数值权威仍为JSON/Resource。

## 本次验证与边界

最终GLB已重新导入后执行（2026-10-03）：

- 内容/schema/翻译检查通过，388个双语key与PO一致。
- `tests/ranger_rules.gd`：体型/翻滚调整后23项通过，包含高速扫掠、墙阻挡、齐射去重、箭雨锁区/有限脉冲/无敌、前摇冻结取消、翻滚资格和移除清理。另验证完整翻滚速度与距离一致，以及长路径受阻时使用配置中的较短路径；持续近距测试仍会反击。
- `tests/ranger_asset.gd`：前轮最新GLB导入后9项通过（本轮只改场景缩放，未重导模型），单角色/必需动作、实际弓弦变形、抬弓与收弓、翻滚翻转及水平根位移检查。
- `tests/ranger_integration.gd`：最新Forward+ 1280×800 **27项通过**。从真实店铺F6进入，实际指针打开训练面板/点击按钮；覆盖重复刷新、人数上限/坏资源/坏位置失败保留、HP/Build/计数隔离、双语、真实物理墙拒绝翻滚、冻结动画、清场后召唤和玩家死亡清理。
- 同一集成运行另开启16秒真实物理循环，自然决策记录直射7次、齐射2次、箭雨1次、翻滚1次，未强制选择攻击。截图另有暂停后按逻辑阶段采样的姿势对照，不能将这些姿势截图当连续手动操作录像。
- 前轮现有 `enemy_roles.gd` 360个遭遇计划及行为回归通过；普通入口 `training_tools.gd --ordinary` 通过。本轮体型调整复跑内容检查、游侠规则和真实图形集成，没有重复全套旧验证。
- 最新导入/图形测试日志无SCRIPT ERROR或ERROR；既有退出资源警告问题并未做专项根治，仍见 [KNOWN_ISSUES](KNOWN_ISSUES.md)。没有做长期性能、所有随机布局通路或人工操作手感验收。
- 保留剑气半径0.76和三段刺击宽1.8；未生成Release，未提交或推送Git。

### 最新工程截图

按钮位置：[训练工具](previews/elite_ranger/v001/toolbar.png)。

动作采样：[平射](previews/elite_ranger/v001/fast.png)、[齐射放箭](previews/elite_ranger/v001/volley.png)、[抬弓箭雨](previews/elite_ranger/v001/rain.png)、[翻滚中段](previews/elite_ranger/v001/roll.png)。连续物理运行：[自然战斗](previews/elite_ranger/v001/natural.png)。

