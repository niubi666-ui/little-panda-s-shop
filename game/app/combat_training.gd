extends Node3D
## Ephemeral training composition root. Build and loot sessions do not write real saves.
const Loader = preload("res://content/combat/combat_loader.gd")
const Catalog = preload("res://content/combat/combat_catalog.gd")
const Actor = preload("res://combat/actors/combat_actor.gd")
const View = preload("res://presentation/combat/actor_view.gd")
const InputAdapter = preload("res://presentation/combat/combat_input.gd")
const HUD = preload("res://presentation/combat/combat_hud.gd")
const Brain = preload("res://combat/ai/melee_brain.gd")
const Resolver = preload("res://combat/effects/melee_resolver.gd")
const Encounter = preload("res://rogue/training_encounter.gd")
const Style = preload("res://presentation/combat/training_style.tres")
const ThemeFactory = preload("res://presentation/foliage/foliage_theme_factory.gd")
const EffectPalette = preload("res://presentation/combat/effect_picker/palette.tres")
const CameraShake = preload("res://presentation/combat/hit_camera_shake.gd")
const TrainingBuilds = preload("res://app/training_builds.gd")
const TrainingTools = preload("res://app/training_tools.gd")
const TrainingSkillVfx = preload("res://app/training_skill_vfx.gd")
const SkillVfxStyle = preload("res://presentation/combat/skill_vfx_picker/style.tres")
const RoomPresentation = preload("res://presentation/rooms/room_presentation.gd")
const SceneTransition = preload("res://app/scene_transition.gd")
const TrainingRoomProps = preload("res://app/training_room_props.gd")
const EnemyLoader = preload("res://content/enemies/enemy_loader.gd")
const EnemyRuntime = preload("res://combat/enemies/enemy_runtime.gd")
const EncounterPlanner = preload("res://rogue/encounters/encounter_planner.gd")
const EnemyPresentation = preload("res://presentation/combat/enemies/enemy_presentation.gd")
signal enemy_loot_ready(spawn_id: String, enemy_id: String, drops: Array)
var initial_encounter_plan: Dictionary = {}
var encounter_plan: Dictionary = {}
var encounter_depth := 0
var enemy_catalog
var enemy_runtime := EnemyRuntime.new()
var enemy_presentation: Node3D
var _waves: Array = []
var initial_room_plan: Dictionary = {}
var room_props: TrainingRoomProps
@export var room_presentation: RoomPresentation
var room: Node3D
var _player_spawn: Vector3
var _enemy_spawns: Array[Vector3] = []
var _previous_taa := false
@export var build_choices_enabled := true
@export var enable_mechanism_presets := false
@export var test_hint_key := "build.test.arrow_hint"
@export var test_attack_ids: Array[String] = []
@export var build_effects_style: Resource = preload("res://presentation/builds/build_effects_style.tres")
@export var mechanism_style: Resource = preload("res://presentation/builds/mechanism_style.tres")
var builds: TrainingBuilds
var training_tools: TrainingTools
var _managed_ranger
var _ranger_sequence := 0
var _ordinary_complete := false
var skill_vfx: TrainingSkillVfx
var catalog: Catalog
var player: Actor
var actors: Array = []
var brains: Array = []
var views: Array = []
var encounter: Encounter
var input_adapter: InputAdapter
var hud: HUD
var resolver := Resolver.new()
var state := "fighting"
var paused := false
var _next_handle := 0
var _leaving := false
var _transition: Node
var shared_theme: Theme
var pause_menu
var selected_effect_id: StringName
var _camera_shake := CameraShake.new()
func _ready() -> void:
	if room_presentation != null:
		assert(room_presentation.scene != null and not room_presentation.template_id.is_empty())
		assert(room_presentation.camera_min_size > 0.0 and room_presentation.camera_size >= room_presentation.camera_min_size and room_presentation.camera_max_size >= room_presentation.camera_size)
		_previous_taa = get_viewport().use_taa
		get_viewport().use_taa = room_presentation.temporal_antialiasing
		room = room_presentation.scene.instantiate()
		add_child(room)
		_player_spawn = to_local(room.player_spawn())
		for point in room.enemy_spawns(): _enemy_spawns.append(to_local(point))
	else:
		# Original geometry remains an isolated combat regression fixture.
		_player_spawn = $PlayerSpawn.position
		for marker in $EnemySpawns.get_children(): _enemy_spawns.append(marker.position)
	_camera_shake.configure(Style.hit_camera_shake)
	resolver.confirmed_hit.connect(_on_confirmed_hit)
	var loader := Loader.new()
	catalog = loader.load_catalog()
	if catalog == null:
		for error in loader.errors: push_error(error)
		get_tree().quit(1)
		return
	var enemy_loader := EnemyLoader.new()
	enemy_catalog = enemy_loader.load_catalog(catalog)
	if enemy_catalog == null:
		for error in enemy_loader.errors: push_error(error)
		get_tree().quit(1)
		return
	var used_actor_ids: Array = [catalog.player().id]
	used_actor_ids.append_array(enemy_catalog.profiles.keys())
	for id in used_actor_ids:
		if not Style.actor_presentations.has(id) or Style.actor_presentations[id].visual_scene == null or Style.actor_presentations[id].body_shape == null:
			push_error("Training presentation missing visual/body: " + id)
			get_tree().quit(1)
			return
	for wave in catalog.waves():
		if wave.size() > _enemy_spawns.size():
			push_error("Training arena: encounter exceeds authored spawn capacity")
			get_tree().quit(1)
			return
	for language in ["zh_CN", "en"]:
		TranslationServer.add_translation(load("res://generated/locales/%s.po" % language))
	shared_theme = ThemeFactory.create()
	if has_node("UIRoot/ArrowHint"):
		$UIRoot/ArrowHint.theme = shared_theme
		$UIRoot/ArrowHint.text = tr(test_hint_key)
	player = _spawn(catalog.player(), _player_spawn, 0)
	player.killed.connect(func(_actor): _finish("defeat"))
	if room_presentation != null and room_presentation.placement_surface != null:
		room_props = TrainingRoomProps.new()
		add_child(room_props)
		if not room_props.configure(room, player, $UIRoot, shared_theme, room_presentation.placement_surface, room_presentation.prop_visuals, initial_room_plan, _actor_query_origin):
			set_physics_process(false)
			get_tree().quit(1)
			return
		room_props.new_layout_requested.connect(_new_layout)
		resolver.set_hit_filter(room_props.has_clear_path)
	_waves = catalog.waves()
	if room_presentation != null:
		if encounter_depth == 0: encounter_depth = int(enemy_catalog.encounters.training_depth)
		var seed_value := str(room_props.plan.seed) if room_props != null else str(randi())
		encounter_plan = initial_encounter_plan.duplicate(true) if not initial_encounter_plan.is_empty() else EncounterPlanner.new().generate(seed_value, encounter_depth, _enemy_spawns.size(), enemy_catalog)
		if not EncounterPlanner.new().validate_plan(encounter_plan, _enemy_spawns.size(), enemy_catalog):
			push_error("Invalid or incompatible encounter plan")
			get_tree().quit(1)
			return
		encounter_depth = int(encounter_plan.depth)
		_waves = encounter_plan.waves.map(func(wave): return wave.enemy_ids)
	enemy_runtime.configure(player, catalog.player_hurt_radius(), _actor_query_origin, _enemy_sweep)
	enemy_presentation = EnemyPresentation.new()
	add_child(enemy_presentation)
	enemy_presentation.configure(enemy_runtime, Style, $Camera, room.rift_surfaces() if room!=null and room.has_method("rift_surfaces") else [])
	$Camera.size = room_presentation.camera_size if room_presentation != null else Style.camera_size
	_follow_camera()
	input_adapter = InputAdapter.new(player, $Camera, _gameplay_ui_blocked)
	encounter = Encounter.new(_waves, catalog.wave_delay())
	encounter.wave_requested.connect(_spawn_wave)
	encounter.cleared.connect(func(): _finish("victory"))
	hud = HUD.new()
	$UIRoot.add_child(hud)
	hud.configure(shared_theme, Style.hud_margin)
	if not encounter_plan.is_empty():
		hud.configure_encounters(encounter_depth, enemy_catalog.encounters.training_max_depth, Style.encounter_panel_position)
		hud.encounter_requested.connect(_new_encounter)
	for option in EffectPalette.options:
		if option.scene == Style.weapon_effect_scene:
			selected_effect_id = option.id
	assert(not selected_effect_id.is_empty(), "Default weapon effect must be listed in the training palette")
	hud.configure_effect_picker(EffectPalette, selected_effect_id)
	hud.weapon_effect_selected.connect(_select_weapon_effect)
	hud.retry_requested.connect(_retry)
	hud.return_requested.connect(_return)
	hud.resume_requested.connect(func(): paused = false)
	builds = TrainingBuilds.new()
	add_child(builds)
	if not builds.configure(player, func(): return actors, _build_wall_hit, $UIRoot, shared_theme, self, catalog, build_choices_enabled, test_attack_ids, enable_mechanism_presets, build_effects_style, mechanism_style):
		get_tree().quit(1)
		return
	resolver.set_damage_modifier(builds.runtime.melee_damage)
	hud.place_encounters_below(builds.status_panel)
	resolver.confirmed_hit.connect(builds.runtime.on_melee_hit)
	resolver.enemy_contact.connect(builds.runtime.on_melee_contact)
	builds.damage_applied.connect(_on_build_damage)
	encounter.wave_completed.connect(builds.reward_wave)
	encounter.start()
	builds.flush_offers()
	pause_menu = preload("res://app/pause_menu.gd").new()
	add_child(pause_menu)
	pause_menu.configure(shared_theme)
	pause_menu.open_requested.connect(_open_pause_menu)
	pause_menu.closed.connect(func():
		hud.refresh_text()
		builds.refresh_text()
		training_tools.refresh_text()
		skill_vfx.refresh_text()
		skill_vfx.refresh()
		training_tools.panel.set_blocked(builds.is_choosing())
		if has_node("UIRoot/ArrowHint"): $UIRoot/ArrowHint.text = tr(test_hint_key))
	training_tools = TrainingTools.new()
	add_child(training_tools)
	var panels := {"build": builds.status_panel, "fx": hud.effect_picker}
	if hud.encounter_panel != null: panels["depth"] = hud.encounter_panel
	if room_props != null: panels["room"] = room_props.hud
	training_tools.configure(player, func(): return actors, _training_tools_available, $UIRoot, shared_theme, panels, _set_training_hud_visible)
	training_tools.configure_reinforcements(enemy_catalog, str(encounter_plan.get("seed", "fixture")), encounter_depth if encounter_depth > 0 else int(enemy_catalog.encounters.training_depth), _enemy_spawns, _training_spawn_clear, _append_training_wave)
	training_tools.panel.ranger_requested.connect(_refresh_ranger)
	builds.choice_panel.visibility_changed.connect(func(): training_tools.panel.set_blocked(builds.is_choosing()))
	training_tools.panel.set_blocked(builds.is_choosing())
	skill_vfx = TrainingSkillVfx.new()
	add_child(skill_vfx)
	skill_vfx.configure(self, player, func(): return player.facing, func(): return _training_tools_available() and not _gameplay_ui_blocked(), $UIRoot, shared_theme, SkillVfxStyle)
	$UIRoot.move_child(skill_vfx.panel, builds.choice_panel.get_index())
	if room_props != null:
		skill_vfx.panel.set_right_column_reserved(room_props.hud.visible)
		room_props.hud.visibility_changed.connect(func(): skill_vfx.panel.set_right_column_reserved(room_props.hud.visible))
	# The existing effects visibility group owns both visual rehearsal surfaces.
	hud.effect_picker.visibility_changed.connect(func(): skill_vfx.panel.visible = hud.effect_picker.visible)
	builds.choice_panel.visibility_changed.connect(skill_vfx.refresh)
	print("[combat] training ready; waves=", _waves.size(), " encounter=", encounter_plan.get("seed", "fixture"))
