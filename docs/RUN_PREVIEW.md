# 短分支路线测试：当前实现

2026-10-02。独立内存 Run 切片：选合法节点 → 新建战斗房 → 清场回图 → 继续选路；跨房保留生命和测试 Build。正式路线与奖励方向见[房间生成契约](contracts/ROOM_GENERATION.md)，构筑规则见[Build API](BUILD_IMPLEMENTATION_CONTRACT.md)。

## 1. 运行与范围

双击根目录的[启动路线测试.cmd](../启动路线测试.cmd)，或在 Godot 运行 [run_preview.tscn](../game/app/run_preview.tscn)。地图从下向上，点击亮起的可达节点；清场后点返回地图，死亡或终点清场后可重新开始。店铺 F6 仍进入原训练入口。

- 当前固定图为 **5 层、7 节点，两处分叉汇合，每条路径经过 5 个战斗房间**。每次重开生成新的 Run seed，拓扑不变；遭遇由 seed、节点 ID 和内容规则决定。
- 房内顶部显示成功进入的房间编号、节点类型和生命。WASD 移动，左键普攻、右键特殊技、Shift 闪避，滚轮缩放，Esc 暂停/设置，L 中英文切换。
- 清场后（含终点房间）仍可移动和施放技能，玩家当前动作与飞行投射物继续推进；清场信号只发一次。`run_room._encounter_complete` 标记遭遇结束，`stopped` 表示死亡或退出，不再用清场来停用房间。返回地图/重开时 `shutdown()` 统一清理，清场后的空放不重复提交Session。
- 开场由 `starter_build_preset` 编译并注入一次测试 Build，当前为 `left_blast_right_freeze`。后续房间沿用相同状态及程序；本入口没有清场三选一或局内改 Build 操作。
- `elite` 目前用于节点标识，遭遇仍按配置深度/预算生成；`terminal` 是结束本次测试的战斗节点，使用已有敌人，尚未接入正式 Boss。

## 2. 配置与职责

| 入口 | 权威内容 |
|---|---|
| [manifest.json](../game/data/manifest.json) → `run_route_file` | 路线 JSON 入口 |
| [route.json](../game/data/run/route.json)、[schema](../game/data/schemas/run_route.schema.json) | 节点、连接、深度、模板 ID、初始测试预设和空奖励声明 |
| [run_loader.gd](../game/content/run/run_loader.gd) | 严格 JSON、字段/引用/图结构校验，全部成功后发布嵌套只读定义 |
| [run_planner.gd](../game/rogue/run/run_planner.gd) | 按节点深度、模板容量生成并锁定合法遭遇，不修改 Session RNG |
| [run_session.gd](../game/app/session/run_session.gd) | 合法下一节点、入房事务、清场/死亡及跨房权威状态 |
| [run_preview.gd](../game/app/run_preview.gd)、[run_room.gd](../game/app/run_room.gd) | 持久入口＋可替换 RoomSlot；隔离建房、验证、提交后激活战斗 |
| [run_map_view.gd](../game/presentation/run/run_map_view.gd)、[room_progress_hud.gd](../game/presentation/run/room_progress_hud.gd) | 地图/房内 UI，发出选路、返回和重开意图；样式来自 [Resource](../game/presentation/run/run_map_style.tres) |

路线 schema v1：顶层为 `schema_version/id/content_version/start_node_ids/nodes/edges/starter_build_preset/rewards`；边为 `{from,to}`。所有节点必须引用已验证的模板与奖励。当前 **`rewards: [{id: "none", kind: "none"}]` 是唯一合法奖励定义，节点 `reward_id` 必须为 `none`**；它仅明确无奖励，未实现奖励结算。

以下字段不能互相替代：

| 字段 | 含义 |
|---|---|
| `node.id` | 稳定节点身份；分支/计划/回调关联用 ID |
| `node.layer / column` | 地图层级和显示列；当前连接只跨相邻层 |
| `node.depth` | 遭遇预算与难度输入；不从编号或主题推导 |
| `room_count` | 本次 Run 成功入房次数；只有 `commit_enter` 成功才加一 |
| `ticket.room_ordinal` | 待进入房间的预期编号；准备/加载失败不消耗它 |

Planner API 为 `configure(enemy_catalog, template_capacities)`、`plan(node, seed) -> Dictionary`。计划包含 `node_id/template_id/depth/kind/reward_id/encounter_plan`。遭遇 seed 由 Run seed、节点 ID 和 `run_room.v1` 派生，重复准备不重抽；复现承诺限定同引擎、算法及内容版本。该入口还没有布局、装饰或奖励随机流。

## 3. RunSession API 与提交边界

