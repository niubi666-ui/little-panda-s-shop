extends Resource
@export var material: ShaderMaterial
@export var interval_sec: float
@export var lifetime_sec: float
@export var minimum_distance_m: float
@export var max_images: int
func valid() -> bool:
	return material!=null and interval_sec>0.0 and lifetime_sec>interval_sec and minimum_distance_m>0.0 and max_images>0
