extends SceneTree
## 一局冒险（原型）流程：开局元素觉醒 → 出口 = 地图第一层 → 战斗房清场选卡（不含元素核心）→ 出口 = 地图上的后继节点；
## 第一区 Boss 后第二次觉醒（保证同元素与新元素、不替换）→ 进入第二区；宝箱、休息、事件、商店的面板；倒下后的结算与再来一局。
## 图形模式运行：godot --path game --resolution 1280x800 --script res://tests/forest_run_flow.gd
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
	return arena.forest_run.panel.find_children(prefix + "*", "Button", true, false)

func _clear_room(arena) -> void:
	for i in 1200:
		await physics_frame
		if arena.state == "victory": return
		for actor in arena.actors:
			if actor != arena.player and actor.health.alive(): actor.receive_hit(actor.health.current + 1.0)

func _offer(arena) -> Dictionary:
	return arena.builds.session.snapshot().offer

func _choose(arena, index: int) -> void:
	var offer := _offer(arena)
	arena.builds._choose(offer.id, offer.candidates[index].choice_id)
	for i in 6: await physics_frame

func _elements(arena) -> Dictionary:
	return arena.builds.session._sampler.action_elements(arena.builds.session.snapshot())

func _all_add_elements(arena, offer: Dictionary) -> bool:
	return not offer.candidates.is_empty() and offer.candidates.all(func(c):
		return arena.builds.catalog.upgrade(c.upgrade_id).effect_type == "element" and c.operation == "add" and c.replaced.is_empty())

func run() -> void:
	var packed = load("res://app/forest_run.tscn")
	if packed == null: return _done()
	var scene = packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 30: await physics_frame
	var arena = _arena()
	var run_ctl = arena.forest_run
	if not check(run_ctl != null and run_ctl.is_lobby(), "new run starts in the lobby"): return _done()
	check(arena.actors.filter(func(a): return a.health.alive()).size() == 1, "no enemies fight in the lobby")
	# 1. 开局元素觉醒：三个不同元素、都是空按键上的新增
	var offer := _offer(arena)
	check(arena.builds.is_choosing() and offer.candidates.size() == int(run_ctl.run.awakening.count), "lobby opens the first awakening")
	check(_all_add_elements(arena, offer), "awakening only offers new elements on empty actions")
	var shown: Array = offer.candidates.map(func(c): return arena.builds.catalog.upgrade(c.upgrade_id).ranks[0].element_id)
	var unique: Dictionary = {}
	for element in shown: unique[element] = true
	check(unique.size() == shown.size(), "first awakening shows different elements %s" % [shown])
	await _choose(arena, 0)
	var owned := _elements(arena)
	check(owned.size() == 1 and int(run_ctl.state.awakenings) == 1, "awakening adds one element")
	# 2. 出口 = 地图第一层
	var first_layer: Array = run_ctl.map.nodes.filter(func(n): return int(n.layer) == 0)
	var exits := _panel_buttons(arena, "RunExit_")
	check(exits.size() == first_layer.size(), "exits match the map's first layer (%d vs %d)" % [exits.size(), first_layer.size()])
	check(run_ctl._options.all(func(o): return first_layer.any(func(n): return n.id == o.node and n.kind == o.kind)), "exit kinds match map nodes")
	var preview = arena.get_node("MapPreview")
	check(preview._run_plan == run_ctl.map, "M map shows this run's route")
	if exits.is_empty(): return _done()
	var target: String = run_ctl._options[0].node
	exits[0].pressed.emit()
	if not check(await _await_new_scene(arena), "an exit enters the first room"): return _done()
	arena = _arena()
	run_ctl = arena.forest_run
	check(run_ctl.state.node == target and run_ctl.state.room == "battle" and run_ctl.state.visited == [target], "room 1 is the chosen map node")
	check(arena.get_node("MapPreview")._run_progress.current == target, "map marks the current room")
	check(_elements(arena) == owned, "element carries into room 1")
	# 3. 清场：构筑卡三选一，不含元素核心，不出升级/替换，同一按键最多两张
	await _clear_room(arena)
	for i in 10: await physics_frame
	offer = _offer(arena)
	check(arena.builds.is_choosing() and not offer.candidates.is_empty(), "battle clear opens a card offer")
	var per_action: Dictionary = {}
	for c in offer.candidates:
		if c.action_id != "global": per_action[c.action_id] = int(per_action.get(c.action_id, 0)) + 1
	check(offer.candidates.all(func(c): return arena.builds.catalog.upgrade(c.upgrade_id).effect_type != "element" and c.operation == "add"), "card offer has no element cores or upgrades")
	check(per_action.values().all(func(n): return n <= int(run_ctl.run.card_weighting.max_per_action)), "at most two cards per action")
	await _choose(arena, 0)
	var successors: Array = run_ctl.map.edges.filter(func(e): return e.from == target).map(func(e): return e.to)
	exits = _panel_buttons(arena, "RunExit_")
	check(exits.size() == successors.size() and run_ctl._options.all(func(o): return successors.has(o.node)), "exits are the map successors")
	# 4. 第一区 Boss 后：第二次觉醒，保证至少一个同元素、一个新元素，不替换
	run_ctl.state.room = "boss"
	run_ctl.state.node = "boss"
	run_ctl._phase = "fighting"
	run_ctl.room_cleared()
	for i in 6: await physics_frame
	offer = _offer(arena)
	check(arena.builds.is_choosing() and _all_add_elements(arena, offer), "first boss grants the second awakening")
	var owned_ids: Array = _elements(arena).values()
	var elements: Array = offer.candidates.map(func(c): return arena.builds.catalog.upgrade(c.upgrade_id).ranks[0].element_id)
	check(elements.any(func(e): return owned_ids.has(e)) and elements.any(func(e): return not owned_ids.has(e)), "second awakening offers same and new elements %s vs %s" % [elements, owned_ids])
	check(offer.candidates.all(func(c): return not _elements(arena).has(c.action_id)), "second awakening never targets an elemental action")
	await _choose(arena, 0)
	check(_elements(arena).size() == 2 and int(run_ctl.state.area) == 1 and run_ctl.state.node == "", "second awakening leads into area 2")
	exits = _panel_buttons(arena, "RunExit_")
	check(exits.size() == run_ctl.map.nodes.filter(func(n): return int(n.layer) == 0).size(), "area 2 starts at its first map layer")
	# 5. 不打架的房间：宝箱 / 休息 / 事件 / 商店都给出面板，并且能回到出口
	for room in ["treasure", "rest", "event", "shop"]:
		run_ctl.state.room = room
		run_ctl.state.gold = 200
		run_ctl._enter_room()
		var buttons := _panel_buttons(arena, "RunExit_")
		check(not buttons.is_empty(), "%s shows choices" % room)
		if buttons.is_empty(): continue
		var leave_index: int = run_ctl._options.size() - 1 if room in ["event", "shop"] else 0
		buttons[leave_index].pressed.emit()
		for i in 6: await physics_frame
		if arena.builds.is_choosing(): await _choose(arena, 0)
		check(run_ctl._phase == "exits", "%s returns to the exits (phase %s)" % [room, run_ctl._phase])
	# 6. 倒下：结算 + 再来一局
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
			check(_arena().forest_run.is_lobby() and _elements(_arena()).is_empty(), "new run starts clean")
	_done()

func _done() -> void:
	print("FOREST_RUN_FLOW ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
