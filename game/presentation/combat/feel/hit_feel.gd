extends Resource
## 一次命中的手感：顿帧、镜头沿击打方向的冲击、屏幕高频抖动。纯表现参数。
## 顿帧会压缩战斗逻辑时间（见 combat_feel_style.gd 的 hitstop_time_scale），不改伤害和判定。
@export var hitstop_sec: float
@export var kick_m: float
@export var jitter_m: float
