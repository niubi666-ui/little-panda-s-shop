extends RefCounted
## Creates local presentation resources without changing source PNGs or theme.

const DecorationSkin = preload("res://presentation/decorating/decorating_ui_skin.gd")


static func prepare(source: DecorationSkin) -> DecorationSkin:
	var result: DecorationSkin = source.duplicate()
	var prepared: Dictionary[String, Texture2D] = {}
	for key: String in source.style_texture_sizes:
		var texture: Texture2D = source.textures[key]
		var dimensions: Vector2i = source.style_texture_sizes[key]
		var pixels: Image = texture.get_image()
		if pixels == null or pixels.is_empty():
			push_error("Decoration UI texture could not be read: %s" % key)
			return null
		if pixels.is_compressed() and pixels.decompress() != OK:
			push_error("Decoration UI texture could not be decompressed: %s" % key)
			return null
		pixels.clear_mipmaps()
		pixels.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_LANCZOS)
		prepared[key] = ImageTexture.create_from_image(pixels)
	result.style_boxes = {}
	for key: String in source.style_boxes:
		var box: StyleBox = source.style_boxes[key].duplicate()
		if box is StyleBoxTexture:
			var texture_key: String = source.style_sources[key]
			box.texture = prepared[texture_key]
		result.style_boxes[key] = box
	return result
