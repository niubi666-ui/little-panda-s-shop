extends SceneTree
const CombatLoader = preload("res://content/combat/combat_loader.gd")
const BuildLoader = preload("res://content/builds/build_loader.gd")
const Catalog = preload("res://content/combat/combat_catalog.gd")
const Actor = preload("res://combat/actors/combat_actor.gd")
const Damage = preload("res://combat/effects/damage_executor.gd")
const Formula = preload("res://combat/effects/damage_formula.gd")
const Melee = preload("res://combat/effects/melee_resolver.gd")
const BuildFixture = preload("res://tests/fixtures/action_build_fixture.gd")
const BuildRuntime = preload("res://combat/builds/build_runtime.gd")
var failures: Array[String] = []
var combat
var builds
var _handle := 0

func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	combat = CombatLoader.new().load_catalog()
	builds = BuildLoader.new().load_catalog()
	check_damage_and_melee()
	check_dodge_independence()
	check_immune_contact_freeze()
	check_restore()
	print("TRAINING_DAMAGE_OVERRIDE ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)

func make_actor(id: String, team: int) -> Actor:
	_handle += 1
	var actor := Actor.new()
	var attacks: Array[Catalog.Ability] = []
	for ability_id in combat.actor(id).attacks: attacks.append(combat.ability(ability_id))
	actor.configure(combat.actor(id), attacks, combat.dodge() if team == 0 else null, _handle, team)
	root.add_child(actor)
	actor.attributes.set_modifier("test", "crit_chance", "flat", -actor.attributes.value("crit_chance"))
	return actor

func raw_hit(target, amount: float, team: int) -> float:
	return Damage.raw_physical(target, amount, combat.attributes, team).health_loss

func attack(source: Actor, ability_id: String, plan: Dictionary = {}) -> void:
	source.runner.cancel()
	source.runner.cooldown = 0.0
	var ability: Catalog.Ability = combat.ability(ability_id)
	check(source.runner.start(ability, Vector3.FORWARD, plan), "test cast starts")
	source.runner.tick(ability.windup)

func check_damage_and_melee() -> void:
	var source := make_actor("player", 0)
	var enemy := make_actor("scout", 1)
	enemy.position = Vector3.FORWARD
	var events := {"damage": 0, "death": 0, "confirmed": 0, "contact": 0}
	enemy.health.damaged.connect(func(_amount): events.damage += 1)
	enemy.killed.connect(func(_actor): events.death += 1)
	var melee := Melee.new()
	melee.confirmed_hit.connect(func(_s, _t, _cast, _id, _amount): events.confirmed += 1)
	melee.enemy_contact.connect(func(_s, _cast, _id, _target, _point, _amount): events.contact += 1)
	check(not enemy.invulnerable(), "new actors have no damage override")
	enemy.set_damage_immunity(true)
	check(raw_hit(enemy, enemy.health.maximum*2.0, source.team) == 0.0, "shared damage executor respects override for lethal hit")
	attack(source, "slash.2")
	melee.resolve(source, [enemy])
	check(enemy.health.current == enemy.health.maximum and enemy.health.alive(), "immune melee keeps HP and life")
	check(events.damage == 0 and events.death == 0 and events.confirmed == 0, "immune damage does not emit committed damage or death facts")
	check(events.contact == 0 and enemy.motor.impulse_left == 0.0 and enemy.stagger_left == 0.0, "rejected immune hit emits no on-hit, knockback or stagger")
	enemy.set_damage_immunity(false)
	attack(source, "slash.2")
	melee.resolve(source, [enemy])
	var ability: Catalog.Ability = combat.ability("slash.2")
	check(is_equal_approx(enemy.health.maximum - enemy.health.current, ability.damage*Formula.mitigation(combat.attributes,"physical",enemy.attributes.final)), "disabling override restores normal armor-mitigated melee damage")
	check(events.damage == 1 and events.confirmed == 1 and enemy.motor.impulse_left == ability.knockback_duration, "disabling override restores committed hit and knockback")
	check(raw_hit(enemy, enemy.health.maximum*2.0, source.team) > 0.0 and events.death == 1, "normal lethal damage kills once after disabling override")
	raw_hit(enemy, enemy.health.maximum*2.0, source.team)
	check(events.death == 1, "override does not alter death deduplication")
	source.free()
	enemy.free()

func check_dodge_independence() -> void:
	var player := make_actor("player", 0)
	player.dodge_left = player.dodge.duration
	player.dodge_age = 0.0
	player.set_damage_immunity(true)
	player.set_damage_immunity(false)
	check(player.invulnerable() and raw_hit(player, player.health.maximum, 1) == 0.0, "disabling override preserves active dodge immunity")
	player.dodge_age = player.dodge.invulnerable
	check(not player.invulnerable(), "original dodge window still expires")
	player.set_damage_immunity(true)
	check(player.invulnerable() and raw_hit(player, player.health.maximum, 1) == 0.0, "override protects player after dodge immunity expires")
	player.set_damage_immunity(false)
	check(raw_hit(player, combat.ability("enemy.swipe").damage, 1) > 0.0, "player can take damage after override and dodge both end")
	player.free()

func check_immune_contact_freeze() -> void:
	var source := make_actor("player", 0)
	var enemy := make_actor("brute", 1)
	enemy.position = Vector3.FORWARD
	enemy.set_damage_immunity(true)
	var runtime := BuildRuntime.new()
	runtime.configure(builds, source, func(): return [enemy], Callable())
	var program: Dictionary = BuildFixture.compile(builds, {"contact_freeze": 1}, "primary")
	check(runtime.set_program(program), "freeze fixture uses a validated primary action program")
	var melee := Melee.new()
	melee.enemy_contact.connect(runtime.on_melee_contact)
	attack(source, "slash.1", program.actions.primary)
	runtime.on_committed(source.runner.cast_id, source.runner.ability.id)
	melee.resolve(source, [enemy])
	runtime.tick(combat.ability("slash.1").active)
	check(enemy.health.current == enemy.health.maximum and not enemy.control_locked, "invulnerable hit cannot deliver contact freeze")
	check(not runtime.statuses.snapshot(enemy).has("test_freeze") and runtime.diagnostics().rejected == 0, "rejected hit never enters element processing")
	runtime.clear_room()
	source.free()
	enemy.free()

func check_restore() -> void:
	var actor := make_actor("player", 0)
	var events := {"damage": 0, "death": 0}
	actor.health.damaged.connect(func(_amount): events.damage += 1)
	actor.health.died.connect(func(): events.death += 1)
	check(not actor.health.restore(), "restoring full health is a no-op")
	actor.receive_hit(combat.ability("enemy.swipe").damage)
	actor.set_damage_immunity(true)
	check(actor.health.restore() and actor.health.current == actor.health.maximum, "restore returns true only when living health actually increases")
	check(events.damage == 1 and events.death == 0 and actor.invulnerable(), "restore neither emits damage/death nor changes immunity")
	actor.set_damage_immunity(false)
	actor.receive_hit(actor.health.maximum*2.0)
	check(not actor.health.restore() and actor.health.current == 0.0 and not actor.runner.actions_allowed, "restore cannot revive a dead actor or its actions")
	check(events.damage == 2 and events.death == 1, "restore leaves death event count unchanged")
	actor.free()
