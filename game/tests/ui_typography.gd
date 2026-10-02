extends SceneTree
## Ensure both languages render from the bundled font, without masking missing glyphs with OS fonts.
const Typography = preload("res://presentation/foliage/ui_typography.tres")

func _initialize() -> void:
	var missing: Dictionary = {}
	var font: Font = Typography.font_file
	var title_font: FontVariation = Typography.font_at_weight(Typography.heading_weight)
	var text_server := TextServerManager.get_primary_interface()
	var weight_tag := text_server.name_to_tag("wght")
	var actual_axes := text_server.font_get_variation_coordinates(title_font.get_rids()[0])
	assert(actual_axes.has(weight_tag) and is_equal_approx(actual_axes[weight_tag], Typography.heading_weight), "Renderer must apply configured heading weight")
	for locale: String in ["zh_CN", "en"]:
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/locales/"+locale+".json"))
		for text: String in source.messages.values():
			for index in range(text.length()):
				var code := text.unicode_at(index)
				if code > 32 and not font.has_char(code):
					missing[text[index]] = true
	for glyph: String in ["◇", "×"]:
		if not font.has_char(glyph.unicode_at(0)):
			missing[glyph] = true
	print("UI_TYPOGRAPHY family=",font.get_font_name()," renderer_axes=",actual_axes," missing_glyphs=",missing.keys())
	quit(0 if missing.is_empty() else 1)
