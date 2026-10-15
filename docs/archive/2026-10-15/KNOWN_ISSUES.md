# 已知问题与诊断边界

更新：2026-10-15。只列未解决项；修复后记录证据并移出当前问题，不通过“未复现”关闭问题。

## RES-001：图形退出资源警告

既往图形运行常出现7个Texture RID退出警告；某些连续切换诊断还出现ObjectDB/RefCounted警告。未证实与持续低帧有因果关系，不宣称无泄漏或已经修复。已有过渡节点释放检查不代表引擎全部资源正常。历史数据与资源复现见 [植被和加载](FOREST_FOLIAGE_OPTIMIZATION.md)。

## 验收限制

- 正式最低配置/目标帧率未定；静态暂停场景、缓存重开、短时探针均不代表全战斗性能。
- 家具通行采用保守平面网格；新增交互家具专用使用面的净空尚未逐件建模，见 [装修](SHOP_DECORATING.md)。
- 正式磁盘存档、经营与随机模板池是未实现范围，见 [交接](HANDOFF.md)，不要当成已完成后的bug。

## TEST-002：测试脚本落后于当前训练流程（2026-10-15 图形模式实测）

- `training_tools.gd`：“normal encounter completes after all additions die”“post-victory practice gives no extra progression reward”失败。训练场已改为五波（第五波 Boss），测试仍按两波写，杀完第二波就期待胜利。需按五波流程更新测试，规则本身未见问题。
- `golden_sword_trail.gd`：“third attack has its configured narrow width”失败，测试期望刺击宽度 1.0，`combat/prototype.json` 中 `slash.3` 的 `thrust_width_m` 为 1.8。
- `combat_feedback.gd`：“death body and bar finish without delaying rules”失败，与主角/敌人保留尸体、消散时长的表现改动有关，尚未核对断言是否应更新。
- 图形模式运行 `enemy_training.gd`、`combo_feel.gd`、`training_tools.gd` 时引擎报 “Parameter "material" is null”（`material_casts_shadows` / `material_is_animated`），测试本身通过，来源未定位。

## 已修复范围（2026-10-02）

- INPUT-001：Control焦点与已知Popup已有显式移动/攻击门禁，dual_actions及真实场景测试通过。
- 旧TEST-001全局Build图形脚本已归档并替换为v5入口。新场景指针选卡、右键、语言、预设/替换与重试通过headless和Forward+；这不等于旧全局脚本每条断言原样通过。人工编辑器嵌入窗口/输入法仍未完整验收。

## 已修复范围（2026-10-06）

- VFX-001：普通/寒冰月牙取消刃面倾斜，真实节点360方向检查均平行地面，避免原倾角经非等比缩放后近乎侧对庭院镜头；主体/残影一致，玩法范围未变。
- COMBAT-001：训练与短路线房间清场后继续执行技能，自动奖励结束与运行态停止分离；清场不再取消玩家已承诺动作。`post_clear_skills.gd`覆盖跨清场起手、再次右键空放、暂停/退出与奖励隔离；`run_integration.gd`343项及`training_tools.gd`通过。正式持久关卡仍未实现。

## 训练退出相机离树调用：已有修复代码，待运行回归确认

`combat_training.gd` 的 `_apply_camera_shake` 已添加 `Camera.is_inside_tree()` 门禁，战斗视觉文档记录了修复。此前退出时的离树报错保留为回归关注项；本轮仅静态核对，未运行Godot确认修复覆盖范围。
