# 房间随机物件：当前运行接口

更新：2026-09-28。当前使用 [四组合美术v004](ROOM_PRESETS.md)；旧散点、中央件数配额与聚簇半径已废弃，不恢复旧参数。

## 已实现

- 同一个庭院模板内随机选择完整小景、落点与允许朝向；组内保持手工布局，组间留白。当前JSON目标3组，实际受合法位置约束。
- 木桶/木箱1HP，普通近战一次破坏并移除碰撞；墙柱岩石不可破坏。宝箱按F搜刮，重复请求不重复发奖，结果仅计入本次训练。
- 类型目录支持 chest1/chest2/forest_bag，当前v004组合没有启用每一种；不保证每房出现三类容器。
- 重试复用布局和预滚奖励、重置破坏/搜刮/Build；新布局重新抽取。清场后可探索，失败/暂停/三选一禁止搜刮。

## 配置与接口（路径相对 game）

| 路径 | 职责 |
|---|---|
| `data/rooms/props_prototype.json` | 组合池/数量、类别/HP、间距/尝试上限、通行余量、搜刮距离/掉落 |
| `data/schemas/room_props.schema.json`、`content/rooms/` | schema/语义/引用校验与只读目录 |
| `rogue/rooms/prop_planner.gd` | 纯计划、版本化随机流、成员占格/连通验证 |
| `presentation/rooms/forest_courtyard_v001/placement_surface.tres` | 平坦可走bounds、手工落点/允许朝向 |
| `presentation/rooms/props/forest_props.tres` | 实体模型/碰撞尺寸与组合目录 |
| `app/session/training_loot_session.gd` | 隔离候选提交、搜刮/破坏幂等、失败不改变权威状态 |
| `app/training_room_props.gd` | 实例化、独立近战目标列表、F交互、注入绕障与视线查询 |

房间通过 `runtime_prop_container()` 暴露容器；RoomPresentation注入surface和prop_visuals。房间美术节点不自行随机，不在战斗宿主写模板ID/模型路径。箱子使用独立目标句柄，不算敌人、清波计数或Build连锁目标；剑气目前只被实体挡住，不对箱子造成伤害。

## 生成与临时状态契约

- `SHA256(seed|template_id|generation_version|stream)` 前15位十六进制派生种子；摆放与每实例掉落独立，视觉不消耗玩法流。
- 计划保存字符串seed、模板/生成/内容版本、组合及成员稳定ID、实际变换和预滚奖励；旧内容版本拒绝静默复用。正式恢复需保存完整方案，当前没有磁盘Run保存。
- 整组接受/拒绝；成员碰撞矩形按净空膨胀，检查边界、出生点、组间重叠、可走网格连通与搜刮站位。花草不占导航，结构代理按成员并集而非整组大框。
- 尝试次数有限；没有合适落点可省略整组并记录omitted，不拆散乱放、不强塞堵路物件。
- 敌人通过注入的网格路径绕障，缓存当前起终点；破坏后重建占用并清缓存。当前只适用于已标注的平坦内庭，不支持任意固定障碍自动栅格化、斜坡或楼层。
- 搜刮/破坏由候选提交后再更新表现；重复/未知实例拒绝，失败不改状态。没有永久库存、金币、开盖动画或正式拾取界面。

## 扩展与验证

新房间复用相同组合目录，提供自身surface/出生点并验证物理通路；跨模板房间池尚未实现。敌人随机组合和深度预算**已实现**，见 [敌人遭遇](ENEMY_ROLES_AND_ENCOUNTERS.md)，与物件规划解耦。

当前美术源/导出见 [ROOM_PRESETS](ROOM_PRESETS.md)。按 [验证索引](VALIDATION.md) 跑 `room_prop_rules.gd` / `room_props_integration.gd`；历史覆盖40种子、确定性/JSON往返、可达性、提交失败隔离、F搜刮/1HP破坏、真实绕障与重开。旧散点截图和旧Release只在归档。
