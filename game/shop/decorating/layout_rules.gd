extends RefCounted
## Integer-grid furniture placement rules. Rendering and persistent state live elsewhere.

const NEIGHBOURS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
]

var _board_size := Vector2i.ZERO
var _blocked: Dictionary = {}
var _navigation_blocked: Dictionary = {}
var _required_access: Array[Vector2i] = []
var _origin := Vector2i.ZERO
var _clearance := 0
var _configured := false


func configure(
	board_size: Vector2i,
	blocked_cells: Array[Vector2i],
	required_access: Array[Vector2i],
	origin_cell: Vector2i,
	navigation_blocked_cells: Array[Vector2i],
	clearance_cells: int
) -> void:
	_configured = false
	_board_size = board_size
	_origin = origin_cell
	_clearance = clearance_cells
	_blocked.clear()
	_navigation_blocked.clear()
	_required_access.clear()
	if board_size.x <= 0 or board_size.y <= 0 or not _inside(origin_cell) or clearance_cells < 0:
		push_error("Furniture layout requires a positive board, an in-bounds origin and nonnegative clearance.")
		return
	for cell in blocked_cells:
		if not _inside(cell):
			push_error("Furniture layout blocked cell is outside the board: %s" % cell)
			return
		_blocked[cell] = true
	for cell in navigation_blocked_cells:
		if not _inside(cell):
			push_error("Furniture navigation blocked cell is outside the board: %s" % cell)
			return
		_navigation_blocked[cell] = true
	for cell in required_access:
		if not _inside(cell) or _blocked.has(cell) or _navigation_blocked.has(cell):
			push_error("Furniture layout access cell is outside the board or blocked: %s" % cell)
			return
		if not _required_access.has(cell):
			_required_access.append(cell)
	if _blocked.has(_origin) or _navigation_blocked.has(_origin):
		push_error("Furniture layout origin is blocked.")
		return
	_configured = true


func evaluate(
	layout: Array[Dictionary],
	candidate: Dictionary,
	footprint: Vector2i,
	ignore_instance_id: String
) -> Dictionary:
	var empty: Array[Vector2i] = []
	if not _configured or not _valid_entry(candidate, false) or not _valid_size(footprint):
		return _result("invalid", empty)
	# Repositioning may only ignore the instance being repositioned.
	if not ignore_instance_id.is_empty() and ignore_instance_id != candidate["instance_id"]:
		return _result("invalid", empty)
	var cells := occupied_cells(candidate["cell"], footprint, candidate["quarter_turn"])
	var occupied: Dictionary = {}
	var instance_ids: Dictionary = {}
	for entry in layout:
		if not _valid_entry(entry, true) or instance_ids.has(entry["instance_id"]):
			return _result("invalid", cells)
		instance_ids[entry["instance_id"]] = true
		if entry["instance_id"] == ignore_instance_id:
			continue
		for cell in occupied_cells(entry["cell"], entry["footprint"], entry["quarter_turn"]):
			if not _inside(cell) or _blocked.has(cell) or occupied.has(cell):
				return _result("invalid", cells)
			occupied[cell] = true
	# Duplicate stable IDs are not a second piece of furniture.
	if instance_ids.has(candidate["instance_id"]) and ignore_instance_id.is_empty():
		return _result("invalid", cells)
	for cell in cells:
		if not _inside(cell):
			return _result("out_of_bounds", cells)
	for cell in cells:
		if _blocked.has(cell):
			return _result("blocked", cells)
		if occupied.has(cell):
			return _result("occupied", cells)
	var unavailable: Dictionary = _navigation_blocked.duplicate()
	for cell in occupied:
		_add_navigation_footprint(unavailable, cell)
	for cell in cells:
		_add_navigation_footprint(unavailable, cell)
	if not _access_reachable(unavailable):
		return _result("access_blocked", cells)
	return _result("ok", cells)


func occupied_cells(cell: Vector2i, footprint: Vector2i, quarter_turn: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _valid_size(footprint) or quarter_turn < 0 or quarter_turn >= 4:
		return result
	var size := footprint
	if quarter_turn % 2 != 0:
		size = Vector2i(footprint.y, footprint.x)
	for y in range(size.y):
		for x in range(size.x):
			result.append(cell + Vector2i(x, y))
	return result


func _valid_entry(entry: Dictionary, require_footprint: bool) -> bool:
	for key in ["instance_id", "definition_id", "cell", "quarter_turn"]:
		if not entry.has(key):
			return false
	for key in ["instance_id", "definition_id"]:
		if typeof(entry[key]) != TYPE_STRING or String(entry[key]).is_empty():
			return false
	if typeof(entry["cell"]) != TYPE_VECTOR2I or typeof(entry["quarter_turn"]) != TYPE_INT:
		return false
	if entry["quarter_turn"] < 0 or entry["quarter_turn"] >= 4:
		return false
	if require_footprint:
		if not entry.has("footprint") or typeof(entry["footprint"]) != TYPE_VECTOR2I:
			return false
		if not _valid_size(entry["footprint"]):
			return false
	return true


func _valid_size(value: Vector2i) -> bool:
	return value.x > 0 and value.y > 0


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _board_size.x and cell.y < _board_size.y


func _add_navigation_footprint(unavailable: Dictionary, cell: Vector2i) -> void:
	# Chebyshev expansion reserves actor clearance on all eight sides, including corners.
	for y in range(-_clearance, _clearance + 1):
		for x in range(-_clearance, _clearance + 1):
			var expanded := cell + Vector2i(x, y)
			if _inside(expanded):
				unavailable[expanded] = true


func _access_reachable(unavailable: Dictionary) -> bool:
	if unavailable.has(_origin):
		return false
	for cell in _required_access:
		if unavailable.has(cell):
			return false
	var visited: Dictionary = {_origin: true}
	var queue: Array[Vector2i] = [_origin]
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		for direction in NEIGHBOURS:
			var next := current + direction
			if not _inside(next) or unavailable.has(next) or visited.has(next):
				continue
			visited[next] = true
			queue.append(next)
	for cell in _required_access:
		if not visited.has(cell):
			return false
	return true


func _result(code: String, cells: Array[Vector2i]) -> Dictionary:
	return {"ok": code == "ok", "code": code, "cells": cells.duplicate()}
