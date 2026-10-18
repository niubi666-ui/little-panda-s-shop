# 卡牌原画动画库

2026-10-18。已有 **51 张原画全部配置动画**，包括暂未进入正常卡池的旧卡；没有改变卡池、卡牌规则或数值。保留获认可的火/冰/雷核心样板效果，其余逐图标定。新增卡面的最终观感待用户试玩确认。

## 怎么看

- 游戏：**Esc → 画面设置 → 播放卡牌动画 → 开 / 关**。默认开；关时保留静态原画，释放动画资源。偏好存于 `user://player_preferences.cfg`，跨场景和重启保留，与正式存档无关。
- 全卡画廊：根目录 `启动卡牌微动画样板.cmd`。选择器或 **PgUp/PgDn** 切页；**D** 静态/动态、**P** 冻结、**L** 中英文。画廊开关只影响预览，不改玩家保存设置。原来的三核心组合和三张同元素组仍可选择。
- [全卡动态视频](previews/card_catalog_v001.mp4)：17 页、51 张、每页 3 秒、1280×800、24 FPS、无音轨。此帧率只用于录制。
- [全卡渲染截图与验证](previews/catalog/)：17 张页面截图和 `validation.json`。
- 旧 `card_art_motion_v001/v002/v003.mp4`、样板截图及性能报告保留为历史对比。`IMPLEMENTATION_BRIEF.txt` 是最初三卡样板提案，不是当前覆盖范围。

## 素材与制作入口

所有本功能制作源集中在本目录；运行副本在 Godot 的卡牌美术目录。原始 PNG 没有修改，也没有复制成逐帧动画序列。

| 位置（相对本目录） | 用途 |
|---|---|
| `authoring/elemental.json` | 19 张新增火/冰/雷卡的逐图路径、遮罩和表现参数 |
| `authoring/other.json` | 29 张武技、旧卡、土系、双元素卡的逐图参数 |
| `scripts/build_catalog.py` | 生成分类 Resource、SVG 遮罩和按需加载索引；仅 Python 标准库 |
| `masks/` | 可编辑的三个原始核心遮罩，以及按类别导出的新增遮罩 |
| `previews/` | 实机录像、截图与测试/性能报告；不用于游戏运行 |
| `scripts/record_catalog.py` | Godot 画面直接流入 FFmpeg，录制时不产生 PNG/AVI 中间帧 |

运行文件：

- `game/presentation/builds/card_art_motion/fire.tres`、`ice.tres`、`thunder.tres`：三个已认可核心的直接编辑入口。
- `game/presentation/builds/card_art_motion/profiles/<类别>/<卡牌ID>.tres`：其余 48 张；由制作源生成，长期调参改 authoring 后重新导出，避免下次覆盖手改值。
- `game/assets/ui/build_cards/v001/motion/<类别>/`：对应运行遮罩。
- `game/presentation/builds/card_art_motion/library.tres`：仅存路径的索引。只加载当前显示的卡牌，关闭动画或关闭卡牌后释放。
- `profile.gd` / `art_motion.gd` / `local_art.gdshader`：共同渲染器；运行表现数值在 Resource 中。

共 **58 层 / 58 个遮罩**，其中 7 张是双层组合（六种双元素反应 + 蓄力剑气）。新增遮罩为 512×384；三个旧核心 SVG 保留原始绘制尺寸，导入时缩到 512×384。

| 类别 | 动态方式 |
|---|---|
| 火 | 局部流火、明暗起伏、带尾迹火星 |
| 冰 | 从对应冰面/轨迹冒出冷雾，漂移膨胀消散，叠加冰晶闪光 |
| 雷 | 沿原画结构向周围放电，主弧与分叉错峰连续出现 |
| 土 | 裂隙微光、尘屑、旋转碎石 |
| 武技 | 沿刀刃、轨迹或冲击方向流动的能量尾迹 |
| 双元素 | 分别标定两个元素的路径和区域，同时播放 |

效果裁切在原画窗口内；边框、文字和原画主体不做整图扭曲。沿用现有飞入、悬停、选择和退场动画，不另加整卡摇晃。独立视觉随机不消耗玩法随机；隐藏不计时，显式暂停保留当前帧，Esc 暂停冻结动画。选卡阶段暂停战斗但 UI 正常播放。

## 验证与开销

Forward+ 图形模式：

- `tests/card_art_catalog.gd`：**526 项通过**。覆盖全部 51 张的实际像素运动、58 个遮罩尺寸、关/开释放重建、关闭后资源不再占用缓存。
- `tests/card_art_motion.gd`：**393 项通过**。真实奖励 Session、输入、独立材质/相位、随机隔离、双语/分辨率、隐藏/暂停/重复开关等。
- `tests/card_animation_settings.gd`：**63 项通过**。设置 UI 开关、静态原图、持久化、新卡/已有卡、生效信号与暂停；使用独立临时偏好文件，不改变玩家设置。

三张双元素卡同时显示实测（蒸腾、雷火、冰雷）：RTX 4060 Laptop GPU，Godot 4.7.2 Forward+/Vulkan，1280×800，强度 1.0；单进程静/动/静/动，每段预热 3 秒、采样 8 秒，无录制、无 3D 战斗。

| 计时（毫秒） | 静态平均 / P95 | 动态平均 / P95 |
|---|---|---|
| Viewport GPU | 0.224 / 0.225 | 0.284 / 0.325 |
| 渲染 CPU + 帧准备 | 0.070 / 0.090 | 0.155 / 0.240 |
| 实际帧间隔 | 0.551 / 0.635 | 1.320 / 1.728 |

CPU 行不包含脚本执行，帧间隔包含调度和等待。后台负载与 GPU 功耗未控制，不是最低配置或完整战斗帧率验收。[完整测量报告](previews/performance_catalog_1280x800.json)。

当前全卡动画运行文件约 **0.55 MiB**：58 个导入遮罩 437,340 字节，公共渲染代码及 Resource 139,910 字节。此统计不含既有原画、Godot 引擎、开发预览、导出容器压缩差异和少量设置接线；不是整个游戏体积。没有生成 Release。

## 复现

仓库根目录执行，`godot` / `python` / `ffmpeg` 换成本机路径：

```powershell
python source_assets/ui/build_selection/animated_v001/scripts/build_catalog.py
godot --headless --editor --path game --import
godot --path game --script res://tests/card_art_catalog.gd
godot --path game --script res://tests/card_art_motion.gd
godot --path game --script res://tests/card_animation_settings.gd
godot --path game --resolution 1280x800 --script res://ui_lab/card_art_motion/benchmark.gd -- --cards=dual_steam,dual_overload,dual_superconduct --output=source_assets/ui/build_selection/animated_v001/previews/performance_catalog_1280x800.json
python source_assets/ui/build_selection/animated_v001/scripts/record_catalog.py --godot <Godot可执行文件> --ffmpeg <FFmpeg可执行文件>
```

播放游戏和画廊不需要 Python / FFmpeg；它们只用于制作导出与预览录像。全卡像素检查的页面顺序按原画索引，画廊则按类别编排，二者页码不必一致。
