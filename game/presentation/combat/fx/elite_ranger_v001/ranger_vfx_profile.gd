extends Resource
## Presentation tuning only. Attack count, radius, speed and timing come from combat.
@export var arrow_scene: PackedScene
@export var arrow_head_width_ratio: float
@export var trail_material: ShaderMaterial
@export var halo_material: ShaderMaterial
@export var filament_material: ShaderMaterial
@export var tip_material: ShaderMaterial
@export var trail_spark_material: Material
@export var trail_spark_count: int
@export var trail_spark_size: Vector2
@export var trail_lifetime_sec: float
@export var trail_width_m: float
@export var halo_width_ratio: float
@export var filament_width_m: float
@export var filament_amplitude_m: float
@export var filament_frequency: float
@export var filament_flow: float
@export var tip_size_m: float
@export var arrow_light_color: Color
@export var arrow_light_energy: float
@export var arrow_light_radius_m: float
@export var rain_height_ratio: Vector2
@export var rain_fall_window_ratio: Vector2
@export var rain_trail_width_ratio: float
@export var rain_tip_size_ratio: float
@export var rain_radius_ratio: float
@export var rain_embed_m: float
@export var rain_finish_sec: float
@export var rain_fall_curve: Curve
@export var visual_seed: int
@export var launch_burst: Resource
@export var arrow_impact: Resource
@export var rain_impact: Resource

func valid() -> bool:
	for resource in [arrow_scene,trail_material,halo_material,filament_material,tip_material,trail_spark_material,rain_fall_curve,launch_burst,arrow_impact,rain_impact]:
		if resource == null: return false
	for burst in [launch_burst,arrow_impact,rain_impact]:
		if not burst.valid(): return false
	for value in [arrow_head_width_ratio,trail_lifetime_sec,trail_width_m,halo_width_ratio,filament_width_m,tip_size_m,rain_finish_sec,rain_trail_width_ratio,rain_tip_size_ratio]:
		if not is_finite(value) or value <= 0.0: return false
	for range_value in [rain_fall_window_ratio,rain_height_ratio,trail_spark_size]:
		if range_value.x <= 0.0 or range_value.y < range_value.x or not range_value.is_finite(): return false
	return trail_spark_count > 0 and rain_radius_ratio > 0.0 and rain_radius_ratio < 1.0
