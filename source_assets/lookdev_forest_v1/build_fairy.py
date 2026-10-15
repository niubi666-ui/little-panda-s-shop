"""Fairy-tale variant of the forest look-dev scene (fairy_forest.blend).

Run inside the Blender session that holds the downloaded assets, with fairy_forest.blend
open. Rebuilds ground (now with a stream bed), water, layout and camera. Safe to re-run.
"""
import math
import random

import bmesh
import bpy
from mathutils import Vector, noise

rng = random.Random(21)
scene = bpy.context.scene

# tag -> (root object, scale, extra loose objects that belong to the asset e.g. particle instances)
ASSETS = {
    "tree_a": ("Forest Tree", 0.8, ()),
    "tree_c": ("Pine Tree", 0.8, ()),
    "blossom": ("Blossoming Tree", 1.25, ()),
    "fern_a": ("Cinnamon Fern", 0.9, ()),
    "fern_b": ("Fern Plant", 0.8, ()),
    "grass_a": ("Realistic grass clump", 1.6, ()),
    "grass_b": ("High grass clump", 6.0, ()),
    "log_a": ("3D Scanned tree stump and fallen log", 1.6, ()),
    "log_b": ("Fallen 3D Scanned tree 5.5m long", 1.0, ()),
    "stump": ("Tree Stump with Mushrooms", 2.6, ()),
    "pillar": ("Ancient Mossy Stone Pillar", 0.5, ()),
    "boulder": ("Mossy Boulder Rock", 2.4, ()),
    "rock": ("Mossy Rock.006", 1.6, ()),
    "moss_stone": ("Moss Stone", 1.0, ()),
    "river_rocks": ("Sharp River Rocks", 0.6, ()),
    "bush": ("Wild Bush with Red Leaf Cluster", 1.0, ()),
    "shrub": ("Bush", 0.5, ()),
    "lantern": ("Old lantern", 2.4, ()),
    "flowers_white": ("Wild White Flower Patch", 2.6, ()),
    "daisies": ("Marguerite flowers", 1.0, ()),
    "poppy": ("poppy", 1.0, ()),
    "toadstool": ("Mushroom II (Amanita muscaria)", 2.2, ()),
    "butterfly": ("Common Blue Butterfly", 5.0, ()),
    "bridge": ("Wooden Bridge.001", 0.42, ()),
    "lily": ("Low Poly Water Lily", 2.2, ()),
}
# tag -> longest side in metres
FIT = {"blossom": 7.5, "daisies": 0.5, "poppy": 0.45, "toadstool": 0.42, "butterfly": 0.16, "bridge": 4.6, "lily": 0.55}
FLOWER_TINTS = {"flowers_violet": (0.42, 0.25, 0.9), "flowers_pink": (1.0, 0.36, 0.6), "flowers_gold": (1.0, 0.72, 0.12), "flowers_blue": (0.25, 0.5, 1.0), "flowers_red": (0.86, 0.07, 0.05)}

STREAM_HALF = 1.9
BRIDGE_Y = -5.2


def path_x(y):
    return math.sin(y * 0.16) * 1.6 - 0.4 * math.sin(y * 0.41)


def stream_y(x):
    """The brook runs left to right in front of the ruin."""
    return BRIDGE_Y + 1.5 * math.sin(x * 0.2 + 0.4) + 0.5 * math.sin(x * 0.53) - 0.05 * x


def stream_distance(x, y):
    return abs(y - stream_y(x))


def height(x, y):
    n = noise.noise(Vector((x * 0.07, y * 0.07, 0.0))) * 1.1 + noise.noise(Vector((x * 0.25, y * 0.25, 3.0))) * 0.22
    calm = min(1.0, max(0.0, (math.hypot(x, y) - 5.0) / 9.0))
    base = n * (0.12 + 0.88 * calm)
    d = stream_distance(x, y)
    bank = max(0.0, 1.0 - d / (STREAM_HALF * 1.9))
    carve = bank * bank * (3.0 - 2.0 * bank)
    return base * (1.0 - 0.8 * carve) - 0.75 * carve


WATER_Z = -0.42


def collection(name, parent=None):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        (parent or scene.collection).children.link(col)
    return col


def move_tree(obj, col):
    for other in list(obj.users_collection):
        other.objects.unlink(obj)
    col.objects.link(obj)
    for child in obj.children:
        move_tree(child, col)


