"""Game arena, second pass: the same clearing as build_game_arena.py, dressed the way the
look-dev scene is (a meadow of grass clumps and flower drifts instead of a bare lawn), and with
a Cycles ground material that mirrors the Godot ground shader, so a Cycles render of this file
is a fair target for the Godot room.

    blender --background fairy_forest_opt.blend --python build_game_arena_v2.py -- <godot_assets_dir>

Writes fairy_arena_game_v2.blend next to the source (with the original, Cycles-quality
materials) and exports into <godot_assets_dir> the same files as the first version
(library.glb, terrain.glb, layout.json, terrain/*.jpg). The first version's script, blend and
game assets are left untouched, so the game can go back to them.

Render the target views with render_game_views.py on fairy_arena_game_v2.blend.
"""
import math
import os
import re
import sys

import bpy
from mathutils import Vector, noise

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_game_arena as base  # noqa: E402

REPO = os.path.dirname(os.path.dirname(HERE))
GROUND_TRES = os.path.join(REPO, "game", "presentation", "rooms", "fairy_forest_v2", "ground_material.tres")
rng = base.rng
PX, PY = base.PLAY


# ------------------------------------------------------------------------------------------------
# Ground: a Cycles copy of game/presentation/rooms/fairy_forest_v2/terrain.gdshader
# ------------------------------------------------------------------------------------------------
def godot_parameters(path):
    """shader_parameter values from a Godot material .tres (floats and colours only)."""
    values = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            match = re.match(r"shader_parameter/(\w+) = (.+)", line.strip())
            if not match:
                continue
            name, raw = match.groups()
            colour = re.match(r"Color\(([^)]*)\)", raw)
            if colour:
                values[name] = tuple(float(v) for v in colour.group(1).split(","))[:3]
            else:
                try:
                    values[name] = float(raw)
                except ValueError:
                    pass
    return values


class Graph:
    """Small helper for building shader node trees from Python expressions."""

    def __init__(self, tree):
        self.tree = tree

    def node(self, kind, **settings):
        node = self.tree.nodes.new(kind)
        for key, value in settings.items():
            setattr(node, key, value)
        return node

    def feed(self, socket, value):
        if hasattr(value, "is_output") or hasattr(value, "links"):
            self.tree.links.new(value, socket)
        elif isinstance(value, (tuple, list)):
            socket.default_value = tuple(value) + ((1.0,) if len(value) == 3 and len(socket.default_value) == 4 else ())
        else:
            socket.default_value = value

    def math(self, operation, a, b=None, clamp=False):
        node = self.node("ShaderNodeMath", operation=operation, use_clamp=clamp)
        self.feed(node.inputs[0], a)
        if b is not None:
            self.feed(node.inputs[1], b)
        return node.outputs[0]

    def add(self, a, b):
        return self.math("ADD", a, b)

    def mul(self, a, b):
        return self.math("MULTIPLY", a, b)

    def sub(self, a, b):
        return self.math("SUBTRACT", a, b)

    def smooth(self, value, edge0, edge1, rising=True):
        """Godot smoothstep(edge0, edge1, value); rising=False gives 1 - smoothstep."""
        node = self.node("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP", clamp=True)
        self.feed(node.inputs["Value"], value)
        self.feed(node.inputs["From Min"], edge0)
        self.feed(node.inputs["From Max"], edge1)
        node.inputs["To Min"].default_value = 0.0 if rising else 1.0
        node.inputs["To Max"].default_value = 1.0 if rising else 0.0
        return node.outputs["Result"]

    def vec(self, x, y, z=0.0):
        node = self.node("ShaderNodeCombineXYZ")
        self.feed(node.inputs[0], x)
        self.feed(node.inputs[1], y)
        self.feed(node.inputs[2], z)
        return node.outputs[0]

    def noise(self, x, y, scale, offset):
        tex = self.node("ShaderNodeTexNoise")
        tex.inputs["Detail"].default_value = 0.0
        self.feed(tex.inputs["Vector"], self.vec(self.add(self.mul(x, scale), offset), self.add(self.mul(y, scale), offset)))
        tex.inputs["Scale"].default_value = 1.0
        return tex.outputs["Fac"]

    def image(self, image, x, y, scale, non_color=False):
        tex = self.node("ShaderNodeTexImage", image=image)
        self.feed(tex.inputs["Vector"], self.vec(self.math("DIVIDE", x, scale), self.math("DIVIDE", y, scale)))
        return tex.outputs["Color"]

    def mix(self, a, b, factor, blend="MIX"):
        node = self.node("ShaderNodeMix", data_type="RGBA", blend_type=blend, clamp_result=False)
        self.feed(node.inputs["Factor"], factor)
        self.feed(node.inputs[6], a)
        self.feed(node.inputs[7], b)
        return node.outputs[2]

    def mix_float(self, a, b, factor):
        node = self.node("ShaderNodeMix", data_type="FLOAT")
        self.feed(node.inputs["Factor"], factor)
        self.feed(node.inputs[2], a)
        self.feed(node.inputs[3], b)
        return node.outputs[0]


