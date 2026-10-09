extends Resource
## Authored clip timing only. Damage windows continue to come from AbilityRunner.
@export var clips: Dictionary[String, String]
@export var attack_clips: Array[String]
@export var attack_cuts_sec: Dictionary[String, Vector2]
@export var walk_reference_speed_mps: float
@export var run_reference_speed_mps: float
@export var run_threshold_mps: float
@export var movement_epsilon_mps: float
