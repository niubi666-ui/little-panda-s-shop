extends CanvasLayer
## A scene-owned pause owner. The view never modifies combat or duplicates formulas.
const View = preload("res://presentation/attributes/character_sheet.gd")
const Formula = preload("res://combat/effects/damage_formula.gd")
var panel: View
var opened := false
var _actor
var _catalog
var _program: Callable
var _can_open: Callable
var _on_toggle: Callable
var _preview := false
var _previous_pause := false
var _previous_focus: WeakRef
func configure(actor, catalog, program: Callable, can_open: Callable, on_toggle: Callable, shared_theme: Theme, preview: bool = false) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	_actor = actor
	_catalog = catalog
	_program = program
	_can_open = can_open
	_on_toggle = on_toggle
	_preview = preview
	panel = View.new()
	add_child(panel)
	panel.configure(shared_theme,catalog.attributes.data.stat_keys)
	panel.close_requested.connect(close)
	panel.hide()
func open() -> bool:
	if opened or not _can_open.call(): return false
	_previous_pause = get_tree().paused
	var focus := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	_actor.clear_intents()
	_actor.movement = Vector3.ZERO
	opened = true
	_on_toggle.call(true)
	get_tree().paused = true
	panel.show()
	refresh()
	panel.close_button.grab_focus()
	return true
func close() -> void:
	if not opened: return
	_actor.clear_intents()
	panel.hide()
	opened = false
	get_tree().paused = _previous_pause
	_on_toggle.call(false)
	if _previous_focus != null:
		var focus = _previous_focus.get_ref()
		if focus != null and focus.is_visible_in_tree(): focus.grab_focus()
func snapshot() -> Dictionary:
	var program: Dictionary = _program.call()
	var stats: Dictionary = _actor.attributes.final
	var skills: Array = []
	var effects: Array = []
	var bonuses := {"primary":0.0,"special":0.0,"skill":0.0}
	var global_bonus: float = program["global"].damage_scale - 1.0 if not program.is_empty() else 0.0
	for action in bonuses:
		var ids: Array = ["slash.1","slash.2","slash.3"] if action == "primary" else (["heavy_slash"] if action == "special" else ["wave_cast"])
		var scale := 1.0
		if not program.is_empty():
			ids = program.actions[action].ability_ids
			scale = program.actions[action].damage_scale
		bonuses[action] = scale - 1.0
		for id in ids:
			var preview := Formula.preview(_actor, _catalog.ability(id).damage_profile_id, scale)
			preview.id = id.replace(".", "_")
			skills.append(preview)
		if not program.is_empty():
			for effect in program.actions[action].effects:
				if effect.type == "charge_projectile":
					var charged := Formula.preview(_actor, _catalog.ability(ids[0]).damage_profile_id, scale, effect.params.damage_ratio)
					charged.id = "charged_wave"
					skills.append(charged)
				elif effect.type == "element": effects.append({"action":action,"element":effect.params.element_id})
				elif effect.type == "conditional_damage": effects.append({"action":action,"bonus":effect.params.bonus})
	return {"preview":_preview,"stats":stats,"hp":_actor.health.current,"shield":_actor.protection_amount,
		"physical_reduction":1.0-Formula.mitigation(_catalog.attributes,"physical",stats),
		"magical_reduction":1.0-Formula.mitigation(_catalog.attributes,"magical",stats),
		"skills":skills,"effects":effects,"weapon_bonus":global_bonus,"action_bonus":bonuses}
func refresh() -> void:
	if opened: panel.display(snapshot())
func _process(_delta: float) -> void: refresh()
func _input(event: InputEvent) -> void:
	if event.is_echo(): return
	if event.is_action_pressed("ui_character_stats"):
		if opened: close()
		else: open()
		get_viewport().set_input_as_handled()
	elif opened:
		if event.is_action_pressed("ui_cancel"): close()
		elif event.is_action_pressed("toggle_language"):
			TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("zh") else "zh_CN")
			refresh()
		# Keyboard input must not reach combat or another pause owner.
		if event is InputEventKey or event.is_action_pressed("combat_skill") or event.is_action_released("combat_skill"):
			get_viewport().set_input_as_handled()
func _exit_tree() -> void:
	if opened: get_tree().paused = _previous_pause
