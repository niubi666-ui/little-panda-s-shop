extends SceneTree
## Narrow headless contract check. GPU rendering is verified separately.

var _failures: PackedStringArray = PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://presentation/environment_wind_v001/breeze_preview.tscn") as PackedScene
	_check(scene != null, "preview scene loads")
	if scene == null:
		_finish()
		return
	var preview = scene.instantiate()
	var environment: Environment = preview.get_node("WorldEnvironment").environment
	_check(environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "preview uses explicit color ambient without a sky resource")
	_check(environment.ambient_light_sky_contribution == 0.0, "color ambient does not depend on a missing sky")
	var errors: PackedStringArray = preview.profile.validation_errors()
	_check(errors.is_empty(), "profile validates: %s" % errors)
	preview.strength_index = preview.profile.initial_strength_index
	var source := StandardMaterial3D.new()
	source.resource_name = "Smoke check cutout"
	source.albedo_color = Color(0.31, 0.58, 0.14, 0.81)
	source.albedo_texture = GradientTexture2D.new()
	source.normal_enabled = true
	source.normal_texture = GradientTexture2D.new()
	source.normal_scale = 0.67
	source.roughness = 0.73
	source.roughness_texture = GradientTexture2D.new()
	source.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	source.metallic = 0.12
	source.metallic_texture = GradientTexture2D.new()
	source.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	source.metallic_specular = 0.41
	source.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	source.alpha_scissor_threshold = 0.39
	source.uv1_scale = Vector3(1.4, 1.7, 1.0)
	source.uv1_offset = Vector3(0.1, 0.2, 0.0)
	var cull_names := ["cull_back", "cull_front", "cull_disabled"]
	for cull_mode in [BaseMaterial3D.CULL_BACK, BaseMaterial3D.CULL_FRONT, BaseMaterial3D.CULL_DISABLED]:
		source.cull_mode = cull_mode
		var converted: ShaderMaterial = preview._convert_material(source)
		_check(not converted.shader.get_shader_uniform_list().is_empty(), "shader uniform metadata parses for cull mode %d" % cull_mode)
		_check(converted.shader.code.contains(cull_names[cull_mode] + ","), "cull mode %d transfers" % cull_mode)
		for entry in [
			["base_color", source.albedo_color], ["albedo_texture", source.albedo_texture],
			["normal_texture", source.normal_texture], ["normal_scale", source.normal_scale],
			["roughness_value", source.roughness], ["roughness_texture", source.roughness_texture],
			["roughness_channel", Vector4(0, 1, 0, 0)], ["metallic_value", source.metallic],
			["metallic_texture", source.metallic_texture], ["metallic_channel", Vector4(0, 0, 1, 0)],
			["specular_value", source.metallic_specular], ["alpha_scissor_enabled", true],
			["alpha_scissor_threshold", source.alpha_scissor_threshold],
			["uv_scale", Vector2(1.4, 1.7)], ["uv_offset", Vector2(0.1, 0.2)],
		]:
			_check(converted.get_shader_parameter(entry[0]) == entry[1], "%s preserves source value" % entry[0])
	preview.set_wind_time(2.0)
	preview.set_wind_paused(true)
	preview._process(0.5)
	_check(is_equal_approx(preview.wind_time, 2.0), "pause freezes the host clock")
	for material in preview.wind_materials:
		_check(is_equal_approx(material.get_shader_parameter("wind_time"), 2.0), "pause freezes shared material time")
	preview.set_wind_paused(false)
	preview._process(0.5)
	_check(is_equal_approx(preview.wind_time, 2.5), "resume advances the clock")
	preview.set_wind_strength_index(2)
	for material in preview.wind_materials:
		_check(is_equal_approx(material.get_shader_parameter("wind_strength"), preview.profile.strength_levels[2]), "strength preset updates shared material")
	preview.free()
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	print("BREEZE_SMOKE failures=%d (headless material/time contract only; GPU visual quality unverified)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
