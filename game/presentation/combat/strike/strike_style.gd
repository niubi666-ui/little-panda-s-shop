extends Resource
## 打击表现（strike_view.gd 读取）：白色月牙刀光、命中尖刺、重击/击杀爆团。纯表现，所有数值在 strike_style.tres。
@export_group("刀光")
## 技能 ID → StrikeArc（strike_arc.gd）；没列出的技能不出刀光
@export var arcs: Dictionary
@export var arc_material: ShaderMaterial
## 带元素出招时，月牙内缘烟雾染上元素色的程度（0..1）
@export var element_tint: float
## 元素颜色来源（element_style.tres）
@export var element_style: Resource
@export_group("命中尖刺")
@export var star_material: ShaderMaterial
@export var star_size_m: float
@export var star_sec: float
@export var star_height_m: float
@export_group("爆团")
## 这些技能命中时出爆团；击杀一定出
@export var burst_abilities: PackedStringArray
@export var burst_material: ShaderMaterial
@export var burst_size_m: float
@export var kill_burst_size_m: float
@export var burst_sec: float
