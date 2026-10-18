"""Optimisation step 2: scanned props become low-poly meshes with baked textures.

blender --background fairy_forest_opt.blend --python optimize_step2.py

For each scan: copy it, collapse the copy to a triangle budget, give it a fresh UV layout,
then bake the original's colour, surface detail (as a tangent-space normal map) and
roughness onto the copy. The copy takes the original's place in its library collection;
the original moves to "HighPoly_originals". Already-processed assets are skipped, so the
script can be re-run after changing one budget.
"""
import os
import time

import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
TEXTURES = os.path.join(HERE, "textures")
os.makedirs(TEXTURES, exist_ok=True)

# tag -> (mesh object name, triangle budget, texture size, smoothing passes used only for unwrapping)
SCANS = {
    "rock": ("Mossy Rock.006", 1500, 1024, 40),
    "river_rocks": ("Sharp River Rocks", 8000, 2048, 40),
    "boulder": ("abound_20260410-0844_C31e270aa1479", 5000, 1024, 40),
    "moss_stone": ("Moss Stone", 6000, 2048, 40),
    "pillar": ("Column_2", 4000, 2048, 20),
    "stump": ("tree", 2500, 1024, 25),
}
# Modelled (not scanned) props made of many small separate parts: re-unwrapping shatters
# them, and their own UVs are already clean, so these are only collapsed and keep their
# original UVs and materials.  tag -> (mesh object name, triangle budget)
COLLAPSE_ONLY = {
    "toadstool": ("toadstool.", 3000),
}

scene = bpy.context.scene


def enable_gpu():
    scene.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for kind in ("OPTIX", "CUDA"):
        try:
            prefs.compute_device_type = kind
            prefs.get_devices()
            for device in prefs.devices:
                device.use = True
            scene.cycles.device = "GPU"
            return
        except Exception:
            continue


def collection(name, parent):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        parent.children.link(col)
    return col


def find_object(tag, wanted):
    """Resolve the mesh inside the asset's library collection (names can carry suffixes)."""
    col = bpy.data.collections["A_" + tag]
    meshes = [o for o in col.all_objects if o.type == "MESH"]
    for obj in meshes:
        if obj.name == wanted:
            return obj
    return max(meshes, key=lambda o: len(o.data.polygons)) if meshes else None


