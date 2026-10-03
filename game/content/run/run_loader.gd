extends RefCounted
## Route definitions only; live progress belongs to app/session.
const StrictJSON = preload("res://content/run/strict_json.gd")
const Definition = preload("res://content/run/run_definition.gd")
var errors: PackedStringArray = []

func load_route(build_catalog, enemy_catalog, template_ids: Array, manifest_path: String = "res://data/manifest.json") -> Dictionary:
	errors.clear()
	var manifest: Variant = _read(manifest_path)
	if not errors.is_empty(): return {}
	if not manifest is Dictionary or not manifest.has("run_route_file"):
		errors.append(manifest_path + ": missing run_route_file")
		return {}
	var path: Variant = manifest.run_route_file
	if not path is String or not path.begins_with("res://data/run/") or not path.ends_with(".json") or path.contains(".."):
		errors.append(manifest_path + ": invalid run_route_file")
		return {}
	var data: Variant = _read(path)
	if not errors.is_empty(): return {}
	var result := decode(data, build_catalog, enemy_catalog, template_ids)
	if result.is_empty():
		for i in errors.size(): errors[i] = path + ": " + errors[i]
	return result

func decode_json(text: String, build_catalog, enemy_catalog, template_ids: Array) -> Dictionary:
	errors.clear()
	var parser := StrictJSON.new()
	var data: Variant = parser.parse(text, "route")
	if not parser.errors.is_empty():
		errors = parser.errors.duplicate()
		return {}
	return decode(data, build_catalog, enemy_catalog, template_ids)

func decode(data: Variant, build_catalog, enemy_catalog, template_ids: Array) -> Dictionary:
	errors.clear()
	if build_catalog == null or enemy_catalog == null:
		errors.append("route: validated build/enemy catalogs required")
		return {}
	if not _object(data, ["schema_version", "id", "content_version", "start_node_ids", "nodes", "edges", "starter_build_preset", "rewards"], "route"): return {}
	if not _integer(data.schema_version, 1, 1): errors.append("route.schema_version: unsupported version")
	for key in ["id", "content_version", "starter_build_preset"]:
		if not _id(data[key]): errors.append("route." + key + ": invalid stable ID")
	if not _ids(data.start_node_ids, 1, 16): errors.append("route.start_node_ids: expected unique nonempty IDs")
	if not _ids(template_ids, 1, 64): errors.append("route: supported template IDs required")
	if not data.nodes is Array or data.nodes.size() < 2 or data.nodes.size() > 64: errors.append("route.nodes: expected 2..64 nodes")
	if not data.edges is Array or data.edges.is_empty() or data.edges.size() > 256: errors.append("route.edges: expected 1..256 edges")
	if not data.rewards is Array or data.rewards.size() != 1:
		errors.append("route.rewards: current slice requires exactly the none reward")
	else:
		var reward: Variant = data.rewards[0]
		if _object(reward, ["id", "kind"], "route.reward") and (reward.id != "none" or reward.kind != "none"):
			errors.append("route.reward: only id/kind none is implemented")
	if not errors.is_empty(): return {}
	if build_catalog.test_preset(data.starter_build_preset).is_empty(): errors.append("route.starter_build_preset: unknown preset " + data.starter_build_preset)
	var nodes: Dictionary = {}
	var cells: Dictionary = {}
	var terminals: Array[String] = []
	for index in data.nodes.size():
		var node: Variant = data.nodes[index]
		var path := "route.nodes[%s]" % index
		if not _object(node, ["id", "layer", "column", "kind", "depth", "template_id", "reward_id"], path): continue
		if not _id(node.id): errors.append(path + ".id: invalid stable ID"); continue
		path += "(" + str(node.id) + ")"
		if nodes.has(node.id): errors.append(path + ": duplicate node ID")
		nodes[node.id] = node
		if not _integer(node.layer, 0, 63): errors.append(path + ".layer: integer 0..63 required")
		if not _integer(node.column, 0, 15): errors.append(path + ".column: integer 0..15 required")
		if not _integer(node.depth, 1, int(enemy_catalog.encounters.training_max_depth)): errors.append(path + ".depth: outside configured encounter depth cap")
		if not node.kind is String or node.kind not in ["battle", "elite", "terminal"]: errors.append(path + ".kind: unsupported node kind")
		if node.kind == "terminal": terminals.append(node.id)
		if not _id(node.template_id) or not template_ids.has(node.template_id): errors.append(path + ".template_id: unknown template")
		if node.reward_id != "none": errors.append(path + ".reward_id: only none is implemented")
		var cell := "%s:%s" % [node.layer, node.column]
		if cells.has(cell): errors.append(path + ": duplicate layer/column cell")
		cells[cell] = true
	if terminals.size() != 1: errors.append("route.nodes: exactly one terminal is required")
	if not errors.is_empty(): return {}
	_validate_graph(data, nodes, terminals[0])
	return Definition.freeze_copy(data) if errors.is_empty() else {}

