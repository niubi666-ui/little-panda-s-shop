"""Render the game arena from the exact cameras the game uses.

These Cycles images are the target the Godot room (game/presentation/rooms/fairy_forest_v2) is
tuned against: same layout, same camera, same sun. Compare them with the Godot captures made by
game/tests/fairy_lookdev_capture.gd, which uses the same view names.

    blender --background fairy_arena_game.blend --python render_game_views.py -- <out_dir> [views] [samples] [look]

views: comma separated names from VIEWS (default: all). look: a look from render_looks.py (default: fairy).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_looks  # noqa: E402

# Camera position and look-at target in GODOT coordinates (y up, +z towards the player's
# camera). The first four are what the game camera shows (see combat_training.gd
# _follow_camera and fairy_forest_v2/presentation.tres); "hero" is a lower beauty angle.
VIEWS = {
    "game": ((0.0, 12.1, 20.9), (0.0, 0.7, 3.3)),
    "ruin": ((0.0, 12.1, 11.1), (0.0, 0.7, -6.5)),
    "far": ((0.0, 16.66, 23.14), (0.0, 0.7, -1.5)),
    "bridge": ((0.5, 12.1, 22.6), (0.5, 0.7, 5.0)),
    "hero": ((3.5, 5.2, 21.5), (0.0, 0.8, 4.0)),
    "top": ((0.0, 46.0, 0.5), (0.0, 0.0, 0.0)),
}
FOV_Y = 38.0                        # presentation.tres camera_fov (vertical)
KEY_TARGET = (0.3, 0.4, -9.2)       # room.tscn key_target, where the light shaft lands
SIZE = (1280, 800)


def blender(point):
    x, y, z = point
    return Vector((x, -z, y))


def place_lights():
    # render_looks aims the shaft and the lantern at the look-dev set; the arena moved them
    key = bpy.data.objects.get("LD_Key")
    if key is not None:
        direction = Vector(render_looks.LOOKS[LOOK]["sun_dir"]).normalized()
        key.location = blender(KEY_TARGET) + direction * 42.0
    lamp = bpy.data.objects.get("LD_Lantern")
    lantern = next((o for o in bpy.data.collections["Layout"].objects if o.name.startswith("lantern_")), None)
    if lamp is not None and lantern is not None:
        lamp.location = lantern.location + Vector((0.0, 0.0, 0.35))


def camera_for(name):
    position, target = VIEWS[name]
    data = bpy.data.cameras.new("GV_" + name)
    data.sensor_fit = "VERTICAL"
    data.angle_y = math.radians(FOV_Y)
    data.clip_end = 400.0
    camera = bpy.data.objects.new("GV_" + name, data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = blender(position)
    camera.rotation_euler = (blender(target) - blender(position)).to_track_quat("-Z", "Y").to_euler()
    return camera


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = args[0]
    views = args[1].split(",") if len(args) > 1 and args[1] else list(VIEWS)
    samples = int(args[2]) if len(args) > 2 else 96
    LOOK = args[3] if len(args) > 3 else "fairy"
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    render_looks.apply(LOOK, "cycles", samples)
    place_lights()
    scene.render.resolution_x, scene.render.resolution_y = SIZE
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    for name in views:
        scene.camera = camera_for(name)
        scene.render.filepath = os.path.join(out_dir, "%s_cycles.png" % name)
        bpy.ops.render.render(write_still=True)
        print("RENDERED", scene.render.filepath)
