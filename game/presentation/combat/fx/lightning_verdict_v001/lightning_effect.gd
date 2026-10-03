extends Node3D
## Deterministic presentation sampler. All layers use the same pauseable local clock.
const Profile = preload("res://presentation/combat/fx/lightning_verdict_v001/lightning_profile.gd")
@export var profile: Profile
var _time := 0.0
var _running := true
var _speed := 1.0
var _initialized := false
var _rng := RandomNumberGenerator.new()
var _bolts: Array[Dictionary] = []
var _arcs: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _smoke: Array[Dictionary] = []
var _lights: Array[Dictionary] = []
var _spark_data: Array[Dictionary] = []
var _debris_data: Array[Dictionary] = []
var _sparks: MultiMeshInstance3D
var _debris: MultiMeshInstance3D
var _sigil: ShaderMaterial

func _ready() -> void:
	assert(profile != null and profile.duration_sec > 0.0 and profile.shape_count > 0 and profile.shape_rate > 0.0)
	assert(not profile.strike_offsets.is_empty() and profile.bolt_segments >= 8 and profile.ground_arc_segments > 0)
	assert(profile.strike_offsets.size() == profile.strike_delays.size())
	assert(profile.strike_offsets.size() == profile.strike_heights.size() and profile.strike_offsets.size() == profile.strike_widths.size())
	assert(profile.pulse_times.size() >= 2 and profile.pulse_times.size() == profile.pulse_weights.size() and profile.pulse_decay_sec > 0.0)
	_rng.seed = profile.visual_seed
	_build_ground()
	_build_strikes()
	_build_particles()
	_build_smoke()
	_initialized = true
	seek_visual(0.0)

func set_time_running(enabled: bool) -> void:
	_running = enabled

func set_playback_speed(speed: float) -> void:
	assert(is_finite(speed) and speed >= 0.0)
	_speed = speed

func restart() -> void:
	seek_visual(0.0)

func finish() -> void:
	_running = false
	hide()
	queue_free()

func _process(delta: float) -> void:
	if not _running or not _initialized: return
	seek_visual(_time+delta*_speed)
	if _time >= profile.duration_sec: queue_free()

func _pulse(age: float) -> float:
	if age < 0.0 or age >= profile.bolt_duration_sec: return 0.0
	var power := 0.0
	for i: int in profile.pulse_times.size():
		var since: float = age-profile.pulse_times[i]
		if since >= 0.0: power=maxf(power,profile.pulse_weights[i]*exp(-since/profile.pulse_decay_sec))
	return power