def image_for(material_name, key):
    material = bpy.data.materials[material_name]
    surface = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    socket = {"albedo": "Base Color", "normal": "Normal", "roughness": "Roughness"}[key]
    return base.upstream_image(surface.inputs[socket], key)


def arena_ground_material():
    p = godot_parameters(GROUND_TRES)
    material = bpy.data.materials.get("ArenaGround") or bpy.data.materials.new("ArenaGround")
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    g = Graph(tree)
    position = g.node("ShaderNodeNewGeometry").outputs["Position"]
    split = g.node("ShaderNodeSeparateXYZ")
    g.feed(split.inputs[0], position)
    bx, by, bz = split.outputs[0], split.outputs[1], split.outputs[2]

    wobble = g.mul(g.sub(g.noise(bx, by, 0.7, 0.0), 0.5), 0.9)
    # stream bed
    stream = g.add(g.add(-12.4, g.mul(1.2, g.math("SINE", g.add(g.mul(bx, 0.2), 0.4)))), g.mul(0.4, g.math("SINE", g.mul(bx, 0.53))))
    bed = g.smooth(g.add(g.math("ABSOLUTE", g.sub(by, stream)), g.mul(wobble, 0.5)), base.STREAM_HALF * 0.95, base.STREAM_HALF * 1.75, rising=False)
    # leaf-litter path from the bridge to the clearing
    path_centre = g.add(base.BRIDGE_X, g.mul(0.9, g.math("SINE", g.mul(g.add(by, 12.0), 0.22))))
    width = g.mul(g.mul(1.5, g.add(1.0, g.mul(0.25, g.math("SINE", g.mul(by, 0.5))))), g.smooth(by, 0.0, 3.5, rising=False))
    width = g.mul(width, g.math("GREATER_THAN", by, -28.0))
    path = g.smooth(g.add(g.math("ABSOLUTE", g.sub(bx, path_centre)), g.mul(wobble, 0.6)), g.mul(width, 0.5), width, rising=False)
    path = g.mul(path, g.math("GREATER_THAN", width, 0.05))
    blend = g.add(g.mul(g.noise(bx, by, 0.16, 9.0), 0.6), g.mul(g.noise(bx, by, 0.55, 3.0), 0.4))
    patches = g.mul(g.smooth(blend, 0.62, 0.8), p.get("litter_patches", 0.4))
    litter = g.math("MULTIPLY", g.math("MAXIMUM", path, patches), g.sub(1.0, bed), clamp=True)

    moss_scale, litter_scale, pebbles_scale = p.get("moss_scale", 3.0), p.get("litter_scale", 2.5), p.get("pebbles_scale", 1.8)
    contrast = p.get("macro_contrast", 0.36)
    moss = g.mix(g.image(image_for("Forest Floor Moss", "albedo"), bx, by, moss_scale), p.get("moss_tint", (1, 1, 1)), 1.0, "MULTIPLY")
    macro = g.add(1.0 - contrast * 0.5, g.mul(contrast, g.noise(bx, by, 0.09, 20.0)))
    moss = g.mix(moss, g.vec(macro, macro, macro), 1.0, "MULTIPLY")
    litter_colour = g.mix(g.image(image_for("Mossy Ground", "albedo"), bx, by, litter_scale), p.get("litter_tint", (1, 1, 1)), 1.0, "MULTIPLY")
    pebbles = g.mix(g.image(image_for("BrookBedMat", "albedo"), bx, by, pebbles_scale), p.get("wet_tint", (0.34, 0.4, 0.38)), 1.0, "MULTIPLY")
    colour = g.mix(g.mix(moss, litter_colour, litter), pebbles, bed)
    wet = g.smooth(bz, base.WATER_Z, base.WATER_Z + p.get("wet_band", 0.18), rising=False)
    shade = g.mix_float(1.0, 0.6, wet)
    colour = g.mix(colour, g.vec(shade, shade, shade), 1.0, "MULTIPLY")
    saturation = g.node("ShaderNodeHueSaturation")
    saturation.inputs["Saturation"].default_value = p.get("saturation", 1.0)
    g.feed(saturation.inputs["Color"], colour)

    rough = g.mix_float(g.image(image_for("Forest Floor Moss", "roughness"), bx, by, moss_scale),
                        g.image(image_for("Mossy Ground", "roughness"), bx, by, litter_scale), litter)
    rough = g.mix_float(g.mix_float(rough, 0.25, bed), 0.22, wet)
    normal_colour = g.mix(g.mix(g.image(image_for("Forest Floor Moss", "normal"), bx, by, moss_scale),
                                g.image(image_for("Mossy Ground", "normal"), bx, by, litter_scale), litter),
                          g.image(image_for("BrookBedMat", "normal"), bx, by, pebbles_scale), bed)
    for tex in [n for n in tree.nodes if n.type == "TEX_IMAGE"]:
        if tex.image is not None and tex.image.colorspace_settings.name != "sRGB":
            tex.interpolation = "Linear"
    normal = g.node("ShaderNodeNormalMap", space="TANGENT", uv_map="UVMap")
    g.feed(normal.inputs["Color"], normal_colour)

    surface = g.node("ShaderNodeBsdfPrincipled")
    g.feed(surface.inputs["Base Color"], saturation.outputs[0])
    g.feed(surface.inputs["Roughness"], rough)
    g.feed(surface.inputs["Normal"], normal.outputs[0])
    surface.inputs["IOR"].default_value = 1.45
    out = g.node("ShaderNodeOutputMaterial")
    g.feed(out.inputs["Surface"], surface.outputs[0])
    return material


