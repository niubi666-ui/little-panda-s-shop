"""一次性迁移（2026-10-18）：把 lookdev/fairy_arena_game_v2.blend 拆成
  kit/forest_kit.blend                      森林素材库：只有素材，每个素材一个集合（A_<名字>），标记为资产
  rooms/sakura_glade/sakura_glade.blend     樱花林空地：地形、摆放、灯光；素材全部“链接”自素材库

    blender --background lookdev/fairy_arena_game_v2.blend --python tools/migrate_v2.py -- kit
    blender --background lookdev/fairy_arena_game_v2.blend --python tools/migrate_v2.py -- room <layout.json>

先跑 kit 再跑 room（room 要链接 kit 文件）。<layout.json> 是旧的游戏导出，用来取场地常数
（play_half、water_z、stream_half、bridge_x），写进场景文件，导出时原样带出。
留作记录；以后的新场景直接从素材库链接素材，不需要再跑它。
"""
import json
import math
import os
import shutil
import sys

import bpy

TOOLS = os.path.dirname(os.path.abspath(__file__))
FOREST = os.path.dirname(TOOLS)
KIT_DIR = os.path.join(FOREST, "kit")
KIT_FILE = os.path.join(KIT_DIR, "forest_kit.blend")
ROOM_DIR = os.path.join(FOREST, "rooms", "sakura_glade")
ROOM_FILE = os.path.join(ROOM_DIR, "sakura_glade.blend")

# 不进素材库的：高模原件（留在 lookdev 里）、空集合、被否掉的木雕鸟
DROP = {"HighPoly_originals", "A_unused", "A_flowers", "A_bird"}
# 素材依赖的辅助集合（粒子实例源等），放进素材库但不算资产
HELPERS = {"Blossoms_cards", "Cherry Blossom Tree leaves"}
# 地面贴图来源材料：地面着色器不直接用它们，只在导出时取贴图，要防止被当成无用数据清掉
TERRAIN_SOURCES = ("Forest Floor Moss", "Mossy Ground", "BrookBedMat")

# 每个素材：中文名、分类（资产浏览器里的目录）
CATALOGS = {
    "trees": ("树木", "8f2a1b10-0000-4000-8000-000000000001"),
    "plants": ("灌木与蕨类", "8f2a1b10-0000-4000-8000-000000000002"),
    "flowers": ("草与花", "8f2a1b10-0000-4000-8000-000000000003"),
    "rocks": ("石头", "8f2a1b10-0000-4000-8000-000000000004"),
    "wood": ("倒木与树桩", "8f2a1b10-0000-4000-8000-000000000005"),
    "ruins": ("遗迹与人造物", "8f2a1b10-0000-4000-8000-000000000006"),
    "water": ("水边", "8f2a1b10-0000-4000-8000-000000000007"),
    "critters": ("小生物与小物件", "8f2a1b10-0000-4000-8000-000000000008"),
}
ASSETS = {
    "tree_a": ("森林树 A", "trees"), "tree_b": ("森林树 B（带樱花叶粒子）", "trees"), "tree_c": ("松树", "trees"),
    "blossom": ("开花樱树", "trees"), "blossom_parts": ("樱树花簇零件", "trees"),
    "fern_big": ("大蕨", "plants"), "fern_a": ("蕨类 A", "plants"), "fern_b": ("蕨类 B", "plants"),
    "bush": ("灌木", "plants"), "shrub": ("红叶灌木", "plants"),
    "grass_a": ("草丛面片", "flowers"), "grass_b": ("高草丛", "flowers"),
    "flowers_white": ("白花丛", "flowers"), "flowers_violet": ("紫花丛", "flowers"), "flowers_pink": ("粉花丛", "flowers"),
    "flowers_gold": ("金花丛", "flowers"), "flowers_blue": ("蓝花丛", "flowers"), "flowers_red": ("红花丛", "flowers"),
    "daisies": ("雏菊", "flowers"), "poppy": ("罂粟", "flowers"),
    "boulder": ("苔藓大石", "rocks"), "rock": ("苔石", "rocks"), "moss_stone": ("苔藓石", "rocks"),
    "log_a": ("扫描倒木（长）", "wood"), "log_b": ("倒木", "wood"), "stump": ("树桩", "wood"),
    "pillar": ("古石柱", "ruins"), "ruin": ("石柱遗迹", "ruins"), "lantern": ("旧提灯", "ruins"), "bridge": ("小木桥", "ruins"),
    "river_rocks": ("溪石", "water"), "lily": ("睡莲", "water"),
    "toadstool": ("毒蝇伞", "critters"), "butterfly": ("蝴蝶", "critters"),
}


def remove_collection_tree(collection, keep_objects=()):
    for child in list(collection.children):
        remove_collection_tree(child, keep_objects)
    for obj in list(collection.objects):
        if obj.name not in keep_objects and len(obj.users_collection) <= 1:
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(collection)


def purge():
    for _ in range(4):
        bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)


