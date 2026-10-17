extends Node3D
## 悬空太刀的挥砍：没有人握，节点原点就是“手腕”。
## 每招分五段：摆到起手位 → 蓄力（再往后拉、刀身升温）→ 挥砍（缓出，前段极快）→ 收刀回悬浮 → 停顿。
## 刀的朝向：刀身 = +Y，刃口 = +Z（朝运动方向）。

signal phase_changed(phase: String, move: Resource)
signal contact(world_pos: Vector3, tangent: Vector3, blade_dir: Vector3, out_dir: Vector3, move: Resource)
signal move_finished

@export var katana: Node3D
@export var trail_base: Node3D
@export var trail_tip: Node3D
@export var trail: Node3D
@export var blade_fx: Node3D
@export var target: Node3D
@export var target_radius := 0.11
@export var trail_substeps := 10
@export var idle_bob := 0.035
@export var heat_cooling := 0.6
## 附魔武器平时也一直在烧，热度不低于这个值
@export var heat_floor := 0.6

var _clock := 0.0
var _heat := 0.0
var _phase := "idle"
var _phase_t := 0.0
var _move: Resource
var _from_basis := Basis()
var _from_pos := Vector3.ZERO
var _cur_basis := Basis()
var _cur_pos := Vector3.ZERO
var _theta_prev := 0.0
var _contact_done := false
var _base_local := Vector3.ZERO
var _tip_local := Vector3.ZERO


func _ready() -> void:
	_base_local = trail_base.position
	_tip_local = trail_tip.position
	var idle := _idle_pose(0.0)
	_cur_basis = idle[0]
	_cur_pos = idle[1]
	_apply()


func heat() -> float:
	return _heat


func is_busy() -> bool:
	return _phase != "idle"


func play_move(move: Resource) -> void:
	_move = move
	_from_basis = _cur_basis
	_from_pos = _cur_pos
	_set_phase("prepare")
	await move_finished


# ---------- 几何 ----------

func _frame() -> Dictionary:
	var to_target := to_local(target.global_position)
	var t := to_target.normalized()
	var up := Vector3.UP
	var r := t.cross(up).normalized()
	return {"T": t, "R": r, "U": up, "D": to_target.length()}


func _motion_dir(f: Dictionary, move: Resource) -> Vector3:
	var phi := deg_to_rad(move.direction_deg)
	var m: Vector3 = -f["U"] * cos(phi) + f["R"] * sin(phi)
	return (m - f["T"] * m.dot(f["T"])).normalized()


static func _blade_basis(d: Vector3, edge: Vector3) -> Basis:
	var y := d.normalized()
	var z := (edge - y * edge.dot(y)).normalized()
	return Basis(y.cross(z), y, z)


func _swing_pose(move: Resource, theta_deg: float, lunge_k: float) -> Array:
	var f := _frame()
	var m := _motion_dir(f, move)
	var th := deg_to_rad(theta_deg)
	var t: Vector3 = f["T"]
	var d := t * cos(th) + m * sin(th)
	var e := -t * sin(th) + m * cos(th)
	var pos: Vector3 = t * move.lunge * lunge_k
	return [_blade_basis(d, e), pos]


func _idle_pose(time: float) -> Array:
	var f := _frame()
	var t: Vector3 = f["T"]
	var d: Vector3 = (f["U"] * 0.85 + t * 0.3 - f["R"] * 0.3).normalized()
	d = d.rotated(t, sin(time * 0.9) * 0.06)
	var pos := Vector3(0.0, sin(time * 1.7) * idle_bob, 0.0)
	return [_blade_basis(d, t), pos]


# ---------- 每帧 ----------

func _process(delta: float) -> void:
	_clock += delta
	if _phase == "idle":
		var idle := _idle_pose(_clock)
		_cur_basis = _cur_basis.slerp(idle[0], clampf(delta * 6.0, 0.0, 1.0))
		_cur_pos = _cur_pos.lerp(idle[1], clampf(delta * 6.0, 0.0, 1.0))
		_cool(delta)
	else:
		_step(delta)
	_apply()
	blade_fx.set_heat(_heat)
	trail.update_mesh(_clock)


func _cool(delta: float) -> void:
	_heat = maxf(heat_floor, _heat * exp(-delta / heat_cooling))


