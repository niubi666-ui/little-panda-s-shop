extends Resource
## Route layout and colors only; graph size, types and progression are content rules.
@export var margin: float
@export var header_height: float
@export var footer_height: float
@export var canvas_padding: float
@export var node_size: Vector2
@export var column_pitch: float
@export var layer_pitch: float
@export var heading_font_size: int
@export var body_font_size: int
@export var node_font_size: int
@export var hint_font_size: int
@export var gap: int
@export var button_height: float
@export var restart_width: float
@export var line_width: float
@export var background: Color
@export var heading_color: Color
@export var text_color: Color
@export var muted_color: Color
@export var notice_color: Color
@export var completed_line: Color
@export var available_line: Color
@export var locked_line: Color
@export var node_styles: Dictionary[String, StyleBox]
@export var available_hover: StyleBox
@export var panel_style: StyleBox
@export var room_width: float
@export var room_padding: int
@export var room_number_font_size: int
