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
- 刀一直在烧（附魔武器，`katana_rig.gd` 的 `heat_floor`）：几百个带火丝的火团（`fire_puffs.png` 图集 + `vfx_fire_puff.gdshader`）从刀面上的发射点（`generated/blade_points.res`，按刀身截面采样）冒出，按寿命白黄→橙→红→黑烟。火团在世界坐标里，挥刀时自然甩在后面成拖尾。
- 刀身附魔火层：刀身材质的 next_pass（`katana_fire_overlay.gdshader`），火纹从刃口按阈值长出、沿刀身往上流。
- 蓄力：刀往后再拉，热度上升（刀身发红、火更旺），火星往刀上聚（Gather）。
- 挥砍：每帧按解析姿态补采样，在刀经过的每个位置补发火团（ArcFlames），所以再快的挥砍拖尾也是连续的一整团火；下面垫一层半透明火焰带和淡烟带把它们连起来；甩出火星（Embers）。
- 收刀：热度回落到常燃水平。

**受击**（`vfx/fire_impact.tscn`，出场时间表 `presets/fire_impact_timeline.tres`）
星芒闪光、柔光、刀口月牙（贴在挥砍平面上）、冲击环、飞溅火星（会在地上弹）、白热火核、几十个火团爆开、刀口余火继续烧 1.6 秒、黑烟、余烬、火光、木桩焦痕（先亮后冷却再淡出）。另外有命中顿帧、镜头震动和木桩晃动。

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

## 冰 / 雷（只在演示里，未接入游戏）

演示里按 **E** 在火 / 冰 / 雷之间切换（录屏参数 `element=ice` / `element=thunder`）。资源在 `vfx_lab/elemental_enchants/`：
- **冰**（`ice_enchant.tscn`）：刀身结霜覆盖层（从刃口长出、夹着闪烁冰晶）、往下沉的寒气、冰晶闪光；挥刀留下寒雾，并甩出会落地弹跳的立体冰碴。受击（`ice_impact.tscn`）：命中点冒出一簇冰刺，停半秒后碎成冰碴落地，配霜花贴花、寒雾、冰屑闪光。
- **雷**（`thunder_enchant.tscn`）：刀身电纹（位置跳变的细亮线）、刀身上不停跳的小电弧、偶尔窜到空中；挥刀沿扇面留下分叉闪电残影和电火花。受击（`thunder_impact.tscn`）：落雷从上方劈下（再闪两次、每次换路径），电弧在命中点周围爬、窜到地面，配电火花、蓝色焦痕、强闪光。
- **土**（`earth_enchant.tscn`）：刀身从刀背一侧结出岩壳、岩缝透金光（覆盖层），小碎石悬浮绕刀、细沙往下漏、带尘土；挥刀留下尘土拖尾并甩出会落地弹跳的碎石。受击（`earth_impact.tscn`）：横向挥砍时一排岩刺沿挥砍方向依次从地里顶出，竖劈时围着目标冒一圈（`spike_eruption.gd`），停一会儿再缩回地下；地上留一片发金光的裂纹、碎石四溅、扬起一圈尘土。
- 附魔脚本都继承 `enchant_base.gd`，和游戏里 `fire_enchant.gd` 同一套约定（挂在 ActorView.blade 下、`configure_blade` + `tick`），以后接入只需在 `training_style.tres` 的 `element_weapon_enchants` 里加一行；刀身覆盖层（霜/电纹）接入时要挂到游戏剑模型的材质上（游戏剑的 UV 和演示太刀不同，需要另调遮罩）。
- 重新生成：`build_enchants.gd -- textures` → `--import` → `build_enchants.gd -- scenes` → 再跑一次本目录的 `build_scenes.gd`。

## 已接入游戏（2026-10-17）

剑上常驻的火焰附魔已接入：`presentation/combat/fx/fire_enchant_v001/`（贴图、着色器复制过去，不依赖本目录）。
- 规则：构筑里**第一个**元素是火 → 主角的剑一直燃烧（`presentation/builds/weapon_enchant_rule.gd`）；第二个元素暂不顶替。
- 配置：`training_style.tres` 的 `element_weapon_enchants`（元素 → 附魔场景）；以后加冰/雷/土附魔或双元素附魔就在这里加。
- 有附魔的元素出招时不再叠加旧的 `element_blade_scenes` 拖尾；其它元素仍用旧拖尾。
- 游戏镜头远，`fire_enchant.gd` 的 `size_scale` 把火团放大；补发火团按剑上一帧到这一帧的姿态插值。
- 检查：`tests/fire_enchant_capture.gd`（截图到 builds/visual_pass/fire_enchant_*.png）。
- 受击火焰、刀光带、蓄力等演示里的其它层还没接入。

## 以后接入其它层时要做的事

- 刀光拖尾和刀弧火团接到角色武器的刀根/刀尖挂点上，补采样用武器动画的骨骼插值代替 `katana_rig` 的解析姿态。
- 受击预制体由命中事件生成，朝向用“刀的运动方向 + 刀身方向”。
- 游戏场景目前关着辉光：要么给战斗场景开辉光，要么把发光层亮度再调一档。
