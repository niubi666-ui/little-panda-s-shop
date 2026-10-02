extends SceneTree
## CLI rule/transaction test. Runs without editor, actors, or graphics.

const Capabilities = preload("res://combat/builds/projectile_capabilities.gd")
const Resolver = preload("res://combat/builds/build_resolver.gd")
const Loader = preload("res://content/builds/build_loader.gd")
const Catalog = preload("res://content/builds/build_catalog.gd")
const Sampler = preload("res://rogue/build_offer_sampler.gd")
const Session = preload("res://app/session/training_build_session.gd")

var failures: Array[String] = []
var _data: Dictionary
var _catalog: Catalog
var _commit_failure := false
var _mutate_commit := false
var _commit_calls := 0
var _committed_copy: Dictionary = {}
var _reentry_session: Session
var _reentry_error := ""


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var loader := Loader.new()
	_catalog = loader.load_catalog()
	check(_catalog != null, "production catalog loads: " + str(loader.errors))
	if _catalog == null:
		_finish()
		return
	_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/builds/prototype.json"))
	_test_rejection()
	_test_readonly()
	_test_sampling()
	_test_session_commit()
	_test_exhaustion()
	_finish()


func _finish() -> void:
	print("BUILD_CHOICES ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _test_rejection() -> void:
	var value: Dictionary = _data.duplicate(true)
	value.erase("offer")
	_rejected(value, "missing required top-level field")
	value = _data.duplicate(true)
	value.offer["unknown"] = true
	_rejected(value, "unknown nested field")
	value = _data.duplicate(true)
	value.schema_version = 1
	_rejected(value, "unsupported version")
	value = _data.duplicate(true)
	value.upgrades[0].weight = NAN
	_rejected(value, "NaN rejected")
	value = _data.duplicate(true)
	value.upgrades[0].ranks[0].bonus = INF
	_rejected(value, "infinity rejected")
	value = _data.duplicate(true)
	value.offer.count = true
	_rejected(value, "boolean cannot be a number")
	value = _data.duplicate(true)
	value.upgrades[0].max_rank = 1.5
	_rejected(value, "fractional rank rejected")
	value = _data.duplicate(true)
	value.upgrades[0].effect_type = "execute_script"
	_rejected(value, "unimplemented effect rejected")
	value = _data.duplicate(true)
	value.upgrades[0].ranks.remove_at(0)
	_rejected(value, "rank length mismatch")
	value = _data.duplicate(true)
	value.upgrades.append(value.upgrades[0].duplicate(true))
	_rejected(value, "duplicate upgrade id")
	value = _data.duplicate(true)
	value.offer.pool_ids.append("unknown_upgrade")
	_rejected(value, "unknown pool reference")
	value = _data.duplicate(true)
	value.offer.pool_ids.append(value.offer.pool_ids[0])
	_rejected(value, "duplicate pool id")
	value = _data.duplicate(true)
	_entry(value, "power").requires = ["missing"]
	_rejected(value, "unknown prerequisite")
	value = _data.duplicate(true)
	_entry(value, "power").requires = ["agility"]
	_entry(value, "agility").requires = ["power"]
	_rejected(value, "prerequisite cycle")
	value = _data.duplicate(true)
	_entry(value, "power").excludes = ["agility"]
	_rejected(value, "asymmetric exclusion")
	value = _data.duplicate(true)
	value.projectiles[0].child_id = "missing"
	_rejected(value, "missing child reference rejected")
	value = _data.duplicate(true)
	value.projectiles[0].executor = "beam"
	_rejected(value, "unsupported executor rejected")
	value = _data.duplicate(true)
	_entry(value, "chain").ranks[0].jumps = value.limits.max_chain_jumps + 1
	_rejected(value, "chain beyond runtime budget")
	value = _data.duplicate(true)
	_entry(value, "split").ranks[0].max_generation = value.limits.max_split_generation + 1
	_rejected(value, "split generation exceeds runtime limit")
	value = _data.duplicate(true)
	value.projectiles[0].height_m = 0.0
	_rejected(value, "projectile height must be positive")
	value = _data.duplicate(true)
	value.stats.move_scale_min = value.stats.move_scale_max + 1.0
	_rejected(value, "inverted stat interval")
	value = _data.duplicate(true)
	value.upgrades[0].required_tags = ["missing_tag"]
	_rejected(value, "ungrantable required tag")
	value = _data.duplicate(true)
	_entry(value, "wave").required_tags = ["projectile"]
	_rejected(value, "upgrade cannot supply its own missing prerequisite tag")
	value = _data.duplicate(true)
	_entry(value, "power").required_tags = ["agile"]
	_entry(value, "power").granted_tags = ["strong"]
	_entry(value, "agility").required_tags = ["strong"]
	_entry(value, "agility").granted_tags = ["agile"]
	_rejected(value, "mutually dependent tag providers are unreachable")
	value = _data.duplicate(true)
	_entry(value, "split").requires = ["wave"]
	value.offer.pool_ids.erase("wave")
	_rejected(value, "unoffered definitions cannot supply prerequisite ranks or tags")
	value = _data.duplicate(true)
	_entry(value, "power").required_tags = ["external"]
	_entry(value, "agility").granted_tags = ["external"]
	value.offer.pool_ids.erase("agility")
	value.offer.fallback_ids.erase("agility")
	_rejected(value, "tag-only provider outside both offer lists cannot unlock a card")
	value = _data.duplicate(true)
	_entry(value, "split").requires = ["wave"]
	_entry(value, "wave").weight = 0.0
	_rejected(value, "zero-weight pool provider is unavailable without explicit fallback")
	value = _data.duplicate(true)
	value.upgrades[0].name_key = "a".repeat(129)
	_rejected(value, "bounded names")
	# A decoder can be reused after a failure without retaining stale errors.
	var loader := Loader.new()
	check(loader.decode(value) == null, "invalid fixture rejected")
	check(loader.decode(_data) != null and loader.errors.is_empty(), "decode resets previous errors")


func _test_readonly() -> void:
	var input: Dictionary = _data.duplicate(true)
	var catalog := Loader.new().decode(input)
	var original_bonus: float = catalog.upgrade("power").ranks[0].bonus
	_entry(input, "power").ranks[0].bonus = original_bonus + 1.0
	input.offer.pool_ids.clear()
	check(catalog.upgrade("power").ranks[0].bonus == original_bonus, "catalog detached from source nested data")
	check(not catalog.offer_rules().pool_ids.is_empty(), "offer arrays detached from source")
	check(catalog.entries().is_read_only(), "entries readonly")
	check(catalog.upgrade("power").is_read_only(), "entry readonly")
	check(catalog.upgrade("power").ranks.is_read_only(), "ranks array readonly")
	check(catalog.upgrade("power").ranks[0].is_read_only(), "rank parameters readonly")
	check(catalog.offer_rules().pool_ids.is_read_only(), "pool ids readonly")
	check(catalog.limits().is_read_only() and catalog.stat_limits().is_read_only(), "global rules readonly")


func _test_sampling() -> void:
	var sampler := Sampler.new()
	configure_sampler(sampler, _catalog)
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 719
	rng_b.seed = 719
	for repeat in 40:
		var first: Array[String] = sampler.sample({}, [], rng_a)
		check(first == sampler.sample({}, [], rng_b), "same seed reproduces offer %s" % repeat)
		var unique: Dictionary = {}
		for id in first:
			unique[id] = true
		check(unique.size() == first.size(), "no replacement in offer")
		check(not first.has("split"), "split excluded before prerequisite")
	check(sampler.is_eligible("split", {"wave": 1}, []), "real capability works without union tag")
	check(not sampler.is_eligible("split", {}, ["projectile"]), "tag alone is not capability")
	check(sampler.is_eligible("split", {"wave": 1}, ["projectile"]), "prerequisite and tag unlock split")
	var capped: Dictionary = {}
	for entry in _catalog.entries():
		capped[entry.id] = int(entry.max_rank)
	check(sampler.sample(capped, ["projectile"], rng_a).is_empty(), "all capped yields empty offer")
	check(not sampler.is_eligible("power", capped, []), "max rank filtered")
	var fixture: Dictionary = _data.duplicate(true)
	fixture.offer.pool_ids = []
	fixture.offer.fallback_ids = ["power", "agility"]
	var fallback_sampler := Sampler.new()
	configure_sampler(fallback_sampler, Loader.new().decode(fixture))
	var fallback: Array[String] = fallback_sampler.sample({}, [], rng_a)
	check(fallback == ["power", "agility"], "insufficient pool uses distinct explicit fallback in order")
	fixture = _data.duplicate(true)
	fixture.offer.pool_ids = ["power"]
	fixture.offer.fallback_ids = ["power", "agility"]
	configure_sampler(fallback_sampler, Loader.new().decode(fixture))
	check(fallback_sampler.sample({}, [], rng_a) == ["power", "agility"], "fallback does not duplicate pool pick")
	fixture = _data.duplicate(true)
	fixture.offer.count = 1
	fixture.offer.pool_ids = ["power", "agility"]
	fixture.offer.fallback_ids = []
	_entry(fixture, "power").weight = 0.0
	_entry(fixture, "agility").weight = 1000000000.0
	configure_sampler(fallback_sampler, Loader.new().decode(fixture))
	for repeat in 10:
		check(fallback_sampler.sample({}, [], rng_a) == ["agility"], "zero-weight pool entries not chosen")
	fixture = _data.duplicate(true)
	_entry(fixture, "power").excludes = ["agility"]
	_entry(fixture, "agility").excludes = ["power"]
	configure_sampler(fallback_sampler, Loader.new().decode(fixture))
	check(not fallback_sampler.is_eligible("power", {"agility": 1}, []), "exclusion filters owned opposing upgrade")
	# External and fallback providers break tag cycles legitimately.
	fixture = _data.duplicate(true)
	_entry(fixture, "wave").required_tags = ["projectile"]
	_entry(fixture, "power").granted_tags = ["projectile"]
	check(Loader.new().decode(fixture) != null, "reachable external provider permits a shared required/granted tag")
	fixture = _data.duplicate(true)
	_entry(fixture, "wave").weight = 0.0
	fixture.offer.fallback_ids.append("wave")
	check(Loader.new().decode(fixture) != null, "zero-weight explicit fallback can supply prerequisite tags")
	# The check does not assume every alternate branch must coexist.
	fixture = _data.duplicate(true)
	_entry(fixture, "power").excludes = ["agility"]
	_entry(fixture, "agility").excludes = ["power"]
	_entry(fixture, "power").granted_tags = ["branch_power"]
	_entry(fixture, "agility").granted_tags = ["branch_agility"]
	_entry(fixture, "chain").required_tags = ["branch_power"]
	check(Loader.new().decode(fixture) != null, "reachable alternative branches are not over-rejected")


func _test_session_commit() -> void:
	var session := Session.new()
	var twin := Session.new()
	session.configure(_catalog, 91823, _commit)
	twin.configure(_catalog, 91823, _commit)
	var before: Dictionary = session.snapshot()
	_commit_failure = true
	var rejected: Dictionary = session.open_offer()
	check(not rejected.ok and rejected.error == "commit_failed", "offer generation requires successful commit")
	check(session.snapshot() == before, "failed offer preserves all state including RNG and sequence")
	_commit_failure = false
	var opened: Dictionary = session.open_offer()
	var twin_offer: Dictionary = twin.open_offer()
	check(opened.ok and opened.offer == twin_offer.offer, "retry after failed save draws exact same candidates")
	check(session.snapshot().rng_state is String, "RNG state uses lossless string")
	var calls_before := _commit_calls
	check(session.open_offer().offer == opened.offer and _commit_calls == calls_before, "reopening pending offer neither rerolls nor saves")
	var locale_before := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	check(session.open_offer().offer == opened.offer, "locale change cannot reroll offer")
	TranslationServer.set_locale(locale_before)
	before = session.snapshot()
	check(not session.choose(opened.offer.id, "not_a_candidate").ok, "forged candidate rejected")
	check(not session.choose("forged_offer", opened.offer.candidates[0]).ok, "forged offer rejected")
	check(session.snapshot() == before, "invalid requests leave authoritative state unchanged")
	var selected: String = opened.offer.candidates[0]
	var previous_program: Dictionary = session.program()
	_commit_failure = true
	var failed: Dictionary = session.choose(opened.offer.id, selected)
	check(not failed.ok and failed.error == "commit_failed", "selection failure reported")
	check(session.snapshot() == before and session.program() == previous_program, "failed selection preserves state and compiled program")
	_commit_failure = false
	_mutate_commit = true
	_reentry_session = session
	var accepted: Dictionary = session.choose(opened.offer.id, selected)
	_mutate_commit = false
	_reentry_session = null
	check(accepted.ok, "valid selection accepted once")
	check(_reentry_error == "commit_in_progress", "adapter reentry cannot interleave another transaction")
	check(session.snapshot().ranks[selected] == 1, "adapter mutation cannot alter committed rank")
	check(session.snapshot().offer.resolved and session.snapshot().history.size() == 1, "offer resolved and history committed atomically")
	_committed_copy.clear()
	check(session.snapshot().history.size() == 1, "adapter retained reference cannot mutate state later")
	var after: Dictionary = session.snapshot()
	check(not session.choose(opened.offer.id, selected).ok, "repeat selection rejected")
	check(session.snapshot() == after, "repeat selection does not stack rank")
	var next: Dictionary = session.open_offer()
	check(next.ok and next.offer.id != opened.offer.id, "next offer has new identity")
	check(not session.choose(opened.offer.id, selected).ok, "old offer rejected after next offer opens")
	check(session.snapshot().is_read_only() and session.snapshot().ranks.is_read_only(), "published state recursively readonly")
	check(session.program().is_read_only() and session.program().effects.is_read_only(), "published program recursively readonly")


func _test_exhaustion() -> void:
	var session := Session.new()
	session.configure(_catalog, 418, _commit)
	var total_ranks := 0
	for entry in _catalog.entries():
		total_ranks += int(entry.max_rank)
	for pick in total_ranks:
		var result: Dictionary = session.open_offer()
		if not result.ok or result.offer.candidates.is_empty():
			check(false, "can progress until all ranks capped: pick %s" % pick)
			return
		var chosen: String = result.offer.candidates[0]
		if result.offer.candidates.has("wave"):
			chosen = "wave"
		elif result.offer.candidates.has("split"):
			chosen = "split"
		check(session.choose(result.offer.id, chosen).ok, "progression commits legal upgrade")
	var empty: Dictionary = session.open_offer()
	check(empty.ok and empty.offer.candidates.is_empty() and empty.offer.resolved, "exhausted pool resolves without trapping player")
	check(session.snapshot().history.size() == total_ranks, "history contains exactly one record per accepted selection")
	for entry in _catalog.entries():
		check(session.snapshot().ranks[entry.id] == int(entry.max_rank), "all ranks stop at authored caps")


func _commit(candidate: Dictionary) -> Error:
	_commit_calls += 1
	_committed_copy = candidate
	if _reentry_session != null:
		_reentry_error = _reentry_session.open_offer().error
	if _mutate_commit:
		candidate.ranks.clear()
		candidate.history.clear()
		candidate.offer.clear()
		candidate.rng_state = "0"
	return ERR_CANT_CREATE if _commit_failure else OK


func _entry(data: Dictionary, id: String) -> Dictionary:
	for entry in data.upgrades:
		if entry.id == id:
			return entry
	assert(false, "Missing fixture entry " + id)
	return {}


func _rejected(data: Variant, description: String) -> void:
	var loader := Loader.new()
	check(loader.decode(data) == null and not loader.errors.is_empty(), description)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func configure_sampler(sampler, catalog) -> void:
	var resolver := Resolver.new()
	resolver.configure(catalog)
	sampler.configure(catalog, func(entry, ranks): return Capabilities.eligible(entry, Capabilities.summarize(catalog, resolver.resolve(ranks), [])))
