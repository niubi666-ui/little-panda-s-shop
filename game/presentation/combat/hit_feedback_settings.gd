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
@export var bar_hide_when_full: bool
## 受击时身体沿击退方向猛地一晃再弹回：最大位移（米）、全程时长、到达最大位移所占比例
@export var lurch_m: float
@export var lurch_sec: float
@export var lurch_peak_fraction: float
