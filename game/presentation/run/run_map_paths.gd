extends Control
## Decorative connection lines; never decides legal next nodes.
const Style = preload("res://presentation/run/run_map_style.tres")
var _paths: Array[Dictionary] = []


func set_paths(paths: Array[Dictionary]) -> void:
	_paths = paths.duplicate(true)
	queue_redraw()


func _draw() -> void:
	for path in _paths:
		var color: Color = Style.locked_line
		if path.state == "completed": color = Style.completed_line
		elif path.state == "available": color = Style.available_line
		draw_line(path.from, path.to, color, Style.line_width, true)
