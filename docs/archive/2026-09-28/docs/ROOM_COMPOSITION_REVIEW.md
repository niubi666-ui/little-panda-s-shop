> 后续进展：用户新增四张参考后已实现 v003 组合随机，见 [ROOM_PRESETS.md](ROOM_PRESETS.md)。本文件保留早期三个小景的美术评审记录。

# 房间组合试摆：三组小景、两套布局

2026-09-27。用户确认先用现有素材做固定组合和完整布局，评审美感后再决定随机生成规则。

## 本轮交付范围

这是 **Godot 实际渲染的固定美术试摆**。完整布局沿用当前战斗相机的角度、正交尺寸与庭院灯光；截图为1600×1000，隐藏HUD和占位敌人，保留主角作尺度参考。三张局部图仅拉近相机，便于观察组合。

组合尚未接入随机池，也未接入碰撞、破坏、搜刮与导航；没有替换现有随机生成代码或已打包Release。不能把本轮图形启动成功当作这些布局的战斗可玩性验收。

## 三个组合

| 场景（game/presentation/rooms/composition_review/） | 设计 |
|---|---|
| supplies.tscn | 长箱承托小箱，矮箱收尾；木桶与背包靠旁，植物衔接墙根。依附场地边缘使用。 |
| treasure_corner.tscn | L形残墙和高低端柱形成背景，木质宝箱背靠墙体、正面向空地，木桶与少量植物陪衬。 |
| broken_wall_island.tscn | 两段残墙形成连续低矮轮廓，一端柱子抬高；小箱、木桶靠墙错位，适合偏中央或边缘使用。 |

小景内变换以各 `.tscn` 为权威，当前为手工摆放。后续随机化应先保持组合关系，再选择整体落点、朝向和有限的组内变体。

## 两套房间布局

- **A：中央留白。** 物资在左后墙边；左前方短墙物资小景与右前方藏宝角分置两侧，中央纹章和大片地面保持清晰。
- **B：中部绕行。** 物资仍靠左后墙；藏宝角移到右后方；一组矮墙放在中部偏后，提供局部遮挡，两侧地面留作候选绕行空间。通行尺寸待选定后接入碰撞验证。

![布局A](previews/composition_layout_a.png)

![布局B](previews/composition_layout_b.png)

局部：[物资组](previews/composition_supplies.png)、[藏宝角](previews/composition_treasure_corner.png)、[低矮障碍组](previews/composition_broken_wall_island.png)。

## 素材来源与复现

- 箱桶、木质宝箱、背包、残墙复用现有 `presentation/rooms/props` 模型。
- `assets/pillar.res`、`flowers.res`、`fern.res`、`fern_ribs.res` 从现有森林庭院运行GLB的 `East_Railing_Pillar_0`、`Forest_flower_border_1_0`、`Forest_fern_1_0_PinnateLeaves` 和 `Forest_fern_1_0_FrondRibs` 复制网格资源。没有重新建模、修改源blend或修改庭院原GLB。
- `layout_a.tscn`、`layout_b.tscn` 只实例化这三个组合；摆放坐标属于表现层场景。
- 使用 Godot 运行 `--path E:/ShopGame/game --resolution 1600x1000 --script res://tests/composition_review_capture.gd` 复现五张截图。该脚本需要图形渲染，不能用headless模式等待渲染帧。
- 实际运行日志：`builds/composition_review_capture.log`，两套布局与三个近景均完成；无脚本/资源错误。退出时仍有此前的7个Texture RID警告。

本轮无需新增素材。优先评审组合轮廓、依附关系和留白；确定方向后再补随机锚点与玩法碰撞，并决定是否需要更多残墙/断柱/植物变体。
