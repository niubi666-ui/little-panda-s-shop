extends Resource
## Presentation-only options; these dimensions never define combat hit shapes.
@export var effects: Dictionary[StringName, PackedScene]
@export var name_keys: Dictionary[StringName, String]
@export var max_instances: int
@export var forward_offset_m: float
@export var ground_offset_m: float
@export var panel_width: float
@export var option_columns: int
@export var bottom_margin: float
@export var right_margin: float
@export var center_bottom_margin: float
@export var header_height: float
@export var header_action_width: float
@export var padding: int
@export var row_gap: int
@export var title_font_size: int
@export var body_font_size: int
@export var hint_font_size: int
@export var button_height: float
@export var panel_style: StyleBox
@export var option_colors: Dictionary[StringName, Color]

func valid() -> bool:
	if effects.is_empty() or max_instances <= 0 or option_columns <= 0: return false
	if panel_width <= 0.0 or bottom_margin < 0.0 or right_margin < 0.0 or padding < 0 or row_gap < 0: return false
	if center_bottom_margin < 0.0 or header_height <= 0.0 or header_action_width <= 0.0: return false
	if title_font_size <= 0 or body_font_size <= 0 or hint_font_size <= 0 or button_height <= 0.0: return false
	if panel_style == null or not is_finite(forward_offset_m) or not is_finite(ground_offset_m): return false
	for id in effects:
		if effects[id] == null or not name_keys.has(id) or name_keys[id].is_empty(): return false
		if not option_colors.has(id): return false
	return true
