extends Node3D
## Actual travel is sampled from combat; a time-bounded history supplies the wake.
const EPSILON := 0.000001
var profile
var actor_style
var body: Node3D
var flare: MeshInstance3D
var light: OmniLight3D
var layers: Array[Dictionary] = []
var history: Array[Dictionary] = []
var motes: MultiMesh
var mote_data: Array[Vector3] = []
var clock := 0.0
var width_ratio := 1.0
var tip_ratio := 1.0
var owner_handle := 0
var facing := Vector3.FORWARD

func configure(value, style, owner: int, seed: int, lit: bool) -> void:
	profile = value
	actor_style = style
	owner_handle = owner
	body = Node3D.new()
	add_child(body)
	var asset: Node3D = profile.arrow_scene.instantiate()
	asset.scale = Vector3.ONE * (style.arrow_width * profile.arrow_head_width_ratio)
	asset.scale.z = style.arrow_length
	body.add_child(asset)
	for node in asset.find_children("*", "MeshInstance3D", true, false):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flare = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * profile.tip_size_m
	flare.mesh = quad
	flare.material_override = profile.tip_material
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flare.position = Vector3.FORWARD * style.arrow_length / 2.0
	body.add_child(flare)
	if lit:
		light = OmniLight3D.new()
		light.light_color = profile.arrow_light_color
		light.light_energy = profile.arrow_light_energy
		light.omni_range = profile.arrow_light_radius_m
		light.shadow_enabled = false
		body.add_child(light)
	for source in [profile.halo_material, profile.trail_material, profile.filament_material, profile.filament_material]:
		var node := MeshInstance3D.new()
		var mesh := ImmediateMesh.new()
		var mat: ShaderMaterial = source.duplicate()
		node.mesh = mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		layers.append({"node":node, "mesh":mesh, "material":mat})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var mote_quad := QuadMesh.new()
	mote_quad.size = Vector2.ONE
	motes = MultiMesh.new()
	motes.transform_format = MultiMesh.TRANSFORM_3D
	motes.use_colors = true
	motes.instance_count = profile.trail_spark_count
	motes.mesh = mote_quad
	var mote_view := MultiMeshInstance3D.new()
	mote_view.multimesh = motes
	mote_view.material_override = profile.trail_spark_material
	mote_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mote_view)
	for i in motes.instance_count:
		mote_data.append(Vector3(rng.randf(), rng.randf_range(-1.0, 1.0), rng.randf_range(profile.trail_spark_size.x, profile.trail_spark_size.y)))
		motes.set_instance_color(i, Color(1, 1, 1, 0))

func sample(point: Vector3, direction: Vector3, delta: float) -> void:
	clock += delta
	facing = direction
	body.show()
	body.global_position = point
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 1.0 - EPSILON else Vector3.UP
	body.global_basis = Basis.looking_at(direction, up)
	flare.scale = Vector3.ONE * tip_ratio
	if history.is_empty() or history[0].point.distance_squared_to(point) > EPSILON:
		history.push_front({"point":point, "time":clock})
	_draw()

func finish(point: Vector3, direction: Vector3) -> void:
	sample(point, direction, 0.0)
	body.hide()

func fade(delta: float) -> bool:
	clock += delta
	_draw()
	return history.is_empty()

func reset() -> void:
	history.clear()
	body.hide()
	for layer in layers: layer.mesh.clear_surfaces()
	for i in motes.instance_count: motes.set_instance_color(i, Color(1, 1, 1, 0))

func _side(tangent: Vector3) -> Vector3:
	var side := tangent.cross(Vector3.UP)
	if side.length_squared() <= EPSILON:
		var camera := get_viewport().get_camera_3d()
		return camera.global_basis.x if camera != null else Vector3.RIGHT
	return side.normalized()

func _draw() -> void:
	while not history.is_empty() and clock - float(history.back().time) > profile.trail_lifetime_sec:
		history.pop_back()
	for layer in layers:
		layer.mesh.clear_surfaces()
		layer.material.set_shader_parameter("visual_time", clock)
	if history.size() < 2:
		for i in motes.instance_count: motes.set_instance_color(i, Color(1, 1, 1, 0))
		return
	for index in layers.size():
		var entry: Dictionary = layers[index]
		var mesh: ImmediateMesh = entry.mesh
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, entry.material)
		for i in history.size() - 1:
			var tangent: Vector3 = history[i].point - history[i + 1].point
			var side := _side(tangent)
			var corners: Array[Dictionary] = []
			for j in [i, i + 1]:
				var age: float = clampf((clock - float(history[j].time)) / profile.trail_lifetime_sec, 0.0, 1.0)
				var alpha := 1.0 - age
				var point: Vector3 = to_local(history[j].point)
				var width: float = profile.trail_width_m * width_ratio
				if index == 0: width *= profile.halo_width_ratio
				elif index >= 2:
					var phase: float = age * profile.filament_frequency - clock * profile.filament_flow + PI * float(index - 2)
					point += (side * sin(phase) + Vector3.UP * cos(phase)) * profile.filament_amplitude_m * sin(age * PI)
					width = profile.filament_width_m * width_ratio
				var half: Vector3 = side * width * (1.0 - age) / 2.0
				corners.append({"a":point-half,"b":point+half,"uv":age,"alpha":alpha})
			for spec in [[0,"a",0.0],[0,"b",1.0],[1,"b",1.0],[0,"a",0.0],[1,"b",1.0],[1,"a",0.0]]:
				var corner: Dictionary = corners[spec[0]]
				mesh.surface_set_color(Color(1,1,1,corner.alpha))
				mesh.surface_set_uv(Vector2(corner.uv,spec[2]))
				mesh.surface_add_vertex(corner[spec[1]])
		mesh.surface_end()
	for i in motes.instance_count:
		var data: Vector3 = mote_data[i]
		var f := data.x * float(history.size() - 1)
		var a := mini(int(floor(f)), history.size() - 2)
		var point: Vector3 = history[a].point.lerp(history[a+1].point, f - a)
		var age: float = lerpf(clock-history[a].time,clock-history[a+1].time,f-a) / profile.trail_lifetime_sec
		var side := _side(history[a].point-history[a+1].point)
		point += side * data.y * profile.filament_amplitude_m + Vector3.UP * sin(clock * profile.filament_flow + float(i)) * profile.filament_amplitude_m
		motes.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*data.z), to_local(point)))
		motes.set_instance_color(i, Color(1,1,1,pow(maxf(0.0,1.0-age),2.0)))
