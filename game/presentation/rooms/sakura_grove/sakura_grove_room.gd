extends "res://rogue/rooms/authored_room.gd"
## 樱花林训练场：接入层。只负责给导入网格配材质，并生成地面、草丛、碰撞、灯光、
## 树影、光柱和飘落的花瓣。不含任何战斗逻辑。
## 美术源文件：source_assets/combat_visual_v1/blender/build_sakura_grove.py（可重跑）。
@export var world_shader: Shader
@export var floor_shader: Shader
@export var ground_shader: Shader
@export var gobo_shader: Shader
@export var shaft_shader: Shader
@export var mood_shader: Shader
## 可行走矩形的半边长（米）；墙体模型的内侧面与此对齐。
@export var play_half := Vector2(9.5, 8.0)
## 石坪顶面高度：角色出生点与之同高。
@export var floor_height := 0.12
## 指向太阳的方向：逆光。太阳在画面左上方的远处，影子朝镜头方向拉长，花枝与角色带亮边。
@export var to_sun := Vector3(-0.55, 0.62, -0.56)
@export_group("氛围")
@export var lantern_energy := 1.6
@export var lantern_range := 6.0
@export var grass_tufts := 5200
@export var falling_petals := 240
## 树影覆盖率：场地中央 / 场地边缘（0 = 无树影，1 = 全阴）
@export var shade_centre := 0.16
@export var shade_edge := 0.6
@export var light_shafts := 9
@export var shaft_intensity := 0.3
## 镜头方向（与 presentation.tres 的 camera_offset 一致），用于让光柱面向镜头
@export var camera_offset := Vector3(0, 17, 17)

var _floor: MeshInstance3D

func rift_surfaces() -> Array:
	return [_floor]

func _ready() -> void:
	to_sun = to_sun.normalized()
	$Lights/Sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	_assign_materials()
	_build_ground()
	_build_grass()
	_build_collision()
	_build_lights()
	_build_canopy_shade()
	_build_light_shafts()
	_build_petals()
	_build_screen_mood()

func _toon(params: Dictionary = {}) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = world_shader
	for key in params: material.set_shader_parameter(key, params[key])
	return material

func _assign_materials() -> void:
	var solid := _toon()
	var blossom := _toon({"sway": 0.1, "sway_height": 7.0, "toon_wrap": 0.55, "toon_soft": 0.4, "translucency": 0.45})
	var leaves := _toon({"sway": 0.04, "sway_height": 2.0, "toon_wrap": 0.35, "toon_soft": 0.35, "translucency": 0.2})
	# 布料是单面片，需要双面可见
	var cloth := StandardMaterial3D.new()
	cloth.vertex_color_use_as_albedo = true
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.roughness = 1.0
	cloth.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var glow := _toon({"emission_strength": 4.0})
	for mesh in $Art.find_children("*", "MeshInstance3D", true, false):
		var id: String = mesh.name
		if id.begins_with("Blossom"): mesh.material_override = blossom
		elif id.begins_with("Leaves"): mesh.material_override = leaves
		elif id.begins_with("Cloth"): mesh.material_override = cloth
		elif id.begins_with("LanternGlow"):
			mesh.material_override = glow
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else: mesh.material_override = solid
		if id.begins_with("Flowers"): mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _plane(id: String, size: Vector2, height: float, shader: Shader, params: Dictionary) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = id
	var mesh := PlaneMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = shader
	for key in params: material.set_shader_parameter(key, params[key])
	node.material_override = material
	node.position.y = height
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _build_ground() -> void:
	var court := play_half + Vector2(0.6, 0.6)
	_floor = _plane("CourtFloor", court * 2.0, floor_height, floor_shader, {"half_extent": court})
	_plane("Ground", Vector2(180, 180), 0.0, ground_shader, {"court_half": court + Vector2(0.3, 0.3)})
	# 石坪的侧沿：把抬高的 12cm 接到草地上
	var skirt := MeshInstance3D.new()
	skirt.name = "CourtSkirt"
	var box := BoxMesh.new()
	box.size = Vector3(court.x * 2.0, floor_height, court.y * 2.0)
	skirt.mesh = box
	skirt.position.y = floor_height / 2.0 - 0.002
	var side := StandardMaterial3D.new()
	side.albedo_color = Color(0.3, 0.3, 0.35)
	side.roughness = 1.0
	skirt.material_override = side
	skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(skirt)

