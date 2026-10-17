extends SceneTree
## 生成火焰太刀演示的材质、招式预设、火焰受击预制体和演示场景（都是可在编辑器里继续调的 .tres/.tscn）。
## 先跑 build_assets.gd 并 --import 一次，再跑：
## Godot --headless --path game --script res://vfx_lab/fire_katana/tools/build_scenes.gd

const ROOT := "res://vfx_lab/fire_katana/"
const TEX := ROOT + "generated/textures/"
const MAT := ROOT + "materials/"
const PRE := ROOT + "presets/"
const SCR := ROOT + "scripts/"
const SH := ROOT + "shaders/"

var _fire_noise: NoiseTexture2D


func _init() -> void:
	_fire_noise = _save(_noise_tex(0.018, 256), MAT + "noise_fire.tres")
	var mats := _build_materials()
	var timeline := _build_timeline()
	_build_impact(mats, timeline)
	var moves := _build_moves()
	var looks := _build_looks()
	_build_demo(mats, moves, looks)
	print("fire katana lab built")
	quit()


# ---------------- 小工具 ----------------

func _save(res: Resource, path: String) -> Resource:
	var err := ResourceSaver.save(res, path)
	assert(err == OK, "save failed " + path)
	return load(path)


func _noise_tex(freq: float, size: int, normal := false, bump := 4.0, ramp: Gradient = null) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = n
	t.as_normal_map = normal
	t.bump_strength = bump
	if ramp:
		t.color_ramp = ramp
	return t


