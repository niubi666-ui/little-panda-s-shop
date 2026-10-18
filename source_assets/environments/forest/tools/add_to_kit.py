"""把中转文件里的新素材（A_ 集合）和地面材质收进素材库。

    blender --background kit/forest_kit.blend --python tools/add_to_kit.py -- <中转.blend> <素材名=中文名=目录>...

目录用 migrate_v2.py 里 CATALOGS 的键（trees、plants、flowers、rocks、wood、ruins、water、critters）。
已存在的同名素材会被替换。材质（带假用户的）一并收进来，供场景文件取地面贴图。
顺手修一个常见问题：下载的材质里 UV 节点指向的 UV 名和模型的不一致，会整块变灰——统一改成用模型当前的 UV。
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from migrate_v2 import CATALOGS  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
source = args[0]
labels = {}
for item in args[1:]:
    name, label, catalog = item.split("=")
    labels[name] = (label, catalog)

kit = bpy.data.collections["Kit"]
preview = bpy.data.collections["Preview"]
with bpy.data.libraries.load(source, link=False) as (src, dst):
    dst.collections = [n for n in src.collections if n.startswith("A_")]
    dst.materials = [n for n in src.materials]
for col in dst.collections:
    name = col.name
    for old in [c for c in bpy.data.collections if c != col and c.name.split(".")[0] == name.split(".")[0] and c.name.startswith(name.split(".")[0])]:
        if old in kit.children[:]:
            kit.children.unlink(old)
            for obj in list(old.objects):
                bpy.data.objects.remove(obj)
            bpy.data.collections.remove(old)
    col.name = name.split(".")[0]
    kit.children.link(col)
    for obj in col.all_objects:
        if obj.type != "MESH" or not obj.data.uv_layers:
            continue
        uv = obj.data.uv_layers.active.name
        for slot in obj.material_slots:
            if slot.material and slot.material.node_tree:
                for node in slot.material.node_tree.nodes:
                    if node.type == "UVMAP":
                        node.uv_map = uv
                    elif node.type == "NORMAL_MAP":
                        node.uv_map = uv
    key = col.name[2:]
    label, catalog = labels.get(key, (key, "rocks"))
    col.asset_mark()
    col.asset_data.description = label
    col.asset_data.catalog_id = CATALOGS[catalog][1]
    col.asset_data.tags.new("forest")
    if not any(o.instance_collection == col for o in preview.objects):
        index = len(preview.objects)
        empty = bpy.data.objects.new("P_" + key, None)
        empty.instance_type = "COLLECTION"
        empty.instance_collection = col
        empty.location = ((index % 7) * 9.0, -(index // 7) * 9.0, 0.0)
        preview.objects.link(empty)
    print("KIT added", col.name, label)
for material in dst.materials:
    material.use_fake_user = True
    print("KIT material", material.name)
view = bpy.context.view_layer.layer_collection
view.children["Kit"].exclude = True
bpy.ops.wm.save_mainfile(compress=False)
blend1 = bpy.data.filepath + "1"
if os.path.exists(blend1):
    os.remove(blend1)
print("KIT saved")
