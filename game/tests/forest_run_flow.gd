extends SceneTree
## 一局冒险（原型）流程：开局选祝福 → 第 1 间 → 清场领奖三选一 → 选出口 → 第 2 间（构筑、生命、金币带过去）；
## 另验证倒下后的结算和“再来一局”。图形模式运行：
## godot --path game --resolution 1280x800 --script res://tests/forest_run_flow.gd
var failures: Array = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> bool:
	if not ok: failures.append(label)
	return ok

func _arena():
	return current_scene

## 等场景切换完成（SceneTransition 在后台加载后替换 current_scene）
func _await_new_scene(old) -> bool:
	for i in 900:
		await process_frame
		var scene = current_scene
		if scene != null and scene != old and is_instance_valid(scene) and scene.is_node_ready() and scene.get("forest_run") != null:
			for j in 10: await physics_frame
			return true
	return false

func _panel_buttons(arena, prefix: String) -> Array:
	var panel = arena.forest_run.panel
	return panel.find_children(prefix + "*", "Button", true, false)

func _clear_room(arena) -> void:
	for i in 1200:
		await physics_frame
		if arena.state == "victory": return
		for actor in arena.actors:
			if actor != arena.player and actor.health.alive(): actor.receive_hit(actor.health.current + 1.0)

func run() -> void:
	var packed = load("res://app/forest_run.tscn")
	if packed == null: return _done()
	var scene = packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 30: await physics_frame
	var arena = _arena()
	if not check(arena.get("forest_run") != null and arena.forest_run.is_lobby(), "new run starts in the lobby"): return _done()
	var exits := _panel_buttons(arena, "RunExit_")
	check(exits.size() == int(arena.forest_run.run.first_exit_count), "lobby offers the first blessings (%d)" % exits.size())
	check(arena.actors.filter(func(a): return a.health.alive()).size() == 1, "no enemies fight in the lobby (%s)" % [arena.actors.map(func(a): return a.definition.id)])
	if exits.is_empty(): return _done()
	var chosen_element: String = arena.forest_run._options[0].element
	exits[0].pressed.emit()
	if not check(await _await_new_scene(arena), "choosing a blessing enters room 1"): return _done()
	arena = _arena()
	var run_state: Dictionary = arena.forest_run.state
	check(int(run_state.room_index) == 0 and run_state.pending_reward.kind == "boon" and run_state.pending_reward.element == chosen_element, "room 1 carries the chosen blessing")
	await _clear_room(arena)
	check(arena.state == "victory", "room 1 can be cleared")
	for i in 10: await physics_frame
	check(arena.builds.is_choosing(), "clearing opens the blessing offer")
	var offer: Dictionary = arena.builds.session.snapshot().offer
	var element_ok := true
	for candidate in offer.get("candidates", []):
		var elements: Array = arena.builds.session._sampler.upgrade_elements(arena.builds.catalog.upgrade(candidate.upgrade_id))
		if not elements.has(chosen_element): element_ok = false
	check(element_ok and not offer.get("candidates", []).is_empty(), "blessing offer only holds cards of the chosen element")
	if offer.get("candidates", []).is_empty(): return _done()
	var first_choice: String = offer.candidates[0].choice_id
	arena.builds._choose(offer.id, first_choice)
	for i in 10: await physics_frame
	var selections: Array = arena.builds.session.snapshot().selections
	check(selections.size() >= 1, "the chosen card is in the build")
	exits = _panel_buttons(arena, "RunExit_")
	check(exits.size() >= int(arena.forest_run.run.exit_count_min), "exits appear after the reward")
	if exits.is_empty(): return _done()
	arena.player.health.current = arena.player.health.maximum - 17.0
	var hp_before: float = arena.player.health.current
	var gold_before: int = int(arena.forest_run.state.gold)
	exits[0].pressed.emit()
	if not check(await _await_new_scene(arena), "an exit enters room 2"): return _done()
	arena = _arena()
	check(int(arena.forest_run.state.room_index) == 1, "room 2 index")
	check(arena.builds.session.snapshot().selections == selections, "build carries into room 2")
	check(is_equal_approx(arena.player.health.current, hp_before), "health carries into room 2")
	check(int(arena.forest_run.state.gold) == gold_before, "gold carries into room 2")
	check(arena.encounter_plan.waves.size() >= 1 and not arena.encounter_plan.has("run_boss"), "room 2 is an ordinary encounter")
	# 倒下：结算 + 再来一局
	arena.player.set_damage_immunity(false)
	arena.player.receive_hit(arena.player.health.current + 1.0)
	for i in 10: await physics_frame
	var result := _panel_buttons(arena, "RunResult_")
	check(result.size() == 2, "defeat shows the run result")
	var new_run: Button = null
	for button in result: if button.name == "RunResult_new_run": new_run = button
	if check(new_run != null, "new run button exists"):
		new_run.pressed.emit()
		if check(await _await_new_scene(arena), "new run reloads"):
			check(_arena().forest_run.is_lobby() and _arena().builds.session.snapshot().selections.is_empty(), "new run starts clean")
	_done()

func _done() -> void:
	print("FOREST_RUN_FLOW ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
