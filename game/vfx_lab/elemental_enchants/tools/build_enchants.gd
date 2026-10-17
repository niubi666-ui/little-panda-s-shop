extends SceneTree
## 生成冰/雷附魔演示用的贴图、冰晶网格、材质、附魔场景和受击场景。分两步（中间要 --import 一次）：
## Godot --headless --path game --script res://vfx_lab/elemental_enchants/tools/build_enchants.gd -- textures
## Godot --headless --path game --import
## Godot --headless --path game --script res://vfx_lab/elemental_enchants/tools/build_enchants.gd -- scenes

const DIR := "res://vfx_lab/elemental_enchants/"
const GEN := DIR + "generated/"
const SCR := DIR + "scripts/"
const SH := DIR + "shaders/"
const LAB := "res://vfx_lab/fire_katana/"
const LAB_TEX := LAB + "generated/textures/"

var _noise := FastNoiseLite.new()


func _init() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 5
	_noise.frequency = 1.0
	var args := OS.get_cmdline_user_args()
	if args.has("textures"):
		_build_textures()
	if args.has("scenes"):
		_build_scenes()
	quit()


func _n(x: float, y: float) -> float:
	return _noise.get_noise_2d(x, y) * 0.5 + 0.5


# ================= 贴图 / 网格 =================

func _build_textures() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GEN))
	_mist_atlas(512).save_png(GEN + "mist_atlas.png")
	var frost := _frost_decal(256)
	frost[0].save_png(GEN + "frost_albedo.png")
	frost[1].save_png(GEN + "frost_emission.png")
	_blue_scorch().save_png(GEN + "scorch_emission_blue.png")
	ResourceSaver.save(_crystal_mesh(true), GEN + "ice_spike_mesh.res")
	ResourceSaver.save(_crystal_mesh(false), GEN + "ice_shard_mesh.res")
	print("enchant textures built")


