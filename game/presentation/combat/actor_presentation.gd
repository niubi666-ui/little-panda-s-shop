extends Resource
## Asset-only mapping: replacing model/animation/body geometry does not change combat.
@export var visual_scene: PackedScene
@export var body_shape: Shape3D
@export var body_height: float
@export var idle_animation: StringName
@export var move_animation: StringName
@export var visual_yaw_offset_deg: float
@export var retain_corpse: bool = false
@export var embedded_weapon: bool = false
## 模型自带武器和攻击动作，但仍保留一把不可见的虚拟剑来驱动刀光特效。
@export var virtual_blade: bool = false
