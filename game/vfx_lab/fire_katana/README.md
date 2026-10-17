# 火焰太刀特效实验室

独立的特效演示空间：一把悬空太刀反复挥砍木桩，用来调火元素刀光和火焰受击。
**没有被任何游戏代码引用**，满意后再按下面“接入游戏”一节迁过去。

## 怎么看

在 Godot 编辑器里打开 `fire_katana_demo.tscn`，按 F6（运行当前场景）。

| 按键 | 作用 |
|---|---|
| 空格 | 暂停/继续 |
| 1–4 | 只放某一招（斜劈 / 横斩 / 上撩 / 蓄力重劈） |
| 0 | 四招循环 |
| S | 慢放（0.3 倍） |
| L | 白天/夜晚（检查亮暗背景下都看得清） |
| C | 机位：展示 / 游戏俯视角 / 近景 |
| 右键拖动、滚轮 | 旋转、缩放镜头 |

调色和游戏战斗场景一致（AgX，对比度 1.5，曝光 1.19）；演示场景开了辉光，游戏里目前没开。

## 特效分层（照 B 站 Godot 特效课的做法）

**挥刀**（三段：预兆 → 爆发 → 消散）
- 蓄力：刀往后再拉一点，刀身从刃口开始烧红（`katana_blade.gdshader` 的 `heat`），火星往刀上聚（Gather），刀身冒火（Flames），刀上的火光照亮周围。
- 挥砍：刀光拖尾三层共用一条带子：烟（最底，透明混合）/ 火焰本体（HDR 橙红，噪声咬出火舌、越老越红、往上飘）/ 白热外沿细线（加色）。沿刀弧补出火团（ArcFlames），挥砍时甩出火星（Embers）。
- 收刀：刀身慢慢冷却变暗。

**受击**（`vfx/fire_impact.tscn`，出场时间表 `presets/fire_impact_timeline.tres`）
星芒闪光、柔光、刀口月牙（贴在挥砍平面上）、冲击环、飞溅火星（会在地上弹）、白热火核、翻滚火团、黑烟、余烬、火光、木桩焦痕（先亮后冷却再淡出）。另外有命中顿帧、镜头震动和木桩晃动。

## 文件

- `presets/`：四招的节奏和强度（`slash_*.tres`），受击时间表，白天/夜晚光照。**改手感先改这里**。
- `materials/`：所有材质，颜色、亮度、寿命都在这些 .tres 里。
- `shaders/`：刀身、刀柄、刀光拖尾、火团/烟、发光粒子。
- `scripts/`：挥刀（`katana_rig.gd`）、拖尾（`fire_ribbon_trail.gd`）、刀身火（`fire_blade_fx.gd`）、分层播放（`vfx_sequence_player.gd`）、演示控制。
- `tools/build_assets.gd`：生成灰度特效贴图和太刀网格；`tools/build_scenes.gd`：生成材质、预制体和演示场景（会覆盖 materials/presets/vfx 和场景文件，在编辑器里手调过的数值要先同步回这个脚本）。
- `tools/encode_video.py`：把录屏帧拼成 mp4。

重新生成：
```
Godot --headless --path game --script res://vfx_lab/fire_katana/tools/build_assets.gd
Godot --headless --path game --import
Godot --headless --path game --script res://vfx_lab/fire_katana/tools/build_scenes.gd
```
录屏（-- 后面可加 look=1 白天、camera=0/1/2、move=1..4、slow=1）：
```
Godot --path game --resolution 1280x720 --write-movie <目录>/f.png --fixed-fps 60 --quit-after 560 res://vfx_lab/fire_katana/fire_katana_demo.tscn
```

## 接入游戏时要做的事（还没做）

- 刀光拖尾和刀弧火团接到角色武器的刀根/刀尖挂点上，补采样用武器动画的骨骼插值代替 `katana_rig` 的解析姿态。
- 受击预制体由命中事件生成，朝向用“刀的运动方向 + 刀身方向”。
- 游戏场景目前关着辉光：要么给战斗场景开辉光，要么把发光层亮度再调一档。
