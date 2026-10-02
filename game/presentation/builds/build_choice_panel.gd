extends Control
## The application owns offers and commits. This view only requests a choice.
signal choice_requested(offer_id: String, upgrade_id: String)

const Style = preload("res://presentation/builds/build_ui_style.tres")
var buttons: Dictionary = {}
var _catalog
var _offer: Dictionary = {}
var _ranks: Dictionary = {}
var _body: VBoxContainer
var _title: Label
var _subtitle: Label
var _cards: HBoxContainer
var _error: Label
var _error_key := ""
var _card_text: Dictionary = {}


func configure(catalog, shared_theme: Theme) -> void:
	assert(catalog != null and shared_theme != null)
	_catalog = catalog
	theme = shared_theme
	name = "BuildChoicePanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Style.overlay_color
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body = VBoxContainer.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_constant_override("separation", Style.gap)
	add_child(_body)
	_title = _label(_body, &"Title", Style.gold_color)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle = _label(_body, &"Muted", Style.muted_color)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cards = HBoxContainer.new()
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.add_theme_constant_override("separation", Style.gap)
	_body.add_child(_cards)
	_error = _label(_body, &"Muted", Style.error_color)
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resized.connect(_layout)
	_body.minimum_size_changed.connect(_layout.call_deferred)
	dismiss()
	refresh_text()


func show_offer(offer: Dictionary, ranks: Dictionary) -> void:
	assert(_catalog != null)
	assert(offer.has("id") and offer.has("candidates") and offer.has("resolved"))
	assert(not bool(offer["resolved"]))
	_offer = offer.duplicate(true)
	_ranks = ranks.duplicate(true)
	_error_key = ""
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	buttons.clear()
	_card_text.clear()
	for candidate in _offer["candidates"]:
		_add_card(String(candidate))
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
	_title.text = tr("build.title")
	_subtitle.text = tr("build.subtitle")
	_error.text = tr(_error_key) if not _error_key.is_empty() else ""
	_error.visible = not _error_key.is_empty()
	for id in _card_text:
		var entry: Dictionary = _catalog.upgrade(id)
		var next_rank: int = int(_ranks[id]) + 1 if _ranks.has(id) else 1
		assert(next_rank <= int(entry["max_rank"]))
		var params: Dictionary = entry["ranks"][next_rank - 1].duplicate(true)
		if entry.effect_type == "status":
			var definition: Dictionary = _catalog.status(params.status_id)
			var bonus := 0.0
			for owned_id in _ranks:
				var owned: Dictionary = _catalog.upgrade(owned_id)
				if owned.effect_type == "status_duration":
					var owned_params: Dictionary = owned.ranks[int(_ranks[owned_id]) - 1]
					if owned_params.status_id == params.status_id: bonus += float(owned_params.bonus)
			params.duration_sec = _display_decimal(minf(definition.max_duration_sec, definition.duration_sec * (1.0 + bonus)))
			params.slow_percent = _display_decimal((1.0 - float(definition.move_scale)) * 100.0)
		params["rank"] = next_rank
		params["max_rank"] = int(entry["max_rank"])
		for key in ["jumps", "count", "max_generation"]:
			if params.has(key):
				params[key] = int(params[key])
		if params.has("bonus"):
			params["bonus_percent"] = _display_decimal(float(params["bonus"]) * 100.0)
		if params.has("damage_ratio"):
			params["damage_percent"] = _display_decimal(float(params["damage_ratio"]) * 100.0)
		if params.has("falloff"):
			params["falloff_percent"] = _display_decimal(float(params["falloff"]) * 100.0)
		for key in ["radius_m", "speed_mps", "lifetime_sec", "spread_deg"]:
			if params.has(key):
				params[key] = _display_decimal(float(params[key]))
		var labels: Dictionary = _card_text[id]
		labels["name"].text = tr(entry["name_key"])
		labels["rank"].text = tr("build.rank").format(params)
		labels["description"].text = tr(entry["description_key"]).format(params)
		labels["next"].text = tr("build.next").format(params)
		labels["choose"].text = tr("build.choose")
		buttons[id].tooltip_text = tr(entry["name_key"]) + "\n" + labels["description"].text
	_layout.call_deferred()


func _display_decimal(value: float) -> String:
	var text := String.num(value, 2)
	if text.contains("."):
		while text.ends_with("0"):
			text = text.trim_suffix("0")
		text = text.trim_suffix(".")
	return text


func _add_card(id: String) -> void:
	var button := Button.new()
	button.name = "Upgrade_" + id
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", Style.card_normal)
	button.add_theme_stylebox_override("hover", Style.card_hover)
	button.add_theme_stylebox_override("pressed", Style.card_pressed)
	button.add_theme_stylebox_override("focus", Style.card_focus)
	button.pressed.connect(_request_choice.bind(id))
	_cards.add_child(button)
	buttons[id] = button
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(edge, Style.card_padding)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", Style.gap)
	margin.add_child(stack)
	var rank_label := _label(stack, &"Muted", Style.muted_color)
	var title_label := _label(stack, &"PaperHeading", Style.gold_color)
	title_label.custom_minimum_size.y = Style.title_min_height
	var paper := PanelContainer.new()
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paper.add_theme_stylebox_override("panel", Style.paper)
	stack.add_child(paper)
	var paper_stack := VBoxContainer.new()
	paper_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper_stack.add_theme_constant_override("separation", Style.gap)
	paper.add_child(paper_stack)
	var next_label := _label(paper_stack, &"Muted", Style.paper_text_color)
	var description := _label(paper_stack, &"PaperLabel", Style.paper_text_color)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var choose_label := _label(stack, &"PaperHeading", Style.gold_color)
	choose_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choose_label.custom_minimum_size.y = Style.action_min_height
	_card_text[id] = {"name": title_label, "rank": rank_label, "next": next_label, "description": description, "choose": choose_label}


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


func _label(parent: Node, variation: StringName, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = variation
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _layout() -> void:
	if _body == null or size.x <= 0.0:
		return
	var width: float = minf(Style.content_width, maxf(0.0, size.x - Style.outer_margin * 2.0))
	_body.custom_minimum_size.x = width
	_body.size.x = width
	if not buttons.is_empty():
		var card_width: float = maxf(0.0, (width - Style.gap * (buttons.size() - 1)) / buttons.size())
		var card_height: float = minf(Style.card_height, maxf(0.0, size.y - Style.vertical_reserved))
		for button in buttons.values():
			button.custom_minimum_size = Vector2(card_width, card_height)
	_body.reset_size()
	_body.position = (size - _body.size) / 2.0


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		accept_event()