func _select_weapon_effect(effect_id: StringName) -> void:
	if _leaving or (builds != null and builds.is_choosing()) or effect_id == selected_effect_id: return
	for option in EffectPalette.options:
		if option.id != effect_id: continue
		views[0].set_weapon_effect(option.scene)
		var effect = views[0].weapon_effect
		effect.set_time_running(not paused)
		effect.set_active(player.health.alive() and player.runner.phase() == "active")
		if effect.has_method("sample_current_pose"): effect.sample_current_pose()
		selected_effect_id = effect_id
		hud.effect_picker.set_selected(effect_id)
		return
func _actor_query_origin(actor) -> Vector3:
	return actor.global_position + Vector3.UP * Style.actor_presentations[actor.definition.id].body_height
func _spawn(definition: Catalog.Actor, point: Vector3, team: int) -> Actor:
	var actor := Actor.new()
	_next_handle += 1
	var abilities: Array[Catalog.Ability] = []
	for id in definition.attacks: abilities.append(catalog.ability(id))
	actor.configure(definition, abilities, catalog.dodge() if team == 0 else null, _next_handle, team)
	if training_tools != null: training_tools.prepare_actor(actor)
	actor.name = "Actor_%s" % _next_handle
	actor.position = point
	actor.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	shape.shape = Style.actor_presentations[definition.id].body_shape
	shape.position.y = Style.actor_presentations[definition.id].body_height
	actor.add_child(shape)
	var parent: Node3D = $RunActors if team == 0 else $RoomActors
	parent.add_child(actor)
	var view := View.new()
	actor.add_child(view)
	view.configure(actor, Style, shared_theme.default_font)
	actors.append(actor)
	views.append(view)
	return actor