func _grad(stops: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	return g


func _grad_tex(stops: Array) -> GradientTexture1D:
	var t := GradientTexture1D.new()
	t.gradient = _grad(stops)
	return t


func _curve_tex(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(Vector2(p[0], p[1]))
	var t := CurveTexture.new()
	t.curve = c
	return t


func _curve(points: Array) -> Curve:
	var c := Curve.new()
	for p in points:
		c.add_point(Vector2(p[0], p[1]))
	return c


func _shader_mat(shader: String, params: Dictionary, priority := 0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SH + shader)
	for k in params:
		m.set_shader_parameter(k, params[k])
	m.render_priority = priority
	return m


func _own(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_own(c, owner)


func _add(parent: Node, child: Node, n: String) -> Node:
	child.name = n
	parent.add_child(child)
	return child


## 火团的寿命颜色：白黄 → 橙 → 红 → 黑烟 → 消失
func _fire_ramp() -> GradientTexture1D:
	return _grad_tex([[0.0, Color(1.0, 0.7, 0.3, 0.0)], [0.05, Color(1.0, 0.62, 0.2, 1.0)], [0.2, Color(1.0, 0.38, 0.04, 1.0)],
		[0.5, Color(0.8, 0.13, 0.01, 0.9)], [0.78, Color(0.14, 0.08, 0.06, 0.5)], [1.0, Color(0.06, 0.05, 0.05, 0.0)]])


## 火团粒子的通用参数（随机图集格、随机角度和自转、向上飘、由小变大）
func _puff_opts(extra: Dictionary) -> Dictionary:
	var o := {"color_ramp": _fire_ramp(), "anim_speed_min": 0.0, "anim_speed_max": 0.0, "anim_offset_min": 0.0, "anim_offset_max": 1.0,
		"angle_min": 0.0, "angle_max": 360.0, "angular_velocity_min": -90.0, "angular_velocity_max": 90.0,
		"gravity": Vector3(0, 2.8, 0), "lifetime_randomness": 0.35, "scale_min": 0.55, "scale_max": 1.2,
		"scale_curve": _curve_tex([[0.0, 0.35], [0.25, 0.9], [1.0, 1.35]])}
	o.merge(extra, true)
	return o


## 三片竖直面片绕 Y 轴每 60° 交叉，底边在 y=0（火从表面往上长）。
func _cross_quads(w: float, h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var a := PI / 3.0 * i
		var r := Vector3(cos(a), 0.0, sin(a)) * w * 0.5
		var p := [-r, r, r + Vector3(0, h, 0), -r + Vector3(0, h, 0)]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[idx])
			st.add_vertex(p[idx])
	var mesh := st.commit()
	return mesh


## 一层粒子。opts 里的键直接设到 ParticleProcessMaterial 上。
func _particles(n: String, amount: int, lifetime: float, quad: Vector2, mat: Material, opts: Dictionary, node_opts := {}) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = n
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.fixed_fps = 0
	var q := QuadMesh.new()
	q.size = quad
	p.draw_pass_1 = q
	p.material_override = mat
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.0
	for k in opts:
		pm.set(k, opts[k])
	p.process_material = pm
	for k in node_opts:
		p.set(k, node_opts[k])
	return p


# ---------------- 材质 ----------------

func _build_materials() -> Dictionary:
	var m := {}
	var soft := load(TEX + "soft_dot.png")
	var flame_atlas := load(TEX + "flame_atlas.png")
	# 太刀
	m.blade = _save(_shader_mat("katana_blade.gdshader", {"detail_noise": _noise_tex(0.03, 256)}), MAT + "katana_blade.tres")
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.86, 0.63, 0.32)
	gold.metallic = 1.0
	gold.roughness = 0.28
	m.gold = _save(gold, MAT + "katana_gold.tres")
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.07, 0.065, 0.06)
	iron.metallic = 0.75
	iron.roughness = 0.48
	iron.normal_enabled = true
	iron.normal_texture = _noise_tex(0.05, 256, true, 3.0)
	iron.uv1_scale = Vector3(2, 2, 1)
	m.iron = _save(iron, MAT + "katana_iron.tres")
	m.tsuka = _save(_shader_mat("katana_tsuka.gdshader", {}), MAT + "katana_tsuka.tres")

	# 刀光拖尾三层：烟（最底）→ 火焰本体 → 白热外沿
	m.ribbon_smoke = _save(_shader_mat("fire_ribbon_mix.gdshader", {
		"life": 0.6, "fade_in": 0.06, "rise": 1.0, "noise_tex": _fire_noise, "noise_scale": Vector2(5.0, 2.0), "noise_drift": 0.8,
		"band_center": 0.68, "band_width": 0.36, "dissolve_softness": 0.35,
		"color_new": Color(0.08, 0.055, 0.045), "color_old": Color(0.035, 0.032, 0.03), "emission": 1.0, "opacity": 0.42}, -2), MAT + "ribbon_smoke.tres")
	m.ribbon_flame = _save(_shader_mat("fire_ribbon_mix.gdshader", {
		"life": 0.3, "rise": 0.45, "noise_tex": _fire_noise, "noise_scale": Vector2(9.0, 3.0), "noise_drift": 1.4,
		"band_center": 0.8, "band_width": 0.22, "dissolve_softness": 0.3,
		"color_new": Color(1.0, 0.5, 0.1), "color_old": Color(0.75, 0.1, 0.01), "emission": 1.3, "opacity": 0.5}, 0), MAT + "ribbon_flame.tres")
	m.ribbon_core = _save(_shader_mat("fire_ribbon_add.gdshader", {
		"life": 0.13, "rise": 0.05, "noise_tex": _fire_noise, "noise_scale": Vector2(4.0, 6.0), "noise_drift": 1.0,
		"band_center": 0.93, "band_width": 0.07, "dissolve_softness": 0.3,
		"color_new": Color(1.0, 0.8, 0.5), "color_old": Color(1.0, 0.4, 0.08), "emission": 2.6, "opacity": 1.0}, 1), MAT + "ribbon_core.tres")

	# 粒子材质
	var add := func(tex: Texture2D, tint: Color, emission: float, billboard: bool) -> ShaderMaterial:
		return _shader_mat("vfx_additive.gdshader", {"tex": tex, "tint": tint, "emission": emission, "billboard": billboard}, 2)
	m.fx_flash = _save(add.call(load(TEX + "flare_star.png"), Color(1.0, 0.78, 0.5), 3.0, true), MAT + "fx_flash.tres")
	m.fx_glow = _save(add.call(soft, Color(1.0, 0.45, 0.12), 0.5, true), MAT + "fx_glow.tres")
	m.fx_ring = _save(add.call(load(TEX + "ring.png"), Color(1.0, 0.5, 0.16), 1.5, true), MAT + "fx_ring.tres")
	m.fx_crescent = _save(add.call(load(TEX + "cut_crescent.png"), Color(1.0, 0.8, 0.55), 3.5, false), MAT + "fx_crescent.tres")
	m.fx_spark = _save(add.call(soft, Color(1.0, 0.72, 0.38), 5.0, false), MAT + "fx_spark.tres")
	m.fx_ember = _save(add.call(soft, Color(1.0, 0.6, 0.25), 5.0, false), MAT + "fx_ember.tres")
	m.fx_gather = _save(add.call(soft, Color(1.0, 0.55, 0.2), 4.0, true), MAT + "fx_gather.tres")
	var flame := func(hot: Color, cool: Color, emission: float, opacity: float, dissolve_start: float, softness: float) -> ShaderMaterial:
		return _shader_mat("vfx_flame.gdshader", {"shape_tex": flame_atlas, "noise_tex": _fire_noise, "atlas_h": 2, "atlas_v": 2,
			"hot_color": hot, "cool_color": cool, "emission": emission, "opacity": opacity, "dissolve_start": dissolve_start, "dissolve_softness": softness}, 1)
	m.fx_flame = _save(flame.call(Color(1.0, 0.62, 0.18), Color(0.85, 0.16, 0.02), 1.3, 0.9, 0.1, 0.3), MAT + "fx_flame.tres")
	m.fx_flame_hot = _save(flame.call(Color(1.0, 0.85, 0.5), Color(1.0, 0.38, 0.05), 1.8, 1.0, 0.0, 0.3), MAT + "fx_flame_hot.tres")
	m.fx_wisp = _save(flame.call(Color(1.0, 0.62, 0.18), Color(0.85, 0.16, 0.02), 1.3, 0.75, 0.0, 0.45), MAT + "fx_flame_wisp.tres")
	m.fx_wisp.set_shader_parameter("noise_scale", 1.3)
	ResourceSaver.save(m.fx_wisp, MAT + "fx_flame_wisp.tres")
	# 序列帧火焰（4x4，按寿命播一遍）：刀身火、刀弧火、受击火团、余火都用它，每团火都在舔动变形
	var flip := load(TEX + "flame_flipbook.png")
	var flame_anim := func(hot: Color, cool: Color, emission: float, opacity: float, billboard: bool) -> ShaderMaterial:
		return _shader_mat("vfx_flame.gdshader", {"shape_tex": flip, "noise_tex": _fire_noise, "atlas_h": 4, "atlas_v": 4,
			"hot_color": hot, "cool_color": cool, "emission": emission, "opacity": opacity, "dissolve_start": 0.45,
			"dissolve_softness": 0.35, "noise_scale": 0.9, "billboard": billboard}, 1)
	m.fx_flame_anim = _save(flame_anim.call(Color(1.0, 0.62, 0.18), Color(0.85, 0.16, 0.02), 1.35, 0.95, true), MAT + "fx_flame_anim.tres")
	m.fx_flame_anim_hot = _save(flame_anim.call(Color(1.0, 0.85, 0.5), Color(1.0, 0.38, 0.05), 1.8, 1.0, true), MAT + "fx_flame_anim_hot.tres")
	m.fx_afterburn = _save(flame_anim.call(Color(1.0, 0.66, 0.22), Color(0.85, 0.16, 0.02), 1.3, 0.95, false), MAT + "fx_afterburn.tres")
	# 火团（主力）：大量叠加 + 按寿命上色
	m.fx_puff = _save(_shader_mat("vfx_fire_puff.gdshader", {"tex": load(TEX + "fire_puffs.png"), "atlas_h": 4, "atlas_v": 4}, 1), MAT + "fx_fire_puff.tres")
	m.fx_puff_hot = _save(_shader_mat("vfx_fire_puff.gdshader", {"tex": load(TEX + "fire_puffs.png"), "atlas_h": 4, "atlas_v": 4,
		"emission_young": 1.8, "emission_old": 1.1}, 1), MAT + "fx_fire_puff_hot.tres")
	# 刀身附魔火层：挂在刀身材质的 next_pass 上
	var overlay := _shader_mat("katana_fire_overlay.gdshader", {"noise_tex": _fire_noise}, 1)

	m.blade.next_pass = overlay
	m.blade.set_shader_parameter("heat_emission", 2.2)
	ResourceSaver.save(m.blade, MAT + "katana_blade.tres")
	m.fx_smoke = _save(flame.call(Color(0.13, 0.1, 0.08), Color(0.045, 0.04, 0.035), 1.0, 0.6, 0.3, 0.4), MAT + "fx_smoke.tres")
	m.fx_smoke.render_priority = -1
	ResourceSaver.save(m.fx_smoke, MAT + "fx_smoke.tres")

	# 场景
	var ground := StandardMaterial3D.new()
	ground.albedo_texture = _noise_tex(0.02, 512, false, 4.0, _grad([[0.0, Color(0.13, 0.11, 0.09)], [0.55, Color(0.22, 0.19, 0.15)], [1.0, Color(0.3, 0.27, 0.21)]]))
	ground.normal_enabled = true
	ground.normal_texture = _noise_tex(0.035, 512, true, 6.0)
	ground.roughness = 0.95
	ground.uv1_scale = Vector3(14, 14, 1)
	m.ground = _save(ground, MAT + "ground.tres")
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = _noise_tex(0.03, 256, false, 4.0, _grad([[0.0, Color(0.24, 0.15, 0.09)], [0.5, Color(0.38, 0.26, 0.16)], [1.0, Color(0.5, 0.36, 0.23)]]))
	wood.normal_enabled = true
	wood.normal_texture = _noise_tex(0.05, 256, true, 3.0)
	wood.roughness = 0.82
	wood.uv1_scale = Vector3(3, 0.25, 1)
	m.wood = _save(wood, MAT + "wood.tres")
	var stone := StandardMaterial3D.new()
	stone.albedo_texture = _noise_tex(0.04, 256, false, 4.0, _grad([[0.0, Color(0.25, 0.25, 0.24)], [1.0, Color(0.42, 0.41, 0.39)]]))
	stone.normal_enabled = true
	stone.normal_texture = _noise_tex(0.06, 256, true, 5.0)
	stone.roughness = 0.9
	m.stone = _save(stone, MAT + "stone.tres")
	return m


# ---------------- 受击 ----------------

func _build_timeline() -> Resource:
	var t: Resource = load(SCR + "vfx_timeline.gd").new()
	t.delays = {
		"Flash": 0.0, "Glow": 0.0, "CutCrescent": 0.0, "ImpactLight": 0.0, "Sparks": 0.0, "Scorch": 0.0,
		"FireCore": 0.01, "Shockwave": 0.02, "FireBurst": 0.03, "Embers": 0.05, "Smoke": 0.07, "Afterburn": 0.08,
	}
	t.lifetime = 7.0
	return _save(t, PRE + "fire_impact_timeline.tres")


## 受击特效的本地坐标：X = 刀的运动方向，Y = 刀身方向（指向木桩里面），-Y = 朝外
func _build_impact(m: Dictionary, timeline: Resource) -> void:
	var root := Node3D.new()
	root.name = "FireImpact"
	root.set_script(load(SCR + "vfx_sequence_player.gd"))
	root.set("timeline", timeline)
	var fade_out := _grad_tex([[0.0, Color(1, 1, 1, 1)], [0.6, Color(1, 1, 1, 0.6)], [1.0, Color(1, 1, 1, 0)]])

	# 爆点星芒：一帧弹出再收（课程 Flare）
	root.add_child(_particles("Flash", 1, 0.14, Vector2(1.1, 1.1), m.fx_flash, {
		"scale_curve": _curve_tex([[0.0, 0.3], [0.15, 1.0], [1.0, 0.0]]), "angle_min": 0.0, "angle_max": 360.0}, {"local_coords": true}))
	root.add_child(_particles("Glow", 1, 0.25, Vector2(1.5, 1.5), m.fx_glow, {
		"scale_curve": _curve_tex([[0.0, 0.5], [0.2, 1.0], [1.0, 1.1]]), "color_ramp": fade_out}, {"local_coords": true}))
	# 刀口月牙：贴在挥砍平面上，告诉玩家“这一刀从哪划过去”
	root.add_child(_particles("CutCrescent", 1, 0.16, Vector2(1.3, 0.65), m.fx_crescent, {
		"scale_curve": _curve_tex([[0.0, 0.4], [0.25, 1.0], [1.0, 1.1]]),
		"color_ramp": _grad_tex([[0.0, Color(1, 1, 1, 1)], [0.4, Color(1, 0.8, 0.6, 0.8)], [1.0, Color(1, 0.4, 0.1, 0)]])}, {"local_coords": true}))
	root.add_child(_particles("Shockwave", 1, 0.2, Vector2(1.1, 1.1), m.fx_ring, {
		"scale_curve": _curve_tex([[0.0, 0.15], [0.35, 0.85], [1.0, 1.0]]), "color_ramp": fade_out}, {"local_coords": true}))
	# 飞溅火星：沿刀的运动方向喷出，拉长、受重力、在地上弹
	root.add_child(_particles("Sparks", 60, 0.7, Vector2(0.02, 0.22), m.fx_spark, {
		"direction": Vector3(1.0, -0.3, 0.0), "spread": 40.0, "initial_velocity_min": 4.0, "initial_velocity_max": 10.0,
		"gravity": Vector3(0, -9.8, 0), "damping_min": 1.0, "damping_max": 3.0, "lifetime_randomness": 0.5,
		"scale_curve": _curve_tex([[0.0, 1.0], [1.0, 0.2]]),
		"color_ramp": _grad_tex([[0.0, Color(1, 1, 1, 1)], [0.3, Color(1, 0.8, 0.5, 1)], [0.7, Color(1, 0.35, 0.08, 1)], [1.0, Color(0.8, 0.1, 0.0, 0)]]),
		"collision_mode": ParticleProcessMaterial.COLLISION_RIGID, "collision_bounce": 0.35, "collision_friction": 0.2},
		{"transform_align": GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY, "explosiveness": 0.95, "collision_base_size": 0.01}))
	# 火团：白热小核 + 向外翻滚的火焰
	root.add_child(_particles("FireCore", 14, 0.35, Vector2(0.4, 0.4), m.fx_puff_hot, _puff_opts({
		"initial_velocity_min": 0.3, "initial_velocity_max": 0.9, "spread": 180.0, "gravity": Vector3(0, 2.0, 0)})))
	# 爆开的火：几十个火团一起喷出去，叠成一大团
	root.add_child(_particles("FireBurst", 60, 0.7, Vector2(0.42, 0.42), m.fx_puff, _puff_opts({
		"direction": Vector3(1.0, -0.25, 0.0), "spread": 70.0, "initial_velocity_min": 0.8, "initial_velocity_max": 3.2,
		"damping_min": 3.0, "damping_max": 5.0, "gravity": Vector3(0, 2.4, 0), "lifetime_randomness": 0.45}),
		{"explosiveness": 0.9}))
	# 余火：刀口处继续烧一会儿（消散阶段）
	var afterburn := _particles("Afterburn", 90, 0.6, Vector2(0.24, 0.24), m.fx_puff, _puff_opts({
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_BOX, "emission_box_extents": Vector3(0.12, 0.04, 0.04),
		"gravity": Vector3(0, 2.2, 0)}),
		{"one_shot": false, "explosiveness": 0.0, "position": Vector3(0, -0.06, 0)})
	afterburn.set_script(load(SCR + "vfx_emit_for.gd"))
	afterburn.set("duration", 1.6)
	root.add_child(afterburn)
	root.add_child(_particles("Smoke", 9, 1.4, Vector2(0.7, 0.7), m.fx_smoke, {
		"direction": Vector3(0.5, -0.5, 0.0), "spread": 60.0, "initial_velocity_min": 0.3, "initial_velocity_max": 0.9,
		"damping_min": 1.5, "damping_max": 1.5, "gravity": Vector3(0, 0.9, 0), "lifetime_randomness": 0.3,
		"scale_curve": _curve_tex([[0.0, 0.4], [1.0, 1.6]]), "angle_min": -30.0, "angle_max": 30.0,
		"anim_offset_min": 0.0, "anim_offset_max": 1.0}, {"explosiveness": 0.7}))
	root.add_child(_particles("Embers", 28, 1.8, Vector2(0.012, 0.05), m.fx_ember, {
		"direction": Vector3(1.0, 0.0, 0.0), "spread": 180.0, "initial_velocity_min": 1.0, "initial_velocity_max": 3.5,
		"gravity": Vector3(0, 0.8, 0), "damping_min": 1.5, "damping_max": 1.5, "lifetime_randomness": 0.4,
		"turbulence_enabled": true, "turbulence_noise_strength": 2.0, "turbulence_noise_scale": 2.5,
		"turbulence_influence_min": 0.15, "turbulence_influence_max": 0.3,
		"scale_curve": _curve_tex([[0.0, 1.0], [1.0, 0.0]]),
		"color_ramp": _grad_tex([[0.0, Color(1, 0.8, 0.4, 1)], [0.5, Color(1, 0.4, 0.1, 1)], [1.0, Color(0.6, 0.08, 0.0, 0)]])},
		{"transform_align": GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY, "explosiveness": 0.8}))
	# 火光
	var light := OmniLight3D.new()
	light.name = "ImpactLight"
	light.set_script(load(SCR + "vfx_light_pulse.gd"))
	light.position = Vector3(0, -0.15, 0)
	light.omni_range = 4.0
	light.light_color = Color(1.0, 0.55, 0.25)
	light.shadow_enabled = false
	light.set("peak_energy", 7.0)
	light.set("duration", 0.4)
	light.set("curve", _curve([[0.0, 1.0], [0.15, 0.7], [1.0, 0.0]]))
	root.add_child(light)
	# 焦痕：从外往木桩里投（Decal 沿自身 -Y 投影，所以绕 X 转 180°）
	var decal := Decal.new()
	decal.name = "Scorch"
	decal.set_script(load(SCR + "vfx_decal_fade.gd"))
	decal.rotation_degrees = Vector3(180, 0, 0)
	decal.size = Vector3(0.45, 0.4, 0.22)
	decal.texture_albedo = load(TEX + "scorch_albedo.png")
	decal.texture_emission = load(TEX + "scorch_emission.png")
	decal.normal_fade = 0.3
	decal.upper_fade = 0.05
	decal.lower_fade = 0.05
	root.add_child(decal)
	_own(root, root)
	for c in root.get_children():
		c.owner = root
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, ROOT + "vfx/fire_impact.tscn") == OK)


