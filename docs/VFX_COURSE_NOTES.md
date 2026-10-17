# Godot 游戏特效课笔记（余烬CG 搬运，原 Udemy "Godot VFX for Games"）

## 01 课程简介
- 特效类型：环境、技能（AOE/投射物/增益诅咒）、受击、UI；三要素：形状/时间节奏(timing)/颜色。
- 工具：Godot 粒子 + 可视化着色器；纹理用 Krita 手绘 + Material Maker（节点式，免费 SD 替代）。

## 02 火花
- 贴图：Material Maker 做软圆点：Shape(Circle) → Gaussian Blur(sigma 50) → Colorize（白→透明），导出 PNG。
- 材质：StandardMaterial3D 无光照（unshaded）、透明、加色混合、Billboard=Particle Billboard，Vertex Color as Albedo；颜色用 HDR（>1）配合 Glow 发光。
- GPUParticles3D：one_shot、explosiveness=1、amount≈40、lifetime 短；velocity 方向+spread（圆锥）、初速度 5~10。
- 拉长火花：Scale Curve 用 X/Y 分开曲线（Curve XYZ），一轴大一轴小；粒子朝速度方向对齐（Particle Flags: align Y to velocity）→ 拉成线条；Scale 曲线后段下降→快结束时缩小。
- 重力、阻尼 Damping；碰撞(Collision) 让火花在地面弹跳，摩擦/反弹可调。
- Process material 改前要“Make Unique”，复制系统时避免共享。

## 03 AOE 概览
- 先画草图，分三阶段：**Anticipation 预兆**（粒子聚拢、亮光闪、圆柱+着色器）→ **Climax 爆发**（半球护罩着色器、圆环、冲击波、粒子）→ **Dissipation 消散**（漂浮粒子、地面裂纹、残余火焰/魔法）。
- 脚本 PlayParticleSystems.gd：收集所有子粒子，按“名字→延迟秒”字典依次 restart()，统一一键播放；
  另一个脚本按鼠标射线命中点生成 AOE 预制体，lifetime 后 queue_free。
- 粒子改 lifetime 0.2 等用于测试节奏。

## 04 蓝色 AOE（82 分钟，主课）
一个 AOE 由约 10 个独立的 GPUParticles3D 叠成，每层只做一件事，用 PlayParticleSystems 的延迟表排时间
（AnticipationParticles 0 / CircleGround 0 / Cylinder 0 / ImpactFlare 0.5 / ImpactParticles 0.5 / HalfSphere 0.5 / ShockwaveGround / ShockwaveRings / GroundMarks…）。
1. **蓄力粒子**：球形发射，Radial Accel 为负并用曲线控制（先慢后快往中心吸），Damping≈3，Scale Curve，**Alpha Curve 末尾淡出**；QuadMesh + 软圆贴图、Vertex Color as Albedo、HDR 蓝色。
2. **光柱（圆柱）**：Blender 建开口圆柱（UV 竖向展开）导出 obj，作为粒子 Draw Pass（amount=1）。可视化着色器：
   Texture2DParameter(主纹理) ← UVFunc(Panning, 偏移 = Time × speed 参数)；再乘一张**竖向渐变遮罩**（上下淡出，贴图 Repeat 关掉才平滑）；
   乘 Input.COLOR（粒子颜色/曲线可驱动）→ Albedo + Alpha。主纹理用 Material Maker：Dirt 噪声 → Colorize → Blur（可平铺）。
   粒子 Scale Curve 让它长出/收回，Color Ramp 控制颜色和透明度（作者说比单独 Alpha Curve 好用）。
3. **地面圆环**：两个 Circle 相减（A−B）→ Gaussian Blur → Colorize 得到软圆环；平放的 Quad，不做 billboard。
4. **爆点星光 Flare**：Circle Splatter（20 个细长形状，随机旋转/缩放）× 径向渐变 → 星芒贴图；Scale Curve 极快弹出再收；注意贴图边缘别被裁硬。
5. **爆发火花**：沿用第 2 课火花，大小 0.1~0.3。
6. **半球护罩**：Blender 半球 mesh；贴图 = Voronoi → Tones Step → Warp(FBM 噪声) → Blur（流动的网状纹理），UV 平移；Color Ramp 驱动淡入淡出。
7. **冲击波地面环**：圆环贴图，颜色 HDR（蓝通道=2）发光；Scale Curve 从小快速放大。
8. **冲击波竖环**：Blender 窄圆柱环 mesh；顶点着色器用 **GetBillboardMatrix(Particles) → Model View Matrix** 让 mesh 也能 billboard；
   贴图 Polygon + Warp(FBM) 得到破碎边缘的条带。
