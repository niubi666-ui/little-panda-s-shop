extends Resource
## Decoration artwork and layout only. Gameplay values remain in the catalog.
## Fonts and font sizes are inherited from the injected shared UI theme.

@export var textures: Dictionary[String, Texture2D]
@export var icons: Dictionary[String, Texture2D]
@export var style_boxes: Dictionary[String, StyleBox]
@export var metrics: Dictionary[String, float]
@export var text_color: Color
@export var muted_color: Color
@export var valid_color: Color
@export var invalid_color: Color

## The authored PNGs are much larger than their UI use. These raster dimensions
## let the presentation factory preserve the corner art at logical UI size.
@export var style_texture_sizes: Dictionary[String, Vector2i]
@export var style_sources: Dictionary[String, String]
