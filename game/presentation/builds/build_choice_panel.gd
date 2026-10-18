extends Control
## Offers remain owned by the application. This modal only presents and chooses.
signal choice_requested(offer_id: String, choice_id: String)
## 给音效用：一张卡飞入落定、选中的卡换了一张
signal card_dealt(index: int)
signal card_focused(index: int)

const Style = preload("res://presentation/builds/build_ui_style.tres")
const CardSkin = preload("res://presentation/builds/build_card_skin.tres")
const Art = preload("res://presentation/builds/build_card_art_library.tres")
const CardView = preload("res://presentation/builds/build_card_view.gd")
var buttons: Dictionary = {}
var _catalog
var _offer: Dictionary = {}
var _selections: Array = []
var _bindings: Dictionary = {}
var _body: Control
var _title: Label
var _heading: Array = ["build.title", "build.subtitle"]
var _subtitle: Label
var _cards: Control
var _error: Label
var _error_key := ""
var _shade: ColorRect
## 弹出/关闭的进度（背景模糊、标题）；关闭动画期间面板仍可见但不再接受输入
var _open := 0.0
var _closing := false
var _tween: Tween
var _accept_at_msec := 0
var _requested_id := ""
var _focused_id := ""
var _queued: Array = []   # 关闭动画还没放完时到来的下一组 [offer, selections, heading]

func configure(catalog, shared_theme: Theme) -> void:
	assert(catalog != null and shared_theme != null)
	_catalog = catalog
	for entry in catalog.entries():
		assert(Art.cards.has(entry.id), "Card art catalog is incomplete: " + entry.id)
	theme = shared_theme
	name = "BuildChoicePanel"
	z_index = CardSkin.overlay_z_index
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade = ColorRect.new()
	_shade.name = "Backdrop"
	_shade.color = CardSkin.overlay_color
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop := ShaderMaterial.new()
	backdrop.shader = CardSkin.backdrop_shader
	backdrop.set_shader_parameter("blur_lod", CardSkin.backdrop_blur_lod)
	backdrop.set_shader_parameter("tint", CardSkin.backdrop_tint)
	backdrop.set_shader_parameter("vignette", CardSkin.backdrop_vignette)
	_shade.material = backdrop
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body = Control.new()
	_body.name = "CardCanvas"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size = CardSkin.canvas_size
	add_child(_body)
	_title = _canvas_label("Heading", CardSkin.heading_rect, CardSkin.heading_font_size, CardSkin.gold_color)
	_title.theme_type_variation = &"Title"
	_subtitle = _canvas_label("Subtitle", CardSkin.subtitle_rect, CardSkin.subtitle_font_size, CardSkin.muted_color)
	_cards = Control.new()
	_cards.name = "Cards"
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_cards)
	_error = _canvas_label("Error", CardSkin.error_rect, CardSkin.subtitle_font_size, Style.error_color)
	resized.connect(_layout)
	_finish_close()
	refresh_text()

## heading: title/subtitle keys; awakening has a distinct heading.
func show_offer(offer: Dictionary, selections: Array, heading: Array = ["build.title", "build.subtitle"]) -> void:
	assert(_catalog != null and heading.size() == 2)
	assert(offer.has("id") and offer.has("candidates") and offer.has("resolved"))
	assert(not bool(offer["resolved"]))
	if _closing:
		# 上一张卡的选中动画放完再弹下一组；期间游戏仍算“在选择中”
		_queued = [offer, selections, heading]
		return
	_present(offer, selections, heading)

## 正在等玩家选择（关闭动画期间不算，除非后面还排着下一组）。
func is_open() -> bool:
	return visible and (not _closing or not _queued.is_empty())

## 弹出动画放完、可以选了
func accepting() -> bool:
	return is_open() and not _closing and Time.get_ticks_msec() >= _accept_at_msec

func _present(offer: Dictionary, selections: Array, heading: Array) -> void:
	_heading = heading.duplicate()
	_offer = offer.duplicate(true)
	_selections = selections.duplicate(true)
	_bindings.clear()
	_error_key = ""
	_clear_cards()
	for candidate in _offer["candidates"]:
		_bindings[candidate.choice_id] = candidate
		_add_card(String(candidate.choice_id))
	_confine_card_focus()
	_closing = false
	_requested_id = ""
	_focused_id = ""
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = not buttons.is_empty()
	refresh_text()
	_layout()
	if visible:
		# 卡面插图在这一帧才加载，这一帧会卡一下；从下一帧再开始动画，免得开头被这一下吞掉
		if _tween != null and _tween.is_valid(): _tween.kill()
		_set_open(0.0)
		for card in buttons.values(): card.appear = 0.0
		_accept_at_msec = Time.get_ticks_msec() + int(CardSkin.input_lock_sec * 1000.0)
		if not get_tree().process_frame.is_connected(_play_open):
			get_tree().process_frame.connect(_play_open, CONNECT_ONE_SHOT)