# ---------------- 招式 / 光照 ----------------

func _build_moves() -> Array[Resource]:
	var script := load(SCR + "swing_move.gd")
	var defs := [
		["slash_diagonal", {"display_name": "斜劈", "direction_deg": 40.0, "start_deg": -115.0, "end_deg": 95.0, "cock_deg": 12.0,
			"prepare_time": 0.4, "charge_time": 0.24, "swing_time": 0.3}],
		["slash_horizontal", {"display_name": "横斩", "direction_deg": 95.0, "start_deg": -120.0, "end_deg": 100.0, "cock_deg": 14.0,
			"prepare_time": 0.42, "charge_time": 0.22, "swing_time": 0.3, "hitstop": 0.05, "shake": 0.04}],
		["slash_rising", {"display_name": "上撩", "direction_deg": 165.0, "start_deg": -105.0, "end_deg": 105.0, "cock_deg": 10.0,
			"prepare_time": 0.45, "charge_time": 0.2, "swing_time": 0.28, "hitstop": 0.05}],
		["slash_heavy", {"display_name": "蓄力重劈", "direction_deg": 0.0, "start_deg": -150.0, "end_deg": 80.0, "cock_deg": 22.0,
			"prepare_time": 0.5, "charge_time": 0.8, "swing_time": 0.34, "swing_power": 5.0, "recover_time": 0.6, "rest_time": 0.5,
			"heat_peak": 1.5, "intensity": 1.4, "lunge": 0.14, "tremble": 1.0, "hitstop": 0.11, "shake": 0.12, "impact_scale": 1.35}],
	]
	var out: Array[Resource] = []
	for d in defs:
		var r: Resource = script.new()
		for k in d[1]:
			r.set(k, d[1][k])
		out.append(_save(r, PRE + d[0] + ".tres"))
	return out


