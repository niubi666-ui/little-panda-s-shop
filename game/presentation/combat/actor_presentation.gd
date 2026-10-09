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
