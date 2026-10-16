extends Node
## 一局冒险（原型）：把战斗训练场当作“一个房间”。
## - 共 areas 个区域，每区一张杀戮尖塔式地图（与 M 键地图同一个生成器，规则在 forest_run.json 的 map）；
##   出口就是地图上当前节点能走到的下一层节点，显示房型和奖励；走完最后一层进区域 Boss。
## - 房型决定奖励：战斗/精英清场后构筑三选一，宝箱给强化（稀有时元素觉醒），事件随机，休息回血或强化，商店用金币买。
## - 元素只从“元素觉醒”获得：开局一次，awakening_after_area 那一区的 Boss 后一次，宝箱/事件稀有；只出空按键，从不替换。
## - 换房间就是重新载入战斗场景，生命、构筑、金币通过 initial_run_state 带过去（只在内存里，没有存档）。
## 配置：data/run/forest_run.json；界面样式：presentation/run/run_exit_style.tres。
const Loader = preload("res://content/run/forest_run_loader.gd")
const EncounterPlanner = preload("res://rogue/encounters/encounter_planner.gd")
const MapGenerator = preload("res://rogue/run/map_preview_generator.gd")
const ExitPanel = preload("res://presentation/run/run_exit_panel.gd")
const PanelStyle = preload("res://presentation/run/run_exit_style.tres")
const SceneTransition = preload("res://app/scene_transition.gd")
const COMBAT_ROOMS := ["battle", "elite", "boss"]

var arena
var run: Dictionary
## {seed, area, node（当前地图节点；"" 为区域入口，"boss" 为区域 Boss）, visited, room（当前房间类型；"start" 为开局）,
##  hp, selections, gold, awakenings}
var state: Dictionary
## 当前区域的地图（MapGenerator 的 plan）
var map: Dictionary
var panel: ExitPanel
var _phase := "room"      # room（非战斗房间或开局）/ fighting / reward / exits / over
var _options: Array = []
var _on_pick: Callable    # 当前面板选项被点击后的处理
var _offer_then: Callable # 当前这次三选一结束后继续做什么
var _shop_bought: Dictionary = {}

func configure(owner_arena, initial_state: Dictionary) -> bool:
	arena = owner_arena
	var loader := Loader.new()
	run = loader.load_run(arena.builds.catalog, arena.builds.reward_groups, arena.enemy_catalog)
	if run.is_empty():
		for error in loader.errors: push_error(error)
		return false
	panel = ExitPanel.new()
	panel.name = "RunPanel"
	arena.get_node("UIRoot").add_child(panel)
	panel.configure(PanelStyle, arena.shared_theme)
	panel.exit_chosen.connect(_on_panel_pick)
	panel.new_run_requested.connect(new_run)
	panel.shop_requested.connect(func(): arena._return())
	arena.builds.offer_finished.connect(_on_offer_finished)
	if initial_state.is_empty():
		state = {"seed": randi(), "area": 0, "node": "", "visited": [], "room": "start", "hp": arena.player.health.maximum,
			"selections": [], "gold": 0, "awakenings": 0}
		var preset: Dictionary = arena.builds.catalog.test_preset(run.start_preset)
		if not arena.builds.restore_selections(preset.selections): return false
	else:
		state = initial_state.duplicate(true)
		if not arena.builds.restore_selections(state.selections):
			push_error("forest run: carried build could not be restored")
			return false
		arena.player.health.current = clampf(float(state.hp), 1.0, arena.player.health.maximum)
	if not _load_map(): return false
	if state.room in COMBAT_ROOMS:
		_phase = "fighting"
	else:
		_phase = "room"
		_enter_room.call_deferred()
	_refresh()
	return true

## 不是战斗房间（开局、宝箱、事件、休息、商店）：不开打
func is_lobby() -> bool: return not (state.room in COMBAT_ROOMS)
func is_boss_room() -> bool: return state.room == "boss"

# ---------------- 地图 ----------------
func _area() -> Dictionary: return run.areas[int(state.area)]

func _load_map() -> bool:
	var result: Dictionary = MapGenerator.new().generate(run.map, "%s:area:%s" % [state.seed, state.area])
	if not result.ok:
		push_error("forest run: map generation failed for area %s" % state.area)
		return false
	map = result.plan
	return true

func _node(id: String) -> Dictionary:
	for node in map.nodes:
		if node.id == id: return node
	return {}