def library():
    lib = collection("Library")
    for tag, (root_name, scale, extras) in ASSETS.items():
        root = bpy.data.objects.get(root_name)
        if root is None:
            print("MISSING asset", tag, root_name)
            continue
        col = collection("A_" + tag, lib)
        move_tree(root, col)
        root.location = (0, 0, 0)
        root.rotation_euler = (0, 0, 0)
        root.scale = (scale,) * 3
        for name in extras:
            extra = bpy.data.objects.get(name)
            if extra is not None:
                parts = collection("A_" + tag + "_parts", lib)
                move_tree(extra, parts)
    # the bridge mesh was authored far from its root
    bridge = bpy.data.objects.get("Bridge")
    if bridge is not None:
        from mathutils import Matrix
        bridge.matrix_parent_inverse = Matrix.Identity(4)
        bridge.location = (0, 0, 0)
        bridge.hide_render = False
    # the unused cherry asset keeps its own collection: take it out of the picture
    unused = bpy.data.collections.get("Cherry Blossom Tree leaves")
    if unused is not None:
        for obj in list(unused.objects):
            obj.hide_render = True
            obj.hide_viewport = True
    # the blossom tree scatters these through a particle system that reads the "Blossoms" collection
    petals = bpy.data.collections.get("Blossoms")
    if petals is not None:
        for name in ("Blossom_01", "Blossom_02", "Blossom_03"):
            part = bpy.data.objects.get(name)
            if part is not None and part.name not in petals.objects:
                petals.objects.link(part)
    # assets whose authored root scale is unknown: size them by their real bounding box
    bpy.context.view_layer.update()
    for tag, target in FIT.items():
        col = bpy.data.collections.get("A_" + tag)
        root = bpy.data.objects.get(ASSETS[tag][0])
        if col is None or root is None:
            continue
        low, high = Vector((1e9,) * 3), Vector((-1e9,) * 3)
        for obj in col.all_objects:
            if obj.type != "MESH":
                continue
            for corner in obj.bound_box:
                world = obj.matrix_world @ Vector(corner)
                low = Vector(map(min, low, world))
                high = Vector(map(max, high, world))
        size = max(high - low)
        if size > 1e-6:
            root.scale = root.scale * (target / size)
    bpy.context.view_layer.update()
    # coloured flower drifts: tinted copies of the white patch
    source = bpy.data.objects.get("Wild White Flower Patch")
    if source is not None:
        for tag, tint in FLOWER_TINTS.items():
            if bpy.data.collections.get("A_" + tag):
                continue
            copy = source.copy()
            copy.data = source.data.copy()
            copy.name = tag
            for index, material in enumerate(copy.data.materials):
                if material is None or "leaf" in material.name.lower():
                    continue
                tinted = material.copy()
                tinted.name = tag + "_" + material.name
                for node in tinted.node_tree.nodes:
                    if node.type == "BSDF_PRINCIPLED":
                        socket = node.inputs[0]
                        for link in list(socket.links):
                            tinted.node_tree.links.remove(link)
                        base = tint if "yellow" not in material.name.lower() else (1.0, 0.85, 0.3)
                        socket.default_value = (*base, 1.0)
                copy.data.materials[index] = tinted
            collection("A_" + tag, lib).objects.link(copy)
            copy.location = (0, 0, 0)
    # anything else the downloads left loose in the scene goes into the library, out of the picture
    keep = {"Ground", "PathPatch", "Brook", "BrookBed", "LookdevCam"}
    spare = collection("A_unused", lib)
    for obj in list(scene.collection.objects) + [o for c in scene.collection.children if c.name not in ("Library", "Layout", "Motes") for o in c.objects]:
        if obj.name not in keep and not obj.name.startswith("LD_"):
            move_tree(obj, spare)
    layer = bpy.context.view_layer.layer_collection.children.get("Library")
    if layer is not None:
        layer.exclude = True


