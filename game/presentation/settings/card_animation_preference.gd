extends RefCounted
## Small UI preference adapter; independent of gameplay saves and scene lifetime.
signal changed(enabled: bool)

const Defaults = preload("res://presentation/settings/player_preferences.tres")
const USER_PATH = "user://player_preferences.cfg"
const SECTION = "presentation"
const KEY = "card_animation_enabled"
var _path: String
var _enabled: bool
var _config := ConfigFile.new()

func _init(path: String = USER_PATH) -> void:
	_path = path
	_enabled = Defaults.card_animation_enabled
	var result := _config.load(_path)
	if result == ERR_FILE_NOT_FOUND: return
	if result != OK:
		push_warning("Could not read UI preferences (%s): %s" % [_path, error_string(result)])
		return
	if not _config.has_section_key(SECTION, KEY): return
	var value: Variant = _config.get_value(SECTION, KEY)
	if value is bool:
		_enabled = value
	else:
		push_warning("Invalid card animation preference; using the authored Resource default")

func is_enabled() -> bool:
	return _enabled

func set_enabled(value: bool) -> Error:
	# Preserve unrelated preference fields written by future settings pages.
	_config.set_value(SECTION, KEY, value)
	var result := _config.save(_path)
	if result != OK:
		push_warning("Could not save UI preferences (%s): %s" % [_path, error_string(result)])
	if _enabled != value:
		_enabled = value
		changed.emit(_enabled)
	return result
