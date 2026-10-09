extends SceneTree
const Loader = preload("res://content/builds/build_loader.gd")
const Resolver = preload("res://combat/builds/build_resolver.gd")
const Caps = preload("res://combat/builds/projectile_capabilities.gd")
var failures: Array[String] = []
var checks := 0
var resolver
var catalog

func _init() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func selection(id: String, action: String, rank: int = 1) -> Dictionary:
	return {"upgrade_id": id, "action_id": action, "rank": rank}

func state(items: Array = [], revision: int = 0) -> Dictionary:
	return {"selections": items, "revision": revision}

func operation(s: Dictionary, id: String, action: String, old: Dictionary = {}, rank: int = 1) -> Dictionary:
	return {"upgrade_id": id, "action_id": action, "operation": "replace" if not old.is_empty() else ("rank" if rank > 1 else "add"), "rank": rank, "replaced": old, "base_revision": s.revision}

func run() -> void:
	var loader := Loader.new()
	catalog = loader.load_catalog()
	check(catalog != null, "catalog v6: " + str(loader.errors))
	if catalog == null: finish(); return
	resolver = Resolver.new()
	resolver.configure(catalog)
	var empty := state()
	var program: Dictionary = resolver.resolve(empty)
	check(program.actions.primary.executor == "melee" and program.actions.primary.ability_ids.size() == 3, "base primary combo")
	check(program.actions.special.form_id == "sword_heavy" and program.actions.special.ability_ids == ["heavy_slash"], "base special heavy")
	check(resolver.valid_program(program) and Caps.valid_program(program, catalog), "whole program authority")
	check(resolver.resolve({"power": 1}).is_empty(), "legacy global ranks rejected")
	check(resolver.legal_operations(empty, "pierce").size() == 1 and resolver.legal_operations(empty, "pierce")[0].action_id == "skill", "base skill alone grants formal projectile capability")
	check(resolver.legal_operations(empty, "wave").is_empty(), "debug wave out of formal candidates")
	check(resolver.legal_operations(empty, "freeze_duration").is_empty(), "no uncarried freeze duration")
	var frozen_primary := state([selection("contact_freeze", "primary")])
	var duration_choices: Array = resolver.legal_operations(frozen_primary, "freeze_duration")
	check(duration_choices.size() == 1 and duration_choices[0].action_id == "primary", "same action carrier only")
	var two_cores := state([selection("contact_freeze", "primary"), selection("impact_blast", "primary")])
	check(resolver.resolve(two_cores).is_empty(), "one core per action")
	var two_actions := state([selection("contact_freeze", "primary", 2), selection("contact_freeze", "special")])
	program = resolver.resolve(two_actions)
	check(program.actions.primary.effects[0].rank == 2 and program.actions.special.effects[0].rank == 1, "same card independent action ranks")
	var source := state([selection("contact_freeze", "skill"), selection("pierce", "skill"), selection("impact_blast", "primary")], 7)
	program = resolver.resolve(source)
	check(not program.is_empty() and program.actions.primary.effects.size() == 1 and program.actions.skill.effects.size() == 2, "left blast right pierce freeze")
	var reversed: Dictionary = source.duplicate(true)
	reversed.selections.reverse()
	check(resolver.resolve(reversed) == program, "selection order independent")
	check(program.is_read_only() and program.actions.is_read_only() and program.actions.skill.effects.is_read_only(), "recursive readonly program")
	var forged: Dictionary = program.duplicate(true)
	forged.actions.skill.damage_scale += 1.0
	check(not resolver.valid_program(forged) and not Caps.valid_program(forged, catalog), "forged program numeric field rejected")
	var split_source: Dictionary = source.duplicate(true)
	split_source.selections.append(selection("split", "skill"))
	check(resolver.resolve(split_source).is_empty(), "same action pierce split rejected")
	# Debug fixture still compiles through this authority, in an isolated action.
	var cross: Dictionary = source.duplicate(true)
	cross.selections.append(selection("split", "debug_arrow"))
	check(not resolver.resolve(cross).is_empty(), "different actions contact strategy independence")
	var frost := state([selection("impact_blast", "skill"), selection("frost_blast", "skill"), selection("pierce", "skill")])
	program = resolver.resolve(frost)
	check(not program.is_empty(), "finite frost pierce plan")
	var blast: Dictionary = program.actions.skill.effects.filter(func(e): return e.type == "explosion")[0]
	check(blast.params.payloads.size() == 2, "finite explicit damage and status payload")
	var bad_frost: Dictionary = frost.duplicate(true)
	bad_frost.selections.append(selection("split", "skill"))
	check(resolver.resolve(bad_frost).is_empty(), "full unsupported frost split pierce set rejected")
	bad_frost.selections.erase(selection("pierce", "skill"))
	check(resolver.resolve(bad_frost).is_empty(), "split frost rejected without pierce")
	var simple := state([selection("contact_freeze", "special")], 9)
	var replace := operation(simple, "impact_blast", "special", simple.selections[0])
	var result: Dictionary = resolver.evaluate(simple, replace)
	check(result.ok and result.state.revision == 10 and result.state.selections == [selection("impact_blast", "special")], "core replacement legal without dependents")
	check(simple.selections == [selection("contact_freeze", "special")] and simple.revision == 9, "pure evaluator leaves source unchanged")
	var dependency := state([selection("contact_freeze", "special"), selection("freeze_duration", "special")], 9)
	result = resolver.evaluate(dependency, replace)
	check(not result.ok and result.error_key == "build.reason.capability", "core replacement refuses to invalidate support")
	check(resolver.resolve(state([selection("sword_wave_form", "special")])).is_empty(), "old unlock state rejected rather than reinterpreted as heavy")
	check(program.actions.special.form_id == "sword_heavy", "skill upgrades cannot replace heavy action")
	replace.base_revision -= 1
	check(not resolver.evaluate(simple, replace).ok, "stale revision rejected")
	replace.base_revision = 9
	replace.replaced = {}
	check(not resolver.evaluate(simple, replace).ok, "forged replacement rejected")
	var stats := state([selection("power", "global", 2), selection("action_power", "special", 3), selection("agility", "global")])
	program = resolver.resolve(stats)
	check(is_equal_approx(program.actions.primary.damage_scale, 1.4) and is_equal_approx(program.actions.special.damage_scale, 2.0) and is_equal_approx(program.global.move_scale, 1.1), "global and action additive once")
	for preset in catalog.test_presets():
		var current := state()
		for item in preset.selections:
			for rank in range(1, int(item.rank) + 1):
				var op := operation(current, item.upgrade_id, item.action_id, {}, rank)
				var accepted: Dictionary = resolver.evaluate(current, op)
				check(accepted.ok, "preset uses same evaluator " + str(preset.id))
				if accepted.ok: current = accepted.state
		check(resolver.valid_program(resolver.resolve(current)), "preset valid program " + str(preset.id))
	for op in resolver.legal_operations(source):
		var accepted: Dictionary = resolver.evaluate(source, op)
		check(accepted.ok and resolver.valid_program(accepted.program), "candidate commit/program alignment " + str(op.upgrade_id))
	check_content(loader)
	finish()

func check_content(loader) -> void:
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/builds/prototype.json"))
	for version in [1, 2, 3, 4, 5, 7]:
		var changed: Dictionary = original.duplicate(true)
		changed.schema_version = version
		check(loader.decode(changed) == null, "reject unsupported schema " + str(version))
	var changed: Dictionary = original.duplicate(true)
	changed.actions[0].form_ids = ["missing"]
	check(loader.decode(changed) == null, "reject unknown form")
	changed = original.duplicate(true)
	changed.upgrades[0].requires = ["agility"]
	changed.upgrades[1].requires = ["power"]
	check(loader.decode(changed) == null, "reject dependency cycle")
	changed = original.duplicate(true)
	changed.test_attacks[0].action_id = "special"
	check(loader.decode(changed) == null, "debug attack must isolate source")
	changed = original.duplicate(true)
	changed.offer.pool_ids.append("chain")
	check(loader.decode(changed) == null, "no fixture upgrade in formal pool")
	changed = original.duplicate(true)
	changed.test_presets[0].selections = [selection("impact_blast", "primary"), selection("contact_freeze", "primary")]
	check(loader.decode(changed) == null, "preset duplicate core rejected")

func finish() -> void:
	print(JSON.stringify({"test": "bound_build_policy", "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
