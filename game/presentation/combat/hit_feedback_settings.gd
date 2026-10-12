extends Resource
@export var flash_material: Material
@export var flash_sec: float
@export var hit_particles: PackedScene
@export var bar_material: ShaderMaterial
@export var bar_size: Vector2
@export var bar_height: float
@export var bar_delay_sec: float
@export var bar_drain_ratio_per_sec: float
## 满血时不显示血条，受伤后才出现；画面更干净
@export var bar_hide_when_full := false