func _spawn_wave(ids: Array) -> void:
	if builds != null: builds.clear_room()
	enemy_runtime.remove_dead()
	if enemy_presentation != null: enemy_presentation.remove_dead()
	# Ordinary corpses are disposable; retained elite corpses live until room exit.
	for index in range(actors.size() - 1, 0, -1):
		if not actors[index].health.alive() and not Style.actor_presentations[actors[index].definition.id].retain_corpse:
			actors[index].queue_free()
			actors.remove_at(index)
			views.remove_at(index)
	brains = enemy_runtime.brains.duplicate()
	for index in ids.size():
		var actor := _spawn(catalog.actor(ids[index]), _enemy_spawns[index], 1)
		encounter.register_enemy(actor.handle)
		var drops: Array = encounter_plan.waves[encounter.wave_index].drops[index].duplicate(true) if not encounter_plan.is_empty() else []
		var spawn_id := "%s:%s:%s:%s" % [encounter_plan.get("seed", "fixture"), encounter_depth, encounter.wave_index, index]
		actor.killed.connect(func(dead):
			enemy_loot_ready.emit(spawn_id, dead.definition.id, drops.duplicate(true))
			encounter.enemy_killed(dead.handle))
		_register_enemy_brain(actor)
	state = "fighting"
func _register_enemy_brain(actor) -> void:
	var route: Callable = room_props.movement_towards if room_props != null else Callable()
	var queries := {"roll_path":_ranger_roll_path,"ground":_ranger_ground,"rain_escape":_ranger_rain_escape,"seed":(str(encounter_plan.get("seed", "fixture")) + ":ranger:" + str(_ranger_sequence)).sha256_text().substr(0, 15).hex_to_int()}
	var brain = enemy_runtime.add(actor, enemy_catalog.profile(actor.definition.id), route, _enemy_sight, _enemy_safe_motion, queries)
	brains.append(brain)
	enemy_presentation.register(brain, views[actors.find(actor)], enemy_catalog.profile(actor.definition.id))

