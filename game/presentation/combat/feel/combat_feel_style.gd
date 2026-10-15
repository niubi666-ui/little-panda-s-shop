extends Resource
## 打击感配置（presentation/combat/combat_feel.gd 读取）。
## 每个技能的手感按稳定技能 ID 配置；没列出的技能用 default_hit，不在代码里写技能名单。
const HitFeel = preload("res://presentation/combat/feel/hit_feel.gd")

@export_group("命中")
@export var default_hit: HitFeel
## 技能 ID → HitFeel
@export var ability_hits: Dictionary
## 击杀时与技能手感取较大值
@export var kill_hit: HitFeel
## 玩家受击
@export var player_hurt: HitFeel
## 顿帧期间战斗时间不是完全静止，按这个比例继续流动，避免卡顿感
@export var hitstop_time_scale: float

@export_group("镜头冲击")
## 多次冲击累加的上限（米）
@export var kick_limit_m: float
## 冲击从出现到归零的时长；结束后镜头精确回到原位
@export var kick_duration_sec: float
@export var jitter_duration_sec: float
## 屏幕抖动在横、竖两个方向的频率（赫兹）
@export var jitter_frequency_hz: Vector2

@export_group("跟随")
## 镜头跟随的阻尼（越大越紧）
@export var follow_sharpness: float
## 朝移动方向的前瞻距离（米）
@export var look_ahead_m: float
@export var look_ahead_sharpness: float
