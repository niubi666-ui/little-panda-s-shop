extends Node
## 纯表现的战斗反馈：受伤屏幕闪红、低血量脉动、击杀花瓣、闪避尘土、底部生命条。
## 只读取战斗状态，不改任何规则；删掉本节点不影响判定。
const Vitals = preload("res://presentation/combat/vitals_hud.gd")
const HURT_SHADER := preload("res://presentation/combat/fx/hurt_vignette.gdshader")

@export var hurt_fade_sec := 0.45
@export var low_health_ratio := 0.3
@export var kill_petals := 28
@export var petal_color_a := Color(0.96, 0.52, 0.7)
@export var petal_color_b := Color(1.0, 0.86, 0.9)

var player
var vitals: Control
var _world: Node3D
var _overlay: ColorRect
var _hurt := 0.0
var _clock := 0.0
var _was_dodging := false
var _petal_texture: Texture2D
var _puff_texture: Texture2D

func configure(player_actor, ui: CanvasLayer, theme: Theme, world: Node3D) -> void:
	player = player_actor
	_world = world
	_overlay = ColorRect.new()
	_overlay.name = "HurtVignette"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = HURT_SHADER
	_overlay.material = material
	ui.add_child(_overlay)
	ui.move_child(_overlay, 0)
	vitals = Vitals.new()
	vitals.name = "Vitals"
	ui.add_child(vitals)
	ui.move_child(vitals, 1)
	vitals.configure(player, theme)
	_petal_texture = _radial(Color.WHITE, 0.72)
	_puff_texture = _radial(Color.WHITE, 0.0)

func _radial(color: Color, solid: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, solid, 1.0]) if solid > 0.0 else PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([color, color, Color(color, 0.0)]) if solid > 0.0 else PackedColorArray([color, Color(color, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture

func player_hurt() -> void:
	_hurt = 1.0

func enemy_killed(actor) -> void:
	if not is_instance_valid(actor) or _world == null: return
	_burst(actor.global_position + Vector3.UP * 0.9)

## real_delta：真实帧时间；暂停时传 0，所有反馈原地冻结。
func refresh(real_delta: float) -> void:
	_clock += real_delta
	_hurt = maxf(0.0, _hurt - real_delta / hurt_fade_sec)
	var ratio: float = player.health.current / player.health.maximum
	var low := 0.0
	if player.health.alive() and ratio < low_health_ratio:
		low = (1.0 - ratio / low_health_ratio) * (0.55 + 0.45 * sin(_clock * 5.0))
	_overlay.material.set_shader_parameter("strength", clampf(_hurt * _hurt + low * 0.5, 0.0, 1.0))
	var dodging: bool = player.dodge_left > 0.0
	if dodging and not _was_dodging: _puff(player.global_position, -player.dodge_direction)
	_was_dodging = dodging
	for child in get_children():
		if child is CPUParticles3D: child.speed_scale = 1.0 if real_delta > 0.0 else 0.0
	vitals.refresh(real_delta)

func set_vitals_visible(shown: bool) -> void:
	vitals.visible = shown

func _particles(amount: int, lifetime: float, at: Vector3) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	add_child(particles)
	particles.global_position = at
	particles.finished.connect(particles.queue_free)
	return particles

func _quad(size: Vector2, texture: Texture2D) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.albedo_texture = texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	return quad

func _burst(at: Vector3) -> void:
	# 击杀：一蓬樱花瓣炸开再飘落
	var particles := _particles(kill_petals, 1.1, at)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.35
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 5.5
	particles.gravity = Vector3(0.4, -4.5, 0)
	particles.damping_min = 2.5
	particles.damping_max = 4.0
	particles.angle_min = -180.0
	particles.angle_max = 180.0
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.5
	var tones := Gradient.new()
	tones.set_color(0, petal_color_a)
	tones.set_color(1, petal_color_b)
	particles.color_initial_ramp = tones
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	particles.color_ramp = fade
	particles.mesh = _quad(Vector2(0.16, 0.1), _petal_texture)
	particles.emitting = true

func _puff(at: Vector3, away: Vector3) -> void:
	# 闪避起步：脚下一团尘土向后散开
	var particles := _particles(9, 0.38, at + Vector3.UP * 0.12)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.18
	particles.direction = (away + Vector3.UP * 0.35).normalized() if not away.is_zero_approx() else Vector3.UP
	particles.spread = 55.0
	particles.initial_velocity_min = 1.2
	particles.initial_velocity_max = 3.0
	particles.gravity = Vector3(0, 0.6, 0)
	particles.damping_min = 4.0
	particles.damping_max = 6.0
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.6
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.4))
	particles.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.95, 0.9, 0.55))
	fade.set_color(1, Color(1.0, 0.95, 0.9, 0.0))
	particles.color_ramp = fade
	particles.mesh = _quad(Vector2(0.5, 0.5), _puff_texture)
	particles.emitting = true
