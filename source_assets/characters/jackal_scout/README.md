# 豺狼斥候：骨骼动画评审

当前确认工程为 **v003**：已校正刀柄握持与刀刃朝向，包含用户认可的七个动作。旧版工程、修正前备份、自动备份及一次性中间脚本已清理；本轮清理采用 Windows 回收站，可恢复。

制作日期：2026-10-07。此目录保存可编辑源资产与动作筛选结果；已接入 Godot 的近战斥候 `scout`。

## Godot 运行资源 v001

- 运行模型与贴图：`E:/ShopGame/game/assets/characters/jackal_scout/melee_scout_v001/`。
- 导出用 Blender：`blender/jackal_scout_runtime_v001.blend`；源为确认的评审 v003，原始下载及评审工程不改写。
- 可复现导出：`E:/blender/blender.exe --background --factory-startup --python E:/ShopGame/source_assets/characters/jackal_scout/scripts/export_runtime_v001.py`，随后运行 Godot 编辑器导入。
- 导出报告：`reports/runtime_export_v001.json`，记录源文件 SHA256、动作范围、骨骼/面数。GLB 仅导出角色骨架、身体与弯刀，65 骨骼，身体 7,827 + 弯刀 1,496 = 9,323 三角面，两个 4K 颜色贴图。Godot 自动提取纹理到 GLB 同目录。
- 七个独立 clips：待机、行走、跑步、横斩、斜斩、受击、死亡，时间原点归零，不携带评审 NLA 循环区间。
- 表现绑定：`game/presentation/combat/scout_presentation.tres`、`enemies/scout_visual.tscn`；`enemies/scout_animation_style.tres` 是动画名/分段/步频唯一表现配置。正常追击用跑步，低速用行走，攻击仅斜斩；用户已停用低姿横斩 `scout_attack_slash`，源资产保留该 clip，运行时不再选用。命中完全由原逻辑时间线决定；当前速度/攻速/半径的150%调整见 `docs/ENEMY_ROLES_AND_ENCOUNTERS.md` 与游戏 JSON。
- 运行尺度 1.65，站立约 1.48 米；原斥候碰撞胶囊保持。刀使用 v003 确认方向，并随右手蒙皮，不再叠加程序占位剑。
- 实际 Godot 截图：`previews/godot_melee_scout_v001/`。验证入口 `game/tests/scout_presentation.gd`，headless/Forward+ 庭院检查及 `enemy_roles.gd` 回归记录见该目录 `validation.json`。退出仍有既有 7 个 Texture RID 警告，未完成密集敌人性能或人工手感验收。

## 打开与播放

- 工程：`blender/jackal_scout_animation_review_v003.blend`。
- 空格播放/暂停；30 FPS，时间线 1–640 帧，约 21.3 秒。
- v003 默认启用 437–527 帧预览范围，循环检查用户指出的斜斩。关闭时间线的预览范围后可播放完整七动作。
- 时间线标记和骨架的 `REVIEW_PLAYLIST_30FPS` NLA 轨道按顺序播放七个动作。
- 单独编辑某个动作时，选 `Jackal_Scout_Rig`，静音评审 NLA 轨道，再在动作编辑器选择对应 `scout_` Action；避免活动 Action 与评审轨道同时混合。

## 动作筛选

| 动作 ID | 原始文件 | 使用理由 |
|---|---|---|
| `scout_idle` | `sword and shield idle (4).fbx` | 简短待机，避免长时间看剑、张望等表演动作 |
| `scout_walk` | `sword and shield walk.fbx` | 前进步态；同名 `(2)` 为后退步态 |
| `scout_run` | `sword and shield run.fbx` | 前进追击；同名 `(2)` 为后退跑步 |
| `scout_attack_slash` | `sword and shield slash (5).fbx` | 位移较小的普通横斩候选，适合目前扇形近战表现 |
| `scout_attack_diagonal` | `sword and shield slash.fbx` | 备用斜斩，供主观比较与后续动作替换 |
| `scout_hit_react` | `sword and shield impact (3).fbx` | 简短受击反馈 |
| `scout_death` | `sword and shield death.fbx` | 死亡表现候选 |

原始动画包共 **49** 个 FBX，项目目录仅保留以上 **7** 个采用的动画源文件。其余 **42** 个项目副本已在逐一核对与桌面原下载文件 SHA256 一致后清理；桌面完整下载包未改动。`reports/animation_selection_v001.json` 是历史筛选记录，其中排除项和旧工程路径不代表现存文件。

## 来源与处理

- 用户角色及独立弯刀来自桌面 `斥候/斥候.blend`，其中的两个 4096×4096 颜色贴图已恢复并打包。
- 蒙皮来自用户补充的 `斥候绑定骨架.fbx`：65 根 Mixamo 骨骼、3,943 个角色顶点、7,827 个角色三角面；全部角色顶点有权重。
- 动画来自用户下载的 `Sword and Shield Pack`。保留 `original/mixamo_v001/斥候.blend` 作为角色/武器原始建模源，保留 `斥候绑定骨架.fbx` 作为蒙皮源；未绑定的冗余 `斥候.fbx` 项目副本已清理，桌面原文件保留。
- 带蒙皮 FBX 保留角色原始侧向绑定姿态，动作包采用 Mixamo 标准朝向；已通过下载角色的 T-Pose 校准并烘焙 FK 转换，**原绑定骨骼矩阵与原蒙皮权重均保持一致**。
- 待机、行走、跑步、两种攻击及受击去除水平根位移，保留上下运动。死亡保留原倒地位移。原动作速度保持 30 FPS；此处不指定玩法攻击速度、命中帧或敌人移速。
- 独立弯刀使用单一右手骨的刚性权重，保持独立网格。握持点按手部蒙皮位置校准；v002 刀柄轴指向食指/拇指侧，刀面按手掌方向校准。没有添加盾牌。
- 评审台面、灯光及相机仅用于看动作，不是房间资源。
- 用户提供素材的具体商用授权凭据未附在本目录；此处记录来源，不代表完成授权审查。

## 实际验证与边界

- 当前验证证据保留于 `previews/godot_melee_scout_v001/`：实机截图、47项无头/图形动画检查及敌人行为回归日志。旧版 Blender 静帧和中间诊断报告已清理。
- 原始源模型站立约 0.90 米，Godot 表现缩放至约 1.48 米；与小熊猫主角对照实机截图见运行资源预览目录。
- v001 Blender 骨骼验证属于历史证据；当前 Godot 动画导入、状态切换和分段映射的结果见上方运行资源 v001，运行性能仍需正式验证。

## 复现

以确认的 `blender/jackal_scout_animation_review_v003.blend` 为当前制作起点，运行 `scripts/export_runtime_v001.py` 重建运行工程与 GLB。旧版修正链已移除，不再从 v001 重建。导出用独立后台 Blender，避免影响其它对话正在使用的进程。

