"""Forest look-dev scene layout. Run inside the Blender session that already holds the
downloaded BlenderKit assets (see README.md): it files each asset into a library
collection and lays out the clearing with collection instances. Safe to re-run.
"""
import math
import random

import bmesh
import bpy
from mathutils import Vector, noise

rng = random.Random(7)
scene = bpy.context.scene

# asset tag -> (root object name, uniform scale to bring it to the size used here)
ASSETS = {
    "tree_a": ("Forest Tree", 0.8),
    "tree_b": ("Birch Tree lowpoly", 0.85),
    "tree_c": ("Pine Tree", 0.8),
    "fern_big": ("Tree Fern Large", 0.3),
    "fern_a": ("Cinnamon Fern", 0.9),
    "fern_b": ("Fern Plant", 0.8),
    "grass_a": ("Realistic grass clump", 1.6),
    "grass_b": ("High grass clump", 6.0),
    "log_a": ("3D Scanned tree stump and fallen log", 1.6),
    "log_b": ("Fallen 3D Scanned tree 5.5m long", 1.0),
    "stump": ("Tree Stump with Mushrooms", 2.6),
    "pillar": ("Ancient Mossy Stone Pillar", 0.5),
    "ruin": ("Old Stone Pillar Ruin Photoscan", 1.5),
    "boulder": ("Mossy Boulder Rock", 2.4),
    "rock": ("Mossy Rock.006", 1.6),
    "bush": ("Wild Bush with Red Leaf Cluster", 1.0),
    "flowers": ("Wild White Flower Patch", 2.6),
    "shrub": ("Bush", 0.5),
    "lantern": ("Old lantern", 2.4),
    "moss_stone": ("Moss Stone", 1.0),
}


def height(x, y):
    """Gentle forest floor; the clearing and the path stay nearly flat."""
    n = noise.noise(Vector((x * 0.07, y * 0.07, 0.0))) * 1.1 + noise.noise(Vector((x * 0.25, y * 0.25, 3.0))) * 0.22
    calm = min(1.0, max(0.0, (math.hypot(x, y) - 5.0) / 9.0))
    return n * (0.12 + 0.88 * calm)


def path_x(y):
    return math.sin(y * 0.16) * 1.6 - 0.4 * math.sin(y * 0.41)


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
    for tag, (root_name, scale) in ASSETS.items():
        root = bpy.data.objects.get(root_name)
        if root is None:
            print("MISSING asset", tag, root_name)
            continue
        col = collection("A_" + tag, lib)
        move_tree(root, col)
        root.location = (0, 0, 0)
        root.rotation_euler = (0, 0, 0)
        root.scale = (scale,) * 3
    layer = bpy.context.view_layer.layer_collection.children.get("Library")
    if layer is not None:
        layer.exclude = True          # instances still render; the originals stay out of the way


