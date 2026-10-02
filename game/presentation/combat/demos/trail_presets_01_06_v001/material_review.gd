extends Node3D
## Static material inspection, deliberately a longer arc than the gameplay attack.
@export var inner_radius: float
@export var outer_radius: float
@export var sweep_degrees: float
@export var arc_segments: int
@export var radial_segments: int
@export var spacing: float
@export var camera_size: float
@export var labels: PackedStringArray
@export var materials: Array[Material]
@export var sword: PackedScene
@export var environment: Environment
@export var capture_delay: float
var _elapsed := 0.0
var _captured := false
func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = environment
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = camera_size
	cam.position = Vector3.UP * camera_size
	cam.look_at(Vector3.ZERO,Vector3.FORWARD)
	cam.current = true
	var light := DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-70,-35,0)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	for preset in materials.size():
		var center := Vector3((float(preset)-float(materials.size()-1)/2.0)*spacing,0,0)
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,materials[preset])
		for x in arc_segments:
			for y in radial_segments:
				var a := Vector2(float(x)/arc_segments,float(y)/radial_segments)
				var b := Vector2(float(x+1)/arc_segments,float(y+1)/radial_segments)
				for uv in [a,Vector2(a.x,b.y),b,a,b,Vector2(b.x,a.y)]:
					var angle := deg_to_rad(-sweep_degrees*(1.0-uv.x))
					mesh.surface_set_color(Color.WHITE)
					mesh.surface_set_uv(uv)
					mesh.surface_add_vertex(center+Vector3(sin(angle),0,-cos(angle))*lerpf(inner_radius,outer_radius,uv.y))
		mesh.surface_end()
		var node := MeshInstance3D.new()
		node.mesh=mesh
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		var weapon := sword.instantiate()
		add_child(weapon)
		weapon.scale=Vector3.ONE*(outer_radius-inner_radius)
		weapon.position=center+Vector3.FORWARD*(outer_radius+inner_radius)/2.0
		weapon.position.y=0.025
		var label := Label.new()
		canvas.add_child(label)
		label.text=labels[preset]
		label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		label.position=Vector2(get_viewport().get_visible_rect().size.x*float(preset)/materials.size()+32,32)
		label.add_theme_font_size_override("font_size",28)
func _process(delta: float) -> void:
	_elapsed+=delta
	if not _captured and _elapsed >= capture_delay:
		_captured=true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../source_assets/vfx/trail_fxs_v2/selected_01_06_v001/previews/material_comparison.png"))
		print("MATERIAL_REVIEW_CAPTURED")
		get_tree().quit()
