extends SceneTree
const Loader = preload("res://content/run/map_preview_loader.gd")
const Generator = preload("res://rogue/run/map_preview_generator.gd")
const Validator = preload("res://rogue/run/map_graph_validator.gd")
const StrictJSON = preload("res://content/run/strict_json.gd")
const Pruner = preload("res://rogue/run/map_branch_pruner.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)

func run() -> void:
	var loader := Loader.new()
	var rules := loader.load_rules("res://data/run/map_preview_manifest.json")
	check(not rules.is_empty() and loader.errors.is_empty(), "valid content")
	if rules.is_empty(): quit(1); return
	check(rules.is_read_only() and rules.room_types.is_read_only() and rules.room_types[0].is_read_only(), "deeply read-only rules")
	var generator := Generator.new()
	var validator := Validator.new()
	var shapes: Dictionary = {}
	var total_pruned := 0
	for value in 300:
		var result := generator.generate(rules, str(value))
		check(result.ok, "seed %s succeeds" % value)
		if not result.ok: continue
		var plan: Dictionary = result.plan
		total_pruned += int(result.pruned_node_count)
		var pruning_rng := RandomNumberGenerator.new()
		pruning_rng.seed = value
		check(Pruner.new().prune(plan, pruning_rng).removed_node_ids.is_empty(), "seed %s has no remaining safely removable duplicate" % value)
		check(validator.validate(plan, rules).is_empty(), "seed %s invariants" % value)
		# Independent reachability check: every start can reach the top; every node is covered.
		var from_start: Dictionary = {}
		var to_end: Dictionary = {}
		for node in plan.nodes:
			if node.layer == 0: from_start[node.id] = true
			if node.layer == rules.rows - 1: to_end[node.id] = true
		for layer in int(rules.rows):
			for edge in plan.edges:
				if from_start.has(edge.from): from_start[edge.to] = true
			for edge in plan.edges:
				if to_end.has(edge.to): to_end[edge.from] = true
		check(from_start.size() == plan.nodes.size() and to_end.size() == plan.nodes.size(), "every node lies on complete path")
		shapes[JSON.stringify(plan.edges)] = true
	check(shapes.size() > 290, "varied topology across seeds")
	check(total_pruned > 0, "batch actually exercises pruning")
	var first := generator.generate(rules, "panda-map")
	generator.generate(rules, "unrelated")
	check(JSON.stringify(first) == JSON.stringify(generator.generate(rules, "panda-map")), "seed reproduction independent of visit order")
	check(first.plan.nodes[0].is_read_only() and first.plan.edges.is_read_only(), "deeply read-only plan")
	seed(527)
	var expected := randi()
	seed(527)
	generator.generate(rules, "global-rng")
	check(randi() == expected, "global RNG isolation")
	var invalid: Dictionary = first.plan.duplicate(true)
	invalid.edges.append(invalid.edges[0].duplicate())
	check(not validator.validate(invalid, rules).is_empty(), "duplicate edge rejected")
	invalid = first.plan.duplicate(true)
	invalid.nodes[0].kind = "unknown"
	check(not validator.validate(invalid, rules).is_empty(), "unknown kind rejected")
	invalid = first.plan.duplicate(true)
	invalid.edges.clear()
	check(not validator.validate(invalid, rules).is_empty(), "disconnected nodes rejected")
	var impossible: Dictionary = rules.duplicate(true)
	impossible.max_attempts = 1
	for kind in impossible.room_types: kind.min_count = 64
	var before := JSON.stringify(impossible)
	check(not generator.generate(impossible, "bounded").ok, "unsatisfiable content fails within attempt budget")
	check(JSON.stringify(impossible) == before, "generation never mutates caller rules")
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/schemas/map_preview.schema.json"))
	var bad: Dictionary = rules.duplicate(true)
	bad.rows = 2
	check(loader.decode(bad, schema).is_empty(), "invalid bounds rejected")
	bad = rules.duplicate(true)
	bad.unexpected = 3
	check(loader.decode(bad, schema).is_empty(), "unknown field rejected")
	bad = rules.duplicate(true)
	bad.room_types[1].id = bad.room_types[0].id
	check(loader.decode(bad, schema).is_empty(), "duplicate kind rejected")
	bad = rules.duplicate(true)
	bad.fixed_layers.append({"layer": 1, "kind": "elite"})
	check(loader.decode(bad, schema).is_empty(), "impossible fixed layer rejected")
	var strict := StrictJSON.new()
	strict.parse('{"rows":15,"rows":16}', "fixture")
	check(not strict.errors.is_empty(), "duplicate JSON keys rejected")
	print("MAP_GENERATION checks=", checks, " failures=", failures.size(), " unique_graphs=", shapes.size(), " pruned_nodes=", total_pruned)
	quit(0 if failures.is_empty() else 1)
