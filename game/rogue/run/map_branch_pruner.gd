extends RefCounted
## Simplifies valid layered graphs only. Each removable interior has one parent and
## one successor; shared junctions and side branches are always retained.
const START = "@preview_start"
const END = "@preview_end"

func prune(graph: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var candidate: Dictionary = graph.duplicate(true)
	var removed: Array[String] = []
	# Every successful pass removes at least one real node, so this is a structural
	# termination bound, not a tunable gameplay limit. Re-index after each deletion:
	# reducing an inner diamond can expose another redundant outer branch.
	for _pass in graph.nodes.size():
		var group := _first_duplicate_group(candidate)
		if group.is_empty(): break
		var kept := rng.randi_range(0, group.size() - 1)
		var deleting: Dictionary = {}
		for index in group.size():
			if index == kept: continue
			for id in group[index]:
				deleting[id] = true
				removed.append(id)
		candidate.nodes = candidate.nodes.filter(func(node): return not deleting.has(node.id))
		candidate.edges = candidate.edges.filter(func(edge): return not deleting.has(edge.from) and not deleting.has(edge.to))
	return {"graph": candidate, "removed_node_ids": removed}

func _first_duplicate_group(graph: Dictionary) -> Array:
	var nodes: Dictionary = {}
	var incoming: Dictionary = {START: [], END: []}
	var outgoing: Dictionary = {START: [], END: []}
	for node in graph.nodes:
		nodes[node.id] = node
		incoming[node.id] = []
		outgoing[node.id] = []
	for edge in graph.edges:
		outgoing[edge.from].append(edge.to)
		incoming[edge.to].append(edge.from)
	# Synthetic links exist only in this analysis index, never in the published plan.
	for node in graph.nodes:
		if node.layer == 0:
			outgoing[START].append(node.id)
			incoming[node.id].append(START)
		if node.layer == int(graph.rows) - 1:
			outgoing[node.id].append(END)
			incoming[END].append(node.id)
	var junctions: Array = outgoing.keys()
	junctions.sort()
	for source in junctions:
		if outgoing[source].size() < 2: continue
		var groups: Dictionary = {}
		var successors: Array = outgoing[source].duplicate()
		successors.sort() # Seeded choice is independent of input node/edge array order.
		for successor in successors:
			var interior: Array[String] = []
			var kinds: Array[String] = []
			var cursor: String = successor
			while cursor != END and incoming[cursor].size() == 1 and outgoing[cursor].size() == 1:
				interior.append(cursor)
				kinds.append(nodes[cursor].kind)
				cursor = outgoing[cursor][0]
			if interior.is_empty(): continue
			# Same source is implicit in this loop. Destination identity and ordered
			# room types matter; different IDs or coordinates are not meaningful choices.
			var signature := JSON.stringify([cursor, kinds])
			if not groups.has(signature): groups[signature] = []
			groups[signature].append(interior)
		for signature in groups:
			if groups[signature].size() > 1: return groups[signature]
	return []