def make_kit():
    scene = bpy.context.scene
    library = bpy.data.collections["Library"]
    helper_sources = {name: bpy.data.collections[name] for name in HELPERS}
    # 场景里除了素材，其余全部拿掉
    for name in ("Layout", "Motes"):
        remove_collection_tree(bpy.data.collections[name])
    for obj in list(scene.collection.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    stage = bpy.data.collections["Collection"]
    for obj in list(stage.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for name in DROP:
        if name in bpy.data.collections:
            remove_collection_tree(bpy.data.collections[name])
    kit = bpy.data.collections.new("Kit")
    helpers = bpy.data.collections.new("Kit_helpers")
    scene.collection.children.link(kit)
    scene.collection.children.link(helpers)
    for child in list(library.children):
        library.children.unlink(child)
        (helpers if child.name in HELPERS else kit).children.link(child)
    for name, col in helper_sources.items():
        for parent in [c for c in bpy.data.collections if name in c.children and c != helpers]:
            parent.children.unlink(col)
        if name not in helpers.children:
            helpers.children.link(col)
    scene.collection.children.unlink(library)
    bpy.data.collections.remove(library)
    if stage.name in scene.collection.children and not stage.objects and not stage.children:
        bpy.data.collections.remove(stage)
    scene.world = None
    # 原件留在原点不动（集合实例以它为准），另建一个“预览”集合，把每个素材按网格摆一份实例方便浏览
    preview = bpy.data.collections.new("Preview")
    scene.collection.children.link(preview)
    names = sorted(c.name for c in kit.children)
    columns = 7
    for index, name in enumerate(names):
        empty = bpy.data.objects.new("P_" + name[2:], None)
        empty.instance_type = "COLLECTION"
        empty.instance_collection = bpy.data.collections[name]
        empty.location = ((index % columns) * 9.0, -(index // columns) * 9.0, 0.0)
        preview.objects.link(empty)
    view = bpy.context.view_layer.layer_collection
    view.children["Kit"].exclude = True
    view.children["Kit_helpers"].exclude = True
    # 资产标记：资产浏览器里按目录、中文名找
    for name in names:
        col = bpy.data.collections[name]
        label, catalog = ASSETS.get(name[2:], (name[2:], "critters"))
        col.asset_mark()
        col.asset_data.description = label
        col.asset_data.catalog_id = CATALOGS[catalog][1]
        col.asset_data.tags.new("forest")
    # 没打包的贴图拷进 kit/textures，改成相对路径
    textures = os.path.join(KIT_DIR, "textures")
    os.makedirs(textures, exist_ok=True)
    copied = 0
    for image in bpy.data.images:
        if image.packed_file is not None or image.source != "FILE" or not image.filepath:
            continue
        source = bpy.path.abspath(image.filepath)
        if not os.path.exists(source):
            print("MIGRATE missing image", image.filepath)
            continue
        target = os.path.join(textures, os.path.basename(source))
        if os.path.normcase(source) != os.path.normcase(target):
            shutil.copy2(source, target)
        image.filepath = target
        copied += 1
    purge()
    with open(os.path.join(KIT_DIR, "blender_assets.cats.txt"), "w", encoding="utf-8") as handle:
        handle.write("VERSION 1\n\n")
        for key, (label, uid) in CATALOGS.items():
            handle.write("%s:%s:%s\n" % (uid, label, label))
    bpy.ops.wm.save_as_mainfile(filepath=KIT_FILE, relative_remap=True, compress=False)
    for image in bpy.data.images:
        if image.packed_file is None and image.filepath and not image.filepath.startswith("//"):
            image.filepath = bpy.path.relpath(image.filepath)
    bpy.ops.wm.save_mainfile()
    print("MIGRATE kit saved", KIT_FILE, "assets", len(names), "textures", copied)


def make_room(layout_json):
    scene = bpy.context.scene
    layout = bpy.data.collections["Layout"]
    used = sorted({obj.instance_collection.name for obj in layout.objects if obj.instance_collection})
    for name in TERRAIN_SOURCES:
        if name in bpy.data.materials:
            bpy.data.materials[name].use_fake_user = True
    # 溪床贴图的来源材质在 v2 文件里已经没有了（当初导出时还在内存里），从减面版文件补回来
    if "BrookBedMat" not in bpy.data.materials:
        with bpy.data.libraries.load(os.path.join(FOREST, "lookdev", "fairy_forest_opt.blend"), link=False) as (source, target):
            target.materials = ["BrookBedMat"]
        bed = target.materials[0]
        bed.use_fake_user = True
        for node in bed.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image is not None and node.image.packed_file is None:
                node.image.pack()
    with bpy.data.libraries.load(KIT_FILE, link=True, relative=True) as (source, target):
        target.collections = [name for name in source.collections if name in used]
    linked = {col.name: col for col in target.collections}
    missing = [name for name in used if name not in linked]
    assert not missing, "kit lacks " + str(missing)
    for obj in layout.objects:
        if obj.instance_collection is not None:
            obj.instance_collection = linked[obj.instance_collection.name]
    # 本地的素材原件全部拿掉（素材库里有）
    remove_collection_tree(bpy.data.collections["Library"])
    for name in HELPERS:
        col = bpy.data.collections.get(name)
        if col is not None and col.library is None:
            remove_collection_tree(col)
    # 整理：地形、灯光镜头各归一个集合
    stage = bpy.data.collections["Collection"]
    stage.name = "Terrain"
    lighting = bpy.data.collections.new("Lighting")
    scene.collection.children.link(lighting)
    for obj in list(scene.collection.objects):
        scene.collection.objects.unlink(obj)
        (stage if obj.type == "MESH" else lighting).objects.link(obj)
    fog = bpy.data.objects.get("LD_Fog")
    if fog is not None and fog.name in stage.objects:
        stage.objects.unlink(fog)
        lighting.objects.link(fog)
    with open(layout_json, encoding="utf-8") as handle:
        old = json.load(handle)
    scene["forest_room"] = json.dumps({key: old[key] for key in ("play_half", "water_z", "stream_half", "bridge_x")})
    purge()
    os.makedirs(ROOM_DIR, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=ROOM_FILE, relative_remap=True, compress=False)
    print("MIGRATE room saved", ROOM_FILE, "linked", len(linked), "instances", len(layout.objects))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    if args[0] == "kit":
        make_kit()
    else:
        make_room(args[1])
