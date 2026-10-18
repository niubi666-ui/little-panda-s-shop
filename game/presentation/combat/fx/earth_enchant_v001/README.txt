土元素：游戏运行资源

来源：game/vfx_lab/elemental_enchants（用户在演示里认可的土特效），由 build_earth_enchant.gd 复制成独立资源。
本目录没有对 vfx_lab 的运行依赖；结构和 elemental_enchants_v001 里的冰/雷一致，共用它的 enchant_base.gd、
vfx_sequence_player / vfx_light_pulse / vfx_decal_fade（战斗时钟，暂停、顿帧一起停）和 glint.gdshader。

earth_enchant.tscn：常驻附魔。刀身岩壳覆盖层（按刀身本地坐标贴，不依赖剑模型 UV）、悬浮碎石、细沙、尘土；
  挥砍时补发尘土拖尾并甩出会落地弹跳的碎石。
earth_impact.tscn：已确认直接命中的受击。岩刺沿攻击方向在目标后方依次从地里顶出（spike_eruption.gd），
  地面金色裂纹、碎石四溅、尘土；命中点往下 ground_drop（= build_effects_style.element_impact_height）当地面。

调整入口：training_style.tres 的 element_weapon_enchants；build_effects_style.tres 的 element_impact_scenes。
常驻规则：第一个选取的元素；命中规则：本次攻击的真实元素。
重建：先 --import，再跑 build_earth_enchant.gd（会覆盖本目录的场景和材质）。
运行验证：game/tests/element_enchant_integration.gd（含 elem_earth_mastery 测试预设）。
