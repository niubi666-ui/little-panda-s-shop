# 层叠火焰斩击：真实训练场录制入口

`showcase.tscn` 实例化真实训练场，并通过HUD按钮已有signal选择 `fire_slash_v002`。角色、长剑、灯光、地面、HUD、AbilityRunner、Actor.step、MeleeResolver与受击反馈均沿用当前项目。

录制参数外置于 `settings.tres`。12秒流程为：正常速度单斩，0.4倍速近景单斩，真实三段连击，以及2.35米处真实目标的慢速命中。末尾留出尾迹、粒子、灯光消散时间。

为了比较美术，敌人AI决策暂停；它们仍由真实Actor更新，血量与伤害没有改写。主角身体沿用现有占位动作，录制没有添加或模拟正式骨骼挥剑动画。右侧测试面板保留，镜头向右平移，让主要动作位于面板左边。

## 输出

- 正常、慢速、三连末段、范围命中末端截图。
- 真实扣血帧截图 `range_hit.png`。
- 消散完成截图 `tail_cleared.png`。
- `source_assets/vfx/fire_slash_v002/reports/capture_result.json` 记录施放、实际命中距离、伤害、HP、截图时间与失败原因。

仅观察截图可运行场景加 `-- --capture`；正式录像命令：

```powershell
& 'E:/GoDot/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/ShopGame/game' --resolution 1280x800 --fixed-fps 60 --write-movie 'E:/ShopGame/source_assets/vfx/fire_slash_v002/previews/fire_combat_v002.avi' 'res://presentation/combat/demos/fire_combat_v002/showcase.tscn' -- --capture
```

用项目已有 `source_assets/vfx/trail_fxs_v2/godot_sword_v001/reports/capture_encode.py` 原样转码为MP4；不修改画面时序。
