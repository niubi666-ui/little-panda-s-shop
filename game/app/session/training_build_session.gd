extends RefCounted
## Detached candidates and RNG reach a commit adapter only after pure validation.
const Catalog = preload("res://content/builds/build_catalog.gd")
const Sampler = preload("res://rogue/build_offer_sampler.gd")
const Resolver = preload("res://combat/builds/build_resolver.gd")

var _catalog: Catalog
var _sampler := Sampler.new()
var _resolver := Resolver.new()
var _commit: Callable
var _state: Dictionary = {}
var _program: Dictionary = {}
var _committing := false

func configure(catalog: Catalog, seed: int, commit: Callable) -> void:
	assert(catalog != null and commit.is_valid())
	_catalog = catalog
	_commit = commit
	_resolver.configure(catalog)
	_sampler.configure(catalog, _resolver.legal_operations)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_state = {"selections": [], "revision": 0, "history": [], "offer": {},
		"offer_sequence": 0, "rng_state": str(rng.state)}
	_program = Catalog.freeze_copy(_resolver.resolve(_build_state(_state)))
	assert(not _program.is_empty(), "Validated initial action loadout must compile")
	_committing = false

func open_offer() -> Dictionary:
	if _committing: return _result(false, "commit_in_progress")
	if not _state.offer.is_empty() and not _state.offer.resolved: return _result(true, "")
	var candidate: Dictionary = _state.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.state = int(candidate.rng_state)
	var operations: Array[Dictionary] = _sampler.sample(_build_state(candidate), rng)
	candidate.offer_sequence += 1
	var offer_id := "training_build_%s" % candidate.offer_sequence
	for index in operations.size():
		operations[index]["choice_id"] = "%s_choice_%s" % [offer_id, index]
	candidate.rng_state = str(rng.state)
	candidate.offer = {"id": offer_id, "candidates": operations,
		"resolved": operations.is_empty(), "base_revision": candidate.revision}
	if not _submit(candidate, _program): return _result(false, "commit_failed")
	return _result(true, "")

func choose(offer_id: String, choice_id: String) -> Dictionary:
	if _committing: return _result(false, "commit_in_progress")
	var offer: Dictionary = _state.offer
	if offer.is_empty() or offer.id != offer_id: return _result(false, "stale_offer", "build.reason.stale")
	if offer.resolved: return _result(false, "offer_resolved", "build.reason.stale")
	var operation: Dictionary = {}
	for locked in offer.candidates:
		if locked.choice_id == choice_id:
			operation = locked
			break
	if operation.is_empty(): return _result(false, "invalid_candidate", "build.reason.invalid_operation")
	var evaluated: Dictionary = _resolver.evaluate(_build_state(_state), operation)
	if not evaluated.ok: return _result(false, "ineligible_upgrade", evaluated.error_key)
	var candidate := _apply_evaluation(_state, evaluated)
	candidate.offer.resolved = true
	candidate.history.append({"offer_id": offer_id, "choice_id": choice_id,
		"operation": operation.duplicate(true), "change": evaluated.change})
	if not _submit(candidate, evaluated.program): return _result(false, "commit_failed")
	return _result(true, "")

func legal_operations(upgrade_id: String = "") -> Array:
	return Catalog.freeze_copy(_resolver.legal_operations(_build_state(_state), upgrade_id))

func submit_operation(operation: Dictionary) -> Dictionary:
	# Explicit training/test command; no alternate ranks path. The UI sends only
	# choose(offer_id, choice_id). This command uses exactly the same evaluator.
	if _committing: return _result(false, "commit_in_progress")
	var evaluated: Dictionary = _resolver.evaluate(_build_state(_state), operation)
	if not evaluated.ok: return _result(false, "ineligible_upgrade", evaluated.error_key)
	var candidate := _apply_evaluation(_state, evaluated)
	candidate.offer = {}
	candidate.history.append({"operation": operation.duplicate(true), "change": evaluated.change})
	if not _submit(candidate, evaluated.program): return _result(false, "commit_failed")
	return _result(true, "")

func apply_test_preset(id: String) -> Dictionary:
	if _committing: return _result(false, "commit_in_progress")
	var preset: Dictionary = _catalog.test_preset(id)
	if preset.is_empty(): return _result(false, "unknown_preset", "build.reason.invalid_operation")
	var candidate: Dictionary = _state.duplicate(true)
	candidate.selections = []
	candidate.revision += 1
	candidate.history = []
	candidate.offer = {}
	var candidate_program: Dictionary = _resolver.resolve(_build_state(candidate))
	for selection in preset.selections:
		for target_rank in range(1, int(selection.rank) + 1):
			var operation: Dictionary = {}
			for option in _resolver.legal_operations(_build_state(candidate), selection.upgrade_id):
				if option.action_id == selection.action_id and int(option.rank) == target_rank:
					operation = option
					break
			if operation.is_empty(): return _result(false, "ineligible_preset", "build.reason.dependency")
			var evaluated: Dictionary = _resolver.evaluate(_build_state(candidate), operation)
			if not evaluated.ok: return _result(false, "ineligible_preset", evaluated.error_key)
			candidate = _apply_evaluation(candidate, evaluated)
			candidate_program = evaluated.program
			candidate.history.append({"preset_id": id, "operation": operation,
				"change": evaluated.change})
	if not _submit(candidate, candidate_program): return _result(false, "commit_failed")
	return _result(true, "")

func snapshot() -> Dictionary: return Catalog.freeze_copy(_state)
func program() -> Dictionary: return _program

func _build_state(state: Dictionary) -> Dictionary:
	return {"selections": state.selections.duplicate(true), "revision": state.revision}

func _apply_evaluation(base: Dictionary, evaluated: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	result.selections = evaluated.state.selections.duplicate(true)
	result.revision = evaluated.state.revision
	return result

func _submit(candidate: Dictionary, candidate_program: Dictionary) -> bool:
	var checked: Dictionary = _resolver.resolve(_build_state(candidate))
	if checked.is_empty() or checked != candidate_program: return false
	_committing = true
	var result: Variant = _commit.call(candidate.duplicate(true))
	_committing = false
	if not result is int or result != OK: return false
	_state = candidate
	_program = Catalog.freeze_copy(checked)
	return true

func _result(ok: bool, error: String, error_key: String = "build.error") -> Dictionary:
	return Catalog.freeze_copy({"ok": ok, "error": error,
		"error_key": "" if ok else error_key, "offer": _state.offer})
