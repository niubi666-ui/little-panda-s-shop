"""Game version of the fairy forest: a flat combat clearing, laid out for the top-down camera,
exported for Godot.

blender --background fairy_forest_opt.blend --python build_game_arena.py -- <godot_assets_dir>

Writes fairy_arena_game.blend next to the source, and into <godot_assets_dir>:
  library.glb     every optimised asset, one node per library collection (A_<tag>)
  terrain.glb     the ground and the brook surface
  layout.json     where each asset instance stands (Blender axes; Godot converts)
  terrain/*.jpg   moss, leaf-litter and stream-bed texture sets for the ground shader

Differences from the look-dev scene: the fight happens on flat ground inside PLAY (the game
keeps characters at a fixed height), nothing tall stands between the camera and the
clearing, and the brook runs along the near edge instead of through the middle.
"""
import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

rng = random.Random(33)
scene = bpy.context.scene

PLAY = (9.5, 8.0)            # half extents of the walkable rectangle (x, y); Godot play_half
STREAM_HALF = 1.7
WATER_Z = -0.4
BRIDGE_X = 0.6


def stream_y(x):
    return -12.4 + 1.2 * math.sin(x * 0.2 + 0.4) + 0.4 * math.sin(x * 0.53)


def path_x(y):
    return BRIDGE_X + 0.9 * math.sin((y + 12.0) * 0.22)


def outside(x, y):
    """Distance outside the play rectangle (0 inside)."""
    return math.hypot(max(abs(x) - PLAY[0], 0.0), max(abs(y) - PLAY[1], 0.0))


