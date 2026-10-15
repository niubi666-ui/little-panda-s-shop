extends Resource
## 屏幕下方生命条的样式（presentation/combat/vitals_hud.gd 读取）。尺寸单位为像素。
@export_group("布局")
@export var bar_size: Vector2
@export var bottom_margin: float
## 外框比生命条大出多少
@export var frame_padding: float
@export var frame_radius: int
@export var frame_border: int
@export var bar_radius: int
@export var shadow_offset: Vector2
@export var shadow_color: Color
## 填充的最小宽度：快死时也能看见一点
@export var min_fill_px: float
## 顶部高光条：相对填充的内缩与高度、颜色
@export var highlight_inset: Vector2
@export var highlight_height: float
@export var highlight_color: Color
@export_group("颜色")
@export var health_color: Color
@export var low_color: Color
@export var trail_color: Color
@export var frame_color: Color
@export var back_color: Color
@export_group("掉血")
## 低于这个生命比例算“低血量”：条变红并脉动，屏幕四周也开始压暗
@export var low_health_ratio: float
@export var low_pulse_speed: float
@export var low_pulse_whiten: float
## 刚掉血时整条闪白的强度与衰减速度（每秒）
@export var damage_flash_whiten: float
@export var damage_flash_decay: float
## 白色残影条停多久再追上、追的速度（每秒占满条的比例）
@export var trail_delay_sec: float
@export var trail_speed: float
@export_group("文字")
@export var font_size: int
@export var outline_size: int
@export var outline_color: Color
@export var text_color: Color
## 文字基线离条底边的距离
@export var text_baseline_inset: float
@export_group("闪避格与技能格")
## 条下方一行小格离条的距离
@export var row_gap: float
@export var pip_size: Vector2
@export var pip_gap: float
@export var pip_radius: int
@export var pip_color: Color
## 正在回充那一格的不透明度
@export var pip_charging_alpha: float
@export var skill_size: Vector2
@export var skill_color: Color
@export var skill_charging_alpha: float
@export var skill_label_font_size: int
@export var skill_label_color: Color
## 技能键位文字与技能格之间的间距
@export var skill_label_gap: float
