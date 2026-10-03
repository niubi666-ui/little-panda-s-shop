extends SceneTree
const BuildLoader = preload("res://content/builds/build_loader.gd")
const CombatLoader = preload("res://content/combat/combat_loader.gd")
const Actor = preload("res://combat/actors/combat_actor.gd")
const Catalog = preload("res://content/combat/combat_catalog.gd")
const Resolver = preload("res://combat/builds/build_resolver.gd")
const Runtime = preload("res://combat/builds/build_runtime.gd")
const Melee = preload("res://combat/effects/melee_resolver.gd")
const Fixture = preload("res://tests/fixtures/action_build_fixture.gd")
var builds
var combat
var failures: Array[String] = []
var next_handle := 0
var actors: Array = []
var resolver := Resolver.new()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func actor(id: String, team: int, point: Vector3 = Vector3.ZERO):
	var result := Actor.new()
	var definition = combat.actor(id)
	var abilities: Array[Catalog.Ability] = []
	for ability_id in definition.attacks: abilities.append(combat.ability(ability_id))
	next_handle += 1
	result.configure(definition, abilities, combat.dodge() if team == 0 else null, next_handle, team)
	root.add_child(result)
	result.position = point
	actors.append(result)
	return result
func setup(selections: Array, wall: Callable = Callable()) -> Dictionary:
	var player = actor("player", 0)
	var runtime := Runtime.new()
	runtime.configure(builds, player, func(): return actors, wall, ["test_arrow"])
	player.runner.committed.connect(runtime.on_committed)
	player.runner.cue_reached.connect(runtime.on_cue)
	player.runner.finished.connect(runtime.on_finished)
	var melee := Melee.new()
	melee.set_damage_modifier(runtime.melee_damage)
	melee.enemy_contact.connect(runtime.on_melee_contact)
	melee.confirmed_hit.connect(runtime.on_melee_hit)
	var state := {"selections": selections, "revision": 1}
	var program := resolver.resolve(state)
	check(not program.is_empty(), "fixture has valid action program")
	check(runtime.set_program(program) and player.set_action_program(program.actions, combat), "action program injected")
	return {"player": player, "runtime": runtime, "melee": melee, "program": program}
func select(id: String, action_id: String, rank: int = 1) -> Dictionary:
	return {"upgrade_id": id, "action_id": action_id, "rank": rank}
func cast(f: Dictionary, id: String) -> void:
	var plan: Dictionary = f.program.actions[id]
	var ability = combat.ability(plan.ability_ids[0])
	check(f.player.runner.start(ability, Vector3.FORWARD, plan), "cast starts " + id)
	f.player.runner.tick(ability.windup)
	f.melee.resolve(f.player, actors)
	f.runtime.tick(0.001)
func clean(f: Dictionary) -> void:
	f.runtime.clear_room()
	for target in actors: target.free()
	actors.clear()
