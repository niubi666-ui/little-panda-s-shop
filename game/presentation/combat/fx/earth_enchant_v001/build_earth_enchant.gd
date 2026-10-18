extends SceneTree
## 把实验室里用户认可的土元素特效复制成游戏用的独立资源（和 elemental_enchants_v001 里的冰/雷同一套结构）：
## - earth_enchant.tscn：常驻附魔（刀身岩壳覆盖层 + 悬浮碎石、细沙、尘土、挥砍尘土拖尾和碎石）
## - earth_impact.tscn：直接命中的受击（地刺、地面裂纹、碎石、尘土），由 build_effects_style.element_impact_scenes 播放
## 材质、网格另存一份（新 UID）；着色器、贴图、脚本都指向游戏目录，不依赖 vfx_lab。粒子参数原样保留。
## 先 --import 一次（本目录的贴图），再跑：
## Godot --headless --path game --script res://presentation/combat/fx/earth_enchant_v001/build_earth_enchant.gd

const DIR := "res://presentation/combat/fx/earth_enchant_v001/"
const LAB := "res://vfx_lab/elemental_enchants/"
const SHARED := "res://presentation/combat/fx/elemental_enchants_v001/"


func _init() -> void:
	var puff: Shader = load(DIR + "earth_puff.gdshader")
	var glint: Shader = load(SHARED + "shaders/glint.gdshader")
	var mats := {}
	mats["earth_dust.tres"] = _port(LAB + "generated/earth_dust.tres", puff, {"tex": load(DIR + "mist_atlas.png")})
	mats["earth_sand.tres"] = _port(LAB + "generated/earth_sand.tres", puff, {"tex": load("res://presentation/combat/fx/fire_enchant_v001/soft_dot.png")})
	mats["earth_flash.tres"] = _port(LAB + "generated/earth_flash.tres", glint, {"tex": load("res://presentation/combat/fx/fire_enchant_v001/soft_dot.png")})
	mats["earth_fleck.tres"] = _port(LAB + "generated/earth_fleck.tres", glint, {"tex": load(SHARED + "shared/generated/textures/flare_star.png")})
	mats["rock.tres"] = _save(load(LAB + "generated/rock.tres").duplicate(true), DIR + "earth_rock.tres")
	mats["rock_spike.tres"] = _save(load(LAB + "generated/rock_spike.tres").duplicate(true), DIR + "earth_rock_spike.tres")
	var rock_mesh: Mesh = _save(load(LAB + "generated/rock_chunk_mesh.res").duplicate(), DIR + "rock_chunk_mesh.res")
	var spike_mesh: Mesh = _save(load(LAB + "generated/rock_spike_mesh.res").duplicate(), DIR + "rock_spike_mesh.res")
	var lab_overlay: ShaderMaterial = load(LAB + "generated/earth_overlay.tres")
	var overlay := ShaderMaterial.new()
	overlay.shader = load(DIR + "earth_overlay.gdshader")
	overlay.render_priority = lab_overlay.render_priority
	for k in ["noise_tex", "cells_tex"]:
		overlay.set_shader_parameter(k, lab_overlay.get_shader_parameter(k))
	overlay = _save(overlay, DIR + "earth_overlay.tres")

	# ---- 常驻附魔 ----
	var src: Node3D = load(LAB + "earth_enchant.tscn").instantiate()
	var root := Node3D.new()
	root.name = "EarthEnchant"
	root.set_script(load(DIR + "earth_enchant.gd"))
	var refs := {}
	for c in src.get_children():
		var node: Node = c.duplicate()
		root.add_child(node)
		refs[c.name] = node
		_swap(node, mats, rock_mesh)
	for kv in [["dust", "Dust"], ["sand", "Sand"], ["pebbles", "Pebbles"], ["trail_dust", "TrailDust"], ["chips", "Chips"], ["light", "EarthLight"], ["fill_reference", "TrailDust"]]:
		root.set(kv[0], refs[kv[1]])
	for p in ["fill_overlap", "chip_chance", "chip_speed", "light_energy"]:
		root.set(p, src.get(p))
	root.set("overlay_material", overlay)
	root.set("idle_power", 0.6)
	root.set("windup_power", 0.9)
	root.set("active_power", 1.25)
	_pack(root, DIR + "earth_enchant.tscn")
	src.free()

	# ---- 受击 ----
	var lab_hit: Node3D = load(LAB + "earth_impact.tscn").instantiate()
	var hit := Node3D.new()
	hit.name = "EarthImpact"
	hit.set_script(load(SHARED + "shared/scripts/vfx_sequence_player.gd"))
	var tl: Resource = load(SHARED + "shared/scripts/vfx_timeline.gd").new()
	tl.delays = lab_hit.timeline.delays.duplicate()
	tl.lifetime = lab_hit.timeline.lifetime
	hit.set("timeline", _save(tl, DIR + "earth_impact_timeline.tres"))
	for c in lab_hit.get_children():
		hit.add_child(_port_layer(c, mats, rock_mesh, spike_mesh))
	_pack(hit, DIR + "earth_impact.tscn")
	lab_hit.free()
	print("earth enchant built")
	quit()


