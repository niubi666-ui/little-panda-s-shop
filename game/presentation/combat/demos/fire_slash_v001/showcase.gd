extends Node
## Isolated art comparison; uses existing player/model/cast timing, no resolver.
const ArenaScene = preload("res://rogue/scenes/training_arena.tscn")
const Settings = preload("res://presentation/combat/demos/fire_slash_v001/settings.tres")
const ThemeFactory = preload("res://presentation/foliage/foliage_theme_factory.gd")
var _arena
var _variant := -1
var _time := 0.0
var _cycle := 0.0
var _slow := false
var _paused := false
var _auto_switch := true
var _capture := false
var _title: Label
var _stats: Label
var _captured: Array[int] = []
var _captured_close: Array[int] = []
var _counts: Array[int] = []
var _failures: Array[String] = []

func _ready() -> void:
	assert(not Settings.effects.is_empty() and Settings.repeat_interval_sec > 0.0 and Settings.variant_duration_sec > 0.0 and Settings.slow_scale > 0.0)
	_capture = "--capture" in OS.get_cmdline_user_args()
	_arena = ArenaScene.instantiate()
	add_child(_arena)
	_arena.set_physics_process(false)
	_arena.set_process_unhandled_input(false)
	_arena.get_node("RoomActors").hide()
	_arena.hud.hide()
	_arena.player.position = Vector3.ZERO
	_arena.player.facing = Vector3.FORWARD
	_arena.player.movement = Vector3.ZERO
	_arena.views[0].label.hide()
	_arena.get_node("Camera").size = Settings.camera_size
	_arena._follow_camera()
	_counts.resize(Settings.effects.size())
	_counts.fill(0)
	_create_overlay()
	_set_variant(0)
	print("SLASH_SHOWCASE_READY; 1/2/3 select, Space replay, Tab slow, P pause, Esc exit")

func _create_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2.ONE * Settings.overlay_margin
	box.theme = ThemeFactory.create()
	layer.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", Settings.overlay_font_size)
	box.add_child(_title)
	_stats = Label.new()
	box.add_child(_stats)
	var row := HBoxContainer.new()
	box.add_child(row)
	for index in Settings.effects.size():
		var button := Button.new()
		button.text = String.chr(65 + index)
		button.pressed.connect(func(): _auto_switch = false; _set_variant(index))
		row.add_child(button)
	var replay := Button.new()
	replay.text = "↻"
	replay.pressed.connect(_replay)
	row.add_child(replay)
	var slow := Button.new()
	slow.text = "× " + str(Settings.slow_scale)
	slow.pressed.connect(func(): _auto_switch = false; _slow = not _slow)
	row.add_child(slow)

func _set_variant(index: int) -> void:
	var cast_id: int = _arena.player.runner.cast_id
	_arena.views[0].set_weapon_effect(Settings.effects[index])
	if _arena.player.runner.cast_id != cast_id: _failures.append("Visual switch changed cast identity")
	_variant = index
	_cycle = 0.0
	_replay()

func _replay() -> void:
	_arena.player.cancel()
	_arena.player.runner.cooldown = 0.0
	_arena.player.runner.start(_arena.catalog.ability(_arena.catalog.player().attacks[0]), Vector3.FORWARD)
	_counts[_variant] += 1
	_cycle = 0.0

func _physics_process(delta: float) -> void:
	if _arena == null: return
	if not _paused:
		_time += delta
		if _auto_switch:
			var desired := int(_time / Settings.variant_duration_sec) % Settings.effects.size()
			if desired != _variant: _set_variant(desired)
			_slow = fmod(_time, Settings.variant_duration_sec) >= Settings.slow_start_sec
		var scaled := delta * (Settings.slow_scale if _slow else 1.0)
		_cycle += scaled
		if _cycle >= Settings.repeat_interval_sec: _replay()
		_arena.player.step(scaled)
		_arena.views[0].refresh(scaled)
	else:
		_arena.views[0].refresh(0.0)
	var effect = _arena.views[0].weapon_effect
	effect.set_playback_speed(Settings.slow_scale if _slow else 1.0)
	_arena.get_node("Camera").size = Settings.close_camera_size if _slow else Settings.camera_size
	_title.text = "FIRE"
	_stats.text = "× %s   |   Space · Tab · P · Esc" % (Settings.slow_scale if _slow else 1.0)
	if _capture:
		var runner = _arena.player.runner
		if _variant not in _captured and runner.phase() == "active" and runner.elapsed >= runner.ability.windup + runner.ability.active * Settings.capture_progress:
			_captured.append(_variant)
			_save_image(_variant, "")
		if _slow and _variant not in _captured_close and runner.phase() == "active" and runner.elapsed >= runner.ability.windup + runner.ability.active * Settings.capture_progress:
			_captured_close.append(_variant)
			_save_image(_variant, "_detail")
		if _time >= Settings.capture_length_sec:
			if _captured.size() != Settings.effects.size(): _failures.append("Missing variant screenshot")
			print("SLASH_SHOWCASE ", JSON.stringify({"failures": _failures, "strokes": _counts, "captured": _captured, "closeups": _captured_close}))
			get_tree().quit(0 if _failures.is_empty() else 1)

func _save_image(index: int, suffix: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://../source_assets/vfx/fire_slash/v001/previews")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join("candidate_%s%s.png" % [String.chr(97 + index), suffix]))

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_1:
			_auto_switch = false
			_set_variant(event.physical_keycode - KEY_1)
		KEY_SPACE: _replay()
		KEY_TAB:
			_auto_switch = false
			_slow = not _slow
		KEY_P: _paused = not _paused
		KEY_ESCAPE: get_tree().quit()
