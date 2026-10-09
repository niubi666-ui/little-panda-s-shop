extends Node3D
## One disposable combat room. Run state and route decisions belong to RunSession.
const Catalog = preload("res://content/combat/combat_catalog.gd")
const Actor = preload("res://combat/actors/combat_actor.gd")
const ActorView = preload("res://presentation/combat/actor_view.gd")
const InputAdapter = preload("res://presentation/combat/combat_input.gd")
const Melee = preload("res://combat/effects/melee_resolver.gd")
const BuildRuntime = preload("res://combat/builds/build_runtime.gd")
const EnemyRuntime = preload("res://combat/enemies/enemy_runtime.gd")
const EnemyView = preload("res://presentation/combat/enemies/enemy_presentation.gd")
const Encounter = preload("res://rogue/training_encounter.gd")
const EncounterPlanner = preload("res://rogue/encounters/encounter_planner.gd")
const Effects = preload("res://presentation/builds/build_effects_view.gd")
const Mechanisms = preload("res://presentation/builds/mechanism_view.gd")
const Style = preload("res://presentation/combat/training_style.tres")
const Shake = preload("res://presentation/combat/hit_camera_shake.gd")
signal cleared(entry_id: String, hp: float)
signal defeated(entry_id: String)
var entry_id := ""
var actors: Array = []
var views: Array = []
var player: Actor
var build_runtime := BuildRuntime.new()
var enemies := EnemyRuntime.new()
var encounter
var active := false
var stopped := false
var _encounter_complete := false
var geometry: Node3D
var camera: Camera3D
var input_adapter
var effects: Node3D
var mechanisms: Node3D
var enemy_view: Node3D
var _melee := Melee.new()
var _combat
var _enemy_catalog
var _presentation: Resource
var _plan: Dictionary
var _font: Font
var _spawns: Array[Vector3] = []
var _next_handle := 0
var _shake := Shake.new()

func setup(ticket: Dictionary, hp: float, program: Dictionary, combat, enemy_catalog, builds, presentation: Resource, theme: Theme) -> bool:
	set_physics_process(false)
	_combat = combat
	_enemy_catalog = enemy_catalog
	_presentation = presentation
	_font = theme.default_font
	_plan = ticket.plan
	entry_id = ticket.id
	geometry = presentation.scene.instantiate()
	add_child(geometry)
	if not geometry.has_method("player_spawn") or not geometry.has_method("enemy_spawns"): return false
	_spawns = geometry.enemy_spawns()
	if not EncounterPlanner.new().validate_plan(_plan.encounter_plan, _spawns.size(), enemy_catalog): return false
	player = _spawn(combat.player(), geometry.player_spawn(), 0)
	if hp <= 0.0 or hp > player.health.maximum: return false
	player.health.current = hp
	player.killed.connect(func(_actor): _finish(false))
	build_runtime.configure(builds, player, func(): return actors, _wall_hit)
	if not build_runtime.set_program(program) or not player.set_action_program(program.actions, combat): return false
	player.set_build_movement_multiplier(program.global.move_scale)
	player.runner.committed.connect(build_runtime.on_committed)
	player.runner.cue_reached.connect(build_runtime.on_cue)
	player.runner.finished.connect(build_runtime.on_finished)
	_melee.set_damage_modifier(build_runtime.melee_damage)
	_melee.enemy_contact.connect(build_runtime.on_melee_contact)
	_melee.confirmed_hit.connect(build_runtime.on_melee_hit)
	_melee.confirmed_hit.connect(func(source, target, _cast, _ability, amount):
		if not stopped and not _encounter_complete and source == player and target.team != player.team and amount > 0.0: _shake.kick())
	build_runtime.damage_applied.connect(func(source, target, amount, _origin):
		if not stopped and not _encounter_complete and source == player and target.team != player.team and amount > 0.0: _shake.kick())
	effects = Effects.new()
	add_child(effects)
	effects.configure(preload("res://presentation/builds/build_effects_style.tres"))
	build_runtime.chain_emitted.connect(effects.show_chain)
	build_runtime.projectile_presented.connect(effects.on_projectile_event)
	build_runtime.action_presented.connect(effects.on_action_event)
	mechanisms = Mechanisms.new()
	add_child(mechanisms)
	mechanisms.configure(preload("res://presentation/builds/mechanism_style.tres"))
	build_runtime.area_presented.connect(mechanisms.show_area_fact)
	enemies.configure(player, _combat.player_hurt_radius(), _origin, _sweep)
	enemy_view = EnemyView.new()
	add_child(enemy_view)
	enemy_view.configure(enemies, Style)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = presentation.camera_size
	add_child(camera)
	camera.make_current()
	_shake.configure(Style.hit_camera_shake)
	_follow_camera()
	input_adapter = InputAdapter.new(player, camera)
	encounter = Encounter.new(_plan.encounter_plan.waves.map(func(wave): return wave.enemy_ids), combat.wave_delay())
	encounter.wave_requested.connect(_spawn_wave)
	encounter.cleared.connect(func(): _finish(true))
	return true
