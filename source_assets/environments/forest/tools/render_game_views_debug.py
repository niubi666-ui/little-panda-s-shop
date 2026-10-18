"""Debug variant of render_game_views.py: render one view with only some light sources, to
compare light/shadow placement with the Godot room term by term.

    blender --background fairy_arena_game_v2.blend --python render_game_views_debug.py -- <out_dir> <view> <mode> [samples]

mode: sun (sun only), key (key light only), sky (world light only), nofog (all lights, no fog)."""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_game_views as views  # noqa: E402
import render_looks  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
out_dir, view, mode = args[0], args[1], args[2]
samples = int(args[3]) if len(args) > 3 else 48
views.LOOK = "fairy"
scene = bpy.context.scene
render_looks.apply("fairy", "cycles", samples)
views.place_lights()
background = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
if mode in ("sun", "key"):
    background.inputs[1].default_value = 0.0
    bpy.data.objects["LD_Fog"].hide_render = True
    for name in ("LD_Lantern",):
        if bpy.data.objects.get(name): bpy.data.objects[name].hide_render = True
    bpy.data.objects["LD_Key" if mode == "sun" else "LD_Sun"].hide_render = True
elif mode == "sky":
    for name in ("LD_Sun", "LD_Key", "LD_Lantern"):
        if bpy.data.objects.get(name): bpy.data.objects[name].hide_render = True
    bpy.data.objects["LD_Fog"].hide_render = True
elif mode == "nofog":
    bpy.data.objects["LD_Fog"].hide_render = True
for obj in bpy.data.objects:
    if obj.name == "Motes": obj.hide_render = True
# optional 5th argument: comma separated asset tags to hide (e.g. tree_a,tree_c)
hidden = args[4].split(",") if len(args) > 4 else []
for obj in bpy.data.collections["Layout"].objects:
    if obj.instance_collection and obj.instance_collection.name[2:] in hidden:
        obj.hide_render = True
if hidden:
    mode += "-no" + "-".join(hidden)
scene.render.resolution_x, scene.render.resolution_y = views.SIZE
scene.render.image_settings.file_format = "PNG"
scene.camera = views.camera_for(view)
scene.render.filepath = os.path.join(out_dir, "%s_cycles%s.png" % (view, mode))
bpy.ops.render.render(write_still=True)
print("RENDERED", scene.render.filepath)
