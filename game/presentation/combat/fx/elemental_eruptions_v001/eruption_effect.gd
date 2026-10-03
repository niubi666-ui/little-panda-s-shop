extends Node3D
## Deterministic presentation sampler: all art layers share one pauseable local clock.
## Ground traces, debris and lights never create collisions, hits or status effects.
const Profile = preload("res://presentation/combat/fx/elemental_eruptions_v001/eruption_profile.gd")
@export var profile: Profile
var _time := 0.0
var _running := true
var _speed := 1.0
var _rng := RandomNumberGenerator.new()
var _spires: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _mists: Array[Dictionary] = []
var _lights: Array[Dictionary] = []
var _chips: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _chip_batch: MultiMeshInstance3D
var _spark_batch: MultiMeshInstance3D
var _ground_material: ShaderMaterial
var _initialized := false

func _ready() -> void:
	assert(profile != null and profile.duration_sec > 0.0)
	assert(profile.spire_meshes.size() > 0 and profile.station_count > 1)
	assert(profile.chip_mesh != null and profile.rise_curve != null)
	_rng.seed = profile.visual_seed
	_build_ground()
	_build_spires()
	_build_debris()
	_build_mist()
	_initialized = true
	seek_visual(0.0)

func _process(delta: float) -> void:
	if not _running or not _initialized:
		return
	seek_visual(_time + delta * _speed)
	if _time >= profile.duration_sec:
		queue_free()

func set_time_running(running: bool) -> void:
	_running = running

func set_playback_speed(speed: float) -> void:
	assert(is_finite(speed) and speed >= 0.0)
	_speed = speed

func restart() -> void:
	seek_visual(0.0)

func finish() -> void:
	_running = false
	hide()
	queue_free()

func seek_visual(time: float) -> void:
	if not _initialized:
		return
	_time = clampf(time, 0.0, profile.duration_sec)
	_ground_material.set_shader_parameter("visual_time", _time)
	for entry: Dictionary in _spires:
		var node: MeshInstance3D = entry.node
		var age: float = _time - float(entry.delay)
		var sink_start: float = profile.rise_sec + profile.hold_sec
		node.visible = age >= 0.0 and age < sink_start + profile.sink_sec
		if not node.visible:
			continue
		var rise: float = profile.rise_curve.sample_baked(clampf(age / profile.rise_sec, 0.0, 1.0))
		if age > sink_start:
			rise *= profile.vanish_curve.sample_baked(clampf((age - sink_start) / profile.sink_sec, 0.0, 1.0))
		var origin: Vector3 = entry.origin
		node.position = origin + Vector3.DOWN * float(entry.height) * (1.0 - rise)
		var material: ShaderMaterial = entry.material
		material.set_shader_parameter("visual_time", maxf(age, 0.0))
		material.set_shader_parameter("reveal", clampf(rise, 0.0, 1.0))
	for entry: Dictionary in _rings:
		var node: MeshInstance3D = entry.node
		var age: float = _time - float(entry.delay)
		node.visible = age >= 0.0 and age < profile.ring_duration
		if node.visible:
			var mat: ShaderMaterial = entry.material
			mat.set_shader_parameter("progress", clampf(age / profile.ring_duration, 0.0, 1.0))
	_sample_debris(_chip_batch, _chips, profile.chip_gravity, true)
	_sample_debris(_spark_batch, _sparks, profile.spark_gravity, false)
	for entry: Dictionary in _mists:
		var node: MeshInstance3D = entry.node
		var age: float = _time - float(entry.delay)
		var life: float = entry.life
		node.visible = age >= 0.0 and age < life
		if not node.visible:
			continue
		var p: float = age / life
		var start: Vector3 = entry.origin
		var drift: Vector3 = entry.drift
		node.position = start + drift * age + Vector3.UP * profile.mist_rise * sqrt(p)
		node.scale = Vector3.ONE * float(entry.size) * lerpf(0.28, 1.65, sqrt(p))
		var mat: ShaderMaterial = entry.material
		mat.set_shader_parameter("progress", p)
	for entry: Dictionary in _lights:
		var light: OmniLight3D = entry.node
		var age: float = _time - float(entry.delay)
		var pulse: float = maxf(0.0, 1.0 - absf(age) / profile.light_pulse_sec)
		light.light_energy = profile.light_energy * pulse * pulse
		light.visible = pulse > 0.0

func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(profile.ground_width, profile.length_m)
	_ground_material = profile.ground_material.duplicate() as ShaderMaterial
	_ground_material.set_shader_parameter("anticipation", profile.anticipation_sec)
	_ground_material.set_shader_parameter("travel", profile.travel_sec)
	_ground_material.set_shader_parameter("duration", profile.duration_sec)
	var trace := _mesh_node("FractureTrail", plane, _ground_material)
	trace.position = Vector3(0.0, profile.ground_height, -profile.length_m * 0.5)
	trace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_ring(Vector3(0.0, profile.ground_height * 2.0, 0.0), 0.0, profile.ring_radius)

