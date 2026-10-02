extends Resource
## Capture-only staging and camera parameters; combat rules remain in the catalog.
@export var player_start: Vector3
@export var enemy_offsets: PackedVector3Array
@export var start_delay_sec: float
@export var opening_duration_sec: float
@export var opening_slow_start_sec: float
@export var opening_facing: Vector3
@export var opening_enemy_distance_scale: float
@export var approach_range_ratio: float
@export var attack_range_ratio: float
@export var normal_camera_size: float
@export var close_camera_size: float
@export var slow_start_sec: float
@export var slow_scale: float
@export var duration_sec: float
@export var screenshot_active_progress: float
@export var expected_arc_deg: float
@export var arc_tolerance_deg: float
@export var previews_path: String
@export var report_path: String
