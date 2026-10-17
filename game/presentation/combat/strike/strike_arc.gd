extends Resource
## 一种出招的刀光形状（strike_style.tres 的 arcs 里按技能 ID 引用）。纯表现，不影响判定。
## 角度以出招方向为 0，俯视逆时针为正（与 attack_motions 的 yaw 相同）。
@export_enum("arc", "thrust") var kind: String
## arc：外缘半径；thrust：刺出的长度（米）
@export var radius_m: float
## arc：月牙带宽；thrust：宽度（米）
@export var thickness_m: float
## arc：从哪个角度扫到哪个角度（度）；thrust 不用
@export var start_deg: float
@export var end_deg: float
## 离地高度（米）
@export var height_m: float
## 扫出用时、扫完后停留、消散用时（秒，按战斗时间走：顿帧时也会停住）
@export var reveal_sec: float
@export var hold_sec: float
@export var fade_sec: float
## 网格细分段数
@export var segments: int
