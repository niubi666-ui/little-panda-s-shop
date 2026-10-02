# 跑步关键姿势 v004：待确认

用户于 2026-09-25 决定弃用之前的跑步动作效果，先确认原骨架重新摆出的姿势截图，确认后才能制作完整动画。

文件：`../blender/red_panda_run_poses_v004.blend`。

沿用现有 46 骨骨架（原 41 骨及已补充的 5 根尾骨）和 v003 修订蒙皮；从静止姿态独立摆姿势，没有采样旧跑步动作。新建的四个 RunPose 场景均无 Action、无关键帧插值。旧场景和旧动作仅为备份。

|姿势|斜前方|侧面|
|---|---|---|
|01 落脚|![落脚](../previews/RunPose_01_Contact_front.png)|![侧面](../previews/RunPose_01_Contact_side.png)|
|02 承重下沉|![下沉](../previews/RunPose_02_Down_front.png)|![侧面](../previews/RunPose_02_Down_side.png)|
|03 收腿经过|![经过](../previews/RunPose_03_Passing_front.png)|![侧面](../previews/RunPose_03_Passing_side.png)|
|04 腾空|![腾空](../previews/RunPose_04_Flight_front.png)|![侧面](../previews/RunPose_04_Flight_side.png)|

## 评审范围

请确认步幅、抬腿、前倾、摆臂、尾巴轮廓是否符合角色气质。这些是同一拟定跑步过程的四个阶段，不是四种风格候选。

当前没有制作节奏、镜像半周期、触地锁定、连续轨迹、尾巴延迟或完整动画。截图来自 Blender 模型视口；不是 AI 生成参考图。手指无独立骨骼，手掌仍是整体爪形；原模型肩袖权重仍有后续精修空间。

最终姿势矩阵保存在 `run_poses_v004_transforms.json`；创建脚本为初始摆姿记录，之后手掌绕自身方向额外调整左右各正负 65 度，最终以矩阵和 blend 文件为准。
