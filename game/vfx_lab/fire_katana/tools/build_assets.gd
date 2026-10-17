extends SceneTree
## 生成火焰太刀演示用的灰度特效贴图和太刀网格。
## 用法：Godot --headless --path game --script res://vfx_lab/fire_katana/tools/build_assets.gd
## 贴图都是灰度（颜色交给粒子和着色器），思路照搬 Material Maker 那套：软圆点、星芒、圆环、火焰团、刀痕、焦痕。

const OUT := "res://vfx_lab/fire_katana/generated/"
const TEX := OUT + "textures/"

var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 7
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4
	_noise.frequency = 1.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEX))
	_save(_soft_dot(128), "soft_dot.png")
	_save(_ring(256), "ring.png")
	_save(_flare(512), "flare_star.png")
	_save(_flame_atlas(512), "flame_atlas.png")
	_save(_crescent(512, 256), "cut_crescent.png")
	var scorch := _scorch(512, 256)
	_save(scorch[0], "scorch_albedo.png")
	_save(scorch[1], "scorch_emission.png")
	var mesh := KatanaMesh.build()
	var err := ResourceSaver.save(mesh, OUT + "katana_mesh.res")
	print("katana mesh saved: ", err == OK, " surfaces=", mesh.get_surface_count())
	quit()


func _save(img: Image, file: String) -> void:
	img.save_png(TEX + file)
	print("saved ", file)


func _n(x: float, y: float) -> float:
	return _noise.get_noise_2d(x, y) * 0.5 + 0.5


func _grey(size: Vector2i, f: Callable) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for py in size.y:
		for px in size.x:
			var x := (px + 0.5) / size.x * 2.0 - 1.0
			var y := 1.0 - (py + 0.5) / size.y * 2.0
			var v := clampf(f.call(x, y), 0.0, 1.0)
			img.set_pixel(px, py, Color(v, v, v, v))
	return img


func _soft_dot(s: int) -> Image:
	return _grey(Vector2i(s, s), func(x: float, y: float) -> float:
		var r2: float = x * x + y * y
		return exp(-r2 * 5.5) * smoothstep(1.0, 0.8, sqrt(r2)))


func _ring(s: int) -> Image:
	return _grey(Vector2i(s, s), func(x: float, y: float) -> float:
		var r := sqrt(x * x + y * y)
		var a := atan2(y, x)
		var wob := 0.03 * (_n(cos(a) * 3.0, sin(a) * 3.0) - 0.5)
		var v := exp(-pow((r - 0.74 - wob) / 0.06, 2.0)) + 0.3 * exp(-pow((r - 0.66) / 0.16, 2.0))
		return v * smoothstep(1.0, 0.92, r))


func _flare(s: int) -> Image:
	var rays := []
	for i in 30:
		rays.append([_rng.randf() * TAU, _rng.randf_range(0.03, 0.07), _rng.randf_range(0.35, 1.0), _rng.randf_range(0.25, 0.8)])
	# 四条主芒（十字星），课程里的 Flare02 做法
	for i in 4:
		rays.append([i * PI * 0.5 + 0.3, 0.04, 1.0, 1.2])
	return _grey(Vector2i(s, s), func(x: float, y: float) -> float:
		var r := sqrt(x * x + y * y)
		var a := atan2(y, x)
		var v := exp(-r * r * 70.0) + 0.35 * exp(-r * r * 9.0)
		for ray in rays:
			var d := absf(wrapf(a - ray[0], -PI, PI))
			v += ray[3] * exp(-pow(d / ray[1], 2.0)) * pow(clampf(1.0 - r / ray[2], 0.0, 1.0), 2.2)
		return v * smoothstep(1.0, 0.9, r))


func _flame_cell(x: float, y: float, seed: float) -> float:
	# 2x2 图集里的一格：带火舌的水滴形火团（Krita 手绘那张的程序化版本）
	var wx := x + 0.28 * (_n(x * 2.2 + seed, y * 2.2) - 0.5)
	var wy := y + 0.22 * (_n(x * 2.2 + 40.0 + seed, y * 2.2 + 40.0) - 0.5)
	var dy := wy + 0.3
	var rr := 0.0
	if dy > 0.0:
		rr = 0.52 * pow(maxf(0.0, 1.0 - dy / 1.2), 1.3)
	else:
		rr = 0.52 * sqrt(maxf(0.0, 1.0 - pow(dy / 0.55, 2.0)))
	if rr <= 0.001:
		return 0.0
	var v := smoothstep(rr, rr * 0.25, absf(wx))
	var tongues := _n(x * 5.0 + seed * 3.0, y * 3.0 - seed)
	v *= smoothstep(0.0, 0.35, tongues + 0.55 - maxf(dy, 0.0) * 0.55)
	v = pow(v, 0.8) * (0.85 + 0.15 * _n(x * 3.5 + seed, y * 3.5))
	return v * smoothstep(1.0, 0.85, maxf(absf(x), absf(y)))


