extends "res://tests/action_build_runtime.gd"
const Session = preload("res://app/session/training_build_session.gd")
const Sampler = preload("res://rogue/build_offer_sampler.gd")
const Conditional = preload("res://combat/builds/conditional_damage.gd")
var checks := 0
var fail_commit := false
func check(ok: bool, message: String) -> void:
	checks += 1
	super.check(ok, message)
func run() -> void:
	var loader := BuildLoader.new()
	builds = loader.load_catalog()
	combat = CombatLoader.new().load_catalog()
	check(builds != null and combat != null, "catalogs load " + str(loader.errors))
	if builds == null or combat == null: quit(1); return
	resolver.configure(builds)
	check_policy()
	check_session()
	for distance in [2.0, 6.0]: check_window(distance)
	check_melee_and_derived()
	check_provenance()
	check_pierce_and_split()
	check_resistance()
	check_additive_and_coexistence()
	print("FREEZE_FOLLOWUP ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
func state(items: Array) -> Dictionary:
	return {"selections": items, "revision": 1}
func check_policy() -> void:
	var empty := state([])
	for id in ["shatter_followup", "opening_strike"]:
		check(resolver.legal_operations(empty, id).is_empty(), "no self-granted prerequisite " + id)
	var q := state([select("contact_freeze", "skill")])
	check(resolver.legal_operations(q, "contact_freeze").all(func(o): return o.action_id != "skill"), "no ineffective rank2 offer")
	check(not resolver.validate_state(state([select("contact_freeze", "skill", 2)])).is_empty(), "old rank2 rejected explicitly")
	for id in ["shatter_followup", "opening_strike"]:
		var ops: Array = resolver.legal_operations(q, id)
		check(ops.size() == 1 and ops[0].action_id == ("skill" if id == "shatter_followup" else "primary"), "only intended receiver " + id)
	var only_left := state([select("contact_freeze", "primary")])
	check(resolver.legal_operations(only_left, "opening_strike").is_empty(), "own freeze cannot qualify cross-action card")
	check(resolver.legal_operations(state([select("contact_freeze", "debug_arrow")]), "opening_strike").is_empty(), "debug cannot provide prerequisite")
	var all_cards := state([select("contact_freeze", "skill"), select("shatter_followup", "skill"), select("opening_strike", "primary"), select("pierce", "skill")])
	check(not resolver.resolve(all_cards).is_empty(), "two cards coexist with pierce")
	check(resolver.legal_operations(all_cards, "impact_blast").all(func(o): return o.action_id != "skill"), "replacement rejects loss of final provider")
	check(resolver.legal_operations(q, "impact_blast").any(func(o): return o.action_id == "skill" and o.operation == "replace" and o.replaced.upgrade_id == "contact_freeze"), "plain freeze replacement explicitly removes core")
	var area := state([select("impact_blast", "skill"), select("frost_blast", "skill")])
	check(not resolver.legal_operations(area, "shatter_followup").is_empty() and not resolver.legal_operations(area, "opening_strike").is_empty(), "real area freeze supplies both cards")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/builds/prototype.json"))
	for version in [5, 6, 8]:
		var wrong := data.duplicate(true); wrong.schema_version = version
		check(BuildLoader.new().decode(wrong) == null, "unsupported content version rejected " + str(version))
	for field in ["source_relation", "root_relation", "provider_scope", "allowed_origins", "bonus"]:
		var wrong := data.duplicate(true)
		var entry: Dictionary = wrong.upgrades.filter(func(u): return u.id == "shatter_followup")[0]
		entry.ranks[0][field] = ["split_projectile"] if field == "allowed_origins" else (-1 if field == "bonus" else "anything")
		check(BuildLoader.new().decode(wrong) == null, "bad conditional schema rejected " + field)
func check_session() -> void:
	var session := Session.new()
	session.configure(builds, 37, func(_candidate): return ERR_CANT_CREATE if fail_commit else OK)
	check(session.apply_test_preset("freeze_pierce").ok, "preset through official session")
	var seen: Dictionary = {}
	var sampler := Sampler.new()
	sampler.configure(builds, resolver.legal_operations)
	var rng := RandomNumberGenerator.new(); rng.seed = 47
	for i in 80:
		var ids: Dictionary = {}
		for op in sampler.sample(session.snapshot(), rng):
			check(not ids.has(op.upgrade_id), "offer samples upgrade once")
			ids[op.upgrade_id] = true; seen[op.upgrade_id] = true
	check(seen.has("shatter_followup") and seen.has("opening_strike"), "both cards reachable in normal pool")
	var chosen: Dictionary = {}
	for seed_value in 40:
		var probe := Session.new()
		probe.configure(builds, seed_value, func(_candidate): return OK)
		probe.apply_test_preset("freeze_pierce")
		probe.open_offer()
		var offer: Dictionary = probe.snapshot().offer
		for candidate in offer.candidates:
			if candidate.upgrade_id not in ["shatter_followup", "opening_strike"]: continue
			check(probe.choose(offer.id, candidate.choice_id).ok, "ordinary locked choice commits " + str(candidate.upgrade_id))
			chosen[candidate.upgrade_id] = true
			break
		if chosen.size() == 2: break
	check(chosen.size() == 2, "both cards selected through normal offer tokens")
	var op: Dictionary = session.legal_operations("opening_strike")[0]
	var before: Dictionary = session.snapshot()
	fail_commit = true
	check(not session.submit_operation(op).ok and session.snapshot() == before, "failed commit preserves all state and RNG")
	fail_commit = false
	check(session.submit_operation(op).ok, "real conditional submission accepted")
	before = session.snapshot()
	check(not session.submit_operation(op).ok and session.snapshot() == before, "stale operation preserves all state and RNG")
	for id in ["freeze_pierce", "freeze_followup", "freeze_opening"]:
		check(session.apply_test_preset(id).ok, "new preset " + id)
func tough(point: Vector3):
	var target = actor("brute", 1, point)
	target.health.maximum = 1000.0; target.health.current = 1000.0
	return target
func advance(f: Dictionary, duration: float) -> void:
	var remaining := duration
	while remaining > 0.000001:
		var dt := minf(1.0 / 120.0, remaining)
		f.runtime.statuses.tick(dt)
		f.player.step(dt)
		f.melee.resolve(f.player, actors)
		f.runtime.tick(dt)
		remaining -= dt
func check_window(distance: float) -> void:
	var f := setup([select("contact_freeze", "skill"), select("shatter_followup", "skill")])
	var victim = tough(Vector3.FORWARD * distance)
	f.player.request_skill(); advance(f, 0.85)
	check(is_equal_approx(victim.health.current, 976.0), "first Q only base damage at " + str(distance))
	var frozen: Dictionary = f.runtime.statuses.snapshot(victim)
	check(frozen.has("test_freeze"), "first Q commits freeze")
	var original_source: Dictionary = frozen.test_freeze.source
	advance(f, 0.2); f.player.request_skill(); advance(f, 0.8)
	check(is_equal_approx(victim.health.current, 937.6), "second independent Q +60% near/mid " + str(distance))
	check(f.runtime.diagnostics().conditional_hits == 1, "exactly one committed feedback")
	# At equal distance arrival separation is ~1.05s, within the 1.2s window.
	print("FOLLOWUP_WINDOW distance=", distance, " cooldown=", combat.ability("wave_cast").cooldown, " damage=", 1000.0 - victim.health.current)
	check(original_source.root_id < f.runtime.diagnostics().last_conditional.root_id, "independent earlier source root")
	advance(f, 2.0)
	check(not victim.control_locked, "followup did not refresh freeze")
	clean(f)
func check_melee_and_derived() -> void:
	var f := setup([select("contact_freeze", "skill"), select("opening_strike", "primary"), select("impact_blast", "primary")], func(_a, _b): return null)
	var victim = tough(Vector3.FORWARD)
	var side = tough(Vector3(2.3, 0, -1))
	cast(f, "skill"); f.runtime.tick(0.12)
	f.player.runner.cancel()
	var before: float = victim.health.current
	cast(f, "primary")
	var base: float = combat.ability("slash.1").damage
	check(is_equal_approx(before - victim.health.current, base * 1.5), "left +50% on prior Q freeze")
	check(f.runtime.diagnostics().conditional_hits == 1, "left feedback once")
	var explosion: Dictionary = builds.upgrade("impact_blast").ranks[0]
	check(1000.0 - side.health.current <= base * float(explosion.damage_ratio), "blast never inherits followup multiplier")
	f.player.runner.cancel(); before = victim.health.current
	cast(f, "special")
	check(is_equal_approx(before - victim.health.current, combat.ability("heavy_slash").damage), "right gets neither card bonus")
	clean(f)
	# Area freeze provider and Q followup: its blast must still use unmodified Q damage.
	f = setup([select("contact_freeze", "primary"), select("impact_blast", "skill"), select("frost_blast", "skill"), select("shatter_followup", "skill")], func(_a, _b): return null)
	victim = tough(Vector3.FORWARD); side = tough(Vector3(2.3, 0, -1))
	cast(f, "primary"); f.player.runner.cancel(); before = victim.health.current
	cast(f, "skill"); f.runtime.tick(0.12)
	check(is_equal_approx(before - victim.health.current, 38.4), "Q can follow earlier player melee freeze")
	check(1000.0 - side.health.current <= 24.0 * float(explosion.damage_ratio), "Q blast base excludes conditional damage")
	clean(f)
func check_provenance() -> void:
	var f := setup([select("contact_freeze", "skill"), select("shatter_followup", "skill")])
	var victim = tough(Vector3.FORWARD)
	cast(f, "skill"); f.runtime.tick(0.12)
	var source: Dictionary = f.runtime.statuses.snapshot(victim).test_freeze.source
	var ctx: Dictionary = f.runtime._context_for_cast(f.player.runner.cast_id)
	# The root may be alive, but the freeze from this root cannot enhance itself.
	check(Conditional.evaluate(ctx, victim, 24.0, "direct_projectile", f.runtime.statuses, builds, f.runtime.get_instance_id()).bonus == 0.0, "same root cannot follow itself")
	var later := ctx.duplicate(true); later.id += 1
	check(Conditional.evaluate(later, victim, 24.0, "split_projectile", f.runtime.statuses, builds, f.runtime.get_instance_id()).bonus == 0.0, "split origin never gets bonus")
	check(not f.runtime.statuses.apply(victim, "test_freeze", 3.0, {"source_handle": 999}, {}), "active refresh refused")
	check(f.runtime.statuses.snapshot(victim).test_freeze.source == source, "refused freeze preserves original provenance")
	for field in ["source_handle", "team", "room_generation", "runtime_id", "action_id", "root_id"]:
		f.runtime.statuses.clear()
		var bad := source.duplicate(true)
		bad[field] = "debug_arrow" if field == "action_id" else int(bad[field]) + 100
		check(f.runtime.statuses.apply(victim, "test_freeze", 1.2, bad), "fixture source installed " + field)
		check(Conditional.evaluate(later, victim, 24.0, "direct_projectile", f.runtime.statuses, builds, f.runtime.get_instance_id()).bonus == 0.0, "wrong provenance blocked " + field)
	f.runtime.clear_room()
	check(f.runtime.statuses.snapshot(victim).is_empty() and f.runtime.diagnostics().conditional_hits == 0, "room clears status and feedback")
	clean(f)
func check_pierce_and_split() -> void:
	var f := setup([select("contact_freeze", "skill"), select("shatter_followup", "skill"), select("pierce", "skill")])
	var first = tough(Vector3.FORWARD * 2.0)
	f.player.request_skill(); advance(f, 1.05)
	var second = tough(Vector3.FORWARD * 4.0)
	f.player.request_skill(); advance(f, 0.5)
	check(is_equal_approx(first.health.current, 937.6) and is_equal_approx(second.health.current, 976.0), "pierce evaluates each pre-hit status independently")
	check(f.runtime.diagnostics().conditional_hits == 1, "pierce no duplicate correction")
	clean(f)
	f = setup([select("contact_freeze", "skill"), select("shatter_followup", "skill"), select("split", "skill")])
	first = tough(Vector3.FORWARD * 2.0)
	f.player.request_skill(); advance(f, 1.05)
	f.player.request_skill(); advance(f, 0.15)
	for child in f.runtime._projectiles.values():
		if child.generation > 0:
			check(is_equal_approx(child.damage, 24.0 * float(builds.upgrade("split").ranks[0].damage_ratio)), "child base never amplified by parent followup")
	clean(f)
func check_resistance() -> void:
	var original = builds
	for response in ["immune", "resistant"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/builds/prototype.json"))
		data.status_rules.actor_responses["brute"] = response
		var loader := BuildLoader.new()
		builds = loader.decode(data)
		check(builds != null, "response catalog " + str(loader.errors))
		if builds == null: continue
		resolver.configure(builds)
		var f := setup([select("contact_freeze", "skill"), select("shatter_followup", "skill")])
		var victim = tough(Vector3.FORWARD * 2.0)
		f.player.request_skill(); advance(f, 1.05)
		f.player.request_skill(); advance(f, 0.5)
		check(f.runtime.diagnostics().conditional_hits == 0 and is_equal_approx(victim.health.current, 952.0), "immune/thawed-resistant never fabricates bonus " + response)
		clean(f)
	builds = original; resolver.configure(builds)
func check_additive_and_coexistence() -> void:
	var f := setup([select("contact_freeze", "skill"), select("shatter_followup", "skill"), select("opening_strike", "primary"), select("pierce", "skill")])
	var victim = tough(Vector3.FORWARD)
	cast(f, "skill"); f.runtime.tick(0.12); f.player.runner.cancel()
	cast(f, "primary")
	check(f.runtime.diagnostics().last_conditional.action_id == "primary", "coexisting cards: primary follows Q")
	var ctx: Dictionary = f.runtime._context_for_cast(f.player.runner.cast_id)
	var test_context := ctx.duplicate(true)
	# Two supported modifiers add, cap once, then multiply ordinary scaled damage.
	var duplicate: Dictionary = test_context.program.effects.filter(func(e): return e.type == "conditional_damage")[0].duplicate(true)
	duplicate.upgrade_id = "fixture_second_modifier"; duplicate.params.bonus = 1.7
	test_context.program.effects.append(duplicate)
	var result := Conditional.evaluate(test_context, victim, 30.0, "direct_melee", f.runtime.statuses, builds, f.runtime.get_instance_id())
	check(result.bonus == 2.0 and result.damage == 90.0, "multiple corrections additive, bounded, applied once")
	check(Conditional.evaluate(test_context, victim, 30.0, "explosion", f.runtime.statuses, builds, f.runtime.get_instance_id()).damage == 30.0, "derived origin explicitly excluded")
	f.player.runner.cancel(); f.player.runner.tick(1.0)
	cast(f, "skill"); f.runtime.tick(0.12)
	check(f.runtime.diagnostics().conditional_hits == 2 and f.runtime.diagnostics().last_conditional.action_id == "skill", "coexisting cards: Q also follows independently")
	var saved: Dictionary = f.runtime.statuses.snapshot(victim)
	f.runtime.statuses.tick(0.0); f.runtime.tick(0.0)
	check(f.runtime.statuses.snapshot(victim) == saved, "pause does not consume frozen window")
	victim.receive_hit(10000.0)
	check(f.runtime.statuses.snapshot(victim).is_empty(), "death clears provenance")
	clean(f)


