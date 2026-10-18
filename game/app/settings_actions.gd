extends RefCounted
## Settings only. No inventory, run state, or game-save writes.
signal card_animation_changed(enabled: bool)
const CardAnimationPreference = preload("res://presentation/settings/card_animation_preference.gd")
var _card_animation: CardAnimationPreference

func _init(preference: CardAnimationPreference = null) -> void:
	_card_animation = preference if preference != null else CardAnimationPreference.new()
	_card_animation.changed.connect(card_animation_changed.emit)

func card_animation_enabled() -> bool:
	return _card_animation.is_enabled()

func set_card_animation_enabled(enabled: bool) -> Error:
	return _card_animation.set_enabled(enabled)

func master_volume() -> float:
	return AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Master"))

func set_master_volume(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), clampf(value, 0.0, 1.0))

func set_language(locale: String) -> void:
	if locale in ["zh_CN", "en"]: TranslationServer.set_locale(locale)

func vsync_enabled() -> bool:
	return DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED

func set_vsync(enabled: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)

func set_fps_limit(limit: int) -> void:
	if limit >= 0: Engine.max_fps = limit
