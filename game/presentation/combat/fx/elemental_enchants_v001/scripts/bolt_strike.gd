extends Node3D
## 雷受击：一道落雷从上方劈到命中点（中途再闪两次、每次换一条路径），
## 之后一小段时间里电弧在命中点周围爬动，并有一两条窜到地面。

@export var strands: Node3D      ## lightning_strands.gd
@export var sky_height := 3.0
@export var main_width := 0.05
@export var restrikes: PackedFloat32Array = [0.0, 0.05, 0.11]
@export var crawl_time := 0.45
@export var crawl_interval := 0.03
@export var crawl_radius := 0.25

var _t := -1.0
var _next_strike := 0
var _crawl_clock := 0.0
var _sky := Vector3.ZERO


func play() -> void:
	_t = 0.0
	_next_strike = 0
	_crawl_clock = 0.0
	_sky = global_position + Vector3(randf_range(-0.6, 0.6), sky_height, randf_range(-0.6, 0.6))


func tick(delta: float) -> void:
	if _t < 0.0:
		strands.update(delta)
		return
	_t += delta
	var at := global_position
	while _next_strike < restrikes.size() and _t >= restrikes[_next_strike]:
		var w := main_width * (1.0 if _next_strike == 0 else 0.75)
		strands.add_bolt(_sky, at, 0.07, w, 0.18, 3, 1.4, 6)
		_next_strike += 1
	_crawl_clock -= delta
	if _t < crawl_time and _crawl_clock <= 0.0:
		_crawl_clock = crawl_interval
		for i in 2:
			var a := at + _around()
			var b := at + _around()
			strands.add_bolt(a, b, randf_range(0.04, 0.08), 0.012, 0.35, 0, 0.9)
		if randf() < 0.3:
			var ground := Vector3(at.x + randf_range(-0.5, 0.5), 0.02, at.z + randf_range(-0.5, 0.5))
			strands.add_bolt(at, ground, 0.06, 0.018, 0.25, 1, 1.0)
	strands.update(delta)
	if _t > crawl_time + 0.3:
		_t = -1.0


func _around() -> Vector3:
	return Vector3(randf_range(-1, 1), randf_range(-1, 1.4), randf_range(-1, 1)).normalized() * randf_range(0.05, crawl_radius)
