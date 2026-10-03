extends "res://presentation/combat/fx/elemental_eruptions_v001/eruption_effect.gd"
## Reuse approved fragments, mist and rings; replace only the spire trajectory.
## No collisions, combat requests or gameplay random streams.
const FallingProfile = preload("res://presentation/combat/fx/frostfall_v001/frostfall_profile.gd")
var _stations: Array[Dictionary] = []
var _fall_trails: Array[Dictionary] = []
var _impact_flashes: Array[Dictionary] = []

func _ready() -> void:
	assert(profile is FallingProfile)
	assert(profile.fall_sec > 0.0 and profile.spawn_height_m > 0.0 and profile.settle_sec > 0.0)
	assert(profile.fall_curve != null and profile.settle_curve != null and profile.flash_sec > 0.0)
	super._ready()

func _build_ground() -> void:
	super._build_ground()
	# The fracture front follows the impact procession rather than the sky spawn.
	_ground_material.set_shader_parameter("anticipation", profile.anticipation_sec + profile.fall_sec)

func _build_spires() -> void:
	for i: int in profile.station_count:
		var f: float = float(i) / float(profile.station_count - 1)
		var center := Vector3(_rng.randf_range(-profile.lateral_spread, profile.lateral_spread), 0.0, -lerpf(profile.length_m / float(profile.station_count), profile.length_m * 0.9, f))
		var delay: float = profile.anticipation_sec + f * profile.travel_sec
		var impact: float = delay + profile.fall_sec
		_stations.append({"origin":center, "delay":delay, "impact":impact})
		var height: float = lerpf(profile.height_range.x, profile.height_range.y, smoothstep(0.0, 1.0, f))
		var width: float = _rng.randf_range(profile.width_range.x, profile.width_range.y)
		_add_falling_spire(center, height, width, delay, i)
		for side: int in [-1, 1]:
			var satellite_height: float = height * _rng.randf_range(profile.satellite_scale.x, profile.satellite_scale.y)
			var satellite_center := center + Vector3(float(side) * width * 0.42, 0.0, _rng.randf_range(-width, width) * 0.2)
			_add_falling_spire(satellite_center, satellite_height, width * 0.7, delay + profile.satellite_delay_sec, i + side)
		_add_ring(center + Vector3.UP * profile.ground_height * 2.0, impact, width * 1.9)
		_add_impact_flash(center, impact, profile.flash_size_m)
		var light := OmniLight3D.new()
		light.name = "FrostfallImpactLight%d" % i
		light.position = center + Vector3.UP * profile.light_height
		light.light_color = profile.light_color
		light.omni_range = profile.light_radius
		light.shadow_enabled = false
		add_child(light)
		_lights.append({"node":light, "delay":impact})
	_build_crown()

func _build_crown() -> void:
	var center: Vector3 = _stations.back().origin
	var delay: float = _stations.back().delay
	for i: int in profile.crown_count:
		var angle: float = TAU * float(i) / float(profile.crown_count)
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var height: float = profile.height_range.y * _rng.randf_range(profile.crown_height_scale.x, profile.crown_height_scale.y)
		var width: float = profile.width_range.y * profile.crown_width_scale
		_add_falling_spire(center + outward * profile.crown_radius, height, width, delay + float(i) * profile.crown_stagger_sec, i)
		# The final downward points remain planted while the broad tops fan outward.
		var entry: Dictionary = _spires.back()
		var lean := Basis(Quaternion(Vector3.UP.cross(outward).normalized(), -deg_to_rad(profile.lean_deg.y)))
		entry.fall_basis = (lean * Basis(Vector3.UP, angle) * Basis(Vector3.FORWARD, PI)).scaled_local(Vector3(width, height, width))
	_add_ring(center + Vector3.UP * profile.ground_height * 3.0, delay + profile.fall_sec, profile.ring_radius * 1.5)
	_add_impact_flash(center, delay + profile.fall_sec, profile.flash_size_m * 1.4)

func _add_falling_spire(origin: Vector3, height: float, width: float, delay: float, index: int) -> void:
	_add_spire(origin, height, width, delay + profile.fall_sec, index)
	var entry: Dictionary = _spires.back()
	var yaw: float = _rng.randf_range(-PI, PI)
	var lean: float = deg_to_rad(_rng.randf_range(profile.lean_deg.x, profile.lean_deg.y))
	entry.fall_basis = (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean) * Basis(Vector3.FORWARD, PI)).scaled_local(Vector3(width, height, width))
	entry.spawn = delay
	var mat: ShaderMaterial = profile.trail_material.duplicate() as ShaderMaterial
	var trail_length: float = profile.trail_length_m * height / profile.height_range.y
	var mesh := QuadMesh.new()
	mesh.size = Vector2(profile.trail_width_m * width / profile.width_range.y, trail_length)
	var nodes: Array[MeshInstance3D] = []
	for cross_plane: int in 2:
		var trail := _mesh_node("FallWake%d_%d" % [_spires.size(), cross_plane], mesh, mat)
		trail.rotation.y = yaw + PI * float(cross_plane) * 0.5
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nodes.append(trail)
	_fall_trails.append({"nodes":nodes, "material":mat, "spire":entry.node, "delay":delay, "length":trail_length})

