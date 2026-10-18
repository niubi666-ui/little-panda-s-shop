# 冰冻特效测试场（已于 2026-10-18 接入游戏：presentation/combat/fx/freeze_encase_v001）

打开 `freeze_lab.tscn` 按 F6。一排游戏里的真实敌人（重锤、冲锋、斥候、弩手、旗手、精英弓手）循环演示 冻结 → 冻住 → 碎冰。
按键：F 手动冻结/碎冰，空格 自动循环开关，P 暂停时间（检查会不会一起停），L 白天/夜晚，C 机位。

## 怎么贴合体型（`scripts/freeze_encase.gd`）
- **冰壳**：给敌人自己的每个网格挂 `material_overlay`（`shaders/ice_shell.gdshader`），顶点沿法线外推（厚度 = 身高 × 2.2%），轮廓、武器、道具、骨骼姿势完全一致。冰从脚往上爬，前沿一道白霜；受光的半透明玻璃感 + 冰裂纹 + 冷光边。
- **冰晶**：在身体网格表面随机取朝上/朝外的点，挂到驱动该点的骨骼上（BoneAttachment3D），数量按 身高×体宽 算（6–26 簇），长度按身高。冰爬到那个高度时冰晶长出来。
- **脚下**：一圈冰刺（数量按周长、高度按身高）、地面霜花（尺寸按体宽）、往下沉的寒气、冰晶闪光。
- **体型**取冻结那一刻姿势下的骨骼包围范围；冻住时动作停住（游戏里冻结也是停住动作）。
- **碎冰**：冰壳沿裂纹亮一下后一块块消失，冰晶和冰刺碎成会落地弹跳的冰碴，冒一团寒雾。

## 接入游戏时
- 敌人表现节点上调用 `attach(visual)`，冻结开始 `freeze()`、结束 `release()`，每帧 `tick(delta)`（跟战斗时钟走，暂停传 0）。
- 冻结状态来自 `mechanism_view` 的 `snapshot.frozen`；接入后可以替换掉现在的 `freeze_mesh` 和蓝色描边。
- 冰晶、冰碴、寒雾材质沿用 `vfx_lab/elemental_enchants/generated/`，接入时按冰/雷那套复制到游戏目录。

重建：`Godot --headless --path game --script res://vfx_lab/freeze_lab/tools/build_freeze_lab.gd`