func _env(night: bool) -> Environment:
	var sky_mat := ProceduralSkyMaterial.new()
	if night:
		sky_mat.sky_top_color = Color(0.02, 0.03, 0.07)
		sky_mat.sky_horizon_color = Color(0.08, 0.1, 0.16)
		sky_mat.ground_horizon_color = Color(0.06, 0.07, 0.1)
		sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.03)
		sky_mat.sky_energy_multiplier = 0.6
	else:
		sky_mat.sky_top_color = Color(0.32, 0.5, 0.78)
		sky_mat.sky_horizon_color = Color(0.72, 0.78, 0.82)
		sky_mat.ground_horizon_color = Color(0.55, 0.55, 0.5)
		sky_mat.ground_bottom_color = Color(0.25, 0.24, 0.2)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.8 if night else 1.0
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.19
	e.tonemap_agx_contrast = 1.5
	e.glow_enabled = true
	e.glow_intensity = 0.45
	e.glow_strength = 1.0
	e.glow_bloom = 0.03
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	e.set_glow_level(0, 0.0)
	e.set_glow_level(1, 0.6)
	e.set_glow_level(2, 1.0)
	e.set_glow_level(3, 0.8)
	e.set_glow_level(4, 0.6)
	e.ssao_enabled = true
	e.fog_enabled = true
	e.fog_light_color = Color(0.1, 0.12, 0.18) if night else Color(0.7, 0.75, 0.8)
	e.fog_density = 0.02 if night else 0.006
	return e


