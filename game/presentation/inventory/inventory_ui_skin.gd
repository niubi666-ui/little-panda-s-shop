extends Resource
## Inventory appearance only; the sample catalog is not player inventory state.
## The injected shared Theme remains the authority for all fonts and font sizes.

@export var textures: Dictionary[String, Texture2D]
@export var items: Dictionary[String, Texture2D]
@export var icons: Dictionary[String, Texture2D]
@export var styles: Dictionary[String, StyleBox]
@export var metrics: Dictionary[String, float]
@export var text_color: Color
@export var muted_color: Color
@export var paper_color: Color
@export var disabled_color: Color
@export var hover_color: Color
@export var dim_color: Color

## Raster sizes and nine-slice cuts are authored in logical UI pixels.
## Preparing a skin crops the AtlasTexture before scaling its image.
@export var style_texture_sizes: Dictionary[String, Vector2i]
@export var style_sources: Dictionary[String, String]
