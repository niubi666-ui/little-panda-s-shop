# 小熊猫的小店：代码架构与开发契约

版本：1.1 · 2026-09-24  
状态：开始实现前的架构基线。本文描述需要实现的设计，不代表相应代码已经存在。

本文是后续开发的工程入口。玩法内容参考《小熊猫的小店-项目玩法说明书.md》，视觉目标参考《美术方向基准.md》。与旧说明书第 11 节冲突的工程约束，以本文为准；新的用户决策应同步更新有关文档。

## 1. 已确认的产品边界

2026-09-27 敌方碰撞补充：所有敌方单位彼此不发生实体碰撞，允许重叠与穿过；敌人与玩家、世界障碍仍有实体碰撞。由 combat_actor 统一设置世界/玩家/敌人碰撞层，场景工厂不覆盖该规则。伤害判定仍由各技能执行器处理。

2026-09-27 敌人分工切片：combat/enemies 负责弩手、冲锋矛兵、旗手及局部光环/投射物执行，沿用近战/重型的 AbilityRunner；rogue/encounters 按深度预算、合法阵容与出生容量生成并锁定遭遇。射击与冲锋在预警开始锁定方向；冲锋撞障碍结束且进入硬直，旗手范围增益取最高值、不叠加、不增强自身。移动增益即时更新，攻击加速在招式开始取快照，已有招式不因旗手死亡突变；新招式立即恢复正常。掉落表独立 JSON，概率与数量先校验并在遭遇计划中按独立随机流锁定；本切片只发出死亡掉落事实，不提交永久库存。未明确要求时不生成 Release。

- Steam PC 单人游戏，Godot 4 + GDScript；高位斜俯视 3D，键鼠先行，输入层预留手柄。
- 战斗约占 70%、店铺约占 30%，作为试玩节奏目标，不强迫每轮等待到固定时长。
- 多位顾客提供订单，玩家可选择 0 或 1 张主订单，也可以自由下地牢。无订单是正常流程。
- 一栋可扩建的主店、一块可装修小院，逐步增加侧翼；首版不做多建筑城镇模拟。
- 三选一不仅增加数值，也能改变攻击行为。火焰、冰霜、毒素、雷电以及剑气、分裂等是候选原型，不锁定最终元素分类或构筑主轴。
- 中英双语、可修改配置、可迁移存档、内容校验从第一个可玩闭环开始建立。
- 先做小型端到端切片，验证接单或自由出发、战斗、构筑、回店、售卖和保存。原说明书中的内容数量不是第一阶段实现清单。
- 三幕用于第一版地图原型；约20敌人/60词条/30商品/40订单等属于中期原型目标。长期扩充十几种房间地图/模板、同风格摆放变体、5–6种Boss及更多敌人、商品和订单；单局Boss数量另行配置。
- 房间怪物难度随深入总体上升。主题、布局、摆放、遭遇与深度曲线分开配置，详见第18节；这些扩展点不要求首版一次实现全部内容。

架构目标是让大多数修改留在所属模块，并把跨模块影响集中在少量明确契约上。新增真正跨系统的玩法仍可能需要多个模块一起修改，不承诺“任何功能都只改一个文件”。

2026-09-25 UI预览补充：树叶主题由`presentation/foliage`负责。预览manifest增加`foliage_preview_file`，其样例目录经schema校验和Registry发布只读Definition，由app注入UI。该目录不是InventoryDef、OrderDef或玩家状态；没有真实库存/交易接入时不得将样例数量、报酬或余额当作游戏数据。UI模式变化使用局部signal协调输入锁定，真实使用/接单/摆放仍应经后续应用用例和会话入口。具体交付边界见`docs/FOLIAGE_UI.md`。

## 2. 总体选择：按功能分模块，用场景组合，显式连接依赖

采用模块化单体：一个游戏程序，内部有清楚的功能边界。每个功能拥有自己的规则；应用层负责把规则连接成完整流程。首版不引入完整 ECS、万能事件总线、通用技能脚本语言或通用行为树编辑器。

~~~mermaid
flowchart TD
    INPUT[输入与界面] --> APP[应用用例与流程]
    APP --> COMBAT[战斗与构筑运行]
    APP --> ROGUE[节点地图、房间、奖励候选]
    APP --> SHOP[订单、打造、零售、装修]
    APP --> INV[库存规则]
    APP --> SESSION[会话状态与提交]
    SESSION --> SAVE[存档适配器]
    BOOT[启动与场景组装] --> CONTENT[只读内容目录]
    BOOT --> APP
    BOOT --> COMBAT
    BOOT --> ROGUE
    BOOT --> SHOP
    COMBAT --> VIEW[模型、动画、音效、特效]
~~~

图中是主要调用与组装关系；事实通知反向通过局部信号传回。UI 和游戏规则都不直接打开存档文件。

### 2.1 依赖规则

1. 输入和 UI 发出请求；应用用例校验并执行；界面展示只读结果。
2. 模块只使用公开接口，不跨模块读取内部 Node、数组、字典或场景路径。
3. 子场景内部可以使用固定的局部节点引用；外部服务、目标和配置由父级组装层传入。
4. 禁止通过多层 get_parent()、绝对 /root/... 路径、全局按名字搜索来获取业务依赖。
5. combat 不导入 shop；shop 不读取敌人状态机；rogue 不操作 HUD；内容加载器不依赖这些模块的运行时对象。
6. 内容定义与少量共享值类型可以被多个模块使用；不要将业务逻辑全部移入一个 CommonManager。
7. GDScript 使用有类型的类与少量基类表达边界；不假设存在 Java/C# 风格的 interface 语法。

Godot 官方也建议由父级注入外部依赖，并让场景尽量独立。这里的分层是本项目的具体选择。[官方场景组织说明](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html)

### 2.2 生命周期与全局对象

2026-09-26 武器表现接口补充：战斗表现 Resource 通过 `weapon_visual_scene: PackedScene` 注入武器模型；武器模型与刀光场景独立替换。视觉模型长度遵循表现配置，不能作为伤害/碰撞范围或技能时序来源。

选择持久主场景 Main，启动后只替换其 World 子节点中的店铺/地牢。首版业务系统无需 Autoload；平台接入等确有独立全局生命周期的服务再单独评估。

~~~text
Main
  Bootstrap                    读取配置、内容、设置和存档，创建依赖
  SessionCoordinator           主流程和跨模块用例
  TimeAuthority                暂停与战斗顿帧
  World
    ShopRoot 或 DungeonRoot
  UIRoot                       常驻HUD/弹窗入口
  AudioRoot
~~~

ContentRegistry、SaveStore 等由 Bootstrap 创建和持有，按需注入。禁止用 Main.services.xxx 作为隐蔽的全局服务定位器。测试场景通过自己的小型组装器创建需要的依赖。

DungeonRoot 内将 RunActors、RoomSlot、CombatWorld 分开；玩家生命周期属于当前冒险，房间敌人和道具属于 RoomSlot。换房时无需把玩家从即将删除的房间中抢救出来。

## 3. 目录与责任

Godot 项目放入 game/，让概念图、文档、Blender 源工程与开发输出留在项目外。下表是目标布局，不要求首日创建所有空目录。

