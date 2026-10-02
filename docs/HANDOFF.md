# 当前项目交接

文档更新：2026-10-01（命中爆炸与控制状态最小切片）；Build专项结果见其API，其它模块沿用2026-09-28状态，不代表本轮全量复验。先读 [核心契约](../PROJECT_CONTRACT.md)，再按 [文档索引](README.md) 选择模块。此处只记录状态与索引，不要求读取归档和所有模块。

## 运行入口

- 工程 `game/project.godot`；主场景 `game/app/main.tscn`。店铺 F6 进入训练，现仍为整场景切换。
- 引擎：`E:/GoDot/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe`；现用 Forward+，本机 RTX 4060 Laptop。尚无正式最低配置/完整战斗性能验收。
- 内容入口 `game/data/manifest.json`，当前 `prototype.7-enemy-roles`；修改JSON后重新启动。构建检查见 [VALIDATION](VALIDATION.md)。
- 只在用户明确要求时生成 Release。已有旧包不含全部最新敌人及修复，不作为当前项目试玩入口。

## 已实现与阅读入口

| 模块 | 当前能力 |
|---|---|
| [店铺](SHOP_PREVIEW.md) | v006场景、v008小熊猫、柜台后方通路、9件原家具F交互、跟随/滚轮镜头 |
| [家具](SHOP_DECORATING.md) | R装修，4种新增家具，网格/旋转/移动/移除/通路检查；当前场景临时布局 |
| [UI](FOLIAGE_UI.md) | HUD、只读样例背包、委托预览、统一字体；ESC设置部分选项即时生效 |
| [战斗](COMBAT_PROTOTYPE.md) | 可移动三连击、闪避、第二段击退、命中轻震、白闪红边/粒子/延迟血条、可换刀光 |
| [Build](BUILD_SYSTEM.md) | 真三选一、9项测试升级；schema v3剑气/箭共用分裂，新增[爆炸/减速/冻结](COMBAT_MECHANISMS.md)及强化候选资格，预算与临时提交 |
| [敌人/遭遇](ENEMY_ROLES_AND_ENCOUNTERS.md) | 近战/重型/弩手/矛兵/旗手，12种预算阵容、两波；敌人彼此无实体碰撞 |
| [房间](ROOM_PROPS_PROTOTYPE.md) | 一个庭院模板内的种子摆放、搜刮、1HP破坏、绕障；[四组合v004](ROOM_PRESETS.md) 为当前认可美术 |
| [加载/植被](FOREST_FOLIAGE_OPTIMIZATION.md) | 树冠/外围低模、后台资源读取、真实进度条；实例化仍在主线程 |

## 尚未实现

- 正式 Profile/Run 存档、随机房间模板池/路线、跨房间结算、永久经济、订单实际接取/交付、上架售卖。
- 敌人掉落已有配置、入房预滚与死亡事实；没有地面拾取或永久库存入账。
- 原始店铺固定家具不可编辑；新增布局离开场景丢弃。背包/订单样例不是玩家资产。
- 正式骨骼攻击动画、最终敌人模型、主动技能槽/完整状态系统仍待设计接入；元素主题未定。
- [能力适配](contracts/BUILD_CAPABILITIES.md)已完成直线投射物最小切片；完整武器/换装事务、复杂适配器及UI受益攻击列表尚未实现。最新入口 `启动机制测试.cmd` / `game/app/mechanism_slice.tscn`；T发箭。

## 当前待处理

优先保留 [KNOWN_ISSUES](KNOWN_ISSUES.md) 的 **PERF-001：混合字符深度应用后持续低帧**。用户报告重新应用纯数字恢复；诊断未复现，未改代码，不得标记已解决。退出资源警告、输入焦点隔离缺口也在该页。

已完成冲锋贴障碍时序/停止碰撞修复及敌人互不碰撞，具体语义与历史验证见敌人文档。后续修改按范围重新验证，不把历史通过视作当前全量测试通过。