def clear(name):
    col = collection(name)
    for obj in list(col.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    return col


def place(layout, tag, x, y, scale=1.0, yaw=None, tilt=0.0, sink=0.0, z=None):
    col = bpy.data.collections.get("A_" + tag)
    if col is None:
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


def water_material():
    material = bpy.data.materials.get("BrookWater") or bpy.data.materials.new("BrookWater")
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    out = tree.nodes.new("ShaderNodeOutputMaterial")
    bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs[0].default_value = (0.42, 0.68, 0.66, 1.0)
    for name, value in (("Roughness", 0.03), ("IOR", 1.33), ("Transmission Weight", 1.0)):
        if name in bsdf.inputs:
            bsdf.inputs[name].default_value = value
    ripple = tree.nodes.new("ShaderNodeTexNoise")
    ripple.inputs["Scale"].default_value = 3.2
    ripple.inputs["Detail"].default_value = 4.0
    mapping = tree.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (0.35, 1.0, 1.0)      # stretched along the flow
    coords = tree.nodes.new("ShaderNodeTexCoord")
    bump = tree.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.34
    tree.links.new(coords.outputs["Object"], mapping.inputs["Vector"])
    tree.links.new(mapping.outputs["Vector"], ripple.inputs["Vector"])
    tree.links.new(ripple.outputs[0], bump.inputs["Height"])
    tree.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    tree.links.new(bsdf.outputs[0], out.inputs["Surface"])
    return material


def ground():
    obj = bpy.data.objects["Ground"]
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=260, y_segments=260, size=45.0)
    uv = bm.loops.layers.uv.verify()
    for vert in bm.verts:
        vert.co.z = height(vert.co.x, vert.co.y)
    for face in bm.faces:
        face.smooth = True
        for loop in face.loops:
            loop[uv].uv = (loop.vert.co.x / 3.0, loop.vert.co.y / 3.0)
    bm.to_mesh(obj.data)
    bm.free()

    # leaf-litter path, feathered at the edges; it stops at each bank and the bridge carries it over
    strip = bpy.data.objects["PathPatch"]
    bm = bmesh.new()
    uv = bm.loops.layers.uv.verify()
    fade = bm.loops.layers.float_color.new("Edge")
    cuts = [-1.0, -0.6, 0.0, 0.6, 1.0]
    rows = []
    for i in range(121):
        y = -30.0 + i * 0.3
        gap = min(1.0, max(0.0, (stream_distance(path_x(y), y) - 2.0) / 1.2))
        width = (1.9 * (1.0 + 0.25 * math.sin(y * 0.5)) if y < 2.0 else 1.9 * max(0.0, 1.0 - (y - 2.0) / 3.0) * 1.6) * gap
        rows.append([bm.verts.new((path_x(y) + c * width, y, height(path_x(y) + c * width, y) + 0.035)) for c in cuts])
    for i in range(len(rows) - 1):
        for j in range(len(cuts) - 1):
            quad = (rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j])
            face = bm.faces.new(quad)
            face.smooth = True
            for loop, c in zip(face.loops, (cuts[j], cuts[j + 1], cuts[j + 1], cuts[j])):
                edge = 1.0 - abs(c)
                loop[fade] = (edge, edge, edge, 1.0)
                loop[uv].uv = (loop.vert.co.x / 2.5, loop.vert.co.y / 2.5)
    bm.to_mesh(strip.data)
    bm.free()

    # the brook surface
    water = bpy.data.objects.get("Brook")
    if water is None:
        water = bpy.data.objects.new("Brook", bpy.data.meshes.new("Brook"))
        scene.collection.objects.link(water)
    bm = bmesh.new()
    previous = None
    for i in range(181):
        x = -45.0 + i * 0.5
        pair = (bm.verts.new((x, stream_y(x) - STREAM_HALF * 1.6, WATER_Z)), bm.verts.new((x, stream_y(x) + STREAM_HALF * 1.6, WATER_Z)))
        if previous is not None:
            bm.faces.new((previous[0], pair[0], pair[1], previous[1])).smooth = True
        previous = pair
    bm.to_mesh(water.data)
    bm.free()
    water.data.materials.clear()
    water.data.materials.append(water_material())

    # the stream bed: dark wet stones under the water, feathered into the moss on both banks.
    # Without it the clear water just shows green moss and stops reading as water.
    bed = bpy.data.objects.get("BrookBed")
    if bed is None:
        bed = bpy.data.objects.new("BrookBed", bpy.data.meshes.new("BrookBed"))
        scene.collection.objects.link(bed)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.verify()
    fade = bm.loops.layers.float_color.new("Edge")
    cuts = [-1.0, -0.72, -0.35, 0.0, 0.35, 0.72, 1.0]
    rows = []
    for i in range(181):
        x = -45.0 + i * 0.5
        rows.append([bm.verts.new((x, stream_y(x) + c * STREAM_HALF * 1.75, height(x, stream_y(x) + c * STREAM_HALF * 1.75) + 0.03)) for c in cuts])
    for i in range(len(rows) - 1):
        for j in range(len(cuts) - 1):
            face = bm.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
            face.smooth = True
            for loop, c in zip(face.loops, (cuts[j], cuts[j + 1], cuts[j + 1], cuts[j])):
                edge = 1.0 - abs(c)
                loop[fade] = (edge, edge, edge, 1.0)
                loop[uv].uv = (loop.vert.co.x / 1.8, loop.vert.co.y / 1.8)
    bm.to_mesh(bed.data)
    bm.free()
    bed.visible_shadow = False
    bed.data.materials.clear()
    bed.data.materials.append(bed_material())


