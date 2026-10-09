extends RefCounted
## Original implementation of layered random walks; no scene, encounter or global RNG access.
const Definition = preload("res://content/run/run_definition.gd")
const Validator = preload("res://rogue/run/map_graph_validator.gd")
const Pruner = preload("res://rogue/run/map_branch_pruner.gd")
const ALGORITHM = "branch_preview.v2"

func generate(rules: Dictionary, seed_text: String) -> Dictionary:
	var topology := RandomNumberGenerator.new()
	var types := RandomNumberGenerator.new()
	var pruning := RandomNumberGenerator.new()
	topology.seed = (ALGORITHM + ":topology:" + seed_text).hash()
	types.seed = (ALGORITHM + ":types:" + seed_text).hash()
	pruning.seed = (ALGORITHM + ":pruning:" + seed_text).hash()
	var validator := Validator.new()
	var pruner := Pruner.new()
	for attempt in int(rules.max_attempts):
		var graph := _topology(rules, topology)
		_assign_types(graph, rules, types)
		if not validator.validate(graph, rules).is_empty(): continue
		var simplified := pruner.prune(graph, pruning)
		graph = simplified.graph
		if validator.validate(graph, rules).is_empty():
			graph["seed"] = seed_text
			graph["algorithm"] = ALGORITHM
			graph["content_version"] = rules.content_version
			return {"ok": true, "plan": Definition.freeze_copy(graph), "attempt": attempt, "pruned_node_count": simplified.removed_node_ids.size()}
	return {"ok": false, "error_key": "map_preview.failed"}

func _topology(rules: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var nodes: Dictionary = {}
	var edges: Array = []
	var first_column := -1
	for path_index in int(rules.paths):
		var column := rng.randi_range(0, int(rules.columns) - 1)
		if path_index == 0: first_column = column
		if path_index == 1 and column == first_column: column = (column + 1) % int(rules.columns)
		var source := _node(nodes, 0, column)
		for layer in range(1, int(rules.rows)):
			var choices: Array[int] = []
			for next_column in range(maxi(0, column - 1), mini(int(rules.columns) - 1, column + 1) + 1):
				var crossing := false
				for edge in edges:
					var a: Dictionary = nodes[edge.from]
					var b: Dictionary = nodes[edge.to]
					if a.layer == layer - 1 and (column - a.column) * (next_column - b.column) < 0:
						crossing = true
						break
				if not crossing: choices.append(next_column)
			# An existing successor remains legal when sharing a source.
			assert(not choices.is_empty())
			column = choices[rng.randi_range(0, choices.size() - 1)]
			var target := _node(nodes, layer, column)
			var link := {"from": source, "to": target}
			if not edges.has(link): edges.append(link)
			source = target
	return {"nodes": nodes.values(), "edges": edges, "rows": int(rules.rows), "columns": int(rules.columns)}

func _node(nodes: Dictionary, layer: int, column: int) -> String:
	var id := "r%s_c%s" % [layer, column]
	if not nodes.has(id): nodes[id] = {"id": id, "layer": layer, "column": column, "kind": ""}
	return id

func _assign_types(graph: Dictionary, rules: Dictionary, rng: RandomNumberGenerator) -> void:
	var by_id: Dictionary = {}
	for node in graph.nodes: by_id[node.id] = node
	for layer in int(rules.rows):
		for node in graph.nodes:
			if node.layer != layer: continue
			for fixed in rules.fixed_layers:
				if fixed.layer == layer: node.kind = fixed.kind
			if not node.kind.is_empty(): continue
			var choices: Array = []
			var total := 0.0
			for kind in rules.room_types:
				if layer < kind.min_layer or layer > kind.max_layer: continue
				var allowed := true
				if kind.avoid_consecutive:
					for edge in graph.edges:
						if edge.to == node.id and by_id[edge.from].kind == kind.id: allowed = false
						if edge.from == node.id:
							for fixed in rules.fixed_layers:
								if fixed.layer == layer + 1 and fixed.kind == kind.id: allowed = false
				if allowed:
					choices.append(kind)
					total += float(kind.weight)
			if choices.is_empty(): continue # Reject the candidate; never substitute hidden defaults.
			var roll := rng.randf() * total
			node.kind = choices.back().id
			for kind in choices:
				roll -= float(kind.weight)
				if roll < 0.0:
					node.kind = kind.id
					break
