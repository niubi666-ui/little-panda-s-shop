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
var _visual_rest := Vector3.ZERO
var _lurch_left := 0.0
var _lurch_direction := Vector3.ZERO
func configure(owner_actor, model: Node3D, profile, body_height: float) -> void:
	actor = owner_actor
	visual = model
	settings = profile
	_burst_height = body_height
	_visual_rest = visual.position
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
	# 击退在伤害之后才施加：方向在下一次 tick 从速度里读
	_lurch_left = settings.lurch_sec
	_lurch_direction = Vector3.ZERO
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
	_tick_lurch(delta)
	bar_state.tick(delta)
	bar_material.set_shader_parameter("health_ratio", bar_state.current)
	bar_material.set_shader_parameter("trailing_ratio", bar_state.trailing)
	bar.visible = actor.health.alive() or bar_state.trailing > 0.0
	if settings.bar_hide_when_full and actor.health.alive() and bar_state.current >= 0.999 and bar_state.trailing <= bar_state.current: bar.visible = false
	visual.visible = actor.health.alive() or flash_left > 0.0
	for i in range(_bursts.size() - 1, -1, -1):
		if not is_instance_valid(_bursts[i]): _bursts.remove_at(i)
		else: _bursts[i].speed_scale = 1.0 if delta > 0.0 else 0.0
func _tick_lurch(delta: float) -> void:
	if _lurch_left <= 0.0:
		visual.position = _visual_rest
		return
	if _lurch_direction.is_zero_approx():
		var planar := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
		# 霸体、不被击退的敌人不晃，只闪白
		if planar.length() < 0.5:
			_lurch_left = 0.0
			return
		_lurch_direction = planar.normalized()
	_lurch_left = maxf(0.0, _lurch_left - delta)
	var t: float = 1.0 - _lurch_left / float(settings.lurch_sec)
	var peak: float = settings.lurch_peak_fraction
	var amount: float = t / peak if t < peak else pow(1.0 - (t - peak) / (1.0 - peak), 2.0)
	visual.position = _visual_rest + _lurch_direction * settings.lurch_m * amount

func has_tail() -> bool:
	return flash_left > 0.0 or bar_state.trailing > 0.0 or not _bursts.is_empty()
