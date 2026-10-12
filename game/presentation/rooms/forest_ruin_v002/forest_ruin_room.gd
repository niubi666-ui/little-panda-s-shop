extends "res://rogue/rooms/authored_room.gd"
## 森林遗迹 v002：Blender 场景接入层。
## 只负责：给导入的网格配材质、生成草地 MultiMesh、按 room_data.json 生成碰撞/灯光/萤火虫。
## 不含任何战斗逻辑。
const DATA_DIR := "res://assets/environments/forest_ruin_v002/"

@export var terrain_shader: Shader
@export var stone_shader: Shader
@export var foliage_shader: Shader
@export var water_shader: Shader
@export var leaf_texture: Texture2D
@export var ground_albedo: Texture2D
@export var plaza_albedo: Texture2D
## 战斗区域半径（广场边缘的柱环以内）；玩家与敌人被圆形边界限制在里面
@export var arena_radius := 13.2
@export var grass_density := 1.0

var data: Dictionary
var _materials: Dictionary = {}

func rift_surfaces() -> Array:
	var result: Array = []
	for name in ["Ground", "PlazaTiles", "Dais"]:
		var node := $Art.find_child(name, true, false)
		if node is MeshInstance3D: result.append(node)
	return result

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR + "room_data.json"))
	assert(data != null, "forest_ruin_v002: room_data.json missing")
	var to_sun := Vector3(data.sun.to_sun[0], data.sun.to_sun[1], data.sun.to_sun[2]).normalized()
	$Lights/Sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	_assign_materials()
	_build_grass()
	_build_collision()
	_build_lights()

# ---------------- 材质 ----------------
func _stone(key: String, a: Color, b: Color, params: Dictionary = {}) -> ShaderMaterial:
	if _materials.has(key): return _materials[key]
	var m := ShaderMaterial.new(); m.shader = stone_shader
	m.set_shader_parameter("color_a", a); m.set_shader_parameter("color_b", b)
	for k in params: m.set_shader_parameter(k, params[k])
	_materials[key] = m
	return m

func _foliage(key: String, params: Dictionary = {}) -> ShaderMaterial:
	if _materials.has(key): return _materials[key]
	var m := ShaderMaterial.new(); m.shader = foliage_shader
	m.set_shader_parameter("leaf_tex", leaf_texture)
	for k in params: m.set_shader_parameter(k, params[k])
	_materials[key] = m
	return m

func _std(key: String, color: Color, rough: float, metal := 0.0, emission := Color.BLACK, energy := 0.0, vertex_color := false) -> StandardMaterial3D:
	if _materials.has(key): return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color; m.roughness = rough; m.metallic = metal
	m.vertex_color_use_as_albedo = vertex_color
	if energy > 0.0:
		m.emission_enabled = true; m.emission = emission; m.emission_energy_multiplier = energy
	_materials[key] = m
	return m

