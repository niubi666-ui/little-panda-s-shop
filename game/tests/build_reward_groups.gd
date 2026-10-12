extends SceneTree
const Loader = preload("res://content/builds/build_loader.gd")
const Rewards = preload("res://content/builds/reward_groups_loader.gd")
const Session = preload("res://app/session/training_build_session.gd")
var failures: Array[String] = []
var fail_commit := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func run() -> void:
	var catalog = Loader.new().load_catalog()
	var loader := Rewards.new()
	var groups := loader.load_groups(catalog)
	check(not groups.is_empty(), "reward groups load: " + str(loader.errors))
	if groups.is_empty(): quit(1); return
	for profile in groups.reward_profiles:
		for seed_value in 12:
			var session := Session.new()
			session.configure(catalog, seed_value, func(_candidate): return ERR_CANT_CREATE if fail_commit else OK, groups)
			var before := session.snapshot()
			fail_commit = true
			check(not session.open_offer(profile).ok and session.snapshot() == before, "failed offer preserves RNG/state")
			fail_commit = false
			var offer: Dictionary = session.open_offer(profile).offer
			check(offer.profile_id == profile, "profile locked")
			for card in offer.candidates:
				check(groups.reward_profiles[profile].rarity_weights.has(card.rarity_id), "rarity never escapes profile")
				check(groups.upgrade_groups[card.upgrade_id] == card.rarity_id, "single rarity authority")
			if not offer.resolved:
				check(session.open_offer("boss_room").offer == offer, "opening another source cannot reroll unresolved offer")
				check(session.choose(offer.id, offer.candidates[0].choice_id).ok, "rarity metadata does not bypass/reject normal evaluator")
			if profile == "boss_room": check(offer.resolved and offer.candidates.is_empty(), "unavailable legendary has no common fallback")
	var invalid := groups.duplicate(true)
	invalid.upgrade_groups.erase(invalid.upgrade_groups.keys()[0])
	check(loader.decode_groups(invalid, catalog).is_empty(), "missing assignment rejected")
	print("BUILD_REWARD_GROUPS ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
