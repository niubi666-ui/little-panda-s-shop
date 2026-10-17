extends Resource
## 演示场景的一套光照（白天 / 夜晚），用来检查特效在亮暗背景下是否都看得清。

@export var display_name := "夜晚"
@export var environment: Environment
@export var sun_color := Color.WHITE
@export var sun_energy := 1.0
@export var sun_rotation_deg := Vector3(-45.0, 30.0, 0.0)