9. **地面焦痕/暗斑**：Anisotropic Noise（ScaleY 很大 → 拉丝条纹）、Slope Blur 做烟状斑块；暗色混合留在地上，最后淡出（Dissipation 阶段）。
- 要点：每层贴图都在 Material Maker 里几分钟做完；颜色一律用 HDR + Glow；所有层都是 one_shot，靠延迟错开节奏。

## 05 火焰 AOE（变体）
- 复制蓝色 AOE，主要换颜色（青→黄/橙，HDR）和贴图；结构不变 → **一套结构 + 换色换贴图 = 多个元素版本**。
- 新 Flare02：细长 Circle 经 Transform（ScaleX 0.1）做成十字星，再乘柔光圆。
- **火焰着色器（溶解/侵蚀 erosion）**：MainTex（Krita 手绘的火焰团块）+ DissolveTex（噪声，UVFunc 平移，参数 DissolveTiling / DissolveSpeed），
  用 DissolveAmount 做阈值 → 火焰边缘被噪声“吃掉”。最后乘 Input.COLOR 的完整 RGBA（不是只接 RGB）→ 粒子的颜色曲线/alpha 曲线就能驱动溶解和淡出。
- Krita 手绘：2048² 黑底，软笔刷画白色团块，用橡皮擦出火舌缺口，图层样式加外发光。
- 烟：同一个火焰着色器，颜色设成纯黑（暗色烟），explosiveness 0.5，lifetime 1.2。
- 最后做一个 AOE 预制体，点击地面生成。

## 06 投射物概览
- 草图：投射物 = 粒子 + 拖尾(Trail) + Capsule1（着色器 遮罩+UV滚动）+ Capsule2 + Capsule3（闪电版）；另配 **枪口(Muzzle)** 和 **撞击(Impact)** 两个独立特效。
- 贴图：无缝电流纹理、撞击纹理。
- SpawnProjectile.gd：fire_rate、projectile_lifetime、projectile_prefab、rotate_to_mouse、fire_point；按住开火。
- ProjectileMove.gd：RigidBody3D，contact_monitor=true、max_contacts_reported=1；_integrate_forces 里 linear_velocity = direction*speed；
  碰撞时在接触点+法线生成 impact 再 queue_free；出生时在枪口生成 muzzle，2 秒后释放。
- 拖尾用 Godot 的 GPU Trails 插件（或 GPUParticles 的 Trails）。

## 07 火焰投射物
- Blender 用球体拉长做**胶囊 mesh**（UV 展开），作粒子 Draw Pass。
- 三层胶囊：CapsuleBright（亮黄白核）/ CapsuleDark（橙暗外壳，独立材质）/ CapsuleSmall，复用 AOE 的滚动着色器（Speed vec2、MainTex、Mask 渐变）→ 火球表面像在向后流动。
- 前端一个**亮白发光点**（球形 billboard，HDR）做“头”，读起来像高速火球。
- FloatingParticles：球形发射小火星，Turbulence 开启（噪声强度≈1、scale 0.1）→ 围着火球乱飘。
- Smoke：火焰溶解着色器的黑色版本，粒子 local_coords 关掉 → **烟留在身后成尾迹**；Alpha Curve 先淡入再淡出。
- Trail：GPUTrail3D（Length 12~15，Length Seconds 0.2~0.3），TrailBright + TrailDark 两条，贴图滚动，Curve 控制粗细从头到尾变细；**Use Red as Alpha**（灰度贴图用 R 通道当透明度）。
- 所有层挂在 RigidBody 预制体下，ProjectileMove 推着走；颜色改 R/G 通道即可换色。

