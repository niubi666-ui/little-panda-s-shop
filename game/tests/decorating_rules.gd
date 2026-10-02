extends SceneTree
## Run separately when the editor is available: --headless --script res://tests/decorating_rules.gd

const Rules = preload("res://shop/decorating/layout_rules.gd")
const Session = preload("res://shop/decorating/decoration_session.gd")
const Catalog = preload("res://content/decorating/decorating_catalog.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	_test_rotation_and_bounds()
	_test_collisions_and_repositioning()
	_test_access_and_isolation()
	_test_navigation_clearance()
	_test_invalid_data()
	_test_catalog_isolation()
	_test_session_transactions()
	print("DECORATING_RULES ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _test_rotation_and_bounds() -> void:
	var rules := _open_board()
	var wide: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2)]
	var tall: Array[Vector2i] = [Vector2i(2, 2), Vector2i(2, 3)]
	check(rules.occupied_cells(Vector2i(2, 2), Vector2i(2, 1), 0) == wide, "unrotated footprint")
	check(rules.occupied_cells(Vector2i(2, 2), Vector2i(2, 1), 1) == tall, "90 degrees swaps axes")
	check(rules.occupied_cells(Vector2i(2, 2), Vector2i(2, 1), 2) == wide, "180 degrees keeps bounds")
	check(rules.occupied_cells(Vector2i(2, 2), Vector2i(2, 1), 3) == tall, "270 degrees swaps axes")
	var layout: Array[Dictionary] = []
	check_code(rules.evaluate(layout, _item("new", Vector2i(4, 2), 1), Vector2i(2, 1), ""), "ok", "rotated edge fits")
	check_code(rules.evaluate(layout, _item("new", Vector2i(4, 2), 0), Vector2i(2, 1), ""), "out_of_bounds", "unrotated edge rejected")
	check_code(rules.evaluate(layout, _item("new", Vector2i(-1, 2), 0), Vector2i.ONE, ""), "out_of_bounds", "negative anchor rejected")
	check_code(rules.evaluate(layout, _item("new", Vector2i(2, 4), 1), Vector2i(2, 1), ""), "out_of_bounds", "rotated bottom edge rejected")


func _test_collisions_and_repositioning() -> void:
	var rules := Rules.new()
	rules.configure(Vector2i(5, 5), [Vector2i(4, 4)], [Vector2i(0, 4)], Vector2i.ZERO, [Vector2i(4, 4)], 0)
	var old := _item("old", Vector2i(2, 2), 0)
	old["footprint"] = Vector2i(2, 1)
	var layout: Array[Dictionary] = [old]
	check_code(rules.evaluate(layout, _item("new", Vector2i(3, 2), 0), Vector2i.ONE, ""), "occupied", "another instance overlaps")
	check_code(rules.evaluate(layout, _item("new", Vector2i(4, 4), 0), Vector2i.ONE, ""), "blocked", "fixed obstacle rejected")
	check_code(rules.evaluate(layout, _item("old", Vector2i(2, 2), 1), Vector2i(2, 1), "old"), "ok", "rotation ignores original footprint")
	check_code(rules.evaluate(layout, _item("new", Vector2i(2, 2), 0), Vector2i.ONE, "old"), "invalid", "cannot ignore another instance")
	check_code(rules.evaluate(layout, _item("old", Vector2i(4, 3), 0), Vector2i.ONE, ""), "invalid", "stable IDs cannot duplicate")
	check(layout[0]["cell"] == Vector2i(2, 2) and layout[0]["quarter_turn"] == 0, "evaluation leaves original layout untouched")


func _test_access_and_isolation() -> void:
	var rules := Rules.new()
	var blocked: Array[Vector2i] = [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 3), Vector2i(2, 4)]
	var targets: Array[Vector2i] = [Vector2i(4, 2)]
	var navigation: Array[Vector2i] = blocked.duplicate()
	rules.configure(Vector2i(5, 5), blocked, targets, Vector2i(0, 2), navigation, 0)
	blocked.clear()
	navigation.clear()
	targets.clear()
	var layout: Array[Dictionary] = []
	check_code(rules.evaluate(layout, _item("new", Vector2i(2, 2), 0), Vector2i.ONE, ""), "access_blocked", "closing one-cell corridor rejected after input arrays mutate")
	check_code(rules.evaluate(layout, _item("new", Vector2i(4, 2), 0), Vector2i.ONE, ""), "access_blocked", "required interaction cell protected")
	check_code(rules.evaluate(layout, _item("new", Vector2i(0, 2), 0), Vector2i.ONE, ""), "access_blocked", "player entrance protected")
	var candidate := _item("new", Vector2i(1, 1), 0)
	var result: Dictionary = rules.evaluate(layout, candidate, Vector2i.ONE, "")
	check_code(result, "ok", "side cell preserves corridor")
	result["cells"].clear()
	check(rules.evaluate(layout, candidate, Vector2i.ONE, "")["cells"].size() == 1, "returned cells are isolated")
	check(candidate["cell"] == Vector2i(1, 1), "candidate is not mutated")
	var diagonal := Rules.new()
	diagonal.configure(Vector2i(3, 3), [Vector2i(1, 0)], [Vector2i(2, 2)], Vector2i.ZERO, [Vector2i(1, 0)], 0)
	check_code(diagonal.evaluate(layout, _item("new", Vector2i(0, 1), 0), Vector2i.ONE, ""), "access_blocked", "diagonal gap is not a four-neighbour passage")