func run() -> void:
	var loader := BuildLoader.new()
	builds = loader.load_catalog()
	check(builds != null, "builds load: " + str(loader.errors))
	combat = CombatLoader.new().load_catalog()
	if builds == null or combat == null: quit(1); return
	resolver.configure(builds)
	check_base_and_form()
	check_independent_cores()
	check_pierce_contacts()
	check_frost_snapshot()
	check_debug_isolation_and_split()
	check_cancel_reentry()
	print("ACTION_BUILD_RUNTIME ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
func check_base_and_form() -> void:
	var f := setup([])
	var victim = actor("brute", 1, Vector3.FORWARD)
	cast(f, "special")
	check(victim.health.current < victim.health.maximum and f.runtime.projectiles().is_empty(), "empty build special is real melee heavy")
	clean(f)
	f = setup([select("sword_wave_form", "special"), select("contact_freeze", "special")])
	victim = actor("brute", 1, Vector3.FORWARD)
	cast(f, "special")
	check(victim.health.current == victim.health.maximum and not victim.control_locked, "projectile form bypasses melee contact, even at touching distance")
	check(f.runtime.projectiles().size() == 1, "wave launches on cue without a melee hit")
	f.runtime.tick(0.15)
	check(victim.health.current < victim.health.maximum and victim.control_locked, "projectile alone deals damage and applies its core")
	clean(f)
func check_independent_cores() -> void:
	var selections := [select("impact_blast", "primary"), select("sword_wave_form", "special"), select("contact_freeze", "special"), select("pierce", "special")]
	var f := setup(selections, func(_a, _b): return null)
	var target = actor("brute", 1, Vector3.FORWARD)
	var side = actor("brute", 1, Vector3(1.8, 0, -1))
	var areas: Array = []
	f.runtime.area_presented.connect(func(fact): areas.append(fact))
	cast(f, "primary")
	check(areas.size() == 1 and areas[0].action_id == "primary", "left blast belongs to left root")
	check(not target.control_locked and not side.control_locked, "right freeze never leaks into left blast")
	f.player.runner.cancel()
	var later = actor("brute", 1, Vector3(0, 0, -4))
	cast(f, "special")
	f.runtime.tick(0.4)
	check(target.control_locked and later.control_locked and not side.control_locked, "right freezes each direct pierced target only")
	check(areas.size() == 1, "right freeze never inherits left explosion")
	check(f.runtime.statuses.snapshot(target).test_freeze.source.action_id == "special", "status metadata retains bound source")
	clean(f)
func check_pierce_contacts() -> void:
	var order_runs: Array = []
	for step in [0.01, 1.0]:
		var f := setup([select("sword_wave_form", "special"), select("pierce", "special")])
		var hits: Array = []
		var ids: Array = []
		for i in 5: ids.append(actor("brute", 1, Vector3(0, 0, -float(i + 1))))
		f.runtime.damage_applied.connect(func(_s, t, _amount, _o): hits.append(ids.find(t)))
		cast(f, "special")
		for i in int(ceil(1.0 / step)): f.runtime.tick(step)
		check(hits.size() == builds.upgrade("pierce").ranks[0].max_hits, "total finite contact cap")
		order_runs.append(hits)
		clean(f)
	check(order_runs[0] == order_runs[1], "small and large steps keep direct contact order")
	var f := setup([select("sword_wave_form", "special"), select("pierce", "special")], func(a, b): return Vector3(0, a.y, -2) if a.z >= -2 and b.z <= -2 else null)
	var before = actor("brute", 1, Vector3(0, 0, -1))
	var behind = actor("brute", 1, Vector3(0, 0, -2))
	cast(f, "special")
	f.runtime.tick(1.0)
	check(before.health.current < before.health.maximum and behind.health.current == behind.health.maximum, "wall wins tie without hitting through geometry")
	check(f.runtime.projectiles().is_empty(), "wall terminates pierced wave")
	clean(f)
func check_frost_snapshot() -> void:
	var selected: Array = builds.test_preset("right_frost").selections.duplicate(true)
	var f := setup(selected, func(_a, _b): return null)
	var near = actor("brute", 1, Vector3(0, 0, -1))
	var side = actor("brute", 1, Vector3(1, 0, -1))
	var later = actor("brute", 1, Vector3(0, 0, -5))
	var emitted: Array = []
	f.runtime.area_presented.connect(func(fact): emitted.append(fact))
	cast(f, "special")
	selected.append(select("freeze_duration", "special"))
	var next := resolver.resolve({"selections": selected, "revision": 2})
	check(f.runtime.set_program(next) and f.player.set_action_program(next.actions, combat), "can replace build during in-flight shot")
	f.runtime.tick(0.5)
	check(near.control_locked and side.control_locked and not later.control_locked, "frost first blast freezes center and area, later pierced target is ordinary damage")
	check(emitted.size() == 1 and emitted[0].revision == 1 and emitted[0].action_id == "special", "old blast retains original revision and action")
	check(is_equal_approx(f.runtime.statuses.snapshot(side).test_freeze.remaining, builds.status("test_freeze").duration_sec), "in-flight payload does not gain newly selected duration")
	check(f.runtime.diagnostics().rejected == 0, "legal frost plan stays under budget")
	var countdown: float = f.runtime.statuses.snapshot(side).test_freeze.remaining
	f.runtime.statuses.tick(0.0)
	check(f.runtime.statuses.snapshot(side).test_freeze.remaining == countdown, "status pause preserves clock")
	clean(f)
func check_debug_isolation_and_split() -> void:
	var f := setup(builds.test_preset("left_blast_right_freeze").selections.duplicate(true))
	var first = actor("brute", 1, Vector3(0, 0, -1))
	var second = actor("brute", 1, Vector3(0, 0, -2))
	check(f.runtime.fire_attack("test_arrow", Vector3.FORWARD), "explicit debug attack can fire")
	f.runtime.tick(0.001); f.runtime.tick(0.5)
	check(not first.control_locked and not second.control_locked and second.health.current == second.health.maximum, "T arrow inherits no left/right core or piercing")
	clean(f)
	# Legacy carrier mechanics remain through explicitly named debug action plans.
	f = setup(Fixture.state({"split": 1}, "debug_arrow").selections)
	first = actor("brute", 1, Vector3.FORWARD)
	var facts: Array = []
	f.runtime.projectile_presented.connect(func(fact): facts.append(fact))
	f.runtime.fire_attack("test_arrow", Vector3.FORWARD)
	f.runtime.tick(0.001); f.runtime.tick(0.1)
	check(f.runtime.projectiles().size() == int(builds.upgrade("split").ranks[0].count), "debug arrow reuses split handler without sword-wave upgrade")
	for shot in f.runtime.projectiles(): check(shot.action_id == "debug_arrow" and shot.generation == 1, "children retain root action identity")
	check(facts.any(func(fact): return fact.event == "terminated" and fact.reason == "contact_limit"), "termination fact records reason and identity")
	clean(f)
func check_cancel_reentry() -> void:
	var f := setup([select("sword_wave_form", "special")])
	var plan: Dictionary = f.program.actions.special
	f.player.runner.start(combat.ability("wave_cast"), Vector3.FORWARD, plan)
	f.player.runner.cancel("dodge")
	f.player.runner.tick(2.0)
	f.runtime.tick(0.1)
	check(f.runtime.projectiles().is_empty(), "pre-cue cancellation cannot launch wave")
	clean(f)
	f = setup([select("sword_wave_form", "special"), select("pierce", "special")])
	actor("brute", 1, Vector3.FORWARD)
	var second = actor("brute", 1, Vector3(0, 0, -2))
	f.runtime.damage_applied.connect(func(_a, _b, _c, _d): f.runtime.clear_room(), CONNECT_ONE_SHOT)
	cast(f, "special")
	f.runtime.tick(1.0)
	check(second.health.current == second.health.maximum and f.runtime.diagnostics().roots == 0, "synchronous room clear stops later contacts")
	clean(f)
