extends "res://presentation/combat/rigs/actor_clip_set.gd"
## 顺时针八方向：前、右前、右、右后、后、左后、左、左前。以瞄准朝向为基准。
@export var run_directions: Array[StringName]
@export var walk_directions: Array[StringName]
@export var roll_directions: Array[StringName]
@export var walk_below_speed: float
@export var walk_reference_speed: float
@export var weapon_base_path: NodePath
@export var weapon_tip_path: NodePath
@export var roll_attack_clip: StringName
@export var roll_attack_lower_blend_sec: float
@export var roll_attack_upper_blend_sec: float
@export var roll_attack_turn_sec: float
@export var upper_body_root: StringName

func direction_index(direction: Vector3, facing: Vector3) -> int:
	var forward := Vector3(facing.x, 0.0, facing.z).normalized()
	var right := forward.cross(Vector3.UP)
	var angle := atan2(direction.dot(right), direction.dot(forward))
	return posmod(roundi(angle / (TAU / 8.0)), 8)
