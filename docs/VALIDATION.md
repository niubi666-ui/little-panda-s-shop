# 按改动选择验证

2026-10-02。这是运行入口，不是“本轮全部通过”报告。先读相应脚本，确认需要图形窗口/资源与输出副作用；不要为小改动无差别跑全套。

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
| 镜头/刀光接口 | `hit_camera_shake.gd`、`golden_sword_trail.gd`、`sword_reach_alignment.gd`、`combat_effect_picker.gd`；火焰专项 `fire_slash_v002.gd` |
| 敌人/预算/碰撞 | `enemy_roles.gd`、`charger_obstacles.gd`；完整流程 `enemy_training.gd` |
| 精英游侠/动画/训练刷新 | `ranger_rules.gd`、`ranger_asset.gd`；最新导入后运行 `ranger_integration.gd`（Forward+1280×800），结果与边界见 [游侠](ELITE_RANGER.md#本次验证与边界) |
| 训练工具/显示控制 | `training_tools_content.gd`、`training_damage_override.gd`；`training_tools.gd`支持headless与图形，覆盖真实场景工具、追加/奖励隔离、显示/模态与重试 |
| Build候选/绑定/事务 | `bound_build_policy.gd`、`bound_build_session.gd`、`mechanism_content.gd` |
| 动作/构筑执行/表现隔离 | `dual_actions.gd`、`action_build_runtime.gd`、`action_build_vfx.gd` |
| 控制与真实时序 | `status_controls.gd`、`freeze_guard.gd`、`mechanism_order.gd` |
| 双语/预设/普通选择/替换/输入/重试 | `action_build_integration.gd`，支持headless与Forward+1280×800 |
| 房间组合/物件/搜刮 | `room_prop_rules.gd`、`room_props_integration.gd`；美术截图 `room_presets_capture.gd` |
| 内存路线/跨房 | `run_session.gd`、`run_content.gd`、`run_map_ui.gd`；`run_integration.gd`支持headless/Forward+1280×800 |
| 房间模板/加载 | `forest_room.gd`、`scene_transition.gd`；渲染对照 `forest_foliage_preview.gd` |
| 店铺/镜头/通路 | `shop_preview_controls.gd`、`shop_scene_integration.gd`、`shop_accessibility.gd`、`shop_camera.gd` |
| 家具 | `decorating_rules.gd`、`shop_decorating.gd`、`decorating_ui.gd` |
| UI/字体/设置 | 选择 `foliage_ui.gd`、`inventory_ui.gd`、`ui_typography.gd`、`settings_menu.gd`、`settings_integration.gd` |

实际通过与未验证范围按模块阅读：[机制切片验证](COMBAT_MECHANISMS.md#6-验证与当前边界)、[训练工具验证](COMBAT_PROTOTYPE.md#2026-10-02-训练工具)。集成脚本使用Button/Menu信号与Viewport输入，不代表人工鼠标或主观手感验收。

持久存档/经济尚无完整实现，不把训练提交失败测试当磁盘恢复验收。未来接入须补版本迁移、A/B文件、保存失败及奖励恢复路径。

## 历史证据与权限

- 各模块列出历史通过范围，逐轮日志路径在 [整理前快照](archive/2026-09-28/README.md)；`builds/` 输出可能清理，不保证永久存在。
- 仅管理本任务启动的进程，不停用其他对话编辑器。图形测试可能移动指针/更新预览截图，运行前确认适合当前工作。
- **用户未明确要求时不导出Release。** 文档整理只做文档链接、文件范围与一致性检查，不启动Godot或重导资产。

## 双动作切片实际验证（2026-10-02）

- 内容/PO检查：309双语key，Build v5与Combat v3通过；非法fixture拒绝由机制内容测试48项和绑定策略59项验证。
- 本轮headless通过：`bound_build_policy`、`bound_build_session`、`mechanism_content`、`dual_actions`、`action_build_runtime`、`freeze_guard`、`status_controls`、`training_damage_override`、`mechanism_order`、`training_tools`。
- `action_build_integration`在headless和Forward+1280×800均通过：真实卡片指针点击、右键输入、预设菜单信号、三组预设、T隔离、双语、替换旧新说明、模态暂停、Popup移动门禁、真实重试清理。图形截图已检查；长卡片使用滚动说明。
- `action_build_vfx` headless **114项通过**：检查默认/关闭/空槽/替换场景下相同伤害与状态、快照/暂停/取消/清理。
- Forward+退出仍报7个Texture RID，未解决；不代表完整性能/人工手感验收。未导出Release或提交Git。
- 旧测试兼容入口转向当前测试；`game/tests/legacy_v4/*.gd.txt`保留历史源码，不执行，不宣称其全部覆盖已迁移。


## 短路线切片实际验证（2026-10-02）

- `run_session.gd` **87项通过**：票据、失败隔离、重复提交、路径限制、清场/终点/死亡、HP与Build保持。
- `run_content.gd` **94项通过**：严格JSON/重复键、图/引用/schema、固定seed计划、访问顺序独立。非法`1e999` fixture会产生预期Exponent too high警告并被拒绝。
- 离线`validate_run.py --self-test`通过7节点/8连接，拒绝35个非法fixture；主内容检查已接路线校验，最新翻译351 keys与PO一致。
- `run_map_ui.gd`通过；真实`run_integration.gd`headless与Forward+1280×800均315项通过（含设置暂停、震动瞄准隔离和换波动作取消断言），覆盖两条完整分支、失败模板、反复点击、实际新房、HP/Build与剑气、禁止提前回图、清场/终点/死亡/重开、双语与清理。最后HUD操作提示补充后已复跑，截图已检查。
- 没有接清场奖励，因此不把去重清场测试写成发奖/奖励恢复验收。固定路线不是随机拓扑，固定灰盒模板不是随机房间池，内存Run不支持退出恢复。