def clear_layout():
    col = collection("Layout")
    for obj in list(col.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    return col


def place(layout, tag, x, y, scale=1.0, yaw=None, tilt=0.0, sink=0.0):
    col = bpy.data.collections.get("A_" + tag)
    if col is None:
        return None
    obj = bpy.data.objects.new("%s_%03d" % (tag, len(layout.objects)), None)
    obj.instance_type = "COLLECTION"
    obj.instance_collection = col
    obj.empty_display_size = 0.3
    obj.location = (x, y, height(x, y) - sink)
    obj.rotation_euler = (rng.uniform(-tilt, tilt), rng.uniform(-tilt, tilt), rng.uniform(0, math.tau) if yaw is None else yaw)
    obj.scale = (scale,) * 3
    layout.objects.link(obj)
    return obj


def ground():
    obj = bpy.data.objects["Ground"]
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=160, y_segments=160, size=45.0)
    uv = bm.loops.layers.uv.verify()
    for vert in bm.verts:
        vert.co.z = height(vert.co.x, vert.co.y)
    for face in bm.faces:
        face.smooth = True
        for loop in face.loops:
            loop[uv].uv = (loop.vert.co.x / 3.0, loop.vert.co.y / 3.0)
    bm.to_mesh(obj.data)
    bm.free()
    obj.location = (0, 0, 0)
    obj.scale = (1, 1, 1)

    # the trodden path: a strip of leaf litter feathered into the moss at both edges
    strip = bpy.data.objects["PathPatch"]
    bm = bmesh.new()
    uv = bm.loops.layers.uv.verify()
    fade = bm.loops.layers.float_color.new("Edge")
    rows = []
    half = 1.9
    cuts = [-1.0, -0.6, 0.0, 0.6, 1.0]
    for i in range(121):
        y = -30.0 + i * 0.3
        width = half * (1.0 + 0.25 * math.sin(y * 0.5)) if y < 2.0 else half * max(0.0, 1.0 - (y - 2.0) / 3.0) * 1.6
        row = []
        for c in cuts:
            x = path_x(y) + c * width
            row.append(bm.verts.new((x, y, height(x, y) + 0.035)))
        rows.append(row)
    for i in range(len(rows) - 1):
        for j in range(len(cuts) - 1):
            face = bm.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
            face.smooth = True
            for loop in face.loops:
                index = next(k for k, v in enumerate(rows[i] + rows[i + 1]) if v == loop.vert) % len(cuts)
                edge = 1.0 - abs(cuts[index])
                loop[fade] = (edge, edge, edge, 1.0)
                loop[uv].uv = (loop.vert.co.x / 2.5, loop.vert.co.y / 2.5)
    bm.to_mesh(strip.data)
    bm.free()
    strip.location = (0, 0, 0)
    strip.scale = (1, 1, 1)
    strip.visible_shadow = False
    if "Mossy Ground" in bpy.data.materials:
        strip.data.materials.clear()
        strip.data.materials.append(bpy.data.materials["Mossy Ground"])
    material = strip.active_material
    tree = material.node_tree if material is not None else None
    out = next((n for n in tree.nodes if n.type == "OUTPUT_MATERIAL" and n.is_active_output), None) if tree else None
    if out is not None and out.inputs["Surface"].links and out.inputs["Surface"].links[0].from_node.name != "EdgeFade":
        for stale in [n for n in tree.nodes if n.name.startswith("EdgeFade")]:
            tree.nodes.remove(stale)
        surface = out.inputs["Surface"].links[0].from_socket
        mix = tree.nodes.new("ShaderNodeMixShader")
        mix.name = "EdgeFade"
        clear = tree.nodes.new("ShaderNodeBsdfTransparent")
        attr = tree.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Edge"
        ramp = tree.nodes.new("ShaderNodeMath")
        ramp.operation = "MULTIPLY"
        ramp.inputs[1].default_value = 1.5
        ramp.use_clamp = True
        tree.links.new(attr.outputs["Color"], ramp.inputs[0])
        tree.links.new(ramp.outputs[0], mix.inputs[0])
        tree.links.new(clear.outputs[0], mix.inputs[1])
        tree.links.new(surface, mix.inputs[2])
        tree.links.new(mix.outputs[0], out.inputs["Surface"])
        material.surface_render_method = "DITHERED"


