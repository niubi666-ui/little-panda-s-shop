extends Node
## Actual training combat with deterministic automatic player intent for review.
## Keeps the arena's default visual effect, lighting, floor and localized HUD.
## Only the initial enemy positions and camera are staged. Damage, knockback,
## death, combo timing and enemy decisions use the normal runtime components.
const ArenaScene = preload("res://rogue/scenes/training_arena.tscn")
const Settings = preload("res://presentation/combat/demos/golden_combat_v001/settings.tres")

var _arena
var _time := 0.0
var _capture := false
var _finishing := false
var _slow := false
var _shots: Dictionary = {}
var _casts: Array[Dictionary] = []
var _hits: Array[Dictionary] = []
var _deaths: Array[Dictionary] = []
var _registered: Dictionary = {}
var _failures: Array[String] = []
var _resolving_source
var _current_cast := -1
var _effect_active_frames := 0
var _opening_attack_requested := false
var _opening_slow_attack_requested := false
var _pending_images := 0
var _previous_time_scale: float

func _ready() -> void:
	assert(Settings.duration_sec > Settings.slow_start_sec and Settings.slow_scale > 0.0)
	assert(Settings.approach_range_ratio > 0.0 and Settings.attack_range_ratio <= 1.0)
	assert(Settings.opening_duration_sec > Settings.start_delay_sec and Settings.opening_enemy_distance_scale >= 1.0)
	assert(Settings.opening_slow_start_sec > Settings.start_delay_sec and Settings.opening_slow_start_sec < Settings.opening_duration_sec)
	assert(not Settings.opening_facing.is_zero_approx())
	_capture = "--capture" in OS.get_cmdline_user_args()
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = 1.0
	_arena = ArenaScene.instantiate()
	add_child(_arena)
	_arena.set_physics_process(false)
	_arena.set_process_unhandled_input(false)
	_arena.player.position = Settings.player_start
	_arena.player.facing = Settings.opening_facing.normalized()
	_arena.player.runner.committed.connect(_on_committed)
	_arena.encounter.wave_requested.connect(_on_wave_spawned)
	_register_and_stage_enemies()
	_arena.get_node("Camera").size = Settings.normal_camera_size
	_arena._follow_camera()
	print("GOLDEN_COMBAT_CAPTURE_READY ", JSON.stringify({
		"arena": ArenaScene.resource_path,
		"effect": _arena.views[0].weapon_effect.scene_file_path,
		"enemy_ai": true,
		"automatic_player_intent": true,
		"staged_enemy_positions": true,
		"opening_empty_swing_sec": Settings.opening_duration_sec,
		"opening_slow_start_sec": Settings.opening_slow_start_sec,
		"duration_sec": Settings.duration_sec,
		"slow_scale": Settings.slow_scale,
	}))

func _on_wave_spawned(_ids: Array) -> void:
	_register_and_stage_enemies()

func _register_and_stage_enemies() -> void:
	var enemy_index := 0
	for actor in _arena.actors:
		if not _registered.has(actor.handle):
			_registered[actor.handle] = true
			actor.health.damaged.connect(_on_damage.bind(actor))
			actor.killed.connect(_on_death)
			if actor.team != 0 and actor.health.alive():
				assert(enemy_index < Settings.enemy_offsets.size())
				var distance_scale: float = Settings.opening_enemy_distance_scale if _arena.encounter.wave_index == 0 else 1.0
				actor.position = _arena.player.position + Settings.enemy_offsets[enemy_index] * distance_scale
		if actor.team != 0 and actor.health.alive():
			enemy_index += 1

