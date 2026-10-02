class_name ShopPreviewRegistry
extends RefCounted
## Published only after the small preview manifest and all its definitions validate.
## Owned by bootstrap; consumers receive the narrow definition, not a global registry.

const Definition = preload("res://content/shop_preview/shop_preview_definition.gd")

var _content_version: String
var _shop_preview: Definition
var _foliage_preview: RefCounted


func _init(content_version: String, shop_preview: Definition, foliage_preview: RefCounted) -> void:
	_content_version = content_version
	_shop_preview = shop_preview
	_foliage_preview = foliage_preview

func get_foliage_preview() -> RefCounted:
	return _foliage_preview


func get_content_version() -> String:
	return _content_version


func get_shop_preview() -> Definition:
	return _shop_preview
