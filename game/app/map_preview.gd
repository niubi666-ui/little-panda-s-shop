extends CanvasLayer
## Scene-owned preview. No RunSession, scene replacement, inventory or reward access.
const Loader = preload("res://content/run/map_preview_loader.gd")
const Generator = preload("res://rogue/run/map_preview_generator.gd")
const View = preload("res://presentation/map_preview/map_preview_view.gd")
const ThemeFactory = preload("res://presentation/foliage/foliage_theme_factory.gd")
@export_file("*.json") var manifest_path: String
@export var style: Resource
@export var translations: Array[Translation]
@export var open_on_ready := false
var view: Control
var plan: Dictionary = {}
var rules: Dictionary = {}
var opened := false
var _previous_pause := false
var _previous_focus: WeakRef
var _seed_rng := RandomNumberGenerator.new()
var _generator := Generator.new()
var _initialized := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_seed_rng.randomize() # Dedicated preview seed source; never touches gameplay RNG.
	_finish_setup.call_deferred()

func _finish_setup() -> void:
	# Parent bootstraps its pause menu in _ready. Receive overlay keys before it.
	get_parent().move_child(self, -1)
	if open_on_ready: open()

func _initialize_view() -> void:
	if _initialized: return
	_initialized = true
	for translation in translations: TranslationServer.add_translation(translation)
	var loader := Loader.new()
	rules = loader.load_rules(manifest_path)
	for error in loader.errors: push_error(error)
	view = View.new()
	add_child(view)
	view.configure(ThemeFactory.create(), style)
	view.hide()
	view.close_requested.connect(close)
	view.new_map_requested.connect(new_map)
	view.seed_requested.connect(generate_seed)
	if rules.is_empty():
		view.show_error("map_preview.unavailable")
		view.new_button.disabled = true
		view.apply_button.disabled = true
	else: new_map()

func open() -> void:
	if opened or get_tree().paused: return
	for window in get_viewport().get_embedded_subwindows():
		if window.visible: return
	_initialize_view()
	_previous_focus = weakref(get_viewport().gui_get_focus_owner())
	_previous_pause = get_tree().paused
	opened = true
	get_tree().paused = true
	view.show()
	view.new_button.grab_focus()

func close() -> void:
	if not opened: return
	opened = false
	view.hide()
	get_tree().paused = _previous_pause
	if _previous_focus != null:
		var focus: Variant = _previous_focus.get_ref()
		if is_instance_valid(focus) and focus is Control and focus.is_visible_in_tree(): focus.grab_focus()

func new_map() -> void:
	generate_seed(str(_seed_rng.randi()))

func generate_seed(seed_text: String) -> bool:
	if rules.is_empty(): return false
	var normalized := seed_text.strip_edges()
	if normalized.is_empty() or normalized.length() > 64:
		view.show_error("map_preview.invalid_seed")
		return false
	var candidate := _generator.generate(rules, normalized)
	if not candidate.ok:
		view.show_error(candidate.error_key)
		return false
	plan = candidate.plan
	view.show_plan(plan)
	return true

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var focus := get_viewport().gui_get_focus_owner()
	var editing := focus is LineEdit or focus is TextEdit
	if opened and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif not editing and style.toggle_event.is_match(event):
		get_viewport().set_input_as_handled()
		if opened: close()
		else: open()
	elif opened and not editing and event.is_action_pressed("toggle_language"):
		get_viewport().set_input_as_handled()
		TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("zh") else "zh_CN")

func _unhandled_input(_event: InputEvent) -> void:
	if opened: get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if opened: get_tree().paused = _previous_pause