func _build_spires() -> void:
	for i: int in profile.station_count:
		var f: float = float(i) / float(profile.station_count - 1)
		var center := Vector3(_rng.randf_range(-profile.lateral_spread, profile.lateral_spread), 0.0, -lerpf(profile.length_m / float(profile.station_count), profile.length_m * 0.9, f))
		var delay: float = profile.anticipation_sec + f * profile.travel_sec
		var height: float = lerpf(profile.height_range.x, profile.height_range.y, smoothstep(0.0, 1.0, f))
		var width: float = _rng.randf_range(profile.width_range.x, profile.width_range.y)
		_add_spire(center, height, width, delay, i)
		for side: int in [-1, 1]:
			var satellite_height: float = height * _rng.randf_range(profile.satellite_scale.x, profile.satellite_scale.y)
			var satellite_center: Vector3 = center + Vector3(float(side) * width * 0.42, 0.0, _rng.randf_range(-width, width) * 0.2)
			_add_spire(satellite_center, satellite_height, width * 0.7, delay + profile.rise_sec * 0.18, i + side)
		_add_ring(center + Vector3.UP * profile.ground_height * 2.0, delay, width * 1.9)
		var light := OmniLight3D.new()
		light.name = "EruptionLight%d" % i
		light.position = center + Vector3.UP * profile.light_height
		light.light_color = profile.light_color
		light.omni_range = profile.light_radius
		light.shadow_enabled = false
		light.light_energy = 0.0
		add_child(light)
		_lights.append({"node": light, "delay": delay})
	_build_crown()

func _build_crown() -> void:
	var center := Vector3(0.0, 0.0, -profile.length_m * 0.9)
	var delay: float = profile.anticipation_sec + profile.travel_sec
	for i: int in profile.crown_count:
		var angle: float = TAU * float(i) / float(profile.crown_count)
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var height: float = profile.height_range.y * _rng.randf_range(profile.crown_height_scale.x, profile.crown_height_scale.y)
		var width: float = profile.width_range.y * profile.crown_width_scale
		_add_spire(center + outward * profile.crown_radius, height, width, delay + float(i) * profile.crown_stagger_sec, i)
		var node: MeshInstance3D = _spires.back().node
		# Fan the final cluster outward rather than repeating a straight hedge.
		var axis := Vector3.UP.cross(outward).normalized()
		var tilt := Basis(Quaternion(axis, deg_to_rad(profile.lean_deg.y)))
		node.basis = (tilt * Basis(Vector3.UP, angle)).scaled_local(Vector3(width, height, width))
	_add_ring(center + Vector3.UP * profile.ground_height * 3.0, delay, profile.ring_radius * 1.5)

func _add_spire(origin: Vector3, height: float, width: float, delay: float, index: int) -> void:
	var mat: ShaderMaterial = profile.spire_material.duplicate() as ShaderMaterial
	var mesh: Mesh = profile.spire_meshes[posmod(index, profile.spire_meshes.size())]
	var node := _mesh_node("Spire%d" % _spires.size(), mesh, mat)
	node.scale = Vector3(width, height, width)
	node.rotation = Vector3(deg_to_rad(_rng.randf_range(profile.lean_deg.x, profile.lean_deg.y)), _rng.randf_range(-PI, PI), deg_to_rad(_rng.randf_range(-profile.lean_deg.x, profile.lean_deg.x)))
	_spires.append({"node": node, "material": mat, "origin": origin, "height": height, "delay": delay})

func _add_ring(origin: Vector3, delay: float, radius: float) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * radius * 2.0
	var material: ShaderMaterial = profile.ring_material.duplicate() as ShaderMaterial
	var node := _mesh_node("ShockRing%d" % _rings.size(), mesh, material)
	node.position = origin
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rings.append({"node": node, "material": material, "delay": delay})

func _build_debris() -> void:
	_chip_batch = _new_batch("FragmentInstances", profile.chip_mesh, profile.chip_material, profile.chip_count + profile.crown_chip_count)
	var spark_mesh := PrismMesh.new()
	spark_mesh.size = Vector3(0.2, 1.0, 0.2)
	_spark_batch = _new_batch("GlitterInstances", spark_mesh, profile.spark_material, profile.spark_count + profile.crown_spark_count)
	_spark_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i: int in profile.chip_count:
		_chips.append(_particle_definition(i, profile.chip_count, profile.chip_size, profile.chip_speed, profile.chip_up_speed, profile.chip_lifetime))
	for i: int in profile.spark_count:
		_sparks.append(_particle_definition(i, profile.spark_count, profile.spark_size, profile.spark_speed, profile.spark_speed, profile.spark_lifetime))
	for i: int in profile.crown_chip_count:
		_chips.append(_crown_particle(profile.chip_size, profile.chip_speed, profile.chip_up_speed, profile.chip_lifetime))
	for i: int in profile.crown_spark_count:
		_sparks.append(_crown_particle(profile.spark_size, profile.spark_speed, profile.spark_speed, profile.spark_lifetime))