func _physics_process(delta: float) -> void:
	if _arena == null or _finishing: return
	# Engine time scale also slows CharacterBody3D, AnimationPlayer and effect _process.
	_time += delta / Engine.time_scale
	var opening_slow := _time >= Settings.opening_slow_start_sec and _time < Settings.opening_duration_sec
	var desired_slow := opening_slow or _time >= Settings.slow_start_sec
	if desired_slow != _slow:
		_slow = desired_slow
		Engine.time_scale = Settings.slow_scale if _slow else 1.0
		_arena.get_node("Camera").size = Settings.close_camera_size if _slow else Settings.normal_camera_size
	if _arena.state not in ["victory", "defeat"]:
		_drive_player()
		for brain in _arena.brains: brain.tick(delta)
		for actor in _arena.actors: actor.step(delta)
		# Match the real arena's player-first resolution and immediate-death ordering.
		for actor in _arena.actors:
			_resolving_source = actor
			_arena.resolver.resolve(actor, _arena.actors)
			if _arena.state in ["victory", "defeat"]: break
		_resolving_source = null
		if _arena.state not in ["victory", "defeat"]:
			_arena.encounter.tick(delta)
			if _arena.encounter.remaining() == 0: _arena.state = "waiting"
	for view in _arena.views: view.refresh(delta)
	_arena._follow_camera()
	_arena.hud.update_state(_arena.player, _arena.encounter, _arena.catalog.waves().size(), _arena.state, false)
	_observe_effect_and_capture()
	if _capture and _time >= Settings.duration_sec:
		_finishing = true
		_finish.call_deferred()

func _drive_player() -> void:
	var player = _arena.player
	player.movement = Vector3.ZERO
	if _time < Settings.start_delay_sec or not player.health.alive(): return
	# Two real opening swings show the trail at normal speed and in a slow close-up.
	# No health, hit feedback or AI is hidden or suspended for this shot.
	if _time < Settings.opening_duration_sec:
		player.facing = Settings.opening_facing.normalized()
		if not _opening_attack_requested:
			player.request_attack()
			_opening_attack_requested = true
		if _time >= Settings.opening_slow_start_sec and not _opening_slow_attack_requested:
			player.request_attack()
			_opening_slow_attack_requested = true
		return
	var target
	var nearest := INF
	for actor in _arena.actors:
		if actor.team == player.team or not actor.health.alive(): continue
		var distance: float = player.global_position.distance_to(actor.global_position)
		if distance < nearest:
			nearest = distance
			target = actor
	if target == null: return
	var offset: Vector3 = target.global_position - player.global_position
	offset.y = 0.0
	if not offset.is_zero_approx(): player.facing = offset.normalized()
	var next_ability = player.attacks[player.combo_index]
	if nearest > next_ability.radius * Settings.approach_range_ratio:
		player.movement = player.facing
	if nearest <= next_ability.radius * Settings.attack_range_ratio:
		player.request_attack()

func _on_committed(cast_id: int, ability_id: String) -> void:
	var ability = _arena.catalog.ability(ability_id)
	_current_cast = _casts.size()
	_casts.append({
		"cast_id": cast_id,
		"ability_id": ability_id,
		"arc_deg": rad_to_deg(ability.angle),
		"radius_m": ability.radius,
		"start_review_sec": _time,
		"opening_empty_swing": _time < Settings.opening_duration_sec,
		"time_scale": Engine.time_scale,
		"hit_count": 0,
		"damage_applied": 0.0,
		"active_fx_frames": 0,
	})

func _on_damage(amount: float, target) -> void:
	if _resolving_source == null:
		_failures.append("Damage arrived outside the real resolver pass")
		return
	var source = _resolving_source
	_hits.append({
		"source_handle": source.handle,
		"target_handle": target.handle,
		"target_id": target.definition.id,
		"cast_id": source.runner.cast_id,
		"ability_id": source.runner.ability.id,
		"amount": amount,
		"target_hp": target.health.current,
		"review_sec": _time,
	})
	if source == _arena.player and _current_cast >= 0:
		_casts[_current_cast].hit_count += 1
		_casts[_current_cast].damage_applied += amount

func _on_death(actor) -> void:
	_deaths.append({"handle": actor.handle, "actor_id": actor.definition.id, "review_sec": _time})

