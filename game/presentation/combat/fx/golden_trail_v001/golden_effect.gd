extends "res://presentation/combat/fx/trail_presets_01_06_v001/preset_effect.gd"
## Runtime adaptation of the approved Blender golden filaments and sparks.
## ActorView can sample after placing the sword, independent of render frame order.
@export var spark_blade_coverage: float
@export var spark_emitter_thickness: float

func configure_blade(length: float) -> void:
	super.configure_blade(length)
	assert(spark_blade_coverage > 0.0 and spark_blade_coverage <= 1.0)
	assert(spark_emitter_thickness > 0.0)
	$Particles.position = Vector3.ZERO
	$Particles.emission_box_extents = Vector3(spark_emitter_thickness, spark_emitter_thickness, length * spark_blade_coverage / 2.0)

func sample_current_pose() -> void:
	# Zero delta only samples geometry; material/particle clocks keep their own tick.
	super._process(0.0)

func finish_at_current_pose() -> void:
	if _active:
		set_active(false)
		sample_current_pose()