func seek_visual(time: float) -> void:
	if not _initialized: return
	_time=clampf(time,0.0,profile.duration_sec)
	_sigil.set_shader_parameter("visual_time",_time)
	for entry: Dictionary in _bolts:
		var age: float = _time-float(entry.delay)
		var pulse: float = _pulse(age)
		var variant: int = posmod(int(floor(maxf(age,0.0)*profile.shape_rate)),profile.shape_count)
		var node: MeshInstance3D = entry.node
		node.visible=pulse>0.008 and variant==int(entry.variant)
		if node.visible:
			var mat: ShaderMaterial = entry.material
			mat.set_shader_parameter("intensity",pulse)
			mat.set_shader_parameter("visual_time",_time)
	for entry: Dictionary in _arcs:
		var age: float = _time-float(entry.delay)
		var node: MeshInstance3D = entry.node
		var pulse: float = _pulse(age)
		var fade: float = 1.0-smoothstep(profile.arc_lifetime_sec*0.3,profile.arc_lifetime_sec,maxf(age,0.0))
		node.visible=age>=0.0 and age<profile.arc_lifetime_sec
		if node.visible:
			var mat: ShaderMaterial = entry.material
			mat.set_shader_parameter("intensity",fade*(0.12+pulse*0.6)*(0.7+sin(_time*35.0+float(entry.phase))*0.3))
			mat.set_shader_parameter("visual_time",_time)
	for entry: Dictionary in _rings:
		var age: float = _time-float(entry.delay)
		var node: MeshInstance3D = entry.node
		node.visible=age>=0.0 and age<profile.ring_lifetime_sec
		if node.visible:
			var mat: ShaderMaterial = entry.material
			var p: float = age/profile.ring_lifetime_sec
			mat.set_shader_parameter("progress",1.0-pow(1.0-p,2.6))
	for entry: Dictionary in _flashes:
		var age: float = _time-float(entry.delay)
		var node: MeshInstance3D = entry.node
		node.visible=age>=0.0 and age<profile.flash_lifetime_sec
		if node.visible:
			var mat: ShaderMaterial = entry.material
			mat.set_shader_parameter("progress",age/profile.flash_lifetime_sec)
	_sample_batch(_sparks,_spark_data,profile.spark_gravity,false)
	_sample_batch(_debris,_debris_data,profile.debris_gravity,true)
	for entry: Dictionary in _smoke:
		var age: float = _time-float(entry.delay)
		var life: float = entry.life
		var node: MeshInstance3D = entry.node
		node.visible=age>=0.0 and age<life
		if node.visible:
			var p: float = age/life
			node.position=entry.origin+entry.drift*sqrt(p)+Vector3.UP*profile.smoke_rise*p
			node.scale=Vector3.ONE*float(entry.size)*lerpf(0.3,1.6,sqrt(p))
			var mat: ShaderMaterial = entry.material
			mat.set_shader_parameter("progress",p)
	for entry: Dictionary in _lights:
		var pulse: float = _pulse(_time-float(entry.delay))
		var light: OmniLight3D = entry.node
		light.visible=pulse>0.008
		light.light_energy=profile.light_energy*pulse

