extends SceneTree
## Run: --headless --path game --script res://tests/hit_camera_shake.gd

const HitCameraShake = preload("res://presentation/combat/hit_camera_shake.gd")
const ShakeStyle = preload("res://presentation/combat/hit_camera_shake_style.gd")
const DEFAULT_STYLE = preload("res://presentation/combat/hit_camera_shake_style.tres")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	_test_lifecycle()
	_test_pause_and_retrigger()
	_test_configured_cap()
	print("HIT_CAMERA_SHAKE ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _test_lifecycle() -> void:
	var shake := _new_shake()
	check(DEFAULT_STYLE.validation_error().is_empty(), "presentation style is valid")
	check(shake.tick(DEFAULT_STYLE.duration_seconds) == Vector2.ZERO, "idle output is exactly zero")
	shake.kick()
	var seen_motion := false
	for index in range(64):
		var offset := shake.tick(DEFAULT_STYLE.duration_seconds / 64.0)
		seen_motion = seen_motion or offset != Vector2.ZERO
		check(offset.is_finite(), "pulse offset stays finite")
		check(offset.length() <= DEFAULT_STYLE.maximum_offset_meters, "pulse obeys configured bound")
	check(seen_motion, "confirmed hit creates a visible pulse")
	check(shake.tick(DEFAULT_STYLE.duration_seconds) == Vector2.ZERO, "expired pulse settles exactly to zero")
	check(shake.tick(0.0) == Vector2.ZERO, "settled pulse stays zero")
	shake.kick()
	shake.tick(DEFAULT_STYLE.duration_seconds / 4.0)
	shake.clear()
	check(shake.tick(0.0) == Vector2.ZERO, "clear immediately removes offset")
	check(shake.tick(DEFAULT_STYLE.duration_seconds) == Vector2.ZERO, "clear does not resume later")


func _test_pause_and_retrigger() -> void:
	var shake := _new_shake()
	var control := _new_shake()
	var step := DEFAULT_STYLE.duration_seconds / 8.0
	shake.kick()
	control.kick()
	var frozen := shake.tick(step)
	check(frozen == control.tick(step), "same input produces deterministic offset")
	for index in range(64):
		check(shake.tick(0.0) == frozen, "zero delta freezes the current offset")
	check(shake.tick(step) == control.tick(step), "paused ticks do not consume pulse duration")
	var single_hit := _new_shake()
	single_hit.kick()
	var expected := single_hit.tick(step)
	for index in range(64):
		shake.kick()
		shake.kick()
		var repeated := shake.tick(step)
		check(repeated == expected, "simultaneous or repeated hits do not accumulate displacement")
		check(repeated.length() <= DEFAULT_STYLE.maximum_offset_meters, "rapid hits stay bounded")
	check(shake.tick(DEFAULT_STYLE.duration_seconds) == Vector2.ZERO, "rapid hits still settle after the last hit")


func _test_configured_cap() -> void:
	var capped_style := DEFAULT_STYLE.duplicate() as ShakeStyle
	capped_style.maximum_offset_meters = DEFAULT_STYLE.maximum_offset_meters / 8.0
	var shake := HitCameraShake.new()
	shake.configure(capped_style)
	shake.kick()
	var reached_cap := false
	for index in range(64):
		var offset := shake.tick(capped_style.duration_seconds / 64.0)
		check(offset.length() <= capped_style.maximum_offset_meters + 0.000001, "vector length cap applies to both axes together")
		reached_cap = reached_cap or is_equal_approx(offset.length(), capped_style.maximum_offset_meters)
	check(reached_cap, "configured length cap is exercised")


func _new_shake() -> HitCameraShake:
	var shake := HitCameraShake.new()
	shake.configure(DEFAULT_STYLE)
	return shake


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