def make_low(high, budget, name, smoothing):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(high.evaluated_get(depsgraph))
    bm = bmesh.new()
    bm.from_mesh(mesh)
    size = max(high.dimensions) / max(max(high.matrix_world.to_scale()), 1e-9)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=size * 1e-5)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    triangles = len(bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    low = bpy.data.objects.new(name, mesh)
    low.parent = high.parent
    low.matrix_parent_inverse = high.matrix_parent_inverse.copy()
    low.location, low.rotation_euler, low.scale = high.location.copy(), high.rotation_euler.copy(), high.scale.copy()
    stage.objects.link(low)
    modifier = low.modifiers.new("Collapse", "DECIMATE")
    modifier.ratio = min(1.0, budget / max(triangles, 1))
    depsgraph = bpy.context.evaluated_depsgraph_get()
    collapsed = bpy.data.meshes.new_from_object(low.evaluated_get(depsgraph))
    low.modifiers.remove(modifier)
    old = low.data
    low.data = collapsed
    bpy.data.meshes.remove(old)
    collapsed.name = name
    collapsed.materials.clear()
    while collapsed.uv_layers:
        collapsed.uv_layers.remove(collapsed.uv_layers[0])
    for polygon in collapsed.polygons:
        polygon.use_smooth = True
    # Fresh UV layout. A scan's surface is bumpy, so projecting it directly shatters the
    # layout into thousands of crumbs. Unwrap a temporarily smoothed version of the same
    # mesh instead (same topology, so the UVs carry over), then put the real shape back.
    count = len(collapsed.vertices)
    shape = [0.0] * (count * 3)
    collapsed.vertices.foreach_get("co", shape)
    bm = bmesh.new()
    bm.from_mesh(collapsed)
    for _ in range(smoothing):
        bmesh.ops.smooth_vert(bm, verts=bm.verts, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.to_mesh(collapsed)
    bm.free()
    bpy.ops.object.select_all(action="DESELECT")
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.35, island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    collapsed.vertices.foreach_set("co", shape)
    collapsed.update()
    return low, triangles


def bake_material(name, size):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    out = tree.nodes.new("ShaderNodeOutputMaterial")
    surface = tree.nodes.new("ShaderNodeBsdfPrincipled")
    tree.links.new(surface.outputs[0], out.inputs["Surface"])
    targets = {}
    for key, colour_data in (("basecolor", True), ("normal", False), ("roughness", False)):
        image = bpy.data.images.new("%s_%s" % (name, key), size, size, alpha=False, is_data=not colour_data)
        if not colour_data:
            image.colorspace_settings.name = "Non-Color"
        node = tree.nodes.new("ShaderNodeTexImage")
        node.image = image
        node.name = key
        targets[key] = node
    normal_map = tree.nodes.new("ShaderNodeNormalMap")
    tree.links.new(targets["basecolor"].outputs["Color"], surface.inputs[0])
    tree.links.new(targets["roughness"].outputs["Color"], surface.inputs["Roughness"])
    tree.links.new(targets["normal"].outputs["Color"], normal_map.inputs["Color"])
    tree.links.new(normal_map.outputs["Normal"], surface.inputs["Normal"])
    return material, targets


def bake(high, low, targets, reach):
    tree = low.active_material.node_tree
    bpy.ops.object.select_all(action="DESELECT")
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    passes = (("basecolor", dict(type="DIFFUSE", pass_filter={"COLOR"})),
              ("normal", dict(type="NORMAL", normal_space="TANGENT")),
              ("roughness", dict(type="ROUGHNESS")))
    for key, options in passes:
        for node in tree.nodes:
            node.select = False
        targets[key].select = True
        tree.nodes.active = targets[key]
        bpy.ops.object.bake(use_selected_to_active=True, cage_extrusion=reach, max_ray_distance=reach * 3.0,
                            margin=12, use_clear=True, **options)
        image = targets[key].image
        image.filepath_raw = os.path.join(TEXTURES, image.name + ".png")
        image.file_format = "PNG"
        image.save()


def quiet_scene(restore=None):
    """Keep everything except the bake stage out of Cycles while baking."""
    root = bpy.context.view_layer.layer_collection
    if restore is None:
        state = {}
        for child in root.children:
            if child.name != "BakeStage":
                state[child.name] = child.exclude
                child.exclude = True
        hidden = {}
        for obj in scene.collection.objects:
            hidden[obj.name] = obj.hide_render
            obj.hide_render = True
        return state, hidden
    state, hidden = restore
    for child in root.children:
        if child.name in state:
            child.exclude = state[child.name]
    for name, value in hidden.items():
        obj = bpy.data.objects.get(name)
        if obj is not None:
            obj.hide_render = value


if __name__ == "__main__":
    enable_gpu()
    samples_before = scene.cycles.samples
    scene.cycles.samples = 8
    library = bpy.data.collections["Library"]
    originals = collection("HighPoly_originals", library)
    stage = collection("BakeStage", scene.collection)
    saved = quiet_scene()
    for tag, (wanted, budget, size, smoothing) in SCANS.items():
        low_name = tag + "_low"
        if bpy.data.objects.get(low_name) is not None:
            print("OPT2 skip", tag)
            continue
        high = find_object(tag, wanted)
        if high is None:
            print("OPT2 missing", tag)
            continue
        started = time.time()
        stage.objects.link(high)
        bpy.context.view_layer.update()
        low, before = make_low(high, budget, low_name, smoothing)
        material, targets = bake_material(tag + "_baked", size)
        low.data.materials.append(material)
        reach = max(high.dimensions) * 0.02
        bake(high, low, targets, reach)
        # swap: the low mesh joins every library collection the original was in
        homes = [c for c in high.users_collection if c.name.startswith("A_")]
        stage.objects.unlink(high)
        stage.objects.unlink(low)
        for home in homes:
            home.objects.link(low)
            home.objects.unlink(high)
        originals.objects.link(high)
        print("OPT2 %-12s %7d -> %5d tris, %dpx, %.0fs" % (tag, before, len(low.data.polygons), size, time.time() - started))
    for tag, (wanted, budget) in COLLAPSE_ONLY.items():
        low_name = tag + "_low"
        if bpy.data.objects.get(low_name) is not None:
            print("OPT2 skip", tag)
            continue
        high = find_object(tag, wanted)
        if high is None:
            print("OPT2 missing", tag)
            continue
        stage.objects.link(high)
        bpy.context.view_layer.update()
        before = sum(len(p.vertices) - 2 for p in high.data.polygons)
        low = high.copy()
        low.name = low_name
        stage.objects.link(low)
        modifier = low.modifiers.new("Collapse", "DECIMATE")
        modifier.ratio = min(1.0, budget / max(before, 1))
        collapsed = bpy.data.meshes.new_from_object(low.evaluated_get(bpy.context.evaluated_depsgraph_get()))
        low.modifiers.remove(modifier)
        low.data = collapsed
        collapsed.name = low_name
        homes = [c for c in high.users_collection if c.name.startswith("A_")]
        stage.objects.unlink(high)
        stage.objects.unlink(low)
        for home in homes:
            if low.name not in home.objects:
                home.objects.link(low)
            home.objects.unlink(high)
        for other in list(low.users_collection):
            if other not in homes:
                other.objects.unlink(low)
        originals.objects.link(high)
        print("OPT2 %-12s %7d -> %5d tris, original UVs and materials kept" % (tag, before, sum(len(p.vertices) - 2 for p in collapsed.polygons)))
    quiet_scene(saved)
    scene.collection.children.unlink(stage)
    bpy.data.collections.remove(stage)
    scene.cycles.samples = samples_before
    bpy.ops.wm.save_mainfile()
    print("OPT2 saved", bpy.data.filepath)
