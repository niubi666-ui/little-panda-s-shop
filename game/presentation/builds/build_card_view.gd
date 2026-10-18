extends Button
## Runtime assembly: art / text backing / ornament / frame / live labels.
const CardSkin = preload("res://presentation/builds/build_card_skin.tres")
var labels: Dictionary = {}
var art_id := ""
var rarity_id := ""
var art_path := ""
var _frame: TextureRect
var _choose: Panel
var _rarity: Dictionary

func configure(id: String, art: Dictionary, rarity: String, rarity_skin: Dictionary) -> void:
	art_id = id
	rarity_id = rarity
	art_path = art.art
	_rarity = rarity_skin
	name = "Upgrade_" + id
	custom_minimum_size = CardSkin.card_size
	size = CardSkin.card_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	# Focus brightens the illustrated frame and its choice surface, preserving the cutout silhouette.
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var surface := ColorRect.new()
	surface.name = "TextBacking"
	surface.color = CardSkin.body_color
	_add_rect(surface, Rect2(CardSkin.surface_inset, rarity_skin.surface_top,
		CardSkin.card_size.x - CardSkin.surface_inset * 2.0, CardSkin.surface_bottom - rarity_skin.surface_top))
	var illustration := TextureRect.new()
	illustration.name = "Illustration"
	illustration.texture = load(art.art)
	assert(illustration.texture != null, "Missing card illustration " + art.art)
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_add_rect(illustration, Rect2(CardSkin.surface_inset, rarity_skin.surface_top,
		CardSkin.card_size.x - CardSkin.surface_inset * 2.0, CardSkin.art_bottom - rarity_skin.surface_top))
	var fade := TextureRect.new()
	fade.name = "ArtToTextFade"
	fade.texture = CardSkin.fade_texture
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_add_rect(fade, CardSkin.fade_rect)
	var ornament := TextureRect.new()
	ornament.name = "BotanicalOrnament"
	ornament.texture = CardSkin.ornament_texture
	ornament.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ornament.modulate.a = CardSkin.ornament_opacity
	_add_rect(ornament, CardSkin.ornament_rect)
	_frame = TextureRect.new()
	_frame.name = "RarityFrame"
	_frame.texture = rarity_skin.frame
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_add_rect(_frame, Rect2(Vector2.ZERO, CardSkin.card_size))
	labels["rarity"] = _label("RarityText", rarity_skin.label_rect, CardSkin.rarity_font_size, CardSkin.text_color, true)
	labels["name"] = _label("CardTitle", CardSkin.title_rect, CardSkin.title_font_size, CardSkin.text_color, true)
	var binding_panel := Panel.new()
	binding_panel.name = "ActionBadge"
	var badge := StyleBoxFlat.new()
	badge.bg_color = Color(CardSkin.body_color, 0.9)
	badge.border_color = Color(rarity_skin.color, 0.65)
	badge.set_border_width_all(1)
	badge.set_corner_radius_all(int(CardSkin.binding_rect.size.y * 0.5))
	binding_panel.add_theme_stylebox_override("panel", badge)
	_add_rect(binding_panel, CardSkin.binding_rect)
	labels["binding"] = _label("ActionText", CardSkin.binding_rect, CardSkin.binding_font_size, CardSkin.text_color)
	labels["next"] = _label("OperationText", CardSkin.operation_rect, CardSkin.operation_font_size, CardSkin.muted_color)
	labels["headline"] = _label("BenefitText", CardSkin.headline_rect, CardSkin.headline_font_size, rarity_skin.color, true)
	var scroll := ScrollContainer.new()
	scroll.name = "RulesScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scroll)
	scroll.position = CardSkin.description_rect.position
	scroll.size = CardSkin.description_rect.size
	var description := Label.new()
	description.name = "RulesText"
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.add_theme_font_size_override("font_size", CardSkin.description_font_size)
	description.add_theme_color_override("font_color", CardSkin.text_color)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scroll.add_child(description)
	labels["description"] = description
	_choose = Panel.new()
	_choose.name = "ChooseSurface"
	var button_style := StyleBoxTexture.new()
	button_style.texture = CardSkin.button_texture
	for edge in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		button_style.set_texture_margin(edge, CardSkin.button_texture_margin)
	_choose.add_theme_stylebox_override("panel", button_style)
	_add_rect(_choose, CardSkin.choose_rect)
	labels["choose"] = _label("ChooseText", CardSkin.choose_rect, CardSkin.choose_font_size, CardSkin.gold_color, true)
	mouse_entered.connect(_update_emphasis)
	mouse_exited.connect(_update_emphasis)
	focus_entered.connect(_update_emphasis)
	focus_exited.connect(_update_emphasis)
	button_down.connect(_update_emphasis)
	button_up.connect(_update_emphasis)

func set_copy(copy: Dictionary) -> void:
	for key in copy:
		if key == "details": continue
		assert(labels.has(key), "Unknown card text layer: " + key)
		labels[key].text = copy[key]
	_fit_line(labels["name"], CardSkin.title_font_size, CardSkin.title_min_font_size)
	_fit_line(labels["headline"], CardSkin.headline_font_size, CardSkin.headline_min_font_size)
	_fit_line(labels["rarity"], CardSkin.rarity_font_size, CardSkin.small_label_min_font_size)
	_fit_line(labels["binding"], CardSkin.binding_font_size, CardSkin.small_label_min_font_size)
	_fit_line(labels["next"], CardSkin.operation_font_size, CardSkin.small_label_min_font_size)
	tooltip_text = copy["name"] + "\n" + copy["binding"] + "\n" + copy["next"] + "\n" + copy["details"]

func _fit_line(label: Label, preferred: int, smallest: int) -> void:
	var font := label.get_theme_font("font")
	var font_size := preferred
	while font_size > smallest and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > label.size.x:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)

func _label(node_name: String, rect: Rect2, font_size: int, color: Color, heading: bool = false) -> Label:
	var label := Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if heading:
		label.theme_type_variation = &"PaperHeading"
	_add_rect(label, rect)
	return label

func _add_rect(control: Control, rect: Rect2) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(control)
	control.position = rect.position
	control.size = rect.size

func _update_emphasis() -> void:
	var active := is_hovered() or has_focus()
	var brightness: float = CardSkin.hover_brightness if active else 1.0
	_frame.modulate = Color(brightness, brightness, brightness)
	_choose.modulate = Color(brightness, brightness, brightness)

