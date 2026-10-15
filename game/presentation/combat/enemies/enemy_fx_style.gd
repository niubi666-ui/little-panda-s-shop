extends Resource
@export var line_color: Color
@export var charge_color: Color
@export var aura_color: Color
@export var projectile_color: Color
@export var line_width: float
@export var ground_height: float
@export var aura_width: float
@export var recipient_radius_scale: float
@export var white_emission: float
@export var projectile_emission: float
@export var spear_pullback_m: float
@export_group("预警材质")
## 弩手射线与冲锋通道的预警材质（fx/telegraph.gdshader）；每个敌人复制一份，颜色取上面的 line_color / charge_color
@export var ranged_lane_material: ShaderMaterial
@export var charge_lane_material: ShaderMaterial
## 精英游侠的箭道预警（颜色取 ranger_style.tres）
@export var arrow_lane_material: ShaderMaterial
## 地面圆环（旗手光环、受增益者、游侠箭雨圈）
@export var ring_material: ShaderMaterial
## 细环实际画的宽度 = max(配置宽度 × ring_band_scale, ring_min_band_m)，再靠柔边收窄，远看不碎
@export var ring_band_scale: float
@export var ring_min_band_m: float