func _step(delta: float) -> void:
	var m := _move
	var prev_t := _phase_t
	_phase_t += delta
	match _phase:
		"prepare":
			var k := smoothstep(0.0, 1.0, minf(_phase_t / m.prepare_time, 1.0))
			var start := _swing_pose(m, m.start_deg, 0.0)
			_cur_basis = _from_basis.slerp(start[0], k)
			_cur_pos = _from_pos.lerp(start[1], k)
			_cool(delta)
			if _phase_t >= m.prepare_time:
				_set_phase("charge")
		"charge":
			var u := minf(_phase_t / m.charge_time, 1.0)
			var theta: float = m.start_deg - m.cock_deg * (1.0 - pow(1.0 - u, 3.0))
			var pose := _swing_pose(m, theta, -0.4 * u)
			_cur_basis = pose[0]
			_cur_pos = pose[1]
			if m.tremble > 0.0:
				var j: float = m.tremble * u
				_cur_basis = _cur_basis.rotated(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized(), j * 0.02)
			_heat = maxf(_heat, m.heat_peak * u * u)
			if _phase_t >= m.charge_time:
				_theta_prev = m.start_deg - m.cock_deg
				_contact_done = false
				trail.break_strip()
				_set_phase("strike")
		"strike":
			_heat = m.heat_peak
			var n := maxi(1, trail_substeps)
			for i in n:
				var tt := lerpf(prev_t, _phase_t, float(i + 1) / n)
				var sample_time := _clock - (_phase_t - tt)
				var pose := _strike_pose(m, tt)
				_cur_basis = pose[0]
				_cur_pos = pose[1]
				var theta: float = pose[2]
				var xf := global_transform * Transform3D(_cur_basis, _cur_pos)
				trail.add_sample(xf * _base_local, xf * _tip_local, sample_time, m.intensity)
				blade_fx.emit_arc(xf * _base_local, xf * _tip_local, m.intensity)
				if not _contact_done and _theta_prev < 0.0 and theta >= 0.0:
					_contact_done = true
					_emit_contact(m)
				_theta_prev = theta
			if _phase_t >= m.swing_time:
				_set_phase("recover")
		"recover":
			_cool(delta)
			var k := smoothstep(0.0, 1.0, minf(_phase_t / m.recover_time, 1.0))
			var idle := _idle_pose(_clock)
			_cur_basis = _from_basis.slerp(idle[0], k)
			_cur_pos = _from_pos.lerp(idle[1], k)
			if _phase_t >= m.recover_time:
				_set_phase("rest")
		"rest":
			_cool(delta)
			var idle := _idle_pose(_clock)
			_cur_basis = _cur_basis.slerp(idle[0], clampf(delta * 6.0, 0.0, 1.0))
			_cur_pos = _cur_pos.lerp(idle[1], clampf(delta * 6.0, 0.0, 1.0))
			if _phase_t >= m.rest_time:
				_set_phase("idle")
				move_finished.emit()


func _strike_pose(m: Resource, tt: float) -> Array:
	var u := clampf(tt / m.swing_time, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - u, m.swing_power)
	var a: float = m.start_deg - m.cock_deg
	var theta := lerpf(a, m.end_deg, e)
	var pose := _swing_pose(m, theta, sin(minf(u * 1.6, 1.0) * PI * 0.5))
	return [pose[0], pose[1], theta]


func _emit_contact(m: Resource) -> void:
	var f := _frame()
	var gb := global_transform.basis
	var t: Vector3 = (gb * f["T"]).normalized()
	var tangent := (gb * _motion_dir(f, m)).normalized()
	var out_dir := -t
	var pos := target.global_position + out_dir * target_radius
	contact.emit(pos, tangent, t, out_dir, m)


func _set_phase(p: String) -> void:
	if p == "recover":
		_from_basis = _cur_basis
		_from_pos = _cur_pos
	_phase = p
	_phase_t = 0.0
	blade_fx.set_charging(p == "charge")
	blade_fx.set_slashing(p == "strike")
	phase_changed.emit(p, _move)


func _apply() -> void:
	katana.transform = Transform3D(_cur_basis.orthonormalized(), _cur_pos)