def smooth(edge0, edge1, value):
    t = min(1.0, max(0.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def height(x, y):
    hills = noise.noise(Vector((x * 0.07, y * 0.07, 0.0))) * 1.0 + noise.noise(Vector((x * 0.25, y * 0.25, 3.0))) * 0.2
    base = hills * smooth(1.2, 8.0, outside(x, y))
    bank = max(0.0, 1.0 - abs(y - stream_y(x)) / (STREAM_HALF * 1.9))
    carve = bank * bank * (3.0 - 2.0 * bank)
    return base * (1.0 - 0.85 * carve) - 0.72 * carve


def collection(name, parent=None):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        (parent or scene.collection).children.link(col)
    return col


def clear(name):
    col = collection(name)
    for obj in list(col.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    return col


def place(layout, tag, x, y, scale=1.0, yaw=None, tilt=0.0, sink=0.0, z=None):
    col = bpy.data.collections.get("A_" + tag)
    if col is None:
        print("GAME missing asset", tag)
        return None
    obj = bpy.data.objects.new("%s_%04d" % (tag, len(layout.objects)), None)
    obj.instance_type = "COLLECTION"
    obj.instance_collection = col
    obj.empty_display_size = 0.2
    obj.location = (x, y, (height(x, y) - sink) if z is None else z)
    obj.rotation_euler = (rng.uniform(-tilt, tilt), rng.uniform(-tilt, tilt), rng.uniform(0, math.tau) if yaw is None else yaw)
    obj.scale = (scale,) * 3
    layout.objects.link(obj)
    return obj


def ground():
    obj = bpy.data.objects["Ground"]
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=200, y_segments=200, size=42.0)
    for vert in bm.verts:
        vert.co.z = height(vert.co.x, vert.co.y)
    for face in bm.faces:
        face.smooth = True
    mesh = bpy.data.meshes.new("Ground")
    bm.to_mesh(mesh)
    bm.free()
    obj.data = mesh
    water = bpy.data.objects["Brook"]
    bm = bmesh.new()
    previous = None
    for i in range(169):
        x = -42.0 + i * 0.5
        pair = (bm.verts.new((x, stream_y(x) - STREAM_HALF * 1.6, WATER_Z)), bm.verts.new((x, stream_y(x) + STREAM_HALF * 1.6, WATER_Z)))
        if previous is not None:
            bm.faces.new((previous[0], pair[0], pair[1], previous[1])).smooth = True
        previous = pair
    mesh = bpy.data.meshes.new("Brook")
    bm.to_mesh(mesh)
    bm.free()
    material = water.data.materials[0] if water.data.materials else None
    water.data = mesh
    if material is not None:
        mesh.materials.append(material)
    for name in ("PathPatch", "BrookBed"):       # the Godot ground shader draws these as masks
        stale = bpy.data.objects.get(name)
        if stale is not None:
            bpy.data.objects.remove(stale, do_unlink=True)


def near_water(x, y, margin=0.5):
    return abs(y - stream_y(x)) < STREAM_HALF + margin


def on_path(x, y, margin):
    return -26.0 < y < 2.0 and abs(x - path_x(y)) < margin


def layout():
    lay = clear("Layout")
    px, py = PLAY

    # --- the ruin behind the clearing: where the light shaft lands --------------------------
    place(lay, "pillar", -2.4, py + 1.9, 1.0, yaw=0.3)
    place(lay, "pillar", 2.9, py + 2.6, 0.82, yaw=1.9, tilt=0.06)
    place(lay, "pillar", 0.4, py + 4.6, 0.55, yaw=1.1, tilt=0.5, sink=0.5)
    place(lay, "moss_stone", 0.2, py + 1.5, 0.9, yaw=0.8, sink=0.12)
    place(lay, "moss_stone", -5.4, py + 1.4, 0.7, yaw=2.6, sink=0.15)
    place(lay, "lantern", 1.7, py + 0.9, 1.0, yaw=0.4, sink=-0.02)
    place(lay, "boulder", 5.6, py + 1.7, 1.2, sink=0.3)
    place(lay, "boulder", -8.2, py + 2.4, 1.5, sink=0.35)

    # --- edge dressing: low things that mark where the clearing ends --------------------------
    place(lay, "log_b", -px - 1.6, -1.5, 1.0, yaw=1.45)
    place(lay, "log_b", px + 1.4, 3.6, 0.9, yaw=1.75)
    place(lay, "stump", px + 1.3, -3.2, 1.0)
    place(lay, "stump", -px - 1.4, 4.4, 0.85)
    place(lay, "stump", -6.4, -py - 1.3, 0.8)
    place(lay, "boulder", px + 1.9, -6.6, 1.0, sink=0.3)
    place(lay, "boulder", -px - 2.2, -6.0, 1.3, sink=0.3)
    place(lay, "bridge", BRIDGE_X + 0.25, stream_y(BRIDGE_X), 1.0, yaw=math.pi / 2, z=0.42)

    # --- blossom trees at the corners and sides, far enough out not to hide the fight -------
    for x, y, s in ((-px - 3.4, py + 2.6, 1.0), (px + 3.8, py + 3.4, 1.1), (-px - 4.4, 0.6, 0.95), (px + 4.6, -1.4, 0.95), (3.4, py + 7.4, 1.15), (-5.6, py + 8.2, 1.0),
                    (-6.8, py + 3.6, 0.9), (7.4, py + 4.4, 0.95), (-0.8, py + 11.5, 1.2), (px + 3.2, 4.6, 0.85), (-px - 3.0, 5.4, 0.9)):
        place(lay, "blossom", x, y, s, sink=0.1)

    # --- tall forest: behind and beside the clearing, never between it and the camera --------
    taken = []
    def far_enough(x, y, gap):
        return all((x - tx) ** 2 + (y - ty) ** 2 > gap * gap for tx, ty in taken)
    count = 0
    while count < 36:
        x, y = rng.uniform(-34, 34), rng.uniform(-22, 34)
        # trunks crowd in at the back and the far half of the sides; the near half of the sides
        # stays open so no crown hangs between the camera and the fight
        side = abs(x) > px + (3.2 if y > 1.0 else 6.5)
        behind = y > py + 3.6
        if not (side or behind) or (y < -py - 1.0 and abs(x) < 17.0) or near_water(x, y, 2.0):
            continue
        if not far_enough(x, y, 4.4):
            continue
        taken.append((x, y))
        place(lay, rng.choice(("tree_a", "tree_a", "tree_c")), x, y, rng.uniform(0.8, 1.15), tilt=0.03, sink=0.2)
        count += 1

    # --- understorey: dense outside the clearing, a light scatter just inside its edge ---------
    def dress(tags, amount, zone, scales, tilt=0.06, keep_out=1.0, inside_share=0.0, path_gap=1.5):
        placed = 0
        guard = 0
        while placed < amount and guard < amount * 40:
            guard += 1
            x, y = rng.uniform(zone[0], zone[1]), rng.uniform(zone[2], zone[3])
            distance = outside(x, y)
            if distance < keep_out:
                inner = min(px - abs(x), py - abs(y))          # how deep inside the rectangle
                if not (distance == 0.0 and inner < 1.6 and rng.random() < inside_share):
                    continue
            if near_water(x, y) or on_path(x, y, path_gap):
                continue
            place(lay, rng.choice(tags), x, y, rng.uniform(*scales), tilt=tilt)
            placed += 1

    dress(("fern_a", "fern_a", "fern_b"), 230, (-24, 24, -22, 24), (0.7, 1.5), tilt=0.08, keep_out=0.8)
    dress(("grass_a", "grass_a", "grass_b"), 1500, (-22, 22, -22, 22), (1.2, 2.6), keep_out=0.3, inside_share=0.7)
    dress(("grass_a",), 260, (-px, px, -py, py), (0.7, 1.2), keep_out=0.0, inside_share=1.0)
    dress(("grass_b",), 160, (-px, px, -py, py), (0.6, 1.0), keep_out=0.0, inside_share=1.0)
    dress(("bush", "shrub", "shrub"), 30, (-24, 24, -21, 24), (0.7, 1.3), keep_out=2.2)
    dress(("rock",), 46, (-22, 22, -20, 22), (0.5, 1.8), tilt=0.3, keep_out=0.6)

    # --- flowers in single-colour drifts around the edge; a few spill inside ---------------------
    drifts = [(-px - 1.6, 5.2, "flowers_violet", 26, 1.2), (px + 1.8, 1.0, "flowers_pink", 22, 1.1), (-3.6, py + 0.6, "flowers_white", 18, 1.0),
              (px + 1.2, -6.2, "flowers_gold", 20, 1.1), (-px - 0.8, -4.6, "flowers_blue", 24, 1.3), (5.2, -py - 0.9, "flowers_violet", 20, 1.1),
              (-4.4, -py - 1.2, "flowers_pink", 18, 1.0), (7.6, py + 0.8, "flowers_blue", 18, 1.1), (-9.6, py + 0.4, "flowers_gold", 16, 1.0),
              (3.2, py + 0.5, "daisies", 14, 0.9), (-px - 0.6, -0.4, "daisies", 12, 0.9), (px + 0.4, 6.4, "flowers_red", 22, 1.0),
              (-1.4, -py - 2.4, "flowers_red", 14, 0.8), (2.8, -py - 2.0, "flowers_white", 14, 0.9)]
    for cx, cy, tag, amount, spread in drifts:
        for i in range(amount):
            x, y = cx + rng.gauss(0, spread), cy + rng.gauss(0, spread)
            inner = min(px - abs(x), py - abs(y))
            if inner > 1.3 or near_water(x, y) or on_path(x, y, 1.2):
                continue
            place(lay, tag, x, y, rng.uniform(0.5, 0.95) if tag.startswith("flowers") else rng.uniform(0.9, 1.5))

    # --- the brook in the foreground ---------------------------------------------------------------
    for i in range(50):
        x = rng.uniform(-24, 24)
        y = stream_y(x) + rng.choice((-1, 1)) * rng.uniform(STREAM_HALF * 0.7, STREAM_HALF * 1.7)
        if abs(x - BRIDGE_X) > 1.7:
            place(lay, "rock", x, y, rng.uniform(0.5, 1.3), tilt=0.4, sink=0.12)
    for x in (-17.0, -10.5, -4.5, 5.5, 11.5, 18.0):
        place(lay, "river_rocks", x, stream_y(x) + rng.uniform(-0.3, 0.3), rng.uniform(0.7, 1.0), z=WATER_Z - 0.36)
    for x in (-7.4, -6.6, 3.6, 4.5, 9.0, -13.0):
        place(lay, "lily", x, stream_y(x) + rng.uniform(-0.6, 0.6), rng.uniform(0.8, 1.3), z=WATER_Z + 0.01)

    # --- toadstool rings by stumps, logs and roots ---------------------------------------------------
    for cx, cy, amount in ((px + 1.7, -2.6, 5), (-px - 1.8, 4.9, 4), (-px - 1.2, -2.2, 4), (-0.6, py + 1.9, 3), (-6.0, -py - 1.8, 4), (px + 1.0, 4.4, 3)):
        for i in range(amount):
            a = rng.uniform(0, math.tau)
            place(lay, "toadstool", cx + math.cos(a) * rng.uniform(0.2, 0.7), cy + math.sin(a) * rng.uniform(0.2, 0.7), rng.uniform(0.6, 1.4), tilt=0.15)

    # --- butterflies over the flowers ---------------------------------------------------------------------
    for cx, cy, tag, amount, spread in drifts[:8]:
        for i in range(2):
            x, y = cx + rng.gauss(0, 0.8), cy + rng.gauss(0, 0.8)
            obj = place(lay, "butterfly", x, y, rng.uniform(0.8, 1.3), z=height(x, y) + rng.uniform(0.5, 1.6))
            obj.rotation_euler = (rng.uniform(-0.5, 0.5), rng.uniform(-0.4, 0.4), rng.uniform(0, math.tau))
    print("GAME layout objects:", len(lay.objects))


# ------------------------------------------------------------------------------------------------
# Export
# ------------------------------------------------------------------------------------------------
def upstream_images(socket, depth=0):
    """Every image feeding a socket, nearest first, with the node type it plugs into."""
    if not socket.is_linked or depth > 6:
        return []
    node = socket.links[0].from_node
    if node.type == "TEX_IMAGE" and node.image is not None:
        return [(node.image, socket.node.type)]
    found = []
    for candidate in node.inputs:
        found += upstream_images(candidate, depth + 1)
    return found


def upstream_image_nodes(socket, depth=0):
    if not socket.is_linked or depth > 6:
        return []
    node = socket.links[0].from_node
    if node.type == "TEX_IMAGE" and node.image is not None:
        return [node]
    found = []
    for candidate in node.inputs:
        found += upstream_image_nodes(candidate, depth + 1)
    return found


def upstream_image(socket, key="albedo"):
    """The colour chain often multiplies an AO map in, and a normal chain may add a bump made
    from the colour map; pick the image that really is what the key asks for."""
    found = upstream_images(socket)
    if key == "albedo":
        found = [f for f in found if f[0].colorspace_settings.name == "sRGB"] or found
    elif key == "normal":
        found = [f for f in found if f[1] == "NORMAL_MAP"]
    return found[0][0] if found else None


def export_texture_set(material_name, prefix, out_dir):
    material = bpy.data.materials.get(material_name)
    if material is None or not material.node_tree:
        print("GAME no material", material_name)
        return {}
    surface = next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    result = {}
    for key, socket_name in (("albedo", "Base Color"), ("normal", "Normal"), ("roughness", "Roughness")):
        image = upstream_image(surface.inputs[socket_name], key) if surface is not None else None
        if image is None:
            continue
        copy = image.copy()
        if max(copy.size) > 2048:
            factor = 2048.0 / max(copy.size)
            copy.scale(int(copy.size[0] * factor), int(copy.size[1] * factor))
        path = os.path.join(out_dir, "%s_%s.jpg" % (prefix, key))
        copy.filepath_raw = path
        copy.file_format = "JPEG"
        copy.save()
        bpy.data.images.remove(copy)
        result[key] = os.path.basename(path)
    print("GAME textures", prefix, result)
    return result


def simplify_materials():
    """glTF can only carry a plain Principled setup. Card materials use a transparent /
    translucent mix that it cannot read, so give them a plain one. Any material that cuts
    its shape out with alpha gets a FOL_ prefix; Godot keys foliage settings off that."""
    for material in bpy.data.materials:
        if not material.node_tree:
            continue
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        surface = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
        out = next((n for n in nodes if n.type == "OUTPUT_MATERIAL" and n.is_active_output), None)
        if out is None:
            continue
        cut = False
        if material.name in ("BlossomCards", "GrassCards", "FlowerCards") or (surface is not None and out.inputs["Surface"].is_linked and out.inputs["Surface"].links[0].from_node.type == "MIX_SHADER"):
            texture = next((n for n in nodes if n.type == "TEX_IMAGE" and n.image is not None), None)
            if surface is None:
                surface = nodes.new("ShaderNodeBsdfPrincipled")
            if texture is not None and material.name.endswith("Cards"):
                links.new(texture.outputs["Color"], surface.inputs[0])
                links.new(texture.outputs["Alpha"], surface.inputs["Alpha"])
                surface.inputs["Roughness"].default_value = 0.7
                cut = True
            links.new(surface.outputs[0], out.inputs["Surface"])
        if surface is not None and surface.inputs["Alpha"].is_linked:
            cut = True
        # Colour chains that multiply an AO map in (or tint through a mix) confuse the exporter:
        # it grabs the first image it meets, which is often the AO map. Wire the colour map
        # straight in instead.
        if surface is not None:
            base = surface.inputs["Base Color"]
            if base.is_linked and base.links[0].from_node.type != "TEX_IMAGE":
                colour = next((n for n in upstream_image_nodes(base) if n.image.colorspace_settings.name == "sRGB"), None)
                if colour is not None:
                    links.new(colour.outputs["Color"], base)
        if cut and not material.name.startswith("FOL_"):
            material.name = "FOL_" + material.name


def export(out_dir):
    os.makedirs(os.path.join(out_dir, "terrain"), exist_ok=True)
    lay = bpy.data.collections["Layout"]
    used = sorted({obj.instance_collection.name for obj in lay.objects if obj.instance_collection})
    instances = []
    for obj in lay.objects:
        matrix = Matrix.LocRotScale(obj.location, obj.rotation_euler, obj.scale)
        instances.append({"asset": obj.instance_collection.name[2:], "m": [round(v, 5) for row in matrix for v in row]})
    textures = export_terrain_textures(out_dir)
    data = {"play_half": list(PLAY), "water_z": WATER_Z, "stream_half": STREAM_HALF, "bridge_x": BRIDGE_X,
            "assets": [name[2:] for name in used], "terrain_textures": textures, "instances": instances}
    with open(os.path.join(out_dir, "layout.json"), "w", encoding="utf-8") as handle:
        json.dump(data, handle, separators=(",", ":"))

    root = bpy.context.view_layer.layer_collection
    def set_visibility(library_on):
        for child in root.children:
            child.exclude = (child.name != "Library") if library_on else (child.name in ("Library", "Layout", "Motes"))
        if library_on:
            for child in root.children["Library"].children:
                child.exclude = child.name not in used
        for obj in scene.collection.objects:
            obj.hide_set(library_on or obj.name not in ("Ground", "Brook"))
    common = dict(export_format="GLB", use_visible=True, export_apply=True, export_yup=True, export_animations=False,
                  export_cameras=False, export_lights=False, export_materials="EXPORT", export_tangents=True)
    # Baked maps were written as PNG; they have no alpha, so hand them over as JPEG and keep
    # the file small. (WebP would be smaller still, but this Godot build rejects WebP-only
    # glTF textures.) Card atlases need their alpha and stay PNG.
    here = os.path.dirname(os.path.abspath(__file__))
    for image in bpy.data.images:
        if "_baked_" in image.name and image.file_format != "JPEG" and image.size[0] > 0:
            image.pixels[0]                                   # make sure the pixels are loaded
            image.file_format = "JPEG"
            image.filepath_raw = os.path.join(here, "textures", image.name + ".jpg")
            image.save()
    set_visibility(True)
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "library.glb"), export_hierarchy_full_collections=True,
                              export_image_format="AUTO", **common)
    for child in root.children:
        child.exclude = child.name == "Library"
    for obj in scene.collection.objects:
        obj.hide_set(False)
    export_terrain(out_dir)
    print("GAME exported", len(instances), "instances of", len(used), "assets to", out_dir)


