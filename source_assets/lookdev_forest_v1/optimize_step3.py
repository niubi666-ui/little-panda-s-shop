"""Optimisation step 3: trees, shrubs, ferns, flowers and the remaining odds and ends.

blender --background fairy_forest_opt.blend --python optimize_step3.py

- trunks, branches, shrubs, ferns, the lantern and the ground are collapsed and keep
  their UVs and materials (bark tiles, so nothing needs re-baking);
- tree foliage is thinned: a share of the leaf cards is removed and the rest enlarged so
  the canopy keeps its coverage;
- flower patches become cards, all sharing one atlas;
- the blossom trees' particle system is turned into one real canopy mesh per tree, which
  is also what Godot needs (it cannot read Blender particles).
Originals go to "HighPoly_originals". Processed assets are skipped on a re-run.
"""
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import optimize_step1 as cards

scene = bpy.context.scene

# mesh object name -> share of triangles kept by the collapse (UVs and materials kept).
# Ratios, not budgets: a trunk is thousands of separate tubes and each tube has a floor.
# Asking for less than the floor turns every twig into a flat shard, so the twigs are
# pruned first (PRUNE) and what remains is collapsed only moderately.
COLLAPSE = {
    "BaseBark_diffuse": 0.3,     # forest tree trunk and branches
    "Bark": 0.3,                 # pine trunk and branches
    "tree.004": 0.1,             # shrub branches
    "Cinnamon Fern": 0.2,
    "High grass clump": 0.36,
    "Base.001": 0.2,             # lantern
}
DROP_MODIFIERS = {"High grass clump": {"SUBSURF"}}
# mesh object name -> share of surface area kept when the smallest loose parts (twigs) are removed
PRUNE = {"BaseBark_diffuse": 0.6, "Bark": 0.6}
# leaf-card mesh name -> (share of cards kept, enlargement of the kept cards)
THIN = {
    "Front_01": (0.42, 1.55), "Front_01_v2": (0.42, 1.55), "Front_01_v3": (0.42, 1.55), "Front_01_v4": (0.42, 1.55),
    "Leaves": (0.3, 1.85),
}
FLOWERS = ["Wild White Flower Patch", "flowers_violet", "flowers_pink", "flowers_gold", "flowers_blue", "flowers_red", "FLOWER.009"]
GROUND_BUDGET = 22000
BLOSSOM_TRUNK_BUDGET = 8000


def collection(name, parent):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        parent.children.link(col)
    return col


def triangles(mesh):
    return sum(len(p.vertices) - 2 for p in mesh.polygons)


def true_world(obj):
    """World matrix from the transform properties; matrix_world is stale for objects that
    live in collections excluded from the view layer."""
    matrix = obj.matrix_basis.copy()
    if obj.parent is not None:
        matrix = true_world(obj.parent) @ obj.matrix_parent_inverse @ matrix
    return matrix


def quiet(restore=None):
    root = bpy.context.view_layer.layer_collection
    if restore is None:
        state = {}
        for child in root.children:
            if child.name != "Stage":
                state[child.name] = child.exclude
                child.exclude = True
        return state
    for child in root.children:
        if child.name in restore:
            child.exclude = restore[child.name]


def replace(high, lows):
    homes = [c for c in high.users_collection if c.name.startswith("A_")]
    for home in homes:
        for low in lows:
            if low.name not in home.objects:
                home.objects.link(low)
        home.objects.unlink(high)
    for other in list(high.users_collection):
        if other.name == "Stage":
            other.objects.unlink(high)
    if high.name not in originals.objects:
        originals.objects.link(high)


def done(name):
    return bpy.data.objects.get(name + "_low") is not None


