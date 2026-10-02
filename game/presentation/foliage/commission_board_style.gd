extends Resource
## Presentation geometry in a single design space; the entire board scales uniformly.
@export var design_size: Vector2
@export var screen_margin: Vector2
@export var board: Texture2D
@export var card: Texture2D
@export var selected: Texture2D
@export var primary_button: Texture2D
@export var secondary_button: Texture2D
@export var portraits: Dictionary
@export var regions: Dictionary
@export var card_size: Vector2
@export var card_gap: int
@export var selection_margins: Vector4
@export var heading_gap: float
@export var hover_style: StyleBox
@export var pressed_style: StyleBox
@export var disabled_style: StyleBox