def ground_v2():
    base.ground()
    mesh = bpy.data.objects["Ground"].data
    uv = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        co = mesh.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (co.x, co.y)
    mesh.materials.clear()
    mesh.materials.append(arena_ground_material())


# ------------------------------------------------------------------------------------------------
# Layout: the v1 clearing, plus a meadow inside it and fuller edges
# ------------------------------------------------------------------------------------------------
def meadow(x, y):
    """0..1: where the grass grows thick. Large soft patches with open moss between them."""
    n = noise.noise(Vector((x * 0.16, y * 0.16, 7.3))) * 0.75 + noise.noise(Vector((x * 0.47, y * 0.47, 2.1))) * 0.25
    return min(1.0, max(0.0, 0.5 + 0.9 * n))


def inside(x, y, grow=0.0):
    return abs(x) < PX + grow and abs(y) < PY + grow


def layout_v2():
    base.layout()
    lay = bpy.data.collections["Layout"]

    # thin out the v1 scatter inside the clearing: the meadow below replaces it
    for obj in list(lay.objects):
        tag = obj.instance_collection.name[2:]
        if tag in ("grass_a", "grass_b") and inside(obj.location.x, obj.location.y, 0.5):
            bpy.data.objects.remove(obj, do_unlink=True)

    # --- the meadow: clumps of grass in soft patches, the dirt path kept clear -------------------
    placed = 0
    guard = 0
    while placed < 1400 and guard < 60000:
        guard += 1
        x, y = rng.uniform(-PX - 1.0, PX + 1.0), rng.uniform(-PY - 1.0, PY + 1.0)
        if base.near_water(x, y, 0.2) or base.on_path(x, y, 0.9):
            continue
        thick = base.smooth(0.3, 0.68, meadow(x, y))
        if rng.random() > 0.06 + 0.94 * thick:
            continue
        if rng.random() < 0.45:
            base.place(lay, "grass_b", x, y, rng.uniform(0.75, 1.25), tilt=0.06)
        else:
            base.place(lay, "grass_a", x, y, rng.uniform(0.75, 1.35), tilt=0.05)
        placed += 1
    # the path edges are where grass grows tallest in the look-dev scene
    for i in range(140):
        y = rng.uniform(-11.0, 2.5)
        x = base.path_x(y) + rng.choice((-1, 1)) * rng.uniform(1.0, 2.2)
        if base.near_water(x, y, 0.3):
            continue
        base.place(lay, rng.choice(("grass_b", "grass_a")), x, y, rng.uniform(1.0, 1.6), tilt=0.06)

    # --- flower drifts inside the meadow ------------------------------------------------------------
    tags = ("flowers_violet", "flowers_pink", "flowers_white", "flowers_gold", "flowers_blue", "flowers_red", "daisies")
    drifts = 0
    guard = 0
    while drifts < 22 and guard < 4000:
        guard += 1
        cx, cy = rng.uniform(-PX + 1.0, PX - 1.0), rng.uniform(-PY + 1.0, PY - 1.0)
        if meadow(cx, cy) < 0.5 or base.on_path(cx, cy, 1.4):
            continue
        tag = tags[drifts % len(tags)]
        for i in range(rng.randint(8, 16)):
            x, y = cx + rng.gauss(0, 0.8), cy + rng.gauss(0, 0.8)
            if base.on_path(x, y, 1.0) or base.near_water(x, y, 0.3):
                continue
            scale = rng.uniform(0.55, 0.9) if tag.startswith("flowers") else rng.uniform(0.9, 1.3)
            base.place(lay, tag, x, y, scale)
        drifts += 1

    # --- the edge of the clearing: ferns and tall grass close in a little further -------------------
    for i in range(160):
        side = rng.choice(("w", "e", "n"))
        if side == "n":
            x, y = rng.uniform(-PX - 2.0, PX + 2.0), PY + rng.uniform(-0.6, 2.5)
        else:
            x, y = (1 if side == "e" else -1) * (PX + rng.uniform(-0.6, 2.5)), rng.uniform(-PY - 2.0, PY + 2.0)
        if base.near_water(x, y, 0.4) or base.on_path(x, y, 1.2):
            continue
        tag = rng.choice(("fern_a", "fern_a", "fern_b", "grass_b", "grass_b", "grass_a"))
        base.place(lay, tag, x, y, rng.uniform(0.9, 1.8) if tag.startswith("grass") else rng.uniform(0.7, 1.3), tilt=0.07)

    # --- blossom trees framing the brook at both sides (clear of the camera's view of the fight) -------
    for x, y, s in ((-13.5, -9.5, 1.0), (14.5, -10.5, 1.05), (-17.0, -3.0, 0.9), (17.5, 1.5, 0.95)):
        base.place(lay, "blossom", x, y, s, sink=0.1)
    print("GAME v2 layout objects:", len(lay.objects))


