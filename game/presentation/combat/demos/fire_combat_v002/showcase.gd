extends Node
## Real training combat with automatic player intent and paused enemy decisions.
## Placeholder body animations remain visible; health and damage are not staged.
const ArenaScene = preload("res://rogue/scenes/training_arena.tscn")
const Settings = preload("res://presentation/combat/demos/fire_combat_v002/settings.tres")
const Palette = preload("res://presentation/combat/effect_picker/palette.tres")
var _arena
var _target
var _time := 0.0
var _previous_time_scale: float
var _finishing := false
var _capture := false
var _requested: Dictionary = {}
var _target_staged := false
var _combo_count := 0
var _mode := "normal"
var _current_cast := -1
var _resolving_source
var _title: Label
var _title_key: String
var _casts: Array[Dictionary] = []
var _hits: Array[Dictionary] = []
var _screenshots: Dictionary = {}
var _failures: Array[String] = []
var _pending_images := 0
var _initial_health: float

func _ready() -> void:
	assert(Settings.duration_sec > Settings.range_slow_end_sec)
	assert(Settings.slow_start_sec < Settings.slow_attack_sec and Settings.slow_attack_sec < Settings.slow_end_sec)
	assert(Settings.slow_end_sec < Settings.combo_start_sec and Settings.combo_start_sec < Settings.target_stage_sec)
	assert(Settings.slow_scale > 0.0 and Settings.slow_scale < 1.0)
	_capture = "--capture" in OS.get_cmdline_user_args()
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = 1.0
	TranslationServer.set_locale("zh_CN")
	_arena = ArenaScene.instantiate()
	add_child(_arena)
	_arena.set_physics_process(false)
	_arena.set_process_unhandled_input(false)
	_arena.player.position = Settings.player_start
	_arena.player.facing = Settings.facing.normalized()
	_arena.player.runner.committed.connect(_on_committed)
	var enemy_index := 0
	for actor in _arena.actors:
		actor.health.damaged.connect(_on_damage.bind(actor))
		if actor.team == _arena.player.team: continue
		assert(enemy_index < Settings.distant_enemy_offsets.size())
		actor.position = Settings.player_start + Settings.distant_enemy_offsets[enemy_index]
		actor.movement = Vector3.ZERO
		actor.facing = -Settings.facing.normalized()
		if _target == null: _target = actor
		enemy_index += 1
	assert(_target != null)
	_initial_health = _target.health.current
	assert(_arena.hud.effect_picker.buttons.has(Settings.effect_id))
	_arena.hud.effect_picker.buttons[Settings.effect_id].pressed.emit()
	assert(_arena.selected_effect_id == Settings.effect_id)
	for option in Palette.options:
		if option.id == Settings.effect_id: _title_key = option.name_key
	_title = Label.new()
	_title.theme = _arena.shared_theme
	_title.add_theme_font_size_override("font_size", Settings.title_font_size)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.position = Settings.title_position
	_arena.hud.add_child(_title)
	_frame_camera(false)
	print("FIRE_V002_CAPTURE_READY ", JSON.stringify({"effect_id": Settings.effect_id, "effect_scene": _arena.views[0].weapon_effect.scene_file_path, "enemy_ai_enabled": false, "target_start_hp": _initial_health}))

func _physics_process(delta: float) -> void:
	if _arena == null or _finishing: return
	_time += delta / Engine.time_scale
	var slow := (_time >= Settings.slow_start_sec and _time < Settings.slow_end_sec) or (_time >= Settings.range_slow_start_sec and _time < Settings.range_slow_end_sec)
	Engine.time_scale = Settings.slow_scale if slow else 1.0
	_arena.player.movement = Vector3.ZERO
	_arena.player.facing = Settings.facing.normalized()
	_request_once("normal", Settings.normal_attack_sec)
	_request_once("slow", Settings.slow_attack_sec)
	if _time >= Settings.combo_start_sec and _combo_count < _arena.player.attacks.size() and not _arena.player.runner.busy():
		_mode = "combo"
		_arena.player.request_attack()
	if not _target_staged and _time >= Settings.target_stage_sec:
		_target.position = _arena.player.position + Settings.facing.normalized() * Settings.target_distance_m
		_target_staged = true
	_request_once("range", Settings.range_attack_sec)
	# Enemy Brain.tick omitted for repeatability; actor physics and combat stay real.
	for actor in _arena.actors: actor.step(delta)
	for actor in _arena.actors:
		_resolving_source = actor
		_arena.resolver.resolve(actor, _arena.actors)
	_resolving_source = null
	for view in _arena.views: view.refresh(delta)
	_frame_camera(slow)
	_arena.hud.update_state(_arena.player, _arena.encounter, _arena.catalog.waves().size(), _arena.state, false)
	_title.text = tr(_title_key) + "  ·  ×" + str(Engine.time_scale)
	_observe_capture()
	if _time >= Settings.duration_sec:
		_finishing = true
		_finish.call_deferred()

func _request_once(id: String, when: float) -> void:
	if _requested.has(id) or _time < when: return
	_mode = id
	_arena.player.request_attack()
	_requested[id] = true

