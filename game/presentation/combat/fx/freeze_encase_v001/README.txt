冰冻状态表现：游戏运行资源

来源：game/vfx_lab/freeze_lab（用户认可）。替换了原来冰冻时套在敌人身上的半透明蓝色胶囊。
本目录没有对 vfx_lab 的运行依赖；冰晶、冰碴、寒雾、冰晶闪光、霜花复用 elemental_enchants_v001/generated 的冰元素资源。

接入点：mechanism_style.tres 的 status_scenes["freeze"] = freeze_encase.tscn。
- 敌人被冻住（status_runtime 快照 frozen = true）时 mechanism_view 生成本场景，configure_effect 按 handle 找到敌人的表现节点并冰封。
- 每帧 sync_effect(snapshot, delta) 跟战斗时钟走（暂停、顿帧一起停）。
- 解冻或死亡时 finish() 碎冰；mechanism_view 对 has_tail() 为真的状态场景继续 tail_tick，碎完再释放（mechanism_view._tails）。

贴合体型（新模型通常不用改代码）：
- 冰壳：敌人自己的每个可见网格挂 material_overlay（ice_shell.gdshader），沿法线外推，厚度 = 身高 × 2.2%。
- 冰晶：身体网格表面按三角形面积随机取点，挂到驱动该点的骨骼上；取样表按网格资源缓存（同种敌人只算一次）。
- 体型：有骨架取当前姿势的骨骼范围；没有骨架取网格包围盒。冰晶数（6–26 处）、冰刺圈、霜花、寒气按身高和体宽缩放。
- 身体网格默认取顶点最多的蒙皮网格；模型可在表现节点上设 meta "freeze_body_mesh"（NodePath）指定。

新模型的要求：表现节点脚底在原点（无骨架时取包围盒底部）、等比缩放；没有骨架时只有冰壳和脚下冰圈，不长冰晶。
已知限制：硬边低模的法线断开处冰壳会有细缝；尾巴/翅膀很长时体宽偏大；冰晶上限 26 处，超大 Boss 会偏稀。

重建：Godot --headless --path game --script res://presentation/combat/fx/freeze_encase_v001/build_freeze_encase.gd
运行验证：game/tests/freeze_encase_integration.gd（截图到 builds/freeze_encase_review/）。
