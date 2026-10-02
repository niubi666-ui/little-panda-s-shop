extends Node
## Four real training arenas, one per effect. Enemy decision ticks are disabled
## for repeatable comparison; actor health, ability timeline and resolver are real.
const ArenaScene = preload("res://rogue/scenes/training_arena.tscn")
const Settings = preload("res://presentation/combat/demos/elemental_combat_v001/settings.tres")
const Palette = preload("res://presentation/combat/effect_picker/palette.tres")

var _arena
var _target
var _segment := -1
var _segment_time := 0.0
var _review_time := 0.0
var _transitioning := false
var _finishing := false
var _capture := false
var _normal_requested := false
var _slow_requested := false
var _hit_requested := false
var _target_staged := false
var _current_cast := -1
var _resolving_source
var _previous_time_scale: float
var _title: Label
var _title_key: String
var _casts: Array[Dictionary] = []
var _hits: Array[Dictionary] = []
var _segments: Array[Dictionary] = []
var _screenshots: Dictionary = {}
var _failures: Array[String] = []
var _pending_images := 0


func _ready() -> void:
	assert(Settings.segment_duration_sec > Settings.hit_attack_sec)
	assert(Settings.slow_start_sec < Settings.slow_attack_sec and Settings.slow_attack_sec < Settings.slow_end_sec)
	assert(Settings.slow_end_sec < Settings.target_stage_sec and Settings.target_stage_sec < Settings.hit_attack_sec)
	assert(Settings.slow_scale > 0.0 and Settings.slow_scale < 1.0)
	assert(Settings.target_distance_m > 0.0 and not Settings.facing.is_zero_approx())
	_capture = "--capture" in OS.get_cmdline_user_args()
	_previous_time_scale = Engine.time_scale
	TranslationServer.set_locale("zh_CN")
	_start_segment(0)


func _start_segment(index: int) -> void:
	if is_instance_valid(_arena):
		remove_child(_arena)
		_arena.free()
	_segment = index
	_segment_time = 0.0
	_normal_requested = false
	_slow_requested = false
	_hit_requested = false
	_target_staged = false
	_current_cast = -1
	Engine.time_scale = 1.0
	_arena = ArenaScene.instantiate()
	add_child(_arena)
	_arena.set_physics_process(false)
	_arena.set_process_unhandled_input(false)
	_arena.player.position = Settings.player_start
	_arena.player.facing = Settings.facing.normalized()
	_arena.player.runner.committed.connect(_on_committed)
	var enemy_index := 0
	_target = null
	for actor in _arena.actors:
		actor.health.damaged.connect(_on_damage.bind(actor))
		if actor.team == _arena.player.team: continue
		assert(enemy_index < Settings.distant_enemy_offsets.size())
		actor.position = Settings.player_start + Settings.distant_enemy_offsets[enemy_index]
		actor.movement = Vector3.ZERO
		actor.facing = -Settings.facing.normalized()
		if _target == null: _target = actor
		enemy_index += 1
	assert(_target != null, "A real spawned target is required.")
	var effect_id: StringName = Settings.effect_ids[index]
	assert(_arena.hud.effect_picker.buttons.has(effect_id), "Capture effect missing from the training palette.")
	# Use the same UI signal and application selection command as a user click.
	_arena.hud.effect_picker.buttons[effect_id].pressed.emit()
	assert(_arena.selected_effect_id == effect_id)
	for option in Palette.options:
		if option.id == effect_id: _title_key = option.name_key
	_title = Label.new()
	_title.theme = _arena.shared_theme
	_title.add_theme_font_size_override("font_size", Settings.title_font_size)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.position = Settings.title_position
	_arena.hud.add_child(_title)
	_segments.append({
		"effect_id": effect_id,
		"effect_scene": _arena.views[0].weapon_effect.scene_file_path,
		"player_visual": _arena.views[0].actor_style.visual_scene.resource_path,
		"target_id": _target.definition.id,
		"target_start_hp": _target.health.current,
		"enemy_ai_enabled": false,
		"arena_recreated": true,
		"started_review_sec": _review_time,
	})
	_frame_camera(false)
	_transitioning = false
	print("ELEMENTAL_CAPTURE_SEGMENT ", JSON.stringify(_segments.back()))


