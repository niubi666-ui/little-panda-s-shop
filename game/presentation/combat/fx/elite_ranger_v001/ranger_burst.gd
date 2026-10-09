extends Node3D
## Pooled draw calls per wave: physical chips, soft dust, sparks, impact stars/ripples.
var profile
var owner_handle := 0
var age := 0.0
var flashes: MultiMesh
var rings: MultiMesh
var flash_material: ShaderMaterial
var ring_material: ShaderMaterial
var clouds: Array[Dictionary] = []
var light: OmniLight3D
var boundary := 0.0

func _instances(mesh: Mesh, count: int, material: Material) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return mm

func configure(value, points: PackedVector3Array, center: Vector3, direction: Vector3, owner: int, seed: int, radius: float) -> void:
	profile = value
	owner_handle = owner
	boundary = radius
	global_position = center
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	flash_material = profile.flash_material.duplicate()
	ring_material = profile.ring_material.duplicate()
	ring_material.set_shader_parameter("area_center",Vector2(center.x,center.z))
	ring_material.set_shader_parameter("area_radius",radius)
	flashes = _instances(quad, points.size(), flash_material)
	rings = _instances(quad, points.size(), ring_material)
	for i in points.size():
		var point: Vector3 = to_local(points[i])
		point.y += profile.flash_lift_m
		flashes.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*profile.flash_size_m),point))
		flashes.set_instance_color(i,Color.WHITE)
		var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.999999 else Vector3.UP
		var basis := Basis(Vector3.RIGHT,PI/2.0) if profile.ring_ground else Basis.looking_at(direction,up)
		if profile.ring_ground: point.y = profile.ground_height_m
		rings.set_instance_transform(i,Transform3D(basis.scaled(Vector3.ONE*profile.ring_radius_m*2.0),point))
		rings.set_instance_color(i,Color.WHITE)
	for kind in ["spark","debris","dust"]:
		var mesh: Mesh = profile.debris_mesh if kind == "debris" else quad
		var material: Material = profile.get(kind + "_material")
		var count: int = profile.get(kind + "_count_per_point")
		var mm := _instances(mesh,count*points.size(),material)
		var items: Array[Dictionary] = []
		var size: Vector2 = profile.get(kind + "_size")
		var life: Vector2 = profile.get(kind + "_life")
		for i in mm.instance_count:
			var up := rng.randf()
			var angle := rng.randf() * TAU
			var flat := sqrt(1.0-up*up)
			var velocity := Vector3(cos(angle)*flat,up,sin(angle)*flat)
			if kind == "dust": velocity = Vector3.UP*profile.dust_rise_mps
			else:
				var speed: Vector2 = profile.get(kind + "_speed")
				velocity *= rng.randf_range(speed.x,speed.y)
			items.append({"point":to_local(points[i/count]),"velocity":velocity,"size":rng.randf_range(size.x,size.y),"life":rng.randf_range(life.x,life.y),"rotation":Basis.from_euler(Vector3(rng.randf()*TAU,rng.randf()*TAU,rng.randf()*TAU))})
		clouds.append({"kind":kind,"mesh":mm,"items":items})
	light = OmniLight3D.new()
	light.light_color = profile.light_color
	light.light_energy = profile.light_energy
	light.omni_range = profile.light_radius_m
	light.position = Vector3.UP * profile.light_radius_m / 3.0
	light.shadow_enabled = false
	add_child(light)
	step(0.0)

func step(delta: float) -> bool:
	age += delta
	flash_material.set_shader_parameter("progress",clampf(age/profile.flash_sec,0.0,1.0))
	ring_material.set_shader_parameter("progress",clampf(age/profile.ring_sec,0.0,1.0))
	light.light_energy = profile.light_energy * pow(maxf(0.0,1.0-age/profile.light_sec),2.0)
	for cloud in clouds:
		var mm: MultiMesh = cloud.mesh
		for i in cloud.items.size():
			var item: Dictionary = cloud.items[i]
			var t := clampf(age/float(item.life),0.0,1.0)
			var gravity: float = 0.0 if cloud.kind == "dust" else profile.get(cloud.kind + "_gravity")
			var point: Vector3 = item.point + item.velocity*age - Vector3.UP*gravity*age*age/2.0
			point.y = maxf(point.y,profile.ground_height_m-global_position.y)
			if boundary > 0.0:
				var flat := Vector2(point.x,point.z).limit_length(boundary)
				point.x=flat.x; point.z=flat.y
			var scale: float = item.size * (1.0+t if cloud.kind=="dust" else 1.0)
			var basis: Basis = item.rotation if cloud.kind=="debris" else Basis.IDENTITY
			mm.set_instance_transform(i,Transform3D(basis.scaled(Vector3.ONE*scale),point))
			var alpha := sin(t*PI) if cloud.kind=="dust" else pow(1.0-t,2.0)
			mm.set_instance_color(i,Color(1,1,1,alpha))
	return age >= profile.duration_sec
