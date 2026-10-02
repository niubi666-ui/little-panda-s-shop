extends Resource
@export var placement_surface: Resource
@export var prop_visuals: Resource
## Scene-level room presentation. Future room selection injects this resource.
@export var template_id: StringName
@export var scene: PackedScene
@export var camera_offset: Vector3
@export var camera_target_offset: Vector3
@export var camera_size: float
@export var camera_min_size: float
@export var camera_max_size: float
@export var camera_zoom_step: float
@export var camera_follow_bounds: Rect2
@export var temporal_antialiasing: bool
