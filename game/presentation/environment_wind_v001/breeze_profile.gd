extends Resource
## Presentation-only settings. All adjustable values live in the .tres profile.

@export_file("*.glb", "*.tscn") var sample_scene_path: String
@export_group("Wind")
@export var direction_xz: Vector2
@export var sway_amplitude_m: float
@export var sway_frequency_hz: Vector2
@export var steady_push_ratio: float
@export var gust_amplitude_m: float
@export var gust_frequency_hz: Vector2
@export var flutter_amplitude_m: float
@export var flutter_frequency_hz: Vector2
@export var spatial_phase_per_m: float
@export var instance_phase_spread: float
@export var normal_bend_reference_m: float
@export var strength_levels: PackedFloat32Array
@export var strength_labels: PackedStringArray
@export var initial_strength_index: int
@export_group("Preview camera")
@export var camera_yaw_degrees: float
@export var camera_pitch_degrees: float
@export var camera_fit_margin: float
@export var camera_min_size_m: float
@export var camera_max_size_m: float
@export var camera_zoom_ratio: float
@export var camera_drag_degrees_per_pixel: float
@export var camera_focus_height_ratio: float
@export_group("Preview stage")
@export var stage_margin_m: float
@export var stage_depth_m: float

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if sample_scene_path.is_empty():
		errors.append("sample_scene_path is required")
	if not direction_xz.is_finite() or direction_xz.length_squared() < 0.000001:
		errors.append("direction_xz must be a finite, nonzero XZ direction")
	for field in ["sway_amplitude_m", "gust_amplitude_m", "flutter_amplitude_m", "steady_push_ratio", "spatial_phase_per_m", "instance_phase_spread"]:
		var value: float = get(field)
		if not is_finite(value) or value < 0.0:
			errors.append("%s must be finite and nonnegative" % field)
	for field in ["normal_bend_reference_m", "camera_fit_margin", "camera_min_size_m", "camera_max_size_m", "camera_zoom_ratio", "camera_drag_degrees_per_pixel", "stage_margin_m", "stage_depth_m"]:
		var value: float = get(field)
		if not is_finite(value) or value <= 0.0:
			errors.append("%s must be finite and positive" % field)
	for field in ["sway_frequency_hz", "gust_frequency_hz", "flutter_frequency_hz"]:
		var value: Vector2 = get(field)
		if not value.is_finite() or value.x <= 0.0 or value.y <= 0.0:
			errors.append("%s must contain two positive frequencies" % field)
	if strength_levels.size() != 3 or strength_labels.size() != 3:
		errors.append("three strength_levels and strength_labels are required")
	for value in strength_levels:
		if not is_finite(value) or value < 0.0:
			errors.append("strength_levels must be finite and nonnegative")
	if initial_strength_index < 0 or initial_strength_index >= strength_levels.size():
		errors.append("initial_strength_index is outside strength_levels")
	if camera_max_size_m < camera_min_size_m or camera_zoom_ratio <= 1.0:
		errors.append("camera_max_size_m must cover camera_min_size_m; camera_zoom_ratio must exceed one")
	if not is_finite(camera_yaw_degrees) or not is_finite(camera_pitch_degrees) or camera_pitch_degrees <= 0.0 or camera_pitch_degrees >= 89.0:
		errors.append("camera angles must be finite; pitch must be between 0 and 89 degrees")
	if not is_finite(camera_focus_height_ratio) or camera_focus_height_ratio < 0.0 or camera_focus_height_ratio > 1.0:
		errors.append("camera_focus_height_ratio must be in [0, 1]")
	return errors
