extends Control
## Offers remain owned by the application. This modal only presents and chooses.
signal choice_requested(offer_id: String, choice_id: String)

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
var _cards: HBoxContainer
var _error: Label
var _error_key := ""

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
	var shade := ColorRect.new()
	shade.color = CardSkin.overlay_color
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body = Control.new()
	_body.name = "CardCanvas"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size = CardSkin.canvas_size
	add_child(_body)
	_title = _canvas_label("Heading", CardSkin.heading_rect, CardSkin.heading_font_size, CardSkin.gold_color)
	_title.theme_type_variation = &"Title"
	_subtitle = _canvas_label("Subtitle", CardSkin.subtitle_rect, CardSkin.subtitle_font_size, CardSkin.muted_color)
	_cards = HBoxContainer.new()
	_cards.name = "Cards"
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.add_theme_constant_override("separation", int(CardSkin.card_gap))
	_body.add_child(_cards)
	_error = _canvas_label("Error", CardSkin.error_rect, CardSkin.subtitle_font_size, Style.error_color)
	resized.connect(_layout)
	dismiss()
	refresh_text()

## heading: title/subtitle keys; awakening has a distinct heading.
func show_offer(offer: Dictionary, selections: Array, heading: Array = ["build.title", "build.subtitle"]) -> void:
	assert(_catalog != null and heading.size() == 2)
	_heading = heading.duplicate()
	assert(offer.has("id") and offer.has("candidates") and offer.has("resolved"))
	assert(not bool(offer["resolved"]))
	_offer = offer.duplicate(true)
	_selections = selections.duplicate(true)
	_bindings.clear()
	_error_key = ""
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	buttons.clear()
	for candidate in _offer["candidates"]:
		_bindings[candidate.choice_id] = candidate
		_add_card(String(candidate.choice_id))
	_confine_card_focus()
	visible = not buttons.is_empty()
	refresh_text()
	_layout.call_deferred()
	if not buttons.is_empty():
		buttons.values()[0].grab_focus.call_deferred()

func dismiss() -> void:
	hide()
	_offer.clear()
	_error_key = ""

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
	buttons[id] = button

func _request_choice(id: String) -> void:
	if visible and _offer.has("id") and buttons.has(id):
		choice_requested.emit(String(_offer["id"]), id)


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
	_body.scale = Vector2.ONE * maxf(factor, 0.01)
	_body.position = (size - CardSkin.canvas_size * factor) / 2.0
	var width: float = CardSkin.card_size.x * buttons.size() + CardSkin.card_gap * maxi(0, buttons.size() - 1)
	_cards.position = Vector2((CardSkin.canvas_size.x - width) / 2.0, CardSkin.cards_top)
	_cards.size = Vector2(width, CardSkin.card_size.y)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		accept_event()