# ------------------------------------------------------------------------------------------------
# Export fix-up: colour under transparent texels
# ------------------------------------------------------------------------------------------------
def image_nodes(tree, seen=None):
    """Every image texture node in a node tree, including inside node groups."""
    seen = seen if seen is not None else set()
    found = []
    for node in tree.nodes:
        if node.type == "TEX_IMAGE" and node.image is not None:
            found.append(node)
        elif node.type == "GROUP" and node.node_tree is not None and node.node_tree.name not in seen:
            seen.add(node.node_tree.name)
            found += image_nodes(node.node_tree, seen)
    return found


def pixels_of(image):
    import numpy as np
    width, height = image.size
    data = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(data)
    return data.reshape(height, width, 4)


def bled_copy(image, mask, folder):
    """A PNG copy of image whose colour is pushed out under the transparent texels (mask < 0.6),
    so that mip-maps of thin blades keep their own colour instead of picking up the grey, black
    or white that the source files store there. That fringe is what turned the game's grass
    silver-grey at a distance; Cycles never filters these textures, so it never showed there."""
    import numpy as np
    import optimize_step1
    pixels = pixels_of(image)
    work = pixels.copy()
    work[..., 3] = mask
    optimize_step1.bleed(work, passes=24)
    pixels[..., :3] = work[..., :3]
    safe = re.sub(r"[^\w.-]+", "_", image.name.rsplit(".", 1)[0] if image.name.lower().endswith((".png", ".jpg", ".jpeg")) else image.name)
    copy = bpy.data.images.new(safe + "_bled", image.size[0], image.size[1], alpha=True)
    copy.pixels.foreach_set(pixels.ravel())
    copy.filepath_raw = os.path.join(folder, safe + "_bled.png")
    copy.file_format = "PNG"
    copy.save()
    copy.colorspace_settings.name = image.colorspace_settings.name
    return copy


