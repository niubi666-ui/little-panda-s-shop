"""Render the forest look-dev scene under several lighting directions.

blender --background forest_lookdev.blend --python render_looks.py -- <out_dir> [look,look] [width] [engine] [samples]
Looks only add lights, world, fog and colour grading on top of the saved layout.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

LOOKS = {
    # warm low sun through cool forest shade: strong shafts, deep but readable shadows
    "golden": dict(sun_dir=(-0.6, 0.5, 0.55), sun_color=(1.0, 0.74, 0.45), sun=4.0, angle=1.0,
                   key=1800000, key_cone=15, lantern=0,
                   sky=(0.05, 0.085, 0.14), sky_strength=1.0, fog=0.011, fog_color=(1.0, 0.88, 0.72), aniso=0.75,
                   exposure=0.0, look="AgX - Medium High Contrast", fill=(0.35, 0.5, 0.9), fill_power=0),
    # fairy tale: the golden shaft, but with luminous green-blue shade instead of deep shadow,
    # lighter haze and richer colour, so flowers and water stay readable everywhere
    "fairy": dict(sun_dir=(-0.58, 0.5, 0.62), sun_color=(1.0, 0.8, 0.56), sun=4.2, angle=1.2,
                  key=1700000, key_cone=19, lantern=40,
                  sky=(0.1, 0.2, 0.26), sky_strength=1.6, fog=0.008, fog_color=(1.0, 0.9, 0.8), aniso=0.78,
                  exposure=0.25, look="AgX - Medium High Contrast", fill=(0.5, 0.8, 1.0), fill_power=0),
    # late morning: bright, airy, green and gentle; soft dapples, thin haze
    "daylight": dict(sun_dir=(-0.4, 0.3, 0.86), sun_color=(1.0, 0.96, 0.88), sun=4.2, angle=1.6,
                     key=500000, key_cone=24, lantern=0,
                     sky=(0.3, 0.44, 0.62), sky_strength=1.0, fog=0.004, fog_color=(0.92, 0.98, 1.0), aniso=0.55,
                     exposure=-0.35, look="AgX - Base Contrast", fill=(0.7, 0.85, 1.0), fill_power=0),
    # blue hour: cool moonlit shade, the lantern is the only warm thing in frame
    "dusk": dict(sun_dir=(0.45, 0.55, 0.6), sun_color=(0.5, 0.68, 1.0), sun=0.9, angle=2.0,
                 key=200000, key_cone=18, lantern=320,
                 sky=(0.018, 0.04, 0.09), sky_strength=1.0, fog=0.012, fog_color=(0.55, 0.72, 1.0), aniso=0.6,
                 exposure=1.3, look="AgX - Medium High Contrast", fill=(1.0, 0.62, 0.3), fill_power=0),
}


def remove(prefix):
    for obj in [o for o in bpy.data.objects if o.name.startswith(prefix)]:
        bpy.data.objects.remove(obj, do_unlink=True)


def apply(look, engine, samples):
    scene = bpy.context.scene
    cfg = LOOKS[look]
    remove("LD_")
    # sun
    data = bpy.data.lights.new("LD_Sun", "SUN")
    data.energy = cfg["sun"]
    data.color = cfg["sun_color"]
    data.angle = math.radians(cfg["angle"])
    sun = bpy.data.objects.new("LD_Sun", data)
    scene.collection.objects.link(sun)
    sun.rotation_euler = Vector(cfg["sun_dir"]).normalized().to_track_quat("Z", "Y").to_euler()
    # hero shaft: a narrow beam along the sun direction that lands on the ruin, the way a
    # gap in the canopy would. This is what puts the "pool of light" where we want it.
    if cfg.get("key", 0) > 0:
        key_data = bpy.data.lights.new("LD_Key", "SPOT")
        key_data.energy = cfg["key"]
        key_data.color = cfg["sun_color"]
        key_data.spot_size = math.radians(cfg.get("key_cone", 16))
        key_data.spot_blend = 0.55
        key_data.shadow_soft_size = 0.4
        key = bpy.data.objects.new("LD_Key", key_data)
        direction = Vector(cfg["sun_dir"]).normalized()
        target = Vector((0.2, 1.6, 0.4))
        key.location = target + direction * 42.0
        key.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
        scene.collection.objects.link(key)
    # the lantern on the ruin
    if cfg.get("lantern", 0) > 0:
        lamp_data = bpy.data.lights.new("LD_Lantern", "POINT")
        lamp_data.energy = cfg["lantern"]
        lamp_data.color = (1.0, 0.56, 0.22)
        lamp_data.shadow_soft_size = 0.08
        lamp = bpy.data.objects.new("LD_Lantern", lamp_data)
        lamp.location = (0.9, 1.1, 0.42)
        scene.collection.objects.link(lamp)
    # a soft local light on the ruin (bounce stand-in)
    if cfg["fill_power"] > 0:
        fill_data = bpy.data.lights.new("LD_Fill", "POINT")
        fill_data.energy = cfg["fill_power"]
        fill_data.color = cfg["fill"]
        fill_data.shadow_soft_size = 0.6
        fill = bpy.data.objects.new("LD_Fill", fill_data)
        fill.location = (0.4, 1.4, 2.2)
        scene.collection.objects.link(fill)
    # world
    world = bpy.data.worlds.new("LD_World")
    world.use_nodes = True
    # look nodes up by type: node names are translated when Blender's UI is not English
    background = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    background.inputs[0].default_value = (*cfg["sky"], 1.0)
    background.inputs[1].default_value = cfg["sky_strength"]
    scene.world = world
    # fog volume
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 14))
    box = bpy.context.active_object
    box.name = "LD_Fog"
    box.scale = (90, 90, 30)
    material = bpy.data.materials.new("LD_FogMat")
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    out = tree.nodes.new("ShaderNodeOutputMaterial")
    volume = tree.nodes.new("ShaderNodeVolumePrincipled")
    volume.inputs["Color"].default_value = (*cfg["fog_color"], 1.0)
    volume.inputs["Density"].default_value = cfg["fog"]
    volume.inputs["Anisotropy"].default_value = cfg["aniso"]
    tree.links.new(volume.outputs["Volume"], out.inputs["Volume"])
    box.data.materials.append(material)
    box.display_type = "WIRE"
    # colour
    scene.view_settings.view_transform = "AgX"
    try:
        scene.view_settings.look = cfg["look"]
    except TypeError:
        pass
    scene.view_settings.exposure = cfg["exposure"]
    # engine
    if engine == "cycles":
        scene.render.engine = "CYCLES"
        scene.cycles.samples = samples
        scene.cycles.use_denoising = True
        scene.cycles.volume_bounces = 1
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for kind in ("OPTIX", "CUDA"):
            try:
                prefs.compute_device_type = kind
                prefs.get_devices()
                for device in prefs.devices:
                    device.use = True
                scene.cycles.device = "GPU"
                break
            except Exception:
                continue
    else:
        scene.render.engine = "BLENDER_EEVEE"
        eevee = scene.eevee
        eevee.taa_render_samples = samples
        for name, value in (("use_raytracing", True), ("use_shadows", True), ("volumetric_tile_size", "4"),
                            ("volumetric_samples", 128), ("volumetric_end", 120.0), ("use_volumetric_shadows", True),
                            ("volumetric_shadow_samples", 32), ("use_gtao", True)):
            try:
                setattr(eevee, name, value)
            except (AttributeError, TypeError):
                print("eevee setting skipped:", name)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    out_dir = args[0]
    looks = args[1].split(",") if len(args) > 1 else list(LOOKS)
    width = int(args[2]) if len(args) > 2 else 1600
    engine = args[3] if len(args) > 3 else "eevee"
    samples = int(args[4]) if len(args) > 4 else 64
    prefix = args[5] if len(args) > 5 else "forest"
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    scene.render.resolution_x = width
    scene.render.resolution_y = int(width * 9 / 16)
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    for look in looks:
        apply(look, engine, samples)
        scene.render.filepath = os.path.join(out_dir, "%s_%s_%s.png" % (prefix, look, engine))
        bpy.ops.render.render(write_still=True)
        print("RENDERED", scene.render.filepath)
