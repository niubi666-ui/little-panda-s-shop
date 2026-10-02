extends SceneTree
const Host = preload("res://app/combat_training.tscn")
const CombatLoader = preload("res://content/combat/combat_loader.gd")
const EnemyLoader = preload("res://content/enemies/enemy_loader.gd")
const Planner = preload("res://rogue/encounters/encounter_planner.gd")
var failures: Array[String] = []
var death_events: Array = []
var catalog
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func plan_for(id: String) -> Dictionary:
	for seed_value in 1000:
		var plan := Planner.new().generate(str(seed_value), 6, 3, catalog)
		if plan.waves[0].combination_id == id: return plan
	assert(false, "expected authored formation in depth pool")
	return {}
func spawn(plan: Dictionary):
	var arena = Host.instantiate()
	arena.build_choices_enabled = false
	arena.initial_encounter_plan = plan
	var prop_catalog = preload("res://content/rooms/room_prop_loader.gd").new().load_catalog()
	var reserved: Array[Vector3] = [Vector3(0,0,3),Vector3(-3,0,-3),Vector3(3,0,-3),Vector3(0,0,-5)]
	arena.initial_room_plan = preload("res://rogue/rooms/prop_planner.gd").new().generate(7, prop_catalog, preload("res://presentation/rooms/forest_courtyard_v001/placement_surface.tres"), preload("res://presentation/rooms/props/forest_props.tres"), reserved)
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	return arena
func step(arena, frames: int) -> void:
	for i in frames:
		await physics_frame
		arena._physics_process(1.0/60.0)
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/ShopGame/docs/previews/" + name + ".png")
func run() -> void:
	catalog = EnemyLoader.new().load_catalog(CombatLoader.new().load_catalog())
	var plan := plan_for("crossfire_charge")
	check(Planner.new().validate_plan(plan,3,catalog), "generated plan validated")
	var invalid := plan.duplicate(true)
	invalid.waves[0].enemy_ids[0] = "banner"
	check(not Planner.new().validate_plan(invalid,3,catalog), "tampered team rejected")
	invalid = plan.duplicate(true);invalid.version = "old"
	check(not Planner.new().validate_plan(invalid,3,catalog), "old content plan rejected")
	var arena = spawn(plan)
	check(arena.brains.size() == 3, "all three formation members instantiated")
	await step(arena,12)
	check(not arena.hud.encounter_panel.get_global_rect().intersects(arena.builds.status_panel.get_global_rect()), "depth controls do not overlap build panel")
	check(arena.brains[1].state == "windup" and arena.brains[2].state == "windup", "ranged and charge telegraphs visible together")
	await capture("enemies_crossbow_charge_windup")
	await step(arena,23)
	check(not arena.enemy_runtime.projectiles.is_empty(), "red projectile exists in actual courtyard")
	await capture("enemies_crossbow_charge_projectile")
	var projectiles: Array = arena.enemy_runtime.projectiles.duplicate(true)
	var positions: Array = arena.actors.map(func(a): return a.position)
	arena.paused = true
	await step(arena,12)
	check(arena.enemy_runtime.projectiles == projectiles and arena.actors.map(func(a): return a.position) == positions, "pause freezes projectiles, AI and motion")
	var old_plan: Dictionary = arena.encounter_plan.duplicate(true)
	var old_room: Dictionary = arena.room_props.plan.duplicate(true)
	arena._retry()
	await arena._transition.completed
	arena = current_scene;arena.set_physics_process(false)
	check(arena.encounter_plan == old_plan and arena.room_props.plan == old_room, "retry preserves both encounter/loot and layout")
	arena._new_encounter(15)
	await arena._transition.completed
	arena = current_scene;arena.set_physics_process(false)
	check(arena.encounter_depth == 15 and arena.encounter_plan.budget == 7 and arena.room_props.plan == old_room, "depth reroll changes legal encounter while retaining scenery")
	arena._new_layout()
	await arena._transition.completed
	arena = current_scene;arena.set_physics_process(false)
	check(arena.encounter_depth == 15 and arena.room_props.plan != old_room, "new layout preserves selected depth")
	arena.queue_free();await process_frame
	arena = spawn(plan_for("banner_brute"))
	await step(arena,12)
	var brute = arena.actors.filter(func(a):return a.definition.id == "brute")[0]
	var flag = arena.actors.filter(func(a):return a.definition.id == "banner")[0]
	check(brute.aura_active and not flag.aura_active, "banner buffs heavy, not itself")
	await capture("enemies_banner_heavy")
	for locale in ["en", "zh_CN"]:
		TranslationServer.set_locale(locale)
		arena.hud.refresh_text()
		arena.hud.update_encounter(arena.encounter_plan, arena.encounter.wave_index)
		await process_frame
		check(not arena.hud.encounter_label.text.contains("encounter."), "encounter text translated: " + locale)
		check(root.get_visible_rect().encloses(arena.hud.encounter_panel.get_global_rect()), "depth panel fits viewport: " + locale)
	arena.enemy_loot_ready.connect(func(spawn_id,id,drops):death_events.append({"spawn_id":spawn_id,"actor_id":id,"drops":drops}))
	flag.receive_hit(flag.health.maximum)
	flag.receive_hit(10)
	await step(arena,1)
	check(not brute.aura_active and brute.enemy_move_multiplier == 1.0, "killing support immediately removes heavy movement buff")
	check(death_events.size() == 1 and death_events[0].drops == arena.encounter_plan.waves[0].drops[1], "death emits locked loot fact exactly once")
	# Resolve every wave; progression remains connected to the normal training flow.
	while arena.state != "victory":
		for enemy in arena.actors.duplicate():
			if enemy.team != 0 and enemy.health.alive(): enemy.receive_hit(enemy.health.maximum)
		if arena.state != "victory": arena.encounter.tick(arena.catalog.wave_delay())
	check(arena.enemy_runtime.projectiles.is_empty() and arena.enemy_runtime.brains.is_empty(), "clear removes hostile actions")
	arena.queue_free();await process_frame
	# Death during a hostile shot must safely clear the same container being stepped.
	arena = spawn(plan_for("crossfire_charge"))
	var shooter = arena.actors.filter(func(a):return a.definition.id == "crossbow")[0]
	arena.player.health.current = 1
	arena.enemy_runtime._shoot(shooter,Vector3.ZERO,catalog.profile("crossbow").config)
	arena.enemy_runtime.projectiles[0].position = arena._actor_query_origin(arena.player)
	arena.enemy_runtime.after_motion(0.1)
	check(arena.state == "defeat" and arena.enemy_runtime.projectiles.is_empty(), "fatal projectile safely cancels remaining hostile state")
	arena.queue_free();await process_frame
	print("ENEMY_TRAINING ",JSON.stringify({"failures":failures,"loot_facts":death_events.size()}))
	quit(0 if failures.is_empty() else 1)