def layout():
    lay = clear_layout()
    # --- the ruin in the clearing: where the light lands -------------------------------
    place(lay, "pillar", -1.6, 3.4, 1.0, yaw=0.3)
    place(lay, "pillar", 2.3, 4.6, 0.82, yaw=1.9, tilt=0.06)
    place(lay, "moss_stone", 0.6, 2.4, 0.9, yaw=0.8, sink=0.1)
    place(lay, "moss_stone", -3.4, 0.6, 0.7, yaw=2.6, sink=0.15)
    place(lay, "lantern", 0.9, 1.1, 1.0, yaw=0.4, sink=-0.02)
    place(lay, "pillar", -0.2, 6.2, 0.55, yaw=1.1, tilt=0.5, sink=0.5)
    place(lay, "boulder", 3.6, 1.6, 1.0, sink=0.25)
    place(lay, "boulder", -4.4, 4.6, 1.5, sink=0.35)
    place(lay, "log_b", -2.6, -4.6, 1.0, yaw=0.5)
    place(lay, "log_a", 3.4, -2.2, 1.0, yaw=2.2)
    place(lay, "stump", 2.2, -6.0, 1.0)
    place(lay, "stump", -5.2, -0.6, 0.8)

    # --- trees: a ring around the clearing, open towards the camera ------------------------
    trunks = [(-8.5, 7.5, "tree_a", 1.0), (7.8, 9.5, "tree_a", 0.9), (-0.5, 15.0, "tree_c", 1.0), (-13.5, 1.0, "tree_a", 1.0),
              (12.0, 2.5, "tree_c", 0.9), (-10.0, -7.5, "tree_c", 0.85), (10.5, -8.0, "tree_a", 0.9), (4.5, 17.5, "tree_c", 1.05),
              (-6.5, 18.0, "tree_a", 1.1), (15.5, 13.0, "tree_a", 1.0), (-16.5, 11.5, "tree_c", 1.1), (-19.0, -4.0, "tree_a", 0.95),
              (18.5, -3.0, "tree_a", 1.0), (0.5, 26.0, "tree_a", 1.2), (-12.0, 24.0, "tree_c", 1.1),
              (-5.5, -11.5, "tree_a", 0.9), (7.0, -13.0, "tree_c", 0.9), (3.5, 9.5, "tree_a", 0.75), (-4.0, 10.5, "tree_c", 0.8), (11.0, 24.5, "tree_c", 1.15)]
    for x, y, tag, s in trunks:
        place(lay, tag, x, y, s, tilt=0.03, sink=0.2)
    for x, y in ():
        place(lay, "fern_big", x, y, rng.uniform(0.8, 1.15))

    # --- understorey: dense at the path edges and around rocks, thin on the path ------------
    def off_path(x, y, margin):
        return abs(x - path_x(y)) > margin or y > 3.5

    count = 0
    while count < 260:
        x, y = rng.uniform(-22, 22), rng.uniform(-24, 22)
        if not off_path(x, y, 2.3):
            continue
        place(lay, rng.choice(("fern_a", "fern_a", "fern_b")), x, y, rng.uniform(0.7, 1.5), tilt=0.08)
        count += 1
    count = 0
    while count < 900:
        near = rng.random() < 0.6
        y = rng.uniform(-24, 16)
        x = path_x(y) + rng.choice((-1, 1)) * rng.uniform(1.7, 4.5) if near else rng.uniform(-20, 20)
        if not off_path(x, y, 1.6):
            continue
        place(lay, rng.choice(("grass_a", "grass_a", "grass_b")), x, y, rng.uniform(1.2, 2.6), tilt=0.05)
        count += 1
    # a few drifts of small white flowers, kept sparse so they read as accents
    for cx, cy in ((-3.8, -2.4), (3.2, 0.2), (-1.8, 5.0), (5.4, -5.6), (-6.5, -8.5)):
        for i in range(9):
            x, y = cx + rng.gauss(0, 0.9), cy + rng.gauss(0, 0.9)
            if off_path(x, y, 1.5):
                place(lay, "flowers", x, y, rng.uniform(0.6, 1.1))
    for i in range(34):
        x, y = rng.uniform(-20, 20), rng.uniform(-22, 20)
        if off_path(x, y, 3.0):
            place(lay, rng.choice(("bush", "shrub", "shrub")), x, y, rng.uniform(0.7, 1.3))
    for i in range(26):
        x, y = rng.uniform(-18, 18), rng.uniform(-22, 18)
        if off_path(x, y, 2.0):
            place(lay, "rock", x, y, rng.uniform(0.5, 1.8), tilt=0.3, sink=0.1)
    print("LAYOUT objects:", len(lay.objects))


def camera():
    cam_data = bpy.data.cameras.get("LookdevCam") or bpy.data.cameras.new("LookdevCam")
    cam = bpy.data.objects.get("LookdevCam") or bpy.data.objects.new("LookdevCam", cam_data)
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    cam_data.lens = 34
    cam_data.clip_end = 300
    cam.location = (2.0, -17.0, 10.5)
    target = Vector((0.0, 0.6, 1.2))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam_data.dof.use_dof = True
    cam_data.dof.focus_distance = (target - cam.location).length
    cam_data.dof.aperture_fstop = 4.0
    scene.camera = cam


library()
ground()
layout()
camera()
bpy.ops.wm.save_mainfile()
print("BUILD done")
