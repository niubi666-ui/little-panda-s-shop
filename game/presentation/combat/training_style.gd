extends Resource
@export var actor_presentations: Dictionary
@export var animation_blend_sec: float
@export var warning_color: Color
@export var strike_color: Color
@export var sector_height: float
@export var blade_size: Vector3
@export var blade_offset: Vector3
## Authored sword-tip placement, independent of gameplay hit radius.
@export var weapon_tip_radius_by_ability: Dictionary
@export var attack_motions: Dictionary[String, Resource]
## Presentation group -> ability ID -> strong motion resource key.
@export var attack_motion_groups: Dictionary
@export var hit_camera_shake: Resource
@export var camera_offset: Vector3
@export var camera_size: float
@export var camera_min_size: float
@export var camera_max_size: float
@export var camera_zoom_step: float
## 是否在玩家头顶显示“当前/最大生命”文字；有屏幕生命条时关掉
@export var player_health_label: bool
@export var health_label_height: float
@export var health_font_size: int
@export var hud_margin: int
@export var training_entry_position: Vector2
@export var hit_feedback: Resource
@export var damage_numbers: Resource
@export var weapon_effect_scene: PackedScene
@export var weapon_visual_scene: PackedScene
@export var health_label_pixel_size: float
@export var encounter_panel_position: Vector2
## 打击感：顿帧、镜头冲击、跟随（feel/combat_feel_style.gd）
@export var combat_feel: Resource
## 生命条、受伤闪红、击杀花瓣、闪避尘土（combat_juice_style.gd）
@export var combat_juice: Resource
## 玩家攻击扇形预警的材质模板（fx/telegraph.gdshader）；每个角色复制一份
@export var sector_material: ShaderMaterial