func _material_for(node_name: String) -> Material:
	var base := node_name.get_slice(".", 0).get_slice("_", 0)
	match base:
		"Ground":
			var m := ShaderMaterial.new(); m.shader = terrain_shader
			var r: Dictionary = data.ground_rect_godot
			m.set_shader_parameter("albedo_tex", ground_albedo)
			m.set_shader_parameter("rect", Vector4(r.x0, r.z0, r.x1 - r.x0, r.z1 - r.z0))
			return m
		"PlazaTiles":
			var m := ShaderMaterial.new(); m.shader = terrain_shader
			var r: Dictionary = data.plaza_rect_godot
			m.set_shader_parameter("albedo_tex", plaza_albedo)
			m.set_shader_parameter("rect", Vector4(r.x0, r.z0, r.x1 - r.x0, r.z1 - r.z0))
			m.set_shader_parameter("detail_strength", 0.12)
			m.set_shader_parameter("roughness_base", 0.82)
			m.set_shader_parameter("wet_level", -9.0)
			return m
		"Stream", "Cascade":
			var m := ShaderMaterial.new(); m.shader = water_shader
			return m
		"Columns", "RuinWall", "Dais", "Statue", "Rocks":
			return _stone("stone", Color(0.39, 0.36, 0.31), Color(0.6, 0.56, 0.48))
		"StreamStones", "Pebbles":
			return _stone("pebble", Color(0.24, 0.23, 0.2), Color(0.5, 0.47, 0.41), {"moss_amount": 0.3, "roughness": 0.35, "moss_min_up": 0.75, "scale": 2.4})
		"Tree", "FallenLog":
			return _stone("bark", Color(0.13, 0.09, 0.06), Color(0.32, 0.23, 0.16), {"stretch": Vector3(3.0, 0.35, 3.0), "scale": 1.6, "moss_amount": 0.7, "moss_min_up": 0.2})
		"Cart", "ReedHeads":
			return _stone("wood", Color(0.18, 0.11, 0.06), Color(0.42, 0.28, 0.17), {"stretch": Vector3(1.0, 0.12, 1.0), "scale": 3.0, "moss_amount": 0.15})
		"LeafCards":
			return _foliage("leaves", {"sway": 0.07, "backlight": 0.6})
		"Ivy":
			return _foliage("ivy", {"sway": 0.03, "backlight": 0.5})
		"FallenLeaves":
			return _foliage("fallen", {"sway": 0.0, "backlight": 0.2})
		"CanopyCore":
			return _foliage("canopy", {"use_texture": false, "sway": 0.07, "backlight": 0.4})
		"Reeds":
			return _foliage("reeds", {"use_texture": false, "sway": 0.05, "sway_height": 1.5, "backlight": 0.6})
		"Flowers":
			return _std("flowers", Color.WHITE, 0.6, 0.0, Color.BLACK, 0.0, true)
		"Banner":
			var m := _std("banner", Color(0.42, 0.08, 0.08), 0.9)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			return m
		"BannerTrim":
			return _std("gold", Color(0.72, 0.54, 0.24), 0.38, 1.0)
		"LanternPosts":
			return _std("iron", Color(0.16, 0.15, 0.13), 0.5, 0.8)
		"LanternGlow":
			return _std("lantern", Color(1.0, 0.85, 0.6), 0.4, 0.0, Color(1.0, 0.62, 0.3), 9.0)
		"Runes", "SigilRings":
			return _std("sigil", Color(0.42, 0.35, 0.22), 0.5, 0.0, Color(1.0, 0.76, 0.36), 3.0)
		"Crystals":
			var m := _std("crystal", Color(0.2, 0.55, 0.68), 0.12, 0.0, Color(0.45, 0.88, 1.0), 2.6)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color.a = 0.85
			return m
		"Mushrooms":
			return _std("mushroom", Color(0.76, 0.33, 0.18), 0.45)
	return null

func _assign_materials() -> void:
	for mi in $Art.find_children("*", "MeshInstance3D", true, false):
		var m := _material_for(mi.name)
		if m == null:
			push_warning("forest_ruin_v002: no material for " + mi.name)
			continue
		mi.material_override = m
		var base: String = mi.name.get_slice(".", 0)
		# 小物件、贴地物件不投影：省阴影开销，也避免漏光的细碎阴影
		if base in ["Flowers", "Pebbles", "FallenLeaves", "Runes", "SigilRings", "Stream", "Cascade", "Ground", "PlazaTiles", "LanternGlow", "Mushrooms", "Reeds", "ReedHeads"]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if base in ["Stream", "Cascade"]:
			mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

# ---------------- 草地 ----------------
func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	for b in 7:
		var phi := TAU * b / 7.0 + rng.randf_range(-0.3, 0.3)
		var lean := rng.randf_range(0.08, 0.2); var h := rng.randf_range(0.28, 0.55)
		var side := Vector3(-sin(phi), 0, cos(phi))
		var rows: Array = []
		for s in 4:
			var t := s / 3.0
			var c := Vector3(cos(phi) * (0.03 + lean * t * t), h * t, sin(phi) * (0.03 + lean * t * t))
			var w := 0.032 * (1.0 - 0.9 * t)
			rows.append([c - side * w, c + side * w])
		for s in 3:
			var a: Array = rows[s]; var n: Array = rows[s + 1]
			for v in [a[0], a[1], n[1], a[0], n[1], n[0]]:
				st.set_normal(Vector3.UP); st.add_vertex(v)
	return st.commit()

func _build_grass() -> void:
	var raw := FileAccess.get_file_as_bytes(DATA_DIR + "grass_instances.bin")
	var floats := raw.to_float32_array()
	var count := floats.size() / 6
	var keep := int(count * clampf(grass_density, 0.0, 1.0))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _blade_mesh()
	mm.instance_count = keep
	var step := float(count) / maxf(keep, 1)
	for i in keep:
		var k := int(i * step) * 6
		var basis := Basis(Vector3.UP, floats[k + 3]).scaled(Vector3(floats[k + 4], floats[k + 4] * 1.1, floats[k + 4]))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(floats[k], floats[k + 1] - 0.03, floats[k + 2])))
		mm.set_instance_custom_data(i, Color(floats[k + 5], 0, 0, 0))
	var node := MultiMeshInstance3D.new()
	node.name = "Grass"
	node.multimesh = mm
	node.material_override = _foliage("grass", {"use_texture": false, "grass_mode": true, "backlight": 0.55})
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 70.0
	add_child(node)

