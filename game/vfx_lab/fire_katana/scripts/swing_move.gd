extends Resource
## 一招挥砍的表现参数（只管画面节奏，不含伤害）。
## 角度都在“刀尖指向目标 = 0°”的挥砍平面里量；direction_deg 决定这个平面怎么转：
## 0 = 从上往下劈，90 = 横斩，180 = 从下往上撩。

@export var display_name := "斜劈"
@export_range(-180.0, 180.0) var direction_deg := 35.0
@export var start_deg := -115.0
@export var end_deg := 95.0
@export var cock_deg := 12.0        ## 蓄力时再往后拉的角度（预兆）
@export var prepare_time := 0.38    ## 从悬浮姿态摆到起手位
@export var charge_time := 0.22     ## 蓄力：刀身升温、火星往刀上聚
@export var swing_time := 0.3       ## 挥砍（含收势）
@export var swing_power := 4.0      ## 缓出指数：越大越“前段快、后段收”
@export var recover_time := 0.45
@export var rest_time := 0.3
@export var heat_peak := 1.0
@export var intensity := 1.0        ## 刀光和受击特效的强度
@export var lunge := 0.08           ## 挥砍时整把刀往前送的距离（米）
@export var tremble := 0.0          ## 蓄力时刀身的颤动（重击用）
@export var hitstop := 0.06         ## 命中顿帧（真实秒）
@export var shake := 0.05           ## 命中镜头震动
@export var impact_scale := 1.0
