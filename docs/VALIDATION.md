# 按改动选择验证

2026-10-15。这是运行入口，不是“本轮全部通过”报告。先读相应脚本，确认需要图形窗口/资源与输出副作用；不要为小改动无差别跑全套。

## 命令

在项目根运行内容检查（不改生成文件）；修改翻译后去掉 `--check` 才生成PO：

```powershell
& builds/content_venv/Scripts/python.exe tools/content/build_shop_preview_content.py --check
& builds/content_venv/Scripts/python.exe tools/content/build_decorating_content.py --check
```

规则测试示例：

```powershell
& 'E:/GoDot/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe' --headless --path E:/ShopGame/game --script res://tests/enemy_roles.gd
```

图形测试去掉 `--headless`，按脚本要求指定分辨率。脚本含截图/等待 `RenderingServer.frame_post_draw` 时不能随意无头运行。不要只看进程退出码，要检查 `SCRIPT ERROR`、`ERROR` 与测试 `failures`。

修改共享 `data/manifest.json` 的字段时，需同步 schema 与 `ShopPreviewLoader` 的严格字段校验，并运行 `shop_preview_controls.gd` 和真实主场景启动检查。离线 schema 通过、独立战斗或路线入口通过，不能代替店铺主入口验证。

## 相关脚本（均在 game/tests）

| 改动 | 优先检查 |
|---|---|
| 基础战斗/连段/反馈 | `combat_rules.gd`；需要实机时 `combo_feel.gd`、`combat_feedback.gd`、`combat_training.gd` |
| 伤害跳字 | `damage_numbers.gd`；支持headless，图形模式额外输出 `builds/damage_numbers_preview.png`，覆盖双方实际扣血、免疫、致死、暂停、数量上限及清理 |
| 特殊敌人冻结累计抗性（非当前游侠响应） | `elite_freeze_resistance.gd`、`freeze_guard.gd`、`freeze_followup.gd`、`mechanism_content.gd`；均支持headless，配置同时运行离线Build校验。游侠减速专项见下方新增入口 |
| 镜头/刀光接口 | `hit_camera_shake.gd`、`golden_sword_trail.gd`、`sword_reach_alignment.gd`、`combat_effect_picker.gd`；火焰专项 `fire_slash_v002.gd` |
| 玩家受击半径/擦身箭 | `player_hurt_radius.gd`；修改半径的内容/schema检查 |
| 敌人/预算/碰撞 | `enemy_roles.gd`、`charger_obstacles.gd`；完整流程 `enemy_training.gd` |
| 豺狼近战斥候模型/骨骼动画 | `scout_presentation.gd`（headless 灰盒；图形加 `-- --forest` 验证真实庭院），行为回归 `enemy_roles.gd` |
| 精英游侠/动画/训练刷新 | `charged_ranger.gd`、`ranger_sequences.gd`、`ranger_rules.gd`、`ranger_vfx.gd`；裂隙接入使用 `ranger_charged_integration.gd`（实际F6入口/Forward+）；改模型时用`ranger_asset.gd`；最新导入后运行 `ranger_integration.gd`（Forward+1280×800），结果与边界见 [游侠](ELITE_RANGER.md#本轮验证与边界) |
| 训练工具/显示控制 | `training_tools_content.gd`、`training_damage_override.gd`；`training_tools.gd`支持headless与图形，覆盖真实场景工具、追加/奖励隔离、显示/模态与重试 |
| Build候选/绑定/事务 | `bound_build_policy.gd`、`bound_build_session.gd`、`mechanism_content.gd` |
| 动作/构筑执行/表现隔离 | `dual_actions.gd`、`action_build_runtime.gd`、`action_build_vfx.gd` |
| 清场后施放/剑气水平外观 | `post_clear_skills.gd`（headless或Forward+；图形模式截图至builds）；`run_integration.gd`覆盖路线/终点空放及退出清理，`training_tools.gd`覆盖追加敌人与奖励隔离 |
| 控制与真实时序 | `status_controls.gd`、`freeze_guard.gd`、`mechanism_order.gd` |
| 双语/预设/普通选择/替换/输入/重试 | `action_build_integration.gd`，支持headless与Forward+1280×800 |
| 房间组合/物件/搜刮 | `room_prop_rules.gd`、`room_props_integration.gd`；美术截图 `room_presets_capture.gd` |
| 随机地图生成/预览 | `build_map_preview_content.py --check`；`map_branch_pruning.gd`、`map_generation.gd`；排版用`map_visual_layout.gd`，实机用`map_preview_ui.gd`（headless/Forward+），入口用`map_preview_hosts.gd`；范围见[地图预览](MAP_PREVIEW.md) |
| 内存路线/跨房 | `run_session.gd`、`run_content.gd`、`run_map_ui.gd`；`run_integration.gd`支持headless/Forward+1280×800 |
| 房间模板/加载 | `forest_room.gd`、`scene_transition.gd`；渲染对照 `forest_foliage_preview.gd` |
| 店铺/镜头/通路 | `shop_preview_controls.gd`、`shop_scene_integration.gd`、`shop_accessibility.gd`、`shop_camera.gd` |
| 家具 | `decorating_rules.gd`、`shop_decorating.gd`、`decorating_ui.gd` |
| UI/字体/设置 | 选择 `foliage_ui.gd`、`inventory_ui.gd`、`ui_typography.gd`、`settings_menu.gd`、`settings_integration.gd` |

实际通过与未验证范围按模块阅读：[机制切片验证](COMBAT_MECHANISMS.md#6-验证与当前边界)、[训练工具历史验证](archive/2026-10-13-doc-cleanup/COMBAT_VALIDATION_HISTORY.md#2026-10-02-训练工具)。集成脚本使用Button/Menu信号与Viewport输入，不代表人工鼠标或主观手感验收。

持久存档/经济尚无完整实现，不把训练提交失败测试当磁盘恢复验收。未来接入须补版本迁移、A/B文件、保存失败及奖励恢复路径。

## 历史证据与权限

- 各模块列出历史通过范围，逐轮日志路径在 [整理前快照](archive/2026-09-28/README.md)；`builds/` 输出可能清理，不保证永久存在。
- 仅管理本任务启动的进程，不停用其他对话编辑器。图形测试可能移动指针/更新预览截图，运行前确认适合当前工作。
- **用户未明确要求时不导出Release。** 文档整理只做文档链接、文件范围与一致性检查，不启动Godot或重导资产。

## 新增专项入口

| 改动 | 优先检查 |
|---|---|
| 三动作键位与蓄力尺寸 | `three_actions.gd`、`charged_wave_scale.gd` |
| 首批冰冻扩展 | `frost_first_batch.gd`；内容/schema校验 |
| 游侠冰冻减速窗口及追击 | `boss_frost_window.gd`、`boss_frost_builds.gd`；累计抗性另用特殊夹具 `elite_freeze_resistance.gd` |
| 五波训练与末波Boss | `training_five_waves.gd`；深度、计划锁定、逐波倍率和胜利条件 |

2026-10-02 至 2026-10-13 的专项通过记录与当时警告见[验证历史](archive/2026-10-13-doc-cleanup/VALIDATION_HISTORY.md)。当前问题以[问题清单](KNOWN_ISSUES.md)为准；文档整理未运行游戏测试。
