extends Node
## 一局冒险（原型）：把战斗训练场当作“一个房间”，串成 普通房 × N → Boss 房。
## - 每间进门前在出口里选定清场奖励（元素祝福、强化、回血、金币）；清场后发放，再选下一间的出口。
## - 换房间就是重新载入战斗场景，生命、构筑、金币通过 initial_run_state 带过去（只在内存里，没有存档）。
## - 规则（构筑评估、遭遇规划）都走已有的 Session / Planner；本节点只负责流程和界面。
## 配置：data/run/forest_run.json；界面样式：presentation/run/run_exit_style.tres。
const Loader = preload("res://content/run/forest_run_loader.gd")
const EncounterPlanner = preload("res://rogue/encounters/encounter_planner.gd")
const ExitPanel = preload("res://presentation/run/run_exit_panel.gd")
const PanelStyle = preload("res://presentation/run/run_exit_style.tres")
const SceneTransition = preload("res://app/scene_transition.gd")

var arena
var run: Dictionary
## {seed, room_index (-1 为开局选祝福), hp, selections, gold, pending_reward}
var state: Dictionary
var panel: ExitPanel
var _options: Array = []
var _phase := "lobby"     # lobby / fighting / reward / exits / over

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
	panel.exit_chosen.connect(_on_exit_chosen)
	panel.new_run_requested.connect(new_run)
	panel.shop_requested.connect(func(): arena._return())
	arena.builds.offer_finished.connect(func(_chosen): _after_reward())
	if initial_state.is_empty():
		state = {"seed": randi(), "room_index": -1, "hp": arena.player.health.maximum, "selections": [],
			"gold": 0, "pending_reward": {}}
		var preset: Dictionary = arena.builds.catalog.test_preset(run.start_preset)
		if not arena.builds.restore_selections(preset.selections): return false
		_show_first_exits()
		return true
	state = initial_state.duplicate(true)
	if not arena.builds.restore_selections(state.selections):
		push_error("forest run: carried build could not be restored")
		return false
	arena.player.health.current = clampf(float(state.hp), 1.0, arena.player.health.maximum)
	_phase = "fighting"
	_refresh_info()
	return true

## 开局还没进第一间：不开始战斗
func is_lobby() -> bool: return _phase == "lobby"
func is_boss_room() -> bool: return int(state.room_index) >= int(run.room_count)

func _refresh_info() -> void:
	var total := int(run.room_count) + 1
	if _phase == "lobby":
		panel.set_info(tr("run.info.lobby"))
	elif is_boss_room():
		panel.set_info(tr("run.info.boss").format({"index": int(state.room_index) + 1, "total": total, "gold": int(state.gold)}))
	else:
		panel.set_info(tr("run.info.room").format({"index": int(state.room_index) + 1, "total": total,
			"reward": _reward_title(state.pending_reward), "gold": int(state.gold)}))

# ---------------- 清场与奖励 ----------------
func room_cleared() -> void:
	if _phase != "fighting": return
	state.gold = int(state.gold) + int(run.clear_gold)
	if is_boss_room():
		state.gold = int(state.gold) + int(run.victory_gold)
		_phase = "over"
		panel.show_result(tr("run.victory.title"), tr("run.victory.body").format({"rooms": int(state.room_index) + 1, "gold": int(state.gold)}))
		return
	_phase = "reward"
	var reward: Dictionary = state.pending_reward
	match String(reward.get("kind", "")):
		"boon":
			arena.builds.request_filtered_offer(run.boon_profile, {"element": reward.element, "per_binding": true})
			return
		"upgrade":
			arena.builds.request_filtered_offer(run.upgrade_profile, {"operation": "rank"})
			return
		"heal":
			arena.player.health.current = minf(arena.player.health.maximum, arena.player.health.current + float(run.heal_amount))
		"gold":
			state.gold = int(state.gold) + int(run.gold_amount)
	_after_reward()

func _after_reward() -> void:
	if _phase != "reward": return
	_phase = "exits"
	_refresh_info()
	_show_exits()

func defeated() -> void:
	if _phase == "over": return
	_phase = "over"
	panel.show_result(tr("run.defeat.title"), tr("run.defeat.body").format({"rooms": maxi(int(state.room_index), 0), "gold": int(state.gold)}))