func _test_navigation_clearance() -> void:
	var rules := Rules.new()
	var blocked: Array[Vector2i] = [Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 5), Vector2i(3, 6)]
	var navigation: Array[Vector2i] = blocked.duplicate()
	navigation.append_array([Vector2i(3, 2), Vector2i(3, 4)])
	rules.configure(Vector2i(7, 7), blocked, [Vector2i(6, 3)], Vector2i(0, 3), navigation, 1)
	var layout: Array[Dictionary] = []
	check_code(rules.evaluate(layout, _item("new", Vector2i(3, 4), 0), Vector2i.ONE, ""), "access_blocked", "navigation mask and candidate clearance close physical gap")
	check_code(rules.evaluate(layout, _item("new", Vector2i(5, 2), 0), Vector2i.ONE, ""), "access_blocked", "diagonal clearance protects access point")
	check_code(rules.evaluate(layout, _item("new", Vector2i(1, 4), 0), Vector2i.ONE, ""), "access_blocked", "clearance protects origin")
	check_code(rules.evaluate(layout, _item("new", Vector2i(1, 0), 0), Vector2i.ONE, ""), "ok", "clearance clipped at board edge remains legal")
	var existing := _item("old", Vector2i(3, 3), 0)
	existing["footprint"] = Vector2i.ONE
	layout.append(existing)
	check_code(rules.evaluate(layout, _item("new", Vector2i(1, 0), 0), Vector2i.ONE, ""), "access_blocked", "existing furniture clearance also participates")
	check_code(rules.evaluate(layout, _item("old", Vector2i(1, 0), 0), Vector2i.ONE, "old"), "ok", "moving removes old navigation footprint")
	var adjacent := Rules.new()
	adjacent.configure(Vector2i(7, 7), [], [Vector2i(0, 6)], Vector2i.ZERO, [], 1)
	existing["cell"] = Vector2i(4, 3)
	check_code(adjacent.evaluate(layout, _item("new", Vector2i(5, 3), 0), Vector2i.ONE, ""), "ok", "navigation clearance is not a furniture overlap margin")


func _test_invalid_data() -> void:
	var rules := _open_board()
	var layout: Array[Dictionary] = []
	var candidate := _item("new", Vector2i(2, 2), 0)
	check_code(Rules.new().evaluate(layout, candidate, Vector2i.ONE, ""), "invalid", "configuration required")
	check_code(rules.evaluate(layout, candidate, Vector2i.ZERO, ""), "invalid", "zero footprint rejected")
	check_code(rules.evaluate(layout, candidate, Vector2i(-1, 1), ""), "invalid", "negative footprint rejected")
	for key in ["instance_id", "definition_id", "cell", "quarter_turn"]:
		var missing: Dictionary = candidate.duplicate()
		missing.erase(key)
		check_code(rules.evaluate(layout, missing, Vector2i.ONE, ""), "invalid", "missing required field " + key)
	for bad_turn in [-1, 4, 1.5, "1"]:
		var bad: Dictionary = candidate.duplicate()
		bad["quarter_turn"] = bad_turn
		check_code(rules.evaluate(layout, bad, Vector2i.ONE, ""), "invalid", "invalid rotation " + str(bad_turn))
	var malformed: Array[Dictionary] = [{"instance_id": "broken"}]
	check_code(rules.evaluate(malformed, candidate, Vector2i.ONE, ""), "invalid", "malformed existing layout rejected")
	var old := _item("old", Vector2i(3, 3), 0)
	old["footprint"] = Vector2i.ONE
	var duplicate: Array[Dictionary] = [old, old.duplicate()]
	check_code(rules.evaluate(duplicate, candidate, Vector2i.ONE, ""), "invalid", "existing duplicate IDs rejected")


func _open_board() -> Rules:
	var rules := Rules.new()
	rules.configure(Vector2i(5, 5), [], [Vector2i(0, 4)], Vector2i.ZERO, [], 0)
	return rules


func _test_catalog_isolation() -> void:
	var source := _catalog_fixture()
	var catalog := Catalog.new(source)
	source["maximum_instances"] = 99
	source["furniture"][0]["footprint_cells"][0] = 9
	source["furniture"][0]["id"] = "changed"
	check(catalog.maximum_instances() == 2, "catalog limit is isolated from source data")
	check(catalog.furniture("furniture.test").footprint == Vector2i.ONE, "catalog footprint is isolated from source data")
	var entries := catalog.entries()
	entries.clear()
	check(catalog.has_id("furniture.test") and not catalog.has_id("changed"), "catalog entry collection is isolated")