def bed_material():
    """River-rock scan texture, tiled, darkened and glossed as if wet, fading out at the banks."""
    material = bpy.data.materials.get("BrookBedMat")
    if material is not None:
        return material
    source = bpy.data.materials.get("Dark River Rocks 1")
    if source is None:
        material = bpy.data.materials.new("BrookBedMat")
        material.use_nodes = True
        return material
    material = source.copy()
    material.name = "BrookBedMat"
    tree = material.node_tree
    out = next(n for n in tree.nodes if n.type == "OUTPUT_MATERIAL" and n.is_active_output)
    surface = out.inputs["Surface"].links[0].from_socket
    for node in tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            for link in list(node.inputs["Roughness"].links):
                tree.links.remove(link)
            node.inputs["Roughness"].default_value = 0.22
            colour_links = list(node.inputs[0].links)
            if colour_links:                        # darken: wet stone is much darker than dry
                source_socket = colour_links[0].from_socket
                dark = tree.nodes.new("ShaderNodeMixRGB")
                dark.blend_type = "MULTIPLY"
                dark.inputs[0].default_value = 1.0
                dark.inputs[2].default_value = (0.3, 0.36, 0.34, 1.0)
                tree.links.new(source_socket, dark.inputs[1])
                tree.links.new(dark.outputs[0], node.inputs[0])
    mix = tree.nodes.new("ShaderNodeMixShader")
    mix.name = "EdgeFade"
    clear_shader = tree.nodes.new("ShaderNodeBsdfTransparent")
    attr = tree.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Edge"
    gain = tree.nodes.new("ShaderNodeMath")
    gain.operation = "MULTIPLY"
    gain.inputs[1].default_value = 2.6
    gain.use_clamp = True
    tree.links.new(attr.outputs[0], gain.inputs[0])
    tree.links.new(gain.outputs[0], mix.inputs[0])
    tree.links.new(clear_shader.outputs[0], mix.inputs[1])
    tree.links.new(surface, mix.inputs[2])
    tree.links.new(mix.outputs[0], out.inputs["Surface"])
    material.surface_render_method = "DITHERED"
    return material


def clear_of_water(x, y, margin=0.4):
    return stream_distance(x, y) > STREAM_HALF + margin