## 当前位置能走到的下一批节点（按列排序）；走完最后一层为空（下一步是 Boss）
func _next_nodes() -> Array:
	var result: Array = []
	if state.node == "boss": return result
	for node in map.nodes:
		if state.node == "" and int(node.layer) == 0: result.append(node)
	for edge in map.edges:
		if edge.from == state.node: result.append(_node(edge.to))
	result.sort_custom(func(a, b): return int(a.column) < int(b.column))
	return result

func _publish_map() -> void:
	var preview = arena.get_node_or_null("MapPreview")
	if preview == null or not preview.has_method("show_run"): return
	preview.show_run(map, {"current": state.node, "visited": state.visited,
		"reachable": _next_nodes().map(func(node): return node.id) if _phase == "exits" else [],
		"title": tr("run.map.area_title").format({"area": tr(_area().name_key), "index": int(state.area) + 1, "total": run.areas.size()})})

func _refresh() -> void:
	var layer := tr("run.info.entrance")
	if state.node == "boss": layer = tr("run.info.boss_layer")
	elif state.node != "": layer = tr("run.info.layer").format({"index": int(_node(state.node).layer) + 1, "rows": int(map.rows)})
	panel.set_info(tr("run.info.bar").format({"area": tr(_area().name_key), "layer": layer,
		"room": tr("run.room." + String(state.room)), "gold": int(state.gold), "awakenings": int(state.awakenings)}))
	_publish_map()

# ---------------- 房间 ----------------
## 刚进入一个不打架的房间（或开局）
func _enter_room() -> void:
	match String(state.room):
		"start": _awakening(_show_exits)
		"treasure": _treasure()
		"rest": _rest()
		"event": _event()
		"shop": _shop()
		_: _show_exits()

func room_cleared() -> void:
	if _phase != "fighting": return
	state.gold = int(state.gold) + int(run.clear_gold[state.room])
	_phase = "reward"
	_refresh()
	match String(state.room):
		"battle": _card_offer(run.battle_profile, _after_room)
		"elite": _card_offer(run.elite_profile, _after_room)
		"boss":
			if int(state.area) >= run.areas.size() - 1:
				_phase = "over"
				panel.show_result(tr("run.victory.title"), tr("run.victory.body").format({"areas": run.areas.size(), "gold": int(state.gold)}))
			elif int(state.area) == int(run.awakening_after_area): _awakening(_next_area)
			else: _card_offer(run.boss_profile, _next_area)

func defeated() -> void:
	if _phase == "over": return
	_phase = "over"
	panel.show_result(tr("run.defeat.title"), tr("run.defeat.body").format({"area": int(state.area) + 1, "gold": int(state.gold)}))

func _after_room() -> void:
	if _phase == "over": return
	_show_exits()

func _next_area() -> void:
	state.area = int(state.area) + 1
	state.node = ""
	state.visited = []
	if not _load_map(): return
	_show_exits()