func _tuft_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var base := Color(0.13, 0.27, 0.17)
	var tip := Color(0.42, 0.6, 0.3)
	for blade in 5:
		var angle := TAU * blade / 5.0 + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(angle), 0, sin(angle))
		var side := Vector3(-sin(angle), 0, cos(angle)) * 0.035
		var height := rng.randf_range(0.2, 0.4)
		var root := out * 0.03
		var top := out * rng.randf_range(0.1, 0.2) + Vector3.UP * height
		for vertex in [[root - side, base], [root + side, base], [top, tip]]:
			tool.set_normal(Vector3.UP)
			tool.set_color(vertex[1])
			tool.add_vertex(vertex[0])
	return tool.commit()

func _build_grass() -> void:
	# 草丛只长在石坪外，以及贴墙的石缝里；战斗区中央保持干净。
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261012
	var points: Array[Vector3] = []
	var court := play_half + Vector2(0.9, 0.9)
	var guard := 0
	while points.size() < grass_tufts and guard < grass_tufts * 6:
		guard += 1
		var p := Vector2(rng.randf_range(-30, 30), rng.randf_range(-26, 24))
		var inside := absf(p.x) < court.x and absf(p.y) < court.y
		if inside:
			var border := minf(play_half.x - absf(p.x), play_half.y - absf(p.y))
			if border > 1.4 or border < 0.15 or rng.randf() > 0.1: continue
		elif absf(p.x) < 1.6 and absf(p.y) > court.y: continue   # 入口小路
		points.append(Vector3(p.x, floor_height if inside else 0.0, p.y))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _tuft_mesh()
	multimesh.instance_count = points.size()
	for index in points.size():
		var scale := rng.randf_range(0.7, 1.35)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale, scale * rng.randf_range(0.8, 1.2), scale))
		multimesh.set_instance_transform(index, Transform3D(basis, points[index]))
	var node := MultiMeshInstance3D.new()
	node.name = "GrassTufts"
	node.multimesh = multimesh
	node.material_override = _toon({"sway": 0.05, "sway_height": 0.4, "sway_speed": 2.0})
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	# 地板顶面略低于出生点：角色胶囊底部不能与地板重叠，否则空位检查会失败。
	_add_box(body, Vector3(80, 0.4, 80), Vector3(0, floor_height - 0.38, 0))
	var thickness := 1.2
	_add_box(body, Vector3(thickness, 4.0, play_half.y * 2.0 + thickness * 2.0), Vector3(play_half.x + thickness / 2.0, 2.0, 0))
	_add_box(body, Vector3(thickness, 4.0, play_half.y * 2.0 + thickness * 2.0), Vector3(-play_half.x - thickness / 2.0, 2.0, 0))
	_add_box(body, Vector3(play_half.x * 2.0, 4.0, thickness), Vector3(0, 2.0, play_half.y + thickness / 2.0))
	_add_box(body, Vector3(play_half.x * 2.0, 4.0, thickness), Vector3(0, 2.0, -play_half.y - thickness / 2.0))

func _add_box(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)

func _build_lights() -> void:
	for marker in $Art.find_children("Lantern_*", "Node3D", true, false):
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.72, 0.42)
		light.light_energy = lantern_energy
		light.omni_range = lantern_range
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		$Lights.add_child(light)
		light.global_position = marker.global_position