## 受击层：粒子换材质；灯、贴花、地刺换成游戏版脚本（跟战斗时钟走），导出参数照搬
func _port_layer(c: Node, mats: Dictionary, rock_mesh: Mesh, spike_mesh: Mesh) -> Node:
	if c is GPUParticles3D:
		var p: Node = c.duplicate()
		_swap(p, mats, rock_mesh)
		return p
	if c is OmniLight3D:
		return _rescript(c, SHARED + "shared/scripts/vfx_light_pulse.gd", ["peak_energy", "duration", "curve", "flicker"])
	if c is Decal:
		var d: Decal = _rescript(c, SHARED + "shared/scripts/vfx_decal_fade.gd", ["glow_peak", "glow_time", "hold_time", "fade_time"])
		d.texture_albedo = load(DIR + "ground_crack_albedo.png")
		d.texture_emission = load(DIR + "ground_crack_emission.png")
		return d
	if c.name == "Eruption":
		var e: Node3D = _rescript(c, DIR + "spike_eruption.gd", ["count", "spacing", "height_range", "radius_range", "stagger", "rise_time",
			"hold_time", "sink_time", "ring_threshold", "ring_radius", "ring_center_offset"], false)
		e.set("spike_mesh", spike_mesh)
		e.set("spike_material", mats["rock_spike.tres"])
		# 游戏里命中点是目标中心：第一根岩刺离远一点，别插进敌人身体里
		e.set("start_offset", 0.6)
		e.set("ground_drop", 0.75)
		for child in c.get_children():
			e.add_child(_port_layer(child, mats, rock_mesh, spike_mesh))
		return e
	return c.duplicate()


func _rescript(c: Node, script_path: String, props: Array, keep_children := true) -> Node:
	var values := {}
	for p in props:
		values[p] = c.get(p)
	var n: Node = c.duplicate() if keep_children else c.duplicate(0)
	if not keep_children:
		for child in n.get_children():
			n.remove_child(child)
			child.free()
	n.set_script(load(script_path))
	for p in values:
		if values[p] != null:
			n.set(p, values[p])
	return n


func _swap(node: Node, mats: Dictionary, rock_mesh: Mesh) -> void:
	if not (node is GPUParticles3D):
		return
	var m: Material = node.material_override
	if m != null:
		var file := m.resource_path.get_file()
		if mats.has(file):
			node.material_override = mats[file]
	if not (node.draw_pass_1 is QuadMesh):
		node.draw_pass_1 = rock_mesh


func _port(path: String, shader: Shader, params: Dictionary) -> ShaderMaterial:
	var m: ShaderMaterial = load(path).duplicate()
	m.shader = shader
	for k in params:
		m.set_shader_parameter(k, params[k])
	return _save(m, DIR + path.get_file())


func _pack(root: Node, path: String) -> void:
	_own(root, root)
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, path) == OK)


func _own(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_own(c, owner)


func _save(res: Resource, path: String) -> Resource:
	assert(ResourceSaver.save(res, path) == OK, "save failed " + path)
	return load(path)
