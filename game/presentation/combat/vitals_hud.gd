extends Control
## 战斗生命条：屏幕下方居中，生命 + 延迟掉血 + 闪避次数 + 技能冷却。只读玩家状态。
## 样式全部在 juice/vitals_hud_style.tres；技能键位文字按当前 InputMap 生成。
const VitalsStyle = preload("res://presentation/combat/juice/vitals_hud_style.gd")
const SkillText = preload("res://presentation/combat/skill_cooldown_text.gd")

var style: VitalsStyle
var player
var _font: Font
var _trail := 1.0
var _shown := 1.0
var _delay := 0.0
var _flash := 0.0
var _skill_total := 0.0
var _clock := 0.0

func configure(player_actor, theme: Theme, settings: VitalsStyle) -> void:
	assert(settings != null, "vitals style missing")
	style = settings
	player = player_actor
	_font = theme.default_font if theme != null else ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shown = player.health.current / player.health.maximum
	_trail = _shown

func refresh(delta: float) -> void:
	_clock += delta
	var ratio: float = clampf(player.health.current / player.health.maximum, 0.0, 1.0)
	if ratio < _shown - 0.0001:
		_delay = style.trail_delay_sec
		_flash = 1.0
	_shown = ratio
	_trail = maxf(_trail, ratio)
	if _delay > 0.0: _delay -= delta
	else: _trail = move_toward(_trail, ratio, style.trail_speed * delta)
	_flash = maxf(0.0, _flash - delta * style.damage_flash_decay)
	var cooldown: float = player.runner.cooldown_for("skill")
	_skill_total = maxf(_skill_total, cooldown) if cooldown > 0.0 else 0.0
	queue_redraw()

func _box(rect: Rect2, color: Color, radius: int, border := 0, border_color := Color.TRANSPARENT) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	if border > 0:
		box.set_border_width_all(border)
		box.border_color = border_color
	draw_style_box(box, rect)

func _text(at: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, style.outline_size, style.outline_color)
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	if player == null: return
	var bar_size := style.bar_size
	var origin := Vector2((size.x - bar_size.x) / 2.0, size.y - style.bottom_margin - bar_size.y)
	var pad := Vector2.ONE * style.frame_padding
	var frame := Rect2(origin - pad, bar_size + pad * 2.0)
	_box(Rect2(frame.position + style.shadow_offset, frame.size), style.shadow_color, style.frame_radius)
	_box(frame, style.back_color, style.frame_radius, style.frame_border, style.frame_color)
	var inner := Rect2(origin, bar_size)
	if _trail > 0.0:
		_box(Rect2(inner.position, Vector2(inner.size.x * _trail, inner.size.y)), style.trail_color, style.bar_radius)
	var low := _shown < style.low_health_ratio
	var fill: Color = style.low_color if low else style.health_color
	if low: fill = fill.lerp(Color.WHITE, style.low_pulse_whiten * (0.5 + 0.5 * sin(_clock * style.low_pulse_speed)))
	fill = fill.lerp(Color.WHITE, _flash * style.damage_flash_whiten)
	if _shown > 0.0:
		_box(Rect2(inner.position, Vector2(maxf(inner.size.x * _shown, style.min_fill_px), inner.size.y)), fill, style.bar_radius)
		# 顶部一道高光，让条有体积
		var inset := style.highlight_inset
		draw_rect(Rect2(inner.position + inset, Vector2(maxf(inner.size.x * _shown - inset.x * 2.0, 0.0), style.highlight_height)), style.highlight_color)
	var text := "%d / %d" % [ceili(player.health.current), ceili(player.health.maximum)]
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, style.font_size)
	_text(inner.position + Vector2((inner.size.x - text_size.x) / 2.0, inner.size.y - style.text_baseline_inset), text, style.font_size, style.text_color)
	var row_y := origin.y + bar_size.y + style.row_gap
	var slot_border := Color(style.frame_color, style.frame_color.a * 0.7)
	# 闪避次数：条下方的小格；正在回充的那一格显示进度
	if player.dodge != null:
		var pip := style.pip_size
		var total: int = player.dodge.charges
		for index in total:
			var rect := Rect2(Vector2(origin.x + index * (pip.x + style.pip_gap), row_y), pip)
			_box(rect, style.back_color, style.pip_radius, 1, slot_border)
			var amount := 1.0 if index < player.charges else 0.0
			if index == player.charges and player.dodge.recharge > 0.0:
				amount = clampf(1.0 - player.recharge_left / player.dodge.recharge, 0.0, 1.0)
			if amount > 0.0:
				var color: Color = style.pip_color if index < player.charges else Color(style.pip_color, style.pip_charging_alpha)
				_box(Rect2(rect.position + Vector2.ONE, Vector2((rect.size.x - 2.0) * amount, rect.size.y - 2.0)), color, maxi(style.pip_radius - 1, 0))
	# 技能冷却：条右下方的一格，左侧标出当前键位
	var skill := Rect2(Vector2(origin.x + bar_size.x - style.skill_size.x, row_y), style.skill_size)
	_box(skill, style.back_color, style.pip_radius, 1, slot_border)
	var cooldown: float = player.runner.cooldown_for("skill")
	var ready := 1.0 if _skill_total <= 0.0 else clampf(1.0 - cooldown / _skill_total, 0.0, 1.0)
	var skill_fill: Color = style.skill_color if ready >= 1.0 else Color(style.skill_color, style.skill_charging_alpha)
	_box(Rect2(skill.position + Vector2.ONE, Vector2((skill.size.x - 2.0) * ready, skill.size.y - 2.0)), skill_fill, maxi(style.pip_radius - 1, 0))
	var label := SkillText.binding_label()
	var label_size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, style.skill_label_font_size)
	var label_at := Vector2(skill.position.x - style.skill_label_gap - label_size.x, skill.position.y + (skill.size.y + label_size.y) / 2.0 - _font.get_descent(style.skill_label_font_size))
	_text(label_at, label, style.skill_label_font_size, style.skill_label_color)