~~~text
E:/ShopGame/
  PROJECT_CONTRACT.md
  AGENTS.md
  小熊猫的小店-项目玩法说明书.md
  美术方向基准.md
  concepts/
  source_assets/               Blender源文件、生成脚本、原始素材
  tools/                       内容校验、翻译生成、导出辅助
  game/                        Godot根目录；这里开始才是res://
    project.godot
    app/                       启动、组装、流程、跨模块用例
    contracts/                 少量共享ID、结果、快照和事件值类型
    content/                   读取、校验、Definition、Registry
    session/                   Session/Profile/Run状态、提交协调
    inventory/                 容器、堆叠、移动、预留规则
    combat/
      actors/                  玩家与敌人共有组件
      abilities/               技能时间线与执行器
      effects/                 伤害、投射物、状态和有限效果类型
      builds/                  词条解析、派生属性、触发器
      ai/                      感知、决策策略、敌人状态机
    rogue/                     节点生成、房间、波次、三选一候选
    shop/
      orders/
      crafting/
      retail/
      decorating/
    presentation/              通用UI、输入、镜头、音频、特效适配
    infrastructure/            文件保存、平台等引擎/系统适配
    data/                      人工编辑的内容JSON
      manifest.json
      schemas/
      balance/
      actors/
      enemies/
      abilities/
      upgrades/
      statuses/
      projectiles/
      items/
      recipes/
      orders/
      loot/
      rooms/
      shop/
      locales/
    resources/                 表现配置、资源目录、Theme等.tres
    generated/locales/         从JSON生成的.po，禁止手改
    assets/                    已整理、可供引擎使用的模型/贴图/音效
    tests/                     有价值的规则测试与可运行验证场景
~~~

模块可拥有自己的 UI 场景和展示脚本，但规则层不得依赖这些展示脚本。inventory 是共享能力；店铺、地牢和订单不各写一套堆叠或扣物品算法。

| 模块 | 唯一负责 | 不负责 |
|---|---|---|
| content | 将内容文件变成已校验的只读定义 | 当前生命、金币、存档进度 |
| combat | 攻击、伤害、状态、构筑效果的执行 | 订单交付、回店发奖 |
| rogue | 地图、房间遭遇、奖励候选生成 | 直接修改永久金币或在自己目录再实现Buff |
| shop | 订单/配方/购买/摆放的规则与变更计划 | 直接写存档、控制玩家战斗 |
| inventory | 库存约束与物品转移计划 | 决定任务奖励、物价或掉率 |
| session | 权威持久状态、修订号、提交入口 | 伤害算法、场景动画 |
| app | 将上述能力组成接单、开局、交付、结算等用例 | 容纳所有算法的巨型GameManager |
| presentation | 输入转意图、界面、模型、镜头、声音 | 决定是否造成伤害或交易成功 |

## 4. 数据驱动：保留 JSON + Resource，避免两个极端

### 4.1 数值外置的准确含义

必须外置的内容包括伤害、生命、移速、冷却、攻击距离、AI决策间隔、掉率、价格、词条权重、状态持续时间、叠层上限等。需要设计师调节的表现参数也外置到资源。

禁止：

~~~gdscript
# 禁止内容数值硬编码，也禁止内容字段的偷偷兜底
damage = 25
move_speed = data.get("move_speed_mps", 5.0)
~~~

允许代码包含算法中的 0/1、索引、枚举、空集合、协议/存档版本和明确命名的技术安全常量。运行状态“当前层数从0开始”可以写在代码里；“初始金币是多少”必须来自新档配置。GDScript 隐式零值或占位初始化不能被当成有效配置使用。

缺少必填配置时，报告文件、内容 ID、字段与原因，阻止开始或加载相关游戏会话；不能退回一个看似能玩的默认伤害。

内容默认值可以存于显式引用的命名 profile。例如 enemy.basic_melee 引用 balance.melee_basic。加载时展开成完整定义。首版最多一层 profile 与显式字段覆盖，不做任意深层继承；数组覆盖是整体替换，不靠隐含合并顺序。

### 4.2 一个字段只有一个权威来源

| 数据 | 权威编辑位置 |
|---|---|
| 敌人/玩家数值、能力时序、攻击范围、词条/状态/投射物参数 | data/ 下按领域拆分的 JSON |
| 商品、配方、订单、掉落、解锁、家具价格与格子占地 | JSON |
| 中英文案、名称、说明模板 | locales JSON |
| 材质、贴图、音效、模型场景、动画库、AnimationTree资源、Theme、镜头预设 | 原生Resource或.tres引用 |
| 场景层次、房间碰撞/导航、插槽/骨骼挂点、初始节点摆放 | .tscn及其引用资源 |
| 角色身体碰撞/受击形状等随模型校准的几何 | 专用ActorPresentation/BodyConfig资源；属于需验收的游戏几何 |
| 攻击命中形状的可调半径、长度、角度 | JSON；不同时在Shape资源里另存一份攻击范围 |
| 默认输入动作与按键 | project.godot |
| 玩家语言、音量、画质和重绑 | user:// 下单独的设置文件 |
| 当前生命、词条层数、金币、库存、已摆家具 | 运行时状态；需要持久的部分进入存档 |

@export 是 Inspector 暴露机制，不是第二套玩法数值仓库。脚本可暴露 definition_id、所需资源引用；不要同时在 Inspector 和 JSON 配置同一个 damage。