def layout():
    lay = clear("Layout")
    # --- ruin, lantern, bridge -------------------------------------------------------------
    place(lay, "pillar", -1.6, 3.4, 1.0, yaw=0.3)
    place(lay, "pillar", 2.3, 4.6, 0.82, yaw=1.9, tilt=0.06)
    place(lay, "pillar", -0.2, 6.2, 0.55, yaw=1.1, tilt=0.5, sink=0.5)
    place(lay, "moss_stone", 0.6, 2.4, 0.9, yaw=0.8, sink=0.1)
    place(lay, "moss_stone", -3.4, 0.6, 0.7, yaw=2.6, sink=0.15)
    place(lay, "lantern", 0.9, 1.1, 1.0, yaw=0.4, sink=-0.02)
    place(lay, "boulder", 3.6, 1.6, 1.0, sink=0.25)
    place(lay, "boulder", -4.4, 4.6, 1.5, sink=0.35)
    place(lay, "log_b", -4.4, -1.6, 1.0, yaw=0.5)
    place(lay, "stump", 3.4, -1.6, 1.0)
    place(lay, "stump", -5.6, 1.4, 0.8)
    bx = path_x(BRIDGE_Y)
    by = stream_y(bx)
    place(lay, "bridge", bx, by, 1.0, yaw=math.pi / 2, z=0.42)

    # --- trees: tall forest behind, blossom trees close to the clearing -----------------------
    trunks = [(-8.5, 7.5, "tree_a", 1.0), (7.8, 9.5, "tree_a", 0.9), (-0.5, 15.0, "tree_c", 1.0), (-13.5, 1.0, "tree_a", 1.0),
              (12.0, 2.5, "tree_c", 0.9), (-10.5, -10.5, "tree_c", 0.85), (11.0, -11.0, "tree_a", 0.9), (4.5, 17.5, "tree_c", 1.05),
              (-6.5, 18.0, "tree_a", 1.1), (15.5, 13.0, "tree_a", 1.0), (-16.5, 11.5, "tree_c", 1.1), (-19.0, -9.0, "tree_a", 0.95),
              (18.5, -9.0, "tree_a", 1.0), (0.5, 26.0, "tree_a", 1.2), (-12.0, 24.0, "tree_c", 1.1), (11.0, 24.5, "tree_c", 1.15),
              (-5.5, -13.5, "tree_a", 0.9), (7.0, -14.5, "tree_c", 0.9), (3.5, 10.5, "tree_a", 0.75), (-4.0, 11.0, "tree_c", 0.8)]
    for x, y, tag, s in trunks:
        place(lay, tag, x, y, s, tilt=0.03, sink=0.2)
    for x, y, s in ((-7.2, 3.4, 1.0), (7.8, 5.6, 1.1), (-3.2, 10.5, 0.95), (-10.5, -2.6, 0.9), (11.5, -3.0, 0.9)):
        place(lay, "blossom", x, y, s, sink=0.1)

    def open_ground(x, y, margin):
        return (abs(x - path_x(y)) > margin or y > 3.5) and clear_of_water(x, y)

    # --- understorey ---------------------------------------------------------------------------
    count = 0
    while count < 240:
        x, y = rng.uniform(-22, 22), rng.uniform(-24, 22)
        if open_ground(x, y, 2.3):
            place(lay, rng.choice(("fern_a", "fern_a", "fern_b")), x, y, rng.uniform(0.7, 1.5), tilt=0.08)
            count += 1
    count = 0
    while count < 950:
        near = rng.random() < 0.6
        y = rng.uniform(-24, 16)
        x = path_x(y) + rng.choice((-1, 1)) * rng.uniform(1.7, 4.5) if near else rng.uniform(-20, 20)
        if open_ground(x, y, 1.6):
            place(lay, rng.choice(("grass_a", "grass_a", "grass_b")), x, y, rng.uniform(1.2, 2.6), tilt=0.05)
            count += 1
    for i in range(30):
        x, y = rng.uniform(-20, 20), rng.uniform(-22, 20)
        if open_ground(x, y, 3.0):
            place(lay, rng.choice(("bush", "shrub", "shrub")), x, y, rng.uniform(0.7, 1.3))
    for i in range(22):
        x, y = rng.uniform(-18, 18), rng.uniform(-22, 18)
        if open_ground(x, y, 2.0):
            place(lay, "rock", x, y, rng.uniform(0.5, 1.8), tilt=0.3, sink=0.1)

    # --- flowers: drifts of one colour each, the way they seed in the wild -----------------------
    drifts = [(-3.6, -1.8, "flowers_violet", 26, 1.2), (3.0, 0.4, "flowers_pink", 22, 1.0), (-1.6, 5.0, "flowers_white", 16, 0.9),
              (5.2, -2.6, "flowers_gold", 20, 1.1), (-6.8, -8.2, "flowers_blue", 24, 1.3), (2.6, -8.4, "flowers_violet", 20, 1.2),
              (-2.4, -9.4, "flowers_pink", 18, 1.1), (7.4, 4.4, "flowers_blue", 18, 1.2), (-7.6, 4.6, "flowers_gold", 16, 1.0),
              (0.6, -2.6, "daisies", 14, 0.9), (-5.2, -3.4, "daisies", 12, 0.9), (4.4, -6.6, "flowers_red", 22, 1.0), (-0.8, 3.4, "flowers_red", 12, 0.7)]
    for cx, cy, tag, amount, spread in drifts:
        for i in range(amount):
            x, y = cx + rng.gauss(0, spread), cy + rng.gauss(0, spread)
            if open_ground(x, y, 1.3):
                scale = rng.uniform(0.5, 0.95) if tag.startswith("flowers") else rng.uniform(0.9, 1.5)
                place(lay, tag, x, y, scale)

    # --- the brook: stones on the banks and in the water, lily pads in the slow bends -----------
    for i in range(46):
        x = rng.uniform(-22, 22)
        side = rng.choice((-1, 1))
        y = stream_y(x) + side * rng.uniform(STREAM_HALF * 0.7, STREAM_HALF * 1.7)
        if abs(x - bx) < 1.6:
            continue
        place(lay, "rock", x, y, rng.uniform(0.5, 1.3), tilt=0.4, sink=0.12)
    for x in (-15.0, -8.5, -3.0, 5.5, 11.5, 17.0):
        place(lay, "river_rocks", x, stream_y(x) + rng.uniform(-0.3, 0.3), rng.uniform(0.7, 1.0), z=WATER_Z - 0.38)
    for x in (-6.4, -5.6, 3.6, 4.5, 9.0):
        place(lay, "lily", x, stream_y(x) + rng.uniform(-0.6, 0.6), rng.uniform(0.8, 1.3), z=WATER_Z + 0.01)

    # --- toadstools in little rings, by stumps and roots --------------------------------------------
    for cx, cy, amount in ((3.9, -1.0, 5), (-5.0, 1.9, 4), (-4.8, -2.4, 4), (1.6, 3.2, 3), (6.0, -6.8, 4), (-8.0, -6.6, 3)):
        for i in range(amount):
            a = rng.uniform(0, math.tau)
            place(lay, "toadstool", cx + math.cos(a) * rng.uniform(0.2, 0.7), cy + math.sin(a) * rng.uniform(0.2, 0.7), rng.uniform(0.6, 1.4), tilt=0.15)

    # --- life: butterflies over the flowers, birds on the ruin and the bridge rail -------------------
    for cx, cy in ((-3.6, -1.8), (3.0, 0.4), (5.2, -2.6), (0.4, 1.8), (-1.6, 5.0), (2.6, -8.4)):
        for i in range(3):
            x, y = cx + rng.gauss(0, 0.8), cy + rng.gauss(0, 0.8)
            obj = place(lay, "butterfly", x, y, rng.uniform(0.8, 1.3), z=height(x, y) + rng.uniform(0.5, 1.7))
            obj.rotation_euler = (rng.uniform(-0.5, 0.5), rng.uniform(-0.4, 0.4), rng.uniform(0, math.tau))
    perches = [(-1.6, 3.4, 3.66), (2.3, 4.6, 3.0), (0.55, 2.35, 0.86), (-4.6, -1.5, 0.5), (bx + 0.42, by - 0.6, 0.62)]
    for x, y, z in ():
        place(lay, "bird", x, y, 1.0, z=z)
    print("LAYOUT objects:", len(lay.objects))