func validate_spawns() -> bool:
	# Validate authored body clearance before publishing the successful entry counter.
	var reserved: Array = [{"point": player.global_position, "radius": Style.actor_presentations.player.body_shape.radius}]
	var player_query := PhysicsShapeQueryParameters3D.new()
	player_query.shape = Style.actor_presentations.player.body_shape
	player_query.transform.origin = _origin(player)
	player_query.collision_mask = 1
	if not get_world_3d().direct_space_state.intersect_shape(player_query, 1).is_empty(): return false
	for wave in _plan.encounter_plan.waves:
		var wave_reserved := reserved.duplicate()
		for index in wave.enemy_ids.size():
			var style: Resource = Style.actor_presentations[wave.enemy_ids[index]]
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = style.body_shape
			query.transform.origin = _spawns[index] + Vector3.UP * style.body_height
			query.collision_mask = 1
			if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return false
			for other in wave_reserved:
				if _spawns[index].distance_to(other.point) <= style.body_shape.radius + other.radius: return false
			wave_reserved.append({"point": _spawns[index], "radius": style.body_shape.radius})
	return true
func activate() -> void:
	if active or stopped: return
	active = true
	encounter.start()
	set_physics_process(true)
func _spawn(definition, point: Vector3, team: int) -> Actor:
	var actor := Actor.new()
	var abilities: Array[Catalog.Ability] = []
	for id in definition.attacks: abilities.append(_combat.ability(id))
	_next_handle += 1
	actor.configure(definition, abilities, _combat.dodge() if team == 0 else null, _next_handle, team)
	actor.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(actor)
	actor.global_position = point
	var collider := CollisionShape3D.new()
	collider.shape = Style.actor_presentations[definition.id].body_shape
	collider.position.y = Style.actor_presentations[definition.id].body_height
	actor.add_child(collider)
	var view := ActorView.new()
	actor.add_child(view)
	view.configure(actor, Style, _font)
	actors.append(actor)
	views.append(view)
	return actor
func _spawn_wave(ids: Array) -> void:
	# Wave boundaries retire their roots and their unfinished action together.
	player.cancel("wave_change")
	build_runtime.clear_room()
	enemies.clear()
	enemy_view.clear()
	for index in range(actors.size() - 1, 0, -1):
		if not actors[index].health.alive() and Style.actor_presentations[actors[index].definition.id].retain_corpse: continue
		actors[index].queue_free()
		actors.remove_at(index)
		views.remove_at(index)
	for index in ids.size():
		var actor := _spawn(_combat.actor(ids[index]), _spawns[index], 1)
		encounter.register_enemy(actor.handle)
		actor.killed.connect(func(dead): encounter.enemy_killed(dead.handle))
		var profile: Dictionary = _enemy_catalog.profile(actor.definition.id)
		var brain = enemies.add(actor, profile, Callable(), _sight, _safe_motion)
		enemy_view.register(brain, views.back(), profile)