func _build_looks() -> Array[Resource]:
	var script := load(SCR + "light_look.gd")
	var night: Resource = script.new()
	night.display_name = "夜晚"
	night.environment = _env(true)
	night.sun_color = Color(0.55, 0.65, 1.0)
	night.sun_energy = 0.35
	night.sun_rotation_deg = Vector3(-35, 140, 0)
	var day: Resource = script.new()
	day.display_name = "白天"
	day.environment = _env(false)
	day.sun_color = Color(1.0, 0.95, 0.88)
	day.sun_energy = 2.0
	day.sun_rotation_deg = Vector3(-50, -30, 0)
	var out: Array[Resource] = [_save(night, PRE + "look_night.tres"), _save(day, PRE + "look_day.tres")]
	return out


# ---------------- 演示场景 ----------------

func _mesh_node(mesh: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi


func _build_demo(m: Dictionary, moves: Array[Resource], looks: Array[Resource]) -> void:
	var root := Node3D.new()
	root.name = "FireKatanaDemo"
	root.set_script(load(SCR + "demo_director.gd"))

	var env := WorldEnvironment.new()
	env.environment = looks[0].environment
	_add(root, env, "WorldEnvironment")
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 20.0
	_add(root, sun, "Sun")
	var cam := Camera3D.new()
	cam.set_script(load(SCR + "demo_camera.gd"))
	cam.fov = 50.0
	cam.current = true
	_add(root, cam, "Camera")

	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	_add(root, _mesh_node(plane, m.ground), "Ground")
	var floor_col := GPUParticlesCollisionBox3D.new()
	floor_col.size = Vector3(40, 1, 40)
	floor_col.position = Vector3(0, -0.5, 0)
	_add(root, floor_col, "FloorCollision")

	# 木桩
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.5, 0.18, 0.5)
	_add(root, _mesh_node(base_mesh, m.stone, Vector3(0, 0.09, 0)), "PostBase")
	var post := Node3D.new()
	post.set_script(load(SCR + "target_post.gd"))
	post.position = Vector3(0, 0.18, 0)
	_add(root, post, "TargetPost")
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.11
	cyl.bottom_radius = 0.115
	cyl.height = 1.75
	cyl.radial_segments = 32
	_add(post, _mesh_node(cyl, m.wood, Vector3(0, 0.875, 0)), "Post")
	var band := CylinderMesh.new()
	band.top_radius = 0.119
	band.bottom_radius = 0.121
	band.height = 0.05
	band.radial_segments = 32
	_add(post, _mesh_node(band, m.iron, Vector3(0, 1.5, 0)), "BandTop")
	_add(post, _mesh_node(band, m.iron, Vector3(0, 0.3, 0)), "BandLow")
	var contact := Marker3D.new()
	contact.position = Vector3(0, 1.07, 0)
	_add(post, contact, "ContactPoint")

	# 太刀
	var rig := Node3D.new()
	rig.set_script(load(SCR + "katana_rig.gd"))
	rig.position = Vector3(-0.6, 1.25, 0.05)
	_add(root, rig, "KatanaRig")
	var katana := Node3D.new()
	_add(rig, katana, "Katana")
	var km := MeshInstance3D.new()
	km.mesh = load(ROOT + "generated/katana_mesh.res")
	_add(katana, km, "KatanaMesh")
	km.set_surface_override_material(0, m.blade)
	km.set_surface_override_material(1, m.gold)
	km.set_surface_override_material(2, m.iron)
	km.set_surface_override_material(3, m.tsuka)
	var tb := Marker3D.new()
	tb.position = Vector3(0, 0.12, 0.0)
	_add(katana, tb, "TrailBase")
	var tt := Marker3D.new()
	tt.position = Vector3(0, 0.746, -0.0395)
	_add(katana, tt, "TrailTip")

	var bfx := Node3D.new()
	bfx.set_script(load(SCR + "fire_blade_fx.gd"))
	_add(katana, bfx, "BladeFx")
	# 冰/雷附魔挂这里：刀身中点，刀尖朝 -Z（和游戏里 ActorView.blade 的约定一样）
	var mount := Node3D.new()
	mount.position = Vector3(0, 0.39, -0.015)
	mount.rotation_degrees = Vector3(90, 0, 0)
	_add(katana, mount, "EnchantMount")
	var blade_center := Vector3(0, 0.39, -0.01)
	var blight := OmniLight3D.new()
	blight.omni_range = 3.5
	blight.light_color = Color(1.0, 0.5, 0.2)
	blight.light_energy = 0.0
	blight.shadow_enabled = false
	blight.position = blade_center
	_add(bfx, blight, "BladeLight")
	var gather := _particles("Gather", 40, 0.35, Vector2(0.035, 0.035), m.fx_gather, {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_BOX, "emission_box_extents": Vector3(0.2, 0.42, 0.2),
		"radial_accel_min": -9.0, "radial_accel_max": -7.0, "damping_min": 2.0, "damping_max": 2.0,
		"scale_min": 0.6, "scale_max": 1.3,
		"color_ramp": _grad_tex([[0.0, Color(1, 1, 1, 0)], [0.3, Color(1, 0.8, 0.5, 1)], [1.0, Color(1, 0.4, 0.1, 0)]])},
		{"one_shot": false, "explosiveness": 0.0, "local_coords": true, "position": blade_center})
	_add(bfx, gather, "Gather")
	# 刀身火和火星从刀面上的点发射（点由 build_assets 按刀身截面采样，偏刃口）
	var blade_points: Texture2D = load(ROOT + "generated/blade_points.res")
	var points := {"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_POINTS,
		"emission_point_texture": blade_points, "emission_point_count": blade_points.get_width()}
	# 刀身持续燃烧：几百个火团从刀面冒出、向上飘、按寿命变色成烟。粒子在世界坐标里，挥刀时自然甩在后面成拖尾
	var flame_opts := _puff_opts({"inherit_velocity_ratio": 0.05})
	flame_opts.merge(points)
	var flames := _particles("Flames", 340, 0.55, Vector2(0.17, 0.17), m.fx_puff, flame_opts,
		{"one_shot": false, "explosiveness": 0.0})
	_add(bfx, flames, "Flames")
	var ember_opts := {
		"initial_velocity_min": 0.5, "initial_velocity_max": 1.5, "spread": 180.0, "inherit_velocity_ratio": 0.25,
		"gravity": Vector3(0, -2.0, 0), "damping_min": 1.5, "damping_max": 1.5, "lifetime_randomness": 0.4,
		"turbulence_enabled": true, "turbulence_noise_strength": 1.5, "turbulence_noise_scale": 3.0,
		"turbulence_influence_min": 0.1, "turbulence_influence_max": 0.2,
		"scale_curve": _curve_tex([[0.0, 1.0], [1.0, 0.0]]),
		"color_ramp": _grad_tex([[0.0, Color(1, 0.9, 0.6, 1)], [0.5, Color(1, 0.45, 0.1, 1)], [1.0, Color(0.7, 0.1, 0.0, 0)]])}
	ember_opts.merge(points)
	var embers := _particles("Embers", 80, 0.8, Vector2(0.012, 0.07), m.fx_ember, ember_opts,
		{"one_shot": false, "explosiveness": 0.0, "transform_align": GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY})
	_add(bfx, embers, "Embers")
	bfx.set("blade_mesh", km)
	bfx.set("light", blight)
	bfx.set("gather", gather)
	bfx.set("flames", flames)
	bfx.set("embers", embers)
	# 挥砍时沿刀弧补发的火团（按补采样点发射，拖尾连续不断成簇）
	# 挥砍时加量：同样从刀面发射，每帧在刀经过的位置留下一排火团，连起来就是火焰拖尾
	var arc_opts := _puff_opts({"damping_min": 2.0, "damping_max": 3.0, "lifetime_randomness": 0.45, "inherit_velocity_ratio": 0.04})
	arc_opts.merge(points)
	var arc_flames := _particles("ArcFlames", 2200, 0.4, Vector2(0.26, 0.26), m.fx_puff, arc_opts,
		{"one_shot": false, "explosiveness": 0.0})
	_add(root, arc_flames, "ArcFlames")
	bfx.set("arc_flames", arc_flames)

	# 刀光拖尾
	var trail := Node3D.new()
	trail.set_script(load(SCR + "fire_ribbon_trail.gd"))
	_add(root, trail, "FireTrail")
	# 只留淡淡的烟带；火的拖尾交给火团本身
	for pair in [["Smoke", m.ribbon_smoke], ["Flame", m.ribbon_flame]]:
		var mi := MeshInstance3D.new()
		mi.material_override = pair[1]
		_add(trail, mi, pair[0])

	rig.set("katana", katana)
	rig.set("trail_base", tb)
	rig.set("trail_tip", tt)
	rig.set("trail", trail)
	rig.set("blade_fx", bfx)
	rig.set("target", contact)

	# 界面
	var ui := CanvasLayer.new()
	_add(root, ui, "UI")
	var label := Label.new()
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 5)
	_add(ui, label, "Help")

	root.set("rig", rig)
	root.set("impact_scene", load(ROOT + "vfx/fire_impact.tscn"))
	root.set("moves", moves)
	root.set("camera", cam)
	root.set("target_post", post)
	root.set("label", label)
	root.set("world_env", env)
	root.set("sun", sun)
	root.set("looks", looks)
	const ENCH := "res://vfx_lab/elemental_enchants/"
	root.set("element_enchants", {"ice": load(ENCH + "ice_enchant.tscn"), "thunder": load(ENCH + "thunder_enchant.tscn")})
	root.set("element_impacts", {"ice": load(ENCH + "ice_impact.tscn"), "thunder": load(ENCH + "thunder_impact.tscn")})
	root.set("blade_overlays", {"fire": m.blade.next_pass, "ice": load(ENCH + "generated/frost_overlay.tres"), "thunder": load(ENCH + "generated/electric_overlay.tres")})
	root.set("enchant_mount", mount)
	root.set("blade_fx", bfx)
	root.set("fire_trail", trail)
	root.set("katana_mesh", km)

	_own(root, root)
	for c in root.get_children():
		_own(c, root)
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, ROOT + "fire_katana_demo.tscn") == OK)
