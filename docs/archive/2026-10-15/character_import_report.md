# 小熊猫 v008：店铺原型用运行资源

日期：2026-09-25。此记录覆盖角色导出与独立导入检查；店铺实机效果由场景整合验收。

## 交付与来源

- 源文件：[red_panda_run_v008.blend](../source_assets/characters/red_panda/blender/red_panda_run_v008.blend)。源文件未保存或覆盖，原始网格比例未改。
- 运行资源：[red_panda_v008.glb](../game/assets/characters/red_panda/red_panda_v008.glb)。同名候选副本保存在 `source_assets/characters/red_panda/exports/`。
- 重复导出脚本：[export_red_panda.py](../tools/assets/export_red_panda.py)。仅选择 v008 骨架与角色网格，排除历史评审场景、灯光、相机和其他物体。
- 原动作评审：[run_v008_review.md](../source_assets/characters/red_panda/reports/run_v008_review.md)。其中衣服接缝、步速匹配等限制继续有效。

导出副本修正了网格的历史父级引用：原网格 parent 指向旧 `RedPanda_ARP_Rig_v003`，实际蒙皮修改器指向新 `RedPanda_RunRig_v008`；导出时保持 world transform，将 parent 与蒙皮统一到 v008 骨架。Blender 新版 Action 使用显式 slot 绑定，避免重命名导出副本后动作不求值。上述调整仅存在于后台实例与派生 GLB。

## 引擎接入约定

| 项目 | 当前值 |
|---|---|
| GLB 前方 / 上方 | +X / +Y |
| 中立站立高度 | 0.99951166 模型单位 |
| 调整到约 1.2m 的整体缩放 | `Vector3.ONE * 1.20058629`；写在模型表现节点或资源，不改源网格比例 |
| 脚底 | 中立姿态已对齐本地 Y≈0；跑步保留原动作垂直起伏 |
| Actor 使用 -Z 为前方时 | 模型表现子节点绕 Y 旋转 +90° |
| AnimationPlayer 路径 | GLB 根节点下的 `AnimationPlayer` |
| 模型路径 | `RedPandaRig/Skeleton3D/RedPandaMesh` |
| 骨架 | 46 骨，与 v008 一致 |
| 运行网格 | 1 个 MeshInstance3D、2 个材质 surface、1 个 Skin |
| 源网格 | 6,552 顶点、12,084 多边形；未主动减面 |
| 贴图 | 1 张内嵌贴图，没有外部图片 URI |

建议模型保持独立表现子树，人物碰撞和移动由 Actor/Motor 管理。衣服、尾巴、头部的渲染包围盒不直接作为行走碰撞体或家具占地。

## 动作

| GLB 动作名 | 时长 | 用途 |
|---|---|---|
| `run` | 0.8 秒 | 来自 `RP_Run_New_v008`，30fps，保留 1–25 帧的闭合区间；无水平根运动 |
| `idle` | 1.0 秒 | 用 v008 修订后的骨架生成中立静态站姿，只作交互原型占位 |

GLB 不携带 Godot 动画循环设置，默认导入 `loop_mode=0`。整合者应在导入参数设置 `idle` 和 `run` 为循环；若由表现适配器设置，先复制对应动画资源以隔离实例状态，再设 `Animation.LOOP_LINEAR`。

没有复用历史 `RP3_idle` 等动作，因为 v008 调整过右臂静止骨架；旧动作兼容性未通过本轮验收。新 `idle` 没有呼吸或尾巴动态，不把它描述为完整待机动作。行走速度与步频需要在店铺镜头中调校；暂未制作慢走、转向、武器或斜坡动作。

## 已验证

1. Blender 5.2.1 LTS 后台导出成功。GLB 6,343,464 字节，只有一组角色网格/蒙皮及 `idle`、`run` 两个动作。
2. 源跑步首帧与修正父级后的导出副本首帧包围盒一致；25 帧采样中动作实际求值，根骨垂直位置变化，首尾相同。
3. Godot 4.7.2 `GLTFDocument` 独立 headless 导入成功，使用 `GLTFDocumentExtensionConvertImporterMesh` 转换为运行 MeshInstance3D。没有打开项目编辑器或并发扫描项目资源。
4. Godot 中 `idle` 为 15 条有效轨道、`run` 为 23 条有效轨道；多帧检查骨骼变换有限。跑步根骨水平位置一致，首尾根骨位置一致，中间姿势有变化。
5. 检视导出副本的 Blender 静态预览：中立姿势与跑步姿势可区分，角色、尾巴、材质可见。预览不代表 Godot 店铺最终光照验收。

记录与预览：

- [导出测量结果](../source_assets/characters/red_panda/exports/red_panda_v008_export_report.json)
- [Godot导入检查](../source_assets/characters/red_panda/exports/red_panda_v008_godot_validation.json)
- [中立站姿预览](../source_assets/characters/red_panda/exports/red_panda_v008_idle_preview.png)
- [跑步姿势预览](../source_assets/characters/red_panda/exports/red_panda_v008_run_preview.png)

## 复现命令

```powershell
& 'E:\blender\blender.exe' --background --factory-startup 'E:\ShopGame\source_assets\characters\red_panda\blender\red_panda_run_v008.blend' --python-exit-code 1 --python 'E:\ShopGame\tools\assets\export_red_panda.py' -- --previews
& 'E:\GoDot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\ShopGame\source_assets\characters\red_panda\exports' --script 'E:\ShopGame\source_assets\characters\red_panda\exports\validate_red_panda.gd'
```

导出命令会重新生成候选 GLB 并复制到 `game/assets/characters/red_panda/`，执行前遵守文件归属，避免与引擎导入同时覆盖。
