extends SceneTree
## 生成冰冻特效（freeze_fx.tscn）和测试场（freeze_lab.tscn）。冰晶、冰碴、寒雾、冰晶闪光沿用冰元素演示里的材质。
## Godot --headless --path game --script res://vfx_lab/freeze_lab/tools/build_freeze_lab.gd

const DIR := "res://vfx_lab/freeze_lab/"
const ICE := "res://vfx_lab/elemental_enchants/generated/"
const LAB := "res://vfx_lab/fire_katana/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR + "generated"))
	var shell := ShaderMaterial.new()
	shell.shader = load(DIR + "shaders/ice_shell.gdshader")
	shell.set_shader_parameter("cells_tex", _noise(0.04, true))
	shell.set_shader_parameter("noise_tex", _noise(0.02, false))
	shell.render_priority = 1
	shell = _save(shell, DIR + "generated/ice_shell.tres")

	# ---- 冰冻特效 ----
	var fx := Node3D.new()
	fx.name = "FreezeFx"
	fx.set_script(load(DIR + "scripts/freeze_encase.gd"))
	var puff := {"anim_speed_min": 0.0, "anim_speed_max": 0.0, "anim_offset_min": 0.0, "anim_offset_max": 1.0,
		"angle_min": 0.0, "angle_max": 360.0, "angular_velocity_min": -20.0, "angular_velocity_max": 20.0}
	var mist_ramp := _grad([[0.0, Color(0.85, 0.95, 1.0, 0.0)], [0.2, Color(0.8, 0.92, 1.0, 0.45)], [1.0, Color(0.7, 0.85, 1.0, 0.0)]])
	var o := puff.duplicate()
	o.merge({"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_BOX, "emission_box_extents": Vector3(0.4, 0.5, 0.4),
		"color_ramp": mist_ramp, "gravity": Vector3(0, -0.35, 0), "initial_velocity_min": 0.02, "initial_velocity_max": 0.08,
		"spread": 180.0, "damping_min": 0.4, "damping_max": 0.7, "lifetime_randomness": 0.4, "scale_min": 0.7, "scale_max": 1.3,
		"scale_curve": _curve([[0.0, 0.4], [0.3, 1.0], [1.0, 1.6]])})
	var mist := _particles("Mist", 26, 1.8, _quad(0.45), load(ICE + "ice_mist.tres"), o, {"one_shot": false, "explosiveness": 0.0})
	fx.add_child(mist)
	var glitter := _particles("Glitter", 18, 1.2, _quad(0.05), load(ICE + "ice_glint.tres"), {"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_BOX,
		"emission_box_extents": Vector3(0.4, 0.5, 0.4), "color_ramp": _grad([[0.0, Color(1, 1, 1, 0)], [0.3, Color(1, 1, 1, 1)], [1.0, Color(1, 1, 1, 0)]]),
		"initial_velocity_min": 0.0, "initial_velocity_max": 0.05, "spread": 180.0, "scale_min": 0.6, "scale_max": 1.4, "angle_min": 0.0, "angle_max": 360.0},
		{"one_shot": false, "explosiveness": 0.0})
	fx.add_child(glitter)
	var shards := _particles("Shards", 400, 1.5, load(ICE + "ice_shard_mesh.res"), load(ICE + "ice_shard.tres"), {"gravity": Vector3(0, -9.8, 0),
		"damping_min": 0.2, "damping_max": 0.4, "scale_min": 0.025, "scale_max": 0.06,
		"color_ramp": _grad([[0.0, Color(1, 1, 1, 1)], [0.75, Color(1, 1, 1, 1)], [1.0, Color(1, 1, 1, 0)]]),
		"collision_mode": ParticleProcessMaterial.COLLISION_RIGID, "collision_bounce": 0.3, "collision_friction": 0.4, "lifetime_randomness": 0.3},
		{"one_shot": false, "explosiveness": 0.0, "collision_base_size": 0.02})
	shards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	fx.add_child(shards)
	var o2 := puff.duplicate()
	o2.merge({"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_BOX, "emission_box_extents": Vector3(0.4, 0.5, 0.4), "color_ramp": mist_ramp,
		"initial_velocity_min": 0.3, "initial_velocity_max": 1.0, "spread": 180.0, "damping_min": 2.0, "damping_max": 3.0,
		"gravity": Vector3(0, -0.3, 0), "scale_curve": _curve([[0.0, 0.5], [1.0, 1.7]])})
	var burst := _particles("BurstMist", 20, 1.1, _quad(0.5), load(ICE + "ice_mist.tres"), o2, {"one_shot": true, "explosiveness": 0.9})
	fx.add_child(burst)
	var decal := Decal.new()
	decal.name = "FrostDecal"
	decal.size = Vector3(1.2, 1.0, 1.2)
	decal.texture_albedo = load(ICE + "frost_albedo.png")
	decal.texture_emission = load(ICE + "frost_emission.png")
	decal.emission_energy = 0.6
	fx.add_child(decal)
	for kv in [["shell_material", shell], ["crystal_mesh", load(ICE + "ice_spike_mesh.res")], ["crystal_material", load(ICE + "ice_shard.tres")],
			["mist", mist], ["glitter", glitter], ["shards", shards], ["burst_mist", burst], ["frost_decal", decal]]:
		fx.set(kv[0], kv[1])
	_pack(fx, DIR + "freeze_fx.tscn")

	# ---- 测试场 ----
	var root := Node3D.new()
	root.name = "FreezeLab"
	root.set_script(load(DIR + "scripts/freeze_lab_director.gd"))
	var looks: Array[Resource] = [load(LAB + "presets/look_night.tres"), load(LAB + "presets/look_day.tres")]
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = looks[1].environment
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	root.add_child(sun)
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.set_script(load(LAB + "scripts/demo_camera.gd"))
	cam.set("focus", Vector3(0, 0.75, 0))
	cam.set("presets", [Vector3(0.0, 14.0, 8.5), Vector3(-30.0, 52.0, 12.0), Vector3(-25.0, 8.0, 3.2)] as Array[Vector3])
	cam.set("preset_names", PackedStringArray(["全排", "游戏俯视角", "近景"]))
	cam.fov = 45.0
	cam.current = true
	root.add_child(cam)
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.material_override = load(LAB + "materials/ground.tres")
	root.add_child(ground)
	var floor_col := GPUParticlesCollisionBox3D.new()
	floor_col.name = "FloorCollision"
	floor_col.size = Vector3(40, 1, 40)
	floor_col.position = Vector3(0, -0.5, 0)
	root.add_child(floor_col)
	var ui := CanvasLayer.new()
	ui.name = "UI"
	root.add_child(ui)
	var label := Label.new()
	label.name = "Help"
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 5)
	ui.add_child(label)
	root.set("freeze_scene", load(DIR + "freeze_fx.tscn"))
	root.set("camera", cam)
	root.set("label", label)
	root.set("world_env", env)
	root.set("sun", sun)
	root.set("looks", looks)
	_pack(root, DIR + "freeze_lab.tscn")
	print("freeze lab built")
	quit()


func _noise(freq: float, cellular: bool) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	if cellular:
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	else:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	t.invert = cellular
	return t


func _particles(n: String, amount: int, lifetime: float, draw: Mesh, mat: Material, opts: Dictionary, node_opts: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = n
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.fixed_fps = 0
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.draw_pass_1 = draw
	p.material_override = mat
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3.ZERO
	for k in opts:
		pm.set(k, opts[k])
	p.process_material = pm
	for k in node_opts:
		p.set(k, node_opts[k])
	return p


func _quad(w: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(w, w)
	return q


func _grad(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(Vector2(p[0], p[1]))
	var t := CurveTexture.new()
	t.curve = c
	return t


func _pack(root: Node, path: String) -> void:
	_own(root, root)
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, path) == OK)


func _own(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_own(c, owner)


func _save(res: Resource, path: String) -> Resource:
	assert(ResourceSaver.save(res, path) == OK, "save failed " + path)
	return load(path)