func _test_session_transactions() -> void:
	var session := Session.new(Catalog.new(_catalog_fixture()))
	session.set_rules(_open_board())
	var first_id: String = session.next_id()
	var candidate := _item(first_id, Vector2i(2, 2), 0)
	check_code(session.preview(candidate, false), "ok", "session preview accepts a legal candidate")
	check(session.snapshot().is_empty() and session.revision() == 0, "cancel by discarding preview leaves authority unchanged")
	check(session.next_id() == first_id, "preview does not consume an instance ID")
	check_code(session.apply(_item(first_id + ".unissued", Vector2i(1, 1), 0), false, 0), "invalid", "caller cannot invent a generated instance ID")
	check_code(session.apply(candidate, false, 0), "applied", "first placement commits")
	check(session.revision() == 1 and session.snapshot().size() == 1, "apply publishes one layout and advances revision once")
	candidate["cell"] = Vector2i(4, 4)
	check(session.find(first_id)["cell"] == Vector2i(2, 2), "apply isolates caller candidate")
	var snapshot: Array[Dictionary] = session.snapshot()
	snapshot[0]["cell"] = Vector2i(3, 3)
	snapshot.clear()
	var found: Dictionary = session.find(first_id)
	found["quarter_turn"] = 3
	check(session.find(first_id)["cell"] == Vector2i(2, 2) and session.find(first_id)["quarter_turn"] == 0, "snapshots and find results cannot mutate authority")
	var second_id: String = session.next_id()
	var second := _item(second_id, Vector2i(3, 3), 0)
	check_code(session.apply(_item(second_id, Vector2i(2, 2), 0), false, 1), "occupied", "commit rechecks layout rules")
	check(session.revision() == 1 and session.next_id() == second_id, "failed rules check does not consume revision or ID")
	check_code(session.apply(second, false, 0), "stale", "outdated placement revision rejected")
	check_code(session.remove(first_id, 0), "stale", "outdated removal revision rejected")
	check(session.revision() == 1 and session.snapshot().size() == 1, "stale commands leave authority unchanged")
	check_code(session.apply(_item(first_id, Vector2i(1, 1), 0), false, 1), "invalid", "duplicate instance rejected at current revision")
	check_code(session.preview({"definition_id": "furniture.test"}, true), "invalid", "malformed moving candidate rejected safely")
	var moved := _item(first_id, Vector2i(3, 2), 1)
	check_code(session.apply(moved, true, 1), "applied", "moving replaces existing instance")
	check(session.snapshot().size() == 1 and session.find(first_id)["cell"] == Vector2i(3, 2), "moving keeps one instance at new cell")
	check(session.find(first_id)["quarter_turn"] == 1 and session.find(first_id)["footprint"] == Vector2i.ONE, "moving records rotation and catalog footprint")
	check(session.revision() == 2 and session.next_id() == second_id, "moving advances revision without consuming an ID")
	check_code(session.apply(_item("missing", Vector2i(2, 2), 0), true, 2), "invalid", "moving nonexistent instance rejected")
	var swapped := _item(first_id, Vector2i(1, 1), 0)
	swapped["definition_id"] = "furniture.other"
	check_code(session.apply(swapped, true, 2), "invalid", "moving cannot swap furniture definitions")
	check_code(session.remove(first_id, 2), "removed", "remove commits at current revision")
	check(session.snapshot().is_empty() and session.revision() == 3, "remove publishes empty layout and advances revision")
	check(session.next_id() == second_id and second_id != first_id, "remove never rewinds generated instance IDs")
	check_code(session.apply(_item(first_id, Vector2i(1, 1), 0), false, 3), "invalid", "removed instance ID cannot be manually reused")
	check_code(session.apply(second, false, 3), "applied", "new placement uses next unused ID after removal")
	var third_id: String = session.next_id()
	check_code(session.apply(_item(third_id, Vector2i(1, 1), 0), false, 4), "applied", "placement reaches configured instance limit")
	var over_limit := _item(session.next_id(), Vector2i(4, 4), 0)
	check_code(session.preview(over_limit, false), "limit", "limit rejects preview")
	check_code(session.apply(over_limit, false, 5), "limit", "limit also rejects authoritative commit")
	check(session.revision() == 5 and session.snapshot().size() == 2, "limit rejection leaves authority unchanged")
	check_code(session.apply(_item(second_id, Vector2i(3, 2), 0), true, 5), "applied", "moving remains available at instance limit")
	check(session.revision() == 6 and session.snapshot().size() == 2, "moving at limit does not add an instance")


func _catalog_fixture() -> Dictionary:
	return {
		"grid_size_m": 1.0,
		"maximum_instances": 2,
		"furniture": [
			{"id": "furniture.test", "name_key": "test.name", "asset_id": "test.asset", "footprint_cells": [1, 1]},
			{"id": "furniture.other", "name_key": "other.name", "asset_id": "other.asset", "footprint_cells": [2, 1]},
		],
	}


func _item(instance_id: String, cell: Vector2i, quarter_turn: int) -> Dictionary:
	return {"instance_id": instance_id, "definition_id": "furniture.test", "cell": cell, "quarter_turn": quarter_turn}


func check_code(result: Dictionary, expected: String, message: String) -> void:
	check(result["code"] == expected and result["ok"] == (expected in ["ok", "applied", "removed"]), message + ": " + str(result))


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