`configure(route, seed: int, hp: float, build_state, program, plan_builder: Callable, commit: Callable) -> bool`：注入已校验路线、已编译 Build、计划函数和提交适配器。入口阶段为 `map`；Session 不读文件、不自行抽随机数。`plan_builder(node, seed)` 返回合法非空计划；`commit(candidate)` 返回 `OK` 才发布候选。当前 app 适配器仅复制到内存，未接磁盘。

| API | 当前语义 |
|---|---|
| `snapshot()` | 脱离权威状态的嵌套只读快照 |
| `map_snapshot()` | `nodes[{id,layer,column,kind,state}]`、`edges`、`current_node_id/room_count/phase/available_node_ids`；节点状态为 `current/completed/available/locked`，当前节点优先 |
| `prepare_enter(node_id)` | 验证可达，返回 `{ok,error_key,ticket}`；ticket 含 `id/run_id/base_revision/node_id/room_ordinal/plan`，不发布入房状态 |
| `commit_enter(ticket_id)` | 重查票据与合法邻接，提交成功才进入 `combat`、增加编号；`active_entry_id = ticket.id` |
| `cancel_enter(ticket_id)` | 丢弃该待提交票据，不改变已发布 Run 状态 |
| `complete_room(entry_id, hp)` | 活跃房间清场写入生命检查点，普通节点进入 `cleared`，终点进入 `completed`；HP 为零转死亡 |
| `return_to_map(entry_id)` | `cleared → map`，开放当前节点未访问的直接后继 |
| `defeat(entry_id)` | 活跃房间进入 `defeated`；死亡优先于该房间先到的清场回调 |

除准备成功额外返回 ticket 外，操作结果为 `{ok,error_key,changed}`；失败原因是翻译 key。重复成功入房/清场/返回/死亡不重复推进；旧票据、旧房回调、重入和重开前的代数被拒绝。重复清场不会再次覆盖生命。提交失败保留权威状态；Session 保留待提交票据供重试，app 的加载失败流程则主动取消并释放候选房间。

快照字段为 `run_id/revision/phase/seed/current_node_id/room_count/active_entry_id/active_room_plan/visited_node_ids/cleared_node_ids/hp/build_state/build_program`，seed 以十进制字符串表示。`hp` 是房间边界检查点，战斗中的实时生命由 Actor 持有。每房新建 Actor、敌人和效果，仅保留HP与Build，动作/冷却/控制等临时状态不跨房；换波时显式取消旧动作并清理派生效果根。重开创建新 Session，恢复初始生命与配置测试 Build。

## 4. 房间模板替换

资源链为 [run_templates.tres](../game/app/run_templates.tres) 的 `rooms` 字典 → [run_graybox/presentation.tres](../game/presentation/rooms/run_graybox/presentation.tres) → [room.tscn](../game/presentation/rooms/run_graybox/room.tscn)。节点通过 `template_id` 选择此字典里的 Resource；目前只有简单 `graybox` 场景，没有随机模板池或庭院随机组合接入。

替换模板时保留场景根节点协议：`player_spawn() -> Vector3`、`enemy_spawns() -> Array[Vector3]`、`spawn_capacity() -> int`。出生点返回世界坐标，容量与实际可用敌人出生点一致；场景提供地面和世界碰撞，表现 Resource 提供场景引用、镜头等参数。模板 ID、路线引用、出生空间和遭遇容量必须匹配。

app 先创建候选房间，等待物理状态同步，检查玩家/每波敌人与世界碰撞及出生间距，再提交入房并激活战斗。失败留在地图、编号不变。这覆盖当前人工房间的出生净空，尚未实现任意随机障碍布局的完整通路/出口可达性验证。

## 5. 已验证与未完成

2026-10-02 的针对性验证：

- [run_content.gd](../game/tests/run_content.gd)：94 项通过；非法 `1e999` 样例触发预期 `Exponent too high` 警告并被拒绝。
- [run_session.gd](../game/tests/run_session.gd)：87 项通过，覆盖分叉汇合、事务失败、重复/过期回调、死亡优先与隔离。
- [run_map_ui.gd](../game/tests/run_map_ui.gd)：通过；[离线校验](../tools/content/validate_run.py)通过并拒绝 35 个非法样例。
- [run_integration.gd](../game/tests/run_integration.gd)：真实入口 headless 315 项、Forward+ 315 项通过，图形日志无 ERROR；中英文地图和房内提示已截图检查。

独立[M键地图预览](MAP_PREVIEW.md)已能生成随机图，但不改变本入口固定可玩路线。

本Run尚未实现：随机拓扑接入、随机模板/主题池、随机装饰集成、正式精英/Boss内容、大小奖励与跨房 Build 成长、地面拾取/永久库存、店铺进入正式冒险、Run/Profile 磁盘保存和恢复。本切片不提供奖励闭环、正式数值平衡或完整性能验收；退出程序后内存 Run 丢弃。验证明细与后续门禁见[验证索引](VALIDATION.md)。
