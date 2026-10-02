extends RefCounted
## Training-only transaction coordinator. The adapter owns persistence policy.
## Candidate state, adapter input, and published state share no mutable values.

const Capabilities = preload("res://combat/builds/projectile_capabilities.gd")
const Catalog = preload("res://content/builds/build_catalog.gd")
const Sampler = preload("res://rogue/build_offer_sampler.gd")
const Resolver = preload("res://combat/builds/build_resolver.gd")

var _attack_ids: Array = []
var _has_melee := false
var _catalog: Catalog
var _sampler := Sampler.new()
var _resolver := Resolver.new()
var _commit: Callable
var _state: Dictionary = {}
var _program: Dictionary = {}
var _committing := false


func configure(catalog: Catalog, seed: int, commit: Callable, attack_ids: Array = [], has_melee: bool = false) -> void:
	assert(catalog != null and commit.is_valid(), "Build session requires a catalog and explicit commit adapter")
	_catalog = catalog
	_commit = commit
	_attack_ids = Catalog.freeze_copy(attack_ids)
	_has_melee = has_melee
	_sampler.configure(catalog, _compatible)
	_resolver.configure(catalog)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_state = {
		"ranks": {}, "history": [], "offer": {},
		"offer_sequence": 0, "rng_state": str(rng.state),
	}
	_program = Catalog.freeze_copy(_resolver.resolve(_state.ranks))
	_committing = false


func capability_summary() -> Array:
	return Capabilities.summarize(_catalog, _program, _attack_ids, _has_melee)

func _compatible(entry: Dictionary, ranks: Dictionary) -> bool:
	var current: Dictionary = _resolver.resolve(ranks)
	if current.is_empty() or not Capabilities.eligible(entry, Capabilities.summarize(_catalog, current, _attack_ids, _has_melee)): return false
	var next: Dictionary = ranks.duplicate(true)
	next[entry.id] = int(next.get(entry.id, 0)) + 1
	return not _resolver.resolve(next).is_empty()

func open_offer() -> Dictionary:
	if _committing:
		return _result(false, "commit_in_progress")
	if not _state.offer.is_empty() and not _state.offer.resolved:
		return _result(true, "")
	var candidate: Dictionary = _state.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.state = int(candidate.rng_state)
	var ids: Array[String] = _sampler.sample(candidate.ranks, _program.tags, rng)
	candidate.offer_sequence += 1
	candidate.rng_state = str(rng.state)
	candidate.offer = {
		"id": "training_build_%s" % candidate.offer_sequence,
		"candidates": ids,
		"resolved": ids.is_empty(),
	}
	if not _submit(candidate, _program):
		return _result(false, "commit_failed")
	return _result(true, "")


func choose(offer_id: String, upgrade_id: String) -> Dictionary:
	if _committing:
		return _result(false, "commit_in_progress")
	var offer: Dictionary = _state.offer
	if offer.is_empty() or offer.id != offer_id:
		return _result(false, "stale_offer")
	if offer.resolved:
		return _result(false, "offer_resolved")
	if not offer.candidates.has(upgrade_id):
		return _result(false, "invalid_candidate")
	if not _sampler.is_eligible(upgrade_id, _state.ranks, _program.tags):
		return _result(false, "ineligible_upgrade")
	var candidate: Dictionary = _state.duplicate(true)
	var current_rank: int = int(candidate.ranks[upgrade_id]) if candidate.ranks.has(upgrade_id) else 0
	candidate.ranks[upgrade_id] = current_rank + 1
	candidate.offer.resolved = true
	candidate.history.append({
		"offer_id": offer_id, "upgrade_id": upgrade_id, "rank": current_rank + 1,
	})
	var candidate_program: Dictionary = _resolver.resolve(candidate.ranks)
	if candidate_program.is_empty(): return _result(false, "invalid_program")
	if not _submit(candidate, candidate_program):
		return _result(false, "commit_failed")
	return _result(true, "")

func apply_test_preset(id: String) -> Dictionary:
	# Training convenience uses the exact same eligibility/compiler path. Only
	# the fully validated detached candidate reaches the commit adapter once.
	if _committing: return _result(false, "commit_in_progress")
	var preset: Dictionary = _catalog.test_preset(id)
	if preset.is_empty(): return _result(false, "unknown_preset")
	var candidate: Dictionary = _state.duplicate(true)
	candidate.ranks = {}
	candidate.history = []
	candidate.offer = {}
	var candidate_program: Dictionary = _resolver.resolve(candidate.ranks)
	for upgrade_id in preset.upgrade_ids:
		if not _sampler.is_eligible(upgrade_id, candidate.ranks, candidate_program.tags): return _result(false, "ineligible_upgrade")
		var rank := int(candidate.ranks.get(upgrade_id, 0)) + 1
		candidate.ranks[upgrade_id] = rank
		candidate_program = _resolver.resolve(candidate.ranks)
		if candidate_program.is_empty(): return _result(false, "invalid_program")
		candidate.history.append({"preset_id": id, "upgrade_id": upgrade_id, "rank": rank})
	if not _submit(candidate, candidate_program): return _result(false, "commit_failed")
	return _result(true, "")


func snapshot() -> Dictionary:
	return Catalog.freeze_copy(_state)


func program() -> Dictionary:
	return _program


func _submit(candidate: Dictionary, candidate_program: Dictionary) -> bool:
	if not Capabilities.valid_program(candidate_program, _catalog): return false
	_committing = true
	var result: Variant = _commit.call(candidate.duplicate(true))
	_committing = false
	if not result is int or result != OK:
		return false
	_state = candidate
	_program = Catalog.freeze_copy(candidate_program)
	return true


func _result(ok: bool, error: String) -> Dictionary:
	return Catalog.freeze_copy({"ok": ok, "error": error, "offer": _state.offer})
