extends RefCounted
## A route/room plan is a value, without live progress or scene objects.
static func freeze_copy(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = freeze_copy(value[key])
		result.make_read_only()
		return result
	if value is Array:
		var result: Array = []
		for child in value: result.append(freeze_copy(child))
		result.make_read_only()
		return result
	return value
