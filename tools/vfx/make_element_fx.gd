extends SceneTree
## 一次性：生成元素特效用的粒子场景到 presentation/builds/elements/，之后在编辑器里调。
const OUT := "res://presentation/builds/elements/"
func _initialize() -> void:
	_save(_status_fire(), "status_fire")
	_save(_status_ice(), "status_ice")
	_save(_status_thunder(), "status_thunder")
	_save(_status_earth(), "status_earth")
	_save(_apply_burst(), "apply_burst")
	_save(_reaction_burst(), "reaction_burst")
	_save(_reaction_smoke(), "reaction_smoke")
	_save(_pull_burst(), "pull_burst")
	_save(_zone_embers(), "zone_embers")
	_save(_blade("BladeFire", Color(1, 0.8, 0.25, 1), Color(1, 0.35, 0.05, 0.95), Color(0.6, 0.08, 0.02, 0), Vector3(0, 1.2, 0), 0.34, true), "blade_fire")
	_save(_blade("BladeIce", Color(0.95, 1, 1, 1), Color(0.55, 0.85, 1, 0.9), Color(0.4, 0.7, 1, 0), Vector3(0, -0.6, 0), 0.24, true), "blade_ice")
	_save(_blade("BladeThunder", Color(1, 1, 1, 1), Color(0.72, 0.64, 1, 0.95), Color(0.5, 0.4, 1, 0), Vector3.ZERO, 0.16, true), "blade_thunder")
	_save(_blade("BladeEarth", Color(0.9, 0.75, 0.5, 1), Color(0.6, 0.44, 0.28, 0.85), Color(0.4, 0.3, 0.2, 0), Vector3(0, -6.0, 0), 0.2, false), "blade_earth")
	quit(0)

func _save(node: Node, name: String) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed, OUT + name + ".tscn") == OK)
	print("saved ", name)
	node.free()

func _radial(solid: float, size := 32) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, solid, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t

func _quad(size: Vector2, additive: bool, solid := 0.2) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive: m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.albedo_texture = _radial(solid)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = m
	return quad

