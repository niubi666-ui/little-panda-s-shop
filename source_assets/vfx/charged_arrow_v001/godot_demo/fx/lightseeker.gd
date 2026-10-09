extends Node3D
## Passive visual study. Reads rule state and committed facts; never inflicts damage.
var art: Resource
var rules
var camera: Camera3D
var charge_root: Node3D
var charge_ring: MeshInstance3D
var charge_arrow: Node3D
var flight_arrow: Node3D
var charge_flare: MeshInstance3D
var flight_flare: MeshInstance3D
var impact_flare: MeshInstance3D
var impact_ring: MeshInstance3D
var impact_time := -1.0
var impact_point := Vector3.ZERO
var ground: MeshInstance3D
var ground_material: ShaderMaterial
var warning: MeshInstance3D
var charge_lines: Array[MeshInstance3D] = []
var flight_lines: Array[MeshInstance3D] = []
var launch_rings: Array[MeshInstance3D] = []
var gather: MultiMesh
var embers: MultiMesh
var seed_points: Array[Vector3] = []
var light: OmniLight3D
var ground_lights: Array[OmniLight3D] = []
var voices: Dictionary = {}
var was_fired := false
var pulse_seen := 0
var enabled := true
var rift
const Rift = preload("res://fx/rift.gd")

func configure(profile: Resource, model, view_camera: Camera3D, floor_adapter: Node3D) -> void:
	art = profile
	art.validate()
	rules = model
	camera = view_camera
	rift=Rift.new()
	add_child(rift)
	rift.configure(art,rules,floor_adapter)
	charge_root = Node3D.new()
	add_child(charge_root)
	charge_arrow = _arrow(charge_root)
	flight_arrow = _arrow(self)
	charge_ring = _quad(art.sigil, charge_root)
	charge_flare = _quad(art.flare, self)
	flight_flare = _quad(art.flare, self)
	impact_flare = _quad(art.flare, self)
	impact_ring = _quad(art.sigil, self)
	for i in art.charge_orbits: charge_lines.append(_mesh(art.ribbon))
	flight_lines.append(_mesh(art.flight_halo))
	flight_lines.append(_mesh(art.flight_core))
	for i in 2: flight_lines.append(_mesh(art.ribbon))
	for i in art.launch_ring_count: launch_rings.append(_quad(art.sigil, self))
	ground_material = art.ground.duplicate()
	ground = _mesh(ground_material)
	warning = _mesh(art.warning_material)
	gather = _particles(art.charge_particle_count)
	embers = _particles(art.trail_particle_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = art.visual_seed
	for i in maxi(art.charge_particle_count, art.trail_particle_count):
		seed_points.append(Vector3(rng.randf(), rng.randf(), rng.randf()))
	light = OmniLight3D.new()
	light.light_color = art.light_color
	light.omni_range = art.light_range_m
	add_child(light)
	for i in art.launch_ring_count:
		var lamp := OmniLight3D.new()
		lamp.light_color = art.light_color
		lamp.omni_range = art.light_range_m
		add_child(lamp)
		ground_lights.append(lamp)
	for id in ["charge", "fire", "pulse"]:
		var audio := AudioStreamPlayer.new()
		audio.stream = art.get(id + "_sound")
		audio.volume_db = art.audio_volume_db
		add_child(audio)
		voices[id] = audio
	rules.released.connect(_released)
	rules.damaged.connect(_damaged)
	reset()

func _arrow(parent: Node3D) -> Node3D:
	var item: Node3D = art.arrow_scene.instantiate()
	parent.add_child(item)
	item.scale = Vector3(art.arrow_width_m, art.arrow_width_m, art.arrow_length_m)
	for node in item.find_children("*", "MeshInstance3D", true, false):
		node.material_override = art.body
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return item

func _mesh(material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.material_override = material.duplicate()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _quad(material: Material, parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	node.mesh = mesh
	node.material_override = material.duplicate()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _particles(count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	mm.mesh = mesh
	mm.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = art.mote
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return mm

func reset() -> void:
	was_fired = false
	pulse_seen = 0
	impact_time = -1.0
	rift.reset()
	for voice in voices.values(): voice.stop()
	if enabled: voices.charge.play()
	refresh()

func _released() -> void:
	voices.charge.stop()
	if enabled: voices.fire.play()

func _damaged(kind: String, _amount: float, _timestamp: float) -> void:
	if kind == "scar" and enabled: voices.pulse.play()
	impact_time = _timestamp
	impact_point = rules.target

func pause_audio(value: bool) -> void:
	for voice in voices.values(): voice.stream_paused = value

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	if not value:
		rift.reset()
		for voice in voices.values(): voice.stop()

func _ribbon(node: MeshInstance3D, points: PackedVector3Array, width: float, alpha: float, tail: bool = false) -> void:
	if alpha <= 0.0:
		node.visible = false
		return
	node.visible = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var right: Array[Vector3] = []
	for i in points.size():
		var tangent: Vector3 = points[mini(i+1, points.size()-1)] - points[maxi(i-1, 0)]
		var side := tangent.cross(camera.global_position - points[i]).normalized()
		right.append(side)
	for i in points.size()-1:
		for corner in [Vector2i(i,0), Vector2i(i+1,0), Vector2i(i+1,1), Vector2i(i,0), Vector2i(i+1,1), Vector2i(i,1)]:
			var t := float(corner.x) / (points.size()-1)
			var taper := sin(t*PI) if tail else 1.0
			st.set_uv(Vector2(t, corner.y))
			st.set_color(Color(1,1,1,alpha*taper))
			st.add_vertex(points[corner.x] + right[corner.x] * width * (float(corner.y)-0.5))
	node.mesh = st.commit()
	node.material_override.set_shader_parameter("time_value", rules.clock)

func _ground_mesh() -> void:
	var origin: Vector3 = rules.origin
	origin.y = art.trail_height_m
	var side: Vector3 = rules.direction.cross(Vector3.UP)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for uv in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
		st.set_uv(uv)
		st.set_normal(Vector3.UP)
		st.add_vertex(origin + rules.direction * uv.x * rules.config.skill.range_m + side * (uv.y*2.0-1.0)*rules.config.skill.trail_half_width_m)
	ground.mesh = st.commit()
	ground_material = ground.material_override
	ground_material.set_shader_parameter("length_m", rules.config.skill.range_m)
	ground_material.set_shader_parameter("half_width", rules.config.skill.trail_half_width_m)
	ground_material.set_shader_parameter("tick_sec", rules.config.skill.trail_tick_sec)

func point_at(distance_m: float) -> Vector3:
	var point: Vector3 = rules.origin + rules.direction * distance_m
	point.y = lerpf(rules.origin.y, art.flight_height_m, minf(1.0,distance_m/art.launch_blend_m))
	return point

func refresh() -> void:
	if not enabled: return
	var p := clampf(rules.clock / rules.config.skill.charge_sec, 0.0, 1.0)
	var fired: bool = rules.fire_time >= 0.0
	var age: float = rules.clock - rules.fire_time if fired else 0.0
	var frame := Basis.looking_at(rules.direction, Vector3.UP)
	var side := frame.x
	var up := frame.y
	var impact_progress := clampf((rules.clock-impact_time)/art.impact_sec,0.0,1.0)
	impact_flare.visible=impact_time>=0.0 and impact_progress<1.0
	impact_flare.global_position=impact_point+Vector3.UP*art.flight_height_m
	impact_flare.scale=Vector3.ONE*art.impact_size_m
	impact_flare.material_override.set_shader_parameter("opacity",pow(1.0-impact_progress,2.0))
	impact_ring.visible=impact_flare.visible
	impact_ring.global_position=impact_point+Vector3.UP*art.trail_height_m
	impact_ring.basis=Basis(Vector3.RIGHT,PI/2.0).scaled(Vector3.ONE*art.impact_size_m*impact_progress)
	impact_ring.material_override.set_shader_parameter("opacity",pow(1.0-impact_progress,2.0))
	impact_ring.material_override.set_shader_parameter("time_value",rules.clock)
	var warning_points := PackedVector3Array()
	for i in 2:
		var point: Vector3 = rules.origin + rules.direction * rules.config.skill.range_m * i
		point.y = art.trail_height_m
		warning_points.append(point)
	_ribbon(warning,warning_points,rules.config.skill.arrow_radius_m*2.0,0.0 if fired else (p if rules.locked else p*art.draw_fraction))
	charge_root.global_position = rules.origin
	charge_root.basis = frame
	charge_root.visible = not fired
	charge_arrow.position = Vector3(0,0,-art.arrow_length_m/2.0)
	charge_arrow.visible = p >= art.draw_fraction
	charge_ring.scale = Vector3.ONE * art.charge_radius_m * 2.0 * p
	charge_ring.position.z = -art.charge_radius_m / 2.0
	charge_ring.material_override.set_shader_parameter("opacity", pow(p,2.0))
	charge_ring.material_override.set_shader_parameter("time_value", rules.clock)
	charge_flare.global_position = rules.origin
	charge_flare.scale = Vector3.ONE * art.flare_size_m * p
	charge_flare.visible = not fired or age < art.launch_sec
	var burst := pow(maxf(0.0,1.0-age/art.launch_sec),2.0)
	charge_flare.material_override.set_shader_parameter("opacity", burst if fired else pow(p,3.0))
	for line_index in charge_lines.size():
		var points := PackedVector3Array()
		for i in 64:
			var t := float(i) / 63.0
			var angle: float = t * TAU * art.charge_turns + rules.clock * art.charge_speed + TAU * line_index / charge_lines.size()
			var radius: float = art.charge_radius_m * (1.0-t) * p
			var point: Vector3 = rules.origin + (side*cos(angle)+up*sin(angle))*radius + rules.direction*(t*2.0-1.0)*art.charge_radius_m
			points.append(point)
		_ribbon(charge_lines[line_index], points, art.charge_width_m, 0.0 if fired else p, true)
	for i in gather.instance_count:
		var seed: Vector3 = seed_points[i]
		var t := fmod(seed.z + rules.clock * art.charge_speed / TAU,1.0)
		var a: float = seed.x * TAU + t*TAU*art.charge_turns
		var radius: float = art.charge_radius_m*(1.0-t)*p
		var point: Vector3 = rules.origin + (side*cos(a)+up*sin(a))*radius + rules.direction*(seed.y*2.0-1.0)*radius
		gather.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*art.charge_particle_size_m),point))
		gather.set_instance_color(i,Color(1,1,1,0.0 if fired else sin(t*PI)*p))
	if fired and not was_fired:
		was_fired = true
		_ground_mesh()
	var travel: float = rules.travelled()
	var flight_sec: float = rules.config.skill.range_m / rules.config.skill.speed_mps
	var afterglow: float = maxf(0.0,1.0-maxf(0.0,age-flight_sec)/art.flight_echo_sec)
	var flying := fired and age <= flight_sec
	flight_arrow.visible = flying
	flight_arrow.global_position = point_at(travel)
	flight_arrow.basis = frame.scaled(Vector3(art.arrow_width_m, art.arrow_width_m, art.arrow_length_m))
	flight_flare.visible = fired and afterglow > 0.0
	flight_flare.global_position = point_at(travel)
	flight_flare.scale = Vector3.ONE * art.flare_size_m
	flight_flare.material_override.set_shader_parameter("opacity", afterglow)
	for index in flight_lines.size():
		var points := PackedVector3Array()
		var length_m := minf(travel, art.flight_tail_m) if flying else travel
		for i in 48:
			var t := float(i)/47.0
			var at: float = travel-length_m+t*length_m
			var point: Vector3 = point_at(at)
			if index > 1:
				var a: float = at/art.flight_tail_m*art.flight_helix_turns*TAU+index*PI-rules.clock*art.charge_speed
				point += (side*cos(a)+up*sin(a))*art.flight_helix_radius_m*sin(t*PI)
			points.append(point)
		var width: float=art.charge_width_m
		if index==0: width=art.flight_width_m*art.flight_halo_ratio
		elif index==1: width=art.flight_width_m
		_ribbon(flight_lines[index],points,width,afterglow if fired else 0.0,true)
	for i in launch_rings.size():
		var ring: MeshInstance3D = launch_rings[i]
		var progress := clampf(age/art.launch_sec,0.0,1.0)
		ring.visible = fired and progress < 1.0
		ring.global_position = rules.origin+rules.direction*art.launch_ring_radius_m*progress*i
		ring.basis = frame.scaled(Vector3.ONE*art.launch_ring_radius_m*2.0*progress)
		ring.material_override.set_shader_parameter("opacity",pow(1.0-progress,2.0))
		ring.material_override.set_shader_parameter("time_value",rules.clock)
	var life: float = clampf(1.0-maxf(0.0,age-rules.config.skill.trail_duration_sec)/art.trail_fade_sec,0.0,1.0) if fired else 0.0
	rift.refresh(life,age)
	ground.visible = fired and life > 0.0
	ground.material_override.set_shader_parameter("life",life)
	ground.material_override.set_shader_parameter("travel",travel/rules.config.skill.range_m)
	ground.material_override.set_shader_parameter("time_value",age)
	var pulse: float = pow(1.0-fmod(age,rules.config.skill.trail_tick_sec)/rules.config.skill.trail_tick_sec,5.0)
	for i in embers.instance_count:
		var seed: Vector3 = seed_points[i]
		var t := fmod(seed.z + age/rules.config.skill.trail_tick_sec,1.0)
		var at: float = seed.x*rules.config.skill.range_m
		var shape: Vector2=rift.shape(at)
		var point: Vector3 = rules.origin+rules.direction*at+side*(shape.x+(seed.y*2.0-1.0)*shape.y)
		point.y = art.trail_height_m+pow(t,2.0)*art.trail_particle_height_m
		var size_m: float = art.trail_particle_size_m*(1.0+seed.y)
		embers.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size_m),point))
		embers.set_instance_color(i,Color(1,1,1,sin(t*PI)*life if fired and at<=travel else 0.0))
	light.global_position = rules.origin
	light.light_energy = art.shot_light_energy*burst if fired else art.charge_light_energy*pow(p,2.0)
	for i in ground_lights.size():
		var lamp: OmniLight3D = ground_lights[i]
		lamp.global_position = rules.origin + rules.direction * rules.config.skill.range_m * (float(i)+0.5)/ground_lights.size()
		lamp.global_position.y = art.rift_height_m.x/2.0
		lamp.light_energy = life * (1.0+pulse) * art.charge_light_energy / ground_lights.size()
