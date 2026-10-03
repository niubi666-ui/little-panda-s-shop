extends SceneTree
## Bound operation sampling, revision tokens and isolated training transactions.
const Loader = preload("res://content/builds/build_loader.gd")
const Catalog = preload("res://content/builds/build_catalog.gd")
const Resolver = preload("res://combat/builds/build_resolver.gd")
const Sampler = preload("res://rogue/build_offer_sampler.gd")
const Session = preload("res://app/session/training_build_session.gd")
var failures: Array[String] = []
var catalog
var fail_commit := false
var mutate_commit := false
var calls := 0
var reentry
var reentry_error := ""
var retained: Dictionary = {}

func _initialize() -> void: call_deferred("run")
func check(condition: bool, label: String) -> void:
	if not condition: failures.append(label)
func finish() -> void:
	print("BOUND_BUILD_SESSION ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	var loader := Loader.new()
	catalog = loader.load_catalog()
	check(catalog != null, "current catalog loads: " + str(loader.errors))
	if catalog == null:
		finish()
		return
	check_sampling()
	check_transactions()
	check_binding_replacement()
	check_presets()
	finish()

func make_session(seed_value: int = 731) -> Session:
	var session := Session.new()
	session.configure(catalog, seed_value, commit)
	return session

func commit(value: Dictionary) -> Error:
	calls += 1
	retained = value
	if reentry != null: reentry_error = reentry.open_offer().error
	if mutate_commit:
		value.selections.clear()
		value.history.clear()
		value.offer.clear()
		value.rng_state = "0"
		value.revision = -1
	return ERR_CANT_CREATE if fail_commit else OK

func pick(session: Session, upgrade_id: String, action_id: String) -> Dictionary:
	for operation in session.legal_operations(upgrade_id):
		if operation.action_id == action_id: return operation.duplicate(true)
	return {}

func acquire(session: Session, upgrade_id: String, action_id: String) -> Dictionary:
	var operation := pick(session, upgrade_id, action_id)
	check(not operation.is_empty(), "legal operation exists: " + action_id + "/" + upgrade_id)
	return session.submit_operation(operation) if not operation.is_empty() else {"ok": false}

func rank_for(session: Session, upgrade_id: String, action_id: String) -> int:
	for selection in session.snapshot().selections:
		if selection.upgrade_id == upgrade_id and selection.action_id == action_id: return int(selection.rank)
	return 0

func check_sampling() -> void:
	var resolver := Resolver.new()
	resolver.configure(catalog)
	var sampler := Sampler.new()
	sampler.configure(catalog, resolver.legal_operations)
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 717
	b.seed = 717
	var state := {"selections": [], "revision": 0}
	for count in 60:
		var first := sampler.sample(state, a)
		check(first == sampler.sample(state, b), "deterministic bound offer %s" % count)
		var ids: Dictionary = {}
		for operation in first:
			check(not ids.has(operation.upgrade_id), "one upgrade cannot occupy two cards")
			ids[operation.upgrade_id] = true
			check(resolver.evaluate(state, operation).ok, "every sampled operation passes same evaluator")
			check(operation.upgrade_id not in ["pierce", "split", "frost_blast"], "no carrier or source means no support/synergy")
	# Give one ID one binding and the other two. Both retain equal ID weight.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/builds/prototype.json"))
	data.offer.pool_ids = ["power", "impact_blast"]
	data.offer.fallback_ids = []
	data.offer.count = 1
	for entry in data.upgrades:
		if entry.id in data.offer.pool_ids: entry.weight = 1.0
	var weighted_catalog := Catalog.new(data)
	var weighted_resolver := Resolver.new()
	weighted_resolver.configure(weighted_catalog)
	sampler.configure(weighted_catalog, weighted_resolver.legal_operations)
	var counts := {"power": 0, "impact_blast": 0}
	for trial in 1200:
		var sample := sampler.sample(state, a)
		check(sample.size() == 1, "weighted fixture has a legal candidate")
		if sample.size() == 1: counts[sample[0].upgrade_id] += 1
	check(int(counts.power) > 480 and int(counts.power) < 720, "two action bindings do not double a card's weight: " + str(counts))

func check_transactions() -> void:
	var session := make_session()
	var twin := make_session()
	var before := session.snapshot()
	fail_commit = true
	check(not session.open_offer().ok, "failed offer commit is reported")
	check(session.snapshot() == before, "failed offer keeps state/RNG/revision")
	fail_commit = false
	var opened := session.open_offer()
	check(opened.ok and opened.offer == twin.open_offer().offer, "retry draws same locked bound choices")
	var before_calls := calls
	check(session.open_offer().offer == opened.offer and calls == before_calls, "pending offer cannot reroll")
	var old_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	check(session.open_offer().offer == opened.offer, "locale does not reroll binding")
	TranslationServer.set_locale(old_locale)
	var selected: Dictionary = opened.offer.candidates[0]
	before = session.snapshot()
	check(not session.choose(opened.offer.id, selected.upgrade_id).ok, "UI cannot select by global upgrade ID")
	check(not session.choose("fake", selected.choice_id).ok, "forged offer rejected")
	check(not session.choose(opened.offer.id, "fake").ok, "forged choice rejected")
	check(session.snapshot() == before, "forged tokens do not alter RNG or state")
	var old_program := session.program()
	fail_commit = true
	check(not session.choose(opened.offer.id, selected.choice_id).ok, "selection save failure reported")
	check(session.snapshot() == before and session.program() == old_program, "failed choice preserves program and offer")
	fail_commit = false
	mutate_commit = true
	reentry = session
	check(session.choose(opened.offer.id, selected.choice_id).ok, "locked operation commits once")
	reentry = null
	mutate_commit = false
	check(reentry_error == "commit_in_progress", "adapter reentry cannot interleave transaction")
	check(rank_for(session, selected.upgrade_id, selected.action_id) == int(selected.rank), "adapter cannot mutate authoritative bound selection")
	check(session.snapshot().revision == before.revision + 1, "successful choice increments build revision")
	retained.clear()
	check(session.snapshot().history.size() == 1, "adapter retained reference isolated")
	before = session.snapshot()
	check(not session.choose(opened.offer.id, selected.choice_id).ok and session.snapshot() == before, "duplicate token cannot stack rank")
	check(not session.submit_operation(selected).ok and session.snapshot() == before, "old base_revision rejected")
	check(session.snapshot().selections.is_read_only() and session.program().actions.is_read_only(), "published state and program immutable")

func check_binding_replacement() -> void:
	var session := make_session()
	check(acquire(session, "action_power", "primary").ok, "primary damage support installs")
	check(acquire(session, "action_power", "primary").ok, "primary damage support ranks independently")
	check(acquire(session, "action_power", "special").ok, "special damage support starts at own rank")
	check(rank_for(session, "action_power", "primary") == 2 and rank_for(session, "action_power", "special") == 1, "same upgrade keeps independent ranks")
	check(acquire(session, "contact_freeze", "primary").ok, "primary freeze installs")
	check(acquire(session, "contact_freeze", "special").ok, "same core independently installs special")
	check(rank_for(session, "contact_freeze", "primary") == 1 and rank_for(session, "contact_freeze", "special") == 1, "same ID retains action identity")
	var replace := pick(session, "impact_blast", "primary")
	check(not replace.is_empty() and replace.operation == "replace" and replace.replaced.upgrade_id == "contact_freeze", "core replacement locks old identity and rank")
	check(session.submit_operation(replace).ok, "unrequired core replacement succeeds")
	check(rank_for(session, "contact_freeze", "primary") == 0 and rank_for(session, "contact_freeze", "special") == 1, "replacement affects only target action")
	check(acquire(session, "frost_blast", "primary").ok, "primary explosion synergy installs")
	var blocked := {"upgrade_id": "contact_freeze", "action_id": "primary", "operation": "replace", "rank": 1,
		"replaced": {"upgrade_id": "impact_blast", "action_id": "primary", "rank": 1}, "base_revision": session.snapshot().revision}
	var before := session.snapshot()
	var rejection := session.submit_operation(blocked)
	check(not rejection.ok and not rejection.error_key.is_empty(), "dependent core replacement rejected with localized reason")
	check(session.snapshot() == before, "rejected replacement cannot remove/refund dependent synergy")
	check(pick(session, "contact_freeze", "primary").is_empty(), "sampler and submit agree on blocked replacement")
	check(pick(session, "pierce", "special").is_empty(), "debug arrow cannot grant real special carrier")
	check(acquire(session, "sword_wave_form", "special").ok, "special wave form grants real carrier")
	check(acquire(session, "pierce", "special").ok, "special carrier enables pierce")
	check(pick(session, "split", "special").is_empty(), "same action pierce rejects split")
	check(pick(session, "sword_heavy_form", "special").is_empty(), "removing carrier with dependent pierce not offered")
	var form_session := make_session()
	check(acquire(form_session, "sword_wave_form", "special").ok, "standalone wave form installs")
	var restore := pick(form_session, "sword_heavy_form", "special")
	check(not restore.is_empty() and restore.operation == "replace", "dependency-free form restore offered")
	check(form_session.submit_operation(restore).ok and form_session.program().actions.special.form_id == "sword_heavy", "form restores through same transaction")

func check_presets() -> void:
	var session := make_session()
	var opened := session.open_offer()
	var before := session.snapshot()
	var program := session.program()
	fail_commit = true
	check(not session.apply_test_preset("left_blast_right_freeze").ok, "preset failure reported")
	check(session.snapshot() == before and session.program() == program, "failed preset preserves pending offer/ranks/RNG/program")
	fail_commit = false
	for preset in catalog.test_presets():
		var rng_before: String = session.snapshot().rng_state
		var calls_before := calls
		check(session.apply_test_preset(preset.id).ok, "authored preset valid: " + preset.id)
		check(calls == calls_before + 1, "preset publishes only once: " + preset.id)
		check(session.snapshot().rng_state == rng_before, "preset does not draw RNG: " + preset.id)
		check(session.snapshot().offer.is_empty(), "preset invalidates previous pending offer")
	check(not session.choose(opened.offer.id, opened.offer.candidates[0].choice_id).ok, "pre-preset token cannot survive reset")
	before = session.snapshot()
	check(not session.apply_test_preset("missing").ok and session.snapshot() == before, "unknown preset leaves all state intact")
	check(session.apply_test_preset("basic_actions").ok and session.snapshot().selections.is_empty(), "basic preset compiles empty build")