## 08 枪口特效（Muzzle）
- 直接从 AOE 里复制现成层（Ctrl+C/V 到 vfx_Projectile01_Muzzle 下）再改小改快 → **特效层可以跨特效复用**。
- 层：QuickImpact（极短闪一下的星芒）/ Shockwave（小圆环快速放大）/ Flash（柔光点）/ BeamDark / ParticlesBurstBright + ParticlesBurstDark（往前喷的火星，Turbulence 弱一点）。
- 全部 one_shot，Emitting 默认关；根节点挂 PlayParticleSystems，延迟表全 0 或差几十毫秒；Alpha Curve 快进慢出。
- 时长 0.2~0.5 秒即可，枪口只是“开火的一下”，不要抢投射物的戏。

## 09 撞击特效（Impact）
- 层：Flash / Shockwave / BeamDark / ImpactMarkBright + ImpactMarkDark（贴在表面的焦痕）/ ImpactParticlesBright + Dark / Fire（小火焰团，向法线方向喷，初速度提高）。
- **整个 Impact 的朝向 = 碰撞法线**：根节点按法线 look_at，平面层（冲击环、焦痕）旋转 90° 让它“贴合碰撞表面”。
- Flash 用 Particle Billboard + Keep Scale；焦痕不 billboard，暗色、寿命长、最后淡出。
- 火焰小团给撞击“添细节”：同一个溶解火焰着色器。

## 10 闪电投射物（变体）
- Blender 新做**子弹头形 mesh**（胶囊一端用 S 缩尖），替换原胶囊 → 外形更锋利，读起来“快”。
- 换蓝色 HDR + 新贴图：Material Maker 里 **Polygon → Transform(ScaleX 16, ScaleY 0.45) 拉成细长条 → Warp(Voronoi) 扭曲 → Math pow(17) 收细** → 横向锯齿电光条带。
- 拖尾换电光贴图，Use Red as Alpha；ProjectileMove 增加 trails 数组：**撞击时把拖尾从投射物上拆下来留在原地自然消失**，不随 queue_free 一起瞬间没了。

## 11 闪电枪口 + 撞击
- 复制火焰版的 Muzzle/Impact，改颜色为蓝白、换电光贴图；新做一张“撞击印记”贴图（不规则电痕）。
- 同一结构三件套（投射物/枪口/撞击）× 换色换贴图 = 一个新元素。

## 12 总结
- 作者展示更多可练方向：全屏着色器、全息、曲线路径、爪击、风格化火焰等；课程工程可自由使用。

---

## 方法论提炼（对 ShopGame 有用的部分）
1. **一个特效 = 多个单一职责的层**：亮核 + 暗衬 + 闪光 + 冲击环 + 火星 + 残留（焦痕/烟）。每层单独调，叠起来才有厚度。暗层（BeamDark/ParticlesDark/黑烟）很关键：给亮色一个背景，否则在亮地面上发白看不清。
2. **三段节奏**：预兆（聚拢/蓄力）→ 爆发（0.1~0.2 秒内最亮最大）→ 消散（慢慢淡出、留痕迹）。用一个“名字→延迟”表统一触发，表放资源里可调。
3. **曲线比数值重要**：Scale Curve 弹出快、收回慢；Alpha/Color Ramp 快进慢出；Radial Accel 用曲线做“先慢后快吸入”。
4. **少量通用着色器**：①UV 滚动 + 渐变遮罩 × 粒子颜色（光柱/护罩/胶囊/拖尾）②溶解火焰（MainTex + 噪声阈值，粒子 alpha 驱动溶解）③mesh billboard（GetBillboardMatrix）。所有着色器都乘 Input.COLOR 的 RGBA，让粒子曲线能控制一切。
5. **贴图程序化**：Material Maker 几分钟一张：软圆点、圆环、星芒、网格流动纹理、电光条、拉丝焦痕。全是灰度图，颜色交给粒子 + HDR。
6. **HDR + Glow** 出发光；加色混合做光，普通 alpha 混合做烟/暗层。
7. **复用**：同一套结构换颜色和贴图 = 新元素（蓝 AOE → 火 AOE；火球 → 闪电）。
8. 撞击朝向法线；拖尾在撞击时脱离父节点自然消失；粒子 local_coords 关掉让烟留在身后。
