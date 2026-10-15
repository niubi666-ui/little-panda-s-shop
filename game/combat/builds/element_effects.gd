extends RefCounted
## 元素状态与反应（原型）。由 BuildRuntime 持有并驱动，数值全部来自 data/builds/elements.json。
##
## - 动作的执行计划里带一个 `element` 效果（核心层，每个动作只能有一个元素），该动作的直接命中就带这个元素。
## - 命中时：目标身上若已有另一种元素 → 触发两者的反应，消耗旧状态，不再挂新元素；
##   否则挂上 / 叠加本元素状态。感电在被任意直接命中时放电（雷元素再次命中会放电后重新挂上）。
## - 元素造成的伤害（灼烧、放电、反应、熔岩）不再触发元素，也不进入构筑的派生链，避免互相喂触发。
const Damage = preload("res://combat/effects/damage_executor.gd")

## handle → {target: WeakRef, elements: {id: {stacks, remaining, tick_left}}, vulnerable: float, vulnerable_left: float}
var _states: Dictionary = {}
var _zones: Array[Dictionary] = []
var _next_zone := 0

## 元素数值 = elements.json 的基础值 + 元素强化卡（element_boost）的累加
static func param(runtime, id: String, field: String) -> float:
	var value := float(runtime._catalog.element(id)[field])
	var boosts: Dictionary = runtime._program.get("global", {}).get("element_boosts", {})
	if boosts.has(id) and boosts[id].has(field): value += float(boosts[id][field])
	return value

static func max_stacks(runtime, id: String) -> int:
	return maxi(1, int(round(param(runtime, id, "max_stacks"))))

func element_of(program: Dictionary) -> Dictionary:
	for effect in program.effects:
		if effect.type == "element": return effect.params
	return {}

## 目标受到伤害的倍率：碎甲层数与超导易伤相加
func incoming_scale(runtime, target) -> float:
	if not runtime._catalog.has_elements() or not is_instance_valid(target) or not _states.has(target.handle): return 1.0
	var state: Dictionary = _states[target.handle]
	var bonus: float = float(state.vulnerable) if float(state.vulnerable_left) > 0.0 else 0.0
	for id in state.elements:
		bonus += param(runtime, id, "damage_taken_per_stack") * int(state.elements[id].stacks)
	return 1.0 + bonus

## 直接命中且造成了伤害之后调用
func on_direct_hit(runtime, context: Dictionary, target, applied: float) -> void:
	var catalog = runtime._catalog
	if not catalog.has_elements() or not is_instance_valid(target) or not target.health.alive(): return
	var hit := element_of(context.program)
	var hit_id: String = hit.get("element_id", "")
	var state := _state(target)
	# 感电：被任何直接命中都会放电；被其他元素命中时改为反应
	var shocked := _shocked_id(runtime, state)
	if not shocked.is_empty() and (hit_id.is_empty() or hit_id == shocked):
		_discharge(runtime, context, target, shocked)
		if not target.health.alive(): return
	if hit_id.is_empty(): return
	var poise_ratio := param(runtime, hit_id, "poise_damage_ratio")
	if poise_ratio > 0.0: target.add_poise_damage(applied * poise_ratio)
	for other in catalog.element_order():
		if other == hit_id or not state.elements.has(other): continue
		var reaction: Dictionary = catalog.reaction_between(hit_id, other)
		if reaction.is_empty(): continue
		var stacks := int(state.elements[other].stacks)
		state.elements.erase(other)
		_react(runtime, context, target, reaction, stacks, hit_id, other)
		return
	_apply(runtime, context, target, state, hit_id, int(hit.stacks_per_hit))

func _state(target) -> Dictionary:
	if not _states.has(target.handle):
		_states[target.handle] = {"target": weakref(target), "elements": {}, "vulnerable": 0.0, "vulnerable_left": 0.0}
	return _states[target.handle]

func _shocked_id(runtime, state: Dictionary) -> String:
	for id in state.elements:
		if param(runtime, id, "discharge_damage") > 0.0: return id
	return ""

