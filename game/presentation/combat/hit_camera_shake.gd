extends RefCounted
## A bounded visual pulse; no actor movement, camera ownership, or gameplay RNG.
## The caller assigns tick() to its camera offsets relative to their base values.

const ShakeStyle = preload("res://presentation/combat/hit_camera_shake_style.gd")

var _style: ShakeStyle
var _elapsed := 0.0
var _active := false


func configure(style: ShakeStyle) -> void:
	clear()
	_style = null
	if style == null:
		push_error("Hit camera shake requires an explicit presentation style.")
		return
	var error := style.validation_error()
	if not error.is_empty():
		push_error("Invalid hit camera shake style: " + error)
		return
	_style = style.duplicate() as ShakeStyle


func kick() -> void:
	if _style == null:
		push_error("Hit camera shake must be configured before kick().")
		return
	# Multi-target hits restart one pulse instead of summing camera displacement.
	_elapsed = 0.0
	_active = true


func tick(delta: float) -> Vector2:
	if not _active:
		return Vector2.ZERO
	assert(is_finite(delta) and delta >= 0.0, "Camera shake delta must be finite and nonnegative.")
	_elapsed = minf(_elapsed + delta, _style.duration_seconds)
	if _elapsed >= _style.duration_seconds:
		clear()
		return Vector2.ZERO
	var envelope := pow(1.0 - _elapsed / _style.duration_seconds, _style.envelope_power)
	var phase := _style.frequencies_hz * (TAU * _elapsed) + _style.phase_radians
	var offset := Vector2(sin(phase.x), sin(phase.y)) * _style.amplitude_meters * envelope
	return offset.limit_length(_style.maximum_offset_meters)


func clear() -> void:
	_elapsed = 0.0
	_active = false
