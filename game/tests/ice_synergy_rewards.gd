extends "res://tests/forest_run_flow.gd"
## Actual locked reward tokens, then actual training UI and adventure scene reconstruction.
const BuildLoader = preload("res://content/builds/build_loader.gd")
const RewardLoader = preload("res://content/builds/reward_groups_loader.gd")
const Session = preload("res://app/session/training_build_session.gd")
const FOUR := {"shatter_followup": "skill", "opening_strike": "primary", "frost_path": "skill", "ice_coat": "skill"}
var catalog
var rewards: Dictionary
var run_config: Dictionary
var winning: Dictionary = {}

func _offer_filter() -> Dictionary:
	var filter: Dictionary = run_config.card_weighting.duplicate(true)
	filter.mode = "card"
	return filter

func _path(seed_value: int) -> Dictionary:
	var session := Session.new()
	session.configure(catalog, seed_value, func(_s): return OK, rewards)
	var awakening: Dictionary = run_config.awakening.duplicate(true)
	awakening.mode = "awakening"
	var result := session.open_offer(run_config.battle_profile, awakening)
	var starters: Array = result.offer.candidates.filter(func(c): return c.upgrade_id == "ice_core" and c.action_id == "skill")
	if starters.is_empty(): return {}
	check(session.choose(result.offer.id, starters[0].choice_id).ok, "ice awakening is an offered choice")
	var route: Array = [{"profile": "awakening", "pick": starters[0].choice_id, "upgrade": "ice_core"}]
	var wanted: Array = FOUR.keys() + ["pierce"]
	for index in 12:
		var profile: String = run_config.elite_profile if index % 3 == 2 else run_config.battle_profile
		result = session.open_offer(profile, _offer_filter())
		var offered: Array = result.offer.candidates
		if offered.is_empty(): return {}
		var chosen: Dictionary = {}
		for candidate in offered:
			check(candidate.operation == "add" and catalog.upgrade(candidate.upgrade_id).effect_type != "element", "ordinary rewards respect awakening separation")
			if wanted.has(candidate.upgrade_id): chosen = candidate; break
		if chosen.is_empty():
			var safe: Array = offered.filter(func(c): return c.upgrade_id != "split")
			if safe.is_empty(): return {}
			chosen = safe[0]
		check(session.choose(result.offer.id, chosen.choice_id).ok, "locked candidate commits normally")
		wanted.erase(chosen.upgrade_id)
		route.append({"profile": profile, "pick": chosen.choice_id, "upgrade": chosen.upgrade_id})
		if wanted.is_empty(): return {"seed": seed_value, "route": route, "selections": session.snapshot().selections}
	return {}

func run() -> void:
	catalog = BuildLoader.new().load_catalog()
	if not check(catalog != null, "catalog loads"): return _done()
	rewards = RewardLoader.new().load_groups(catalog)
	run_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/run/forest_run.json"))
	# Fixed reward-stream seed; never reroll or forcibly submit a missing card.
	winning = _path(13)
	if not check(not winning.is_empty(), "actual adventure rewards provide all four plus pierce"): return _done()
	check(_path(int(winning.seed)) == winning, "reward seed and choices reproduce exactly")
	var sample := Session.new()
	sample.configure(catalog, 91, func(_s): return OK, rewards)
	for index in 12:
		var result := sample.open_offer(run_config.elite_profile, _offer_filter())
		check(result.offer.candidates.all(func(c): return not FOUR.has(c.upgrade_id)), "no ice or freeze provider means no synergy candidates")
		if not result.offer.candidates.is_empty(): sample.choose(result.offer.id, result.offer.candidates[0].choice_id)
	var sampler = sample._sampler
	for id in FOUR:
		check(sampler.upgrade_elements(catalog.upgrade(id)).has("ice"), "ice affinity identified: " + id)
		check(is_equal_approx(sampler._relevance(id, [], {"skill": "ice"}, _offer_filter()), run_config.card_weighting.owned_element_scale), "ice relevance applied: " + id)
	print("ICE_REWARD_ROUTE ", JSON.stringify(winning))
	await _training_and_transfer()
	print("ICE_SYNERGY_REWARDS ", JSON.stringify({"failures": failures}))
	_done()

func _training_and_transfer() -> void:
	var arena = load("res://app/combat_training.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena); current_scene = arena
	for i in 10: await physics_frame
	arena.player.set_damage_immunity(true)
	arena.training_tools.set_menu_visible("build", true)
	var menu = arena.builds.status_panel._grant_menu
	check(menu != null and menu.is_visible_in_tree(), "training has visible single-card menu after showing Build UI")
	check(not arena.builds.grant_training_upgrade("shatter_followup", "skill").ok, "training cannot grant missing prerequisite")
	check(arena.builds.grant_training_upgrade("ice_core", "skill").ok, "training grants only the ice starting core")
	for id in FOUR:
		var options: Array = arena.builds.status_panel._grant_options
		var index := -1
		for i in options.size():
			if options[i].upgrade_id == id: index = i; break
		if not check(index >= 0, "UI lists legal card: " + id): continue
		menu.get_popup().id_pressed.emit(index)
		check(arena.builds.session.snapshot().selections.any(func(s): return s.upgrade_id == id), "UI grants one card preserving previous choices: " + id)
	check(arena.builds.session.snapshot().selections.size() == 5, "training grants accumulated four plus ice")
	arena.paused = true
	var clock_before: float = arena.builds.runtime.statuses.diagnostics().clock
	for i in 10: await physics_frame
	check(arena.builds.runtime.statuses.diagnostics().clock == clock_before, "actual arena pause holds status clock")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var output := ProjectSettings.globalize_path("res://../builds/ice_synergy_20261016/training.png")
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		root.get_texture().get_image().save_png(output)
	arena.queue_free(); await process_frame
	# Carry the normally acquired cards into a real adventure scene and through another room.
	var scene = load("res://app/forest_run.tscn").instantiate()
	scene.initial_run_state = {"seed": 20261016, "area": 0, "node": "", "visited": [], "room": "rest", "hp": 100.0,
		"selections": winning.selections, "gold": 100, "awakenings": 1}
	root.add_child(scene); current_scene = scene
	for i in 20: await physics_frame
	arena = scene
	check(arena.builds.status_panel._grant_menu == null, "adventure does not expose direct grants")
	check(not arena.builds.grant_training_upgrade("power", "global").ok, "adventure also rejects direct grant commands")
	check(arena.builds.session.snapshot().selections == winning.selections, "adventure restores normally acquired cards")
	arena.forest_run._on_panel_pick(0)
	for i in 6: await physics_frame
	arena.forest_run._on_panel_pick(0)
	if not check(await _await_new_scene(arena), "actual next-room transition"): return
	arena = _arena()
	check(arena.builds.session.snapshot().selections == winning.selections, "all cards retained after transition")
	check(arena.builds.runtime.frost.paths.is_empty() and arena.player.protection_amount == 0, "new room starts without old path/shield")