# ---------------- 碰撞 ----------------
func _build_collision() -> void:
	var body := StaticBody3D.new(); body.name = "Collision"
	body.collision_layer = 1; body.collision_mask = 0
	add_child(body)
	# 地板：竞技场范围内是平的石板/草地，用一块厚板即可
	var floor_shape := CollisionShape3D.new(); var fb := BoxShape3D.new()
	# 顶面略低于出生点高度（0.12），角色胶囊底部不能与地板重叠，否则出生/追加敌人的空位检查全部失败
	fb.size = Vector3(80, 0.4, 80); floor_shape.shape = fb; floor_shape.position = Vector3(0, -0.26, -1.45)
	body.add_child(floor_shape)
	# 圆形边界：一圈薄盒子
	var center: Vector3 = Vector3(data.plaza_center[0], 0, data.plaza_center[2])
	var segs := 40
	for i in segs:
		var a := TAU * (i + 0.5) / segs
		var cs := CollisionShape3D.new(); var box := BoxShape3D.new()
		box.size = Vector3(TAU * (arena_radius + 0.4) / segs + 0.2, 4.0, 0.8)
		cs.shape = box
		cs.position = center + Vector3(cos(a), 0, sin(a)) * (arena_radius + 0.4) + Vector3.UP * 2.0
		cs.rotation.y = -a + PI / 2
		body.add_child(cs)
	# 中央石台：角色在平面上移动，石台作为中央掩体
	var dais := CollisionShape3D.new(); var dc := CylinderShape3D.new()
	dc.radius = 2.1; dc.height = 2.0; dais.shape = dc; dais.position = center + Vector3.UP
	body.add_child(dais)
	# 竞技场内部的阻挡物：柱子、大石、倒塌柱段
	for b in data.blockers:
		var c := Vector3(b.center[0], b.center[1], b.center[2])
		var flat := Vector2(c.x - center.x, c.z - center.z).length()
		if flat > arena_radius + 1.5: continue
		var cs := CollisionShape3D.new()
		if b.kind == "trunk":
			var cyl := CylinderShape3D.new(); cyl.radius = b.radius; cyl.height = 4.0
			cs.shape = cyl; cs.position = Vector3(c.x, 2.0, c.z)
		else:
			var size := Vector3(b.size[0], b.size[1], b.size[2])
			if size.y < 0.5 and b.kind != "Columns": continue
			var box := BoxShape3D.new(); box.size = Vector3(maxf(size.x * 0.85, 0.3), maxf(size.y, 1.0), maxf(size.z * 0.85, 0.3))
			cs.shape = box; cs.position = Vector3(c.x, maxf(c.y, box.size.y * 0.5), c.z)
		body.add_child(cs)

# ---------------- 灯光 ----------------
func _build_lights() -> void:
	var holder := $Lights
	for l in data.lights:
		var o := OmniLight3D.new()
		o.position = Vector3(l.pos[0], l.pos[1], l.pos[2])
		o.light_color = Color(l.color[0], l.color[1], l.color[2])
		var crystal: bool = l.kind == "crystal"
		o.light_energy = 2.2 if crystal else 1.6
		o.omni_range = 7.0 if crystal else 5.5
		o.omni_attenuation = 1.4
		o.light_volumetric_fog_energy = 1.5
		o.shadow_enabled = false
		holder.add_child(o)
	# 萤火虫：GPU 粒子，在场景四周缓慢漂浮
	var p := GPUParticles3D.new(); p.name = "Fireflies"
	p.amount = 220; p.lifetime = 9.0; p.preprocess = 9.0
	p.visibility_aabb = AABB(Vector3(-40, -2, -50), Vector3(80, 10, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(30, 1.6, 26)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.05; pm.initial_velocity_max = 0.25
	pm.direction = Vector3(0, 1, 0); pm.spread = 180.0
	pm.turbulence_enabled = true; pm.turbulence_noise_strength = 0.6; pm.turbulence_noise_speed_random = 0.4
	var curve := Curve.new(); curve.add_point(Vector2(0, 0)); curve.add_point(Vector2(0.2, 1)); curve.add_point(Vector2(0.8, 1)); curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new(); ct.curve = curve; pm.scale_curve = ct
	p.process_material = pm
	p.position = Vector3(0, 1.8, -4)
	var q := QuadMesh.new(); q.size = Vector2(0.09, 0.09)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.albedo_color = Color(1.0, 0.9, 0.5)
	qm.emission_enabled = true; qm.emission = Color(1.0, 0.85, 0.4); qm.emission_energy_multiplier = 6.0
	var g := GradientTexture2D.new(); g.fill = GradientTexture2D.FILL_RADIAL; g.fill_from = Vector2(0.5, 0.5); g.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new(); grad.set_color(0, Color(1, 1, 1, 1)); grad.set_color(1, Color(1, 1, 1, 0)); g.gradient = grad
	qm.albedo_texture = g
	q.material = qm; p.draw_pass_1 = q
	add_child(p)
