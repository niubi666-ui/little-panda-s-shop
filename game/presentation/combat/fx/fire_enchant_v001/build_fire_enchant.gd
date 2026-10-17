extends SceneTree
## 生成 fire_enchant.tscn（参数沿用 vfx_lab/fire_katana 里用户认可的那版）。生成后可以直接在编辑器里调场景。
## Godot --headless --path game --script res://presentation/combat/fx/fire_enchant_v001/build_fire_enchant.gd

const DIR := "res://presentation/combat/fx/fire_enchant_v001/"


func _init() -> void:
	var root := Node3D.new()
	root.name = "FireEnchant"
	root.set_script(load(DIR + "fire_enchant.gd"))
	var puff_mat := ShaderMaterial.new()
	puff_mat.shader = load(DIR + "enchant_puff.gdshader")
	puff_mat.set_shader_parameter("tex", load(DIR + "fire_puffs.png"))
	puff_mat.render_priority = 1
	var spark_mat := ShaderMaterial.new()
	spark_mat.shader = load(DIR + "enchant_spark.gdshader")
	spark_mat.set_shader_parameter("tex", load(DIR + "soft_dot.png"))
	spark_mat.render_priority = 2

	var flames := _particles("Flames", 340, 0.55, Vector2(0.17, 0.17), puff_mat, _puff_opts({"inherit_velocity_ratio": 0.05}))
	root.add_child(flames)
	# 拖尾火团一出生就接近全尺寸，挥砍前沿不会出现一排小点
	var arc := _particles("ArcFlames", 4000, 0.4, Vector2(0.22, 0.22), puff_mat, _puff_opts({"damping_min": 2.0, "damping_max": 3.0, "lifetime_randomness": 0.45,
		"scale_curve": _curve_tex([[0.0, 0.75], [0.25, 1.0], [1.0, 1.3]])}))
	root.add_child(arc)
	var embers := _particles("Embers", 80, 0.8, Vector2(0.012, 0.07), spark_mat, {
		"initial_velocity_min": 0.5, "initial_velocity_max": 1.5, "spread": 180.0, "inherit_velocity_ratio": 0.25,
		"gravity": Vector3(0, -2.0, 0), "damping_min": 1.5, "damping_max": 1.5, "lifetime_randomness": 0.4,
		"turbulence_enabled": true, "turbulence_noise_strength": 1.5, "turbulence_noise_scale": 3.0,
		"turbulence_influence_min": 0.1, "turbulence_influence_max": 0.2,
		"scale_curve": _curve_tex([[0.0, 1.0], [1.0, 0.0]]),
		"color_ramp": _grad_tex([[0.0, Color(1, 0.9, 0.6, 1)], [0.5, Color(1, 0.45, 0.1, 1)], [1.0, Color(0.7, 0.1, 0.0, 0)]])})
	embers.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	root.add_child(embers)
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color(1.0, 0.5, 0.2)
	light.omni_range = 2.2
	light.light_energy = 0.0
	light.shadow_enabled = false
	root.add_child(light)
	root.set("flames", flames)
	root.set("arc_flames", arc)
	root.set("embers", embers)
	root.set("light", light)
	for c in root.get_children():
		c.owner = root
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, DIR + "fire_enchant.tscn") == OK)
	print("fire enchant built")
	quit()


func _particles(n: String, amount: int, lifetime: float, quad: Vector2, mat: Material, opts: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = n
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = false
	p.explosiveness = 0.0
	p.local_coords = false
	p.fixed_fps = 0
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = quad
	p.draw_pass_1 = q
	p.material_override = mat
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3.ZERO
	for k in opts:
		pm.set(k, opts[k])
	p.process_material = pm
	return p


## 火团的寿命颜色：白黄 → 橙 → 红 → 黑烟 → 消失
func _fire_ramp() -> GradientTexture1D:
	return _grad_tex([[0.0, Color(1.0, 0.7, 0.3, 0.0)], [0.05, Color(1.0, 0.62, 0.2, 1.0)], [0.2, Color(1.0, 0.38, 0.04, 1.0)],
		[0.5, Color(0.8, 0.13, 0.01, 0.9)], [0.78, Color(0.14, 0.08, 0.06, 0.5)], [1.0, Color(0.06, 0.05, 0.05, 0.0)]])


func _puff_opts(extra: Dictionary) -> Dictionary:
	var o := {"color_ramp": _fire_ramp(), "anim_speed_min": 0.0, "anim_speed_max": 0.0, "anim_offset_min": 0.0, "anim_offset_max": 1.0,
		"angle_min": 0.0, "angle_max": 360.0, "angular_velocity_min": -90.0, "angular_velocity_max": 90.0,
		"gravity": Vector3(0, 2.8, 0), "lifetime_randomness": 0.35, "scale_min": 0.55, "scale_max": 1.2,
		"scale_curve": _curve_tex([[0.0, 0.35], [0.25, 0.9], [1.0, 1.35]])}
	o.merge(extra, true)
	return o


func _grad_tex(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _curve_tex(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(Vector2(p[0], p[1]))
	var t := CurveTexture.new()
	t.curve = c
	return t