def motes():
    """Pollen and fireflies hanging in the light: tiny emissive specks around the clearing."""
    col = clear("Motes")
    material = bpy.data.materials.get("Mote") or bpy.data.materials.new("Mote")
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    out = tree.nodes.new("ShaderNodeOutputMaterial")
    glow = tree.nodes.new("ShaderNodeEmission")
    glow.inputs[0].default_value = (1.0, 0.86, 0.5, 1.0)
    glow.inputs[1].default_value = 30.0
    tree.links.new(glow.outputs[0], out.inputs["Surface"])
    bm = bmesh.new()
    for i in range(150):
        x, y = rng.gauss(0.0, 5.5), rng.gauss(0.5, 5.5)
        z = height(x, y) + rng.uniform(0.25, 4.5)
        added = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=rng.uniform(0.005, 0.011))
        bmesh.ops.translate(bm, verts=added["verts"], vec=(x, y, z))
    mesh = bpy.data.meshes.new("Motes")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material)
    obj = bpy.data.objects.new("Motes", mesh)
    obj.visible_shadow = False
    col.objects.link(obj)


def camera():
    cam = bpy.data.objects["LookdevCam"]
    cam.data.lens = 32
    cam.location = (2.6, -18.5, 10.0)
    target = Vector((0.2, -0.6, 0.9))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.dof.focus_distance = (target - cam.location).length
    cam.data.dof.aperture_fstop = 4.5


library()
ground()
layout()
motes()
camera()
bpy.ops.wm.save_mainfile()
print("BUILD done", bpy.data.filepath)
