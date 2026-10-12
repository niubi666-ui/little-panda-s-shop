extends SceneTree
const Planner = preload("res://rogue/encounters/encounter_planner.gd")
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func run() -> void:
	var combat = preload("res://content/combat/combat_loader.gd").new().load_catalog()
	var loader := preload("res://content/enemies/enemy_loader.gd").new()
	var enemies = loader.load_catalog(combat)
	check(enemies != null, "catalog loads " + str(loader.errors))
	if enemies == null: quit(1); return
	var planner := Planner.new()
	for depth in [1,6,15,30]:
		var plan := planner.generate_training("five-wave-test",depth,3,enemies)
		check(plan.waves.size() == 5 and plan.waves[4].enemy_ids == ["elite_ranger"], "five waves end in ranger at depth " + str(depth))
		check(planner.validate_plan(plan,3,enemies), "locked plan reproduces")
		for i in 4:
			check(plan.waves[i+1].health_multiplier > plan.waves[i].health_multiplier and plan.waves[i+1].damage_multiplier > plan.waves[i].damage_multiplier, "each wave strengthens stats")
		plan.waves[0].health_multiplier += 1
		check(not planner.validate_plan(plan,3,enemies), "tampered strength rejected")
	var arena = load("res://app/combat_training.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena); current_scene = arena
	arena.set_physics_process(false)
	check(arena.encounter_plan.get("training_progression",false), "default training uses progression")
	var saved: Dictionary = arena.encounter_plan.duplicate(true)
	for i in 5:
		check(arena.encounter.wave_index == i and arena.state != "victory", "wave begins before final victory " + str(i))
		var rule: Dictionary = enemies.encounters.training_waves[i]
		var alive: Array = arena.actors.filter(func(a): return a.team == 1 and a.health.alive())
		check(not alive.is_empty(), "wave has living enemies")
		for actor in alive:
			check(is_equal_approx(actor.health.maximum,combat.actor(actor.definition.id).health*rule.health_multiplier), "scaled runtime HP")
			for ability in actor.attacks:
				check(is_equal_approx(ability.damage,combat.ability(ability.id).damage*rule.damage_multiplier), "scaled melee damage")
		if i == 4:
			check(alive.size() == 1 and alive[0].definition.id == "elite_ranger", "fifth wave actually spawns boss")
			var brain = arena.brains.filter(func(b): return b.actor == alive[0])[0]
			check(is_equal_approx(brain.config.charged_damage,enemies.profile("elite_ranger").config.charged_damage*rule.damage_multiplier), "boss ranged damage scaled")
		for actor in alive: actor.health.apply(actor.health.maximum,false)
		if i < 4:
			check(arena.state != "victory", "early wave does not finish training")
			arena.encounter.tick(combat.wave_delay()+.01)
	check(arena.state == "victory", "boss death completes training")
	check(planner.validate_plan(saved,3,enemies), "retry reuses locked plan without compounded scaling")
	arena.queue_free(); await process_frame
	print("TRAINING_FIVE_WAVES ",JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
