extends SceneTree
const Pruner = preload("res://rogue/run/map_branch_pruner.gd")
const Validator = preload("res://rogue/run/map_graph_validator.gd")
const Loader = preload("res://content/run/map_preview_loader.gd")
const Definition = preload("res://content/run/run_definition.gd")
var checks := 0
var failures: Array[String] = []

class FixedGenerator:
	extends "res://rogue/run/map_preview_generator.gd"
	var fixture: Dictionary
	var calls := 0
	func _topology(_rules: Dictionary, _rng: RandomNumberGenerator) -> Dictionary:
		calls += 1
		return fixture.duplicate(true)
	func _assign_types(_graph: Dictionary, _rules: Dictionary, _rng: RandomNumberGenerator) -> void:
		pass

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)

func graph(rows: int, nodes: Array, edges: Array) -> Dictionary:
	var result := {"rows": rows, "columns": 3, "nodes": [], "edges": []}
	for n in nodes: result.nodes.append({"id": n[0], "layer": n[1], "column": n[2], "kind": n[3]})
	for edge in edges: result.edges.append({"from": edge[0], "to": edge[1]})
	return result

func prune(value: Dictionary, seed_value: int = 13) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Pruner.new().prune(value, rng)

func _words(current: String, nodes: Dictionary, outgoing: Dictionary, prefix: Array, result: Dictionary) -> void:
	var next: Array = prefix.duplicate()
	next.append(nodes[current].kind)
	if outgoing[current].is_empty(): result[JSON.stringify(next)] = true
	for child in outgoing[current]: _words(child, nodes, outgoing, next, result)

func language(value: Dictionary) -> Dictionary:
	var nodes: Dictionary = {}
	var outgoing: Dictionary = {}
	for node in value.nodes:
		nodes[node.id] = node
		outgoing[node.id] = []
	for edge in value.edges: outgoing[edge.from].append(edge.to)
	var result: Dictionary = {}
	for node in value.nodes:
		if node.layer == 0: _words(node.id, nodes, outgoing, [], result)
	return result

func verify(value: Dictionary, removed: int, label: String) -> Dictionary:
	var original := JSON.stringify(value)
	var result := prune(Definition.freeze_copy(value))
	check(result.removed_node_ids.size() == removed, label + ": expected deletion count")
	check(JSON.stringify(value) == original, label + ": caller unchanged")
	check(language(result.graph) == language(value), label + ": preserves all ordered room-type experiences")
	check(prune(result.graph).removed_node_ids.is_empty(), label + ": reaches fixed point")
	check(JSON.stringify(result) == JSON.stringify(prune(value)), label + ": reproducible choice")
	for node in result.graph.nodes: check(value.nodes.has(node), label + ": surviving node unchanged")
	for edge in result.graph.edges: check(value.edges.has(edge), label + ": no added/rewired edges")
	return result