func _mesh(label: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name=label
	node.mesh=mesh
	node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size=Vector2.ONE*profile.ground_radius*2.0
	_sigil=profile.sigil_material.duplicate() as ShaderMaterial
	_sigil.set_shader_parameter("charge_sec",profile.charge_sec)
	_sigil.set_shader_parameter("duration_sec",profile.duration_sec)
	var sigil := _mesh("ChargingGroundSeal",plane,_sigil)
	sigil.position=profile.target+Vector3.UP*profile.ground_height
	for arc: int in profile.ground_arc_count:
		var angle: float = TAU*float(arc)/float(profile.ground_arc_count)
		var points := PackedVector3Array()
		var radius: float = profile.ground_radius*_rng.randf_range(0.7,1.0)
		for step: int in profile.ground_arc_segments+1:
			var f: float = float(step)/float(profile.ground_arc_segments)
			var a: float = angle+_rng.randf_range(-0.08,0.08)
			points.append(profile.target+Vector3(cos(a)*radius*f,profile.ground_height*2.0,sin(a)*radius*f))
		var material := profile.corona_material.duplicate() as ShaderMaterial
		var node := _mesh("GroundDischarge%d"%arc,_paths_mesh([points],[profile.bolt_width*0.65]),material)
		_arcs.append({"node":node,"material":material,"delay":profile.charge_sec,"phase":_rng.randf_range(-PI,PI)})

func _build_strikes() -> void:
	for strike: int in profile.strike_offsets.size():
		var origin: Vector3 = profile.target+profile.strike_offsets[strike]
		var delay: float = profile.strike_delays[strike]
		for variant: int in profile.shape_count:
			var paths: Array[PackedVector3Array] = []
			var widths: Array[float] = []
			var stem := PackedVector3Array()
			var height: float = profile.strike_heights[strike]
			for segment: int in profile.bolt_segments+1:
				var f: float = float(segment)/float(profile.bolt_segments)
				var jitter: float = sin(f*PI)*profile.bolt_jitter
				stem.append(origin+Vector3(_rng.randf_range(-jitter,jitter),height*(1.0-f),_rng.randf_range(-jitter,jitter)))
			paths.append(stem)
			widths.append(profile.bolt_width*profile.strike_widths[strike])
			for branch: int in profile.branch_count:
				var start_index := _rng.randi_range(3,profile.bolt_segments-5)
				var start: Vector3 = stem[start_index]
				var angle: float = _rng.randf_range(-PI,PI)
				var span := _rng.randf_range(profile.branch_span.x,profile.branch_span.y)
				var end := start+Vector3(cos(angle)*span,-_rng.randf_range(profile.branch_drop.x,profile.branch_drop.y),sin(angle)*span)
				end.y=maxf(profile.ground_height,end.y)
				var fork := PackedVector3Array()
				for step: int in 9:
					var f: float = float(step)/8.0
					var jitter: float = sin(f*PI)*profile.bolt_jitter*0.65
					fork.append(start.lerp(end,f)+Vector3(_rng.randf_range(-jitter,jitter),_rng.randf_range(-jitter,jitter),_rng.randf_range(-jitter,jitter)))
				paths.append(fork)
				widths.append(profile.bolt_width*profile.branch_width_ratio*profile.strike_widths[strike])
			for layer: int in 2:
				var mat := (profile.core_material if layer==0 else profile.corona_material).duplicate() as ShaderMaterial
				var layer_widths: Array[float] = []
				for width: float in widths: layer_widths.append(width*(1.0 if layer==0 else profile.corona_width_ratio))
				var node := _mesh("Bolt_%d_%d_%d"%[strike,variant,layer],_paths_mesh(paths,layer_widths),mat)
				_bolts.append({"node":node,"material":mat,"delay":delay,"variant":variant})
		var light := OmniLight3D.new()
		light.position=origin+Vector3.UP*0.65
		light.light_color=profile.light_color
		light.omni_range=profile.light_radius
		light.shadow_enabled=false
		add_child(light)
		_lights.append({"node":light,"delay":delay})
		for wave: int in 2:
			var plane := PlaneMesh.new()
			plane.size=Vector2.ONE*profile.ring_radius*2.0*(1.0 if strike==0 else 0.65)
			var material := profile.ring_material.duplicate() as ShaderMaterial
			var ring := _mesh("ShockRing_%d_%d"%[strike,wave],plane,material)
			ring.position=origin+Vector3.UP*profile.ground_height*float(3+wave)
			_rings.append({"node":ring,"material":material,"delay":delay+float(wave)*profile.pulse_times[1]})
		var quad := QuadMesh.new()
		quad.size=Vector2.ONE*profile.flash_size
		var flash_mat := profile.flash_material.duplicate() as ShaderMaterial
		var flash := _mesh("GroundContactFlash%d"%strike,quad,flash_mat)
		flash.position=origin+Vector3.UP*0.18
		_flashes.append({"node":flash,"material":flash_mat,"delay":delay})

func _paths_mesh(paths: Array, widths: Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for path_index: int in paths.size():
		var points: PackedVector3Array = paths[path_index]
		var width: float = widths[path_index]
		for segment: int in points.size()-1:
			var tangent := (points[segment+1]-points[segment]).normalized()
			var side := tangent.cross(Vector3.FORWARD).normalized()
			if side.length_squared()<0.001: side=tangent.cross(Vector3.UP).normalized()
			# Crossed ribbons keep the filament legible from the game camera.
			for plane: int in 3:
				var across := side.rotated(tangent,PI*float(plane)/3.0)*width*0.5
				for corner: Vector2 in [Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(1,0)]:
					var index: int = segment+int(corner.x)
					var f: float = float(index)/float(points.size()-1)
					var taper: float = 1.0 if path_index==0 else lerpf(1.0,0.12,f)
					surface.set_uv(Vector2(f,corner.y))
					surface.add_vertex(points[index]+across*(corner.y*2.0-1.0)*taper)
	surface.generate_normals()
	return surface.commit()

func _batch(label: String, mesh: Mesh, material: Material, count: int) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.mesh=mesh
	multi.instance_count=count
	var node := MultiMeshInstance3D.new()
	node.name=label
	node.multimesh=multi
	node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb=AABB(Vector3(-12,-8,-18),Vector3(24,24,30))
	add_child(node)
	return node

func _particle_data(index: int, sizes: Vector2, speeds: Vector2, lives: Vector2) -> Dictionary:
	var strike: int = index%profile.strike_offsets.size()
	var angle := _rng.randf_range(-PI,PI)
	var speed := _rng.randf_range(speeds.x,speeds.y)
	var origin: Vector3 = profile.target+profile.strike_offsets[strike]+Vector3.UP*profile.ground_height
	return {"origin":origin,"velocity":Vector3(cos(angle)*speed,_rng.randf_range(0.6,1.4)*speed,sin(angle)*speed),"delay":profile.strike_delays[strike],"life":_rng.randf_range(lives.x,lives.y),"size":_rng.randf_range(sizes.x,sizes.y),"spin":_rng.randf_range(-TAU,TAU),"phase":_rng.randf_range(-PI,PI)}

func _build_particles() -> void:
	var spark_mesh := PrismMesh.new()
	spark_mesh.size=Vector3(0.13,1.0,0.13)
	_sparks=_batch("ElectricSparks",spark_mesh,profile.spark_material,profile.spark_count)
	_debris=_batch("DislodgedStone",profile.debris_mesh,profile.debris_material,profile.debris_count)
	for i: int in profile.spark_count: _spark_data.append(_particle_data(i,profile.spark_size,profile.spark_speed,profile.spark_lifetime))
	for i: int in profile.debris_count: _debris_data.append(_particle_data(i,profile.debris_size,profile.debris_speed,profile.debris_lifetime))

func _sample_batch(batch: MultiMeshInstance3D, entries: Array[Dictionary], gravity: float, bounce: bool) -> void:
	for i: int in entries.size():
		var entry: Dictionary = entries[i]
		var age: float = _time-float(entry.delay)
		var life: float = entry.life
		if age<0.0 or age>=life:
			batch.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.00001),Vector3.DOWN*100.0))
			continue
		var start: Vector3 = entry.origin
		var velocity: Vector3 = entry.velocity
		var offset := velocity*age+Vector3.DOWN*gravity*age*age*0.5
		if bounce:
			var hit: float = (velocity.y+sqrt(velocity.y*velocity.y+2.0*gravity*start.y))/gravity
			if age>hit:
				var after: float = age-hit
				offset.y=maxf(0.0,(gravity*hit-velocity.y)*profile.debris_bounce*after-gravity*after*after*0.5)-start.y
				offset.x=velocity.x*(hit+after*profile.debris_drag)
				offset.z=velocity.z*(hit+after*profile.debris_drag)
		var basis: Basis
		if bounce:
			basis=Basis(Vector3.UP,float(entry.phase)+float(entry.spin)*age)
		else:
			var direction := (velocity-Vector3.UP*gravity*age).normalized()
			basis=Basis(Quaternion(Vector3.UP,direction))
		var size: float = float(entry.size)*profile.fade_curve.sample_baked(age/life)
		basis=basis.scaled(Vector3.ONE*maxf(size,0.00001))
		batch.multimesh.set_instance_transform(i,Transform3D(basis,start+offset))

func _build_smoke() -> void:
	var quad := QuadMesh.new()
	quad.size=Vector2.ONE
	for i: int in profile.smoke_count:
		var strike: int = i%profile.strike_offsets.size()
		var mat := profile.smoke_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("particle_seed",_rng.randf_range(0.0,100.0))
		var node := _mesh("OzoneVapor%d"%i,quad,mat)
		var angle := _rng.randf_range(-PI,PI)
		_smoke.append({"node":node,"material":mat,"origin":profile.target+profile.strike_offsets[strike]+Vector3.UP*profile.ground_height,"drift":Vector3(cos(angle),0,sin(angle))*profile.smoke_spread,"delay":profile.strike_delays[strike],"life":_rng.randf_range(profile.smoke_lifetime.x,profile.smoke_lifetime.y),"size":_rng.randf_range(profile.smoke_size.x,profile.smoke_size.y)})
