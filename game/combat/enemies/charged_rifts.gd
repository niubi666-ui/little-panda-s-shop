extends RefCounted
## Committed charged-arrow paths; fixed pulse clock, no renderer or asset access.
signal started(area: Dictionary)
signal retired(id: int)
signal pulsed(area: Dictionary, applied: float, point: Vector3)
var items: Array[Dictionary] = []

func add(projectile: Dictionary) -> void:
	var c: Dictionary=projectile.config.rift
	var point: Vector3=projectile.start_position
	point.y=projectile.source.global_position.y
	var area: Dictionary={"id":projectile.id,"source":projectile.source,"owner_handle":projectile.source.handle,"origin":point,"direction":projectile.direction,"config":c,"age":0.0,"length":0.0,"next_tick":c.interval_sec,"projectile":projectile}
	items.append(area)
	started.emit(area)

func step(delta: float, target, radius: float, query_origin: Callable, sweep: Callable, impact: Callable) -> void:
	if delta<=0.0:return
	for area in items.duplicate():
		if not is_instance_valid(area.source) or not area.source.health.alive():
			remove(area.id)
			continue
		area.length=area.projectile.position.distance_to(area.projectile.start_position)
		area.age+=delta
		while area.next_tick<=area.age+0.000001 and area.next_tick<area.config.duration_sec-0.000001:
			area.next_tick+=area.config.interval_sec
			var applied:=0.0
			var center: Vector3=query_origin.call(target)
			var start: Vector3=area.origin;start.y=center.y
			var end: Vector3=start+area.direction*area.length
			var closest:=Geometry3D.get_closest_point_to_segment(center,start,end)
			# No damage beyond a world-truncated endpoint or through lateral cover.
			var along: float=(center-start).dot(area.direction)
			if area.length>0.0 and along>=0.0 and along<=area.length and center.distance_to(closest)<=area.config.half_width_m+radius and sweep.call(closest,center,0.0)>=1.0:
				applied=impact.call(area.source,target,area.config.damage,Vector3.ZERO,0.0,0.0)
			pulsed.emit(area,applied,target.global_position)
			if not target.health.alive():return
		if area.age>=area.config.duration_sec:remove(area.id)

func remove(id: int) -> void:
	for i in range(items.size()-1,-1,-1):
		if items[i].id==id:
			items.remove_at(i)
			retired.emit(id)

func remove_source(handle: int) -> void:
	for area in items.duplicate():
		if area.owner_handle==handle:remove(area.id)

func clear() -> void:
	for area in items.duplicate():remove(area.id)