func run() -> void:
	# The user's screenshot: two entry rooms merge immediately, without a real start node.
	var entry := graph(2, [["a",0,0,"battle"],["b",0,1,"battle"],["m",1,1,"battle"]], [["a","m"],["b","m"]])
	verify(entry, 1, "virtual start")
	var diamond := graph(3, [["s",0,1,"battle"],["a",1,0,"event"],["b",1,2,"event"],["m",2,1,"rest"]], [["s","a"],["s","b"],["a","m"],["b","m"]])
	verify(diamond, 1, "internal diamond")
	var different := diamond.duplicate(true)
	different.nodes[2].kind = "shop"
	verify(different, 0, "different room types")
	var end := graph(2, [["s",0,1,"battle"],["a",1,0,"rest"],["b",1,2,"rest"]], [["s","a"],["s","b"]])
	verify(end, 1, "virtual end")
	var parallel := graph(3, [["a",0,0,"battle"],["b",0,2,"battle"],["c",1,0,"event"],["d",1,2,"event"],["e",2,0,"rest"],["f",2,2,"rest"]], [["a","c"],["b","d"],["c","e"],["d","f"]])
	verify(parallel, 3, "whole parallel routes between virtual endpoints")
	var reversed := parallel.duplicate(true)
	reversed.nodes[3].kind = "rest"
	reversed.nodes[5].kind = "event"
	verify(reversed, 0, "same kinds in different order")
	var side_exit := graph(4, [["s",0,1,"battle"],["a",1,0,"event"],["b",1,2,"event"],["m",2,1,"rest"],["x",2,0,"shop"],["t",3,1,"battle"]], [["s","a"],["s","b"],["a","m"],["b","m"],["a","x"],["m","t"],["x","t"]])
	verify(side_exit, 0, "external outgoing branch preserved")
	var side_entry := graph(3, [["s",0,1,"battle"],["x",0,0,"shop"],["a",1,0,"event"],["b",1,2,"event"],["m",2,1,"rest"]], [["s","a"],["s","b"],["x","a"],["a","m"],["b","m"]])
	verify(side_entry, 0, "external incoming branch preserved")
	var nested := graph(5, [["s",0,1,"battle"],["a",1,0,"event"],["b",1,2,"event"],["c",2,0,"battle"],["d",2,1,"battle"],["e",2,2,"battle"],["f",3,0,"shop"],["g",3,2,"shop"],["t",4,1,"rest"]], [["s","a"],["s","b"],["a","c"],["a","d"],["b","e"],["c","f"],["d","f"],["e","g"],["f","t"],["g","t"]])
	verify(nested, 4, "inner pruning exposes outer duplicate")
	var three := diamond.duplicate(true)
	three.nodes.append({"id":"c", "layer":1, "column":1, "kind":"event"})
	three.edges.append({"from":"s", "to":"c"})
	three.edges.append({"from":"c", "to":"m"})
	verify(three, 2, "three equivalent branches retain exactly one")
	var permuted := nested.duplicate(true)
	permuted.nodes.reverse()
	permuted.edges.reverse()
	check(prune(nested).removed_node_ids == prune(permuted).removed_node_ids, "input iteration order does not affect selection")
	seed(35)
	var expected := randi()
	seed(35)
	prune(nested)
	check(randi() == expected, "pruning does not consume global RNG")
	var survivors: Dictionary = {}
	for seed_value in 16:
		var reduced: Dictionary = prune(diamond, seed_value).graph
		for node in reduced.nodes:
			if node.layer == 1: survivors[node.id] = true
	check(survivors.size() == 2, "seeded keeper avoids always retaining same side")
	# Valid before pruning; only the minimum rest count fails afterwards. A second,
	# meaningful event/shop choice stays intact, so this tests the real post-prune gate.
	var quota := graph(5, [["s",0,1,"battle"],["a",1,0,"event"],["b",1,2,"shop"],["m",2,1,"battle"],["r1",3,0,"rest"],["r2",3,2,"rest"],["t",4,1,"battle"]], [["s","a"],["s","b"],["a","m"],["b","m"],["m","r1"],["m","r2"],["r1","t"],["r2","t"]])
	var rules: Dictionary = Loader.new().load_rules("res://data/run/map_preview_manifest.json").duplicate(true)
	rules.rows = 5
	rules.columns = 3
	rules.max_attempts = 2
	rules.fixed_layers = []
	for kind in rules.room_types:
		kind.min_layer = 0
		kind.max_layer = 4
		kind.min_count = 2 if kind.id == "rest" else 0
	var validator := Validator.new()
	check(validator.validate(quota, rules).is_empty(), "quota fixture initially valid")
	check(validator.validate(prune(quota).graph, rules).has("missing required type: rest"), "post-prune quota violation detected")
	var generator := FixedGenerator.new()
	generator.fixture = quota
	check(not generator.generate(rules, "quota").ok and generator.calls == 2, "generator retries finitely instead of publishing invalid pruned graph")
	print("MAP_BRANCH_PRUNING checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
