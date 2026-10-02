# 按改动选择验证

2026-09-28。这是运行入口，不是“本轮全部通过”报告。先读相应脚本，确认需要图形窗口/资源与输出副作用；不要为小改动无差别跑全套。

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

## 相关脚本（均在 game/tests）

| 改动 | 优先检查 |
|---|---|
| 基础战斗/连段/反馈 | `combat_rules.gd`；需要实机时 `combo_feel.gd`、`combat_feedback.gd`、`combat_training.gd` |
| 镜头/刀光接口 | `hit_camera_shake.gd`、`golden_sword_trail.gd`、`sword_reach_alignment.gd`、`combat_effect_picker.gd`；火焰专项 `fire_slash_v002.gd` |
| 敌人/预算/碰撞 | `enemy_roles.gd`、`charger_obstacles.gd`；完整流程 `enemy_training.gd` |
| Build候选/运行 | `build_choices.gd`、`build_runtime.gd`、`projectile_capabilities.gd`；新入口 `projectile_slice_integration.gd`（支持headless/图形）；旧UI输入 `build_training.gd`本轮失败见KNOWN_ISSUES |
| 爆炸/控制状态 | `impact_blast.gd`、`status_controls.gd`、`mechanism_order.gd`；`mechanism_slice_integration.gd`支持headless和图形；控制路径回归`combat_rules.gd`/`enemy_roles.gd` |
| 房间组合/物件/搜刮 | `room_prop_rules.gd`、`room_props_integration.gd`；美术截图 `room_presets_capture.gd` |
| 房间模板/加载 | `forest_room.gd`、`scene_transition.gd`；渲染对照 `forest_foliage_preview.gd` |
| 店铺/镜头/通路 | `shop_preview_controls.gd`、`shop_scene_integration.gd`、`shop_accessibility.gd`、`shop_camera.gd` |
| 家具 | `decorating_rules.gd`、`shop_decorating.gd`、`decorating_ui.gd` |
| UI/字体/设置 | 选择 `foliage_ui.gd`、`inventory_ui.gd`、`ui_typography.gd`、`settings_menu.gd`、`settings_integration.gd` |

持久存档/经济尚无完整实现，不把训练提交失败测试当磁盘恢复验收。未来接入须补版本迁移、A/B文件、保存失败及奖励恢复路径。

## 历史证据与权限

- 各模块列出历史通过范围，逐轮日志路径在 [整理前快照](archive/2026-09-28/README.md)；`builds/` 输出可能清理，不保证永久存在。
- 仅管理本任务启动的进程，不停用其他对话编辑器。图形测试可能移动指针/更新预览截图，运行前确认适合当前工作。
- **用户未明确要求时不导出Release。** 文档整理只做文档链接、文件范围与一致性检查，不启动Godot或重导资产。
