extends Control
const EffectPicker = preload("res://presentation/combat/effect_picker/effect_picker.gd")
signal retry_requested
signal return_requested
signal resume_requested
signal weapon_effect_selected(effect_id: StringName)
signal encounter_requested(depth: int)
var encounter_label: Label
var depth_selector: SpinBox
var encounter_panel: PanelContainer
var _encounter_floor := 0.0
var status: Label
var message: Label
var resume: Button
var effect_picker
var _top: VBoxContainer
var _margin: int
var _texts: Dictionary = {}
func configure(shared_theme: Theme, margin: int) -> void:
	theme = shared_theme
	_margin = margin
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := VBoxContainer.new()
	_top = top
	add_child(top)
	top.position = Vector2(margin, margin)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label(top, "combat.title")
	status = _add_label(top, "")
	message = _add_label(top, "")
	var footer := VBoxContainer.new()
	add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(margin, size.y - margin)
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_label(footer, "combat.controls")
	_add_label(footer, "combat.prototype")
	var actions := HBoxContainer.new()
	footer.add_child(actions)
	for key in ["combat.retry", "combat.return", "combat.resume"]:
		var button := Button.new()
		actions.add_child(button)
		_texts[button] = key
		match key:
			"combat.retry": button.pressed.connect(func(): retry_requested.emit())
			"combat.return": button.pressed.connect(func(): return_requested.emit())
			"combat.resume":
				resume = button
				button.pressed.connect(func(): resume_requested.emit())
	refresh_text()
func configure_effect_picker(palette: Resource, current_id: StringName) -> void:
	effect_picker = EffectPicker.new()
	add_child(effect_picker)
	effect_picker.configure(palette, theme)
	effect_picker.set_selected(current_id)
	effect_picker.effect_selected.connect(func(id: StringName): weapon_effect_selected.emit(id))
	effect_picker.minimum_size_changed.connect(_layout_effect_picker.call_deferred)
	for child in _top.get_children():
		if child is Label: child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resized.connect(_layout_effect_picker)
	_layout_effect_picker()
func configure_encounters(depth: int, max_depth: int, panel_position: Vector2) -> void:
	encounter_panel = PanelContainer.new()
	add_child(encounter_panel)
	encounter_panel.position = panel_position
	_encounter_floor = panel_position.y
	var column := VBoxContainer.new()
	encounter_panel.add_child(column)
	encounter_label = _add_label(column, "")
	var row := HBoxContainer.new()
	column.add_child(row)
	_add_label(row, "encounter.depth")
	depth_selector = SpinBox.new()
	row.add_child(depth_selector)
	depth_selector.min_value = 1
	depth_selector.max_value = max_depth
	depth_selector.step = 1
	depth_selector.value = depth
	var reroll := Button.new()
	column.add_child(reroll)
	_texts[reroll] = "encounter.reroll"
	reroll.pressed.connect(func(): encounter_requested.emit(int(depth_selector.value)))
	refresh_text()
func place_encounters_below(panel: Control) -> void:
	if encounter_panel == null: return
	var relayout := func(): encounter_panel.position.y = maxf(_encounter_floor, panel.position.y + panel.size.y + _margin)
	panel.resized.connect(relayout)
	relayout.call_deferred()
func update_encounter(plan: Dictionary, wave_index: int) -> void:
	if encounter_label == null: return
	var wave: Dictionary = plan.waves[clampi(wave_index, 0, plan.waves.size() - 1)]
	encounter_label.text = tr("encounter.status").format({"depth":int(plan.depth),"budget":int(plan.budget),"name":tr(wave.name_key)})
func _layout_effect_picker() -> void:
	if effect_picker == null: return
	effect_picker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	effect_picker.size = effect_picker.get_combined_minimum_size()
	effect_picker.position = Vector2(size.x - _margin - effect_picker.size.x, _margin)
	_top.size.x = maxf(0.0, effect_picker.position.x - _margin * 2.0)
func _add_label(parent: Node, key: String) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	if not key.is_empty(): _texts[label] = key
	return label
func refresh_text() -> void:
	for node in _texts: node.text = tr(_texts[node])
	if effect_picker != null: effect_picker.refresh_text()
func update_state(player, encounter, wave_count: int, state: String, paused: bool) -> void:
	status.text = tr("combat.status").format({"hp":ceili(player.health.current), "max_hp":ceili(player.health.maximum), "charges":player.charges, "max_charges":player.dodge.charges, "wave":encounter.wave_index + 1, "total":wave_count, "enemies":encounter.remaining()})
	var key := "combat." + ("paused" if paused else state)
	message.text = tr(key)
	resume.visible = paused