func _observe_effect_and_capture() -> void:
	var runner = _arena.player.runner
	var effect = _arena.views[0].weapon_effect
	if _capture and _slow and _time < Settings.opening_duration_sec and runner.phase() == "recovery" and not _shots.has("opening_slow_sweep") and DisplayServer.get_name() != "headless":
		# The first recovery pose is the authored 160-degree endpoint, with its tail intact.
		_shots["opening_slow_sweep"] = {"review_sec": _time, "cast_id": runner.cast_id, "active_progress": 1.0, "phase": "first_recovery"}
		_save_image("opening_slow_sweep")
	if runner.phase() != "active": return
	if not is_instance_valid(effect):
		_failures.append("Default weapon effect missing during attack")
		return
	_effect_active_frames += 1
	if _current_cast >= 0: _casts[_current_cast].active_fx_frames += 1
	if not _capture or DisplayServer.get_name() == "headless": return
	var progress: float = (runner.elapsed - runner.ability.windup) / runner.ability.active
	var shot_name: String = runner.ability.id.replace(".", "_") + ("_slow" if _slow else "_normal")
	if _time < Settings.opening_duration_sec:
		if _slow: return
		shot_name = "opening_empty_swing"
	if progress >= Settings.screenshot_active_progress and not _shots.has(shot_name):
		_shots[shot_name] = {"review_sec": _time, "cast_id": runner.cast_id, "active_progress": progress}
		_save_image(shot_name)

func _save_image(shot_name: String) -> void:
	_pending_images += 1
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path(Settings.previews_path)
	DirAccess.make_dir_recursive_absolute(directory)
	var error := get_viewport().get_texture().get_image().save_png(directory.path_join(shot_name + ".png"))
	if error != OK: _failures.append("Screenshot save failed: " + shot_name)
	_pending_images -= 1

func _finish() -> void:
	while _pending_images > 0: await get_tree().process_frame
	var seen: Dictionary = {}
	var player_hit_count := 0
	var opening_count := 0
	for cast in _casts:
		seen[cast.ability_id] = true
		player_hit_count += cast.hit_count
		if absf(cast.arc_deg - Settings.expected_arc_deg) > Settings.arc_tolerance_deg:
			_failures.append("Unexpected attack arc: " + cast.ability_id)
		if cast.opening_empty_swing:
			opening_count += 1
			if cast.hit_count > 0: _failures.append("Opening review swing unexpectedly hit an enemy")
	if opening_count != 2: _failures.append("Expected two real opening review swings")
	for id in _arena.player.definition.attacks:
		if not seen.has(id): _failures.append("Missing combo attack: " + id)
	if player_hit_count == 0: _failures.append("No real player damage resolved")
	if _effect_active_frames == 0: _failures.append("No active effect frames")
	var report := {
		"arena": ArenaScene.resource_path,
		"default_effect_scene": _arena.views[0].weapon_effect.scene_file_path,
		"default_effect_script": _arena.views[0].weapon_effect.get_script().resource_path,
		"enemy_ai_enabled": true,
		"staged_enemy_positions": true,
		"opening_empty_swing_sec": Settings.opening_duration_sec,
		"opening_slow_start_sec": Settings.opening_slow_start_sec,
		"opening_facing": [Settings.opening_facing.x, Settings.opening_facing.y, Settings.opening_facing.z],
		"opening_enemy_distance_scale": Settings.opening_enemy_distance_scale,
		"normal_camera_size": Settings.normal_camera_size,
		"close_camera_size": Settings.close_camera_size,
		"slow_start_sec": Settings.slow_start_sec,
		"slow_scale": Settings.slow_scale,
		"review_duration_sec": _time,
		"final_state": _arena.state,
		"player_hp": _arena.player.health.current,
		"casts": _casts,
		"hits": _hits,
		"deaths": _deaths,
		"screenshots": _shots,
		"effect_active_frames": _effect_active_frames,
		"failures": _failures,
	}
	var path := ProjectSettings.globalize_path(Settings.report_path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("Cannot write capture report")
	else:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("GOLDEN_COMBAT_CAPTURE ", JSON.stringify(report))
	Engine.time_scale = _previous_time_scale
	get_tree().quit(0 if _failures.is_empty() else 1)

func _exit_tree() -> void:
	Engine.time_scale = _previous_time_scale
