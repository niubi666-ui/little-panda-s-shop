extends "res://tests/enemy_roles.gd"
const Damage = preload("res://combat/effects/damage_executor.gd")
const Formula = preload("res://combat/effects/damage_formula.gd")
const BuildLoader = preload("res://content/builds/build_loader.gd")
const BuildRuntime = preload("res://combat/builds/build_runtime.gd")
const BuildFixture = preload("res://tests/fixtures/action_build_fixture.gd")
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	super.check(value, message)
func run() -> void:
	combat = CombatLoader.new().load_catalog()
	check(combat != null, "combat with attributes loads")
	if combat == null: quit(1); return
	enemies = EnemyLoader.new().load_catalog(combat)
	check(enemies != null, "all enemy profile references load")
	var build_loader := BuildLoader.new()
	var builds = build_loader.load_catalog()
	check(builds != null, "build profiles load: " + str(build_loader.errors))
	world = Node3D.new()
	root.add_child(world)
	check(combat.attributes.data.is_read_only() and combat.attributes.actor("player").is_read_only(), "deeply immutable content")
	check_schema()
	for id in combat.attributes.data.actors:
		var a = actor(id, Vector3.ZERO)
		check(a.attributes.final.size() == 10 and a.attributes.final.is_read_only(), "ten final stats: " + id)
		a.free()
	var player = actor("player", Vector3.ZERO)
	var victim = actor("brute", Vector3(0,0,-2))
	victim.attributes.set_modifier("test", "max_health", "flat", 1000.0)
	victim.health.current = victim.health.maximum
	victim.attributes.set_modifier("test", "armor", "flat", 80.0)
	victim.attributes.set_modifier("test", "magic_resistance", "flat", 95.0)
	var hit := Damage.request(player, "ability.slash.1", 100.0, 1, "primary")
	var result := Damage.submit(victim, hit)
	check(is_equal_approx(result.health_loss, 50.0), "100 physical versus 100 armor")
	check(is_equal_approx(result.poise_basis,100.0), "armor does not reduce poise impact")
	hit.components[0].type = "magical"
	victim.break_left = 0.0
	result = Damage.submit(victim, hit)
	check(is_equal_approx(result.health_loss, 50.0), "100 magical versus 100 MR")
	victim.set_incoming_modifier("test", 0.5, 0.5)
	hit.components[0].type = "true"
	hit.source_scale = 1.5
	hit.critical = true
	victim.grant_protection(30.0, 4.0)
	result = Damage.submit(victim, hit)
	check(is_equal_approx(result.shield_loss,30.0) and is_equal_approx(result.health_loss,70.0) and not result.critical, "true ignores resistance, normal bonuses, reduction, vulnerability and crit; shield works")
	victim.set_damage_immunity(true)
	check(not Damage.submit(victim, hit).valid_hit, "invulnerability rejects true damage")
	victim.set_damage_immunity(false)
	victim.break_left = 0.0
	victim.remove_incoming_modifier("test")
	victim.attributes.set_modifier("test", "magic_resistance", "flat", -5.0)
	hit.critical = false
	hit.source_scale = 1.0
	hit.components = [{"type":"physical","basis":80.0},{"type":"magical","basis":20.0}]
	victim.grant_protection(10.0,4.0)
	var events := [0]
	victim.damage_received.connect(func(_fact): events[0] += 1)
	result = Damage.submit(victim, hit)
	check(is_equal_approx(result.shield_loss,10.0) and is_equal_approx(result.health_loss,50.0) and events[0]==1, "mixed damage is one shield/health/hit commit")
	victim.grant_protection(1000.0,4.0)
	result = Damage.submit(victim, hit)
	check(result.valid_hit and result.health_loss==0.0 and result.shield_loss>0.0, "fully shielded damage remains a valid hit")
	check(is_equal_approx(result.poise_basis,100.0), "shield does not reduce poise impact")
	var hp: float = player.health.current
	player.attributes.set_modifier("buff", "max_health", "flat", 100.0)
	check(player.health.current == hp and player.health.maximum == 200.0, "max health growth does not heal")
	player.attributes.set_modifier("buff", "max_health", "flat", 100.0)
	check(player.health.maximum == 200.0, "same source replaces instead of stacking")
	player.attributes.remove_source("buff")
	check(player.health.maximum == hp, "modifier removable")
	player.attributes.set_modifier("training", "attack_power", "flat", 20.0)
	check(is_equal_approx(Formula.elemental_growth(player.attribute_catalog,player.attributes.final,player.attributes.base),1.2), "positive bonus AD growth")
	player.attributes.remove_source("training")
	player.attributes.set_modifier("training", "spell_power", "flat", 10.0)
	check(is_equal_approx(Formula.elemental_growth(player.attribute_catalog,player.attributes.final,player.attributes.base),1.2), "AP growth")
	player.attributes.remove_source("training")
	player.attributes.set_modifier("training", "crit_chance", "flat", 0.95)
	player.attributes.set_modifier("training", "attack_speed_multiplier", "multiply", 2.0)
	player.attributes.set_modifier("training", "cooldown_haste", "flat", 1.0)
	player.request_attack();player.step(0.001)
	check(player.runner.damage_snapshot.critical, "committed action rolls a critical once")
	check(is_equal_approx(player.runner.ability.windup,combat.ability("slash.1").windup/2.0), "attack speed changes authoritative timeline")
	check(is_equal_approx(player.runner.ability.cooldown,combat.ability("slash.1").cooldown/2.0), "primary rearm uses attack speed only")
	check(is_equal_approx(player.skill_cooldown(2.0),1.0), "skill haste independent")
	player.cancel()
	player.attributes.remove_source("training")
	victim.clear_protection()
	victim.free();player.free()
	if builds != null: check_build_damage(builds)
	world.free()
	print("COMBAT_ATTRIBUTES ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func check_schema() -> void:
	var loader:=preload("res://content/combat/attribute_loader.gd").new()
	var schema: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/schemas/combat_attributes.schema.json"))
	for invalid in ["missing", "unknown", "range", "type"]:
		var data: Dictionary=combat.attributes.data.duplicate(true)
		match invalid:
			"missing": data.actors.player.erase("armor")
			"unknown": data.actors.player["misspelled_armor"]=10.0
			"range": data.actors.player.crit_chance=2.0
			"type": data.linear_profiles["ability.slash.1"].damage_type="unrecognized"
		check(loader.decode(data,schema)==null and not loader.errors.is_empty(),"strict attribute validation rejects " + invalid)

func check_build_damage(builds) -> void:
	var player = actor("player",Vector3.ZERO)
	var victim = actor("scout",Vector3(0,0,-1))
	player.attributes.set_modifier("test", "crit_chance", "flat", -0.05)
	var runtime := BuildRuntime.new()
	var evaluator := preload("res://combat/builds/build_resolver.gd").new()
	evaluator.configure(builds)
	var state := {"revision":1,"selections":[{"upgrade_id":"power","action_id":"global","rank":1},{"upgrade_id":"ice_core","action_id":"primary","rank":1}]}
	check(evaluator.validate_state(state).is_empty(), "damage fixture is a legal build: " + str(evaluator.validate_state(state)))
	var program: Dictionary = evaluator.resolve(state)
	if program.is_empty(): player.free(); victim.free(); return
	runtime.configure(builds, player, func():return [victim], Callable())
	runtime.set_program(program)
	player.set_action_program(program.actions, combat)
	player.runner.committed.connect(runtime.on_committed)
	player.runner.cue_reached.connect(runtime.on_cue)
	player.request_attack();player.step(0.01)
	var hit := runtime.apply_melee_damage(player,victim,player.runner.ability.damage)
	check(hit.valid_hit, "bound melee reaches unified executor")
	var expected: float = player.runner.ability.damage * program.actions.primary.damage_scale * Formula.mitigation(player.attribute_catalog,"physical",victim.attributes.final)
	check(is_equal_approx(hit.health_loss,expected), "weapon bonus and armor each apply once")
	check(runtime.elements.stacks_on(victim.handle).has("ice"), "physical weapon hit retains element attachment")
	runtime.clear_room()
	player.free();victim.free()
