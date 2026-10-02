# 四款元素刀光实机对比录制

`showcase.tscn` 实例化真实 `training_arena.tscn`，依次经训练HUD按钮信号选择火焰、闪电、雷霆、冰霜。每款独立重建一次训练场，恢复来自真实目录的初始血量。

每段6秒：正常速度空挥、0.4倍速近景空挥、对2.35米处真实敌人的正常速度命中。录像保留训练场灯光、模型、地面、HUD与当前效果高亮。近景镜头尺寸6.5，构图偏向画面左側，为右侧面板留出空间。

为比较而暂停敌人AI决策；没有改写血量、伤害或能力定义。`Actor.step()`、AbilityRunner时间线、MeleeResolver、ActorView、受击反馈、击退均使用真实组件。示意长剑和角色动作仍是项目当前表现，不额外替换。

所有录制专用参数位于 `settings.tres`，生产战斗规则仍来自JSON。新增效果ID必须先存在于训练palette并由主整合任务统一导入。

## 运行

```powershell
& 'E:/GoDot/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/ShopGame/game' --resolution 1280x800 --fixed-fps 60 --write-movie 'E:/ShopGame/source_assets/vfx/elemental_slashes_v001/previews/elemental_combat.avi' 'res://presentation/combat/demos/elemental_combat_v001/showcase.tscn' -- --capture
```

程序完成后自动退出。`capture_result.json` 记录每款资源路径、实际施放能力、半径、角度、实际命中距离、伤害与剩余血量、末端截图及失败原因。近景第一帧收招截为每款的PNG，截取位置仍有完整末端尾迹。

使用已有编码程序转MP4，不编辑时间或画面：

```powershell
& 'E:/blender/blender.exe' --background --factory-startup --disable-autoexec --python 'E:/ShopGame/source_assets/vfx/trail_fxs_v2/godot_sword_v001/reports/capture_encode.py' -- 'E:/ShopGame/source_assets/vfx/elemental_slashes_v001/previews/elemental_combat.avi' 'E:/ShopGame/source_assets/vfx/elemental_slashes_v001/previews/elemental_combat.mp4'
```
