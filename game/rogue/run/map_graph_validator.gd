extends RefCounted
## Graph invariants, independent of generation and presentation.
func validate(graph: Dictionary, rules: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var nodes: Dictionary = {}
	var cells: Dictionary = {}
	var incoming: Dictionary = {}
	var outgoing: Dictionary = {}
	var counts: Dictionary = {}
	var kinds: Dictionary = {}
	for kind in rules.room_types:
		kinds[kind.id] = kind
		counts[kind.id] = 0
	if graph.nodes.is_empty(): errors.append("empty graph")
	for node in graph.nodes:
		var cell := "%s:%s" % [node.layer, node.column]
		if nodes.has(node.id) or cells.has(cell): errors.append("duplicate node/cell")
		if node.layer < 0 or node.layer >= rules.rows or node.column < 0 or node.column >= rules.columns: errors.append("node outside grid")
		nodes[node.id] = node
		cells[cell] = true
		incoming[node.id] = []
		outgoing[node.id] = []
		if not kinds.has(node.kind):
			errors.append("unassigned/unknown kind")
			continue
		counts[node.kind] += 1
		if node.layer < kinds[node.kind].min_layer or node.layer > kinds[node.kind].max_layer: errors.append("kind outside permitted layers")
		for fixed in rules.fixed_layers:
			if node.layer == fixed.layer and node.kind != fixed.kind: errors.append("fixed layer mismatch")
	var links: Dictionary = {}
	for edge in graph.edges:
		if not nodes.has(edge.from) or not nodes.has(edge.to):
			errors.append("unknown edge endpoint")
			continue
		var key: String = edge.from + ":" + edge.to
		if links.has(key): errors.append("duplicate edge")
		links[key] = true
		var a: Dictionary = nodes[edge.from]
		var b: Dictionary = nodes[edge.to]
		if b.layer != a.layer + 1 or absi(b.column - a.column) > 1: errors.append("invalid direction/span")
		if a.kind == b.kind and kinds.has(a.kind) and kinds[a.kind].avoid_consecutive: errors.append("consecutive special type")
		incoming[b.id].append(a.id)
		outgoing[a.id].append(b.id)
	var has_branch := false
	var has_merge := false
	var reached: Dictionary = {}
	for layer in int(rules.rows):
		for node in graph.nodes:
			if node.layer != layer: continue
			if layer == 0: reached[node.id] = true
			for parent in incoming[node.id]:
				if reached.has(parent): reached[node.id] = true
			if not reached.has(node.id): errors.append("unreachable node")
			if layer < int(rules.rows) - 1 and outgoing[node.id].is_empty(): errors.append("dead end")
			has_branch = has_branch or outgoing[node.id].size() > 1
			has_merge = has_merge or incoming[node.id].size() > 1
	if not has_branch or not has_merge: errors.append("missing branch/merge")
	for kind in kinds:
		if counts[kind] < kinds[kind].min_count: errors.append("missing required type: " + kind)
	for i in graph.edges.size():
		var left: Dictionary = graph.edges[i]
		if not nodes.has(left.from) or not nodes.has(left.to): continue
		for j in range(i + 1, graph.edges.size()):
			var right: Dictionary = graph.edges[j]
			if not nodes.has(right.from) or not nodes.has(right.to): continue
			var a: Dictionary = nodes[left.from]
			var b: Dictionary = nodes[left.to]
			var c: Dictionary = nodes[right.from]
			var d: Dictionary = nodes[right.to]
			if a.layer == c.layer and (a.column - c.column) * (b.column - d.column) < 0: errors.append("crossing edges")
	return errors
