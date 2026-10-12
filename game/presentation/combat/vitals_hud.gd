extends Control
## 战斗生命条：屏幕下方居中，生命 + 延迟掉血 + 闪避次数 + 技能冷却。只读玩家状态。
@export var bar_size := Vector2(320, 18)
@export var bottom_margin := 54.0
@export var health_color := Color(0.42, 0.86, 0.6)
@export var low_color := Color(0.95, 0.32, 0.3)
@export var trail_color := Color(1.0, 0.93, 0.8)
@export var frame_color := Color(0.82, 0.68, 0.38)
@export var back_color := Color(0.05, 0.1, 0.08, 0.82)
@export var pip_color := Color(0.98, 0.82, 0.42)
@export var trail_delay_sec := 0.35
@export var trail_speed := 0.6

var player
var _font: Font
var _trail := 1.0
var _shown := 1.0
var _delay := 0.0
var _flash := 0.0
var _skill_total := 0.0
var _clock := 0.0

func configure(player_actor, theme: Theme) -> void:
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
		_delay = trail_delay_sec
		_flash = 1.0
	_shown = ratio
	_trail = maxf(_trail, ratio)
	if _delay > 0.0: _delay -= delta
	else: _trail = move_toward(_trail, ratio, trail_speed * delta)
	_flash = maxf(0.0, _flash - delta * 4.0)
	var cooldown: float = player.runner.cooldown_for("skill")
	_skill_total = maxf(_skill_total, cooldown) if cooldown > 0.0 else 0.0
	queue_redraw()

func _box(rect: Rect2, color: Color, radius: float, border := 0.0, border_color := Color.TRANSPARENT) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	if border > 0.0:
		style.set_border_width_all(int(border))
		style.border_color = border_color
	draw_style_box(style, rect)

func _draw() -> void:
	if player == null: return
	var origin := Vector2((size.x - bar_size.x) / 2.0, size.y - bottom_margin - bar_size.y)
	var frame := Rect2(origin - Vector2(4, 4), bar_size + Vector2(8, 8))
	_box(Rect2(frame.position + Vector2(0, 3), frame.size), Color(0, 0, 0, 0.35), 9)
	_box(frame, back_color, 9, 2, frame_color)
	var inner := Rect2(origin, bar_size)
	if _trail > 0.0:
		_box(Rect2(inner.position, Vector2(inner.size.x * _trail, inner.size.y)), Color(trail_color, 0.85), 5)
	var low := _shown < 0.3
	var fill: Color = low_color if low else health_color
	if low: fill = fill.lerp(Color.WHITE, 0.25 * (0.5 + 0.5 * sin(_clock * 9.0)))
	fill = fill.lerp(Color.WHITE, _flash * 0.7)
	if _shown > 0.0:
		_box(Rect2(inner.position, Vector2(maxf(inner.size.x * _shown, 6.0), inner.size.y)), fill, 5)
		# 顶部一道高光，让条有体积
		draw_rect(Rect2(inner.position + Vector2(3, 2), Vector2(maxf(inner.size.x * _shown - 6.0, 0.0), 4)), Color(1, 1, 1, 0.22))
	var text := "%d / %d" % [ceili(player.health.current), ceili(player.health.maximum)]
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	var text_at := inner.position + Vector2((inner.size.x - text_size.x) / 2.0, inner.size.y - 4.0)
	draw_string_outline(_font, text_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0.03, 0.06, 0.05, 0.9))
	draw_string(_font, text_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.98, 0.92))
	# 闪避次数：条下方的小格；正在回充的那一格显示进度
	if player.dodge != null:
		var pip := Vector2(34, 7)
		var gap := 6.0
		var total: int = player.dodge.charges
		var row := Vector2(origin.x, origin.y + bar_size.y + 9.0)
		for index in total:
			var rect := Rect2(row + Vector2(index * (pip.x + gap), 0), pip)
			_box(rect, back_color, 3, 1, Color(frame_color, 0.7))
			var amount := 1.0 if index < player.charges else 0.0
			if index == player.charges and player.dodge.recharge > 0.0:
				amount = clampf(1.0 - player.recharge_left / player.dodge.recharge, 0.0, 1.0)
			if amount > 0.0:
				var color: Color = pip_color if index < player.charges else Color(pip_color, 0.45)
				_box(Rect2(rect.position + Vector2(1, 1), Vector2((rect.size.x - 2) * amount, rect.size.y - 2)), color, 2)
	# 技能冷却：条右下方的一格，标 Q
	var skill := Rect2(Vector2(origin.x + bar_size.x - 64.0, origin.y + bar_size.y + 9.0), Vector2(64, 7))
	_box(skill, back_color, 3, 1, Color(frame_color, 0.7))
	var cooldown: float = player.runner.cooldown_for("skill")
	var ready := 1.0 if _skill_total <= 0.0 else clampf(1.0 - cooldown / _skill_total, 0.0, 1.0)
	_box(Rect2(skill.position + Vector2(1, 1), Vector2((skill.size.x - 2) * ready, skill.size.y - 2)), Color(0.55, 0.85, 1.0) if ready >= 1.0 else Color(0.55, 0.85, 1.0, 0.45), 2)
	draw_string_outline(_font, skill.position + Vector2(-16, 9), "Q", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0.03, 0.06, 0.05, 0.9))
	draw_string(_font, skill.position + Vector2(-16, 9), "Q", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.93, 1.0))
