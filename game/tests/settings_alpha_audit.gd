extends SceneTree
func _initialize():
 var skin = load("res://presentation/settings/settings_skin.tres")
 for key in skin.textures:
  var image: Image = skin.textures[key].atlas.get_image()
  var bounds := Rect2i()
  var found := false
  for y in range(0,image.get_height(),2):
   for x in range(0,image.get_width(),2):
    if image.get_pixel(x,y).a > 0.9:
     if not found:
      bounds = Rect2i(x,y,1,1)
      found = true
     else: bounds = bounds.expand(Vector2i(x,y))
  print(key, " ", bounds)
 quit()