func _flame_atlas(s: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var cell := s / 2
	for cy in 2:
		for cx in 2:
			var seed := float(cy * 2 + cx) * 17.3 + 3.0
			for py in cell:
				for px in cell:
					var x := (px + 0.5) / cell * 2.0 - 1.0
					var y := 1.0 - (py + 0.5) / cell * 2.0
					var v := clampf(_flame_cell(x, y, seed), 0.0, 1.0)
					img.set_pixel(cx * cell + px, cy * cell + py, Color(v, v, v, v))
	return img


func _crescent(w: int, h: int) -> Image:
	# 受击瞬间的“刀口”月牙：横向是刀的运动方向
	return _grey(Vector2i(w, h), func(x: float, y: float) -> float:
		var yc := 0.25 - 0.55 * x * x
		var th := 0.22 * pow(maxf(0.0, 1.0 - x * x), 1.6) + 0.002
		var d := (y - yc) / th
		# 外沿（上侧）锐利、内侧拖出一点
		var v := exp(-d * d * 2.5) if d > 0.0 else exp(-d * d * 0.6)
		v *= pow(maxf(0.0, 1.0 - x * x), 0.8)
		return v * (0.75 + 0.25 * _n(x * 3.0, y * 25.0)))


func _scorch(w: int, h: int) -> Array:
	var albedo := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var emission := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for py in h:
		for px in w:
			var x := (px + 0.5) / w * 2.0 - 1.0
			var y := 1.0 - (py + 0.5) / h * 2.0
			var wob := 0.12 * (_n(x * 2.0, 5.0) - 0.5)
			var span := pow(maxf(0.0, 1.0 - x * x), 0.6)
			var width := 0.42 * span * (0.75 + 0.5 * _n(x * 4.0, 9.0))
			var d := absf(y - wob)
			var char_v := smoothstep(width, width * 0.25, d) * smoothstep(0.2, 0.55, _n(x * 6.0, y * 6.0) + 0.3 * (1.0 - d / maxf(width, 0.001)))
			char_v *= smoothstep(1.0, 0.85, absf(x))
			var inner := smoothstep(width * 0.6, 0.0, d)
			var c := Color(0.07, 0.045, 0.03).lerp(Color(0.015, 0.012, 0.01), inner)
			albedo.set_pixel(px, py, Color(c.r, c.g, c.b, clampf(char_v, 0.0, 1.0)))
			var line_w := 0.07 * span + 0.004
			var e := exp(-pow(d / line_w, 2.0)) * (0.5 + 0.5 * _n(x * 10.0, 3.0)) * span
			e = clampf(e, 0.0, 1.0)
			emission.set_pixel(px, py, Color(e, e * 0.42, e * 0.1, 1.0))
	return [albedo, emission]


## 程序化太刀：刀身（镐造截面+反+切先）、鎺、切羽、镡、缘、柄、头。
## 刀身沿 +Y，刃口朝 +Z，弯向 -Z（刀背一侧）。原点在镡上沿（握持点）。
class KatanaMesh:
	const BLADE_START := 0.036
	const BLADE_LEN := 0.71
	const KISSAKI := 0.93

	static func blade_section(t: float) -> Dictionary:
		var y := BLADE_START + t * BLADE_LEN
		var zm := -0.0155 - 0.024 * pow(t, 1.7)
		var w := lerpf(0.031, 0.0225, t)
		var th := lerpf(0.0072, 0.005, t)
		var f := 1.0
		if t > KISSAKI:
			var k := (t - KISSAKI) / (1.0 - KISSAKI)
			f = sqrt(maxf(0.0, 1.0 - k * k))
		var g := pow(f, 0.6)
		# 截面：刃 → 镐筋 → 栋角 → 栋顶 → 另一侧
		var pts: Array[Vector2] = [
			Vector2(0.0, zm + w * f),
			Vector2(th * 0.5 * g, zm + 0.27 * w * f),
			Vector2(th * 0.33 * g, zm + 0.04 * w * f),
			Vector2(0.0, zm),
			Vector2(-th * 0.33 * g, zm + 0.04 * w * f),
			Vector2(-th * 0.5 * g, zm + 0.27 * w * f),
		]
		return {"y": y, "zm": zm, "w": w, "pts": pts}

	static func blade_ts() -> PackedFloat32Array:
		var ts := PackedFloat32Array()
		for i in 25:
			ts.append(KISSAKI * i / 24.0)
		for i in range(1, 17):
			ts.append(KISSAKI + (1.0 - KISSAKI) * i / 16.0)
		return ts

	static func add_tri(st: SurfaceTool, p: Array, n: Array, uv: Array, outward: Vector3) -> void:
		var gn: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
		if gn.length_squared() < 1e-14:
			return
		var order := [0, 1, 2] if gn.dot(outward) < 0.0 else [0, 2, 1]
		for i in order:
			st.set_normal(n[i])
			st.set_uv(uv[i])
			st.add_vertex(p[i])

	static func build_blade(st: SurfaceTool) -> void:
		var ts := blade_ts()
		var rings := []
		for t in ts:
			var s := blade_section(t)
			var ring := []
			for p in s["pts"]:
				ring.append(Vector3(p.x, s["y"], p.y))
			rings.append({"ring": ring, "s": s, "t": t})
		var count := rings.size()
		for facet in 6:
			var a := facet
			var b := (facet + 1) % 6
			var normals := []
			var last_n := Vector3.ZERO
			for j in count:
				var r: Array = rings[j]["ring"]
				var prev: Array = rings[maxi(j - 1, 0)]["ring"]
				var next: Array = rings[mini(j + 1, count - 1)]["ring"]
				var along: Vector3 = (next[a] + next[b]) - (prev[a] + prev[b])
				var across: Vector3 = r[b] - r[a]
				var nrm := across.cross(along)
				var s: Dictionary = rings[j]["s"]
				var center := Vector3(0.0, s["y"], s["zm"] + s["w"] * 0.4)
				if nrm.length_squared() < 1e-14:
					nrm = last_n
				else:
					nrm = nrm.normalized()
					if nrm.dot((r[a] + r[b]) * 0.5 - center) < 0.0:
						nrm = -nrm
				last_n = nrm
				normals.append(nrm)
			for j in count - 1:
				var r0: Array = rings[j]["ring"]
				var r1: Array = rings[j + 1]["ring"]
				var s0: Dictionary = rings[j]["s"]
				var s1: Dictionary = rings[j + 1]["s"]
				var u := func(p: Vector3, s: Dictionary) -> float: return (p.z - s["zm"]) / s["w"]
				var uv00 := Vector2(u.call(r0[a], s0), rings[j]["t"])
				var uv01 := Vector2(u.call(r0[b], s0), rings[j]["t"])
				var uv10 := Vector2(u.call(r1[a], s1), rings[j + 1]["t"])
				var uv11 := Vector2(u.call(r1[b], s1), rings[j + 1]["t"])
				var out: Vector3 = normals[j]
				add_tri(st, [r0[a], r0[b], r1[b]], [normals[j], normals[j], normals[j + 1]], [uv00, uv01, uv11], out)
				add_tri(st, [r0[a], r1[b], r1[a]], [normals[j], normals[j + 1], normals[j + 1]], [uv00, uv11, uv10], out)
		# 刀根封口（藏在鎺里）
		var base: Array = rings[0]["ring"]
		var c := Vector3.ZERO
		for p in base:
			c += p
		c /= 6.0
		for i in 6:
			add_tri(st, [c, base[i], base[(i + 1) % 6]], [Vector3.DOWN, Vector3.DOWN, Vector3.DOWN], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], Vector3.DOWN)

	## 椭圆旋转体。rings: [y, rx, rz, cz]，segments 圈分段。法线用网格差分。
	static func lathe(st: SurfaceTool, rings: Array, segments: int = 40) -> void:
		var grid := []
		for r in rings:
			var row := []
			for i in segments + 1:
				var a := TAU * i / segments
				row.append(Vector3(cos(a) * r[1], r[0], sin(a) * r[2] + (r[3] if r.size() > 3 else 0.0)))
			grid.append(row)
		var nr := rings.size()
		var cz: float = rings[0][3] if rings[0].size() > 3 else 0.0
		var centroid := Vector3(0.0, (rings[0][0] + rings[nr - 1][0]) * 0.5, cz)
		var normals := []
		for j in nr:
			var nrow := []
			for i in segments + 1:
				var ip := (i + 1) % segments
				var im := (i - 1 + segments) % segments
				var du: Vector3 = grid[j][ip] - grid[j][im]
				var dv: Vector3 = grid[mini(j + 1, nr - 1)][i] - grid[maxi(j - 1, 0)][i]
				var n := du.cross(dv)
				if n.length_squared() < 1e-14:
					# 端盖中心点：沿轴向朝外
					var other: float = rings[1][0] if j == 0 else rings[nr - 2][0]
					n = Vector3(0.0, signf(rings[j][0] - other), 0.0)
				else:
					n = n.normalized()
					if n.dot(grid[j][i] - centroid) < 0.0:
						n = -n
				nrow.append(n)
			normals.append(nrow)
		for j in nr - 1:
			for i in segments:
				var p00: Vector3 = grid[j][i]
				var p01: Vector3 = grid[j][i + 1]
				var p10: Vector3 = grid[j + 1][i]
				var p11: Vector3 = grid[j + 1][i + 1]
				var uv00 := Vector2(float(i) / segments, float(j) / (nr - 1))
				var uv01 := Vector2(float(i + 1) / segments, float(j) / (nr - 1))
				var uv10 := Vector2(float(i) / segments, float(j + 1) / (nr - 1))
				var uv11 := Vector2(float(i + 1) / segments, float(j + 1) / (nr - 1))
				var mid := (p00 + p11) * 0.5
				var out: Vector3 = normals[j][i] + normals[j + 1][i + 1]
				if out.length_squared() < 1e-8:
					out = mid - Vector3(0.0, mid.y, 0.0)
				add_tri(st, [p00, p01, p11], [normals[j][i], normals[j][i + 1], normals[j + 1][i + 1]], [uv00, uv01, uv11], out)
				add_tri(st, [p00, p11, p10], [normals[j][i], normals[j + 1][i + 1], normals[j + 1][i]], [uv00, uv11, uv10], out)

	static func build() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		# 0 刀身
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		build_blade(st)
		st.generate_tangents()
		st.commit(mesh)
		# 1 金具（切羽 + 鎺）
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		lathe(st, [[0.0, 0.0, 0.0], [0.0, 0.0155, 0.0235], [0.0016, 0.0155, 0.0235], [0.0016, 0.0, 0.0]])
		lathe(st, [[0.0016, 0.0, 0.0, -0.0005], [0.0016, 0.0062, 0.0185, -0.0005], [0.03, 0.0058, 0.0178, -0.0005], [0.034, 0.0054, 0.0172, -0.0005], [0.036, 0.0045, 0.0165, -0.0005], [0.036, 0.0, 0.0, -0.0005]])
		st.generate_tangents()
		st.commit(mesh)
		# 2 铁件（镡、缘、头）
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		lathe(st, [[-0.0075, 0.0, 0.0], [-0.0075, 0.033, 0.039], [-0.0071, 0.0355, 0.0415], [-0.0059, 0.0365, 0.0425], [-0.0016, 0.0365, 0.0425], [-0.0004, 0.0355, 0.0415], [0.0, 0.033, 0.039], [0.0, 0.0, 0.0]], 64)
		lathe(st, [[-0.024, 0.0, 0.0], [-0.024, 0.0128, 0.0178], [-0.0225, 0.0134, 0.0186], [-0.009, 0.0134, 0.0186], [-0.0075, 0.0128, 0.0178], [-0.0075, 0.0, 0.0]])
		lathe(st, [[-0.257, 0.0, 0.0], [-0.257, 0.0124, 0.0166], [-0.262, 0.0128, 0.0171], [-0.268, 0.0118, 0.0158], [-0.2715, 0.0085, 0.0114], [-0.2735, 0.0, 0.0]])
		st.generate_tangents()
		st.commit(mesh)
		# 3 柄（柄卷 + 鲛皮由着色器画）
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings := []
		for i in 25:
			var k := i / 24.0
			var y := lerpf(-0.024, -0.257, k)
			var waist := 1.0 - 0.06 * sin(k * PI)
			rings.append([y, lerpf(0.0122, 0.0118, k) * waist, lerpf(0.0172, 0.0162, k) * waist])
		lathe(st, rings, 48)
		st.generate_tangents()
		st.commit(mesh)
		return mesh