InputMap 是引擎提供的输入映射接口，不能把它笼统当作 .tres。默认设置与运行时重绑分别由 project.godot 和设置适配器管理。[InputMap文档](https://docs.godotengine.org/en/stable/classes/class_inputmap.html)

### 4.3 按领域拆 JSON，不做一个巨型总表

manifest.json 是统一入口，列出要加载的文件、内容 schema 版本和 content_version。伤害集中在能力/敌人/构筑所属数据文件中，经济集中在经济配置；同一数值不复制进多个表。

标识符使用稳定英文 ID，例如 enemy.forest_slime、ability.sword_slash、upgrade.sword_wave。玩家看见的名字是翻译键，不参与逻辑比较。引用字段统一使用 _id/_ids；时间用 _sec，距离用 _m，速度用 _mps，作者输入角度用 _deg，解码时统一转换。

概率使用 0到1，抽取权重是非负相对权重，二者不混用。金额和数量使用经过范围校验的整数。Godot JSON 数字处理需要明确整数性与精度检查，不能只凭解析后的类型名称判断它是不是整数。[JSON文档](https://docs.godotengine.org/en/stable/classes/class_json.html)

### 4.4 加载与校验

~~~text
manifest
→ 读取与严格语法检查
→ schema字段/类型/范围/未知字段检查
→ ID唯一性与跨表引用检查
→ 业务一致性检查
→ 解码成有类型的Definition
→ 完整成功后发布ContentRegistry
→ 工厂查定义并注入实例
~~~

- 构建工具先以严格JSON解析拒绝重复键，再使用版本固定的JSON Schema校验器拒绝拼错的未知字段、非法类型/数值，最后检查跨表引用。
- 运行时解码器仍校验关键字段与类型；schema、解码器和样例由同一接口负责人协调，有一致性验证。
- 校验订单商品有配方或可获得来源、敌人技能与掉落存在、词条前置条件无错误循环、互斥/等级合法、卡池有可用候选。
- 效果类型、AI策略、事件类型只能来自代码注册的能力清单。Bootstrap将支持清单交给内容校验，不让内容层反向导入战斗实现。
- 校验翻译键、占位符、资源 ID、动画动作映射、技能时间点与取消策略。错误列表尽量一次报告完整。
- 强类型 Definition 建议使用 RefCounted 数据类；与 Inspector 协作的表现定义使用 Resource。每帧逻辑不解析 JSON、不反复查字符串字典。

Registry 持有完整定义目录，但模块只收到需要的 EnemyDef、AbilityDef、BuildCatalog 等窄依赖。共享 Definition 按只读约定封装；嵌套集合也需只读或返回副本。不能把 Resource 或 Dictionary 中的剩余生命/剩余时长改成运行状态。Resource 可共享引用，尤其动画图与材质的运行时参数必须注意实例隔离。[Resource文档](https://docs.godotengine.org/en/stable/classes/class_resource.html)

首版不做战斗中的内容热重载。开发时重载需先回到安全场景，生成完整新目录后再开始新会话。

### 4.5 原始 JSON 与资源进入导出包

本项目约定内容 JSON 通过 FileAccess 读取原始文本，资源通过 ResourceLoader/显式资源引用加载。必须配置 Keep File 或导出包含规则，逐项确认 manifest 文件在导出的程序中存在；不能只在编辑器里验证。

JSON只保存受支持的内容/资源 ID。AssetCatalog.tres 建立模型、图标、特效、声音等 ID 到原生资源的强引用，使依赖可检查、可打包。JSON不能提供任意脚本路径或可执行表达式。[FileAccess导出注意事项](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html)

## 5. 定义、运行状态与所有权

| 层次 | 例子 | 生命周期与修改权 |
|---|---|---|
| Definition | EnemyDef、AbilityDef、UpgradeDef、ItemDef | 启动后只读，可共享 |
| ActorRuntime | 当前HP、技能进度、状态层数、仇恨目标 | 当前角色，由对应战斗组件修改 |
| RunState | run_id、节点进度、局内钱、战利品、Build、随机状态、当前奖励 | 当前冒险；高频战斗状态在安全点汇总 |
| ProfileState | 永久钱、长期库存、订单板候选/已接订单、解锁、店铺布局、结算凭据、店铺随机流 | 由Session提交入口接受完整变更 |
| SettingsState | 语言、键位、音量、辅助功能 | 设置服务，独立保存 |
| PresentationState | 粒子、动画混合、镜头震动 | 可重建，不写入业务存档 |

SessionState 包含 ProfileState 和可空的 RunState。需要一致提交的数据放在同一个存档快照里，不把金币、订单和当前冒险分别写入互不协调的文件。

InventoryState 中不同容器分别代表长期仓库、地牢战利品、货架和交货预留区。上架是物品转移或显式预留，不复制一份商品。出售、打造和交货只能消费尚可用的数量。

普通材料使用 definition_id + quantity；真正需要独立属性的商品再使用稳定 instance_id 和已确定的词缀值。不要给每块普通石头都创建完整独立实体。

推荐初始区分 run.coin 与 profile.gold；换算规则若启用，由结算数据显式定义。这是可调整的经济设计选择，系统不能默认把两种余额混成一个数字。

## 6. 模块之间怎样通信

命令用于请求动作；初期就是明确的有类型方法，不创建万能 CommandBus。返回 CommandResult，带 ok/error_code/参数/变化摘要。规则层只返回错误码和值，UI负责把它转换为本地化消息。

| 公开命令 | 所有者 | 必要输入/结果约束 |
|---|---|---|
| accept_order | app/订单用例 | offer_id、当前revision；检查档案状态、订单仍有效、主订单槽位 |
| start_run | app/开局用例 | 合法loadout；从权威状态读取可空订单，不接受UI随意伪造订单 |
| choose_route | rogue，经app入口 | 当前node_id、可到达next_node_id；拒绝重复/非法跳转 |
| choose_upgrade | app/奖励用例 | offer_id、candidate_id；对当前已保存候选验证，只接受一次 |
| craft | app/打造用例 | recipe_id、quantity；规划材料扣除与产出后整体提交 |
| list_item / buy_item | app/零售用例 | 物品/货架/报价与revision；检查可用数量 |
| fulfill_order | app/交付用例 | order_instance_id、商品分配；扣货、奖励、信誉、订单状态一起提交 |
| place_furniture | app/装修用例 | 家具实例、区域、格子、旋转；检查权限、占地、通行 |
| finish_run | app/结算用例 | 当前run_id、合法结束原因；由已提交战斗状态形成结果 |

过去式 signals 用于事实通知，例如 room_cleared、upgrade_selected、inventory_changed、order_fulfilled、run_settled。跨模块连接由 app 完成，监听者只响应事实。

禁止“扣材料信号→某监听者加金币→另一个监听者完成订单”的广播式交易。任何一次交易完成后再发通知，UI漏接消息不会影响结果。

事件数据使用有类型的值对象，不把自由 Dictionary 当成永久公共接口。异步操作携带 request_id、run_id、room_generation 或 owner_token，确保过时回调失效。

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

## 10. 订单、经营与装修

### 10.1 订单可选

ProfileState唯一持有OrderBoardState和已接OrderInstance；订单板记录候选实例、需求/报价已确定值、刷新批次与期限。OrderService根据输入快照计算规则和变更计划，不维护第二份可变订单状态。候选展示前提交，刷新是显式用例；打开UI、生成顾客模型和切语言都不会重新抽取订单。

订单提示RouteHint只是目标标签/来源信息，交给节点地图展示；地图不直接读取订单UI。active_order_id为空时仍能开局、抽卡、拾取、结算、解锁和售卖。

订单图纸、所需商品与可到达来源要通过内容校验。构筑的临时火焰附魔不自动等于店铺拥有永久火焰商品；商品标签由物品/打造规则产生。接受已有库存能完成的订单是合法情况。

期限使用经营日/完成冒险次数等业务时钟，明确由run结算推进，不用系统现实时间。普通/紧急订单的惩罚和报酬放在数据中。接取本身是否预留库存必须显示且由用例提交；默认不隐式锁住所有相似素材。

### 10.2 交易

打造、上架、购买、交货、扩建都通过显式用例。Shop规则计算价格/需求；Inventory规则分配和转移；Progression数据规定解锁。会话提交成功后才通知展示层。

顾客模型不是订单/售卖的权威数据。即使顾客场景暂未生成，业务规则也可以独立验证；点击/动画结账只是发出购买请求，不能在动画结束又重复加钱。

### 10.3 装修与场景

LayoutState记录家具instance_id、definition_id、区域ID、格子坐标、旋转档位。PlacementValidator检查解锁区域、占地、重叠、必要通道和地窖/柜台入口。先在预览快照验证，确认后提交。

首版采用网格与有限装修区域。摆放验证用自己的占格/通路数据，不把渲染模型AABB直接当业务占地。布局提交后由场景适配器实例化模型并更新顾客导航；修改家具美术不会直接改变格子规则。

店内与小院分别是同一LayoutState里的区域，侧翼扩建是新增区域或升级区域定义，不需要现在做任意建筑生成器。

## 11. 中英双语

JSON作为唯一人工编辑源；构建工具将其生成Godot原生PO翻译文件，再由TranslationServer加载。生成文件放generated/locales，首版提交进Git方便直接打开工程，CI/校验脚本重生成后要求无差异；禁止手改PO。

Godot支持PO、复数和上下文，可利用原生能力，不另造一套完整翻译引擎。[gettext本地化文档](https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_gettext.html)

规则：

- 支持zh_CN与en；初次自动匹配，界面可即时切换，并保存用户偏好；不支持的系统语言回退到配置语言。
- 所有面向玩家的固定文本使用稳定key。字符串参数采用有名占位符，不拼接“前半句＋物品＋后半句”。
- 技能说明中的数值来自同一个Build/Ability解析结果，不在翻译文本重复写死伤害。
- 英文复数使用JSON中的one/other形式，生成正确PO复数条目并经tr_n处理；中文对应自己的形式。
- 动态UI保存key+args并在语言切换时重新格式化，不仅依赖静态Label的自动翻译。
- 玩家自定义名字禁用自动翻译；作为RichText参数使用时转义，避免被当成格式标签。
- 使用包含中文和拉丁字形的字体及fallback；字体有明确分发许可。Container/最小尺寸/换行适配较长英文。
- 商品图标、招牌和场景贴图不烘焙必须翻译的文字。键位提示从当前InputMap生成。
- 开发期缺key显示显眼标识并报错；发布构建要求必要key完整。两种语言占位符、参数类型与BBCode结构均校验。

以下是结构样例，数值仅用于演示，不是确认后的平衡值：

~~~json
{
  "locale": "zh_CN",
  "messages": {
    "upgrade.fire.name": "火焰附魔",
    "upgrade.fire.description": "为可附魔攻击附加 {fire_damage} 点火焰伤害。",
    "ui.item_count": {
      "plural_key": "ui.item_count.plural",
      "forms": { "other": "{count} 件商品" }
    }
  }
}
~~~

~~~json
{
  "locale": "en",
  "messages": {
    "upgrade.fire.name": "Flame Imbuement",
    "upgrade.fire.description": "Add {fire_damage} fire damage to eligible attacks.",
    "ui.item_count": {
      "plural_key": "ui.item_count.plural",
      "forms": { "one": "{count} item", "other": "{count} items" }
    }
  }
}
~~~

更多字体、占位符和切换行为参考[官方国际化说明](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html)。

## 12. 会话流程、事务与存档

### 12.1 唯一主流程

~~~text
BOOT → MENU → SHOP → PREPARING → RUNNING → SETTLING → SHOP
                            订单可空
RUNNING内部：
MAP → ROOM_LOADING → COMBAT → REWARD → MAP / SETTLING
~~~

主流程只由SessionCoordinator推动。门、Boss、UI按钮提出请求或报告事实，不能自行切场景又各写一次存档。

### 12.2 原子用例与幂等

对持久经济变更采用明确的提交帮助函数，不做完整数据库或事件溯源系统：

~~~text
读取当前revision
→ 各规则模块校验并形成变更计划
→ 对候选SessionState应用全部变更
→ 检查库存非负/容量/余额/引用等不变量
→ 保存候选快照成功
→ 一次替换权威内存状态
→ 发布完成事实，刷新UI
~~~

候选SessionState必须通过专用clone/to_dto-from_dto构造完全隔离的可变状态，包括嵌套Inventory、Run、Build、Layout、订单集合和随机流状态；可以共享只读Definition。不能假设浅拷贝Dictionary或一个通用duplicate就能复制自定义对象。交易抽随机数也在候选RNG上执行，失败时权威状态及RNG均不改变。

命令在主线程串行处理；保存期间有关提交排队或显示忙状态。期望revision不符时重新校验，不能执行基于旧库存的方案。高频攻击/移动不每帧写磁盘。

run结算使用稳定settlement_id（由run_id派生）防重。同一提交包含：战利品保留/损失、货币换算、订单期限推进、解锁与信誉结果、结算凭据以及清除当前RunState。存档成功但UI尚未显示时退出，重开读取凭据也不会重复发奖。

订单交付同样用订单实例状态/交易ID防重。不能仅靠按钮灰掉保证只领奖一次。

### 12.3 首版保存范围

首版实现店铺操作后保存，以及房间入口、清房后、三选一候选与选择结果的安全点保存。战斗中退出恢复到当前房间入口的快照，当前房间未提交的血量、消耗和掉落随之回退；在继续游戏提示中明确说明。

房间入口保存已决定的room/encounter seed与入口状态；奖励保存已经抽出的候选。RunState还必须记录稳定的room_instance_id、resume_phase、room_cleared、reward_instance_id和奖励状态，恢复不依赖某个UI是否还打开。

清房时在一次提交中入账当前房间已确认产出、保存清房标记并进入REWARD_PENDING；下次步骤在候选状态中抽取卡片并提交为REWARD_OFFERED，之后才显示UI。在这两个提交之间退出，恢复后继续生成未生成的候选，不能再发清房奖励；已生成的候选必须复用。选择成功则在同一提交里标记奖励已领取、更新Build并进入MAP或结算阶段。没有三选一的房间也必须显式完成奖励阶段。

首版不承诺任意战斗帧恢复，也不承诺利用存档无法改变战斗结果。

存档保存稳定内容ID、值、布局与随机状态；不保存NodePath、Node引用、Godot Object instance_id、Signal、加载中的Resource或翻译后的显示名。

### 12.4 版本与磁盘可靠性

分别记录game_version、content_version、content_schema_version和save_version。存档升级采用顺序迁移，迁移后再次验证；改名/删除内容要提供ID映射或明确补偿。遇到更高版本存档，不允许直接覆盖。

先验证文件完整性，再判断版本兼容性。“完整但不兼容”与“损坏”是不同结果。最新完整槽不兼容时保留两槽并阻止覆盖，不能悄悄回退旧版本进度继续保存。content_version变化也要执行兼容检查；首版仅直接恢复相同内容版本的未完成Run，升级时需明确的迁移器或用户可理解的处理方案，不能仅因ID还存在就用新数值继续旧冒险。

每槽采用两个快照文件A/B，轮流写入非当前槽，按有效revision选择最新快照：

1. 同目录写临时文件，包含版本、revision、完整会话payload与校验摘要。
2. flush/close，重新读取并验证内容和摘要。
3. 替换非当前槽文件，检查文件操作结果；此前最新有效槽保留。
4. 发布保存成功。启动时选择最高有效revision，损坏则使用上一份有效档并告知恢复。

摘要用于损坏检测，不作为防作弊。替换与掉电表现必须在目标Windows环境验证，不宣称跨文件或断电绝对原子。仅在临时文件有效但最终替换未完成时，不能擅自将它当成已提交交易。

同一槽仅一个写入者，revision单调递增，防止异步旧快照晚完成后盖掉新进度。SettingsState单独保存，语言切换不必重写整个游戏存档。

## 13. 随机、输入、表现与排错

### 13.1 随机流

地图、战斗判定、掉落、三选一使用Run中的独立命名RNG流，由run seed与固定流ID通过项目明确的派生算法生成。顾客、订单候选使用Profile中的持久RNG流，由profile seed派生，首次冒险前或Run为空时也能正常工作。表现粒子另用非玩法随机。不用依赖实现细节的字符串hash作为长期协议。

保存RNG的seed和state为十进制字符串，避免64位整数被JSON浮点损坏；恢复先seed后state。候选顺序和需要排序的目标使用稳定规则。

复现承诺限定为同引擎、同算法、同内容版本与相同输入条件下的生成流程，不承诺跨版本或物理战斗的逐帧完全重放。[RandomNumberGenerator文档](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html)

### 13.2 输入与UI

InputAdapter将具体键位转换为move/aim/attack/dodge/skill/interaction意图。Actor不直接判断键盘字符。原说明书技能2和交互共用E，本架构默认交互改为F、技能保留Q/E，动作映射可重绑。

输入上下文至少有Gameplay、UI、Decorating；优先级与焦点由统一入口控制，避免点击三选一卡同时挥剑。未来手柄改变适配和UI焦点，不改变攻击执行器。

### 13.3 表现

音效、模型、镜头和粒子消费已确认结果。关掉特效或更换动画后，规则结果不变。攻击预警的实际几何来自技能解析结果，特效不能画出与命中范围不符的大小。

材质/动画资源保持实例状态隔离；模型及动作名称通过表现配置映射。概念图、AI生成模型需要清理、绑定和实机验收，不能让生成资产的命名随意成为玩法ID。

预留降低震屏、闪光与音量的设置；危险区同时依靠形状/节奏，不只依靠红绿颜色。首版记录同屏投射物、触发队列长度、AI更新次数和帧时间，再决定是否需要对象池。若使用池，复用时清理事件订阅、计时、已命中集合和ActorHandle代数。

### 13.4 可观察性

开发面板至少能看当前状态、敌人技能阶段、解析后属性、Build列表、触发链、当前房间/RNG、内容版本和保存revision。日志包含内容ID及run/cast/event/transaction关联ID，不能只有“发生错误”。

在关键边界提供最小验证场景：无HUD战斗房、无顾客模型的订单交易、纯Build触发测试。出错时能分辨内容、规则、表现还是存档问题。

## 14. 可照着实现的数据示例

以下展示字段组织与依赖关系；数字为占位示例，需要内容负责人后续调校。不是完整发布数据包，引用到的投射物、状态与表现定义必须补齐才可通过加载校验。

~~~json
{
  "schema_version": 1,
  "abilities": [
    {
      "id": "ability.sword_slash",
      "name_key": "ability.sword_slash.name",
      "tags": ["weapon_sword", "melee", "imbue_eligible"],
      "animation_action_id": "anim.sword_slash",
      "timing": {
        "windup_sec": 0.2,
        "active_sec": 0.1,
        "recovery_sec": 0.3,
        "commit_cue_id": "cue.slash_release"
      },
      "cooldown_sec": 0.6,
      "costs": [],
      "aim_policy": "lock_at_commit",
      "cancel_policy_id": "cancel.melee_standard",
      "hit_shape": {
        "kind": "sector",
        "radius_m": 1.6,
        "angle_deg": 100
      },
      "damage": {
        "origin_tag": "direct_melee",
        "components": [{ "type": "physical", "amount": 12 }],
        "hit_group_id": "hit.slash_primary"
      },
      "cues": [
        { "id": "cue.slash_release", "phase": "active", "offset_sec": 0.0 }
      ]
    }
  ]
}
~~~

~~~json
{
  "schema_version": 1,
  "upgrades": [
    {
      "id": "upgrade.sword_wave",
      "name_key": "upgrade.sword_wave.name",
      "description_key": "upgrade.sword_wave.description",
      "icon_id": "icon.sword_wave",
      "max_rank": 1,
      "offer_weight": 10,
      "required_capability_tags": ["weapon_sword"],
      "excluded_upgrade_ids": [],
      "ranks": [
        {
          "rank": 1,
          "trigger": {
            "event": "ability_cue_reached",
            "cue_id": "cue.slash_release",
            "required_ability_tags": ["weapon_sword"],
            "max_activations_per_cast": 1
          },
          "effects": [
            {
              "kind": "spawn_projectile",
              "projectile_id": "projectile.sword_wave",
              "count": 1,
              "spread_deg": 0,
              "inherit_source_snapshot": true
            }
          ]
        }
      ]
    }
  ]
}
~~~

projectile.sword_wave自己的定义必须明确伤害分量、速度、寿命、碰撞规则、imbue_eligible标签、secondary_projectile来源、分裂预算继承和表现ID；不能从名字推断规则。词条提示里的数量从当前rank解析，不再在UI复制一个常量。

### 14.1 最小公开类型清单

Definition：PlayerDef、EnemyDef、AbilityDef、UpgradeDef、StatusDef、ProjectileDef、ItemDef、RecipeDef、OrderDef、RoomDef、FurnitureDef。按实际里程碑建立，不为未实现玩法先写空壳。

运行类型：ActorHandle、ActorIntent、CastInstance、EffectContext、DamagePacket、DamageResult、BuildState、BuildProgram、OfferState、InventoryState、OrderInstance、LayoutState、RunState、ProfileState、SessionState、CommandResult。

公共方法在代码实现时给出精确的GDScript类型，文档与调用者同步。数量较少时不引入动态自动注册、反射扫描或依赖注入框架。

## 15. 后续AI协作与版本控制

一个文件同一时刻只有一个写入者。职责按目录与契约划分，不按某个永远存在的聊天编号划分。

| 工作负责人 | 可写范围 | 需协调的共享项 |
|---|---|---|
| 架构/整合 | app、contracts、session、content基础设施、schema、根工程配置 | 公开接口、存档版本、manifest协议 |
| 战斗 | combat及专属验证场景 | 新效果/策略需同步能力清单和schema |
| 地牢 | rogue及其场景 | 奖励与结算经过app接口 |
| 店铺 | shop、inventory约定范围 | 共享库存与持久交易契约 |
| 内容（可由原Agent 4承担） | 指派的data内容JSON和翻译JSON | 不擅改schema、不臆造未实现效果类型 |
| 美术/表现 | source_assets、assets、resources及指派的presentation | 攻击范围/受击几何、表现映射与资源ID |

project.godot、export_presets.cfg、Main场景、公共契约、schema和根文档指定整合者。需要新字段时先同步用途、默认策略、调用者和存档影响，再由相应所有者落地；允许代理直接沟通。

每项任务说明：目标、可写路径、依赖接口、内容需求、验收方法。不要依赖“某美术会话永远不关闭”；可复用脚本、版本化文件和文档才是交接依据。

开始代码实现时初始化Git并设置忽略项；.godot/、导出包、缓存和密钥不提交，Godot所需源文件/资源与应跟踪的UID文件保留。大模型/贴图按仓库实际需要使用Git LFS。锁定Godot稳定版本和所需依赖版本，升级引擎单独验收。

## 16. 实现顺序与验收

| 阶段 | 实现结果 | 必须证明 |
|---|---|---|
| M0 基础入口 | Main、内容加载校验、JSON→PO、设置、SaveStore | 缺配置报明确错误；切换中英；导出程序能找到内容和字体 |
| M1 最小闭环 | 一种敌人、一种掉落、自由下地牢、回店售卖 | 不接订单照常玩；退出重开库存与金币一致 |
| M2 核心承诺 | 多位订单候选、接0/1单、打造交付、小店/小院摆放 | 接单不阻塞自由出发；售卖/打造/交付不重复消费；布局保存恢复 |
| M3 构筑切片 | 三选一与少量攻击派生、投射物变化、状态/连锁组合，主题待选 | 行为改变成立；顺序、继承、触发限制可解释且无无限增长 |
| M4 动态品质 | 选定场景风格、主角动画、两类敌人策略、HUD与效果 | 前摇可读；配置可调；换模型/动画不改规则；参考机器帧率达目标 |
| M5 内容铺量 | 三幕原型、中期数量目标，之后扩充长期房间与Boss内容池 | 新数值变体主要改数据；同模板摆放可变；深入难度可调；新增机制只扩相应处理器和契约 |

战斗基础与端到端切片迭代推进，不必等全部架构工具完备才看到角色移动。资源数量小的时候就完成一次Windows导出验证。

高价值验收：

- schema/跨表ID/资源/翻译完整性；错误字段拼写必须被发现。
- 同挥砍多碰撞形状只伤一次；同帧多伤害只死亡一次。
- 受击取消、死亡、换房后旧技能不再产生伤害。
- 无敌、护盾、零伤害、持续伤害触发规则一致。
- 多种派生效果（可用附魔＋剑气＋分裂＋连锁作为样本）共享预算；移除/升级词条不会重复加成。
- 三选一卡不会因切语言/重开界面重新抽取，连点只选择一次。
- 订单为空的开局/地图/HUD/结算/存档全流程。
- 库存非负、钱款和物品变化符合用例；重复结算/交付不重复奖励。
- 存档损坏恢复、版本迁移、保存失败、旧异步请求失效。
- 中英文长文案、中文玩家名、重绑键位和弹窗输入焦点。
- 更换动画、关闭特效、复制敌人实例后逻辑结果和实例状态仍正确。

初期不做：Mod、运行时任意热更新、联网同步、跨版本精确回放、通用行为树编辑器、无限自由技能图、战斗任意帧保存、大型城镇模拟。接口仅为明确需求留空间，不先建设这些系统。

## 17. 开工前的最少未决项

这些影响内容或性能目标，不阻塞上述模块边界：

- 最低/推荐PC配置与目标帧率：建立首个动态场景时确认。
- 首批构筑样本、伤害/状态分类、叠层规则与主动技能槽数量：首批配置时明确，元素体系和最终流派后续讨论。
- 普通/紧急订单期限、死亡保留、局内货币换算：在M1/M2的run/economy规则文件中确定。
- 主角最终模型、骨架与可用动作：通过表现映射接入，不将概念图的命名写死进逻辑。

架构变更应同时更新本文与对应接口/校验。首次实现之后，以可运行代码、schema与验证场景共同约束后续工作；文档不替代实际验证。

## 18. 模块化房间、摆放变体与深入难度

### 18.1 内容边界

用户确认的是扩展方向与总体难度推进；以下为初始工程基线，曲线形状、分支深度规则和单局Boss节奏仍需试玩。三幕和中期数量不能成为数组长度、固定枚举或流程分支中的上限。

| 配置 | 职责与权威来源 |
|---|---|
| RunStructureDef | 路线规则、节点类型、阶段与Boss节点节奏，JSON；不写死三幕 |
| RoomTemplateDef | 布局ID、场景资源ID、门/区域引用、尺寸与兼容标签，JSON；实际门位、区域几何、导航和基础碰撞以场景为准，不重复抄坐标 |
| ThemeDef | 美术主题、套件及兼容模板引用，JSON；具体模型、材质与灯光参数由场景/Resource提供 |
| DecorationProfileDef | 道具池、权重、密度、间距、朝向规则及合法区域标签，JSON |
| EncounterDef | 敌人组合、波次、预算成本、出生条件、同时在场上限、精英规则，JSON |
| DifficultyCurveDef | 深度曲线、房型修正、数值倍率上下限与遭遇预算，JSON |
| BossPoolDef | Boss候选、出现条件、适配竞技场、重复限制与奖励关联，JSON |

以上Definition按实际需求逐步建立；已有最小RoomDef可逐步拆分，禁止同时维护两份相同规则。rogue拥有房间选择、生成和遭遇计划，content负责校验/解码，presentation实例化表现，combat执行敌人行为。规划器不直接修改存档，由app/session提交进入房间的状态。

一个主题可有多个布局；一个布局可有多个装饰方案与多个合法遭遇。主题替换需通过兼容标签校验，不保证任意美术套件可以无条件套到任意布局。首版使用人工布局模板和规则化摆放，不先建设任意几何生成器。

### 18.2 生成流程与恢复

1. 生成RunGraph：确定节点ID、房型、连接、进度深度和阶段候选；验证起终点连通与可选路线。
2. 按节点条件选择兼容布局与主题，解析门和摆放区域；Boss只选适配竞技场。
3. 计算并锁定DifficultyContext，按预算和空间约束选定遭遇；战斗区域、出口和安全出生区优先保留。
4. 放置影响玩法的障碍物并验证可达性；在其余合法区域添加纯视觉装饰。
5. 形成RoomPlan：节点/模板/主题ID、内容版本、实际物件变换、遭遇与出生计划、难度快照、随机流状态和奖励规则引用。场景按该方案实例化，禁止各节点在_ready中自行重新抽取玩法内容。
6. 沿用第12节的房间边界存档与会话提交机制，在允许玩家操作前保存进入方案。重开恢复该方案和入场状态，不重新洗牌；后续清房奖励仍按既有奖励事务提交。

布局、遭遇、玩法障碍与纯视觉装饰使用独立随机流；视觉变化不能消耗战斗/掉落随机序列。节点派生种子使用明确、版本化的稳定算法。种子加生成器/内容版本用于复现，当前房间的最终方案用于恢复；版本不兼容走迁移规则，不能假装同一seed能跨版本生成相同房间。未探索节点的详细方案可延迟到进入时生成。

关键门、互动点、玩家与怪物出生区保持必要净空；检查角色体型/导航尺寸、路径、攻击预警区与镜头遮挡。可阻挡或破坏的道具属于玩法对象，需要相应规则和存档策略。静态模板优先使用预验证导航；阻挡物只放在允许的区域，若后续引入运行时导航更新，须在开放操作前完成并验证。

随机摆放重试次数来自配置且有上限；失败时使用预验证的兼容回退方案并记录原因。没有合法方案则拒绝进入并报告内容错误，不静默生成堵路房间。已接订单的地图保证方式取决于订单设计；若承诺本局可完成，路线与素材池校验必须兑现该承诺。

### 18.3 深度如何影响难度

DifficultyContext至少记录node_id、depth_index、room_type、可选stage_id、曲线版本、遭遇预算和最终倍率。RunGraph定义进度深度，成功提交下一节点时推进；回访、失败恢复和重载不能重复累加。不同分支长度、休息节点是否推进深度在RunStructureDef明确，UI与生成器读取同一结果。

总体随深入提高压力，但允许曲线平台、休息房与Boss前缓冲。生物群系/场景主题不等于难度级别，同一主题可在浅层和深层使用。初版不按玩家当前Build强度、金币或即时表现偷偷调整难度；锁定本房难度后，局内升级不会让现存敌人同步变强。

建议优先增加敌人角色配合、波次安排、精英比例和招式组合，生命/伤害等使用有上限的曲线。预算选怪同时满足出场数量、同时存活数、远程/控制类比例和空间容量约束，不能为了花完预算无限堆便宜敌人。倍率只作用于明确列出的属性；攻击前摇、投射物速度等可读性参数不能跟随一个全局倍率一起压缩。

奖励表根据房型、深度与风险等级配置；经济模块消费掉落结果，不反向控制战斗。Boss数量、候选池与阶段节点分别配置，5–6种是长期内容池目标，不是每局必遇数量。

### 18.4 最小验证与扩展顺序

先用少量布局、一个主题、少量摆放变体与敌人组合验证：同模板能出现不同摆设；相同方案重载一致；深度增加会改变遭遇；门和出生点不被堵；装饰变化不改变怪物/掉落随机流。再增加三幕路线、中期内容量与长期地图/Boss池。

校验还应覆盖Boss与竞技场不匹配、无可用怪物组合、超出容量、预算不足、回退失败及生成中断后的恢复。这里只确立扩展边界，不预建未用到的复杂工具或一次制作所有主题。


## 19. 2026-09-26 初始战斗训练切片（已实现边界）

2026-09-26 三连段手感更新：按玩家面向，第一段左向右挥刀、第二段右向左挥刀、第三段向前刺击。前两段保留 160°/2.5 米扇形，第三段使用前向 2.8 米、宽 1.0 米的矩形刺击区域；命中形状与尺寸唯一来源为战斗 JSON。`combat_prototype` schema_version 升为2，所有能力必填 `hit_shape`（sector/thrust）和 `thrust_width_m`；sector 要求 angle_deg>0、thrust_width_m=0，thrust 要求 angle_deg=0、thrust_width_m>0。radius_m 对刺击表示向前长度。角色中心仍为受击点，后方与侧方不受刺击伤害。

默认刀光仍为金色破碎流光，已选美术场景仍可替换。剑尖最大美术距离独立存于 `training_style.tres.weapon_tip_radius_by_ability`（1.9/1.9/2.2 米），三段动作由 `attack_motions` 显式映射的 Resource 读取前摇/生效/后摇进度，控制挥动方向、收剑、刺出与回收。该映射与模型姿态不能用于判定；尚未接入正式骨骼挥剑动画。

真实命中后，MeleeResolver 发出局部 `confirmed_hit(source,target,cast_id,ability_id,applied_damage)`；只在实际扣血后发出，沿用单次命中去重。训练app消费玩家命中事实触发轻微镜头震动，空挥、重复接触及无敌拒绝不触发。震动强度/时长来自表现 Resource，屏幕平面偏移不改相机旋转或玩家瞄准计算，不消耗玩法随机流；暂停冻结，结束归零，同时多目标命中不无限叠加。

新增 `elemental_slashes_v001` 的火焰、闪电、雷霆、冰霜四套 Blender 实作烘焙刀光，接入训练面板。名称表示美术主题，不引入元素枚举或元素伤害机制。四套新刀光最外网格半径为 2.208/2.208/2.508 米；扩大后的中心受击判定保留约 0.29 米接触余量。飘散粒子、屏幕泛光及移动后残留的旧尾迹不产生持续伤害；当前仍为角色中心受击规则。换刀光不会动态修改半径。资源、测量与验证记录见 `source_assets/vfx/elemental_slashes_v001/README.md`。

后续火焰表现迭代 `fire_slash_v002`：独立选项 `fire_slash_v002`／「焰浪 · 火焰重斩」，宽火焰弧面、快速退场的热刃、Blender 16 帧火舌粒子、长短火星、淡烟和短促局部照明。配置仍为表现 `.tscn/.tres`；多个发射器、材质时钟和灯光包络都服从同一 `set_time_running` 接口。ActorView 在死亡/隐藏提前返回前同步此接口，死亡后的尾效也能正确暂停。所有粒子只在能力 active 阶段新发射，退场不产生伤害。此选项不替换已认可的默认刀光、不改变攻击半径/角度/时序，也不实现燃烧状态、命中停顿或镜头震动。源工程、来源限制和实机记录见 `source_assets/vfx/fire_slash_v002/README.md`。

刀光场景可选实现 `sample_current_pose()` 与 `finish_at_current_pose()`；前者在 ActorView 完成剑姿态更新后采样，后者在取消/死亡回到待机前结束当前拖尾，避免生成回拉弧线。接口只处理表现；暂停冻结尾迹、粒子及材质时间。纹理烘焙不等于把 Blender Geometry Nodes 直接导入引擎，运行时实现与验证入口见 `source_assets/vfx/trail_fxs_v2/godot_sword_v001/README.md`。

训练HUD提供刀光测试面板：选项ID、翻译key与PackedScene引用集中在 `presentation/combat/effect_picker/palette.tres`。面板只发出本地选择信号，由训练app验证ID并调用玩家ActorView切换表现；不得改变施放、生命、伤害、角度或持久状态。默认项与 `training_style.weapon_effect_scene` 对应，重新训练恢复默认；这不是构筑解锁或技能选择系统。

- `combat_prototype_file` 加入统一 manifest；schema/构建校验通过后，由训练 Bootstrap 的 CombatLoader 解码只读 CombatCatalog，注入角色与遭遇。ShopPreviewRegistry 继续仅发布店铺预览目录；训练场独立加载战斗目录，不由店铺服务定位战斗配置。
- 这是无持久状态的开发训练入口，F6/店铺训练按钮进入；暂时以整场景切换隔离训练和店铺预览。正式冒险接入 SessionCoordinator 时再改为持久 Main 下 World 切换，不能将当前训练入口当成已实现 start_run/finish_run。
- 当前能力支持平面近战扇形和前向矩形刺击，角色中心为受击点，一次施放一个命中组；攻击开始时锁定方向并开始冷却，无资源成本。取消不退冷却。普通攻击/受击/闪避不产生库存、金币或掉落。
- 玩家三段攻击由定义中的 attack_ids 顺序执行，忙碌期间缓存一次攻击意图，超出 combo_reset_sec 从首段开始。三段的 movement_speed_multiplier 当前均为1，允许全程移动。闪避消耗次数，按 recharge_sec 逐次恢复；无敌窗口不超过闪避持续时间。
- 第二段命中施加击退；AbilityDef 增加 knockback_speed_mps/knockback_duration_sec，未使用击退的能力显式填0。两个字段必须同时为0或同时为正。只有真实扣血才申请击退，死亡不再施加；Motor以线性衰减冲量覆盖自主移动并进行碰撞检测，重复冲量替换上一冲量，不累加失控。重卫抗硬直不等于免疫击退。
- 近战敌人按独立决策间隔追击；AbilityRunner 唯一拥有前摇/生效/后摇时间。当前地形为无内部障碍的平面训练场，不宣称实现导航绕障或视线射击。
- 判定顺序固定玩家在前；死亡立即取消施放，已死单位不反击。同挥砍同目标只尝试一次伤害，包括无敌拒绝的接触。当前未实现护盾、抗性、多段和多种伤害分量；派生剑气/连锁/分裂见第20节。
- AbilityRunner 的 committed/cue_reached 已接入第20节构筑运行；三选一、剑气、分裂、连锁及根预算已实现。元素体系和持续状态尚未实现；新机制需补充上下文、预算与校验，禁止信号递归直接伤害。
- 每个角色的模型、碰撞体、动作名称和朝向偏移来自独立 ActorPresentation Resource。预警几何取自 AbilityDef；模型动画不决定伤害。所有战斗调参仍在 JSON。
- 刀光以独立 PackedScene 挂在剑身中部，ActorView.set_weapon_effect 接受后续构筑表现选择。场景必须实现 set_active(bool)/set_time_running(bool)，可选实现 configure_blade(length)，由ActorView注入表现配置中的实际剑长；局部正Z为剑根、负Z为剑尖。当前默认刀光已改为 golden_trail_v001 金色破碎流光，旧候选演示保留；仍未接入Build选择。刀光长度和剑尖延伸只影响表现，不能增加命中范围。HitFeedback消费已提交伤害，临时替换每个网格材质为白色发光+红色外轮廓、发射粒子，并恢复各实例原材质。血条实际比例立即更新，白色残留延迟平滑收敛；致死时规则与碰撞立即结束，表现尾效继续播放。特效/白条时间来自表现Resource，不能延迟伤害或死亡规则。
- 详见 `docs/COMBAT_PROTOTYPE.md`。当前训练切片不代表 M1 端到端持久闭环已完成。

## 20. 2026-09-26 三选一与 Build 训练切片（已实现边界）

- 内容版本 `prototype.6-builds`；新增 `build_prototype_file` manifest 字段，指向 `data/builds/prototype.json`（独立 schema_version=1），现有战斗 schema_version=2 保持。
- 已实现五类机制：攻击倍率、移动倍率、普攻剑气、命中连锁、剑气分裂；5项测试升级共14级，用于验证组合，正式主题和技能名单仍待用户决定。
- `content/builds`负责严格校验/只读目录，`rogue/build_offer_sampler`负责权重无放回和等级/前置/标签/互斥过滤，`combat/builds`负责确定性解析、施放快照及预算队列；`app/session/training_build_session`负责隔离候选提交与RNG事务，`app/training_builds`组装训练流程。面板只发本地选择请求。
- 开场及非最终波次清场奖励三选一；训练调试按钮允许继续选。选项不足允许少于3张，全部满级显示提示并继续战斗。候选不因重开/切语言重抽；重复/旧选择拒绝。选择期间禁止Gameplay输入并冻结规则/子弹/特效时间。
- 每次施放快照共享根预算，队列/每步请求/活跃投射物/单根投射物/代数都有JSON上限。近战和剑气可触发连锁，每个升级每次施放最多触发一次；连锁不能再触发连锁/分裂，子弹分裂继承父快照、剩余寿命及排除目标。零寿命子弹不生效，清房代数使旧请求失效。
- 本轮仍为临时训练：提交器为内存适配器，失败通过注入回调测试，重试/回店丢弃Build；未接正式Run存档、掉落、永久解锁、状态/主动槽位/通用联动解析。第12节的正式冒险恢复协议仍是后续接入要求，不把当前临时快照当磁盘恢复。
- 表现独立使用 `presentation/builds` Resource；沿用共享字体。右侧既有刀光测试器继续只换美术，不自动授予对应构筑。
- 用户操作、扩展方法和实际验收见 `docs/BUILD_SYSTEM.md`；精确API见 `docs/BUILD_IMPLEMENTATION_CONTRACT.md`。

## 21. 2026-09-27 首个美术战斗房间接入

- 店铺训练进入通用宿主 `app/combat_training.tscn`，当前宿主注入 `forest_courtyard.v001` 的RoomPresentation。它只是当前测试模板，不是正式冒险必定进入的第一关；初次接入时未启用随机物件；同日物件种子与摆放切片现已接入，见第23节，房间池仍未启用。
- `combat_training.gd` 不包含庭院ID或模型路径。RoomPresentation引用PackedScene并提供场景级镜头/抗锯齿参数；房间通过 `player_spawn()` / `enemy_spawns()` 返回世界坐标，应用层注入战斗。既有简易训练场保留为独立回归夹具。
- 模型、灯光、材质、固定碰撞及出生点在表现资源/场景中；JSON继续拥有战斗与构筑数值。未来房间池、权重、深度和随机摆放属于独立规则目录，由RoomPlan选择并注入，不能在美术房间_ready中自行抽随机数。
- 当前主庭院为封闭测试区，出口/林间道路未接房间切换；原美术摆设固定，不自动成为可破坏、可拾取或随机对象。运行时物件容器现由第23节的随机物件模块填充。
- 接入、渲染近似边界和真实验证见 `docs/FOREST_COURTYARD_INTEGRATION.md`。Cycles离线光照和实时渲染存在差异，不将模型导入成功等同于逐像素还原。

### 21.1 同日植被与加载补充

- 用户授权树冠/外围背景低模与叶片贴图转换，主体建筑保持不变。高模源blend与旧GLB在source_assets保留，运行GLB只替换明确列出的植被，安装前验证非目标几何/UV/材质/变换一致。见 `docs/FOREST_FOLIAGE_OPTIMIZATION.md`。
- 训练场过渡由临时 `app/scene_transition.gd` 协调后台资源请求、暂停/绘制状态恢复和场景提交；界面在 `presentation/loading`。进度来自引擎资源读取，场景准备单列阶段，未来动画只替换表现层。没有增加全局服务定位器、正式冒险持久状态或房间池。
- 正式Main/RoomSlot方案仍按第2节；当前训练重开仍创建新场景，复用引擎缓存，不宣称已实现“只重置角色不重建房间”。

## 22. 2026-09-27 ESC 设置菜单切片

- 店铺与战斗通过场景拥有的 app/pause_menu 组装同一 presentation/settings 界面，打开时暂停 SceneTree，关闭恢复原暂停状态；不引入全局服务或持久 Session。
- 语言、Master 总音量、VSync 和帧率上限即时作用于引擎；设置当前不写磁盘。源 art v002 的样例百分比不能成为默认值，界面读取真实引擎状态。
- 正式存读档、音频分类、画质、显示模式安全确认、重绑和灵敏度尚未实现，只显示禁用占位。底部保存／读取进入同一说明页，退出有未保存进度确认。
- 所有翻译仍经 JSON→PO，共用字体 Resource；视觉资源和裁切在 settings_skin.tres。接入边界、验证与后续事项见 docs/SETTINGS_UI.md。


## 23. 2026-09-27 房间随机物件最小切片

- `item2.blend` 的木桶/板条箱为 1 HP 可破坏物；石质残墙为不可破坏障碍；`chest1`、`chest2`、`forest_bag1` 为 F 搜刮容器。箱子长短/堆叠通过共享模型组合，整组为一个实例。
- `content/rooms` 校验 JSON 并发布只读目录；`rogue/rooms/prop_planner` 生成带种子、模板/内容/生成版本、实际摆放与预滚奖励的计划；`app/training_room_props` 注入表现和可选寻路/命中接口。数值、模型与状态分开。
- 数量为目标区间；出生点留空，碰撞膨胀后的网格连通、搜刮站位通过检查才接受。重试上限后使用已校验的稀疏计划，不强放障碍。当前只支持模板明确给出的平坦内庭，不宣称支持任意固定地形自动导航。
- 独立 SHA256 派生的 props / 每实例 loot 流；显示/粒子/Build 不消耗这些流。计划值可序列化，但尚未接入正式 Profile/Run 存档。训练重开直接复用计划并重置临时状态，新布局按钮另取种子。
- 搜刮和破坏状态经 `app/session/training_loot_session` 候选提交，重复请求幂等，失败不改权威数据。当前提交适配器只接受内存训练状态，不增改永久库存、金币或存档。
- 箱子从独立近战目标列表受击，不参与敌人计数或 Build 派生触发；剑气暂在实体处停止。清场后可继续探索和搜刮。模型/参数入口、已验收和剩余边界见 `docs/ROOM_PROPS_PROTOTYPE.md`。


### 23.1 不规则散布 v002（已被 v003 组合取代）

全庭院开放连续坐标和连续朝向；中央目标2–3件，混合散点和有距离限制的聚簇候选，不再按导航网格吸附。玩法参数来自room props JSON，中央区域来自模板Resource。旋转外包范围参与碰撞/出生点/可达性检查。schema与生成版本升级为2，旧计划拒绝跨版本复用。现有商店家具网格规则不受影响；参考与验证见 ROOM_PROPS_PROTOTYPE.md 的v002章节。

### 23.2 美术组合评审阶段

用户反馈v002的散点/聚簇仍缺少美感，确认先用现有素材手工制作三个小景与两套完整布局。目标是物件依附墙柱、组内主次高低、组间留白；不继续将中央数量配额和任意朝向当作美术目标。本轮固定组合只在独立表现场景及截图工具中试摆，未替换现有生成器或Release，未实现组合碰撞/交互。待评审后再将获认可的组合接入种子选择、落点约束与玩法验证。交付见 `docs/ROOM_COMPOSITION_REVIEW.md`。

### 23.3 四种可复用小景 v003

用户确认长墙木桶、残墙宝箱、断柱木箱、墙角岩石四种参考。共享 Composition Resource 拥有成员稳定 ID、模型 ID、局部位姿和纯装饰场景；房间 PlacementSurface 拥有独立落点与允许朝向。JSON groups 改为选择组合 ID，数量等玩法参数仍只在 JSON。旧散点/中央配额参数删除，生成与内容版本提升为 3，旧计划拒绝静默迁移。

计划保存组合实际落点/朝向及每个实体成员的实际位姿、预滚奖励。按整个组合接受/拒绝，碰撞和可达性按成员并集检查；装饰不占导航、不消耗玩法随机流。宝箱、木桶、木箱各自独立交互/破坏，墙柱岩石不可破坏。复用到其他房间只需注入同一组合目录和该房间的安全落点，不能将庭院 ID 写入战斗逻辑。训练临时事务边界不变。

### 23.4 Blender 组合美术返修 v004

用户已认可 `source_assets/environments/dungeon/room_compositions/v004/blender/forest_compositions_review_v004.blend` 的四组模型，要求替换 Godot 旧版美术。该文件是美术母版；派生 GLB 位于 `game/assets/environments/room_compositions_v004/`，程序材质烘焙为贴图，不烘焙评审灯光。拍摄地板、镜头、灯光不进入组合。完整 Collection 与稳定根对象保留在母版。

静态墙柱、岩石和花草合并为每组表现模型；分件物理代理使用导出测量的 bounds 与局部原点，不重复绘制静态结构。宝箱、木桶、木箱单独导出并由各自 RoomProp 拥有，因此搜刮、破坏及碰撞移除仍独立。新组合移除旧版额外背包，内容版本为 `room-presets.4`，schema/generation 仍为 3；旧内容计划明确拒绝复用。不要恢复 v003 花草场景作为降级默认值。实际验收记录见 `docs/ROOM_PRESETS.md`。
