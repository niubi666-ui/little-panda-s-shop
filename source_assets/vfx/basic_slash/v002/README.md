# 完整剑身刀光 v002

日期：2026-09-26。用户反馈：刀光相对长剑过短、轮廓不清楚。本版修正覆盖范围与尾迹，并接入训练场默认效果；具体颜色与强度仍可继续评审。

## 看结果

- [实机视频](previews/slash_compare.mp4)：A → B → C，1280×800、60 FPS、13.4秒，每套先正常速度，再近景0.35倍慢放。
- [默认效果近景](previews/candidate_a_detail.png)、[游戏镜头](previews/candidate_a.png)、[实际命中反馈](previews/training_hit.png)。
- [B近景](previews/candidate_b_detail.png)、[C近景](previews/candidate_c_detail.png)。
- 可玩训练包：`E:/ShopGame/builds/combat-prototype.pck`，店铺F6进入训练；代码运行入口仍为原训练场。

## 实际修改

1. 默认效果原先只沿剑中点轨迹生成宽0.14的竖直窄带，并叠加较强发光核心，无法表现整段剑身的扫动范围。
2. 新效果根据实际剑长，采样剑根和剑尖，生成世界空间完整弧面。默认A覆盖长度为剑长的1.09倍，剑尖有适度延伸；B更宽更长，C带断续纹理。
3. 明亮外缘放在剑尖一侧，浅金内层半透明，避免整块白色扇面遮盖角色。减小发光粒子并移到剑尖，移除中点发光球。
4. 默认尾迹寿命从0.16秒调整为0.32秒；加入角度插值，让短攻击时间内的弧线更平滑。结束时补齐最后剑尖位置，各刀尾迹彼此独立。
5. 复用v001生成的三张贴图，由Shader与动态网格改变外观，本次没有重新生成或编辑位图。生成提示词仍见 [v001提示词](../v001/prompts.json)。

## 资源与接口

| 内容 | 入口 |
| --- | --- |
| 默认效果 | `game/presentation/combat/fx/slash_default.tscn` → v002 A |
| 新刀光场景与材质 | `game/presentation/combat/fx/slash_candidates_v002/` |
| 效果脚本 | 同目录 `ribbon_effect.gd` |
| 演示场景 | `game/presentation/combat/demos/slash_showcase_v002/showcase.tscn` |
| 原贴图 | `game/assets/vfx/basic_slash_v001/` |
| 改动前备份 | 本目录 `backup/`；v001演示与原图保留 |

`ActorView`仍将效果挂在剑身中点；若效果提供 `configure_blade(length)`，会注入 `training_style.tres` 中的实际剑长。局部正Z为剑根、负Z为剑尖。根偏移与剑尖延伸为长度比例，尾迹寿命、采样距离、最大角度间隔、衰减在 `.tscn` 中配置；颜色、亮度、边缘宽度与内层强度在 `.tres` 中配置。没有复制玩法伤害、攻击角度或攻击时间数值。

效果API保留 `set_active(bool)`、`set_time_running(bool)`，额外支持 `set_playback_speed(float)` 与 `clear_tail()`。效果不能调用伤害结算，长度延伸也不会增加命中范围。

## 播放

在Godot中打开上述独立演示场景，F6运行。`1/2/3`选择A/B/C，`Space`重播，`Tab`切换近景慢放，`P`暂停，`Esc`退出。也可在原训练场实际挥砍，默认使用新A效果。

主角用实际GLB，剑与骨骼挥砍仍是占位表现；此次验收针对刀光覆盖与消散。

## 验证

- `verification.log`：三种效果覆盖整段剑长、角度插值、暂停、结束消散、不同挥砍不相连、清空，以及替换默认效果不改变cast；`SLASH_VERIFY_V002 failures=[]`。
- `combat_feedback.log`：实际命中与既有击退、受击材质隔离/恢复、延迟血条等检查；`COMBAT_FEEDBACK failures=[]`。
- `capture.log`：三种效果均录制普通/近景截图，`SLASH_SHOWCASE failures=[]`。
- MP4回读结果：`previews/video_validation.json`。
- 导出和导出包启动记录：`export.log`、`packed_run.log`。

本版未改玩法JSON、命中范围、伤害、连段时序或存档。动态网格仍用于原型验证，正式大规模战斗时再按实测优化。
