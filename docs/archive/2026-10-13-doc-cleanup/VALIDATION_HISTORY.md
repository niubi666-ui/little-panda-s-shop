# 专项验证历史记录

2026-10-13 从验证索引移出；以下结果仅对应各记录日期和当时版本，不代表当前工作区通过。当前入口见[验证索引](../../VALIDATION.md)。

## 冰冻追击切片实际验证（2026-10-09）

- 内容/schema/PO：396双语key，Build v7、Combat v3；新条件字段严格校验，旧v6/冻结rank2拒绝。
- `freeze_followup.gd`：命中前状态、独立根、来源/房间/调试隔离、无自触发、继承基数、两卡共存、加算限幅、免疫/抗性、候选和失败/RNG隔离；当前351项通过。2米/6米目标使用1秒Q冷却、1.2秒普通冻结，第一发24、后续38.4，第二发不延长冻结。
- headless本轮通过：`bound_build_policy`（72）、`bound_build_session`、`mechanism_content`（50）、`action_build_runtime`、`three_actions`、`freeze_guard`、`status_controls`、`action_build_vfx`（114）、`post_clear_skills`、`mechanism_order`、`run_session`（97，含两张新卡跨房保留）、`run_integration`（353）。
- `action_build_integration` Forward+1280×800通过：六个预设、真实Q/左键输入、冻结追击事实、双语提示/预设界面、替换旧新说明、暂停/Popup门禁、真实重试清空；截图人工检查浅蓝追击提示。旧三个预设继续验证，普通训练菜单也已启用。
- 原有7个Texture RID退出警告仍存在；未做完整性能、人工操作手感或正式存档验证。无Release、commit或push。输出在被忽略的`builds/ice_*.log`及`builds/action_ice_*.png`，不作为永久资源。

## 双动作切片历史验证（2026-10-02）

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

## Boss冰冻窗口（2026-10-12本轮）

- `boss_frost_window.gd`：24项通过，包含JSON非法响应、首次减速、不重启蓄力、局部/正常时间、连续射击、已射箭/箭雨独立、翻滚、最强减速、消费/寒印/抗冻、死亡与状态提示装配。
- `boss_frost_builds.gd`：64项通过，近远距离Q追击、左键追击、来源校验、派生不继承、Boss冰衣/破冰、寒印和抗冻不能冒充窗口。
- 回归通过：elite_freeze_resistance（显式特殊累计夹具）、freeze_guard、ranger_sequences（32项）、freeze_followup（351项）、mechanism_content（50项）、frost_first_batch。
- 离线内容/schema与424条双语键检查通过，PO已生成。
- action_build_slice训练入口headless启动至`training ready`；退出时触发combat_training._shutdown相机离树调用错误（引入版本未确定），本轮未修改该共享手感/相机代码。未进行实际图形试玩，动画/提示可读性与难度仍待用户体验；无Release或Git提交。

## 满蓄力宽寒冰月牙（2026-10-12）

charged_wave_scale专项、frost_first_batch回归与离线内容/双语校验通过。检查原演示整体模型比例、满蓄力事实、1.95米半径、侧方命中和3倍基础伤害、短按恢复普通弹、不隐式授予冻结。参考预览已查看；新版实战画面尚未人工试玩。

## 战斗键位调整（2026-10-12）

project.godot将combat_skill绑定鼠标右键、combat_special绑定R。three_actions与charged_wave_scale自动测试通过，覆盖右键即时剑气、按住蓄力/松键发射、R重击、Q不再触发战斗动作和UI输入隔离；424条双语内容校验与PO生成通过。未进行本轮图形试玩，未提交Git。店铺R装修保持原场景内用途。

## 五波训练（2026-10-13）

training_five_waves.gd通过：四档训练深度生成/锁定复现/篡改拒绝，默认实场连续五波、逐波血量/近战伤害倍率、末波真实游侠及远程伤害倍率、前四波不胜利、Boss死亡才胜利、重试计划不叠加。headless过程中有四条dummy renderer material为null日志，规则断言全部通过；未做图形手感验收。离线schema/内容校验通过。不生成Release，不提交Git。
