# 【Godot 3D特效】系列（极客像素喵 搬运）笔记

## 动态火焰特效（从零开始）BV19NcnzYEpj
- 贴图来源：在线贴图生成器（类似 Effect Texture Maker，带“爆炸2”等预设，可导出带透明通道 PNG / 序列帧图集）；推荐 “Textures for VFX – Database”（GDC 演讲配套的 Notion 资源库：贴图包、笔刷、生成器、教程）。
- 单个 GPUParticles3D 做火：材质 Unshaded + 透明 + Vertex Color as Albedo + Particle Billboard；**一个 Color Ramp 从白黄 → 橙 → 红 → 深灰黑**，火焰往上走自然变成顶上的烟（同一系统、普通透明混合）。
- Alpha Curve 淡入淡出、Scale Curve 由小变大；**闪烁感靠极随机的参数**（缩放、角度、寿命随机度拉满）。
- 第二个系统做火星：Ring 发射形状（贴地一圈），往上加速、寿命短的小亮点。
- OmniLight3D 橙色 + AnimationPlayer 做亮度闪烁。
- 变体：静态贴图版 vs 序列帧动画版（Anim_A，flipbook 播放生成器导出的火焰动画）。

## 地刺（土系技能）BV12YTezVEqm（46 分钟）
- 模型：Sketchfab 下载免费（CC）的低多边形岩石包，在 Godot 里把单块石头拉长、旋转成尖刺，每根尖刺一个 MeshInstance（可加 StaticBody + 碰撞，让地刺真的挡路/伤人）。
- 动画：**AnimationPlayer 给每根尖刺打位置关键帧**，从地下依次冒出（沿一条线错开时间，形成“一路刺过去”的波），停留后缩回地下。
- 地面裂纹：两张贴图（颜色 + 粗糙度/法线），用 godotshaders.com 上的“Decal shader”（假贴花，兼容 Compatibility/移动端）挂在每根尖刺脚下的方块上，或用 Godot 自带 Decal；每根尖刺一个 GroundMark，随尖刺一起出现、最后淡出。
- 碎石：GPUParticles3D 的 Draw Pass 用碎石 mesh，爆发向上飞、受重力、开碰撞落在地上（GPUParticlesCollision）。
- 尘土：smoke_dust 粒子（烟团贴图、灰褐色、慢速扩散）在尖刺根部。
- 要点：**实体模型 + 动画 + 贴花 + 碎石 + 尘** 五层，土系不靠发光，靠实体和尘土。

## 激光束 BV1R5TezxEfT（27 分钟）
- 光束主体：GPUParticles3D amount=1、寿命很长，Draw Pass 用拉长的圆柱（mesh 横放），这样能用粒子的 Scale Curve / Color 控制它；材质是可视化着色器 dynamic_shader：
  两张噪声贴图（T_VFX_Noise）各自 UV 平移（Time × 速度，方向/速度不同）→ 相乘得到流动的能量纹理；× 横向渐变遮罩（圆柱两侧淡出，GradientTexture2D）；× 粒子颜色（Input.COLOR，HDR 紫色）→ Albedo/Alpha，unshaded 加色。
- 叠两层：外层粗、暗、慢的 BeamEnergy；内层细、亮、快的核心 → 有体积感。
- 发射口：Splash Energy 圆环（简单着色器 + GetBillboardMatrix 让模型朝镜头）、Flare 星光闪烁、飞溅小火花粒子（向四周喷）。
- 开关：AnimationPlayer 给各层 emitting / scale 打关键帧：光束从 0 长度伸出 → 维持 → 收细消失；发射口先闪再持续。
- 可以直接借到 ShopGame：持续施法类技能（光束、喷火）都是“粒子承载 mesh + 双噪声流动着色器 + 遮罩”。

## 3D 闪电着色器（落雷）BV1eWMHzREzL（23 分钟）
- Blender 做一个网格、三块表面：竖直扭曲的长条（雷柱）、底部喇叭口圆锥（落地溅射波）、地面平面（落点光斑）。导出 obj，作为粒子 Draw Pass，每块表面一个材质。
- 闪电贴图：Photoshop 黑底上用白色硬笔刷画折线（几笔就够）。
- 雷柱着色器：贴图 R → **SmoothStep(edge0, edge0+0.1)**，阈值由粒子 Input.COLOR.a 驱动 → 粒子 Color Ramp 的 alpha 从 0→1→0 就变成“雷从细到粗再消失”；UV 平移让雷纹抖动；× 颜色参数（HDR 蓝）。
- 溅射波（wave）着色器：竖向渐变贴图做遮罩 + 平移；地面光斑（mark）：径向柔光贴图。
- 所有颜色、阈值做成着色器参数（uniform）→ 一套材质换成红色就是另一种雷。
- 要点：**用 smoothstep 阈值做“出现/消失”比单纯 alpha 淡出更有能量感**（边缘锐利，形状在变）。

## 风格化火焰着色器（原神篝火参考）BV1CAMJzhE4p（22 分钟）
- 贴图：Photoshop 里拿火焰照片/素材做成灰度火焰形状图 + 一张扭曲（distortion）噪声图。
- 着色器：扭曲图 UV 向上平移 → 取值去偏移火焰形状图的 UV（火焰扭动、往上窜）；× 竖向渐变遮罩（GradientTexture2D，底部实、顶部消失）；
  再用 step / smoothstep 把灰度切成两三档 → 外圈橙、内芯黄的**卡通分层色**（风格化的关键，不是连续渐变）。
