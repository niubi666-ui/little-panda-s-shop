extends RefCounted
## Stateless encounter stream per run+node. Never touches another stream's RNG.
const Encounters = preload("res://rogue/encounters/encounter_planner.gd")
const Definition = preload("res://content/run/run_definition.gd")
const STREAM_VERSION := "run_room.v1"
var errors: PackedStringArray = []
var _enemies
var _capacities: Dictionary = {}

func configure(enemy_catalog, template_capacities: Dictionary) -> void:
	errors.clear()
	_enemies = enemy_catalog
	_capacities = template_capacities.duplicate(true)
	if _enemies == null: errors.append("run planner: validated enemy catalog required")
	for id in _capacities:
		var value: Variant = _capacities[id]
		if not id is String or not (value is int or value is float) or not is_finite(float(value)) or value != floor(value) or value < 1 or value > 65536:
			errors.append("run planner: invalid template capacity " + str(id))
	if _capacities.is_empty(): errors.append("run planner: no templates configured")
	if not errors.is_empty():
		_enemies = null
		_capacities.clear()

func plan(node: Dictionary, seed: int) -> Dictionary:
	errors.clear()
	if _enemies == null or _capacities.is_empty(): return _fail("run planner: not configured")
	for key in ["id", "template_id", "depth", "kind", "reward_id"]:
		if not node.has(key): return _fail("run planner: missing node field " + key)
	if not node.id is String or node.id.is_empty() or not node.template_id is String or not _capacities.has(node.template_id): return _fail("run planner: unknown node/template")
	if not (node.depth is int or node.depth is float) or not is_finite(float(node.depth)) or node.depth != floor(node.depth) or node.depth < 1 or node.depth > _enemies.encounters.training_max_depth: return _fail("run planner: unsupported depth")
	if not node.kind in ["battle", "elite", "terminal"] or node.reward_id != "none": return _fail("run planner: unsupported node kind/reward")
	var capacity := int(_capacities[node.template_id])
	if Encounters.legal(int(node.depth), capacity, _enemies).is_empty(): return _fail("run planner: no legal encounter for node " + node.id)
	var derived_seed := node_seed(seed, node.id)
	var encounter: Dictionary = Encounters.new().generate(derived_seed, int(node.depth), capacity, _enemies)
	if encounter.is_empty(): return _fail("run planner: encounter generation failed")
	return Definition.freeze_copy({"node_id": node.id, "template_id": node.template_id, "depth": int(node.depth), "kind": node.kind, "reward_id": node.reward_id, "encounter_plan": encounter})

static func node_seed(seed: int, node_id: String) -> String:
	return str((str(seed) + "|" + STREAM_VERSION + "|" + node_id).sha256_text().substr(0, 15).hex_to_int())

func _fail(message: String) -> Dictionary:
	errors.append(message)
	return {}
