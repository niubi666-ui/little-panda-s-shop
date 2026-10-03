extends Node3D
const Profile = preload("res://presentation/combat/fx/sword_waves_v001/wave_profile.gd")
@export var profile: Profile
var _time := 0.0
var _running := true
var _ready_for_sampling := false
var _rng := RandomNumberGenerator.new()
var _batch: MultiMeshInstance3D
var _particles: Array[Dictionary] = []
var _mists: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _flash: MeshInstance3D
var _flash_mat: ShaderMaterial
var _light: OmniLight3D

func _ready() -> void:
	_rng.seed = profile.visual_seed
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = profile.shard_mesh
	multi.instance_count = profile.burst_count
	_batch = MultiMeshInstance3D.new()
	_batch.name = "ImpactFragments"
	_batch.multimesh = multi
	_batch.material_override = profile.shard_material
	_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_batch.custom_aabb = AABB(Vector3(-10,-10,-10),Vector3.ONE*20.0)
	add_child(_batch)
	for i: int in profile.burst_count:
		var angle := _rng.randf_range(-PI,PI)
		var speed := _rng.randf_range(profile.burst_speed.x,profile.burst_speed.y)
		_particles.append({"velocity":Vector3(cos(angle)*speed,_rng.randf_range(-0.2,0.85)*speed,sin(angle)*speed),"size":_rng.randf_range(profile.burst_size.x,profile.burst_size.y),"phase":_rng.randf_range(-PI,PI),"spin":_rng.randf_range(-TAU,TAU),"life":profile.burst_duration*_rng.randf_range(0.65,1.0)})
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for i: int in profile.burst_mist_count:
		var mat := profile.mist_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("particle_seed",_rng.randf_range(0.0,100.0))
		var node := _mesh("ImpactVapor%d"%i,quad,mat)
		var angle := _rng.randf_range(-PI,PI)
		_mists.append({"node":node,"material":mat,"direction":Vector3(cos(angle),_rng.randf_range(-0.2,0.2),sin(angle)),"size":_rng.randf_range(profile.burst_mist_size.x,profile.burst_mist_size.y),"life":profile.burst_duration*_rng.randf_range(0.8,1.0)})
	for i: int in 2:
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE * profile.impact_ring_radius * 2.0
		var mat := profile.ring_material.duplicate() as ShaderMaterial
		var node := _mesh("ImpactRing%d"%i,plane,mat)
		if i == 0:
			node.position.y = -profile.flight_height + 0.04
		else:
			node.rotation.x = PI * 0.5
			node.scale = Vector3.ONE * 0.7
		_rings.append({"node":node,"material":mat,"delay":float(i)*profile.impact_flash_duration*0.5})
	_flash_mat = profile.flash_material.duplicate() as ShaderMaterial
	_flash = _mesh("ContactStar",quad,_flash_mat)
	_flash.scale = Vector3.ONE*profile.impact_flash_size
	_light = OmniLight3D.new()
	_light.light_color = profile.light_color
	_light.omni_range = profile.light_range * 1.5
	_light.shadow_enabled = false
	add_child(_light)
	_ready_for_sampling = true
	seek_visual(0.0)

func _mesh(label: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func set_time_running(enabled: bool) -> void:
	_running = enabled

func _process(delta: float) -> void:
	if not _running: return
	seek_visual(_time+delta)
	if _time >= profile.burst_duration: queue_free()

func finish(_reason: String = "") -> void:
	_running = false
	hide()
	queue_free()

func seek_visual(time: float) -> void:
	if not _ready_for_sampling: return
	_time = maxf(time,0.0)
	for i: int in _particles.size():
		var entry: Dictionary = _particles[i]
		var p: float = clampf(_time / float(entry.life),0.0,1.0)
		var size: float = float(entry.size) * profile.fade_curve.sample_baked(p)
		var point: Vector3 = entry.velocity * _time + Vector3.DOWN * profile.burst_gravity * _time * _time * 0.5
		var axis: Vector3 = Vector3(entry.velocity).normalized()
		var basis := Basis(Quaternion(axis,float(entry.phase)+_time*float(entry.spin))).scaled(Vector3.ONE*maxf(size,0.00001))
		_batch.multimesh.set_instance_transform(i,Transform3D(basis,point))
	for entry: Dictionary in _mists:
		var p: float = clampf(_time/float(entry.life),0.0,1.0)
		var node: MeshInstance3D = entry.node
		node.visible = p < 1.0
		node.position = entry.direction * profile.burst_mist_spread * sqrt(p)
		node.scale = Vector3.ONE * float(entry.size) * lerpf(0.2,1.7,sqrt(p))
		var mat: ShaderMaterial = entry.material
		mat.set_shader_parameter("progress",p)
	for entry: Dictionary in _rings:
		var p: float = clampf((_time-float(entry.delay))/profile.burst_duration,0.0,1.0)
		var node: MeshInstance3D = entry.node
		node.visible = _time >= float(entry.delay) and p < 1.0
		var mat: ShaderMaterial = entry.material
		mat.set_shader_parameter("progress",1.0-pow(1.0-p,3.0))
	var flash_p: float = clampf(_time/profile.impact_flash_duration,0.0,1.0)
	_flash.visible = flash_p < 1.0
	_flash_mat.set_shader_parameter("progress",flash_p)
	_light.light_energy = profile.light_energy * 3.0 * pow(1.0-flash_p,2.0)
