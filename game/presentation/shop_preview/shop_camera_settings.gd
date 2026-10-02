extends Resource
## Camera presentation only; authored in a .tres, independent of movement rules.
@export var initial_size: float
@export var minimum_size: float
@export var maximum_size: float
@export var zoom_step: float
@export var zoom_response: float
@export var follow_response: float
@export var focus_height: float
@export var focus_bounds: Rect2
@export var camera_distance: float

func is_valid() -> bool:
	return minimum_size > 0 and maximum_size >= minimum_size and initial_size >= minimum_size and initial_size <= maximum_size and zoom_step > 0 and zoom_response > 0 and follow_response > 0 and camera_distance > 0 and focus_bounds.has_area()
