extends Resource
## Staging is capture-only; all attacks and health use the real training catalog.
@export var effect_ids: Array[StringName]
@export var segment_duration_sec: float
@export var normal_attack_sec: float
@export var slow_start_sec: float
@export var slow_attack_sec: float
@export var slow_end_sec: float
@export var target_stage_sec: float
@export var hit_attack_sec: float
@export var slow_scale: float
@export var normal_camera_size: float
@export var close_camera_size: float
@export var camera_right_shift: float
@export var player_start: Vector3
@export var facing: Vector3
@export var distant_enemy_offsets: PackedVector3Array
@export var target_distance_m: float
@export var distance_tolerance_m: float
@export var expected_arc_deg: float
@export var arc_tolerance_deg: float
@export var title_position: Vector2
@export var title_font_size: int
@export var previews_path: String
@export var report_path: String
