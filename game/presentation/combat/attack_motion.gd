extends Resource
## Sword/body poses sampled from the confirmed ability timeline.
## Distances are presentation offsets from the separately authored maximum tip radius.
@export_enum("swing", "thrust") var motion_kind: String
@export var yaw_start_deg: float
@export var yaw_end_deg: float
@export var pullback_distance: float
@export var extension_distance: float
@export var lateral_offset: float
@export var grip_height_offset: float
@export var active_completion_fraction: float
@export var body_windup_degrees: Vector3
@export var body_strike_degrees: Vector3

func validate() -> void:
	assert(motion_kind in ["swing", "thrust"], "Unknown attack presentation motion")
	assert(pullback_distance >= 0.0 and extension_distance >= 0.0)
	assert(active_completion_fraction > 0.0 and active_completion_fraction <= 1.0)
	if motion_kind == "thrust":
		assert(is_equal_approx(yaw_start_deg, yaw_end_deg), "A thrust must retain its aiming direction")

func sample_pose(phase: String, progress: float) -> Dictionary:
	var amount := smoothstep(0.0, 1.0, clampf(progress, 0.0, 1.0))
	var yaw := 0.0
	var retreat := extension_distance
	var body := Vector3.ZERO
	match phase:
		"windup":
			yaw = lerpf(0.0, yaw_start_deg, amount)
			retreat = extension_distance + pullback_distance * amount
			body = Vector3.ZERO.lerp(body_windup_degrees, amount)
		"active":
			# A short, fast extension can finish before the active window closes.
			amount = smoothstep(0.0, active_completion_fraction, clampf(progress, 0.0, 1.0))
			yaw = lerpf(yaw_start_deg, yaw_end_deg, amount)
			retreat = lerpf(extension_distance + pullback_distance, 0.0, amount)
			body = body_windup_degrees.lerp(body_strike_degrees, amount)
		"recovery":
			yaw = lerpf(yaw_end_deg, 0.0, amount)
			retreat = extension_distance * amount
			body = body_strike_degrees.lerp(Vector3.ZERO, amount)
	return {
		"yaw_deg": yaw,
		"tip_retreat": retreat,
		"lateral_offset": lateral_offset,
		"grip_height_offset": grip_height_offset,
		"body_degrees": body,
	}