func _crown_particle(sizes: Vector2, speeds: Vector2, up_speeds: Vector2, lifetimes: Vector2) -> Dictionary:
	var entry: Dictionary = _particle_definition(1, 2, sizes, speeds, up_speeds, lifetimes)
	entry.velocity *= profile.crown_burst_speed_scale
	return entry

func _particle_definition(index: int, count: int, sizes: Vector2, speeds: Vector2, up_speeds: Vector2, lifetimes: Vector2) -> Dictionary:
	var f: float = float(index) / float(maxi(1, count - 1))
	var angle: float = _rng.randf_range(-PI, PI)
	var radial: float = _rng.randf_range(speeds.x, speeds.y)
	var origin := Vector3(_rng.randf_range(-profile.lateral_spread, profile.lateral_spread), profile.ground_height, -lerpf(profile.length_m / float(profile.station_count), profile.length_m * 0.9, f))
	var velocity := Vector3(cos(angle) * radial, _rng.randf_range(up_speeds.x, up_speeds.y), sin(angle) * radial)
	var axis := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()
	if axis.length_squared() < 0.001:
		axis = Vector3.UP
	return {"origin": origin, "velocity": velocity, "delay": profile.anticipation_sec + f * profile.travel_sec, "life": _rng.randf_range(lifetimes.x, lifetimes.y), "size": _rng.randf_range(sizes.x, sizes.y), "axis": axis, "phase": _rng.randf_range(-PI, PI), "spin": _rng.randf_range(-TAU, TAU), "tint": Color.from_hsv(_rng.randf(), 0.0, _rng.randf_range(0.7, 1.0))}

func _sample_debris(batch: MultiMeshInstance3D, entries: Array[Dictionary], gravity: float, bounce: bool) -> void:
	for i: int in entries.size():
		var entry: Dictionary = entries[i]
		var age: float = _time - float(entry.delay)
		var life: float = entry.life
		if age < 0.0 or age >= life:
			batch.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.00001), Vector3.DOWN * 100.0))
			continue
		var start: Vector3 = entry.origin
		var velocity: Vector3 = entry.velocity
		var offset: Vector3 = velocity * age + Vector3.DOWN * gravity * age * age * 0.5
		if bounce:
			var first_hit: float = (velocity.y + sqrt(velocity.y * velocity.y + 2.0 * gravity * start.y)) / gravity
			if age > first_hit:
				var after: float = age - first_hit
				var bounce_speed: float = (gravity * first_hit - velocity.y) * profile.chip_bounce
				offset.y = maxf(0.0, bounce_speed * after - gravity * after * after * 0.5) - start.y
				offset.x = velocity.x * first_hit + velocity.x * after * profile.chip_drag
				offset.z = velocity.z * first_hit + velocity.z * after * profile.chip_drag
		var scale_factor: float = profile.chip_scale_curve.sample_baked(clampf(age / life, 0.0, 1.0))
		var axis: Vector3 = entry.axis
		var basis := Basis(Quaternion(axis, float(entry.phase) + float(entry.spin) * age))
		if not bounce:
			var direction: Vector3 = (velocity - Vector3.UP * gravity * age).normalized()
			if direction.length_squared() > 0.001:
				basis = Basis(Quaternion(Vector3.UP, direction))
		basis = basis.scaled(Vector3.ONE * float(entry.size) * scale_factor)
		batch.multimesh.set_instance_transform(i, Transform3D(basis, start + offset))
		batch.multimesh.set_instance_color(i, entry.tint)

func _build_mist() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for i: int in profile.mist_count:
		var f: float = float(i) / float(maxi(1, profile.mist_count - 1))
		var angle: float = _rng.randf_range(-PI, PI)
		var material: ShaderMaterial = profile.mist_material.duplicate() as ShaderMaterial
		material.set_shader_parameter("particle_seed", _rng.randf_range(0.0, 100.0))
		var node := _mesh_node("RollingMist%d" % i, quad, material)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var origin := Vector3(_rng.randf_range(-profile.lateral_spread, profile.lateral_spread), profile.ground_height, -lerpf(profile.length_m / float(profile.station_count), profile.length_m * 0.9, f))
		_mists.append({"node": node, "material": material, "origin": origin, "delay": profile.anticipation_sec + f * profile.travel_sec, "life": _rng.randf_range(profile.mist_lifetime.x, profile.mist_lifetime.y), "size": _rng.randf_range(profile.mist_size.x, profile.mist_size.y), "drift": Vector3(cos(angle), 0.0, sin(angle)) * profile.mist_spread})

func _mesh_node(label: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	return node

func _new_batch(label: String, mesh: Mesh, material: Material, count: int) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	node.material_override = material.duplicate()
	node.custom_aabb = AABB(Vector3(-profile.length_m, -profile.length_m, -profile.length_m * 2.0), Vector3.ONE * profile.length_m * 3.0)
	add_child(node)
	return node
