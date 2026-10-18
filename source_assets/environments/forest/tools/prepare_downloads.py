"""在正开着的 Blender 里（BlenderKit 刚下载完），把下载的模型整理成素材库可用的样子，写到一个中转文件。

每项：(场景里的对象名, 素材名, 目标三角面数)。做的事：
  合并成一个网格、清掉父子关系、应用旋转缩放；按目标面数塌陷减面（保留原 UV，扫描贴图照用）；
  原点放到底面中心、移回原点；贴图打包；放进集合 A_<素材名>。
另外把地面材质（三叶草）加假用户一起写出。之后用 add_to_kit.py 收进 forest_kit.blend。
"""
import os

import bpy
from mathutils import Vector

OUT = r"E:\ShopGame\source_assets\environments\forest\kit\incoming\valley_downloads.blend"
JOBS = [
    ("Moss Rock Wall", "cliff_wall", 16000),
    ("Rock Cliff Low Poly Photoscan", "cliff_low", 5000),
    ("Flat Shaped Stone", "slab", 2500),
    ("Big Flat Rock Photoscan", "flat_rock", 6000),
    ("Small Flat Stone 2", "flat_stone", 1500),
]
MATERIALS = ["Clover Ground Cover"]
# 这次要处理哪些：调用前可以在 bpy.app.driver_namespace["prep"] 里放 {"out": 路径, "jobs": [...], "materials": [...]}
_override = bpy.app.driver_namespace.get("prep")
if _override:
    OUT, JOBS, MATERIALS = _override["out"], _override["jobs"], _override.get("materials", [])


def meshes_of(root):
    found = [root] if root.type == "MESH" else []
    for child in root.children_recursive:
        if child.type == "MESH":
            found.append(child)
    return found


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


written = set()
for name, asset, budget in JOBS:
    root = bpy.data.objects[name]
    parts = meshes_of(root)
    for part in parts:
        world = part.matrix_world.copy()
        part.parent = None
        part.matrix_world = world
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    if root.type == "EMPTY" and root.name in bpy.data.objects:
        bpy.data.objects.remove(root)
    obj.name = asset
    obj.data.name = asset
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    before = tris(obj)
    if before > budget:
        mod = obj.modifiers.new("decimate", "DECIMATE")
        mod.ratio = budget / before
        bpy.ops.object.modifier_apply(modifier=mod.name)
    # 原点：底面中心
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    low = min(c.z for c in corners)
    centre = sum(corners, Vector()) / 8.0
    bpy.context.scene.cursor.location = (centre.x, centre.y, low)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    obj.location = (0.0, 0.0, 0.0)
    bpy.ops.object.shade_smooth()
    col = bpy.data.collections.new("A_" + asset)
    bpy.context.scene.collection.children.link(col)
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)
    for slot in obj.material_slots:
        if slot.material and slot.material.node_tree:
            for node in slot.material.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image is not None and node.image.packed_file is None:
                    node.image.pack()
    print("PREP", asset, "tris", before, "->", tris(obj), "size", tuple(round(d, 2) for d in obj.dimensions))
    written.add(col)

for name in MATERIALS:
    material = bpy.data.materials[name]
    material.use_fake_user = True
    for node in material.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image is not None and node.image.packed_file is None:
            node.image.pack()
    written.add(material)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.data.libraries.write(OUT, written, fake_user=True, compress=False)
print("PREP wrote", OUT)