func _validate_graph(data: Dictionary, nodes: Dictionary, terminal: String) -> void:
	var incoming: Dictionary = {}
	var outgoing: Dictionary = {}
	for id in nodes:
		incoming[id] = []
		outgoing[id] = []
	var edge_ids: Dictionary = {}
	for index in data.edges.size():
		var edge: Variant = data.edges[index]
		var path := "route.edges[%s]" % index
		if not _object(edge, ["from", "to"], path): continue
		if not _id(edge["from"]) or not _id(edge.to) or not nodes.has(edge["from"]) or not nodes.has(edge.to):
			errors.append(path + ": unknown node reference")
			continue
		var source: Dictionary = nodes[edge["from"]]
		var target: Dictionary = nodes[edge.to]
		var identity := str(source.id) + "/" + str(target.id)
		if edge_ids.has(identity): errors.append(path + ": duplicate connection")
		edge_ids[identity] = true
		if int(target.layer) != int(source.layer) + 1: errors.append(path + ": connections must advance exactly one layer")
		if int(target.depth) <= int(source.depth): errors.append(path + ": encounter depth must increase")
		outgoing[source.id].append(target.id)
		incoming[target.id].append(source.id)
	if not errors.is_empty(): return
	for id in data.start_node_ids:
		if not nodes.has(id): errors.append("route.start_node_ids: unknown start " + str(id))
		elif nodes[id].layer != 0 or not incoming[id].is_empty(): errors.append("route.start_node_ids: starts must be layer-zero roots")
	if not errors.is_empty(): return
	for id in nodes:
		if incoming[id].is_empty() and not data.start_node_ids.has(id): errors.append("route.nodes." + str(id) + ": disconnected undeclared root")
		if id == terminal:
			if not outgoing[id].is_empty(): errors.append("route terminal cannot have outgoing edges")
		elif outgoing[id].is_empty(): errors.append("route.nodes." + str(id) + ": nonterminal dead end")
	var reached := _walk(data.start_node_ids, outgoing)
	var reaches_terminal := _walk([terminal], incoming)
	for id in nodes:
		if not reached.has(id): errors.append("route.nodes." + str(id) + ": unreachable from starts")
		if not reaches_terminal.has(id): errors.append("route.nodes." + str(id) + ": cannot reach terminal")

func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append(path + ": missing file")
		return null
	var parser := StrictJSON.new()
	var value: Variant = parser.parse(FileAccess.get_file_as_string(path), path)
	errors.append_array(parser.errors)
	return value

static func _walk(starts: Array, adjacency: Dictionary) -> Dictionary:
	var reached: Dictionary = {}
	var queue: Array = starts.duplicate()
	while not queue.is_empty():
		var id: String = queue.pop_front()
		if reached.has(id): continue
		reached[id] = true
		queue.append_array(adjacency[id])
	return reached

func _object(value: Variant, fields: Array, path: String) -> bool:
	if not value is Dictionary:
		errors.append(path + ": expected object")
		return false
	var valid := true
	for field in fields:
		if not value.has(field): errors.append(path + "." + field + ": required"); valid = false
	for key in value:
		if not fields.has(key): errors.append(path + "." + str(key) + ": unknown field"); valid = false
	return valid

static func _id(value: Variant) -> bool:
	if not value is String or value.length() > 128: return false
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_.-]*$")
	return pattern.search(value) != null

static func _ids(value: Variant, minimum: int, maximum: int) -> bool:
	if not value is Array or value.size() < minimum or value.size() > maximum: return false
	var seen: Dictionary = {}
	for id in value:
		if not _id(id) or seen.has(id): return false
		seen[id] = true
	return true

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum
