extends RefCounted
## Validated, immutable definitions. No runtime JSON lookups.
var rules: Dictionary
var _props: Dictionary = {}
var _items: Dictionary = {}
static func frozen(value: Variant) -> Variant:
	if value is Dictionary:
		var copy: Dictionary = {}
		for key in value: copy[key] = frozen(value[key])
		copy.make_read_only()
		return copy
	if value is Array:
		var copy: Array = []
		for entry in value: copy.append(frozen(entry))
		copy.make_read_only()
		return copy
	return value
func _init(data: Dictionary) -> void:
	rules = frozen(data)
	for entry in rules.props: _props[entry.id] = entry
	for entry in rules.loot_items: _items[entry.id] = entry
func prop(id: String) -> Dictionary:
	assert(_props.has(id))
	return _props[id]
func item(id: String) -> Dictionary:
	assert(_items.has(id))
	return _items[id]