## 选中后由应用调用：被选的卡放大闪光上升，其余下沉，背景恢复；放完才真正隐藏。
func dismiss() -> void:
	_offer.clear()
	_error_key = ""
	if not visible or _closing:
		return
	_closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for card in buttons.values():
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.release_focus()
	_restart_tween()
	var wait := 0.0
	if buttons.has(_requested_id):
		var chosen = buttons[_requested_id]
		_burst(chosen)
		_tween.tween_property(chosen, "picked", 1.0, CardSkin.pick_sec)
		wait = CardSkin.pick_sec * 0.45
	for id in buttons:
		if id != _requested_id:
			_tween.tween_property(buttons[id], "discarded", 1.0, CardSkin.discard_sec).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween.tween_method(_set_open, _open, 0.0, CardSkin.close_sec).set_delay(wait)
	_tween.chain().tween_callback(_finish_close)

func _finish_close() -> void:
	_closing = false
	if not _queued.is_empty():
		var next: Array = _queued
		_queued = []
		_present(next[0], next[1], next[2])
		return
	hide()
	_clear_cards()
	_set_open(0.0)

func _clear_cards() -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	buttons.clear()

func _restart_tween() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	_tween = create_tween().set_parallel(true).set_ignore_time_scale(true)

func _play_open() -> void:
	if not visible or _closing: return
	_restart_tween()
	_tween.tween_method(_set_open, _open, 1.0, CardSkin.open_sec).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var index := 0
	for card in buttons.values():
		card.appear = 0.0
		card.picked = 0.0
		card.discarded = 0.0
		var delay: float = CardSkin.deal_delay_sec + CardSkin.deal_stagger_sec * index
		_tween.tween_property(card, "appear", 1.0, CardSkin.deal_sec).set_delay(delay)
		_tween.tween_callback(card_dealt.emit.bind(index)).set_delay(delay)
		index += 1
	var settled: float = CardSkin.deal_delay_sec + CardSkin.deal_stagger_sec * maxi(0, buttons.size() - 1) + CardSkin.deal_sec
	_accept_at_msec = Time.get_ticks_msec() + int(maxf(CardSkin.input_lock_sec, settled * 0.6) * 1000.0)

func _set_open(value: float) -> void:
	_open = value
	(_shade.material as ShaderMaterial).set_shader_parameter("progress", value)
	var eased := value * value * (3.0 - 2.0 * value)
	for label in [_title, _subtitle]:
		label.modulate.a = eased
	_title.position.y = CardSkin.heading_rect.position.y - CardSkin.heading_drop * (1.0 - eased)
	_subtitle.position.y = CardSkin.subtitle_rect.position.y - CardSkin.heading_drop * 0.6 * (1.0 - eased)

## 选中瞬间从卡中心迸出的光点（稀有度颜色）
func _burst(card: Control) -> void:
	var sparks := CPUParticles2D.new()
	sparks.name = "PickBurst"
	sparks.texture = CardSkin.burst_texture
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = CardSkin.burst_amount
	sparks.lifetime = CardSkin.burst_lifetime
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = CardSkin.card_size * Vector2(0.4, 0.42)
	sparks.direction = Vector2.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = CardSkin.burst_speed.x
	sparks.initial_velocity_max = CardSkin.burst_speed.y
	sparks.gravity = Vector2(0.0, CardSkin.burst_gravity)
	sparks.damping_min = CardSkin.burst_speed.x * 0.8
	sparks.damping_max = CardSkin.burst_speed.x * 1.2
	sparks.scale_amount_min = CardSkin.burst_size.x
	sparks.scale_amount_max = CardSkin.burst_size.y
	var fade := Gradient.new()
	var tone: Color = Art.skin(card.rarity_id).color
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(tone, 0.9), Color(tone, 0.0)])
	fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	sparks.color_ramp = fade
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sparks.material = additive
	_body.add_child(sparks)
	sparks.position = card.home + CardSkin.card_size * 0.5
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)

