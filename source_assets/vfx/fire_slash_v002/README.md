# 焰浪 · 火焰重斩（Blender → Godot）

本轮制作目标：更饱满的火焰主体、更清楚的层次与大幅挥砍轮廓，并加入真实训练场供试玩。它是新增外观选项；原来的金色默认刀光和其他候选保留。

## 试玩

店铺按 **F6** 进入训练场，在右上角「刀光测试」选择第一行右侧的 **焰浪 · 火焰重斩**。共 12 个选项。左键攻击，L 切换中英；新效果英文名 `Inferno · Cleave`，稳定 ID 为 `fire_slash_v002`。

- [Godot 12 秒实机录像](previews/fire_combat_v002.mp4)
- [慢动作实机截图](previews/slow_endpoint.png)
- [Blender 3.2 秒实际渲染动画](blender_previews/fire_slash_v002_motion.mp4)
- [Blender 美术检视静帧](blender_previews/fire_slash_v002_hero.png)

Godot 录像包含正常单斩、0.4 倍速近景、三连击、2.35 米处真实目标命中。为便于比较，敌人 AI 决策暂停；角色、技能时间线、扣血、击退和受击反馈使用现有游戏代码。录像没有接入新的骨骼挥剑动作。详细说明见 [捕获报告](reports/capture_report.md)。

## 本轮分层

1. **宽火焰弧面**：连续弯月承担主要体量，内部有黄橙热流、红色冷槽、定向卷纹和撕裂孔洞。
2. **窄热刃**：贴合主弧外沿，快速衰减，让斩击峰值清楚，随后露出火体和尾效。
3. **动画火舌**：Blender 中实际建立变形的立体火团，透明渲染为 16 帧；游戏沿剑扫过处发射，错开角度、大小与时刻。
4. **长短火星**：短亮点与拉长火屑形成不同速度和尺度。
5. **淡烟与短促局部照明**：烟稍晚显露，灯光随挥击短暂照亮周围，尾效按各自寿命退场。

迭代中修正了两处实际画面问题：火焰卡片数量过多、同向重复，调整为更少且拉长/错向的火舌；新烘焙纹理的径向上下方向曾与共享旧 Shader 约定相反，现使用本选项专属 `body.gdshader` 正确采样，热刃与外沿贴合。旧特效 Shader 与贴图未被改动。

## 源文件与配置

| 位置 | 用途 |
|---|---|
| [blender/fire_slash_v002.blend](blender/fire_slash_v002.blend) | 可编辑材质、宽弧、剑、灯光、相机、160° 形状键和挥剑动画；1–96 帧播放 |
| [blender/flame_atlas_source.blend](blender/flame_atlas_source.blend) | 立体火团模型、材质、透明渲染相机 |
| `scripts/art_build.py` | 原生 Blender 制作、实际烘焙/渲染重建脚本 |
| `bakes/` | 四帧 2048×512 HDR emission EXR 与对应 mask PNG，16 帧透明火团及 1024² atlas |
| `game/assets/vfx/fire_slash_v002/` | 九张运行时纹理；启用 mipmaps、VRAM 压缩，EXR 保留线性 HDR |
| `game/presentation/combat/fx/fire_slash_v002/fire_slash.tscn` | 独立效果入口，尾迹、四个发射器与灯光配置 |
| 同目录 `body.tres` / `hot_edge.tres` | 主体贴图、亮度，热刃位置/宽度/衰减 |
| 同目录 `fire_effect.gd` | 多层启停、暂停、清理、独立材质时钟与灯光包络 |
| `game/presentation/combat/effect_picker/palette.tres` | 训练场可选项 |

Blender 源材质通过真实 Cycles EMIT 烘焙，火团 atlas 来自真实 EEVEE 透明渲染。未使用生成式图片，也没有安装额外插件或使用网上作者的工程/贴图。[美术制作细节](reports/art_notes.md)。

## 范围、时序和架构

- 玩法范围继续由 JSON 控制：三段 **2.5 / 2.5 / 2.8 米、160°**；本轮没有改动这些数值或伤害/冷却。
- 主火弧网格外缘 **2.208 / 2.208 / 2.508 米**，位于当前命中范围内。离散火星、烟和残留尾迹是装饰，不产生持续伤害。
- 新发射只发生在真实能力的 active 阶段。热刃先淡出，火舌约 0.24 秒、主尾迹约 0.26 秒、火星/烟最长约 0.42 秒。
- 配置容量：138 个短火星、28 个火舌、42 个长火星、22 个烟粒子，合计最多 230 个粒子槽；不表示每帧全部同时可见。两个主弧绘制层复用同一几何，另有一个无阴影短时光源。
- 切换、取消、死亡、暂停都通过现有 ActorView 接口处理。修复了死亡后 ActorView 提前返回造成尾效未收到暂停状态的问题。
- 没有新增燃烧状态、伤害类型、全局命中停顿、镜头震动或音效。攻击力度在本轮通过视觉层次与峰值/消散时序改善，是否满意仍以用户试玩为准。

## 网上参考的实际边界

主要参考 [De Andre Martin — Fire Sword Slash VFX](https://goldmario100.artstation.com/projects/zDrmJm) 的作者说明：随剑运动的火焰、滞后溶解层，以及亮黄到红的热度变化。也查阅了其他作者的分层与侵蚀讨论。

**本轮没有成功播放网上内嵌动画。** 浏览器读取与策略检查受阻，具体情况记录于 [网页调研](references/web_reference_research.md)。因此不声称逐帧看过或复刻了参考视频；交付的 Blender/Godot 动画均为本项目实际制作与验证结果。

## 已运行的验证

- 美术验证：两份 `.blend` 重新打开、八张主弧源/运行纹理尺寸与哈希、atlas RGBA/末帧透明，以及 Blender MP4 帧数通过。[art_validation.json](reports/art_validation.json)
- 新效果生命周期：**98 项检查，failures=[]**，包含多层暂停、材质/灯光时钟、取消、死亡、尾效消散、跨挥砍无连接、切换释放与实例隔离。[运行时报告](reports/runtime_validation.md)
- 12 项×3 招共 **36 组**主刀光范围测量通过；原有刀光尺寸仍与保留基线一致。[reach_after.json](reports/reach_after.json)
- 所有 12 个按钮实际安装对应场景；暂停切换、点击不穿透、1280×800 中英文布局通过。[picker_validation.json](reports/picker_validation.json)
- 原金色刀光的几何、消散、取消与材质隔离回归通过：`golden_regression.log`。
- 实机录制 6 次真实施放，三连顺序正确；2.35 米处 `slash.1` 造成 16 点伤害，HP 46→30，`capture_result.json failures=[]`。
- 内容构建 **119 个双语 key**，JSON/PO 一致；导入无错误。
- Windows PCK 导出成功；从 builds 目录独立启动训练场及新火焰自动展示，实际渲染正常，无运行错误。此项是资源/启动检查，不代表完整性能测试。

Godot 实机片为 1280×800 / 60 fps / 12 秒固定步长录制；Blender 片为 960×600 / 30 fps / 96 帧。帧率指视频输出规格，不作为游戏性能基准。
