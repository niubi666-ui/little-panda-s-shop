extends "res://tests/action_build_runtime.gd"
## Headless regression: only earth into an active freeze window may shatter.
var facts: Array = []

func _hit(f: Dictionary, action: String, target) -> void:
	f.player.runner.cancel()
	f.player.runner._cooldowns.clear()
	var plan: Dictionary = f.program.actions[action]
	check(f.player.runner.start(combat.ability(plan.ability_ids[0]), Vector3.FORWARD, plan), "test action starts")
	var context: Dictionary = f.runtime._context_for_cast(f.player.runner.cast_id)
	f.runtime._apply_direct_damage(context, target, 1.0, "direct_melee")

func _count() -> int:
	return facts.filter(func(fact): return fact.event == "reaction" and fact.reaction_id == "shatter").size()

func _fixture() -> Dictionary:
	var f := setup([select("ice_core", "skill"), select("earth_core", "special")])
	facts.clear()
	f.runtime.element_presented.connect(func(fact): facts.append(fact))
	return f

func _target(id: String):
	var target = actor(id, 1, Vector3.FORWARD)
	target.health.maximum = 10000.0
	target.health.current = 10000.0
	return target

func run() -> void:
	var loader := BuildLoader.new()
	builds = loader.load_catalog()
	combat = CombatLoader.new().load_catalog()
	check(builds != null and combat != null, "catalogs load: " + str(loader.errors))
	if builds == null or combat == null: quit(1); return
	resolver.configure(builds)
	for id in ["scout", "elite_ranger"]:
		var f := _fixture()
		var target = _target(id)
		_hit(f, "skill", target)
		check(not f.runtime.statuses.snapshot(target).has("test_freeze"), "one chill is not freeze: " + id)
		_hit(f, "special", target)
		check(_count() == 0, "one chill plus earth cannot shatter: " + id)
		# Earth must not consume partial chill; it can still build up to a real window.
		_hit(f, "skill", target)
		_hit(f, "skill", target)
		check(f.runtime.statuses.snapshot(target).has("test_freeze"), "chill reaches active freeze: " + id)
		check(target.control_locked == (id == "scout"), "boss window is slow, ordinary freeze locks")
		# Partial chill reapplied while frozen must not bypass window consumption.
		_hit(f, "skill", target)
		_hit(f, "special", target)
		check(_count() == 1, "earth shatters once: " + id)
		check(not f.runtime.statuses.snapshot(target).has("test_freeze"), "shatter consumes window: " + id)
		check(not f.runtime.elements.stacks_on(target.handle).has("ice"), "shatter consumes residual chill")
		_hit(f, "special", target)
		check(_count() == 1, "thaw immunity is not another window: " + id)
		clean(f)
	var f := _fixture()
	var target = _target("scout")
	_hit(f, "special", target)
	_hit(f, "skill", target)
	check(_count() == 0, "reverse earth then ice cannot shatter")
	clean(f)
	f = _fixture()
	target = _target("scout")
	for i in 3: _hit(f, "skill", target)
	f.runtime.statuses.tick(float(builds.status("test_freeze").max_duration_sec) + 0.01)
	_hit(f, "special", target)
	check(_count() == 0, "expired freeze and mark cannot shatter")
	clean(f)
	# Existing effects intentionally use current global boosts (user decision).
	f = setup([select("fire_core", "primary")])
	target = _target("scout")
	_hit(f, "primary", target)
	var hp: float = target.health.current
	f.runtime.elements.tick(0.5, f.runtime)
	var before: float = hp - target.health.current
	var updated := resolver.resolve({"selections": [select("fire_core", "primary"), select("fire_kindling", "global")], "revision": 2})
	check(f.runtime.set_program(updated), "global boost upgrade applies")
	hp = target.health.current
	f.runtime.elements.tick(0.5, f.runtime)
	check(hp - target.health.current > before, "existing burn uses upgraded global boost")
	clean(f)
	print("SHATTER_WINDOW ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
