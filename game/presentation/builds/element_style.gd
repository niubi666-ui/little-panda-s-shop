extends Resource
## 元素表现配置（element_view.gd 读取）。全部是占位特效，换成正式美术只需替换这里引用的场景/材质。
@export_group("元素")
## 元素 ID → 颜色（命中闪光、电弧、反应文字等用）
@export var element_colors: Dictionary
## 元素 ID → 挂在敌人身上的循环粒子（presentation/builds/elements/status_*.tscn）
@export var status_scenes: Dictionary
## 状态特效离脚底的高度；每多一层放大多少
@export var status_height_m: float
@export var status_scale_per_stack: float
## 挂上元素一瞬间的火花（颜色按元素）和闪光
@export var apply_burst: PackedScene
@export var apply_flash_energy: float
@export var apply_flash_range_m: float
@export_group("敌人身上的元素标记")
## 身体染色强度：挂上 1 层时、每多一层增加多少（0..1）
@export var tint_base: float
@export var tint_per_stack: float
## 元素名与层数（例如“火 ×3”）：显示在脚下光环靠镜头的一侧，离地高度与向镜头方向的偏移
@export var badge_toward_camera_m: float
@export var badge_height_m: float
@export var badge_font_size: int
@export var badge_outline: Color
## 脚下的元素光环（status_ring.gdshader）
@export var under_ring_material: ShaderMaterial
@export var under_ring_radius_m: float
@export_group("反应")
## 反应 ID → 颜色
@export var reaction_colors: Dictionary
@export var reaction_burst: PackedScene
## 会冒烟/蒸汽的反应 ID 与其烟雾场景
@export var smoke_reactions: PackedStringArray
@export var reaction_smoke: PackedScene
## 吸附型反应（磁暴）的向内粒子
@export var pull_burst: PackedScene
@export var burst_height_m: float
## 贴地冲击波光环（shock_ring.gdshader）；单体反应用 ring_min_radius_m 作为半径
@export var ring_material: ShaderMaterial
@export var ring_sec: float
@export var ring_min_radius_m: float
## 反应瞬间的闪光
@export var flash_energy: float
@export var flash_range_m: float
@export var flash_sec: float
@export_group("反应文字")
@export var label_font_size: int
@export var label_outline: Color
@export var label_height_m: float
@export var label_rise_m: float
@export var label_sec: float
@export_group("熔岩区域")
@export var zone_material: ShaderMaterial
@export var zone_embers: PackedScene
@export var zone_fade_sec: float
@export_group("电弧")
@export var arc_width_m: float
@export var arc_segment_m: float
@export var arc_jitter_m: float
@export var arc_sec: float
@export var arc_height_m: float
