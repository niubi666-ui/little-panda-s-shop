"""把一个 .blend 里的 A_ 素材集合各渲一张小图（斜上方 35° 看过去），拼成一张总览。

    blender --background <文件.blend> --python tools/preview_assets.py -- <输出.png> [素材名,素材名]
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
only = set(args[1].split(",")) if len(args) > 1 and args[1] else None
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = 420
scene.render.film_transparent = False
world = bpy.data.worlds.new("preview") if scene.world is None else scene.world
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.62, 0.7, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
sun_data = bpy.data.lights.new("pv_sun", "SUN")
sun_data.energy = 3.5
sun = bpy.data.objects.new("pv_sun", sun_data)
sun.rotation_euler = (math.radians(50), 0, math.radians(35))
scene.collection.objects.link(sun)
cam_data = bpy.data.cameras.new("pv_cam")
cam = bpy.data.objects.new("pv_cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
names = sorted(c.name for c in bpy.data.collections if c.name.startswith("A_") and (only is None or c.name[2:] in only))
tiles = []
for name in names:
    inst = bpy.data.objects.new("pv_" + name, None)
    inst.instance_type = "COLLECTION"
    inst.instance_collection = bpy.data.collections[name]
    scene.collection.objects.link(inst)
    corners = [o.matrix_world @ Vector(c) for o in bpy.data.collections[name].all_objects if o.type == "MESH" for c in o.bound_box]
    low = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    high = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    centre = (low + high) / 2
    radius = max((high - low).length / 2, 0.2)
    direction = Vector((0.0, -math.cos(math.radians(35)), math.sin(math.radians(35))))
    cam.location = centre + direction * radius * 2.6
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    for other in scene.collection.objects:
        if other.name.startswith("pv_A_"):
            other.hide_render = other is not inst
    path = os.path.join(os.path.dirname(out), "_pv_%s.png" % name)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    image = bpy.data.images.load(path)
    w, h = image.size
    px = np.array(image.pixels[:], dtype=np.float32).reshape(h, w, 4)
    tiles.append(px)
    os.remove(path)
    print("PV", name, "size", tuple(round(v, 2) for v in (high - low)))
cols = 4
rows = (len(tiles) + cols - 1) // cols
sheet = np.ones((rows * 420, cols * 420, 4), dtype=np.float32)
for i, t in enumerate(tiles):
    r, c = divmod(i, cols)
    sheet[(rows - 1 - r) * 420:(rows - r) * 420, c * 420:(c + 1) * 420] = t
img = bpy.data.images.new("sheet", cols * 420, rows * 420, alpha=True)
img.pixels = sheet.ravel()
img.filepath_raw = out
img.file_format = "PNG"
img.save()
print("PV wrote", out)
