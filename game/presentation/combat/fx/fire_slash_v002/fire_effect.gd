extends "res://presentation/combat/fx/golden_trail_v001/golden_effect.gd"
## Blender-baked flame sheet + sharp hot edge + short-lived plume/ember layers.
## This adapter owns visual clocks only. It never schedules damage or hit-stop.
@export var core_material: ShaderMaterial
@export var extra_emitter_paths: Array[NodePath]
@export var flame_span_ratio: float
@export var flame_center_ratio: float
@export var flame_emitter_thickness: float
@export var flash_duration_sec: float
@export var flash_peak_energy: float
@export var flash_height: float
var _extra_emitters: Array[CPUParticles3D] = []
var _core_ribbon: MeshInstance3D
var _flash_left := 0.0
var _fire_light: OmniLight3D

func _ready() -> void:
	assert(core_material != null and not extra_emitter_paths.is_empty())
	assert(flame_span_ratio > 0.0 and flame_emitter_thickness > 0.0)
	assert(flash_duration_sec > 0.0 and flash_peak_energy >= 0.0)
	core_material = core_material.duplicate()
	super._ready()
	_core_ribbon = MeshInstance3D.new()
	_core_ribbon.name = "HotEdge"
	_core_ribbon.mesh = _mesh
	_core_ribbon.material_override = core_material
	_core_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core_ribbon.top_level = true
	add_child(_core_ribbon)
	_core_ribbon.global_transform = Transform3D.IDENTITY
	for path in extra_emitter_paths:
		var emitter := get_node(path) as CPUParticles3D
		assert(emitter != null, "Fire layer must be a configured CPUParticles3D: " + str(path))
		_extra_emitters.append(emitter)
	_fire_light = $FireLight
	_fire_light.top_level = true
	_fire_light.light_energy = 0.0
	_fire_light.hide()

func configure_blade(length: float) -> void:
	super.configure_blade(length)
	for emitter in _extra_emitters:
		emitter.position = Vector3(0.0, 0.0, -length * flame_center_ratio)
		emitter.emission_box_extents = Vector3(flame_emitter_thickness, flame_emitter_thickness, length * flame_span_ratio / 2.0)

func set_active(active: bool) -> void:
	if active and not _active:
		_flash_left = flash_duration_sec
	super.set_active(active)
	for emitter in _extra_emitters: emitter.emitting = active
	_update_light()

func set_time_running(running: bool) -> void:
	super.set_time_running(running)
	for emitter in _extra_emitters: emitter.speed_scale = _speed if running else 0.0

func set_playback_speed(speed: float) -> void:
	super.set_playback_speed(speed)
	for emitter in _extra_emitters: emitter.speed_scale = speed if _running else 0.0

func _process(delta: float) -> void:
	if _running:
		_flash_left = flash_duration_sec if _active else maxf(0.0, _flash_left - delta * _speed)
	super._process(delta)
	core_material.set_shader_parameter("heat_phase", _visual_clock)
	_update_light()

func sample_current_pose() -> void:
	# Sample once the presentation adapter has placed the sword for this physics pose.
	if _active or _end_pending:
		_fire_light.global_position = global_position + Vector3.UP * flash_height
	_process(0.0)

func finish_at_current_pose() -> void:
	if _active:
		set_active(false)
		sample_current_pose()

func _update_light() -> void:
	if not is_instance_valid(_fire_light): return
	var envelope := clampf(_flash_left / flash_duration_sec, 0.0, 1.0)
	_fire_light.light_energy = flash_peak_energy * envelope * envelope
	_fire_light.visible = envelope > 0.0

func clear_tail() -> void:
	super.clear_tail()
	for emitter in _extra_emitters:
		emitter.restart()
		emitter.emitting = false
	_flash_left = 0.0
	_update_light()
