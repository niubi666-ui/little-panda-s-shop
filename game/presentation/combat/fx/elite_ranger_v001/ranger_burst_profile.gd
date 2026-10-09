extends Resource
@export var duration_sec: float
@export var flash_material: ShaderMaterial
@export var flash_size_m: float
@export var flash_sec: float
@export var flash_lift_m: float
@export var ring_material: ShaderMaterial
@export var ring_radius_m: float
@export var ring_sec: float
@export var ring_ground: bool
@export var spark_material: Material
@export var spark_count_per_point: int
@export var spark_size: Vector2
@export var spark_speed: Vector2
@export var spark_life: Vector2
@export var spark_gravity: float
@export var debris_mesh: Mesh
@export var debris_material: Material
@export var debris_count_per_point: int
@export var debris_size: Vector2
@export var debris_speed: Vector2
@export var debris_life: Vector2
@export var debris_gravity: float
@export var dust_material: ShaderMaterial
@export var dust_count_per_point: int
@export var dust_size: Vector2
@export var dust_life: Vector2
@export var dust_rise_mps: float
@export var ground_height_m: float
@export var light_color: Color
@export var light_energy: float
@export var light_radius_m: float
@export var light_sec: float

func valid() -> bool:
	for resource in [flash_material,ring_material,spark_material,dust_material,debris_mesh,debris_material]:
		if resource == null: return false
	for value in [duration_sec,flash_sec,ring_sec,flash_size_m,ring_radius_m,ground_height_m,light_radius_m,light_sec]:
		if not is_finite(value) or value <= 0.0: return false
	for range_value in [spark_size,spark_speed,spark_life,debris_size,debris_speed,debris_life,dust_size,dust_life]:
		if range_value.x <= 0.0 or range_value.y < range_value.x or not range_value.is_finite(): return false
	return spark_count_per_point >= 0 and debris_count_per_point >= 0 and dust_count_per_point >= 0 and duration_sec >= maxf(spark_life.y,maxf(debris_life.y,dust_life.y))
