extends "res://tests/action_build_runtime.gd"
## New elemental freeze shares the existing window/provenance, trail and shield executors.
const Capabilities = preload("res://combat/builds/projectile_capabilities.gd")
const Conditional = preload("res://combat/builds/conditional_damage.gd")
const Session = preload("res://app/session/training_build_session.gd")
const FOUR := {"shatter_followup": "skill", "opening_strike": "primary", "frost_path": "skill", "ice_coat": "skill"}
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	super.check(ok, message)

func _begin(f: Dictionary, action: String) -> Dictionary:
	f.player.runner.cancel()
	f.player.runner._cooldowns.clear()
	var plan: Dictionary = f.program.actions[action]
	check(f.player.runner.start(combat.ability(plan.ability_ids[0]), Vector3.FORWARD, plan), "cast commits: " + action)
	return f.runtime._context_for_cast(f.player.runner.cast_id)

func _hit(f: Dictionary, action: String, target) -> float:
	return f.runtime._apply_direct_damage(_begin(f, action), target, 10.0, "direct_projectile" if action == "skill" else "direct_melee")

func _tough(id: String = "scout", point: Vector3 = Vector3.FORWARD):
	var target = actor(id, 1, point)
	target.health.maximum = 10000.0
	target.health.current = 10000.0
	return target

func _cards() -> Array:
	var result: Array = [select("ice_core", "skill")]
	for id in FOUR: result.append(select(id, FOUR[id]))
	return result

