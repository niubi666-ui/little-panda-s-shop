extends Resource
## 一局冒险界面的样式（run_exit_panel.gd 读取）：选出口、结算、房间信息条。
@export_group("选出口")
@export var dim_color: Color
@export var card_size: Vector2
@export var card_gap: float
@export var card_radius: int
@export var card_border: int
@export var card_back: Color
@export var title_font_size: int
@export var card_title_font_size: int
@export var card_detail_font_size: int
@export var text_color: Color
@export var detail_color: Color
## 奖励类型 → 卡片主色；元素祝福的颜色取元素颜色（element_style.tres）
@export var reward_colors: Dictionary
@export var element_style: Resource
@export var disabled_tint: Color
@export_group("房间信息条")
@export var info_font_size: int
@export var info_top_margin: float
@export var info_color: Color
