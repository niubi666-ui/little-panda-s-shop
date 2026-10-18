extends SceneTree
## 生成游戏用的冰冻状态场景 freeze_encase.tscn（参数沿用 vfx_lab/freeze_lab 里用户认可的那版）。
## 冰晶、冰碴、寒雾、冰晶闪光、霜花复用 elemental_enchants_v001 里已接入游戏的冰元素资源，本目录只多一个冰壳着色器。
## Godot --headless --path game --script res://presentation/combat/fx/freeze_encase_v001/build_freeze_encase.gd

const DIR := "res://presentation/combat/fx/freeze_encase_v001/"
const ICE := "res://presentation/combat/fx/elemental_enchants_v001/generated/"


func _init() -> void:
	var shell := ShaderMaterial.new()
	shell.shader = load(DIR + "ice_shell.gdshader")
	shell.set_shader_parameter("cells_tex", _noise(0.04, true))
	shell.set_shader_parameter("noise_tex", _noise(0.02, false))
	shell.render_priority = 1
	shell = _save(shell, DIR + "ice_shell.tres")

	var fx := Node3D.new()
	fx.name = "FreezeEncase"
	fx.set_script(load(DIR + "freeze_encase.gd"))
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
	for c in fx.get_children():
		c.owner = fx
	var packed := PackedScene.new()
	assert(packed.pack(fx) == OK)
	assert(ResourceSaver.save(packed, DIR + "freeze_encase.tscn") == OK)
	print("freeze encase built")
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


func _save(res: Resource, path: String) -> Resource:
	assert(ResourceSaver.save(res, path) == OK, "save failed " + path)
	return load(path)