def prune(mesh, share):
    """Copy of the mesh without its smallest loose parts. A trunk is thousands of separate
    tubes; collapsing cannot remove a tube entirely, so the twigs set a floor on the
    triangle count. Keep the largest parts that together hold `share` of the surface."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    seen = set()
    islands = []
    for vert in bm.verts:
        if vert.index in seen:
            continue
        stack = [vert]
        seen.add(vert.index)
        faces = set()
        while stack:
            current = stack.pop()
            faces.update(current.link_faces)
            for edge in current.link_edges:
                other = edge.other_vert(current)
                if other.index not in seen:
                    seen.add(other.index)
                    stack.append(other)
        islands.append((sum(f.calc_area() for f in faces), faces))
    islands.sort(key=lambda item: item[0], reverse=True)
    total = sum(area for area, faces in islands)
    running = 0.0
    drop = []
    for area, faces in islands:
        if running >= total * share:
            drop.extend(faces)
        running += area
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    pruned = bpy.data.meshes.new(mesh.name + "_pruned")
    bm.to_mesh(pruned)
    bm.free()
    for material in mesh.materials:
        pruned.materials.append(material)
    return pruned


def collapse(name, ratio):
    high = bpy.data.objects.get(name)
    if high is None or done(name):
        print("OPT3 skip", name)
        return
    before = triangles(high.data)
    low = high.copy()
    low.name = name + "_low"
    stage.objects.link(low)
    for modifier in list(low.modifiers):
        if modifier.type in DROP_MODIFIERS.get(name, set()) or modifier.type == "PARTICLE_SYSTEM":
            low.modifiers.remove(modifier)
    start = before
    if name in PRUNE:
        low.data = prune(high.data, PRUNE[name])
        start = triangles(low.data)
    decimate = low.modifiers.new("Collapse", "DECIMATE")
    decimate.ratio = ratio
    mesh = bpy.data.meshes.new_from_object(low.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    low.modifiers.clear()
    low.data = mesh
    mesh.name = low.name
    stage.objects.unlink(low)
    replace(high, [low])
    print("OPT3 collapse %-22s %7d -> %6d tris" % (name, before, triangles(mesh)))


def thin(name, keep, grow):
    high = bpy.data.objects.get(name)
    if high is None or done(name):
        print("OPT3 skip", name)
        return
    rng = random.Random(hash(name) & 0xFFFF)
    before = triangles(high.data)
    bm = bmesh.new()
    bm.from_mesh(high.data)
    drop = [face for face in bm.faces if rng.random() > keep]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    for face in bm.faces:
        centre = face.calc_center_median()
        for vert in face.verts:
            vert.co = centre + (vert.co - centre) * grow
    mesh = bpy.data.meshes.new(name + "_low")
    bm.to_mesh(mesh)
    bm.free()
    for material in high.data.materials:
        mesh.materials.append(material)
    low = high.copy()
    low.name = name + "_low"
    low.data = mesh
    replace(high, [low])
    print("OPT3 thin     %-22s %7d -> %6d tris (kept %d%% of the cards, x%.2f size)" % (name, before, triangles(mesh), keep * 100, grow))


def flowers(studio):
    sources = [bpy.data.objects.get(n) for n in FLOWERS]
    sources = [s for s in sources if s is not None and not done(s.name)]
    if not sources:
        print("OPT3 skip flowers")
        return
    tile = 256
    atlas_size = (1024, 1024)
    shots, tiles = [], []
    for source in sources:
        # The petals mix in a white translucent lobe. Lit evenly from all sides that washes
        # every colour out to pastel, so give the lobe the petal's own colour first.
        for material in source.data.materials:
            if material is None or not material.node_tree:
                continue
            base = next((n.inputs[0] for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED" and not n.inputs[0].is_linked), None)
            for node in material.node_tree.nodes:
                if base is not None and node.type == "BSDF_TRANSLUCENT" and not node.inputs[0].is_linked:
                    node.inputs[0].default_value = base.default_value[:]
    for index, source in enumerate(sources):
        column, row = index % 4, index // 4
        side_xy = (column * tile, row * 2 * tile + tile)
        top_xy = (column * tile, row * 2 * tile)
        side_path = os.path.join(cards.TEXTURES, "_tmp_flower_side.png")
        top_path = os.path.join(cards.TEXTURES, "_tmp_flower_top.png")
        side = studio.shoot(source, "front", (tile, tile), side_path)
        top = studio.shoot(source, "top", (tile, tile), top_path)
        tiles.append((cards.read_pixels(side_path), side_xy[0], side_xy[1]))
        tiles.append((cards.read_pixels(top_path), top_xy[0], top_xy[1]))
        os.remove(side_path)
        os.remove(top_path)
        shots.append((source, side, top, side_xy, top_xy))
    image = cards.save_atlas("flower_cards", atlas_size, tiles)
    material = cards.card_material("FlowerCards", image, 0.3)
    for source, side, top, side_xy, top_xy in shots:
        bm = bmesh.new()
        uv_layer = bm.loops.layers.uv.verify()
        centre, half_w, half_h = side
        for yaw in (0.0, 1.0472, 2.0944):
            cards.upright(bm, uv_layer, centre, half_w, half_h, yaw, (side_xy[0], side_xy[1], tile, tile), atlas_size)
        low_corner, high_corner = cards.local_bounds(source)
        # seen from above a flower patch is mostly its heads: put the top photograph up near them
        lifted = Vector((top[0].x, top[0].y, low_corner.z + (high_corner.z - low_corner.z) * 0.8))
        cards.flat(bm, uv_layer, lifted, top[1], top[2], (top_xy[0], top_xy[1], tile, tile), atlas_size)
        mesh = bpy.data.meshes.new(source.name + "_low")
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(material)
        low = bpy.data.objects.new(source.name + "_low", mesh)
        low.matrix_world = true_world(source)
        replace(source, [low])
    print("OPT3 flowers -> cards:", len(shots), "variants, one atlas", atlas_size)


def blossom_trees():
    tree = bpy.data.objects.get("Blossom_Tree")
    if tree is None or done("Blossom_Tree"):
        print("OPT3 skip blossom tree")
        return
    stage.objects.link(tree)
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    to_local = tree.evaluated_get(depsgraph).matrix_world.inverted()
    canopy = bmesh.new()
    canopy.loops.layers.uv.verify()
    count = 0
    card_material = None
    for instance in depsgraph.object_instances:
        if not instance.is_instance or instance.parent is None or instance.parent.original != tree:
            continue
        source = instance.object.original
        if source.type != "MESH":
            continue
        card_material = card_material or (source.data.materials[0] if source.data.materials else None)
        start = len(canopy.verts)
        canopy.from_mesh(source.data)
        canopy.verts.ensure_lookup_table()
        matrix = to_local @ instance.matrix_world
        for index in range(start, len(canopy.verts)):
            canopy.verts[index].co = matrix @ canopy.verts[index].co
        count += 1
    mesh = bpy.data.meshes.new("blossom_canopy")
    canopy.to_mesh(mesh)
    canopy.free()
    if card_material is not None:
        mesh.materials.append(card_material)
    crown = tree.copy()
    crown.name = "blossom_canopy"
    crown.modifiers.clear()
    crown.data = mesh
    # trunk
    before = triangles(tree.data)
    trunk = tree.copy()
    trunk.name = "Blossom_Tree_low"
    stage.objects.link(trunk)
    for modifier in list(trunk.modifiers):
        trunk.modifiers.remove(modifier)
    decimate = trunk.modifiers.new("Collapse", "DECIMATE")
    decimate.ratio = min(1.0, BLOSSOM_TRUNK_BUDGET / max(before, 1))
    trunk_mesh = bpy.data.meshes.new_from_object(trunk.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    trunk.modifiers.clear()
    trunk.data = trunk_mesh
    trunk_mesh.name = trunk.name
    stage.objects.unlink(trunk)
    replace(tree, [trunk, crown])
    print("OPT3 blossom tree: %d blossom clusters merged into one %d-tri canopy; trunk %d -> %d tris" % (count, triangles(mesh), before, triangles(trunk_mesh)))


def ground():
    obj = bpy.data.objects["Ground"]
    before = triangles(obj.data)
    if before <= GROUND_BUDGET * 1.2:
        print("OPT3 skip ground")
        return
    obj.data.use_fake_user = True
    obj.data.name = "Ground_high"
    was_hidden = obj.hide_viewport
    decimate = obj.modifiers.new("Collapse", "DECIMATE")
    decimate.ratio = GROUND_BUDGET / before
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    obj.modifiers.remove(decimate)
    obj.data = mesh
    mesh.name = "Ground"
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    print("OPT3 ground %d -> %d tris" % (before, triangles(mesh)))


if __name__ == "__main__":
    library = bpy.data.collections["Library"]
    originals = collection("HighPoly_originals", library)
    stage = collection("Stage", scene.collection)
    saved = quiet()
    blossom_trees()
    for name, ratio in COLLAPSE.items():
        collapse(name, ratio)
    for name, (keep, grow) in THIN.items():
        thin(name, keep, grow)
    quiet(saved)
    ground()
    scene.collection.children.unlink(stage)
    bpy.data.collections.remove(stage)
    studio = cards.Studio()
    flowers(studio)
    studio.close()
    bpy.ops.wm.save_mainfile()
    print("OPT3 saved", bpy.data.filepath)
