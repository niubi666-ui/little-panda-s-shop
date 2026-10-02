# 基础挥砍刀光候选 v001

日期：2026-09-26。状态：可播放的美术对比原型，三种方向待用户选择。

后续修订：[v002完整剑身刀光](../v002/README.md)已修正尺寸并接入训练场默认效果。本目录保留第一版原图与录制。

## 观看

- 实机视频：[slash_compare.mp4](previews/slash_compare.mp4)，1280×800、60 FPS、13.4 秒，无音频。
- 顺序为 A → B → C。每套先以训练场游戏镜头正常播放，再以近景 0.35 倍速播放。
- 训练场和临时剑仍是占位资源；视频用实际小熊猫模型，剑沿现有逻辑时间线扫动。角色当前没有完整的骨骼挥剑动画，尚不能据此判断最终挥剑动作的力度。

| 候选 | 外观 | 可考虑的用途 | 普通镜头 | 近景慢放 |
| --- | --- | --- | --- | --- |
| A 清晰银线 | 窄、连续、尾迹短 | 普通挥砍 | [截图](previews/candidate_a.png) | [截图](previews/candidate_a_detail.png) |
| B 厚重月刃 | 更宽、更长，覆盖范围明显 | 重击或蓄力斩 | [截图](previews/candidate_b.png) | [截图](previews/candidate_b_detail.png) |
| C 迅捷碎光 | 断续细线与稀疏碎光 | 快速连击 | [截图](previews/candidate_c.png) | [截图](previews/candidate_c_detail.png) |

以上用途只是讨论建议；没有确定元素属性、正式攻击类型或最终美术方向。浅色训练场便于比较轮廓，正式地牢中的对比度与遮挡仍需验证。

## 资源位置

- 本目录 `textures/`：三张生成原图，2172×724 RGBA。透明度与裁切区域检查见 `asset_validation.json`。
- `game/assets/vfx/basic_slash_v001/`：Godot 中使用的贴图副本。
- `game/presentation/combat/fx/slash_candidates_v001/`：三套效果场景、材质和 ribbon 脚本。
- `game/presentation/combat/demos/slash_showcase_v001/showcase.tscn`：独立对比演示入口。
- `prompts.json`：内置 imagegen 模式生成所用完整提示词及原始输出路径。生成的是展开的刀光带状贴图；弧形来自 Godot 中剑身运动采样。

没有把候选替换为游戏默认效果，也没有改动启动场景或游戏玩法配置。

## 运行与操作

在 Godot 编辑器打开 `game/`，打开上述 `showcase.tscn` 并运行当前场景（F6）。

- 初始自动循环 A/B/C。
- `1 / 2 / 3` 或画面按钮：选择对应候选，停止自动切换。
- `Space` / ↻：重播。
- `Tab` / ×0.35：切换正常速度与近景慢放，停止自动切换。
- `P`：暂停/继续。
- `Esc`：退出演示。

也可以命令行运行：

```powershell
& 'E:/GoDot/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe' --path 'E:/ShopGame/game' 'res://presentation/combat/demos/slash_showcase_v001/showcase.tscn'
```

## 给后续代码与美术任务

1. 候选效果兼容当前 `actor_view.set_weapon_effect(scene)` 接口：`set_active(bool)` 控制发射，`set_time_running(bool)` 控制暂停。额外提供 `set_playback_speed(float)` 与 `clear_tail()`。
2. 效果挂在当前剑身中点，采样全局位置和剑长方向，生成逐渐消散的世界空间带状网格。不同挥砍用独立 stroke 标识，避免上一刀与下一刀连成一片。
3. 宽度、拖尾寿命、采样间距、粒子、颜色、亮度与贴图采样区域来自各 `.tscn/.tres`。演示时长、镜头、慢放等来自 `settings.tres`。这些是表现参数。
4. 攻击阶段仍由现有 Catalog 的主角首个攻击驱动，玩法数值保留现有 JSON 权威来源。演示不调用命中 Resolver，不结算伤害、库存或持久状态。
5. 本版 ribbon 网格每帧重建、粒子使用 CPU，适合小规模对比验证。正式多角色战斗前根据实测决定是否换成固定顶点缓冲与 GPU 粒子。
6. 接入正式剑模型与挥剑动画后，应根据剑尖/剑根挂点修正采样轴、宽度和生成时机，再在最终游戏镜头与地牢光照下确认轮廓。不能把训练场视频作为正式动作或最终环境质量验收。

## 已验证

- 三种材质与场景均在 Godot 实际加载并完成录制；`capture.log` 记录每种普通/近景截图均已捕获，没有失败。
- `verify.gd` 验证移动采样、暂停、尾迹消散、不同刀之间不连接、清空，以及效果替换不改变当前攻击 cast ID。结果见 `verification.log`：`failures=[]`。
- MP4 经过 Blender 回读确认 804 帧、1280×800、60 FPS，见 `previews/video_validation.json`。
- `encode_preview.py` 只在后台转码录制视频，没有修改用户当前 Blender 场景。

## 下一步评审

先选普通攻击的轮廓方向，再调整亮度、宽度、寿命与粒子数量。速度感和力度还需结合正式骨骼挥剑、命中停顿及音效一起评审。
