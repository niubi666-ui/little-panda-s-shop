extends Node3D
## Shared sampled contour drives both cut geometry and paving mask. Art-only clock/RNG.
var art: Resource
var rules
var floor_view: Node3D
var walls: MeshInstance3D
var lips: MeshInstance3D
var bottom: MeshInstance3D
var source: MeshInstance3D
var curtains: Array[MeshInstance3D] = []
var built := false
var contour: PackedVector2Array
var contour_texture: ImageTexture

func configure(profile: Resource, model, floor_adapter: Node3D) -> void:
	art=profile
	rules=model
	floor_view=floor_adapter
	walls=_node(art.rift_wall)
	lips=_node(art.rift_lip)
	bottom=_node(art.rift_void)
	source=_node(art.rift_source)
	for i in art.rift_curtain_count:
		var curtain:=_node(art.rift_curtain)
		curtain.material_override.set_shader_parameter("layer_phase",float(i)*19.71)
		curtains.append(curtain)
	_make_contour()

func _node(material: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	node.material_override=material.duplicate()
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func triangle(value: float) -> float:
	return absf(fposmod(value,1.0)*2.0-1.0)*2.0-1.0

func _hash(index: int) -> float:
	var n: int=(index+art.visual_seed)*374761393
	n=(n^(n>>13))*1274126177
	return float((n^(n>>16))&0x7fffffff)/2147483647.0

func _noise(x: float) -> float:
	var i:=int(floor(x))
	return lerpf(_hash(i),_hash(i+1),fposmod(x,1.0))*2.0-1.0

func _make_contour() -> void:
	contour.clear()
	var image:=Image.create(art.rift_station_count,1,false,Image.FORMAT_RGF)
	for i in art.rift_station_count:
		var u:=float(i)/float(art.rift_station_count-1)
		var x: float=u*rules.config.skill.range_m*art.rift_frequency
		var taper:=smoothstep(0.0,0.04,u)*(1.0-smoothstep(0.92,1.0,u))
		var center: float=(_noise(x*0.73)*0.75+_noise(x*3.1+17.0)*0.25)*art.rift_center_ratio*taper
		var width: float=(art.rift_opening_ratio+(_noise(x*1.9+51.0)*0.55+_noise(x*7.3+97.0)*0.45)*art.rift_jagged_ratio)*taper
		contour.append(Vector2(center,width))
		image.set_pixel(i,0,Color(center,width,0,1))
	contour_texture=ImageTexture.create_from_image(image)
	floor_view.set_rift_contour(contour_texture,rules.config.skill.range_m)

func shape(distance_m: float) -> Vector2:
	var sample: float=clampf(distance_m/rules.config.skill.range_m,0,1)*(contour.size()-1)
	var i:=mini(int(sample),contour.size()-2)
	return contour[i].lerp(contour[i+1],sample-i)*rules.config.skill.trail_half_width_m

func _plume_point(x: float, lateral: float, y: float, layer: int) -> Vector3:
	var s:=shape(x)
	var h: float=lerpf(art.rift_height_m.x,art.rift_height_m.y,(_noise(x*art.rift_frequency+layer*31.0)+1.0)/2.0)
	var drift: float=sin(y*PI)*_noise(x*0.83+layer*17.0+y*2.0)*art.rift_beam_drift_m
	return Vector3(x+drift,lerpf(art.rift_surface_height_m,h,y),s.x+s.y*lateral*0.65+drift)

func _strip(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, u0: float, u1: float) -> void:
	for vertex in [{"p":a,"uv":Vector2(u0,0)},{"p":b,"uv":Vector2(u1,0)},{"p":c,"uv":Vector2(u1,1)},
	               {"p":a,"uv":Vector2(u0,0)},{"p":c,"uv":Vector2(u1,1)},{"p":d,"uv":Vector2(u0,1)}]:
		st.set_uv(vertex.uv)
		st.add_vertex(vertex.p)

func _surface() -> SurfaceTool:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

func build() -> void:
	built=true
	global_position=Vector3(rules.origin.x,rules.ground_height,rules.origin.z)
	basis=Basis(rules.direction,Vector3.UP,rules.direction.cross(Vector3.UP))
	var wall_st:=_surface()
	var lip_st:=_surface()
	var void_st:=_surface()
	var source_st:=_surface()
	var curtain_st: Array[SurfaceTool]=[]
	for i in curtains.size(): curtain_st.append(_surface())
	var length_m: float=rules.config.skill.range_m
	for i in art.rift_station_count-1:
		var u0: float=float(i)/(art.rift_station_count-1)
		var u1: float=float(i+1)/(art.rift_station_count-1)
		var x0: float=u0*length_m
		var x1: float=u1*length_m
		var s0:=shape(x0)
		var s1:=shape(x1)
		for side in [-1.0,1.0]:
			var z0: float=s0.x+s0.y*side
			var z1: float=s1.x+s1.y*side
			_strip(wall_st,Vector3(x0,art.rift_surface_height_m,z0),Vector3(x1,art.rift_surface_height_m,z1),
			       Vector3(x1,-art.rift_depth_m,s1.x+s1.y*side/2.0),Vector3(x0,-art.rift_depth_m,s0.x+s0.y*side/2.0),u0,u1)
			var y0: float=art.rift_surface_height_m+_hash(i+int(side)*911)*art.rift_lip_height_m
			var y1: float=art.rift_surface_height_m+_hash(i+1+int(side)*911)*art.rift_lip_height_m
			var w0: float=art.rift_lip_width_m*_hash(i+int(side)*43)
			var w1: float=art.rift_lip_width_m*_hash(i+1+int(side)*43)
			if _hash(i+int(side)*179)>0.3:
				_strip(lip_st,Vector3(x0,y0,z0),Vector3(x1,y1,z1),Vector3(x1,art.rift_surface_height_m,z1+side*w1),Vector3(x0,art.rift_surface_height_m,z0+side*w0),u0,u1)
		_strip(void_st,Vector3(x0,-art.rift_depth_m,s0.x-s0.y),Vector3(x1,-art.rift_depth_m,s1.x-s1.y),
		       Vector3(x1,-art.rift_depth_m,s1.x+s1.y),Vector3(x0,-art.rift_depth_m,s0.x+s0.y),u0,u1)
		_strip(source_st,Vector3(x0,-art.rift_source_depth_m,s0.x-s0.y/2.0),Vector3(x1,-art.rift_source_depth_m,s1.x-s1.y/2.0),
		       Vector3(x1,-art.rift_source_depth_m,s1.x+s1.y/2.0),Vector3(x0,-art.rift_source_depth_m,s0.x+s0.y/2.0),u0,u1)
		for j in curtains.size():
			var lateral:=float(j)/maxi(1,curtains.size()-1)*2.0-1.0
			for k in art.rift_vertical_segments:
				var v0:=float(k)/float(art.rift_vertical_segments)
				var v1:=float(k+1)/float(art.rift_vertical_segments)
				var pts: Array[Vector3]=[_plume_point(x0,lateral,v0,j),_plume_point(x1,lateral,v0,j),_plume_point(x1,lateral,v1,j),_plume_point(x0,lateral,v1,j)]
				var uvs: Array[Vector2]=[Vector2(u0,v0),Vector2(u1,v0),Vector2(u1,v1),Vector2(u0,v1)]
				for index in [0,1,2,0,2,3]:
					curtain_st[j].set_uv(uvs[index])
					curtain_st[j].add_vertex(pts[index])
	# Pointed remnants of paving split the cut into short side forks.
	for fork: Vector4 in art.rift_forks:
		var x0: float=fork.x
		var x1: float=fork.x+fork.y
		var s0:=shape(x0)
		var s1:=shape(x1)
		var z0: float=s0.x+s0.y*fork.z*0.9
		var z1: float=s1.x+s1.y*fork.z*0.30
		var cap: Array[Vector3]=[Vector3(x0,art.rift_surface_height_m,z0-fork.w),Vector3(x1,art.rift_surface_height_m,z1),Vector3(x0,art.rift_surface_height_m,z0+fork.w)]
		for k in 3:
			lip_st.set_uv(Vector2(cap[k].x/length_m,0))
			lip_st.add_vertex(cap[k])
			var next: Vector3=cap[(k+1)%3]
			_strip(wall_st,cap[k],next,next-Vector3.UP*art.rift_depth_m,cap[k]-Vector3.UP*art.rift_depth_m,cap[k].x/length_m,next.x/length_m)
	for entry in [{"node":walls,"st":wall_st},{"node":lips,"st":lip_st},{"node":bottom,"st":void_st},{"node":source,"st":source_st}]:
		entry.st.generate_normals()
		entry.node.mesh=entry.st.commit()
	for i in curtains.size():
		curtain_st[i].generate_normals()
		curtains[i].mesh=curtain_st[i].commit()

func reset() -> void:
	built=false
	visible=false
	floor_view.set_rift(rules.origin,rules.direction,0.0,0.0,art)

func refresh(life: float, age: float) -> void:
	visible=rules.fire_time>=0.0 and life>0.0
	if not visible:
		floor_view.set_rift(rules.origin,rules.direction,0.0,0.0,art)
		return
	if not built: build()
	basis=Basis(rules.direction,Vector3.UP,rules.direction.cross(Vector3.UP)*life)
	var progress: float=rules.travelled()/rules.config.skill.range_m
	var rise: float=clampf(age/art.rift_rise_sec,0.0,1.0)
	for item in [walls,lips,bottom,source]+curtains:
		item.material_override.set_shader_parameter("travel",progress)
		item.material_override.set_shader_parameter("life",life)
		item.material_override.set_shader_parameter("time_value",age)
		if item in curtains:
			item.material_override.set_shader_parameter("rise",rise)
			item.material_override.set_shader_parameter("tick_sec",rules.config.skill.trail_tick_sec)
	floor_view.set_rift(rules.origin,rules.direction,rules.travelled(),rules.config.skill.trail_half_width_m*life,art)
