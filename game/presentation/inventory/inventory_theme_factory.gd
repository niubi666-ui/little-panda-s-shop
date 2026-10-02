extends RefCounted
## Creates local style resources. Authored PNGs and the shared Theme stay intact.

const InventoryAppearance = preload("res://presentation/inventory/inventory_ui_skin.gd")

static var _cached_source: InventoryAppearance
static var _cached_textures: Dictionary[String, Texture2D] = {}


static func prepare(source: InventoryAppearance) -> InventoryAppearance:
	assert(source != null, "Inventory UI requires a skin Resource")
	if _cached_source != source:
		var prepared: Dictionary[String, Texture2D] = {}
		for key: String in source.style_texture_sizes:
			assert(source.textures.has(key), "Inventory UI is missing texture: %s" % key)
			var texture: Texture2D = source.textures[key]
			var dimensions: Vector2i = source.style_texture_sizes[key]
			var pixels: Image = texture.get_image()
			if pixels == null or pixels.is_empty():
				push_error("Inventory UI texture could not be read: %s" % key)
				return null
			if pixels.is_compressed() and pixels.decompress() != OK:
				push_error("Inventory UI texture could not be decompressed: %s" % key)
				return null
			pixels.clear_mipmaps()
			pixels.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_LANCZOS)
			prepared[key] = ImageTexture.create_from_image(pixels)
		_cached_source = source
		_cached_textures = prepared
	var result: InventoryAppearance = source.duplicate()
	result.styles = {}
	for key: String in source.styles:
		var box: StyleBox = source.styles[key].duplicate()
		if box is StyleBoxTexture:
			assert(source.style_sources.has(key), "Inventory UI is missing style source: %s" % key)
			var texture_key: String = source.style_sources[key]
			assert(_cached_textures.has(texture_key), "Inventory UI texture was not prepared: %s" % texture_key)
			box.texture = _cached_textures[texture_key]
		result.styles[key] = box
	return result
