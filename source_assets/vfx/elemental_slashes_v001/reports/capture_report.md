# 四款刀光实际训练场录像验证

## 输出

- MP4：`source_assets/vfx/elemental_slashes_v001/previews/elemental_combat.mp4`
- 原始 Godot Movie Maker 录像：同目录 `elemental_combat.avi`
- 1280×800，60 FPS，1444帧，24.0667秒；MP4约7.67MB。
- 实际端点截图：`element_fire.png`、`element_lightning.png`、`element_thunder.png`、`element_frost.png`。
- 机器可读结果：`capture_result.json`；运行日志：`capture_run.log`；转码日志：`capture_encode.log`。

## 实际运行方法

使用真实训练场、当前小熊猫模型、长剑、灯光、地面与HUD。通过HUD按钮已有signal切换效果，录屏保留选中高亮。每款6秒，包含正常挥砍、0.4倍速近景挥砍，以及新范围内的真实命中。

**为便于形态比较，敌人AI决策暂停。** 实际Actor、AbilityRunner、MeleeResolver、受击反馈、击退与HP状态照常执行。每款开始重新实例化训练场，敌人初始46HP来自真实目录，没有修改最大血量、当前血量或伤害。角色身体目前仍是项目原有动作表现。

## 结果

总计12次真实施放，四款各执行 `slash.1` 正常展示、`slash.2` 慢速展示、`slash.3` 范围命中。角度全部160°；前两段实际规则半径2.5米，第三段2.8米。空挥阶段没有命中；每款范围命中目标距离均为2.3499999米，单次27伤害，目标由46HP降至19HP。

| 效果ID | 场景 | 范围命中距离 | 伤害 | 剩余HP |
|---|---|---:|---:|---:|
| element_fire | `res://presentation/combat/fx/elemental_slashes_v001/fire/slash.tscn` | 2.35米 | 27 | 19 |
| element_lightning | `res://presentation/combat/fx/elemental_slashes_v001/lightning/slash.tscn` | 2.35米 | 27 | 19 |
| element_thunder | `res://presentation/combat/fx/elemental_slashes_v001/thunder/slash.tscn` | 2.35米 | 27 | 19 |
| element_frost | `res://presentation/combat/fx/elemental_slashes_v001/frost/slash.tscn` | 2.35米 | 27 | 19 |

`capture_result.json` 的 `failures=[]`。Godot退出码0，未出现脚本或资源错误。四张实机截图均已人工目视：刀光完整位于右侧面板之外，当前选项高亮正确，火焰、闪电、雷霆、冰霜形态可区分。

转码调用现有 `capture_encode.py`，Blender原生H.264编码成功，输出与原录像均为1444帧／60FPS／1280×800。未裁切、未变速、未拼接概念画面。

录制入口及外置参数：`game/presentation/combat/demos/elemental_combat_v001/`。该目录仅负责演示，不作为正式战斗流程。