func _apply(runtime, context: Dictionary, target, state: Dictionary, id: String, stacks: int) -> void:
	var element: Dictionary = runtime._catalog.element(id)
	var duration := param(runtime, id, "duration_sec")
	var current: Dictionary = state.elements.get(id, {"stacks": 0, "remaining": 0.0, "tick_left": float(element.tick_sec)})
	current.stacks = mini(int(current.stacks) + stacks, max_stacks(runtime, id))
	current.remaining = duration
	state.elements[id] = current
	if not str(element.slow_status_id).is_empty():
		runtime._apply_status(context, target, element.slow_status_id, duration)
	if not str(element.freeze_status_id).is_empty() and int(current.stacks) >= max_stacks(runtime, id):
		# 叠满：冻结（Boss 按自身响应改为减速窗口），冰寒清零重新累积
		state.elements.erase(id)
		runtime._apply_status(context, target, element.freeze_status_id, float(runtime._catalog.status(element.freeze_status_id).duration_sec))
	runtime.element_presented.emit({"event": "applied", "element": id, "handle": target.handle, "position": target.global_position, "stacks": int(current.stacks)})

func _discharge(runtime, context: Dictionary, target, id: String) -> void:
	_states[target.handle].elements.erase(id)
	var origin: Vector3 = target.global_position
	var points := PackedVector3Array([origin])
	var damage := param(runtime, id, "discharge_damage")
	_damage(runtime, target, damage)
	for other in _nearest(runtime, origin, param(runtime, id, "discharge_radius_m"), int(round(param(runtime, id, "discharge_max_targets"))), target):
		points.append(other.global_position)
		points.append(origin)
		_damage(runtime, other, damage)
	runtime.element_presented.emit({"event": "discharge", "element": id, "handle": target.handle, "position": origin, "points": points})

func _react(runtime, context: Dictionary, target, reaction: Dictionary, stacks: int, hit_id: String, other_id: String) -> void:
	var center: Vector3 = target.global_position
	var handle: int = target.handle
	var affected: Array = [target]
	# 双元素卡（reaction_boost）：反应伤害按比例提高、范围加大
	var boost: Dictionary = runtime._program.get("global", {}).get("reaction_boosts", {}).get(reaction.id, {"damage_bonus": 0.0, "radius_bonus_m": 0.0})
	var damage_scale := 1.0 + float(boost.damage_bonus)
	var radius := float(reaction.radius_m) + (float(boost.radius_bonus_m) if float(reaction.radius_m) > 0.0 else 0.0)
	_damage(runtime, target, (float(reaction.damage) + float(reaction.damage_per_stack) * stacks) * damage_scale)
	if radius > 0.0:
		for other in _nearest(runtime, center, radius, int(reaction.max_targets), target):
			affected.append(other)
			if float(reaction.area_damage) > 0.0: _damage(runtime, other, float(reaction.area_damage) * damage_scale)
	for victim in affected:
		if not is_instance_valid(victim) or not victim.health.alive(): continue
		if float(reaction.knockback_mps) != 0.0 and victim != target:
			# 正数向外推开，负数向中心吸拢
			var away: Vector3 = victim.global_position - center
			away.y = 0.0
			if not away.is_zero_approx():
				var push: Vector3 = away.normalized() * signf(float(reaction.knockback_mps))
				victim.apply_knockback(push, absf(float(reaction.knockback_mps)), float(reaction.knockback_sec))
		if float(reaction.vulnerability) > 0.0:
			var state := _state(victim)
			state.vulnerable = maxf(float(state.vulnerable), float(reaction.vulnerability))
			state.vulnerable_left = maxf(float(state.vulnerable_left), float(reaction.vulnerability_sec))
		if not str(reaction.slow_status_id).is_empty():
			runtime._apply_status(context, victim, reaction.slow_status_id, float(runtime._catalog.status(reaction.slow_status_id).duration_sec))
	var zone_id := -1
	if float(reaction.zone_sec) > 0.0 and _zones.size() < int(runtime._catalog.element_zone_limit()):
		_next_zone += 1
		zone_id = _next_zone
		_zones.append({"id": zone_id, "reaction_id": reaction.id, "position": center, "radius": float(reaction.zone_radius_m) + float(boost.radius_bonus_m),
			"remaining": float(reaction.zone_sec), "tick": float(reaction.zone_tick_sec), "tick_left": float(reaction.zone_tick_sec),
			"damage": float(reaction.zone_damage_per_tick) * damage_scale})
	runtime.element_presented.emit({"event": "reaction", "reaction_id": reaction.id, "name_key": reaction.name_key,
		"elements": [hit_id, other_id], "handle": handle, "position": center, "radius": radius,
		"pull": float(reaction.knockback_mps) < 0.0, "zone_id": zone_id, "zone_radius": float(reaction.zone_radius_m) + float(boost.radius_bonus_m), "zone_sec": float(reaction.zone_sec),
		"boosted": float(boost.damage_bonus) > 0.0 or float(boost.radius_bonus_m) > 0.0})