func _physics_process(delta: float) -> void:
	if not active or stopped: return
	build_runtime.statuses.tick(delta)
	if not _encounter_complete: enemies.before_motion(delta)
	# Aim is sampled from the authored camera, before presentation-only shake.
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	input_adapter.update()
	for actor in actors: actor.step(delta)
	_melee.resolve(player, actors)
	if not stopped: build_runtime.tick(delta)
	if not stopped and not _encounter_complete:
		enemies.update_auras()
		for actor in actors:
			if actor != player: _melee.resolve(actor, actors)
			if stopped: break
	if not stopped and not _encounter_complete: enemies.after_motion(delta)
	if not stopped and not _encounter_complete: encounter.tick(delta)
	refresh(0.0 if stopped else delta)
func refresh(delta: float) -> void:
	for view in views: view.refresh(delta)
	effects.sync(build_runtime.projectiles(), delta)
	mechanisms.sync(build_runtime.statuses.visuals(), delta)
	enemy_view.refresh()
	_follow_camera()
	var offset := _shake.tick(delta)
	camera.h_offset = offset.x
	camera.v_offset = offset.y
func _finish(won: bool) -> void:
	if stopped: return
	if won and player.health.alive():
		if _encounter_complete: return
		_encounter_complete = true
		_shake.clear()
		encounter.cancel()
		for actor in actors:
			if actor != player: actor.cancel()
		enemies.clear()
		enemy_view.clear()
		# Remain playable until the owner explicitly leaves/disposes this room.
		cleared.emit(entry_id, player.health.current)
		return
	stopped = true
	active = false
	_shake.clear()
	set_physics_process(false)
	for actor in actors: actor.cancel()
	build_runtime.clear_room()
	enemies.clear()
	enemy_view.clear()
	effects.clear()
	mechanisms.clear()
	refresh(0.0)
	defeated.emit(entry_id)
func shutdown() -> void:
	active = false
	stopped = true
	set_physics_process(false)
	for actor in actors:
		if is_instance_valid(actor): actor.cancel()
	build_runtime.clear_room()
	enemies.clear()
	if encounter != null: encounter.cancel()
	if is_instance_valid(effects): effects.clear()
	if is_instance_valid(mechanisms): mechanisms.clear()
	if is_instance_valid(enemy_view): enemy_view.clear()
func pause_visuals() -> void:
	if player != null: player.clear_intents()
	if effects != null: refresh(0.0)
func _unhandled_input(event: InputEvent) -> void:
	if not active or stopped: return
	if event.is_action_pressed("camera_zoom_in"): camera.size = maxf(_presentation.camera_min_size, camera.size - _presentation.camera_zoom_step)
	elif event.is_action_pressed("camera_zoom_out"): camera.size = minf(_presentation.camera_max_size, camera.size + _presentation.camera_zoom_step)
	else: input_adapter.event(event)
func _follow_camera() -> void:
	var bounds: Rect2 = _presentation.camera_follow_bounds
	var point: Vector3 = Vector3(clampf(player.position.x, bounds.position.x, bounds.end.x), 0.0, clampf(player.position.z, bounds.position.y, bounds.end.y)) + _presentation.camera_target_offset
	camera.position = point + _presentation.camera_offset
	camera.look_at(point)
func _origin(actor) -> Vector3:
	return actor.global_position + Vector3.UP * Style.actor_presentations[actor.definition.id].body_height
func _wall_hit(from: Vector3, to: Vector3) -> Variant:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	return null if hit.is_empty() else hit.position
func _sweep(from: Vector3, to: Vector3, radius: float) -> float:
	if radius <= 0.0:
		var hit = _wall_hit(from, to)
		return 1.0 if hit == null or from.is_equal_approx(to) else from.distance_to(hit) / from.distance_to(to)
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform.origin = from
	query.collision_mask = 1
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return 0.0
	query.motion = to - from
	return get_world_3d().direct_space_state.cast_motion(query)[0]
func _sight(source, target) -> bool:
	var radius: float = Style.actor_presentations[source.definition.id].body_shape.radius if _enemy_catalog.profile(source.definition.id).role == "charger" else 0.0
	return _sweep(_origin(source), _origin(target), radius) >= 1.0
func _safe_motion(actor, direction: Vector3) -> bool:
	var radius: float = Style.actor_presentations[actor.definition.id].body_shape.radius
	return _sweep(_origin(actor), _origin(actor) + direction * radius * 2.0, radius) >= 1.0
func _exit_tree() -> void: shutdown()
