extends Node
## 纯表现的战斗反馈：受伤屏幕闪红、低血量脉动、击杀爆点、闪避尘土、底部生命条。
## 只读取战斗状态，不改任何规则；删掉本节点不影响判定。
## 所有参数在 juice/combat_juice_style.tres（由 training_style.tres 的 combat_juice 引用），
## 粒子外观在 juice/kill_petals.tscn、juice/dodge_puff.tscn 里调。
const Vitals = preload("res://presentation/combat/vitals_hud.gd")
const JuiceStyle = preload("res://presentation/combat/juice/combat_juice_style.gd")

var style: JuiceStyle
var player
var vitals: Control
var _world: Node3D
var _overlay: ColorRect
var _hurt := 0.0
var _clock := 0.0
var _was_dodging := false
var _labels: Array = []   # [Label3D, 已存在时间]
var _font: Font

func configure(player_actor, ui: CanvasLayer, theme: Theme, world: Node3D, settings: JuiceStyle) -> void:
	assert(settings != null and settings.vignette_material != null and settings.kill_burst != null and settings.dodge_puff != null and settings.vitals != null, "combat juice style incomplete")
	assert(settings.hurt_fade_sec > 0.0)
	style = settings
	player = player_actor
	_world = world
	_overlay = ColorRect.new()
	_overlay.name = "HurtVignette"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 每个场景一份材质实例，strength 是运行时状态
	_overlay.material = style.vignette_material.duplicate()
	ui.add_child(_overlay)
	ui.move_child(_overlay, 0)
	vitals = Vitals.new()
	vitals.name = "Vitals"
	ui.add_child(vitals)
	ui.move_child(vitals, 1)
	vitals.configure(player, theme, style.vitals)
	_font = theme.default_font if theme != null else null

func player_hurt() -> void:
	_hurt = 1.0

func enemy_killed(actor) -> void:
	if not is_instance_valid(actor) or _world == null: return
	_emit(style.kill_burst, actor.global_position + Vector3.UP * style.kill_burst_height_m)

## real_delta：真实帧时间；暂停时传 0，所有反馈原地冻结。
func refresh(real_delta: float) -> void:
	_clock += real_delta
	_hurt = maxf(0.0, _hurt - real_delta / style.hurt_fade_sec)
	var ratio: float = player.health.current / player.health.maximum
	var threshold: float = style.vitals.low_health_ratio
	var low := 0.0
	if player.health.alive() and ratio < threshold:
		var floor_level: float = style.low_pulse_floor
		low = (1.0 - ratio / threshold) * (floor_level + (1.0 - floor_level) * sin(_clock * style.low_pulse_speed))
	_overlay.material.set_shader_parameter("strength", clampf(_hurt * _hurt + low * style.low_vignette_weight, 0.0, 1.0))
	var dodging: bool = player.dodge_left > 0.0
	if dodging and not _was_dodging: _puff(player.global_position, -player.dodge_direction)
	_was_dodging = dodging
	for child in get_children():
		if child is CPUParticles3D: child.speed_scale = 1.0 if real_delta > 0.0 else 0.0
	vitals.refresh(real_delta)
	_tick_labels(real_delta)

## 敌人霸体被打破：头顶弹出提示文字
func guard_broken(actor) -> void:
	if not is_instance_valid(actor) or _world == null: return
	var label := Label3D.new()
	label.text = tr(style.break_label_key)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.pixel_size = 0.01
	label.font_size = style.break_label_font_size
	label.outline_size = maxi(style.break_label_font_size / 6, 1)
	label.modulate = style.break_label_color
	label.outline_modulate = style.break_label_outline
	if _font != null: label.font = _font
	add_child(label)
	label.global_position = actor.global_position + Vector3.UP * style.break_label_height_m
	_labels.append([label, 0.0, label.global_position])

func _tick_labels(real_delta: float) -> void:
	for index in range(_labels.size() - 1, -1, -1):
		var entry: Array = _labels[index]
		entry[1] += real_delta
		var t: float = entry[1] / style.break_label_sec
		if t >= 1.0:
			entry[0].queue_free()
			_labels.remove_at(index)
			continue
		# 先弹大再回落，随后上飘淡出
		var pop := 1.0 + 0.35 * maxf(0.0, 1.0 - t * 6.0)
		entry[0].scale = Vector3.ONE * pop
		entry[0].global_position = entry[2] + Vector3.UP * style.break_label_rise_m * t
		entry[0].modulate.a = 1.0 - smoothstep(0.6, 1.0, t)
		entry[0].outline_modulate.a = entry[0].modulate.a

func set_vitals_visible(shown: bool) -> void:
	vitals.visible = shown

## direction 为零向量时保留场景里配置的喷射方向
func _emit(scene: PackedScene, at: Vector3, direction := Vector3.ZERO) -> void:
	var particles: CPUParticles3D = scene.instantiate()
	if not direction.is_zero_approx(): particles.direction = direction
	add_child(particles)
	particles.global_position = at
	particles.finished.connect(particles.queue_free)
	particles.restart()

func _puff(at: Vector3, away: Vector3) -> void:
	# 闪避起步：脚下一团尘土向闪避反方向散开
	var direction := (away + Vector3.UP * style.dodge_puff_lift).normalized() if not away.is_zero_approx() else Vector3.ZERO
	_emit(style.dodge_puff, at + Vector3.UP * style.dodge_puff_height_m, direction)
