# 文档索引与按需阅读

2026-09-28。新任务默认只读根目录 AGENTS、精简 PROJECT_CONTRACT 和 [HANDOFF](HANDOFF.md)，然后选下表相关文档；不递归读取全部 Markdown。

| 本次任务 | 首选文档 | 必要时补读 |
|---|---|---|
| 战斗手感、命中、模型/刀光接口 | [COMBAT_PROTOTYPE](COMBAT_PROTOTYPE.md) | 改复杂规则再读 [战斗扩展](contracts/COMBAT_AND_BUILDS.md) |
| 敌人、深度预算、遭遇、掉落钩子 | [ENEMY_ROLES_AND_ENCOUNTERS](ENEMY_ROLES_AND_ENCOUNTERS.md) | [当前问题](KNOWN_ISSUES.md) |
| 三选一与Build | [BUILD_SYSTEM](BUILD_SYSTEM.md) | 改接口读 [BUILD_IMPLEMENTATION_CONTRACT](BUILD_IMPLEMENTATION_CONTRACT.md) |
| 房间随机物件/搜刮/绕障 | [ROOM_PROPS_PROTOTYPE](ROOM_PROPS_PROTOTYPE.md) | 调组合美术读 [ROOM_PRESETS](ROOM_PRESETS.md) |
| 房间美术接入、光照 | [FOREST_COURTYARD_INTEGRATION](FOREST_COURTYARD_INTEGRATION.md) | 仅相关任务读取其源资产说明 |
| 性能、植被、加载 | [FOREST_FOLIAGE_OPTIMIZATION](FOREST_FOLIAGE_OPTIMIZATION.md) | [当前问题](KNOWN_ISSUES.md) |
| 店铺场景、交互、镜头 | [SHOP_PREVIEW](SHOP_PREVIEW.md) | 换角色读 [character_import_report](character_import_report.md) |
| 家具摆放 | [SHOP_DECORATING](SHOP_DECORATING.md) | 接经济/保存读 [状态存档](contracts/SESSION_AND_SAVE.md) |
| HUD/背包/委托/设置/字体 | [FOLIAGE_UI](FOLIAGE_UI.md) | 只选 [背包](INVENTORY_UI.md)、[委托](COMMISSION_BOARD_UI.md)、[设置](SETTINGS_UI.md)、[字体](UI_FONTS.md) 中相关页 |
| 正式订单、库存、经济与存档 | [状态存档](contracts/SESSION_AND_SAVE.md) | 实现前先核对临时原型边界 |
| 新房间池、路线、Boss节奏 | [房间生成](contracts/ROOM_GENERATION.md) | 当前模板/遭遇模块 |
| schema、翻译、内容发布 | [内容本地化](contracts/CONTENT_AND_LOCALIZATION.md) | 对应模块的现有schema/Loader |
| 验证 | [VALIDATION](VALIDATION.md) | 只运行受影响的脚本 |

## 维护规则

- 稳定的跨模块约束放根契约；模块接口/配置/限制放模块文档；未解决问题只在 KNOWN_ISSUES 维护详情。
- HANDOFF 是状态入口，不堆逐轮日志。同一字段的权威数值在JSON/Resource，不在多份文档里同步抄写。
- 历史测试数量、旧导出路径、被替换方案和早期接口示例在 [归档](archive/2026-09-28/README.md)，只在追溯时读。
- 素材目录 README 和制作说明保留原位，修改该素材时再读。原玩法说明书是愿景，不是实现清单。
- 文档整理不会删除当前聊天历史；新模块任务可以开全新对话，引用本入口与具体任务，无需复制旧聊天全文。

## 新对话可用的开场说明

> 在 E:\ShopGame 开发。先读 AGENTS.md、PROJECT_CONTRACT.md、docs/HANDOFF.md，再按任务读取相关模块文档，不要通读归档。本次任务是：……。保持项目架构，注意其他对话的写入范围；未明确要求时不生成 Release。