func set_error(key: String) -> void:
	_error_key = key
	refresh_text()

func refresh_text() -> void:
	if _title == null:
		return
	_title.text = tr("build.card.title") if _heading[0] == "build.title" else tr(_heading[0])
	_subtitle.text = tr("build.card.subtitle") if _heading[1] == "build.subtitle" else tr(_heading[1])
	_error.text = tr(_error_key) if not _error_key.is_empty() else ""
	_error.visible = not _error_key.is_empty()
	for id in buttons:
		var binding: Dictionary = _bindings[id]
		var entry: Dictionary = _catalog.upgrade(binding.upgrade_id)
		var art: Dictionary = Art.card(entry.id)
		var params := _description_params(entry, int(binding.rank), binding.action_id)
		var rarity: String = binding.rarity_id if binding.has("rarity_id") else art.default_rarity
		var description := tr(entry["description_key"]).format(params)
		var operation := tr("build.operation." + binding.operation).format(params)
		operation += " · " + tr("build.rank").format(params)
		if not binding.replaced.is_empty():
			var previous: Dictionary = _catalog.upgrade(binding.replaced.upgrade_id)
			var old_params := _description_params(previous, int(binding.replaced.rank), binding.action_id)
			operation = tr("build.replaces").format({"name": tr(previous.name_key), "rank": int(binding.replaced.rank)})
			description += "\n\n" + tr("build.removed_effect").format({"effect": tr(previous.description_key).format(old_params)})
		buttons[id].set_copy({
			"rarity": tr("build.rarity." + rarity),
			"name": tr(art.title_key),
			"binding": _action_label(binding.action_id),
			"next": operation,
			"headline": tr(art.headline_key).format(params),
			"description": tr(art.body_key).format(params),
			"details": description,
			"choose": tr("build.card.choose"),
		})
	_layout.call_deferred()

func _description_params(entry: Dictionary, rank: int, action_id: String) -> Dictionary:
	var params: Dictionary = entry.ranks[rank - 1].duplicate(true)
	if entry.effect_type in ["status", "area_status"]:
		var definition: Dictionary = _catalog.status(params.status_id)
		var bonus := 0.0
		for selection in _selections:
			if selection.action_id != action_id: continue
			var owned: Dictionary = _catalog.upgrade(selection.upgrade_id)
			if owned.effect_type == "status_duration":
				var owned_params: Dictionary = owned.ranks[int(selection.rank) - 1]
				if owned_params.status_id == params.status_id: bonus += float(owned_params.bonus)
		params.duration_sec = _display_decimal(minf(definition.max_duration_sec, definition.duration_sec * (1.0 + bonus)))
		params.slow_percent = _display_decimal((1.0 - float(definition.move_scale)) * 100.0)
	params.rank = rank
	params.max_rank = int(entry.max_rank)
	for key in ["jumps", "count", "max_generation", "max_hits", "max_targets", "max_per_root", "max_per_parent"]:
		if params.has(key): params[key] = int(params[key])
	for key in ["stacks_per_hit", "spread_stacks"]:
		if params.has(key): params[key] = int(params[key])
	for pair in [["bonus", "bonus_percent"], ["damage_ratio", "damage_percent"], ["falloff", "falloff_percent"], ["add", "add_percent"], ["damage_bonus", "damage_bonus_percent"]]:
		if params.has(pair[0]): params[pair[1]] = _display_decimal(float(params[pair[0]]) * 100.0)
	for key in ["radius_m", "speed_mps", "lifetime_sec", "spread_deg", "add", "radius_bonus_m", "damage", "damage_per_stack"]:
		if params.has(key): params[key] = _display_decimal(float(params[key]))
	return params


func _action_label(action_id: String) -> String:
	var label := tr("build.action." + action_id)
	var input_id: String = {"primary": "combat_attack", "special": "combat_special", "skill": "combat_skill"}.get(action_id, "")
	if input_id.is_empty() or not InputMap.has_action(input_id): return label
	var events := InputMap.action_get_events(input_id)
	if events.is_empty(): return label
	var event: InputEvent = events[0]
	var key := event.as_text()
	if event is InputEventKey:
		key = OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: key = tr("build.input.left_mouse")
		elif event.button_index == MOUSE_BUTTON_RIGHT: key = tr("build.input.right_mouse")
	return tr("build.action_binding").format({"action": label, "key": key})


