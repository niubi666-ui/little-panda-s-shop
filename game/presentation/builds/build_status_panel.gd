extends PanelContainer
signal test_offer_requested

const Style = preload("res://presentation/builds/build_ui_style.tres")
var _catalog
var _ranks: Dictionary = {}
var _title: Label
var _summary: Label
var _notice: Label
var _notice_key := ""
var _test_button: Button


func configure(catalog, shared_theme: Theme) -> void:
	assert(catalog != null and shared_theme != null)
	_catalog = catalog
	theme = shared_theme
	name = "BuildStatusPanel"
	position = Style.status_position
	custom_minimum_size.x = Style.status_width
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", Style.status_panel)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	for edge in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(edge, Style.status_padding)
	add_child(margin)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	stack.add_theme_constant_override("separation", Style.status_gap)
	margin.add_child(stack)
	_title = _label(stack)
	_title.theme_type_variation = &"PaperHeading"
	_title.add_theme_color_override("font_color", Style.gold_color)
	var divider := ColorRect.new()
	divider.color = Style.separator_color
	divider.custom_minimum_size.y = Style.separator_height
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(divider)
	var summary_scroll := ScrollContainer.new()
	summary_scroll.name = "BuildSummaryScroll"
	summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	summary_scroll.custom_minimum_size.y = Style.status_summary_height
	stack.add_child(summary_scroll)
	_summary = _label(summary_scroll)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice = _label(stack)
	_notice.name = "BuildNotice"
	_notice.theme_type_variation = &"Muted"
	_notice.add_theme_color_override("font_color", Style.error_color)
	_test_button = Button.new()
	_test_button.name = "BuildTestOffer"
	_test_button.custom_minimum_size.y = Style.status_button_height
	_test_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_test_button.pressed.connect(func(): test_offer_requested.emit())
	stack.add_child(_test_button)
	refresh_text()


func update_state(ranks: Dictionary) -> void:
	_ranks = ranks.duplicate(true)
	refresh_text()


func set_notice(key: String) -> void:
	_notice_key = key
	refresh_text()


func refresh_text() -> void:
	if _title == null:
		return
	_title.text = tr("build.owned")
	var lines: PackedStringArray = []
	for entry in _catalog.entries():
		var id: String = entry["id"]
		if not _ranks.has(id) or int(_ranks[id]) <= 0:
			continue
		var rank_text := tr("build.rank").format({"rank": int(_ranks[id]), "max_rank": int(entry["max_rank"])})
		lines.append(tr(entry["name_key"]) + "  " + rank_text)
	_summary.text = tr("build.empty") if lines.is_empty() else "\n".join(lines)
	_notice.text = tr(_notice_key) if not _notice_key.is_empty() else ""
	_notice.visible = not _notice_key.is_empty()
	_test_button.text = tr("build.test_offer")
	reset_size()
	_fit_after_layout.call_deferred()


func _fit_after_layout() -> void:
	# Measure wrapping at the actual container width, without a resize signal loop.
	await get_tree().process_frame
	if is_inside_tree(): reset_size()


func _label(parent: Node) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		accept_event()