func run() -> void:
	var loader := BuildLoader.new()
	builds = loader.load_catalog()
	combat = CombatLoader.new().load_catalog()
	check(builds != null and combat != null, "catalogs load: " + str(loader.errors))
	if builds == null or combat == null: quit(1); return
	resolver.configure(builds)
	_policy()
	for id in ["scout", "elite_ranger"]: _windows(id)
	_sources()
	_path_and_lifecycle()
	await _real_projectiles()
	print("ICE_SYNERGY ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _policy() -> void:
	for base in [[], [select("fire_core", "skill")], [select("ice_core", "primary")]]:
		for id in FOUR:
			check(resolver.legal_operations({"selections": base, "revision": 0}, id).is_empty(), "no false provider: " + id + str(base))
	for id in FOUR:
		var options := resolver.legal_operations({"selections": [select("ice_core", "skill")], "revision": 0}, id)
		check(options.size() == 1 and options[0].action_id == FOUR[id], "one ice core unlocks " + id)
	check(not resolver.legal_operations({"selections": [select("ice_core", "special")], "revision": 0}, "opening_strike").is_empty(), "R ice also provides opening strike")
	for mods in [[], ["pierce"], ["returning_wave"], ["charged_wave"], ["pierce", "returning_wave", "charged_wave"]]:
		var cards := _cards()
		for id in mods: cards.append(select(id, "skill"))
		var program := resolver.resolve({"selections": cards, "revision": 1})
		check(not program.is_empty(), "all four compatible with " + str(mods))
		var session := Session.new()
		session.configure(builds, 1, func(_s): return OK)
		cards.reverse()
		check(session.restore_selections(cards).ok, "unordered cross-room rebuild " + str(mods))
		var summary := Capabilities.summarize_plan(builds, program.actions.skill)
		check(summary[0].freeze_window_ids.has("test_freeze"), "buildup advertises real freeze window")
		check(not summary[0].status_ids.has("test_freeze"), "buildup does not pretend to be immediate freeze")
	# Adapting windows must not accidentally claim legacy duration effects modify elemental freeze.
	check(resolver.legal_operations({"selections": [select("ice_core", "skill")], "revision": 0}, "freeze_duration").is_empty(), "unadapted legacy duration stays unavailable")

func _windows(id: String) -> void:
	var f := setup(_cards())
	var target = _tough(id)
	_hit(f, "skill", target)
	check(not f.runtime.statuses.snapshot(target).has("test_freeze") and f.player.protection_amount == 0, "chill alone no window or shield: " + id)
	check(is_equal_approx(_hit(f, "primary", target), 10.0), "partial chill no opening bonus")
	_hit(f, "skill", target)
	_hit(f, "skill", target)
	var snapshot: Dictionary = f.runtime.statuses.snapshot(target)
	check(snapshot.has("test_freeze") and target.control_locked == (id == "scout"), "real freeze or boss window: " + id)
	check(f.player.protection_amount == builds.upgrade("ice_coat").ranks[0].shield_amount, "real window grants finite shield")
	var ctx: Dictionary = f.runtime._context_for_cast(f.player.runner.cast_id)
	check(Conditional.evaluate(ctx, target, 10.0, "direct_projectile", f.runtime.statuses, builds, f.runtime.get_instance_id()).bonus == 0, "same cast/return cannot follow itself")
	check(is_equal_approx(_hit(f, "primary", target), 15.0), "other-action left opening bonus")
	check(is_equal_approx(_hit(f, "skill", target), 16.0), "later right followup bonus")
	check(f.runtime.statuses.snapshot(target).test_freeze.source == snapshot.test_freeze.source, "bonuses do not refresh or consume window")
	f.player.clear_protection()
	f.runtime.frost.shield_cooldown = 0.0
	for i in 3: _hit(f, "skill", target)
	check(f.player.protection_amount == 0.0, "active freeze failure cannot regrant shield")
	f.runtime.statuses.tick(float(f.runtime.statuses.snapshot(target).test_freeze.remaining) + 0.01)
	for i in 3: _hit(f, "skill", target)
	check(f.player.protection_amount == 0.0 and not f.runtime.statuses.snapshot(target).has("test_freeze"), "thaw immunity cannot regrant shield")
	check(is_equal_approx(_hit(f, "primary", target), 10.0), "mark/slow/thaw immunity no opening")
	f.runtime.statuses.tick(100.0)
	for i in 3: _hit(f, "skill", target)
	check(f.player.protection_amount > 0, "new valid window after immunity grants protection")
	var before: float = f.player.protection_amount
	f.runtime.tick(0)
	check(f.player.protection_amount == before, "pause preserves shield")
	f.runtime.clear_room()
	check(f.player.protection_amount == 0 and f.runtime.statuses.snapshot(target).is_empty(), "room clear removes shield and windows")
	clean(f)

func _sources() -> void:
	var cards := _cards()
	cards.append(select("ice_core", "primary"))
	var f := setup(cards)
	var target = _tough()
	for i in 3: _hit(f, "primary", target)
	check(f.player.protection_amount == 0, "right coat does not borrow left freeze")
	check(is_equal_approx(_hit(f, "primary", target), 10.0), "opening cannot follow own left freeze")
	check(is_equal_approx(_hit(f, "skill", target), 10.0), "right followup cannot borrow left freeze")
	f.runtime.statuses.clear()
	f.runtime.elements.clear()
	for i in 3: _hit(f, "skill", target)
	var source: Dictionary = f.runtime.statuses.snapshot(target).test_freeze.source
	var later := _begin(f, "skill")
	for origin in ["split_projectile", "explosion"]:
		check(Conditional.evaluate(later, target, 10, origin, f.runtime.statuses, builds, f.runtime.get_instance_id()).bonus == 0, "derived origin excluded: " + origin)
	for key in ["runtime_id", "room_generation", "source_handle", "team", "root_id", "action_id"]:
		f.runtime.statuses.clear()
		var wrong := source.duplicate(true)
		wrong[key] = "debug_arrow" if key == "action_id" else int(wrong[key]) + 100
		f.runtime.statuses.apply(target, "test_freeze", 1.2, wrong)
		check(Conditional.evaluate(later, target, 10, "direct_projectile", f.runtime.statuses, builds, f.runtime.get_instance_id()).bonus == 0, "foreign provenance rejected: " + key)
	clean(f)

func _path_and_lifecycle() -> void:
	var f := setup(_cards() + [select("returning_wave", "skill"), select("pierce", "skill")])
	cast(f, "skill")
	f.runtime.tick(0.3)
	check(not f.runtime.frost.paths.is_empty(), "real wave emits path")
	var paths: Array = f.runtime.frost.paths.duplicate(true)
	f.runtime.tick(0)
	check(f.runtime.frost.paths == paths, "pause holds path positions and expiry")
	var target = _tough("scout", paths[0].position)
	var hp: float = target.health.current
	f.runtime.tick(0.01)
	check(target.control_move_scale < 1.0 and not target.control_locked and target.health.current == hp, "path only slows, no damage/freeze")
	for i in 50: f.runtime.tick(0.1)
	check(f.runtime.frost.paths.size() <= int(builds.upgrade("frost_path").ranks[0].max_targets), "path count bounded")
	f.runtime.tick(10.0)
	check(f.runtime.frost.paths.is_empty(), "all trail segments expire")
	f.runtime.clear_room()
	check(f.runtime.diagnostics().roots == 0 and f.runtime.statuses.snapshot(target).is_empty(), "room clear releases trail roots and slows")
	f.player.runner.cancel(); f.player.runner._cooldowns.clear()
	cast(f, "skill"); f.runtime.tick(0.3)
	f.player.receive_hit(10000)
	f.runtime.tick(0.01)
	check(f.runtime.frost.paths.is_empty() and f.runtime.diagnostics().roots == 0, "source death clears pending paths")
	clean(f)

func _advance(f: Dictionary, seconds: float) -> void:
	var left := seconds
	while left > 0.000001:
		var dt := minf(0.01, left)
		f.runtime.statuses.tick(dt); f.player.step(dt); f.runtime.tick(dt)
		left -= dt

func _real_projectiles() -> void:
	# No cooldown resets: four real waves at normal fire cadence, with a real pierced contact.
	var f := setup(_cards() + [select("pierce", "skill")])
	var target = _tough("elite_ranger", Vector3.FORWARD * 2.0)
	var rear = _tough("scout", Vector3.FORWARD * 4.0)
	for i in 3:
		f.player.request_skill(); _advance(f, 1.02)
	check(f.runtime.statuses.snapshot(target).has("test_freeze") and f.runtime.statuses.snapshot(rear).has("test_freeze"), "three actual pierced waves create windows")
	f.player.request_skill(); _advance(f, 0.4)
	check(f.runtime.diagnostics().conditional_hits == 2, "fourth actual wave gains followup on both targets")
	clean(f)
	# Charged/returning versions share the same program and trail. Same-root return gains no followup.
	f = setup(_cards() + [select("charged_wave", "skill"), select("returning_wave", "skill")])
	var projectile_facts: Array = []
	f.runtime.projectile_presented.connect(func(fact): projectile_facts.append(fact))
	target = _tough("scout", Vector3.FORWARD * 2.0)
	for i in 2: _hit(f, "skill", target)
	f.player.runner.cancel(); f.player.runner._cooldowns.clear()
	f.player.press_skill(); f.player.step(1.2); f.player.release_skill(); _advance(f, 0.15)
	check(f.player.runner.cast_charged and f.runtime.statuses.snapshot(target).has("test_freeze"), "charged ice opens window")
	check(projectile_facts.any(func(p): return p.charged and p.radius > builds.projectile("sword_wave").radius_m), "charged collision uses large radius")
	_advance(f, 0.5)
	check(f.runtime.diagnostics().conditional_hits == 0 and not f.runtime.frost.paths.is_empty(), "same charged returning root leaves trail without self-followup")
	clean(f)
