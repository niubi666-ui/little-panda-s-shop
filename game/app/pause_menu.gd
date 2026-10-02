extends CanvasLayer
## Scene-owned coordinator. Restores the exact previous pause state.
const SettingsPanel = preload("res://presentation/settings/settings_panel.gd")
const Actions = preload("res://app/settings_actions.gd")
signal closed
signal open_requested
var panel
var _previous_pause := false
var _opened := false

func configure(shared_theme: Theme) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	panel = SettingsPanel.new()
	add_child(panel)
	panel.configure(shared_theme, Actions.new())
	panel.close_requested.connect(close)
	panel.quit_requested.connect(func(): get_tree().quit())
	panel.hide()

func open() -> void:
	if _opened: return
	_opened = true
	_previous_pause = get_tree().paused
	get_tree().paused = true
	panel.show()
	panel.show_page("general")

func close() -> void:
	if not _opened: return
	_opened = false
	panel.hide()
	get_tree().paused = _previous_pause
	closed.emit()

func _input(event: InputEvent) -> void:
	if not _opened and open_requested.has_connections() and event.is_action_pressed("ui_cancel") and not event.is_echo():
		open_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if _opened and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if panel.confirming_exit: panel.show_page(panel.page)
		else: close()

func _unhandled_input(_event: InputEvent) -> void:
	if _opened: get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if _opened: get_tree().paused = _previous_pause
