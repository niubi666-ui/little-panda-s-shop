extends Resource
const Visual = preload("res://presentation/rooms/props/prop_visual.gd")
@export var entries: Array[Resource]
@export var compositions: Array[Resource]
func composition(id: String) -> Resource:
	for entry in compositions:
		if entry.id == id: return entry
	assert(false, "Missing room composition: " + id)
	return null
func visual(id: String) -> Resource:
	for entry in entries:
		if entry.id == id: return entry
	assert(false, "Missing prop visual: " + id)
	return null
