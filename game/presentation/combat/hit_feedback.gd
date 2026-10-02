extends Node3D
const BarState = preload("res://presentation/combat/damage_bar_state.gd")
var actor
var settings
var visual: Node3D
var bar: MeshInstance3D
var bar_material: ShaderMaterial
var bar_state: BarState
var flash_left := 0.0
var _flashing := false
var _overlays: Dictionary = {}
var _bursts: Array[CPUParticles3D] = []
var _burst_height: float
func configure(owner_actor, model: Node3D, profile, body_height: float) -> void:
	actor = owner_actor
	visual = model
	settings = profile
	_burst_height = body_height
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		_overlays[mesh] = [mesh.material_override, mesh.material_overlay]
	if visual is MeshInstance3D: _overlays[visual] = [visual.material_override, visual.material_overlay]
	bar_state = BarState.new(settings.bar_delay_sec, settings.bar_drain_ratio_per_sec)
	bar_state.set_health(actor.health.current / actor.health.maximum)
	bar = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = settings.bar_size
	bar.mesh = quad
	bar_material = settings.bar_material.duplicate()
	bar.material_override = bar_material
	bar.position.y = settings.bar_height
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bar)
	actor.health.damaged.connect(_on_damage)
func _on_damage(_amount: float) -> void:
	bar_state.set_health(actor.health.current / actor.health.maximum)
	flash_left = settings.flash_sec
	_flashing = true
	for mesh in _overlays:
		mesh.material_override = settings.flash_material
		mesh.material_overlay = null
	var burst: CPUParticles3D = settings.hit_particles.instantiate()
	add_child(burst)
	burst.position.y = _burst_height
	burst.finished.connect(burst.queue_free)
	_bursts.append(burst)
	burst.emitting = true
	burst.restart()
func tick(delta: float) -> void:
	flash_left = maxf(0.0, flash_left - delta)
	if _flashing and flash_left <= 0.0:
		_flashing = false
		for mesh in _overlays:
				mesh.material_override = _overlays[mesh][0]
				mesh.material_overlay = _overlays[mesh][1]
	bar_state.tick(delta)
	bar_material.set_shader_parameter("health_ratio", bar_state.current)
	bar_material.set_shader_parameter("trailing_ratio", bar_state.trailing)
	bar.visible = actor.health.alive() or bar_state.trailing > 0.0
	visual.visible = actor.health.alive() or flash_left > 0.0
	for i in range(_bursts.size() - 1, -1, -1):
		if not is_instance_valid(_bursts[i]): _bursts.remove_at(i)
		else: _bursts[i].speed_scale = 1.0 if delta > 0.0 else 0.0
func has_tail() -> bool:
	return flash_left > 0.0 or bar_state.trailing > 0.0 or not _bursts.is_empty()
