# 开发交接 · 当前状态

更新：2026-09-27。此文件保留当前入口和有效状态；历史逐轮重复说明、早期空工程限制及过期分工已清理。

## 开发入口

- 先读 `PROJECT_CONTRACT.md`，玩法与美术分别见根目录玩法说明书、美术方向基准。
- Godot工程：`game/`；入口：`game/app/main.tscn`。
- 本机引擎：`E:/GoDot/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe`。当前日志为Vulkan/Forward+、RTX 4060 Laptop；尚无正式性能验收。
- 内容入口 `game/data/manifest.json`；构建/翻译工具 `tools/content/build_shop_preview_content.py`。JSON人工源，PO生成文件。
- Git已初始化，尚未提交；`builds/`和私有环境是开发输出，不作为源资产。

## 已有功能与维护文档

| 范围 | 当前能力 | 文档 |
|---|---|---|
| 店铺 | v006美术、v008小熊猫、可通行柜台后方、9件家具F交互、沿墙杂物、跟随/滚轮镜头 | [SHOP_PREVIEW.md](SHOP_PREVIEW.md) |
| UI | 店铺HUD、B背包、J委托、R装修目录；示例目录无真实库存交易 | [FOLIAGE_UI.md](FOLIAGE_UI.md) |
| ESC设置 | v002美术，店铺／战斗共用；语言、主音量、VSync、帧率生效，其余明确占位；设置暂不持久化 | [SETTINGS_UI.md](SETTINGS_UI.md) |
| 委托板 | 分层PNG、肖像、鼠标/键盘选0或1张、两种按钮预览反馈、纯文字关闭按钮 | [COMMISSION_BOARD_UI.md](COMMISSION_BOARD_UI.md) |
| 字体 | 共用Noto Serif SC与字号/字重Resource，主菜单与弹窗统一注入 | [UI_FONTS.md](UI_FONTS.md) |
| 家具摆放 | R进入、4种原型家具、吸附/旋转/可达性验证；临时布局 | [SHOP_DECORATING.md](SHOP_DECORATING.md) |
| Build构筑 | 真实三选一、5类测试升级、前置与叠级、剑气/连锁/分裂 | [BUILD_SYSTEM.md](BUILD_SYSTEM.md) |
| 首个地牢房间 | 森林庭院原模型、日照/薄雾/湿地、固定碰撞、可替换房间资源；物件随机切片已接入 | [FOREST_COURTYARD_INTEGRATION.md](FOREST_COURTYARD_INTEGRATION.md) |
| 植被与加载 | 树冠/外围低模，主体几何保持；后台资源读取、真实进度条与失败返回 | [FOREST_FOLIAGE_OPTIMIZATION.md](FOREST_FOLIAGE_OPTIMIZATION.md) |
| 战斗训练 | F6入口、移动三连击、闪避、五种敌人/两波、清场/失败/重试/回店 | [COMBAT_PROTOTYPE.md](COMBAT_PROTOTYPE.md) |
| 敌人分工与遭遇 | 弩手、冲锋矛兵、光环旗手；12种合法组合按深度预算抽取；预滚掉落配置与死亡事实 | [ENEMY_ROLES_AND_ENCOUNTERS.md](ENEMY_ROLES_AND_ENCOUNTERS.md) |

## 最新敌人原型（2026-09-27）

- 敌人彼此取消实体碰撞，使用独立敌人层；仍与玩家、世界障碍碰撞。已验证冲锋穿过五类友军后命中玩家、玩家仍被敌人体积阻挡及庭院场景回归；日志 `builds/enemy_collision_regression.log`、`builds/enemy_collision_training.log`。

- 已修复冲锋贴柱/矮墙后原地循环蓄力：开冲首帧发出位移，冲锋接触即停，胶囊通道受阻先绕路。真实庭院 10 个障碍接近/脱离案例通过，详见敌人文档；没有重新导出 Release。

