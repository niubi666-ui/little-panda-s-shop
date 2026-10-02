# 火焰斩击 V002 · Blender 美术制作记录

2026-09-26。由独立 Blender 美术子任务制作；Godot 分层表现、测试选项与实机验收由主任务整合。

## 目标与修改

用户希望比上一轮细线火焰更饱满、更大、有层次。本轮重建整体连续的宽大弯月火焰片：

- 外缘：窄而连续的高温黄白刃心。
- 主体：黄橙热流、橙色火腹与红色冷却沟槽；扭曲的定向流场形成不等宽的卷纹。
- 内缘：宽肩收尖的火舌，19 处分支轮廓和 11 处湍流窗口，另有少量沿流动方向拉长的孔隙。
- 脱离主弧的火团：四个真实 3D 焰瓣组成一团，顶部收尖、肩部饱满，随时间变形、卷动、噪声侵蚀后消失。

首版主弧虽然已经增宽，内部渐变仍太平滑；第二版加入黄色热流和红色冷槽，保持主体连贯与原发光强度，避免全片曝光成白色。最终 `fire_slash_v002_hero.png` 和 body 贴图都是第二版。

## 参考边界

参考 [De Andre Martin — Fire Sword Slash VFX](https://goldmario100.artstation.com/projects/zDrmJm) 的作者说明：高亮黄色向红色变化，剑上的火焰跟随运动，后方火焰逐渐溶解。本轮网络页面文字可以读取，未播放并观看完整的参考动画，因此不声称逐帧分析或复刻了视频。

本次没有下载该作者的贴图、模型或工程；所有交付 body 节点、3D 焰瓣与 atlas 均在 Blender 中新建。无需额外插件，没有使用 imagegen。

## 文件与实际制作

| 文件 | 内容 |
| --- | --- |
| `blender/fire_slash_v002.blend` | 可编辑程序材质、UV 弧面、长剑、灯光、相机；主弧形状键与挥剑动画 |
| `blender/flame_atlas_source.blend` | 四层 3D 火焰瓣源模型、渐热材质、正交透明渲染相机；打开为可见状态 |
| `blender_previews/fire_slash_v002_hero.png` | Blender 实际渲染静帧 |
| `blender_previews/fire_slash_v002_motion.mp4` | Blender 实际渲染 96 帧，30 FPS，960×600；快速与慢速挥砍 |
| `blender_previews/flame_atlas_contact.jpg` | 16 帧透明火团的中性底联系表 |
| `bakes/ribbon_body_{0..3}_emission.exr` | 4 张 2048×512 scene-linear HDR 发光烘焙 |
| `bakes/ribbon_body_{0..3}_mask.png` | 4 张 2048×512 线性透明度遮罩 |
| `bakes/flame_atlas.png` | 4×4=16 帧、每帧 256×256；sRGB RGBA，straight alpha |

运行时资源复制到 `game/assets/vfx/fire_slash_v002/`。没有写入 presentation、UI 或内容数值目录。

## 运行时接口说明

- Body UV：U=0 为旧尾迹，U=1 为当前刃；V=0 为外缘剑尖，V=1 为内缘剑根。
- Body 颜色与透明度分别从原生 Blender Shader 的 emission 与 coverage 进行真实 Cycles `EMIT` bake。不是从 hero 截图裁切。
- Atlas 帧序：左上角开始逐行；第 0 帧为初生小火，第 3–8 帧为完整翻卷火团，第 9 帧后侵蚀消散，末尾为透明帧。
- Atlas 是实际 Blender EEVEE 透明渲染 16 个 3D 姿态后无色彩转换拼接；背景、剑、地面没有烘入 atlas。
- Blender 演示主弧外缘半径 2.2，角度 160°。该值用于美术检视，不修改游戏命中逻辑；运行时采用主任务配置。
- HDR body 和普通 sRGB atlas 需要各自的材质颜色/能量处理。不要把 atlas 当作 HDR 或把 EXR 当成 sRGB。

## Blender 播放

打开 `fire_slash_v002.blend`，在 1–96 帧播放；1–48 帧快速挥砍，49–96 帧放慢展示。源工程用 11 个主弧形状键记录角度推进，并保留可编辑剑控制器、噪声相位和消散曲线。

短片里的 3D 火团也会逐帧变形，制作脚本保留这部分几何生成。源工程播放有主弧/剑动画及火团材质变化；需要改动火团具体形变后重新运行脚本输出片段。

## 重建顺序

1. Blender 后台运行 `scripts/art_build.py -- body`：原生建材质、宽弧、长剑、灯光，实际 bake body 并渲染 hero。
2. Blender 后台运行 `scripts/art_build.py -- atlas`：实际渲染 16 个透明火团姿态。
3. Python + Pillow 运行 `scripts/art_pack_atlas.py`：逐帧原样拼接 atlas；没有生成或重绘图像内容。
4. Blender 后台运行 `scripts/art_build.py -- movie`，再运行 `scripts/art_encode_movie.py`：渲染并编码真实片段。
5. Blender 后台运行 `scripts/art_finalize_source.py`：保存可播放的主弧源工程，并恢复 atlas 源文件为可见姿态。

精确文件校验和见 `art_bake_manifest.json`、`art_atlas_validation.json`。整合后的实际画面、暂停和时序验证由主任务报告。