## 4x4 软雾团：没有火丝，只有柔和的卷曲（寒气、电晕都用它）
func _mist_atlas(s: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var cell := s / 4
	for c in 16:
		var off := Vector2(c * 23.7, c * 41.3)
		for py in cell:
			for px in cell:
				var x := (px + 0.5) / cell * 2.0 - 1.0
				var y := 1.0 - (py + 0.5) / cell * 2.0
				var wx := x + 0.35 * (_n(x * 1.5 + off.x, y * 1.5 + off.y) - 0.5)
				var wy := y + 0.35 * (_n(x * 1.5 + off.x + 9.0, y * 1.5 + off.y + 9.0) - 0.5)
				var r := sqrt(wx * wx + wy * wy)
				var blob := smoothstep(0.95, 0.05, r)
				var v := pow(blob, 1.6) * (0.45 + 0.55 * _n(x * 3.0 + off.x, y * 3.0 + off.y))
				v *= smoothstep(1.0, 0.88, maxf(absf(x), absf(y)))
				v = clampf(v, 0.0, 1.0)
				img.set_pixel((c % 4) * cell + px, (c / 4) * cell + py, Color(v, v, v, v))
	return img


## 受击处的霜花：放射状的冰晶纹 + 不规则边缘
func _frost_decal(s: int) -> Array:
	var cells := FastNoiseLite.new()
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	cells.frequency = 0.06
	var albedo := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var emission := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for py in s:
		for px in s:
			var x := (px + 0.5) / s * 2.0 - 1.0
			var y := 1.0 - (py + 0.5) / s * 2.0
			var r := sqrt(x * x + y * y)
			var a := atan2(y, x)
			var ragged := 0.55 + 0.3 * _n(cos(a) * 2.0, sin(a) * 2.0)
			var cover := smoothstep(ragged, ragged * 0.6, r)
			var edge := 1.0 - clampf(cells.get_noise_2d(px, py) * 0.5 + 0.5, 0.0, 1.0) * 1.6
			var rays := pow(absf(sin(a * 7.0 + _n(r * 3.0, 1.0) * 2.0)), 18.0) * smoothstep(0.9, 0.1, r)
			var lines := clampf(maxf(smoothstep(0.55, 0.9, edge), rays), 0.0, 1.0)
			var alpha := clampf(cover * (0.35 + 0.65 * lines), 0.0, 1.0)
			var c := Color(0.78, 0.9, 1.0).lerp(Color(1, 1, 1), lines)
			albedo.set_pixel(px, py, Color(c.r, c.g, c.b, alpha))
			var e := lines * cover
			emission.set_pixel(px, py, Color(e * 0.45, e * 0.75, e, 1.0))
	return [albedo, emission]


## 雷击焦痕的自发光：拿火焰焦痕的发光图换成蓝白色
func _blue_scorch() -> Image:
	var src := Image.load_from_file(ProjectSettings.globalize_path(LAB_TEX + "scorch_emission.png"))
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			var e := c.r
			src.set_pixel(x, y, Color(e * 0.5, e * 0.7, e, 1.0))
	return src


## 六棱双锥冰晶。spike = true：底在 y=0、尖在 y=1（受击冰刺）；否则居中、长 1（甩出的冰碴）
func _crystal_mesh(spike: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 6
	var y_bottom := -0.12 if spike else -0.5
	var y_waist := 0.22 if spike else -0.05
	var y_top := 1.0 if spike else 0.5
	var ring: Array[Vector3] = []
	for i in sides:
		var a := TAU * i / sides + 0.2
		var r := 1.0 + 0.18 * sin(i * 2.3)
		ring.append(Vector3(cos(a) * r, y_waist, sin(a) * r))
	var top := Vector3(0.05, y_top, -0.03)
	var bottom := Vector3(0.0, y_bottom, 0.0)
	for i in sides:
		var p0 := ring[i]
		var p1 := ring[(i + 1) % sides]
		for tri in [[p0, top, p1], [p0, p1, bottom]]:
			for v in tri:
				st.set_uv(Vector2(0.0, (v.y - y_bottom) / (y_top - y_bottom)))
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


# ================= 场景 =================

func _save(res: Resource, path: String) -> Resource:
	assert(ResourceSaver.save(res, path) == OK, "save failed " + path)
	return load(path)


func _shader_mat(shader: String, params: Dictionary, priority := 0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SH + shader)
	for k in params:
		m.set_shader_parameter(k, params[k])
	m.render_priority = priority
	return m


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


func _noise_tex(freq: float, cellular := false) -> NoiseTexture2D:
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


func _particles(n: String, amount: int, lifetime: float, draw: Mesh, mat: Material, opts: Dictionary, node_opts := {}) -> GPUParticles3D:
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


func _quad(w: float, h := -1.0) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(w, w if h < 0.0 else h)
	return q


func _pack(root: Node, path: String) -> void:
	_own(root, root)
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, path) == OK)


