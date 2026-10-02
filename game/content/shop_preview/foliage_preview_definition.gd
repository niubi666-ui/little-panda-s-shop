extends RefCounted
## Read-only UI sample catalog, deliberately separate from owned inventory or orders.
var _sections: Dictionary

func _init(data: Dictionary) -> void:
	_sections = data.duplicate(true)
	for section: String in ["inventory", "orders", "decoration"]:
		for entry: Dictionary in _sections[section]:
			entry.make_read_only()
		_sections[section].make_read_only()
	_sections.make_read_only()

func entries(section: String) -> Array:
	assert(section in ["inventory", "orders", "decoration"])
	return _sections[section]