func _physics_process(delta: float) -> void:
	if _arena == null or _finishing or _transitioning: return
	var real_delta := delta / Engine.time_scale
	_review_time += real_delta
	_segment_time += real_delta
	var slow := _segment_time >= Settings.slow_start_sec and _segment_time < Settings.slow_end_sec
	Engine.time_scale = Settings.slow_scale if slow else 1.0
	_arena.player.movement = Vector3.ZERO
	_arena.player.facing = Settings.facing.normalized()
	if not _normal_requested and _segment_time >= Settings.normal_attack_sec:
		_arena.player.request_attack()
		_normal_requested = true
	if not _slow_requested and _segment_time >= Settings.slow_attack_sec:
		_arena.player.request_attack()
		_slow_requested = true
	if not _target_staged and _segment_time >= Settings.target_stage_sec:
		_target.position = _arena.player.position + Settings.facing.normalized() * Settings.target_distance_m
		_target_staged = true
		_segments[_segment]["staged_target_distance_m"] = _target.position.distance_to(_arena.player.position)
	if not _hit_requested and _segment_time >= Settings.hit_attack_sec:
		_arena.player.request_attack()
		_hit_requested = true
	# Brain.tick is intentionally omitted: only decision making is paused.
	# All runtime actors, real health, hit response and knockback still step.
	for actor in _arena.actors: actor.step(delta)
	for actor in _arena.actors:
		_resolving_source = actor
		_arena.resolver.resolve(actor, _arena.actors)
	_resolving_source = null
	for view in _arena.views: view.refresh(delta)
	_frame_camera(slow)
	_arena.hud.update_state(_arena.player, _arena.encounter, _arena.catalog.waves().size(), _arena.state, false)
	_title.text = tr(_title_key) + "  ·  ×" + str(Engine.time_scale)
	_observe_capture(slow)
	if _segment_time >= Settings.segment_duration_sec:
		_segments[_segment]["target_end_hp"] = _target.health.current
		_segments[_segment]["ended_review_sec"] = _review_time
		if _segment + 1 < Settings.effect_ids.size():
			_transitioning = true
			_start_segment.call_deferred(_segment + 1)
		else:
			_finishing = true
			_finish.call_deferred()


func _frame_camera(slow: bool) -> void:
	_arena._follow_camera()
	var camera: Camera3D = _arena.get_node("Camera")
	camera.size = Settings.close_camera_size if slow else Settings.normal_camera_size
	# Shift the framing so the complete strike stays left of the real picker UI.
	camera.position += camera.global_basis.x * Settings.camera_right_shift


func _on_committed(cast_id: int, ability_id: String) -> void:
	var ability = _arena.catalog.ability(ability_id)
	_current_cast = _casts.size()
	_casts.append({
		"effect_id": Settings.effect_ids[_segment],
		"cast_id": cast_id,
		"ability_id": ability_id,
		"phase": "range_hit" if _target_staged else ("slow_review" if _slow_requested else "normal_review"),
		"radius_m": ability.radius,
		"arc_deg": rad_to_deg(ability.angle),
		"target_distance_m": _arena.player.position.distance_to(_target.position),
		"review_sec": _review_time,
		"time_scale": Engine.time_scale,
		"damage_applied": 0.0,
		"hit_count": 0,
		"active_fx_frames": 0,
	})