- 从当前 Godot 工程启动，店铺 F6 进入训练；左侧训练深度默认 6，可应用深度并重抽遭遇。重新训练保留阵容、房间物件与预滚掉落。
- 行为参数在 `game/data/enemies/roles.json`，组合/预算在 `game/data/rooms/encounters.json`，概率/数量在 `game/data/loot/enemies.json`。内容先校验再注入只读目录；敌人逻辑、遭遇抽取、模型表现分开维护。
- 已验证 360 个深度/种子计划及真实庭院中的预警、投射物、冲锋、光环、暂停、重开、死亡清理、双语；原战斗、Build 和房间物件回归通过。走位与击杀顺序的主观手感仍需试玩。
- 掉落目前只有锁定计划与局部死亡事实，尚未实现落地物品、拾取或永久背包入账。
- 本轮没有生成 Release；现有旧导出包不包含本轮功能。之后仅在用户明确要求时导出。

## 最新战斗手感

- 普攻全程可移动；第二段对实际受伤的存活敌人施加受碰撞约束的击退。规则数值在 `game/data/combat/prototype.json`。
- 三连段现在为左→右、右→左、向前刺击；前两段160°扇形，第三段2.8×1.0米前向矩形。动作Resource在 `presentation/combat/attack_motions/`；schema_version=2，旧三段同向扇形约定已替换。
- 玩家真实命中触发0.12秒轻微镜头震动，参数在 `presentation/combat/hit_camera_shake_style.tres`；空挥不震，不改变鼠标瞄准。验收与日志见 `docs/COMBAT_PROTOTYPE.md`。
- 剑身中部刀光粒子与短轨迹有独立场景替换接口，供未来Build表现选择。
- 敌人全身白闪、红色描边、飞散粒子；独立血条包含白色延迟扣血段。表现配置与玩法数值分离。
- 模型和碰撞体按角色独立配置；动画仅idle/run，挥剑仍是临时表现。

## 实现边界

- 店铺尚无实际陈列/交易；已实现临时家具摆放，原始固定家具尚不可编辑；订单没有真实接取。示例UI目录不是玩家库存。
- 训练已支持临时Build与种子物件/搜刮战利品；没有正式冒险存档或回店经济结算。重新训练保留布局，清空临时搜刮/破坏状态。
- 原始Blender资产未覆盖。当前场景/特效需继续试玩调校，不能以参考图代替实机质量验收。
- Windows EXE/PCK已有独立试玩版本；最新房间物件美术版在 `builds/windows-release-room-presets-v004/`。改动后按任务范围重跑规则/场景验证，既往通过不代替本次检查。

## 房间随机物件（最新）

种子摆放、1 HP木桶/板条箱、不可破坏残墙、三种 F 搜刮容器、临时战利品、绕障；规则和扩展入口见 [ROOM_PROPS_PROTOTYPE.md](ROOM_PROPS_PROTOTYPE.md)。

房间物件 v003：四种可复用组合（长墙木桶、残墙宝箱、断柱木箱、墙角岩石）已经接入运行时随机、成员碰撞、破坏与搜刮。组内手工摆放、组间随机选落点/朝向；当前庭院目标3组，保留通道及内部落点。原v002散点/中央配额参数已删除，版本升为3。扩展与最新实机图见 [ROOM_PRESETS.md](ROOM_PRESETS.md)。岩石为可替换占位；源item2未改，主体建筑和战斗代码未改。


## 组合美术 v004（用户已批准，当前 Godot 接入）

用户已批准 `source_assets/environments/dungeon/room_compositions/v004/blender/forest_compositions_review_v004.blend` 的四组模型。Godot 当前组合引用 `game/assets/environments/room_compositions_v004/`，旧 v003 花草不再用于随机组合。保留花盆、苔藓岩石、完整地被和藤蔓，取消长墙旧背包。静态结构/植物合并，独立物理代理按实测 bounds 建立；宝箱、木桶、木箱单独拥有可交互表现。母版与 item2 均未覆盖，战斗逻辑没有改动。

导出和发布脚本在该 v004 目录的 `scripts/`；报告记录源 SHA256、局部位置与尺寸。必须统一网格 UV 层名称再合并，避免有纹理的断柱/叶片错误采样纯色；导出校验检查纹理 UV 非常量。内容版本为 `room-presets.4`，schema/generation=3。实际截图和本轮验收见 [ROOM_PRESETS.md](ROOM_PRESETS.md)。