- 一个粒子（amount 少、寿命长）承载这块火面，另一个系统用独立的烟着色器做顶上的烟，再加零星火星。
- 问题：俯视时能看出是平面贴图 → 改用 **2~3 片十字交叉的面片 mesh** 做 Draw Pass（或多片旋转叠加），俯视角也有体积。
- 对 ShopGame（俯视角）很重要：俯视下 billboard/单片面会穿帮，持续存在的火（燃烧地面、篝火）用十字面片。

## 魔法治疗区域 BV1FQMMzFEha（25 分钟）
- 三部分：花朵模型动画 → 地面法阵 → 粒子。
- 花：Blender 里做花瓣（变形贴合到球面上排成一圈），用形态键/动画做“绽放”，导出 glb 带动画；着色器 = GradientTexture2D（青→绿）当颜色 + 发光，半透明。
- 地面法阵：扁平圆盘 mesh + 圆环着色器（径向渐变得到发光外圈，内部淡淡的填充，可加噪声流动）。
- 粒子：Ring 发射形状沿法阵边缘冒出往上飘的光点/星星；“十字（+）”治疗符号粒子往上升；一个大柔光团。简单着色器 = 贴图 × 粒子颜色。
- 颜色统一一个色相（青绿 = 治疗），亮度分层：外圈最亮、花次之、粒子点缀。
- 对 ShopGame：区域类增益（治疗/护盾区）= “地面法阵 + 中心主体模型动画 + 边缘上升粒子”。

## 打击与碰撞特效 BV1SjNLzsEC7（18 分钟）
- 闪光：GPUParticles3D amount 1、lifetime 0.25、one_shot、explosiveness 1，Angle 随机 −180~180（每次闪光角度不同），简单着色器 = 闪光贴图 × 粒子颜色。
- 火花：Particle Flags 开 **Align Y**（沿速度拉长），初速度大、Alpha Curve 快速淡出、Scale 0.3 左右。
- 地面裂痕 Decal（颜色 + 自发光两张贴图），随打击出现。
- 打包：hit_vfx.tscn 根节点下挂 AnimationPlayer，**动画设为 Autoplay on Load**，里面在第 0 帧把各粒子 emitting 打开 → 场景一实例化就自动播完，生成方不用关心内部。
- 触发：角色手上挂 BoneAttachment3D + Area3D/碰撞体，body_entered 时在接触点实例化 hit_vfx，播完 queue_free。
- 和第一门课的 PlayParticleSystems 延迟表是同一个思路（一次性播放的预制体）。

## 武器元素光效（火焰附魔剑）BV1wxgyz6EkA（21 分钟）—— 和 ShopGame 元素武器直接相关
- **附魔光层用 Material Overlay**（GeometryInstance3D 的材质覆盖层，叠在原材质上再画一遍），不改武器原材质 → 换武器、换元素都只换覆盖层。
- 覆盖层着色器（arcus_shader）：噪声贴图 UV 平移（Time × 速度）× **剑身遮罩**（在 Krita 里照着武器 UV 布局把刀刃涂白、柄涂黑）× 颜色参数 × 强度参数 → Emission + Alpha（加色）。只有刃在流火光，柄不亮。
- 剑身火焰：GPUParticles3D，Emission Shape 用 **Points（从剑的网格生成发射点）**，粒子贴图是 5×5 的火焰序列帧（Particles Anim 设 H/V Frames=5，播放一遍），Particle Billboard；局部坐标关掉 → 挥剑时火焰留在后面。
- 环绕小火苗（small fields）：Ring 发射 + **Orbit Velocity（轨道速度）**，绕着剑身螺旋上升。
- 换元素：覆盖层颜色 + 粒子贴图/颜色一换就是冰/雷。
- 对照我做的火焰太刀：我是用着色器在刀身上画 heat，这里是 Material Overlay 方案——**更适合接入游戏**（不需要每把武器有特制材质）；发射点从网格生成也比我手摆的 Box 更贴刀形。

## 龙卷风（风）BV1kC3BzoExg（24 分钟）
- Blender：圆柱变形成上宽下窄、带扭曲的漏斗，**先用棋盘/笑脸测试贴图检查 UV 是否连续、无拉伸**（UV 是流动着色器好不好看的关键）。
- 着色器：BaseTexture（噪声）按 Speed（vec2，横向为主 → 绕圈流动）平移；再用一张 Distortion Texture 平移后扰动 UV（风的乱流）；× 竖向渐变遮罩（顶底淡出）；强度 → GradientTexture1D 映射颜色（白—浅蓝）；Opacity 参数；cull 关闭（内外都看得到）。
- AnimationPlayer：整个龙卷风 mesh 循环绕 Y 轴旋转（Spinning）。
- 底部 base_waves：粒子承载的环形/喇叭 mesh 在底部一圈圈扩散，开 Local Coords 跟着龙卷风走；外加尘土/碎屑。
- 说明 GPUParticles3D 针对 PC，移动端用 CPUParticles3D。
- 对 ShopGame：风/旋风类元素可直接照这个结构做，同一个漏斗 mesh 换贴图颜色可做火龙卷。

## 特效贴图制作指南（标题叫 PBR，其实讲 VFX 贴图）BV1iBGC6JEE4（29 分钟）
- 免费资源：Textures for VFX 数据库里的噪声包、火焰/爆炸序列帧包、魔法阵贴图等，先找现成的。
- Krita：黑底白画；软笔刷 + 涂抹/运动模糊做拉丝条纹（刀光、风、能量条带）；G'MIC 滤镜插件可一键生成球体高光、光晕等。
- 节点式 2D 工具（Draw Shape + Canvas + Blend 之类）做图案并直接导出序列帧粒子图。
- Blender 烟雾/火焰模拟渲染成序列帧（爆炸），注意大模拟很吃电脑。
- 原则：贴图都做成灰度、边缘留黑（透明），颜色交给引擎。
