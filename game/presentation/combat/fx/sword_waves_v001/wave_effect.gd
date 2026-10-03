extends Node3D
## Reusable flight visual. The adapter owns motion and lifetime in real combat.
const Profile = preload("res://presentation/combat/fx/sword_waves_v001/wave_profile.gd")
@export var profile: Profile
var _time := 0.0
var _running := true
var _external_clock := false
var _initialized := false
var _exit_progress := 0.0
var _art: Node3D
var _rng := RandomNumberGenerator.new()
var _animated_materials: Array[ShaderMaterial] = []
var _mists: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _batch: MultiMeshInstance3D
var _light: OmniLight3D

func _ready() -> void:
	assert(profile != null and profile.blade_mesh != null and profile.shard_mesh != null)
	_rng.seed = profile.visual_seed
	_art = Node3D.new()
	add_child(_art)
	_build_blade()
	_build_ribbons()
	_build_particles()
	_build_mist()
	_light = OmniLight3D.new()
	_light.light_color = profile.light_color
	_light.light_energy = profile.light_energy
	_light.omni_range = profile.light_range
	_light.shadow_enabled = false
	_art.add_child(_light)
	_initialized = true
	seek_visual(0.0)

func configure_effect(_fact: Dictionary) -> void:
	_external_clock = true
	_art.scale = profile.projectile_unit_scale

func sync_effect(_fact: Dictionary, delta: float) -> void:
	if _running and delta > 0.0: seek_visual(_time + delta)

func _process(delta: float) -> void:
	if not _external_clock and _running: seek_visual(_time + delta)

func set_time_running(enabled: bool) -> void:
	_running = enabled

func finish(_reason: String = "") -> void:
	_running = false
	hide()

func restart() -> void:
	show()
	set_exit_progress(0.0)
	seek_visual(0.0)

func set_exit_progress(progress: float) -> void:
	_exit_progress = clampf(progress,0.0,1.0)

func seek_visual(time: float) -> void:
	if not _initialized: return
	_time = maxf(time, 0.0)
	for mat in _animated_materials:
		mat.set_shader_parameter("visual_time", _time)
		mat.set_shader_parameter("exit_progress", _exit_progress)
	for i: int in _particles.size():
		var entry: Dictionary = _particles[i]
		var age: float = fposmod(maxf(0.0, _time - float(entry.delay)), float(entry.life))
		var visible_scale := 0.0 if _time < float(entry.delay) else 1.0
		var p: float = age / float(entry.life)
		var size: float = float(entry.size) * profile.fade_curve.sample_baked(p) * visible_scale * (1.0-_exit_progress)
		var point: Vector3 = entry.origin + entry.velocity * age + Vector3.DOWN * profile.trail_gravity * age * age * 0.5
		var basis := Basis(Quaternion(entry.axis, float(entry.phase) + age * float(entry.spin))).scaled(Vector3.ONE * maxf(size, 0.00001))
		_batch.multimesh.set_instance_transform(i, Transform3D(basis, point))
	for entry: Dictionary in _mists:
		var age: float = fposmod(maxf(0.0, _time - float(entry.delay)), float(entry.life))
		var p: float = age / float(entry.life)
		var node: MeshInstance3D = entry.node
		node.visible = _time >= float(entry.delay)
		node.position = entry.origin + Vector3.BACK * profile.trail_speed * age
		node.scale = Vector3.ONE * float(entry.size) * lerpf(0.35, 1.5, p)
		var mat: ShaderMaterial = entry.material
		mat.set_shader_parameter("progress", p)
		mat.set_shader_parameter("opacity",profile.mist_opacity*(1.0-_exit_progress))
	_light.light_energy = profile.light_energy * (0.92 + sin(_time * 17.0) * 0.08) * (1.0-_exit_progress)