func _ranger_ground(point: Vector3) -> bool:
	var radius: float = Style.actor_presentations.elite_ranger.body_shape.radius
	return room_props != null and room_props.allows_training_spawn(point, radius)

func _ranger_rain_escape(hazards: Array, settings: Dictionary) -> bool:
	# Conservative admission: reserve one straight, full-body route out of all circles.
	# A rejected cast is skipped, never repositioned on top of a wall or the player.
	if room_props == null: return false
	var radius: float = Style.actor_presentations.player.body_shape.radius
	var reach: float = player.definition.speed * (settings.rain_delay_sec - settings.rain_escape_margin_sec)
	var space := get_world_3d().direct_space_state
	for i in int(settings.rain_escape_directions):
		var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * float(i) / settings.rain_escape_directions)
		var distance_m := 0.0
		for hazard in hazards:
			var relative: Vector3 = hazard.center - player.global_position
			relative.y = 0.0
			var along := relative.dot(direction)
			var across_sq := relative.length_squared() - along * along
			var inflated: float = hazard.radius + catalog.player_hurt_radius() + settings.rain_escape_clearance_m
			if across_sq < inflated * inflated:
				distance_m = maxf(distance_m, along + sqrt(inflated * inflated - across_sq))
		if distance_m > reach: continue
		var motion := direction * distance_m
		var point: Vector3 = player.global_position + motion
		if not room_props.allows_training_spawn(point, radius): continue
		var crosses_danger := false
		for hazard in hazards:
			if not hazard.active: continue
			var center: Vector3 = hazard.center
			center.y = point.y
			var safe_radius: float = hazard.radius + catalog.player_hurt_radius()
			# Allow exiting the circle the player already occupies, not routing through another active one.
			if player.global_position.distance_to(center) <= safe_radius: continue
			if Geometry3D.get_closest_point_to_segment(center, player.global_position, point).distance_to(center) <= safe_radius:
				crosses_danger = true
				break
		if crosses_danger: continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = Style.actor_presentations.player.body_shape
		query.transform.origin = _actor_query_origin(player)
		query.collision_mask = Actor.BodyLayer.WORLD
		query.motion = motion
		if space.intersect_shape(query, 1).is_empty() and space.cast_motion(query)[0] >= 1.0: return true
	return false