func _frame_camera(slow: bool) -> void:
	_arena._follow_camera()
	var camera: Camera3D = _arena.get_node("Camera")
	camera.size = Settings.close_camera_size if slow else Settings.normal_camera_size
	camera.position += camera.global_basis.x * Settings.camera_right_shift

func _on_committed(cast_id: int, ability_id: String) -> void:
	if _mode == "combo": _combo_count += 1
	var ability = _arena.catalog.ability(ability_id)
	_current_cast = _casts.size()
	_casts.append({"cast_id": cast_id, "ability_id": ability_id, "phase": _mode, "radius_m": ability.radius, "arc_deg": rad_to_deg(ability.angle), "target_distance_m": _arena.player.position.distance_to(_target.position), "review_sec": _time, "time_scale": Engine.time_scale, "damage_applied": 0.0, "hit_count": 0, "active_fx_frames": 0})

func _on_damage(amount: float, target) -> void:
	if _resolving_source != _arena.player or _current_cast < 0:
		_failures.append("Damage received outside the recorded player resolver pass.")
		return
	_hits.append({"cast_id": _arena.player.runner.cast_id, "ability_id": _arena.player.runner.ability.id, "target_id": target.definition.id, "distance_m": _arena.player.position.distance_to(target.position), "amount": amount, "remaining_hp": target.health.current, "review_sec": _time})
	_casts[_current_cast].hit_count += 1
	_casts[_current_cast].damage_applied += amount
	if _capture and not _screenshots.has("range_hit") and DisplayServer.get_name() != "headless":
		_screenshots["range_hit"] = {"review_sec": _time, "phase": "actual_damage"}
		_save_image("range_hit")

func _observe_capture() -> void:
	var runner = _arena.player.runner
	if _capture and DisplayServer.get_name() != "headless" and _time >= Settings.tail_screenshot_sec and not _screenshots.has("tail_cleared"):
		_screenshots["tail_cleared"] = {"review_sec": _time, "phase": runner.phase()}
		_save_image("tail_cleared")
	if runner.phase() == "active":
		if not is_instance_valid(_arena.views[0].weapon_effect): _failures.append("Effect missing during active attack.")
		elif _current_cast >= 0: _casts[_current_cast].active_fx_frames += 1
	if not _capture or DisplayServer.get_name() == "headless" or runner.phase() != "recovery": return
	if _mode == "combo" and _combo_count != _arena.player.attacks.size(): return
	var name: String = _mode + "_endpoint"
	if _screenshots.has(name): return
	_screenshots[name] = {"review_sec": _time, "cast_id": runner.cast_id, "phase": "first_recovery", "active_progress": 1.0}
	_save_image(name)

func _save_image(name: String) -> void:
	_pending_images += 1
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path(Settings.previews_path)
	DirAccess.make_dir_recursive_absolute(directory)
	var error := get_viewport().get_texture().get_image().save_png(directory.path_join(name + ".png"))
	if error != OK: _failures.append("Screenshot save failed: " + name)
	_pending_images -= 1

func _finish() -> void:
	while _pending_images > 0: await get_tree().process_frame
	var phases: Dictionary = {}
	var combo_ids: Array[String] = []
	for cast in _casts:
		phases[cast.phase] = true
		if absf(cast.arc_deg - Settings.expected_arc_deg) > Settings.arc_tolerance_deg: _failures.append("Unexpected attack angle.")
		if cast.active_fx_frames == 0: _failures.append("No active effect frames.")
		if cast.phase == "combo": combo_ids.append(cast.ability_id)
		if cast.phase != "range" and cast.hit_count > 0: _failures.append("Empty review swing unexpectedly hit.")
		if cast.phase == "range" and (cast.hit_count == 0 or absf(cast.target_distance_m - Settings.target_distance_m) > Settings.distance_tolerance_m): _failures.append("New range hit was not demonstrated.")
	for phase in ["normal", "slow", "combo", "range"]:
		if not phases.has(phase): _failures.append("Missing required review phase: " + phase)
	if combo_ids != _arena.player.definition.attacks: _failures.append("Combo sequence does not match actual actor attack list.")
	if _capture and DisplayServer.get_name() != "headless" and not _screenshots.has("slow_endpoint"): _failures.append("Slow endpoint screenshot missing.")
	var report := {"arena": ArenaScene.resource_path, "effect_id": Settings.effect_id, "effect_scene": _arena.views[0].weapon_effect.scene_file_path, "enemy_ai_enabled": false, "staging_note": "Enemy decisions paused. Actual Actor/AbilityRunner/Resolver/View and catalog health remain active. Body action is the existing placeholder, not a new skeletal attack.", "review_duration_sec": _time, "normal_camera_size": Settings.normal_camera_size, "close_camera_size": Settings.close_camera_size, "slow_scale": Settings.slow_scale, "target_start_hp": _initial_health, "target_end_hp": _target.health.current, "casts": _casts, "hits": _hits, "screenshots": _screenshots, "failures": _failures}
	var path := ProjectSettings.globalize_path(Settings.report_path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	else: _failures.append("Could not write capture report.")
	print("FIRE_V002_CAPTURE ", JSON.stringify(report))
	Engine.time_scale = _previous_time_scale
	get_tree().quit(0 if _failures.is_empty() else 1)

func _exit_tree() -> void:
	Engine.time_scale = _previous_time_scale