func _rng(channel: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%s|%s" % [state.seed, state.area, state.node, channel])
	return rng

# ---------------- 奖励 ----------------
func _card_offer(profile: String, then: Callable) -> void:
	_offer(profile, {"mode": "card", "owned_element_scale": run.card_weighting.owned_element_scale,
		"elemental_action_scale": run.card_weighting.elemental_action_scale, "max_per_action": run.card_weighting.max_per_action}, then)

func _upgrade_offer(then: Callable) -> void:
	_offer(run.upgrade_profile, {"operation": "rank"}, then)

func _can_upgrade() -> bool:
	return arena.builds.session.legal_operations().any(func(option): return option.operation == "rank")

## 还有没带元素、能觉醒的按键
func _can_awaken() -> bool:
	return arena.builds.session.legal_operations().any(func(option):
		return option.operation == "add" and arena.builds.catalog.upgrade(option.upgrade_id).effect_type == "element")

func _awakening(then: Callable) -> void:
	if not _can_awaken():
		then.call()
		return
	_offer(run.battle_profile, {"mode": "awakening", "count": run.awakening.count,
		"guarantee_same": run.awakening.guarantee_same, "guarantee_new": run.awakening.guarantee_new}, func(chosen: bool):
			if chosen: state.awakenings = int(state.awakenings) + 1
			then.call())

func _offer(profile: String, filter: Dictionary, then: Callable) -> void:
	_phase = "reward"
	panel.close()
	_offer_then = then
	arena.builds.request_filtered_offer(profile, filter)

func _on_offer_finished(chosen: bool) -> void:
	var next := _offer_then
	_offer_then = Callable()
	_refresh()
	if not next.is_valid(): return
	# 觉醒的回调要知道是否真的选了；其他回调不带参数
	if next.get_argument_count() == 1: next.call(chosen)
	else: next.call()

func _heal(amount: int) -> void:
	arena.player.health.current = minf(arena.player.health.maximum, arena.player.health.current + float(amount))

func _treasure() -> void:
	var rng := _rng("treasure")
	if _can_awaken() and rng.randf() < float(run.treasure.awakening_chance):
		_menu(tr("run.treasure.title"), [_choice("awakening", tr("run.treasure.awakening"), tr("run.treasure.awakening_detail"))], _grant)
	elif _can_upgrade():
		_menu(tr("run.treasure.title"), [_choice("upgrade", tr("run.reward.upgrade"), tr("run.reward.upgrade_detail"))], _grant)
	else:
		_menu(tr("run.treasure.title"), [_choice("gold", tr("run.reward.gold").format({"amount": int(run.treasure.gold)}), tr("run.reward.gold_detail"))], _grant)

func _rest() -> void:
	var options := [_choice("heal", tr("run.reward.heal").format({"amount": int(run.rest_heal)}), tr("run.reward.heal_detail"))]
	if _can_upgrade(): options.append(_choice("upgrade", tr("run.reward.upgrade"), tr("run.reward.upgrade_detail")))
	_menu(tr("run.rest.title"), options, _grant)

func _event() -> void:
	var rng := _rng("event")
	var outcomes: Array = run.event.outcomes.filter(func(o): return o.kind != "awakening" or _can_awaken())
	var total := 0.0
	for outcome in outcomes: total += float(outcome.weight)
	var roll := rng.randf() * total
	var kind: String = outcomes.back().kind
	for outcome in outcomes:
		roll -= float(outcome.weight)
		if roll < 0.0:
			kind = outcome.kind
			break
	var values := {"gold": int(run.event.gold), "heal": int(run.event.heal), "cost": int(run.event.blood_cost)}
	_menu(tr("run.event.title"), [_choice(kind, tr("run.event.%s" % kind).format(values), tr("run.event.%s_detail" % kind).format(values)),
		_choice("leave", tr("run.button.leave"), tr("run.event.leave_detail"))], _grant)

## 宝箱、休息、事件里选中的一项：按 kind 发放，结束后回到出口
func _grant(index: int) -> void:
	match String(_options[index].kind):
		"awakening": _awakening(_after_room)
		"upgrade": _upgrade_offer(_after_room)
		"card": _card_offer(run.event.card_profile, _after_room)
		"blood_card":
			arena.player.health.current = maxf(1.0, arena.player.health.current - float(run.event.blood_cost))
			_card_offer(run.event.blood_card_profile, _after_room)
		"gold":
			state.gold = int(state.gold) + (int(run.treasure.gold) if state.room == "treasure" else int(run.event.gold))
			_after_room()
		"heal":
			_heal(int(run.rest_heal) if state.room == "rest" else int(run.event.heal))
			_after_room()
		_: _after_room()

func _shop_prices() -> Dictionary:
	return {"card": int(run.shop.card_price), "upgrade": int(run.shop.upgrade_price), "heal": int(run.shop.heal_price)}

func _shop() -> void:
	var prices := _shop_prices()
	var options: Array = []
	for kind in ["card", "upgrade", "heal"]:
		if _shop_bought.has(kind) or (kind == "upgrade" and not _can_upgrade()): continue
		var values := {"price": prices[kind], "amount": int(run.shop.heal_amount)}
		var option := _choice(kind, tr("run.shop.%s" % kind).format(values), tr("run.shop.%s_detail" % kind).format(values))
		option.disabled = int(state.gold) < int(prices[kind])
		options.append(option)
	options.append(_choice("leave", tr("run.button.leave"), tr("run.shop.leave_detail")))
	_menu(tr("run.shop.title").format({"gold": int(state.gold)}), options, _buy)

## 商店：买一样东西后回到商店（每样只能买一次），离开则回到出口
func _buy(index: int) -> void:
	var kind: String = _options[index].kind
	if kind == "leave":
		_shop_bought.clear()
		_after_room()
		return
	var price: int = _shop_prices()[kind]
	if int(state.gold) < price: return
	state.gold = int(state.gold) - price
	_shop_bought[kind] = true
	match kind:
		"card": _card_offer(run.shop.card_profile, _shop)
		"upgrade": _upgrade_offer(_shop)
		"heal":
			_heal(int(run.shop.heal_amount))
			_shop()

# ---------------- 面板 ----------------
func _choice(kind: String, title: String, detail: String) -> Dictionary:
	return {"kind": kind, "title": title, "detail": detail}

func _menu(title: String, options: Array, on_pick: Callable) -> void:
	_phase = "room"
	_options = options
	_on_pick = on_pick
	_refresh()
	panel.show_exits(title, options)

func _on_panel_pick(index: int) -> void:
	if index < 0 or index >= _options.size() or bool(_options[index].get("disabled", false)): return
	if not (_phase in ["room", "exits"]) or not _on_pick.is_valid(): return
	var handler := _on_pick
	_on_pick = Callable()
	panel.close()
	handler.call(index)

## 出口：地图上能去的下一批节点；最后一层之后是区域 Boss
func _show_exits() -> void:
	_phase = "exits"
	var nodes := _next_nodes()
	var options: Array = []
	if nodes.is_empty():
		options.append({"kind": "boss", "node": "boss", "title": tr("run.room.boss"),
			"detail": tr("run.exit.boss_detail_awakening" if int(state.area) == int(run.awakening_after_area) else ("run.exit.boss_detail_final" if int(state.area) == run.areas.size() - 1 else "run.exit.boss_detail"))})
	for node in nodes:
		var title := tr("run.room." + String(node.kind))
		if nodes.size() > 1: title += tr("run.exit.side." + _side(int(node.column)))
		options.append({"kind": node.kind, "node": node.id, "title": title, "detail": tr("run.exit.%s_detail" % node.kind)})
	_options = options
	_on_pick = _go
	_refresh()
	var title_key := "run.exit.area_start" if state.node == "" else "run.exit.title"
	panel.show_exits(tr(title_key).format({"area": tr(_area().name_key)}), options)

## 节点在地图上的左右位置（出口标题里提示，方便和 M 地图对照）
func _side(column: int) -> String:
	var middle := (int(map.columns) - 1) / 2.0
	if is_equal_approx(float(column), middle): return "middle"
	return "left" if float(column) < middle else "right"

func _go(index: int) -> void:
	var chosen: Dictionary = _options[index]
	var next := state.duplicate(true)
	next.node = chosen.node
	next.room = chosen.kind
	if chosen.node != "boss": next.visited.append(chosen.node)
	next.hp = arena.player.health.current
	next.selections = arena.builds.session.snapshot().selections
	var plan: Dictionary = {}
	var depth := 0
	if chosen.kind in COMBAT_ROOMS:
		var area := _area()
		var capacity: int = arena._enemy_spawns.size()
		var seed_text := "%s:area:%s:%s" % [state.seed, state.area, chosen.node]
		var planner := EncounterPlanner.new()
		if chosen.kind == "boss":
			depth = int(area.boss_depth)
			plan = planner.generate_run_boss(seed_text, depth, capacity, arena.enemy_catalog, area.boss_actor_id)
		else:
			depth = int(area.start_depth) + int(_node(chosen.node).layer) * int(area.depth_per_layer)
			if chosen.kind == "elite": depth += int(area.elite_depth_bonus)
			plan = planner.generate(seed_text, depth, capacity, arena.enemy_catalog)
		if plan.is_empty():
			push_error("forest run: no legal encounter for %s" % chosen.node)
			return
	_phase = "over"
	panel.close()
	_enter(next, plan, depth)

func new_run() -> void:
	panel.close()
	_enter({}, {}, 0)

func _enter(next_state: Dictionary, plan: Dictionary, depth: int) -> void:
	if arena._leaving or is_instance_valid(arena._transition): return
	arena.skill_vfx.clear()
	var keep_room = arena.room_presentation
	arena._transition = SceneTransition.begin(get_tree(), arena.scene_file_path, arena.shared_theme, func(next_scene):
		next_scene.room_presentation = keep_room
		next_scene.initial_run_state = next_state
		next_scene.initial_encounter_plan = plan
		if depth > 0: next_scene.encounter_depth = depth)