func _damage(runtime, target, amount: float) -> void:
	if amount <= 0.0 or not is_instance_valid(target) or not target.health.alive(): return
	Damage.apply(target, amount * incoming_scale(runtime, target), runtime._player.team)

## 中心附近最近的若干个敌人（不含 exclude），距离相同按 handle 排序，结果稳定
func _nearest(runtime, center: Vector3, radius: float, limit: int, exclude) -> Array:
	var found: Array = []
	for candidate in runtime._targets.call():
		if not is_instance_valid(candidate) or candidate == exclude or candidate == runtime._player: continue
		if candidate.team == runtime._player.team or not candidate.health.alive(): continue
		var offset: Vector3 = candidate.global_position - center
		offset.y = 0.0
		if offset.length() <= radius: found.append({"target": candidate, "distance": offset.length()})
	found.sort_custom(func(a, b): return a.target.handle < b.target.handle if is_equal_approx(a.distance, b.distance) else a.distance < b.distance)
	return found.slice(0, limit).map(func(entry): return entry.target)

func tick(delta: float, runtime) -> void:
	var catalog = runtime._catalog
	if not catalog.has_elements(): return
	for handle in _states.keys():
		var state: Dictionary = _states[handle]
		var target = state.target.get_ref()
		if target == null or not target.health.alive():
			_states.erase(handle)
			runtime.element_presented.emit({"event": "cleared", "handle": handle})
			continue
		state.vulnerable_left = maxf(0.0, float(state.vulnerable_left) - delta)
		for id in state.elements.keys():
			var current: Dictionary = state.elements[id]
			var element: Dictionary = catalog.element(id)
			if float(element.tick_sec) > 0.0:
				current.tick_left = float(current.tick_left) - delta
				while float(current.tick_left) <= 0.0 and target.health.alive():
					current.tick_left = float(current.tick_left) + float(element.tick_sec)
					_damage(runtime, target, param(runtime, id, "damage_per_tick_per_stack") * int(current.stacks))
			current.remaining = float(current.remaining) - delta
			if float(current.remaining) <= 0.0: state.elements.erase(id)
	for index in range(_zones.size() - 1, -1, -1):
		var zone: Dictionary = _zones[index]
		zone.remaining = float(zone.remaining) - delta
		zone.tick_left = float(zone.tick_left) - delta
		if float(zone.tick_left) <= 0.0:
			zone.tick_left = float(zone.tick_left) + float(zone.tick)
			for victim in _nearest(runtime, zone.position, float(zone.radius), 64, null):
				_damage(runtime, victim, float(zone.damage))
		if float(zone.remaining) <= 0.0:
			_zones.remove_at(index)
			runtime.element_presented.emit({"event": "zone_ended", "zone_id": zone.id})

## 某个目标身上的元素层数（元素 ID → 层数），没有时为空
func stacks_on(handle: int) -> Dictionary:
	var result: Dictionary = {}
	if _states.has(handle):
		for id in _states[handle].elements: result[id] = int(_states[handle].elements[id].stacks)
	return result

## 表现层每帧读取：每个目标身上的元素层数
func snapshot() -> Array:
	var result: Array = []
	for handle in _states:
		var state: Dictionary = _states[handle]
		var target = state.target.get_ref()
		if target == null: continue
		var stacks: Dictionary = {}
		for id in state.elements: stacks[id] = int(state.elements[id].stacks)
		result.append({"handle": handle, "target": target, "elements": stacks, "vulnerable": float(state.vulnerable_left) > 0.0})
	return result

func clear() -> void:
	_states.clear()
	_zones.clear()
