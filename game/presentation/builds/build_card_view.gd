extends Button
## Runtime assembly: art / text backing / ornament / frame / live labels.
const CardSkin = preload("res://presentation/builds/build_card_skin.tres")
const MotionLibrary = preload("res://presentation/builds/card_art_motion/library.tres")
const ArtMotion = preload("res://presentation/builds/card_art_motion/art_motion.gd")
var art_motion: ArtMotion
var _motion_requested := false
var _motion_intensity_override: Variant = null
var _motion_paused := false
var labels: Dictionary = {}
var art_id := ""
var rarity_id := ""
var art_path := ""
var _frame: TextureRect
var _choose: Panel
var _glow: Panel
var _hotkey: Label
var _rarity: Dictionary
## 动画状态：面板只写这几个值，卡自己按 CardSkin 的参数算出位置、缩放、亮度。
var home := Vector2.ZERO       # 落定后的位置（画布坐标）
var side := 0.0                # -1 左、0 中、1 右：飞入时朝外倾斜
var appear := 0.0              # 0 未出现 → 1 落定（线性，曲线在这里套）
var picked := 0.0              # 被选中后的动画 0 → 1
var discarded := 0.0           # 没被选中的退场 0 → 1
var dimmed := false            # 另一张卡处于选中状态
var _focus := 0.0
var _dim := 0.0
var _press := 0.0
var _clock := 0.0

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
	pivot_offset = CardSkin.card_size * Vector2(0.5, 0.55)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	# Focus brightens the illustrated frame and its choice surface, preserving the cutout silhouette.
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# 光晕：只画阴影的方框（阴影本身就是一圈柔和的模糊边），叠加混合
	_glow = Panel.new()
	_glow.name = "FocusGlow"
	var halo := StyleBoxFlat.new()
	halo.draw_center = false
	halo.shadow_color = Color.WHITE
	halo.shadow_size = int(CardSkin.glow_size)
	halo.set_corner_radius_all(int(CardSkin.glow_size * 0.5))
	_glow.add_theme_stylebox_override("panel", halo)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive
	_add_rect(_glow, CardSkin.glow_rect)
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
	_hotkey = _label("HotkeyText", CardSkin.hotkey_rect, CardSkin.hotkey_font_size, CardSkin.gold_color)
	_hotkey.clip_text = false
	var keycap := StyleBoxFlat.new()
	keycap.bg_color = Color(CardSkin.body_color, 0.85)
	keycap.border_color = Color(CardSkin.gold_color, 0.55)
	keycap.set_border_width_all(1)
	keycap.set_corner_radius_all(6)
	_hotkey.add_theme_stylebox_override("normal", keycap)
	# 鼠标移上去就把焦点给这张卡：鼠标和键盘/手柄共用同一个“当前选中”
	mouse_entered.connect(func(): if focus_mode != Control.FOCUS_NONE: grab_focus())
	button_down.connect(func(): _press = 1.0)
	_sync_art_motion()
	_animate(0.0)

func set_hotkey(text: String) -> void:
	_hotkey.text = text
	_hotkey.visible = not text.is_empty()

func active() -> bool:
	return has_focus() and picked <= 0.0 and discarded <= 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_animate(delta)
	if art_motion != null: art_motion.advance(delta, _focus)

func set_art_motion_enabled(value: bool) -> void:
	_motion_requested = value
	_sync_art_motion()

func _sync_art_motion() -> void:
	if not _motion_requested:
		if art_motion != null:
			art_motion.set_enabled(false)
			remove_child(art_motion)
			art_motion.queue_free()
			art_motion = null
		return
	var illustration := get_node_or_null("Illustration") as TextureRect
	if illustration == null or art_motion != null: return
	var motion_profile = MotionLibrary.profile_for(art_id)
	if motion_profile == null: return
	art_motion = ArtMotion.new()
	art_motion.name = "ArtMotion"
	_add_rect(art_motion, Rect2(illustration.position, illustration.size))
	move_child(art_motion, illustration.get_index()+1)
	art_motion.configure(motion_profile, illustration.texture)
	if _motion_intensity_override != null: art_motion.set_intensity(_motion_intensity_override)
	art_motion.set_paused(_motion_paused)

func set_art_motion_intensity(value: float) -> void:
	_motion_intensity_override = value
	if art_motion != null: art_motion.set_intensity(value)

func set_art_motion_paused(value: bool) -> void:
	_motion_paused = value
	if art_motion != null: art_motion.set_paused(value)

func _animate(delta: float) -> void:
	_clock += delta
	var blend := 1.0 - exp(-delta * CardSkin.hover_speed)
	_focus = lerpf(_focus, 1.0 if active() else 0.0, blend)
	_dim = lerpf(_dim, 1.0 if dimmed and not active() else 0.0, blend)
	_press = lerpf(_press, 0.0, blend)
	var land := ease_out_back(clampf(appear, 0.0, 1.0))
	var punch := 1.0 - pow(1.0 - clampf(picked / 0.25, 0.0, 1.0), 3.0)
	var leave := smoothstep(0.3, 1.0, picked)
	var sink := discarded * discarded
	var lift := CardSkin.hover_lift * _focus
	position = home + Vector2(0.0, CardSkin.deal_rise * (1.0 - land) - lift - CardSkin.pick_rise * leave * leave + CardSkin.discard_drop * sink)
	var grow := lerpf(CardSkin.deal_scale, 1.0, land) * (1.0 + CardSkin.hover_scale * _focus - CardSkin.dim_scale * _dim - CardSkin.press_squash * _press)
	scale = Vector2.ONE * grow * (1.0 + CardSkin.pick_punch * punch) * (1.0 - 0.08 * sink)
	rotation = deg_to_rad(CardSkin.deal_tilt_deg * side * (1.0 - land))
	var flash := lerpf(CardSkin.pick_flash, 1.0, smoothstep(0.0, 0.45, picked)) if picked > 0.0 else 1.0
	var shade := (1.0 - CardSkin.dim_darken * _dim) * flash
	modulate = Color(shade, shade, shade, clampf(appear * 2.5, 0.0, 1.0) * (1.0 - leave) * (1.0 - sink))
	var brightness := lerpf(1.0, CardSkin.hover_brightness, _focus)
	_frame.modulate = Color(brightness, brightness, brightness)
	_choose.modulate = Color(brightness, brightness, brightness)
	var pulse := 1.0 + CardSkin.glow_pulse * _focus * sin(_clock * CardSkin.glow_pulse_speed)
	var glow := lerpf(CardSkin.glow_idle, CardSkin.glow_focus, maxf(_focus, punch * (1.0 - leave))) * pulse
	_glow.modulate = Color(_rarity.color, clampf(glow, 0.0, 1.0))

## 先慢后快再略过头回弹（落定那一下有“啪”的感觉）
static func ease_out_back(t: float) -> float:
	var c := 1.4
	var u := t - 1.0
	return 1.0 + (c + 1.0) * u * u * u + c * u * u

func _make_custom_tooltip(for_text: String) -> Object:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(CardSkin.body_color, 0.96)
	style.border_color = Color(_rarity.color, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	box.add_theme_stylebox_override("panel", style)
	var text := Label.new()
	text.text = for_text
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = CardSkin.tooltip_width
	text.add_theme_font_size_override("font_size", CardSkin.description_font_size)
	text.add_theme_color_override("font_color", CardSkin.text_color)
	box.add_child(text)
	return box

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
	tooltip_text = copy["name"] + "  ·  " + copy["binding"] + "\n" + copy["next"] + "\n\n" + copy["details"]

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