func _ramp(colors: Array, offsets: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g

func _curve(points: Array, max_value := 1.0) -> Curve:
	var c := Curve.new()
	c.min_value = 0.0
	c.max_value = max_value
	for point in points: c.add_point(point)
	return c

func _base(name: String, amount: int, lifetime: float, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = name
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 0.95 if one_shot else 0.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = not one_shot
	return p

func _status_fire() -> CPUParticles3D:
	# 灼烧：身上往上窜的小火苗
	var p := _base("StatusFire", 48, 0.75, false)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.45
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.3
	p.gravity = Vector3(0, 1.6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.scale_amount_curve = _curve([Vector2(0, 1), Vector2(1, 0.2)])
	p.color_ramp = _ramp([Color(1, 0.78, 0.2, 1), Color(1, 0.32, 0.04, 0.95), Color(0.55, 0.04, 0.0, 0)], [0.0, 0.45, 1.0])
	p.mesh = _quad(Vector2(0.36, 0.46), false, 0.35)
	return p

func _status_ice() -> CPUParticles3D:
	# 冰寒：周身慢慢飘落的冰晶闪光
	var p := _base("StatusIce", 30, 1.3, false)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.3
	p.gravity = Vector3(0, -0.35, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.color_ramp = _ramp([Color(0.55, 0.9, 1, 0), Color(0.55, 0.9, 1, 1), Color(0.25, 0.6, 1, 0)], [0.0, 0.2, 1.0])
	p.mesh = _quad(Vector2(0.24, 0.24), false, 0.3)
	return p

func _status_thunder() -> CPUParticles3D:
	# 感电：身上噼啪乱跳的电火花
	var p := _base("StatusThunder", 26, 0.16, false)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.55
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.5
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.randomness = 1.0
	p.color_ramp = _ramp([Color(1, 1, 1, 1), Color(0.7, 0.62, 1, 0.9), Color(0.5, 0.4, 1, 0)], [0.0, 0.4, 1.0])
	p.mesh = _quad(Vector2(0.11, 0.11), false, 0.5)
	return p

func _status_earth() -> CPUParticles3D:
	# 碎甲：身上剥落的碎石与尘土
	var p := _base("StatusEarth", 20, 0.9, false)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0, -4.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.color_ramp = _ramp([Color(0.75, 0.58, 0.38, 1), Color(0.55, 0.4, 0.26, 0.8), Color(0.4, 0.3, 0.2, 0)], [0.0, 0.6, 1.0])
	p.mesh = _quad(Vector2(0.17, 0.17), false, 0.75)
	return p

func _apply_burst() -> CPUParticles3D:
	# 挂上元素的一瞬间：一小簇火花（颜色由代码按元素设置）
	var p := _base("ApplyBurst", 30, 0.4, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.damping_min = 6.0
	p.damping_max = 9.0
	p.gravity = Vector3.ZERO
	p.color_ramp = _ramp([Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 1.0])
	p.mesh = _quad(Vector2(0.26, 0.26), false, 0.4)
	return p

func _reaction_burst() -> CPUParticles3D:
	# 反应爆发：大量向外炸开的亮点（颜色由代码按反应设置）
	var p := _base("ReactionBurst", 70, 0.7, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 9.0
	p.damping_min = 5.0
	p.damping_max = 8.0
	p.gravity = Vector3(0, -2.0, 0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.8
	p.color_ramp = _ramp([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)], [0.0, 0.5, 1.0])
	p.mesh = _quad(Vector2(0.2, 0.2), true, 0.25)
	return p

func _reaction_smoke() -> CPUParticles3D:
	# 反应余烟（蒸汽、尘土）：缓缓上升的大团柔光
	var p := _base("ReactionSmoke", 16, 1.2, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.damping_min = 0.5
	p.damping_max = 1.0
	p.gravity = Vector3(0, 0.4, 0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.scale_amount_curve = _curve([Vector2(0, 0.6), Vector2(1, 2.2)], 3.0)
	p.color_ramp = _ramp([Color(1, 1, 1, 0), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)], [0.0, 0.2, 1.0])
	p.mesh = _quad(Vector2(1.0, 1.0), false, 0.0)
	return p

func _pull_burst() -> CPUParticles3D:
	# 磁暴：从外圈被吸向中心的光点
	var p := _base("PullBurst", 48, 0.45, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 5.0
	p.emission_ring_inner_radius = 4.0
	p.emission_ring_height = 0.6
	p.direction = Vector3.UP
	p.spread = 10.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.3
	p.gravity = Vector3.ZERO
	p.radial_accel_min = -45.0
	p.radial_accel_max = -30.0
	p.color_ramp = _ramp([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 0.3, 1.0])
	p.mesh = _quad(Vector2(0.16, 0.16), true, 0.3)
	return p

func _zone_embers() -> CPUParticles3D:
	# 熔岩区域：地面冒出的余烬
	var p := _base("ZoneEmbers", 26, 1.0, false)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 2.2
	p.emission_ring_inner_radius = 0.0
	p.emission_ring_height = 0.05
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, 0.3, 0)
	p.color_ramp = _ramp([Color(1, 0.85, 0.4, 1), Color(1, 0.4, 0.1, 0.8), Color(0.5, 0.1, 0.02, 0)], [0.0, 0.5, 1.0])
	p.mesh = _quad(Vector2(0.09, 0.09), true, 0.3)
	return p

func _blade(name: String, a: Color, b: Color, c: Color, gravity: Vector3, size: float, additive: bool) -> CPUParticles3D:
	# 剑身元素拖尾：挂在剑上，出招时沿刀锋留下一道元素轨迹
	var p := _base(name, 260, 0.5, false)
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.06, 0.06, 0.6)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 1.2
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.gravity = gravity
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.scale_amount_curve = _curve([Vector2(0, 1), Vector2(1, 0.15)])
	p.color_ramp = _ramp([a, b, c], [0.0, 0.4, 1.0])
	p.mesh = _quad(Vector2(size, size) * 1.6, false, 0.35)
	return p
