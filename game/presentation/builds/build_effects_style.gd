extends Resource
@export var enabled: bool
## An explicit null entry disables that slot; absent entries use authored mesh fallback.
@export var projectile_scenes: Dictionary[String, PackedScene] = {}
## Ordered presentation variants, selected once from the committed projectile fact.
## Each rule has definition_id, required_effect_id, scene. Explicit null base slots stay disabled.
@export var projectile_scene_rules: Array[Dictionary] = []
@export var trail_scenes: Dictionary[String, PackedScene] = {}
@export var contact_scenes: Dictionary[String, PackedScene] = {}
@export var termination_scenes: Dictionary[String, PackedScene] = {}
@export var action_scenes: Dictionary[String, PackedScene] = {}
@export var event_lifetime_sec: float
## Geometry, materials and effect clocks never enter combat calculations.
@export var projectile_mesh: Mesh
@export var projectile_material: Material
@export var projectile_size_per_radius: Vector3
@export var projectile_height: float
@export var chain_material: StandardMaterial3D
@export var chain_height: float
@export var chain_lifetime_sec: float

@export var projectile_mesh_overrides: Dictionary[String, Mesh] = {}
