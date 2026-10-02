extends Resource
## Geometry, materials and effect clocks never enter combat calculations.
@export var projectile_mesh: Mesh
@export var projectile_material: Material
@export var projectile_size_per_radius: Vector3
@export var projectile_height: float
@export var chain_material: StandardMaterial3D
@export var chain_height: float
@export var chain_lifetime_sec: float

@export var projectile_mesh_overrides: Dictionary[String, Mesh] = {}