func _display_decimal(value: float) -> String:
	var text := String.num(value, 2)
	if text.contains("."):
		while text.ends_with("0"):
			text = text.trim_suffix("0")
		text = text.trim_suffix(".")
	return text


func _add_card(id: String) -> void:
	var binding: Dictionary = _bindings[id]
	var art: Dictionary = Art.card(binding.upgrade_id)
	var rarity: String = binding.rarity_id if binding.has("rarity_id") else art.default_rarity
	var button := CardView.new()
	_cards.add_child(button)
	button.configure(binding.upgrade_id, art, rarity, Art.skin(rarity))
	button.name = "Upgrade_" + id
	button.pressed.connect(_request_choice.bind(id))
	button.focus_entered.connect(_on_card_focused.bind(id))
	buttons[id] = button
	var index := buttons.size() - 1
	button.set_hotkey(str(index + 1) if index < 9 else "")

func _on_card_focused(id: String) -> void:
	if _closing or id == _focused_id: return
	_focused_id = id
	card_focused.emit(buttons.keys().find(id))

func _request_choice(id: String) -> void:
	if accepting() and _offer.has("id") and buttons.has(id):
		_requested_id = id
		choice_requested.emit(String(_offer["id"]), id)

func _process(_delta: float) -> void:
	if not visible: return
	var any_active := false
	for card in buttons.values():
		any_active = any_active or card.active()
	for card in buttons.values():
		card.dimmed = any_active


func _confine_card_focus() -> void:
	var ordered: Array = buttons.values()
	for index in ordered.size():
		var button: Button = ordered[index]
		var previous: Button = ordered[posmod(index - 1, ordered.size())]
		var next: Button = ordered[(index + 1) % ordered.size()]
		button.focus_previous = button.get_path_to(previous)
		button.focus_next = button.get_path_to(next)
		button.focus_neighbor_left = button.focus_previous
		button.focus_neighbor_right = button.focus_next
		# Vertical navigation also stays inside the modal's single card row.
		button.focus_neighbor_top = NodePath(".")
		button.focus_neighbor_bottom = NodePath(".")


func _canvas_label(node_name: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_body.add_child(label)
	label.position = rect.position
	label.size = rect.size
	return label

func _layout() -> void:
	if _body == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var available: Vector2 = size - Vector2.ONE * CardSkin.outer_margin * 2.0
	var factor := minf(available.x / CardSkin.canvas_size.x, available.y / CardSkin.canvas_size.y)
	factor = minf(factor, size.y * CardSkin.screen_height_fraction / CardSkin.canvas_size.y)
	_body.scale = Vector2.ONE * maxf(factor, 0.01)
	_body.position = (size - CardSkin.canvas_size * factor) / 2.0
	var width: float = CardSkin.card_size.x * buttons.size() + CardSkin.card_gap * maxi(0, buttons.size() - 1)
	var left := (CardSkin.canvas_size.x - width) / 2.0
	var middle := (buttons.size() - 1) / 2.0
	var index := 0
	for card in buttons.values():
		card.home = Vector2(left + (CardSkin.card_size.x + CardSkin.card_gap) * index, CardSkin.cards_top)
		card.side = signf(index - middle)
		card.size = CardSkin.card_size
		card._animate(0.0)
		index += 1

func _input(event: InputEvent) -> void:
	if not is_open(): return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		return
	# 数字键 1/2/3 直接选
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		var index := -1
		if code >= KEY_1 and code <= KEY_9: index = code - KEY_1
		elif code >= KEY_KP_1 and code <= KEY_KP_9: index = code - KEY_KP_1
		if index >= 0 and index < buttons.size():
			get_viewport().set_input_as_handled()
			var id: String = buttons.keys()[index]
			buttons[id].grab_focus()
			_request_choice(id)
			return
	# 还没有卡被选中时，方向键/确认键先把焦点放到中间那张，而不是直接选
	if get_viewport().gui_get_focus_owner() not in buttons.values():
		for action in ["ui_left", "ui_right", "ui_up", "ui_down", "ui_accept", "ui_focus_next", "ui_focus_prev"]:
			if event.is_action_pressed(action) and not buttons.is_empty():
				buttons.values()[buttons.size() / 2].grab_focus()
				get_viewport().set_input_as_handled()
				return


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		accept_event()
