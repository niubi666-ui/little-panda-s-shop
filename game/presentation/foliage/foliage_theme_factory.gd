extends RefCounted
const BaseTheme = preload("res://presentation/foliage/foliage_theme.tres")
const Typography = preload("res://presentation/foliage/ui_typography.tres")

static func create() -> Theme:
	var result: Theme = BaseTheme.duplicate(true)
	Typography.apply_to(result)
	return result