func _ranger_roll_path(actor, motion: Vector3) -> bool:
	if not _ranger_ground(actor.global_position + motion): return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = Style.actor_presentations[actor.definition.id].body_shape
	query.transform.origin = _actor_query_origin(actor)
	query.collision_mask = Actor.BodyLayer.WORLD | Actor.BodyLayer.PLAYER
	query.motion = motion
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return false
	return space.cast_motion(query)[0] >= 1.0

func _refresh_ranger() -> bool:
	if not _training_tools_available(): return false
	var panel = training_tools.panel
	var rules: Dictionary = enemy_catalog.encounters.training_tools
	var alive := 0
	for actor in actors:
		if actor.team != player.team and actor.health.alive() and actor != _managed_ranger: alive += 1
	if alive + 1 > int(rules.max_alive_enemies):
		panel.set_notice("training.tools.limit", {"max":int(rules.max_alive_enemies)})
		return false
	var appearance: Resource = Style.actor_presentations.get("elite_ranger")
	var ranger_scene: PackedScene = appearance.visual_scene
	if ranger_scene == null or not ranger_scene.can_instantiate():
		panel.set_notice("training.tools.unavailable")
		return false
	var visual_candidate := ranger_scene.instantiate()
	var valid_visual: bool = visual_candidate.has_method("validate_assets") and visual_candidate.validate_assets()
	visual_candidate.free()
	if not valid_visual:
		panel.set_notice("training.tools.unavailable")
		return false
	var positions: Array[Vector3] = []
	var steps := int(floor(rules.spawn_search_radius_m / rules.spawn_step_m))
	for x in range(-steps, steps + 1):
		for z in range(-steps, steps + 1):
			var offset := Vector3(x,0,z) * float(rules.spawn_step_m)
			if offset.length() <= rules.spawn_search_radius_m: positions.append(offset)
	positions.sort_custom(func(a,b): return a.length_squared() < b.length_squared())
	var spawn_point: Variant = null
	for offset in positions:
		for anchor in _enemy_spawns:
			if _training_spawn_clear(anchor + offset, "elite_ranger", []):
				spawn_point = anchor + offset
				break
		if spawn_point != null: break
	if spawn_point == null:
		panel.set_notice("training.tools.no_space")
		return false
	# All admission checks precede mutation; the previous managed actor stays intact on failure.
	var candidate := _spawn(catalog.actor("elite_ranger"), spawn_point, 1)
	_register_enemy_brain(candidate)
	if is_instance_valid(_managed_ranger) and _managed_ranger.health.alive():
		enemy_runtime.remove_actor(_managed_ranger)
		enemy_presentation.remove_actor(_managed_ranger)
		if room_props != null: room_props.forget_actor(_managed_ranger.handle)
		var index := actors.find(_managed_ranger)
		if index >= 0:
			actors.remove_at(index)
			views.remove_at(index)
		_managed_ranger.get_parent().remove_child(_managed_ranger)
		_managed_ranger.queue_free()
	_managed_ranger = candidate
	_ranger_sequence += 1
	brains = enemy_runtime.brains.duplicate()
	candidate.killed.connect(func(dead):
		enemy_runtime.remove_actor(dead)
		if _ordinary_complete: _finish("victory"))
	if state == "victory":
		_ordinary_complete = true
		builds.resume_training()
	state = "fighting"
	panel.set_notice("training.tools.ranger_ready")
	return true