def bleed_foliage_images():
    import numpy as np
    folder = os.path.join(HERE, "textures", "bled")
    os.makedirs(folder, exist_ok=True)
    library = bpy.data.collections["Library"]
    materials = {slot.material for obj in library.all_objects if obj.type == "MESH" for slot in obj.material_slots if slot.material}
    replaced = {}
    for material in materials:
        if not material.node_tree:
            continue
        surface = next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        separate_alpha = None
        if surface is not None and surface.inputs["Alpha"].is_linked:
            source = base.upstream_image_nodes(surface.inputs["Alpha"])
            colour = base.upstream_image(surface.inputs["Base Color"], "albedo")
            if source and colour is not None and source[0].image is not colour:
                separate_alpha = (colour, source[0].image)
        for node in image_nodes(material.node_tree):
            image = node.image
            if image in replaced:
                node.image = replaced[image]
                continue
            if separate_alpha is not None and image is separate_alpha[0]:
                mask = pixels_of(separate_alpha[1])[..., 0]
                if mask.shape != tuple(reversed(image.size)):
                    continue
            elif image.depth in (32, 64, 128) and max(image.size) <= 4096:      # RGBA only
                mask = pixels_of(image)[..., 3]
                if float((mask < 0.1).mean()) < 0.05:
                    continue
            else:
                continue
            replaced[image] = bled_copy(image, mask, folder)
            node.image = replaced[image]
            print("GAME bled", image.name, "->", replaced[image].name)
    return replaced


if __name__ == "__main__":
    args = [a for a in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []) if not a.startswith("--")]
    target = os.path.join(os.path.dirname(bpy.data.filepath), "fairy_arena_game_v2.blend")
    bpy.ops.wm.save_as_mainfile(filepath=target)
    ground_v2()
    layout_v2()
    # the saved file keeps the look-dev materials: it is the Cycles reference
    bpy.ops.wm.save_mainfile()
    print("GAME saved", target)
    if args:
        base.simplify_materials()       # glTF-only simplification, never saved
        bleed_foliage_images()
        base.export(args[0])
