extends RefCounted
class Furniture extends RefCounted:
	var _id: String
	var _name_key: String
	var _asset_id: String
	var _footprint: Vector2i
	func _init(data: Dictionary) -> void:
		_id = data.id
		_name_key = data.name_key
		_asset_id = data.asset_id
		_footprint = Vector2i(int(data.footprint_cells[0]), int(data.footprint_cells[1]))
	var id: String:
		get: return _id
	var name_key: String:
		get: return _name_key
	var asset_id: String:
		get: return _asset_id
	var footprint: Vector2i:
		get: return _footprint
var _grid: float
var _limit: int
var _entries: Dictionary = {}
func _init(data: Dictionary) -> void:
	_grid = data.grid_size_m
	_limit = int(data.maximum_instances)
	for item in data.furniture: _entries[item.id] = Furniture.new(item)
	_entries.make_read_only()
func grid_size() -> float: return _grid
func maximum_instances() -> int: return _limit
func entries() -> Array: return _entries.values()
func has_id(id: String) -> bool: return _entries.has(id)
func furniture(id: String) -> Furniture: return _entries[id]
