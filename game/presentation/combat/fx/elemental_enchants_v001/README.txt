冰霜 / 雷电：游戏运行资源

来源：game/vfx_lab/elemental_enchants，连同引用的 fire_katana 贴图/脚本独立归档。
本目录没有对 vfx_lab 的运行依赖，实验室生成器不会覆盖本目录。

ice_enchant.tscn / thunder_enchant.tscn：真实刀刃挂点、常驻附魔与运动拖尾。
ice_impact.tscn / thunder_impact.tscn：已确认直接命中的独立特效。
generated/：材质、噪声贴图、碎冰网格。
shared/：归档的实验室共用依赖；时间表播放器已改成手动战斗时钟。

调整入口：training_style.tres 的 element_weapon_enchants；build_effects_style.tres 的 element_impact_scenes。
常驻规则：第一个选取的元素；命中规则：本次攻击的真实元素。
Shader 使用 effect_time，而不是 TIME，暂停/顿帧时同步停止。
运行验证：game/tests/element_enchant_integration.gd。
