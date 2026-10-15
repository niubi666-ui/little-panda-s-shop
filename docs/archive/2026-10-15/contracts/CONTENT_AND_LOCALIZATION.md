# 内容与本地化详细约定

2026-09-28 从原架构契约拆出。仅在修改本领域接口/规则时读取。

这里规定内容格式与扩展要求；当前字段以 `game/data/schemas/` 和对应 Loader 为准。文中的结构样例不是可直接投入运行的配置。实现状态见 [交接](../HANDOFF.md)，验证入口见 [验证索引](../VALIDATION.md)。

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
