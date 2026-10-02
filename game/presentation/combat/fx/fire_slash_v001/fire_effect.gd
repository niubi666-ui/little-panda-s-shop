extends Node3D
## Visual-only adapter; GPU ribbon spans the whole blade, not a point emitter.
const Trail = preload("res://addons/gputrail_preview/GPUTrail3D.gd")
@export var material: ShaderMaterial
@export var blade_span: float
@export var history_sec: float
@export var fade_out_sec: float
@export var sample_fps: int
var _trail: GPUParticles3D
var _material: ShaderMaterial
var _active := false
var _running := true
var _speed := 1.0
var _tail := 0.0
var _clock := 0.0
func _ready() -> void:
	assert(material != null and blade_span > 0.0 and history_sec > 0.0 and fade_out_sec > 0.0 and sample_fps > 0)
	_trail = Trail.new()
	add_child(_trail)
	_trail.rotation.x = PI / 2.0
	_trail.scale.y = blade_span / 2.0
	_trail.fixed_fps = sample_fps
	_trail.length_seconds = history_sec
	_trail.clip_overlaps = false
	_trail.dewiggle = false
	_trail.snap_to_transform = true
	_material = material.duplicate()
	_trail.draw_pass_1.material = _material
	_trail.visible = false
	_trail.speed_scale = 0.0
func set_active(active: bool) -> void:
	if active and not _active:
		_trail.restart()
		_trail.visible = true
		_tail = fade_out_sec
	_active = active
	$Particles.emitting = active
	_sync_speed()
func set_time_running(running: bool) -> void:
	_running = running
	_sync_speed()
func set_playback_speed(speed: float) -> void:
	assert(speed > 0.0)
	_speed = speed
	_sync_speed()
func _sync_speed() -> void:
	_trail.speed_scale = _speed if _running and _active else 0.0
	$Particles.speed_scale = _speed if _running else 0.0
func clear_tail() -> void:
	_active = false
	_tail = 0.0
	_trail.visible = false
	_trail.restart()
	$Particles.restart()
	$Particles.emitting = false
	_sync_speed()
func _process(delta: float) -> void:
	if _running:
		_clock += delta * _speed
		if not _active: _tail = maxf(_tail - delta * _speed, 0.0)
	_material.set_shader_parameter("flame_time", _clock)
	_material.set_shader_parameter("effect_opacity", 1.0 if _active else _tail / fade_out_sec)
	_trail.visible = _active or _tail > 0.0
