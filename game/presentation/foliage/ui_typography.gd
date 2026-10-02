extends Resource
## All font choices and sizes live in ui_typography.tres, never in page scripts.
@export var font_file: Font
@export var body_weight: float
@export var button_weight: float
@export var heading_weight: float
@export var body_size: int
@export var button_size: int
@export var title_size: int
@export var detail_title_size: int
@export var muted_size: int
@export var catalog_size: int

func apply_to(target: Theme) -> void:
	assert(font_file != null, "UI typography requires a bundled font")
	for size: int in [body_size, button_size, title_size, detail_title_size, muted_size, catalog_size]:
		assert(size > 0, "UI typography sizes must be authored")
	var body := font_at_weight(body_weight)
	var button := font_at_weight(button_weight)
	var heading := font_at_weight(heading_weight)
	target.default_font = body
	target.default_font_size = body_size
	target.set_font("font", "Button", button)
	target.set_font_size("font_size", "Button", button_size)
	target.set_font("font", "Title", heading)
	target.set_font_size("font_size", "Title", title_size)
	target.set_font_size("font_size", "Muted", muted_size)
	target.set_type_variation("PaperHeading", "PaperLabel")
	target.set_font("font", "PaperHeading", heading)
	target.set_font_size("font_size", "PaperHeading", detail_title_size)
	target.set_type_variation("CatalogButton", "Button")
	target.set_font_size("font_size", "CatalogButton", catalog_size)

func font_at_weight(weight: float) -> FontVariation:
	assert(weight > 0, "UI font weights must be authored")
	var font := FontVariation.new()
	font.base_font = font_file
	var weight_tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	font.variation_opentype = {weight_tag: weight}
	return font
