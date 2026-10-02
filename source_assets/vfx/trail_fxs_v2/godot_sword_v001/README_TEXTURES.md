# 金色破碎流光：Godot 贴图转制

2026-09-26。来源是用户认可的 `../blender/sword_trail_study.blend` 中 `01_Golden_Filaments` 材质；沿用用户提供的 Trail FXs v2 程序材质，保留正式样片添加的拖尾淡出和宽度收束。没有改动原 Blender 文件或素材库。

## 输出

- `textures/golden_filaments_0..3_emission.exr`：4 张 1024×256 场景线性 HDR 颜色，保留超过 1 的亮度。
- `textures/golden_filaments_0..3_mask.png`：对应透明覆盖率，按线性数据采样。
- 引擎副本：`game/assets/vfx/golden_trail_v001/`。
- `reports/baked_frames_contact.png`：四帧合成预览；使用简易色调映射，只用于观察纹理与颜色。
- `reports/bake_manifest.json`：源材质、实际输入值、烘焙相位、数值范围和文件校验值。
- `reports/bake_golden_filaments.py`：可重复执行的转制脚本。

## 运行时接入约定

纹理可接入现有 `emission_0..3` / `mask_0..3` shader sampler。EXR 和 mask 都不添加 `source_color` 提示；保持线性采样。纹理本身不是预乘透明度，着色器按 mask 设置 `ALPHA`。

- 网格 U：旧拖尾为 0，当前剑刃为 1。
- 网格 V：剑尖／外缘为 0，剑根／内缘为 1。
- Blender 烘焙图像和现有 Godot Shader 的组合，保留 `vec2(UV.x, 1.0 - UV.y)` 采样转换。
- 尾端淡出和向外缘收束已写入 mask；运行时仅额外做整个效果的生命周期淡出，避免重复强烈压窄。
- 使用 4 个相位来回插值，避免循环末尾突然跳变。相位是 4.125、4.275、4.425、4.575。
- 源发光颜色为 `(1, 0.48, 0.055)` 与 `(1, 0.055, 0.006)`；强度 8。烘焙 HDR 红通道峰值约 7.6，mask 峰值约 0.69。`energy_scale` 可从 0.8–1.0 起调，最终以战斗场景曝光和 Bloom 实机画面为准。

## 本次验证

已在 Blender 5.2.1 后台使用 Cycles 实际执行全部 8 次烘焙，目视检查四帧纹理。另从正式场景计算后的拖尾顶点核对了 U/V 与剑尖、剑根的对应关系。原场景的 `Glow`、`Glow2`、`Hue`、`UseGlowColors`、`Speed` 取自第 99 帧实际 Geometry Nodes 属性，非猜测替换。

该文档只记录贴图转制；角色动作、命中范围和 Godot 运行时效果由整合步骤验证。