func _own(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_own(c, owner)


func _light(n: String, color: Color, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = n
	l.light_color = color
	l.omni_range = reach
	l.light_energy = 0.0
	l.shadow_enabled = false
	return l


func _build_scenes() -> void:
	var mist_tex := load(GEN + "mist_atlas.png")
	var star := load(LAB_TEX + "flare_star.png")
	var soft := load(LAB_TEX + "soft_dot.png")
	var ring := load(LAB_TEX + "ring.png")
	var spike_mesh: Mesh = load(GEN + "ice_spike_mesh.res")
	var shard_mesh: Mesh = load(GEN + "ice_shard_mesh.res")

	# ---- 材质 ----
	var mist_mat := _save(_shader_mat("mist_puff.gdshader", {"tex": mist_tex, "emission": 1.0, "opacity": 0.4}, 1), GEN + "ice_mist.tres")
	var aura_mat := _save(_shader_mat("mist_puff.gdshader", {"tex": mist_tex, "emission": 1.2, "opacity": 0.28, "additive": 1.0}, 1), GEN + "thunder_aura.tres")
	var glint_ice := _save(_shader_mat("glint.gdshader", {"tex": star, "tint": Color(0.75, 0.9, 1.0), "emission": 3.0, "twinkle": 1.0}, 2), GEN + "ice_glint.tres")
	var spark_mat := _save(_shader_mat("glint.gdshader", {"tex": soft, "tint": Color(0.7, 0.82, 1.0), "emission": 7.0, "billboard": false}, 2), GEN + "thunder_spark.tres")
	var shard_mat := _save(_shader_mat("ice_shard.gdshader", {}, 0), GEN + "ice_shard.tres")
	var bolt_glow := _save(_shader_mat("lightning.gdshader", {"color": Color(0.35, 0.5, 1.0), "emission": 1.6, "falloff": 1.6}, 2), GEN + "bolt_glow.tres")
	var bolt_core := _save(_shader_mat("lightning.gdshader", {"color": Color(0.85, 0.92, 1.0), "emission": 6.0, "falloff": 4.0}, 3), GEN + "bolt_core.tres")
	_save(_shader_mat("frost_overlay.gdshader", {"cells_tex": _noise_tex(0.035, true), "noise_tex": _noise_tex(0.02)}, 1), GEN + "frost_overlay.tres")
	_save(_shader_mat("electric_overlay.gdshader", {"noise_tex": _noise_tex(0.025)}, 1), GEN + "electric_overlay.tres")
	var flash_ice := _save(_shader_mat("glint.gdshader", {"tex": star, "tint": Color(0.7, 0.88, 1.0), "emission": 2.0}, 2), GEN + "ice_flash.tres")
	var glow_ice := _save(_shader_mat("glint.gdshader", {"tex": soft, "tint": Color(0.5, 0.75, 1.0), "emission": 0.3}, 2), GEN + "ice_glow.tres")
	var flash_bolt := _save(_shader_mat("glint.gdshader", {"tex": star, "tint": Color(0.8, 0.88, 1.0), "emission": 3.0}, 2), GEN + "thunder_flash.tres")
	var glow_bolt := _save(_shader_mat("glint.gdshader", {"tex": soft, "tint": Color(0.4, 0.55, 1.0), "emission": 0.9}, 2), GEN + "thunder_glow.tres")
	var ring_bolt := _save(_shader_mat("glint.gdshader", {"tex": ring, "tint": Color(0.5, 0.65, 1.0), "emission": 1.8}, 2), GEN + "thunder_ring.tres")

	var mist_ramp := _grad_tex([[0.0, Color(0.85, 0.95, 1.0, 0.0)], [0.15, Color(0.8, 0.92, 1.0, 0.5)], [0.6, Color(0.7, 0.85, 1.0, 0.22)], [1.0, Color(0.7, 0.85, 1.0, 0.0)]])
	var aura_ramp := _grad_tex([[0.0, Color(0.3, 0.45, 1.0, 0.0)], [0.2, Color(0.35, 0.5, 1.0, 0.45)], [1.0, Color(0.45, 0.25, 1.0, 0.0)]])
	var inout := _grad_tex([[0.0, Color(1, 1, 1, 0)], [0.2, Color(1, 1, 1, 1)], [1.0, Color(1, 1, 1, 0)]])
	var fade_end := _grad_tex([[0.0, Color(1, 1, 1, 1)], [0.75, Color(1, 1, 1, 1)], [1.0, Color(1, 1, 1, 0)]])
	var pop := _curve_tex([[0.0, 0.3], [0.15, 1.0], [1.0, 0.0]])
	var fade_out := _grad_tex([[0.0, Color(1, 1, 1, 1)], [0.6, Color(1, 1, 1, 0.6)], [1.0, Color(1, 1, 1, 0)]])
	var puff_common := {"anim_speed_min": 0.0, "anim_speed_max": 0.0, "anim_offset_min": 0.0, "anim_offset_max": 1.0,
		"angle_min": 0.0, "angle_max": 360.0, "angular_velocity_min": -30.0, "angular_velocity_max": 30.0}

	# ---- 冰附魔 ----
	var ice := Node3D.new()
	ice.name = "IceEnchant"
	ice.set_script(load(SCR + "ice_enchant.gd"))
	var o := puff_common.duplicate()
	o.merge({"color_ramp": mist_ramp, "gravity": Vector3(0, -0.5, 0), "initial_velocity_min": 0.05, "initial_velocity_max": 0.15, "spread": 180.0,
		"damping_min": 0.5, "damping_max": 0.8, "lifetime_randomness": 0.35, "scale_min": 0.6, "scale_max": 1.2,
		"scale_curve": _curve_tex([[0.0, 0.4], [0.3, 1.0], [1.0, 1.6]])})
	var mist := _particles("Mist", 90, 1.0, _quad(0.18), mist_mat, o)
	ice.add_child(mist)
	var glints := _particles("Glints", 40, 0.9, _quad(0.035), glint_ice, {"color_ramp": inout, "initial_velocity_min": 0.05,
		"initial_velocity_max": 0.2, "spread": 180.0, "gravity": Vector3(0, -0.15, 0), "scale_min": 0.6, "scale_max": 1.4,
		"lifetime_randomness": 0.4, "angle_min": 0.0, "angle_max": 360.0})
	ice.add_child(glints)
	var o2 := puff_common.duplicate()
	o2.merge({"color_ramp": mist_ramp, "gravity": Vector3(0, -0.4, 0), "damping_min": 1.0, "damping_max": 1.5, "lifetime_randomness": 0.4,
		"scale_min": 0.7, "scale_max": 1.2, "scale_curve": _curve_tex([[0.0, 0.7], [0.3, 1.0], [1.0, 1.5]])})
	var trail_mist := _particles("TrailMist", 1500, 0.8, _quad(0.22), mist_mat, o2)
	ice.add_child(trail_mist)
	var shards := _particles("Shards", 300, 1.4, shard_mesh, shard_mat, {"gravity": Vector3(0, -9.8, 0), "damping_min": 0.2, "damping_max": 0.4,
		"scale_min": 0.018, "scale_max": 0.04, "color_ramp": fade_end, "collision_mode": ParticleProcessMaterial.COLLISION_RIGID,
		"collision_bounce": 0.3, "collision_friction": 0.4, "lifetime_randomness": 0.3}, {"collision_base_size": 0.02})
	shards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ice.add_child(shards)
	var ice_light := _light("IceLight", Color(0.6, 0.8, 1.0), 2.0)
	ice.add_child(ice_light)
	ice.set("fill_overlap", 0.9)
	for kv in [["mist", mist], ["glints", glints], ["trail_mist", trail_mist], ["shards", shards], ["light", ice_light], ["fill_reference", trail_mist]]:
		ice.set(kv[0], kv[1])
	_pack(ice, DIR + "ice_enchant.tscn")

	# ---- 雷附魔 ----
	var thunder := Node3D.new()
	thunder.name = "ThunderEnchant"
	thunder.set_script(load(SCR + "thunder_enchant.gd"))
	var strands := Node3D.new()
	strands.name = "Strands"
	strands.set_script(load(SCR + "lightning_strands.gd"))
	strands.set("glow_material", bolt_glow)
	strands.set("core_material", bolt_core)
	thunder.add_child(strands)
	var o3 := puff_common.duplicate()
	o3.merge({"color_ramp": aura_ramp, "gravity": Vector3(0, 0.3, 0), "initial_velocity_min": 0.02, "initial_velocity_max": 0.1, "spread": 180.0,
		"lifetime_randomness": 0.35, "scale_min": 0.6, "scale_max": 1.2, "scale_curve": _curve_tex([[0.0, 0.5], [0.3, 1.0], [1.0, 1.3]])})
	var aura := _particles("Aura", 90, 0.5, _quad(0.16), aura_mat, o3)
	thunder.add_child(aura)
	var trail_aura := _particles("TrailAura", 900, 0.35, _quad(0.18), aura_mat, o3.duplicate())
	thunder.add_child(trail_aura)
	var sparks := _particles("Sparks", 50, 0.18, _quad(0.007, 0.04), spark_mat, {"initial_velocity_min": 1.5, "initial_velocity_max": 4.0,
		"spread": 180.0, "gravity": Vector3(0, -3.0, 0), "damping_min": 2.0, "damping_max": 3.0, "lifetime_randomness": 0.5,
		"color_ramp": fade_out}, {"transform_align": GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY})
	thunder.add_child(sparks)
	var thunder_light := _light("ThunderLight", Color(0.55, 0.65, 1.0), 2.5)
	thunder.add_child(thunder_light)
	for kv in [["strands", strands], ["aura", aura], ["trail_aura", trail_aura], ["sparks", sparks], ["light", thunder_light], ["fill_reference", trail_aura]]:
		thunder.set(kv[0], kv[1])
	_pack(thunder, DIR + "thunder_enchant.tscn")

	# ---- 受击：冰 ----
	var timeline_script := load(LAB + "scripts/vfx_timeline.gd")
	var player_script := load(LAB + "scripts/vfx_sequence_player.gd")
	var ice_hit := Node3D.new()
	ice_hit.name = "IceImpact"
	ice_hit.set_script(player_script)
	var t_ice: Resource = timeline_script.new()
	t_ice.delays = {"Flash": 0.0, "Glow": 0.0, "Crystals": 0.0, "Frost": 0.0, "Light": 0.0, "MistBurst": 0.02, "Glitter": 0.03,
		"Shatter": 0.62, "ShatterMist": 0.62}
	t_ice.lifetime = 5.0
	ice_hit.set("timeline", t_ice)
	ice_hit.add_child(_one_shot("Flash", 1, 0.15, _quad(1.0), flash_ice, {"scale_curve": pop, "angle_min": 0.0, "angle_max": 360.0}, true))
	ice_hit.add_child(_one_shot("Glow", 1, 0.25, _quad(1.4), glow_ice, {"color_ramp": fade_out}, true))
	var crystals := Node3D.new()
	crystals.name = "Crystals"
	crystals.set_script(load(SCR + "crystal_burst.gd"))
	crystals.set("spike_mesh", spike_mesh)
	crystals.set("spike_material", shard_mat)
	ice_hit.add_child(crystals)
	var frost := Decal.new()
	frost.name = "Frost"
	frost.set_script(load(LAB + "scripts/vfx_decal_fade.gd"))
	frost.rotation_degrees = Vector3(180, 0, 0)
	frost.size = Vector3(0.5, 0.4, 0.5)
	frost.texture_albedo = load(GEN + "frost_albedo.png")
	frost.texture_emission = load(GEN + "frost_emission.png")
	frost.normal_fade = 0.3
	frost.set("glow_peak", 1.5)
	frost.set("glow_time", 1.2)
	frost.set("hold_time", 2.5)
	ice_hit.add_child(frost)
	var o4 := puff_common.duplicate()
	o4.merge({"color_ramp": mist_ramp, "direction": Vector3(0, -1, 0), "spread": 80.0, "initial_velocity_min": 0.5, "initial_velocity_max": 1.5,
		"damping_min": 2.0, "damping_max": 3.0, "gravity": Vector3(0, -0.4, 0), "lifetime_randomness": 0.3,
		"scale_curve": _curve_tex([[0.0, 0.5], [1.0, 1.5]])})
	ice_hit.add_child(_one_shot("MistBurst", 24, 1.2, _quad(0.4), mist_mat, o4))
	ice_hit.add_child(_one_shot("ShatterMist", 12, 1.0, _quad(0.35), mist_mat, o4.duplicate()))
	ice_hit.add_child(_one_shot("Glitter", 30, 1.6, _quad(0.05), glint_ice, {"color_ramp": inout, "initial_velocity_min": 0.3,
		"initial_velocity_max": 1.2, "spread": 180.0, "gravity": Vector3(0, -0.3, 0), "damping_min": 1.0, "damping_max": 1.5}))
	var shatter := _one_shot("Shatter", 36, 1.6, shard_mesh, shard_mat, {"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE,
		"emission_sphere_radius": 0.15, "direction": Vector3(0, -1, 0), "spread": 90.0, "initial_velocity_min": 1.0, "initial_velocity_max": 3.5,
		"gravity": Vector3(0, -9.8, 0), "scale_min": 0.03, "scale_max": 0.08, "color_ramp": fade_end,
		"collision_mode": ParticleProcessMaterial.COLLISION_RIGID, "collision_bounce": 0.3, "collision_friction": 0.4,
		"angle_min": 0.0, "angle_max": 360.0, "particle_flag_rotate_y": true})
	shatter.collision_base_size = 0.03
	shatter.position = Vector3(0, -0.15, 0)
	shatter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ice_hit.add_child(shatter)
	ice_hit.add_child(_pulse("Light", Color(0.6, 0.8, 1.0), 4.0, 0.35, 0.1))
	_pack(ice_hit, DIR + "ice_impact.tscn")

	# ---- 受击：雷 ----
	var bolt_hit := Node3D.new()
	bolt_hit.name = "ThunderImpact"
	bolt_hit.set_script(player_script)
	var t_bolt: Resource = timeline_script.new()
	t_bolt.delays = {"Flash": 0.0, "Glow": 0.0, "Strike": 0.0, "Sparks": 0.0, "Scorch": 0.0, "Light": 0.0, "Ring": 0.02}
	t_bolt.lifetime = 5.0
	bolt_hit.set("timeline", t_bolt)
	bolt_hit.add_child(_one_shot("Flash", 1, 0.1, _quad(0.9), flash_bolt, {"scale_curve": pop, "angle_min": 0.0, "angle_max": 360.0}, true))
	bolt_hit.add_child(_one_shot("Glow", 1, 0.18, _quad(1.2), glow_bolt, {"color_ramp": fade_out}, true))
	bolt_hit.add_child(_one_shot("Ring", 1, 0.2, _quad(1.2), ring_bolt, {"scale_curve": _curve_tex([[0.0, 0.15], [0.35, 0.85], [1.0, 1.0]]), "color_ramp": fade_out}, true))
	var strike := Node3D.new()
	strike.name = "Strike"
	strike.set_script(load(SCR + "bolt_strike.gd"))
	var strike_strands := Node3D.new()
	strike_strands.name = "Strands"
	strike_strands.set_script(load(SCR + "lightning_strands.gd"))
	strike_strands.set("glow_material", bolt_glow)
	strike_strands.set("core_material", bolt_core)
	strike.add_child(strike_strands)
	strike.set("strands", strike_strands)
	bolt_hit.add_child(strike)
	var hit_sparks := _one_shot("Sparks", 70, 0.6, _quad(0.012, 0.18), spark_mat, {"spread": 180.0, "initial_velocity_min": 3.0,
		"initial_velocity_max": 9.0, "gravity": Vector3(0, -6.0, 0), "damping_min": 1.0, "damping_max": 2.5, "lifetime_randomness": 0.5,
		"color_ramp": fade_out, "collision_mode": ParticleProcessMaterial.COLLISION_RIGID, "collision_bounce": 0.3, "collision_friction": 0.2})
	hit_sparks.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	hit_sparks.collision_base_size = 0.01
	bolt_hit.add_child(hit_sparks)
	var scorch := Decal.new()
	scorch.name = "Scorch"
	scorch.set_script(load(LAB + "scripts/vfx_decal_fade.gd"))
	scorch.rotation_degrees = Vector3(180, 0, 0)
	scorch.size = Vector3(0.45, 0.4, 0.3)
	scorch.texture_albedo = load(LAB_TEX + "scorch_albedo.png")
	scorch.texture_emission = load(GEN + "scorch_emission_blue.png")
	scorch.normal_fade = 0.3
	bolt_hit.add_child(scorch)
	bolt_hit.add_child(_pulse("Light", Color(0.6, 0.7, 1.0), 9.0, 0.45, 0.6))
	_pack(bolt_hit, DIR + "thunder_impact.tscn")
	print("enchant scenes built")


func _one_shot(n: String, amount: int, lifetime: float, draw: Mesh, mat: Material, opts: Dictionary, local := false) -> GPUParticles3D:
	var p := _particles(n, amount, lifetime, draw, mat, opts, {"one_shot": true, "explosiveness": 1.0, "local_coords": local})
	return p


func _pulse(n: String, color: Color, peak: float, duration: float, flicker: float) -> OmniLight3D:
	var l := _light(n, color, 4.0)
	l.set_script(load(LAB + "scripts/vfx_light_pulse.gd"))
	l.position = Vector3(0, -0.15, 0)
	l.set("peak_energy", peak)
	l.set("duration", duration)
	l.set("flicker", flicker)
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(0.15, 0.7))
	c.add_point(Vector2(1.0, 0.0))
	l.set("curve", c)
	return l