func _add_impact_flash(origin: Vector3, delay: float, size: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var mat: ShaderMaterial = profile.flash_material.duplicate() as ShaderMaterial
	var node := _mesh_node("IceImpactFlash%d" % _impact_flashes.size(), quad, mat)
	node.position = origin + Vector3.UP * profile.ground_height * 4.0
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_impact_flashes.append({"node":node, "material":mat, "delay":delay})

func _particle_definition(index: int, count: int, sizes: Vector2, speeds: Vector2, up_speeds: Vector2, lifetimes: Vector2) -> Dictionary:
	var entry: Dictionary = super._particle_definition(index, count, sizes, speeds, up_speeds, lifetimes)
	var f: float = float(index) / float(maxi(1, count - 1))
	var station: Dictionary = _stations[roundi(f * float(_stations.size() - 1))]
	entry.origin = station.origin + Vector3(entry.origin.x, profile.ground_height, 0.0)
	entry.delay = station.impact
	return entry

func _build_mist() -> void:
	super._build_mist()
	for i: int in _mists.size():
		var f: float = float(i) / float(maxi(1, _mists.size() - 1))
		var station: Dictionary = _stations[roundi(f * float(_stations.size() - 1))]
		_mists[i].origin = station.origin + Vector3(_mists[i].origin.x, profile.ground_height, 0.0)
		_mists[i].delay = station.impact

func seek_visual(time: float) -> void:
	if not _initialized: return
	super.seek_visual(time)
	for entry: Dictionary in _spires:
		var node: MeshInstance3D = entry.node
		var since_spawn: float = _time - float(entry.spawn)
		var since_impact: float = _time - float(entry.delay)
		node.visible = since_spawn >= 0.0 and since_impact < profile.hold_sec + profile.sink_sec
		if not node.visible: continue
		var airborne: bool = since_impact < 0.0
		var p: float = clampf(since_spawn / profile.fall_sec, 0.0, 1.0)
		var above_ground: float = profile.spawn_height_m * (1.0 - profile.fall_curve.sample_baked(p)) if airborne else 0.0
		var settle: float = profile.settle_curve.sample_baked(clampf(since_impact / profile.settle_sec, 0.0, 1.0)) if not airborne else 0.0
		var shrink: float = profile.vanish_curve.sample_baked(clampf((since_impact - profile.hold_sec) / profile.sink_sec, 0.0, 1.0)) if since_impact > profile.hold_sec else 1.0
		var basis: Basis = entry.fall_basis.scaled(Vector3.ONE * maxf(shrink, 0.00001))
		# OBJ tip is local +Y at unit height. Anchor it to the falling/embedded tip.
		var tip: Vector3 = entry.origin + Vector3.UP * (above_ground - profile.embed_depth_m + settle)
		node.transform = Transform3D(basis, tip - basis * Vector3.UP)
		entry.material.set_shader_parameter("visual_time", maxf(since_impact, 0.0))
		entry.material.set_shader_parameter("reveal", shrink)
	for entry: Dictionary in _fall_trails:
		var age: float = _time - float(entry.delay)
		var visible_now: bool = age >= 0.0 and age < profile.fall_sec
		for node: MeshInstance3D in entry.nodes:
			node.visible = visible_now
			if visible_now: node.position = entry.spire.position + Vector3.UP * float(entry.length) * 0.5
		if visible_now:
			entry.material.set_shader_parameter("visual_time", age)
			entry.material.set_shader_parameter("intensity", sin(PI * age / profile.fall_sec))
	for entry: Dictionary in _impact_flashes:
		var age: float = _time - float(entry.delay)
		entry.node.visible = age >= 0.0 and age < profile.flash_sec
		if entry.node.visible: entry.material.set_shader_parameter("progress", age / profile.flash_sec)
	for entry: Dictionary in _lights:
		var age: float = _time - float(entry.delay)
		var pulse: float = maxf(0.0, 1.0 - maxf(age, 0.0) / profile.light_pulse_sec)
		entry.node.visible = age >= 0.0 and pulse > 0.0
		entry.node.light_energy = profile.light_energy * pulse * pulse