func _mesh(name_text: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_text
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_art.add_child(node)
	return node

func _animated_copy(material: ShaderMaterial) -> ShaderMaterial:
	var copy := material.duplicate() as ShaderMaterial
	_animated_materials.append(copy)
	return copy

func _build_blade() -> void:
	var blade_material := _animated_copy(profile.blade_material)
	var blade := _mesh("CrescentCore", profile.blade_mesh, blade_material)
	blade.scale = profile.blade_scale
	blade.rotation_degrees.z = profile.blade_tilt_deg
	var halo := _mesh("CrescentCorona", profile.blade_mesh, _animated_copy(profile.halo_material))
	halo.scale = profile.blade_scale * profile.halo_scale
	halo.rotation_degrees.z = profile.blade_tilt_deg
	for i: int in profile.echo_offsets.size():
		var mat := _animated_copy(profile.halo_material)
		mat.set_shader_parameter("opacity", profile.echo_opacity[i])
		var echo := _mesh("WakeArc%d" % i, profile.blade_mesh, mat)
		echo.scale = profile.blade_scale * profile.echo_scales[i]
		echo.position = profile.echo_offsets[i]
		echo.rotation_degrees.z = profile.blade_tilt_deg
	for i: int in profile.embedded_shard_count:
		var f: float = float(i + 1) / float(profile.embedded_shard_count + 1)
		var arc_t: float = (f * 2.0 - 1.0) * 0.8
		var x: float = arc_t * profile.blade_scale.x
		var shard := _mesh("CrystalInlay%d" % i, profile.shard_mesh, blade_material)
		var shard_size := _rng.randf_range(profile.embedded_shard_size.x, profile.embedded_shard_size.y)
		shard.scale = Vector3(shard_size * 2.0, shard_size, shard_size * 2.0)
		var tilt := Basis(Vector3.BACK,deg_to_rad(profile.blade_tilt_deg))
		var z: float = (-0.45+0.67*pow(absf(arc_t),1.82))*profile.blade_scale.z
		shard.position = tilt*Vector3(x,shard_size*0.12,z+0.04)
		shard.basis = (tilt*Basis.from_euler(Vector3(-0.7,0.0,-x*0.45))).scaled_local(Vector3(shard_size*2.0,shard_size,shard_size*2.0))

func _build_ribbons() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ribbon: int in profile.ribbon_count:
		var side: float = -1.0 if ribbon % 2 == 0 else 1.0
		var lateral: float = side * _rng.randf_range(0.3, 1.0) * profile.ribbon_spread
		var phase := _rng.randf()
		for segment: int in profile.ribbon_segments:
			for corner: Vector2 in [Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(1,0)]:
				var p: float = (float(segment) + corner.x) / float(profile.ribbon_segments)
				var spread: float = lateral * (1.0 + p * 0.3)
				var width: float = profile.ribbon_width * (1.0 - p) * (corner.y - 0.5)
				surface.set_uv(Vector2(p, corner.y))
				surface.set_color(Color(phase, 1.0, 1.0))
				surface.add_vertex(Vector3(spread + width, sin(p * PI) * profile.ribbon_wave, p * profile.ribbon_length + 0.05))
	surface.generate_normals()
	_mesh("StreamingRibbons", surface.commit(), _animated_copy(profile.ribbon_material))

func _build_particles() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = profile.shard_mesh
	mm.instance_count = profile.trail_count
	_batch = MultiMeshInstance3D.new()
	_batch.name = "TrailingFragments"
	_batch.multimesh = mm
	_batch.material_override = profile.shard_material
	_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_batch.custom_aabb = AABB(Vector3(-8,-5,-3),Vector3(16,10,18))
	_art.add_child(_batch)
	for i: int in profile.trail_count:
		var x := _rng.randf_range(-profile.trail_spread, profile.trail_spread)
		var axis := Vector3(_rng.randf_range(-1.0,1.0),_rng.randf_range(-1.0,1.0),_rng.randf_range(-1.0,1.0)).normalized()
		_particles.append({"origin":Vector3(x, _rng.randf_range(-0.15,0.15), absf(x)*0.15),"velocity":Vector3(x*0.3,_rng.randf_range(-0.4,0.5),profile.trail_speed*_rng.randf_range(0.65,1.15)),"delay":_rng.randf_range(0.0,profile.trail_lifetime.x),"life":_rng.randf_range(profile.trail_lifetime.x,profile.trail_lifetime.y),"size":_rng.randf_range(profile.trail_size.x,profile.trail_size.y),"axis":axis,"phase":_rng.randf_range(-PI,PI),"spin":_rng.randf_range(-TAU,TAU)})

func _build_mist() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for i: int in profile.mist_count:
		var mat := profile.mist_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("opacity",profile.mist_opacity)
		mat.set_shader_parameter("particle_seed",_rng.randf_range(0.0,100.0))
		var node := _mesh("TrailingVapor%d" % i,quad,mat)
		_mists.append({"node":node,"material":mat,"origin":Vector3(_rng.randf_range(-profile.trail_spread,profile.trail_spread),0.0,0.1),"life":_rng.randf_range(profile.trail_lifetime.x,profile.trail_lifetime.y),"delay":_rng.randf_range(0.0,profile.trail_lifetime.x),"size":_rng.randf_range(profile.mist_size.x,profile.mist_size.y)})
