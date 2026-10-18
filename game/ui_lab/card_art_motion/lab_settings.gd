extends Resource
## Lab-only presentation and localized controls. No gameplay reward definitions.
@export var default_locale: String
@export var locales: PackedStringArray
@export var translations: Dictionary
@export var groups: Array[Dictionary]
@export var catalog_groups: Array[Dictionary]
@export var actions: PackedStringArray
@export var starting_motion_enabled: bool
@export var starting_intensity: float
@export var max_intensity: float
@export var intensity_step: float
@export var toolbar_margin: Vector2
@export var toolbar_gap: int
@export var control_height: float
@export var font_size: int
@export var slider_width: float
@export var status_height: float
@export var status_color: Color
@export var background: Texture2D
@export var demo_duration: float
@export var demo_events: Array[Dictionary]
@export var catalog_demo_page_sec: float