# ---------------- 出口 ----------------
func _rng(channel: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%s" % [state.seed, state.room_index, channel])
	return rng

func _show_first_exits() -> void:
	_phase = "lobby"
	var rng := _rng("first")
	var elements: Array = run.boon_elements.duplicate()
	_shuffle(elements, rng)
	_options = []
	for index in mini(int(run.first_exit_count), elements.size()):
		_options.append({"kind": "boon", "element": elements[index]})
	_refresh_info()
	panel.show_exits(tr("run.exit.first"), _decorate(_options))

func _show_exits() -> void:
	var next_index := int(state.room_index) + 1
	if next_index >= int(run.room_count):
		_options = [{"kind": "boss"}]
		panel.show_exits(tr("run.exit.title"), _decorate(_options))
		return
	var rng := _rng("exits")
	var count := rng.randi_range(int(run.exit_count_min), int(run.exit_count_max))
	var weights: Array = []
	for reward in run.rewards:
		if reward.kind == "upgrade" and not _can_upgrade(): continue
		weights.append(reward)
	var elements: Array = run.boon_elements.duplicate()
	_shuffle(elements, rng)
	_options = []
	var guard := 0
	while _options.size() < count and guard < 32:
		guard += 1
		var kind := _weighted_kind(weights, rng)
		var option := {"kind": kind}
		if kind == "boon":
			if elements.is_empty(): continue
			option.element = elements.pop_back()
		elif _options.any(func(existing): return existing.kind == kind): continue
		_options.append(option)
	panel.show_exits(tr("run.exit.title"), _decorate(_options))

func _can_upgrade() -> bool:
	return arena.builds.session.legal_operations().any(func(option): return option.operation == "rank")

func _weighted_kind(weights: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for reward in weights: total += float(reward.weight)
	var roll := rng.randf() * total
	for reward in weights:
		roll -= float(reward.weight)
		if roll < 0.0: return reward.kind
	return weights.back().kind

func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for index in range(items.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held = items[index]
		items[index] = items[other]
		items[other] = held

func _decorate(options: Array) -> Array:
	return options.map(func(option):
		var shown: Dictionary = option.duplicate()
		shown.title = _reward_title(option)
		shown.detail = _reward_detail(option)
		return shown)

func _reward_title(option: Dictionary) -> String:
	match String(option.get("kind", "")):
		"boon": return tr("run.reward.boon").format({"element": tr(arena.builds.catalog.element(option.element).name_key)})
		"upgrade": return tr("run.reward.upgrade")
		"heal": return tr("run.reward.heal").format({"amount": int(run.heal_amount)})
		"gold": return tr("run.reward.gold").format({"amount": int(run.gold_amount)})
		"boss": return tr("run.reward.boss")
	return tr("run.reward.none")

func _reward_detail(option: Dictionary) -> String:
	return tr("run.reward.%s_detail" % String(option.kind))

func _on_exit_chosen(index: int) -> void:
	if index < 0 or index >= _options.size() or not (_phase in ["lobby", "exits"]): return
	var chosen: Dictionary = _options[index]
	var next := state.duplicate(true)
	next.room_index = int(state.room_index) + 1
	next.hp = arena.player.health.current
	next.selections = arena.builds.session.snapshot().selections
	next.pending_reward = {} if chosen.kind == "boss" else chosen
	var capacity: int = arena._enemy_spawns.size()
	var seed_text := "%s:room:%s" % [state.seed, next.room_index]
	var planner := EncounterPlanner.new()
	var plan: Dictionary
	var depth: int
	if int(next.room_index) >= int(run.room_count):
		depth = int(run.boss_depth)
		plan = planner.generate_run_boss(seed_text, depth, capacity, arena.enemy_catalog, run.boss_actor_id)
	else:
		depth = int(run.start_depth) + int(next.room_index) * int(run.depth_per_room)
		plan = planner.generate(seed_text, depth, capacity, arena.enemy_catalog)
	if plan.is_empty():
		push_error("forest run: no legal encounter for room %s" % next.room_index)
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