func _build_canopy_shade() -> void:
	# 只投影、不可见的“头顶花枝”：让阳光成斑驳状洒在地面和角色身上。
	var sheet := MeshInstance3D.new()
	sheet.name = "CanopyShade"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(90, 90)
	sheet.mesh = mesh
	var height := 7.0
	# 挪到太阳一侧，使投影正好覆盖场地
	sheet.position = Vector3(to_sun.x, 0, to_sun.z) / to_sun.y * height + Vector3.UP * height
	var material := ShaderMaterial.new()
	material.shader = gobo_shader
	material.set_shader_parameter("to_sun", to_sun)
	material.set_shader_parameter("court_half", play_half)
	material.set_shader_parameter("cover_centre", shade_centre)
	material.set_shader_parameter("cover_edge", shade_edge)
	sheet.material_override = material
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(sheet)

func _build_light_shafts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var view := -camera_offset.normalized()
	var across := to_sun.cross(view).normalized()
	var holder := Node3D.new()
	holder.name = "LightShafts"
	add_child(holder)
	for index in light_shafts:
		# 光柱偏向场地的受光一侧（太阳所在的左侧与后方），中央留空
		var ground := Vector3(rng.randf_range(-play_half.x * 0.8, play_half.x * 1.1), 0.0, rng.randf_range(-play_half.y * 0.8, play_half.y * 1.1))
		if absf(ground.x) < 3.0 and absf(ground.z) < 2.5: ground.x += 6.0
		var length := rng.randf_range(11.0, 15.0)
		var width := rng.randf_range(1.3, 3.2)
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(width, length)
		quad.mesh = mesh
		# QuadMesh 的 UV.y 自上而下：让上端朝向太阳
		quad.basis = Basis(across, to_sun, across.cross(to_sun))
		quad.position = ground + to_sun * (length * 0.5 - 0.5)
		var material := ShaderMaterial.new()
		material.shader = shaft_shader
		material.set_shader_parameter("intensity", shaft_intensity * rng.randf_range(0.6, 1.2))
		material.set_shader_parameter("phase", rng.randf() * 10.0)
		quad.material_override = material
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(quad)

func _build_petals() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "FallingPetals"
	particles.amount = falling_petals
	particles.lifetime = 11.0
	particles.preprocess = 11.0
	particles.randomness = 1.0
	particles.visibility_aabb = AABB(Vector3(-40, -4, -40), Vector3(80, 20, 80))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(play_half.x + 6.0, 0.6, play_half.y + 5.0)
	process.direction = Vector3(0.9, -0.5, -0.25)
	process.spread = 25.0
	process.initial_velocity_min = 0.5
	process.initial_velocity_max = 1.3
	process.gravity = Vector3(0.22, -0.5, -0.08)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.9
	process.turbulence_noise_scale = 2.4
	process.turbulence_influence_min = 0.05
	process.turbulence_influence_max = 0.18
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -160.0
	process.angular_velocity_max = 160.0
	process.scale_min = 0.6
	process.scale_max = 1.35
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.0))
	fade.add_point(Vector2(0.08, 1.0))
	fade.add_point(Vector2(0.88, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	var fade_texture := CurveTexture.new()
	fade_texture.curve = fade
	process.scale_curve = fade_texture
	var tones := Gradient.new()
	tones.set_color(0, Color(0.95, 0.5, 0.68))
	tones.set_color(1, Color(0.98, 0.8, 0.86))
	var tone_texture := GradientTexture1D.new()
	tone_texture.gradient = tones
	process.color_initial_ramp = tone_texture
	particles.process_material = process
	var petal := QuadMesh.new()
	petal.size = Vector2(0.13, 0.085)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# 椭圆花瓣：径向渐变做透明边
	var shape := Gradient.new()
	shape.offsets = PackedFloat32Array([0.0, 0.72, 1.0])
	shape.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var oval := GradientTexture2D.new()
	oval.gradient = shape
	oval.fill = GradientTexture2D.FILL_RADIAL
	oval.fill_from = Vector2(0.5, 0.5)
	oval.fill_to = Vector2(1.0, 0.5)
	oval.width = 32
	oval.height = 32
	material.albedo_texture = oval
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	petal.material = material
	particles.draw_pass_1 = petal
	particles.position = Vector3(-3.0, 8.5, 2.0)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)

func _build_screen_mood() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ScreenMood"
	layer.layer = 0
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = mood_shader
	rect.material = material
	layer.add_child(rect)