func _on_damage(amount: float, target) -> void:
	if _resolving_source != _arena.player or _current_cast < 0:
		_failures.append("Damage received outside the recorded player resolver pass.")
		return
	var distance: float = _arena.player.position.distance_to(target.position)
	_hits.append({
		"effect_id": Settings.effect_ids[_segment],
		"cast_id": _arena.player.runner.cast_id,
		"ability_id": _arena.player.runner.ability.id,
		"target_id": target.definition.id,
		"distance_m": distance,
		"amount": amount,
		"remaining_hp": target.health.current,
		"review_sec": _review_time,
	})
	_casts[_current_cast].hit_count += 1
	_casts[_current_cast].damage_applied += amount


func _observe_capture(slow: bool) -> void:
	var runner = _arena.player.runner
	if runner.phase() == "active":
		if not is_instance_valid(_arena.views[0].weapon_effect):
			_failures.append("Weapon effect missing during active ability.")
		elif _current_cast >= 0: _casts[_current_cast].active_fx_frames += 1
	var effect_id: StringName = Settings.effect_ids[_segment]
	if _capture and slow and runner.phase() == "recovery" and not _screenshots.has(effect_id) and DisplayServer.get_name() != "headless":
		_screenshots[effect_id] = {"review_sec": _review_time, "cast_id": runner.cast_id, "phase": "first_recovery", "active_progress": 1.0}
		_save_image(String(effect_id))


func _save_image(name: String) -> void:
	_pending_images += 1
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path(Settings.previews_path)
	DirAccess.make_dir_recursive_absolute(directory)
	var error := get_viewport().get_texture().get_image().save_png(directory.path_join(name + ".png"))
	if error != OK: _failures.append("Screenshot could not be saved: " + name)
	_pending_images -= 1


func _finish() -> void:
	while _pending_images > 0: await get_tree().process_frame
	for id in Settings.effect_ids:
		var normal_seen := false
		var slow_seen := false
		var range_hit_seen := false
		for cast in _casts:
			if cast.effect_id != id: continue
			if absf(cast.arc_deg - Settings.expected_arc_deg) > Settings.arc_tolerance_deg: _failures.append("Unexpected attack arc: " + String(id))
			if cast.active_fx_frames == 0: _failures.append("Effect missing active frames: " + String(id))
			if cast.phase == "normal_review": normal_seen = true
			if cast.phase == "slow_review": slow_seen = true
			if cast.phase == "range_hit" and cast.hit_count > 0:
				range_hit_seen = true
				if absf(cast.target_distance_m - Settings.target_distance_m) > Settings.distance_tolerance_m: _failures.append("Range target misplaced: " + String(id))
			if cast.phase != "range_hit" and cast.hit_count > 0: _failures.append("Empty review swing hit an enemy: " + String(id))
		if not normal_seen or not slow_seen or not range_hit_seen: _failures.append("Missing required attack phase or range hit: " + String(id))
		if _capture and DisplayServer.get_name() != "headless" and not _screenshots.has(id): _failures.append("Missing endpoint screenshot: " + String(id))
	var report := {
		"arena": ArenaScene.resource_path,
		"enemy_ai_enabled": false,
		"staging_note": "Enemy decisions paused for comparison; health and combat values come from a fresh real arena per effect. Actor steps, ability timeline, melee resolver, hit response and knockback remain active.",
		"normal_camera_size": Settings.normal_camera_size,
		"close_camera_size": Settings.close_camera_size,
		"slow_scale": Settings.slow_scale,
		"target_distance_m": Settings.target_distance_m,
		"review_duration_sec": _review_time,
		"segments": _segments,
		"casts": _casts,
		"hits": _hits,
		"screenshots": _screenshots,
		"failures": _failures,
	}
	var path := ProjectSettings.globalize_path(Settings.report_path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("Capture report could not be written.")
	else:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("ELEMENTAL_COMBAT_CAPTURE ", JSON.stringify(report))
	Engine.time_scale = _previous_time_scale
	get_tree().quit(0 if _failures.is_empty() else 1)


func _exit_tree() -> void:
	Engine.time_scale = _previous_time_scale
