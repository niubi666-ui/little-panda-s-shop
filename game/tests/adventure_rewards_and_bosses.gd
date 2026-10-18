extends "res://tests/forest_run_flow.gd"
## Forward+ or headless: mandatory choices, shop offer isolation and real Boss spawn scaling/HUD.
const Planner = preload("res://rogue/encounters/encounter_planner.gd")

func run() -> void:
	var scene = load("res://app/forest_run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 30: await physics_frame
	var arena = _arena()
	var ctl = arena.forest_run
	check(arena.builds.is_choosing(), "opening awakening stays visible")
	check(not arena.builds.choice_panel.has_signal("close_requested"), "choice view has no temporary-close command")
	check(arena.builds.choice_panel.find_children("*", "Button", true, false).size() == _offer(arena).candidates.size(), "only choice buttons, no close button")
	for i in 10: await physics_frame
	check(ctl._phase == "reward" and not ctl.panel.is_open(), "cannot advance while reward is pending")
	await _choose(arena, 0)
	check(_elements(arena).size() == 1 and ctl.state.awakenings == 1, "awakening commits before exits")
	# Shop fixture: complete each purchase before requesting the next reward source.
	ctl.state.room = "shop"
	ctl.state.gold = 200
	ctl._shop()
	ctl._on_panel_pick(0)
	for i in 6: await physics_frame
	var first := _offer(arena)
	check(ctl.state.gold == 200 - ctl.run.shop.card_price, "card charged once")
	check(first.candidates.all(func(c): return c.operation == "add"), "card purchase offers new cards")
	ctl._on_panel_pick(0)
	check(ctl.state.gold == 200 - ctl.run.shop.card_price, "repeated purchase blocked while choosing")
	await _choose(arena, 0)
	var upgrade_index := -1
	for i in ctl._options.size():
		if ctl._options[i].kind == "upgrade": upgrade_index = i
	if check(upgrade_index >= 0, "shop has an upgrade"):
		ctl._on_panel_pick(upgrade_index)
		for i in 6: await physics_frame
		var second := _offer(arena)
		check(second.id != first.id, "upgrade receives a new locked offer")
		check(second.candidates.all(func(c): return c.operation == "rank"), "upgrade never reuses prior add choices")
		await _choose(arena, 0)
	var enemies = arena.enemy_catalog
	var combat = arena.catalog
	var run: Dictionary = ctl.run
	var previous_hp := 0.0
	var previous_damage := 0.0
	for index in run.areas.size():
		var area: Dictionary = run.areas[index]
		var plan := Planner.new().generate_run_boss("boss-regression", int(area.boss_depth), 3, enemies, area.boss_actor_id)
		check(Planner.new().validate_plan(plan, 3, enemies), "boss plan validates")
		check(plan.waves[0].name_key == combat.actor(area.boss_actor_id).name_key, "boss uses authoritative actor translation")
		var tampered := plan.duplicate(true)
		tampered.waves[0].health_multiplier += 1.0
		check(not Planner.new().validate_plan(tampered, 3, enemies), "tampered boss scaling rejected")
		var next := {"seed": 20261016, "area": index, "node": "boss", "visited": [], "room": "boss", "hp": 100.0,
			"selections": arena.builds.session.snapshot().selections, "gold": 100, "awakenings": 1}
		arena.forest_run._enter(next, plan, int(area.boss_depth))
		if not check(await _await_new_scene(arena), "enter real boss area " + str(index)): return _done()
		arena = _arena()
		arena.player.set_damage_immunity(true)
		var alive: Array = arena.actors.filter(func(a): return a.team == 1 and a.health.alive())
		if not check(alive.size() == 1, "one boss spawned"): return _done()
		var boss = alive[0]
		var brain = arena.brains.filter(func(b): return b.actor == boss)[0]
		var wave: Dictionary = plan.waves[0]
		check(is_equal_approx(boss.health.maximum, combat.actor(area.boss_actor_id).health * float(wave.health_multiplier)), "boss health applies once")
		for field in enemies.profile(area.boss_actor_id).config:
			if field.ends_with("damage_profile_id"):
				var profile_id: String = brain.config[field]
				var formula = preload("res://combat/effects/damage_formula.gd")
				var amount: float = formula.preview(boss,profile_id).amount
				var base: float = formula.linear(combat.attributes.profile(profile_id),combat.attributes.actor(area.boss_actor_id))
				check(is_equal_approx(amount,base*float(wave.damage_multiplier)), "boss damage depth once: " + field)
		var charged: float=preload("res://combat/effects/damage_formula.gd").preview(boss,brain.config.charged_damage_profile_id).amount
		check(boss.health.maximum > previous_hp and charged > previous_damage, "each area boss is stronger")
		previous_hp = boss.health.maximum
		previous_damage = charged
		for i in 60: await physics_frame
		check(arena.hud.encounter_label.text.contains(tr(plan.waves[0].name_key)), "boss HUD updates without missing keys")
		await _clear_room(arena)
		for i in 6: await physics_frame
		if index == 0:
			check(arena.builds.is_choosing(), "first boss still grants awakening")
		elif index == run.areas.size() - 1:
			check(arena.forest_run._phase == "over", "last boss still completes the run")
	print("ADVENTURE_REWARDS_AND_BOSSES ", JSON.stringify({"failures": failures}))
	_done()