func _training_tools_available() -> bool:
	return not _leaving and not is_instance_valid(_transition) and not paused and not get_tree().paused and not builds.is_choosing() and player.health.alive()
func _set_training_hud_visible(shown: bool) -> void:
	hud.set_training_hud_visible(shown)
	if has_node("UIRoot/ArrowHint"): $UIRoot/ArrowHint.visible = shown
func _training_spawn_clear(point: Vector3, id: String, reserved: Array) -> bool:
	var presentation = Style.actor_presentations[id]
	var radius: float = presentation.body_shape.radius
	var world_point := to_global(point)
	if room_props != null:
		if not room_props.allows_training_spawn(world_point, radius): return false
	elif not _enemy_spawns.has(point):
		# The graybox fixture has no authored navigation surface to validate offsets.
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = presentation.body_shape
	query.transform.origin = world_point + Vector3.UP * presentation.body_height
	query.collision_mask = 1
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return false
	for actor in actors:
		if not actor.health.alive(): continue
		var separation: Vector3 = actor.global_position - world_point
		separation.y = 0.0
		if separation.length() <= radius + Style.actor_presentations[actor.definition.id].body_shape.radius: return false
	for entry in reserved:
		if point.distance_to(entry.point) <= radius + Style.actor_presentations[entry.actor_id].body_shape.radius: return false
	return true
func _append_training_wave(ids: Array, placements: Array) -> void:
	# Preserve live enemies, retained corpses and build; retire dead attack runtimes.
	enemy_runtime.remove_dead()
	enemy_presentation.remove_dead()
	for index in range(actors.size() - 1, 0, -1):
		if not actors[index].health.alive() and not Style.actor_presentations[actors[index].definition.id].retain_corpse:
			if room_props != null: room_props.forget_actor(actors[index].handle)
			actors[index].queue_free()
			actors.remove_at(index)
			views.remove_at(index)
	brains = enemy_runtime.brains.duplicate()
	if state == "victory":
		encounter.reopen_for_training()
		builds.resume_training()
	for index in ids.size():
		var actor := _spawn(catalog.actor(ids[index]), placements[index].point, 1)
		encounter.register_enemy(actor.handle)
		# Practice additions deliberately have no loot/reward identity.
		actor.killed.connect(func(dead): encounter.enemy_killed(dead.handle))
		_register_enemy_brain(actor)
	state = "fighting"
