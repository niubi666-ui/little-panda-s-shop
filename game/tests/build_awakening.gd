extends SceneTree
## 构筑规则（2026-10-16）：元素觉醒只出空按键、从不替换；第二次觉醒保证同元素与新元素；平时三选一不含元素核心；
## 同元素专精只在两个按键同元素时出现；“冰左键＋冰右键”和“火左键＋土 R”两条路都能从空构筑一路拿到。
## godot --headless --path game --script res://tests/build_awakening.gd
const Loader = preload("res://content/builds/build_loader.gd")
const RewardLoader = preload("res://content/builds/reward_groups_loader.gd")
const Session = preload("res://app/session/training_build_session.gd")
var failures: Array = []
var catalog
var rewards: Dictionary

func _initialize() -> void:
	catalog = Loader.new().load_catalog()
	rewards = RewardLoader.new().load_groups(catalog)
	if not check(catalog != null and not rewards.is_empty(), "content loads"): return _done()
	for seed in 12:
		_path(seed, "ice", "primary", "ice", "skill")
		_path(seed, "fire", "primary", "earth", "special")
	_done()

func check(ok: bool, label: String) -> bool:
	if not ok and not failures.has(label): failures.append(label)
	return ok

func _awakening_filter(guarantee: bool) -> Dictionary:
	return {"mode": "awakening", "count": 3, "guarantee_same": guarantee, "guarantee_new": guarantee}

func _card_filter() -> Dictionary:
	return {"mode": "card", "owned_element_scale": 3.0, "elemental_action_scale": 2.0, "max_per_action": 2}

func _element(upgrade_id: String) -> String:
	var entry: Dictionary = catalog.upgrade(upgrade_id)
	return entry.ranks[0].element_id if entry.effect_type == "element" else ""

## 一局：开局觉醒（强制选 first），打几间拿卡，Boss 后第二次觉醒（强制选 second），再拿几张卡
func _path(seed: int, first: String, first_action: String, second: String, second_action: String) -> void:
	var label := "%s %s + %s %s (seed %d)" % [first, first_action, second, second_action, seed]
	var session := Session.new()
	session.configure(catalog, seed, func(_candidate): return OK, rewards)
	if not _force_awakening(session, first, first_action, false, label + " first"): return
	for room in 4: _take_card(session, "normal_room", label)
	if not _force_awakening(session, second, second_action, true, label + " second"): return
	var mastery := "%s_mastery_burst" % first
	var legal_mastery := session.legal_operations(mastery).size() > 0
	check(legal_mastery == (first == second), "%s: mastery legal only with two same elements" % label)
	if first != second:
		var reaction: Dictionary = catalog.reaction_between(first, second)
		check(session.legal_operations("dual_" + String(reaction.id)).size() > 0, "%s: dual reaction card becomes legal" % label)
	for room in 8: _take_card(session, "normal_room", label)
	_take_card(session, "elite_room", label)
	var elements: Dictionary = session._sampler.action_elements(session.snapshot())
	check(elements.get(first_action, "") == first and elements.get(second_action, "") == second, "%s: both elements kept to the end %s" % [label, elements])

func _force_awakening(session, element: String, action: String, guarantee: bool, label: String) -> bool:
	# 抽到的三个选项必须合规；为了走完指定路线，不在选项里时直接提交同一个合法操作（等价于玩家下次觉醒时选它）
	var owned: Array = session._sampler.action_elements(session.snapshot()).values()
	var result: Dictionary = session.open_offer("normal_room", _awakening_filter(guarantee))
	var offer: Dictionary = result.offer
	check(offer.candidates.size() == 3, label + ": awakening shows three options")
	for candidate in offer.candidates:
		check(catalog.upgrade(candidate.upgrade_id).effect_type == "element" and candidate.operation == "add" and candidate.replaced.is_empty(), label + ": awakening never replaces")
	var shown: Array = offer.candidates.map(func(c): return _element(c.upgrade_id))
	if guarantee:
		check(shown.any(func(e): return owned.has(e)), label + ": second awakening offers an owned element")
		check(shown.any(func(e): return not owned.has(e)), label + ": second awakening offers a new element")
	for candidate in offer.candidates:
		if _element(candidate.upgrade_id) == element and candidate.action_id == action:
			return check(session.choose(offer.id, candidate.choice_id).ok, label + ": choose awakening")
	var options: Array = session.legal_operations(element + "_core").filter(func(o): return o.action_id == action and o.operation == "add")
	if not check(options.size() == 1, label + ": %s on %s is legal" % [element, action]): return false
	# submit_operation 会同时结束这次未选的三选一
	return check(session.submit_operation(options[0]).ok, label + ": submit awakening")

func _take_card(session, profile: String, label: String) -> void:
	var result: Dictionary = session.open_offer(profile, _card_filter())
	if not check(result.ok, label + ": card offer opens"): return
	var offer: Dictionary = result.offer
	if offer.candidates.is_empty(): return
	var per_action: Dictionary = {}
	for candidate in offer.candidates:
		var entry: Dictionary = catalog.upgrade(candidate.upgrade_id)
		check(entry.effect_type != "element", label + ": card offer has no element cores")
		check(candidate.operation == "add" and candidate.replaced.is_empty(), label + ": card offer never replaces or upgrades")
		check(float(entry.weight) > 0.0, label + ": retired cards never appear")
		if candidate.action_id != "global": per_action[candidate.action_id] = int(per_action.get(candidate.action_id, 0)) + 1
	check(per_action.values().all(func(n): return n <= 2), label + ": at most two cards per action")
	check(session.choose(offer.id, offer.candidates[0].choice_id).ok, label + ": choose card")

func _done() -> void:
	print("BUILD_AWAKENING ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