def export_terrain_textures(out_dir):
    folder = os.path.join(out_dir, "terrain")
    os.makedirs(folder, exist_ok=True)
    return {
        "moss": export_texture_set("Forest Floor Moss", "moss", folder),
        "litter": export_texture_set("Mossy Ground", "litter", folder),
        "pebbles": export_texture_set("BrookBedMat", "pebbles", folder),
    }


def export_terrain(out_dir):
    """Only the two surfaces, and without materials: Godot shades both itself."""
    bpy.context.view_layer.update()
    for obj in bpy.context.view_layer.objects:
        obj.select_set(obj.name in ("Ground", "Brook"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "terrain.glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_animations=False, export_cameras=False,
                              export_lights=False, export_materials="NONE", export_tangents=False)
    print("GAME terrain exported")


if __name__ == "__main__":
    args = [a for a in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []) if not a.startswith("--")]
    if "--terrain-only" in sys.argv:                      # run on fairy_arena_game.blend itself
        export_terrain_textures(args[0])
        export_terrain(args[0])
        sys.exit(0)
    target = os.path.join(os.path.dirname(bpy.data.filepath), "fairy_arena_game.blend")
    bpy.ops.wm.save_as_mainfile(filepath=target)
    ground()
    layout()
    simplify_materials()
    bpy.ops.wm.save_mainfile()
    if args:
        export(args[0])
        bpy.ops.wm.save_mainfile()
    print("GAME saved", target)