func _physics_process(delta: float) -> void:
	if catalog == null or _leaving: return
	training_tools.refresh()
	if not paused and not builds.is_choosing() and state != "defeat":
		# Aim/movement use the stable camera, never the previous display shake.
		$Camera.h_offset = 0.0
		$Camera.v_offset = 0.0
		input_adapter.update()
		builds.before_motion(delta)
		enemy_runtime.before_motion(delta)
		for actor in actors: actor.step(delta)
		if room_props != null: room_props.resolve_attack()
		# Resolve the player's committed effects before enemy hit windows. The build
		# queue is stepped exactly once, so control cancellation cannot double its budget.
		resolver.resolve(player, actors)
		if state != "defeat":
			builds.step(delta)
			enemy_runtime.update_auras()
		if state not in ["victory", "defeat"]:
			for actor in actors:
				if actor == player: continue
				resolver.resolve(actor, actors)
				if state in ["victory", "defeat"]: break
		if state not in ["victory", "defeat"]:
			enemy_runtime.after_motion(delta)
			enemy_runtime.update_auras()
		if state not in ["victory", "defeat"]:
			encounter.tick(delta)
			if encounter.remaining() == 0: state = "waiting"
	if room_props != null: room_props.refresh(not paused and not builds.is_choosing() and state != "defeat")
	if state == "defeat":
		builds.finish()
	else:
		builds.flush_offers()
	skill_vfx.refresh()
	var display_delta := 0.0 if paused or builds.is_choosing() else delta
	for view in views: view.refresh(display_delta)
	enemy_presentation.refresh(display_delta)
	builds.refresh(display_delta)
	_follow_camera()
	_apply_camera_shake(display_delta)
	hud.update_state(player, encounter, _waves.size(), "choosing" if builds.is_choosing() else state, paused and not builds.is_choosing())
	if not encounter_plan.is_empty(): hud.update_encounter(encounter_plan, encounter.wave_index)
func _enemy_sight(source, target) -> bool:
	if enemy_catalog.profile(source.definition.id).role == "charger":
		# A centre ray can pass a pillar while the capsule cannot. Check the
		# whole body against world geometry before committing to a straight dash.
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = Style.actor_presentations[source.definition.id].body_shape
		query.transform.origin = _actor_query_origin(source)
		query.collision_mask = 1
		query.motion = target.global_position - source.global_position
		query.motion.y = 0.0
		var space := get_world_3d().direct_space_state
		if not space.intersect_shape(query, 1).is_empty(): return false
		if space.cast_motion(query)[0] < 1.0: return false
	if room_props != null: return room_props.has_clear_path(source, target)
	return _enemy_sweep(_actor_query_origin(source), _actor_query_origin(target), 0.0) >= 1.0
func _enemy_sweep(from: Vector3, to: Vector3, radius: float) -> float:
	var space := get_world_3d().direct_space_state
	if radius <= 0.0:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
		var length := from.distance_to(to)
		return 1.0 if hit.is_empty() or is_zero_approx(length) else from.distance_to(hit.position) / length
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform.origin = from
	query.collision_mask = 1
	if not space.intersect_shape(query, 1).is_empty(): return 0.0
	query.motion = to - from
	return space.cast_motion(query)[0]
func _enemy_safe_motion(actor, direction: Vector3) -> bool:
	var radius: float = Style.actor_presentations[actor.definition.id].body_shape.radius
	var from := _actor_query_origin(actor)
	return _enemy_sweep(from, from + direction * radius * 2.0, radius) >= 1.0
func _build_wall_hit(from: Vector3, to: Vector3) -> Variant:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else null
func _on_build_damage(source, target, amount: float, _origin: String) -> void:
	_on_confirmed_hit(source, target, 0, "", amount)
func _follow_camera() -> void:
	if room_presentation == null:
		$Camera.position = player.position + Style.camera_offset
		$Camera.look_at(player.position)
		return
	var bounds := room_presentation.camera_follow_bounds
	var center := Vector3(clampf(player.position.x, bounds.position.x, bounds.end.x), 0.0, clampf(player.position.z, bounds.position.y, bounds.end.y))
	var target := center + room_presentation.camera_target_offset
	$Camera.position = target + room_presentation.camera_offset
	$Camera.look_at(target)
func _on_confirmed_hit(source, target, _cast_id: int, _ability_id: String, applied_damage: float) -> void:
	if not _leaving and source == player and target.team != player.team and applied_damage > 0.0:
		_camera_shake.kick()
func _apply_camera_shake(delta: float) -> void:
	var offset := _camera_shake.tick(delta)
	$Camera.h_offset = offset.x
	$Camera.v_offset = offset.y
func _open_pause_menu() -> void:
	if _leaving or is_instance_valid(_transition): return
	player.cancel()
	for view in views: view.refresh(0.0)
	builds.refresh(0.0)
	training_tools.panel.set_blocked(true)
	skill_vfx.set_time_running(false)
	pause_menu.open()

