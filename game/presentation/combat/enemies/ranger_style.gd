extends Resource
@export var clips: Dictionary[String, String]
@export var death_duration_sec: float
@export var draw_phase_fraction: float
@export var health_bar_height: float
@export var health_bar_size: Vector2
@export var warning_color: Color
@export var skill_vfx_profile: Resource
@export var roll_afterimage_profile: Resource
@export var line_width: float
@export var ground_height: float
@export var arrow_length: float
@export var arrow_width: float
@export var arrow_launch_blend_distance_m: float
@export var rain_arrow_count: int
@export var rain_height: float
@export var rain_fall_sec: float
@export var charged_warning_color: Color
@export var locked_warning_color: Color
@export var rain_active_color: Color
@export var rain_active_width_ratio: float
@export var charged_trail_ratio: float
@export var charge_glow_size: float
@export var charge_light_energy: float
@export var charge_light_range: float
@export var charge_sound: AudioStream
@export var lock_sound: AudioStream
@export var charge_volume_db: float
@export var charge_audio_distance: float
@export var charge_pitch_range: Vector2

func challenge_cues_valid() -> bool:
	return charge_sound != null and lock_sound != null and rain_active_width_ratio > 0.0 and charged_trail_ratio > 0.0 and charge_glow_size > 0.0 and charge_light_energy > 0.0 and charge_light_range > 0.0 and charge_audio_distance > 0.0 and charge_pitch_range.x > 0.0 and charge_pitch_range.y >= charge_pitch_range.x
