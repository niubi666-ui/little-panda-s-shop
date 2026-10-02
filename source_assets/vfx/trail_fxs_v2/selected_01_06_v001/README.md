# Trail FXs 01 / 06 · Godot 材质移植小样

2026-09-26。用户指定 `M_Trail_Blade_01` 与 `M_Trail_Blade_06`，此版用于视觉评审，尚未设为默认战斗效果。

## 查看

- [材质对比图](previews/material_comparison.png)：Godot 实际渲染的 240° 长弧，用于看清色阶、光晕和破碎纹理；这是静态材质检视，不是角色攻击范围。
- [实机视频](previews/presets_01_06.mp4)：1280×800、60 FPS、13.9 秒，先 01 后 06，每款普通速度与近景 0.35 倍慢放。使用实际小熊猫、简洁长剑与现有攻击时间线，骨骼挥剑仍为占位。
- 实机截图：`candidate_a.png` / `candidate_a_detail.png` 为 01；`candidate_b.png` / `candidate_b_detail.png` 为 06。
- 独立演示：`game/presentation/combat/demos/trail_presets_01_06_v001/showcase.tscn`，Godot F6 运行。1/2 切换、Space 重播、Tab 慢放、P 暂停、Esc 退出。

## 原材质保留与适配

从原包 `TrailFXs_Blades.blend` 中读取 `Trail_Blade_01` 与 `Trail_Blade_06` 材质，而不是重新绘制缩略图。`../reports/selected_nodes.json` 保存节点与参数检查记录。

- 01：保留原材质的宽度遮罩、纵向淡出、EASE 色阶和发光强度计算；暖白亮面依次过渡到金黄、橙红尾部。
- 06：保留原 4D 噪声、扭曲、遮罩色阶及 Color Dodge 亮丝结构。选择深紫/亮紫的 Glow Colors 来匹配供应方 06 缩略图；这属于本次颜色适配，不能视为恢复了供应方制作缩略图时全部场景参数。
- 通过 Blender Cycles 原节点烘焙线性 HDR 发光 EXR 和独立透明遮罩 PNG；01 一组，06 四组噪声时刻。Godot 对 06 的四组结果插值并往返播放。它是动态噪声近似，不是无限时长的原 Blender 程序噪声求值。
- Godot 用 HDR 输出和场景 Glow 显示光晕，额外曝光比例 0.65 保存在材质 `.tres` 中。跨引擎色调映射和光晕算法不同，不声称逐像素还原。
- 使用现有 v002 剑根/剑尖采样方式，增加角向插值与径向细分，让贴图随完整剑身弧面展开。没有额外加入原 01/06 中不存在的火星粒子。
- 暂停冻结几何、尾迹消散与材质噪声时间；新攻击不连接到上一刀。攻击、伤害和其他玩法配置保持原逻辑权威来源。

## 文件

- `bake_presets.py`：从原材质烘焙的脚本，原 `.blend` 未保存修改。
- `textures/`：源烘焙输出；`bake_manifest.json`：对应关系。
- `game/assets/vfx/trail_presets_01_06_v001/`：Godot 使用的贴图。
- `game/presentation/combat/fx/trail_presets_01_06_v001/`：独立效果与材质。
- `game/presentation/combat/demos/trail_presets_01_06_v001/`：对比演示、静态材质检视和验证脚本。
- 材质依赖用户提供的 Trail FXs 资产，授权情况沿用源资产记录，不能作为自有原创素材单独分发。

## 验证

Godot 4.7.2 Forward+ 完成实际渲染与录制，普通和近景两款均捕获，无运行错误。`verification.log` 的 `SELECTED_PRESETS_VERIFY failures=[]` 覆盖整段剑身、插值、暂停、材质时钟、消散、独立挥砍和切换效果不改施放。MP4 回读确认 834 帧、1280×800、60 FPS，见 `previews/video_validation.json`。

演示采用深灰地面以观察色阶，两款使用同一场景、同一曝光。后续仍需在正式地牢光照与动作中确认可读性和强度。