func _unhandled_input(event: InputEvent) -> void:
	if catalog == null or _leaving: return
	if _gameplay_ui_blocked():
		player.clear_intents()
		return
	if event.is_action_pressed("toggle_language"):
		TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("zh") else "zh_CN")
		hud.refresh_text()
		builds.refresh_text()
		training_tools.refresh_text()
		skill_vfx.refresh_text()
		if has_node("UIRoot/ArrowHint"): $UIRoot/ArrowHint.text = tr(test_hint_key)
	elif builds.is_choosing():
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and room_props != null and not paused and state != "defeat":
		room_props.search_nearest()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_zoom_in"):
		var camera_style = room_presentation if room_presentation != null else Style
		$Camera.size = maxf(camera_style.camera_min_size, $Camera.size - camera_style.camera_zoom_step)
	elif event.is_action_pressed("camera_zoom_out"):
		var camera_style = room_presentation if room_presentation != null else Style
		$Camera.size = minf(camera_style.camera_max_size, $Camera.size + camera_style.camera_zoom_step)
	elif not paused and state != "defeat":
		if state == "fighting" and builds.handle_test_input(event):
			get_viewport().set_input_as_handled()
		else:
			input_adapter.event(event)
func _gameplay_ui_blocked() -> bool:
	# Explicitly supplied UI surfaces: PopupMenu is a Window, not a Control focus owner.
	if builds != null and builds.status_panel != null:
		if builds.status_panel.has_open_popup(): return true
	if training_tools != null and training_tools.panel != null:
		if training_tools.panel.has_open_popup(): return true
	return false
func _finish(result: String) -> void:
	if state == "defeat" or (state == "victory" and result == "victory"): return
	if result == "victory":
		_ordinary_complete = true
		if is_instance_valid(_managed_ranger) and _managed_ranger.health.alive(): return
	state = result
	if result == "defeat" and skill_vfx != null: skill_vfx.clear()
	encounter.cancel()
	for actor in actors:
		if result == "defeat" or actor != player: actor.cancel()
	if result == "victory": builds.finish_rewards()
	enemy_runtime.clear()
	if enemy_presentation != null: enemy_presentation.clear()
func _shutdown() -> void:
	if _leaving: return
	_leaving = true
	if room_presentation != null: get_viewport().use_taa = _previous_taa
	if is_instance_valid(builds): builds.finish()
	if is_instance_valid(skill_vfx): skill_vfx.clear()
	_camera_shake.clear()
	_apply_camera_shake(0.0)
	encounter.cancel()
	for actor in actors: actor.cancel()
	enemy_runtime.clear()
func _retry() -> void:
	if _leaving or is_instance_valid(_transition): return
	skill_vfx.clear()
	var preserved: Dictionary = room_props.plan if room_props != null else {}
	var saved_encounter := encounter_plan.duplicate(true)
	_transition = SceneTransition.begin(get_tree(), scene_file_path, shared_theme, func(next_scene):
		next_scene.initial_room_plan = preserved
		next_scene.initial_encounter_plan = saved_encounter)
func _new_encounter(depth: int) -> void:
	if _leaving or is_instance_valid(_transition): return
	var preserved: Dictionary = room_props.plan if room_props != null else {}
	var next_plan := EncounterPlanner.new().generate(str(randi()), depth, _enemy_spawns.size(), enemy_catalog)
	if next_plan.is_empty(): return
	skill_vfx.clear()
	_transition = SceneTransition.begin(get_tree(), scene_file_path, shared_theme, func(next_scene):
		next_scene.initial_room_plan = preserved
		next_scene.initial_encounter_plan = next_plan)
func _new_layout() -> void:
	if _leaving or is_instance_valid(_transition): return
	skill_vfx.clear()
	var depth := encounter_depth
	_transition = SceneTransition.begin(get_tree(), scene_file_path, shared_theme, func(next_scene): next_scene.encounter_depth = depth)
func _return() -> void:
	if _leaving or is_instance_valid(_transition): return
	skill_vfx.clear()
	_transition = SceneTransition.begin(get_tree(), "res://app/main.tscn", shared_theme)
func _exit_tree() -> void:
	if encounter != null: _shutdown()
