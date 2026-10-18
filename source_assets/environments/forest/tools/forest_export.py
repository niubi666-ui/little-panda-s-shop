"""森林系列的导出（Blender → Godot）。素材库和场景分开导出：

    blender --background kit/forest_kit.blend --python tools/forest_export.py -- kit  <游戏素材目录>
    blender --background rooms/<场景>/<场景>.blend --python tools/forest_export.py -- room <游戏场景目录>

  kit   → assets/<名字>.gltf：素材库里每个标成资产的集合（A_<名字>）一个文件，Godot 当“模具”用；
          textures/：所有素材共用的贴图（同一张图只存一份）
  room  → layout.json：每个素材摆在哪（Blender 坐标，Godot 自己换算）+ 场地常数
          terrain.glb：Terrain 集合里的网格——地面 Ground、水面 Brook、瀑布 Waterfall*（不带材质，Godot 按名字着色）
          terrain/*.jpg：地面着色器用的苔藓、落叶、溪床贴图

约定：
- 素材库里素材集合叫 A_<名字>，放在 Kit 集合下并标记为资产；没标资产的不导出。
- 场景文件的 Layout 集合里全是“链接自素材库”的集合实例；地面网格叫 Ground，水面叫 Brook。
- 场地常数（play_half、water_z、stream_half、bridge_x）存在场景的自定义属性 forest_room（JSON 文本）。
- 导出前对材质做的简化（glTF 读不了的混合着色、镂空贴图底色外扩）只在内存里做，不保存。
"""
import json
import os
import re
import sys

import bpy
import numpy as np
from mathutils import Matrix

TOOLS = os.path.dirname(os.path.abspath(__file__))
KIT_TEXTURES = os.path.join(os.path.dirname(TOOLS), "kit", "textures")
# 地面贴图从哪个材质取（场景文件里要有这几个材质，加了假用户防止被清理）；clover 只有用到三叶草的场景才有
TERRAIN_SOURCES = {"moss": "Forest Floor Moss", "litter": "Mossy Ground", "pebbles": "BrookBedMat", "clover": "Clover Ground Cover"}
OPTIONAL_SOURCES = {"clover"}


# ---------------------------------------------------------------- 材质：读贴图链
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


# ---------------------------------------------------------------- 材质：为 glTF 简化
def simplify_materials():
    """glTF can only carry a plain Principled setup. Card materials use a transparent /
    translucent mix that it cannot read, so give them a plain one. Any material that cuts
    its shape out with alpha gets a FOL_ prefix; Godot keys foliage settings off that."""
    for material in bpy.data.materials:
        if not material.node_tree or material.library is not None:
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


def bleed(tile, passes=16):
    """Push colour outwards into transparent texels so mip-maps do not pick up a dark fringe."""
    rgb = tile[..., :3].copy()
    # only well-covered texels are trusted as colour sources: thin, half-transparent edge
    # texels carry noisy colour once the renderer's premultiplied alpha is divided out
    filled = tile[..., 3] > 0.6
    for _ in range(passes):
        total = np.zeros_like(rgb)
        count = np.zeros(filled.shape, dtype=np.float32)
        for axis, shift in ((0, 1), (0, -1), (1, 1), (1, -1)):
            total += np.roll(rgb * filled[..., None], shift, axis=axis)
            count += np.roll(filled, shift, axis=axis)
        grow = (~filled) & (count > 0)
        rgb[grow] = total[grow] / count[grow][..., None]
        filled = filled | grow
    if (~filled).any() and filled.any():
        rgb[~filled] = rgb[filled].mean(axis=0)
    tile[..., :3] = rgb
    return tile


def pixels_of(image):
    width, height = image.size
    data = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(data)
    return data.reshape(height, width, 4)


def bled_copy(image, mask, folder):
    """A PNG copy of image whose colour is pushed out under the transparent texels (mask < 0.6),
    so that mip-maps of thin blades keep their own colour instead of picking up the grey, black
    or white that the source files store there. That fringe is what turned the game's grass
    silver-grey at a distance; Cycles never filters these textures, so it never showed there."""
    pixels = pixels_of(image)
    work = pixels.copy()
    work[..., 3] = mask
    bleed(work, passes=24)
    pixels[..., :3] = work[..., :3]
    safe = re.sub(r"[^\w.-]+", "_", image.name.rsplit(".", 1)[0] if image.name.lower().endswith((".png", ".jpg", ".jpeg")) else image.name)
    copy = bpy.data.images.new(safe + "_bled", image.size[0], image.size[1], alpha=True)
    copy.pixels.foreach_set(pixels.ravel())
    copy.filepath_raw = os.path.join(folder, safe + "_bled.png")
    copy.file_format = "PNG"
    copy.save()
    copy.colorspace_settings.name = image.colorspace_settings.name
    return copy


def bleed_foliage_images(collections, folder):
    """Every alpha-cut texture used by the given collections gets a bled copy (see bled_copy)."""
    os.makedirs(folder, exist_ok=True)
    materials = {slot.material for col in collections for obj in col.all_objects if obj.type == "MESH"
                 for slot in obj.material_slots if slot.material}
    replaced = {}
    for material in materials:
        if not material.node_tree:
            continue
        surface = next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        separate_alpha = None
        if surface is not None and surface.inputs["Alpha"].is_linked:
            source = upstream_image_nodes(surface.inputs["Alpha"])
            colour = upstream_image(surface.inputs["Base Color"], "albedo")
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
            print("EXPORT bled", image.name, "->", replaced[image].name)
    return replaced


GLTF_COMMON = dict(export_format="GLB", export_apply=True, export_yup=True, export_animations=False,
                   export_cameras=False, export_lights=False)


# ---------------------------------------------------------------- 素材库
def kit_assets():
    kit = bpy.data.collections["Kit"]
    return [col for col in kit.children if col.asset_data is not None and col.name.startswith("A_")]


def export_kit(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    assets = kit_assets()
    simplify_materials()
    bleed_foliage_images(assets, os.path.join(KIT_TEXTURES, "bled"))
    # Baked maps were written as PNG; they have no alpha, so hand them over as JPEG and keep
    # the file small. (WebP would be smaller still, but this Godot build rejects WebP-only
    # glTF textures.) Card atlases need their alpha and stay PNG.
    for image in bpy.data.images:
        if "_baked_" in image.name and image.file_format != "JPEG" and image.size[0] > 0:
            image.pixels[0]                                   # make sure the pixels are loaded
            image.file_format = "JPEG"
            image.filepath_raw = os.path.join(KIT_TEXTURES, image.name + ".jpg")
            image.save()
    # 每个素材单独一个 .gltf（assets/<名字>.gltf），贴图统一放 textures/，多个素材共用的贴图只存一份。
    # 场景只加载自己用到的素材，素材库再大也不拖慢进场景。
    view = bpy.context.view_layer.layer_collection
    for child in view.children:
        child.exclude = child.name != "Kit"
    os.makedirs(os.path.join(out_dir, "assets"), exist_ok=True)
    for asset in assets:
        for child in view.children["Kit"].children:
            child.exclude = child.name != asset.name
        bpy.context.view_layer.update()
        bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "assets", asset.name[2:] + ".gltf"), use_visible=True,
                                  export_hierarchy_full_collections=True, export_materials="EXPORT",
                                  export_tangents=True, export_image_format="AUTO", export_texture_dir="../textures",
                                  **dict(GLTF_COMMON, export_format="GLTF_SEPARATE"))
    texture_import_settings(os.path.join(out_dir, "textures"))
    print("EXPORT kit", len(assets), "assets to", out_dir)


def texture_import_settings(folder, fix_existing=True):
    """素材贴图在 Godot 里是 3D 贴图：必须开 mipmap（默认的 2D 设置不开，树叶镂空、投影会变样、远处闪烁）。
    还没导入过的先写好 .import；fix_existing 时把已导入的也改对（场景地面贴图不改旧的，免得动到已认可的画面）。"""
    for name in os.listdir(folder):
        if name.endswith(".import"):
            continue
        path = os.path.join(folder, name + ".import")
        if not os.path.exists(path):
            with open(path, "w", encoding="utf-8", newline="\n") as handle:
                handle.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\nmipmaps/generate=true\n')
            continue
        if not fix_existing:
            continue
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        if "mipmaps/generate=false" in text:
            with open(path, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(text.replace("mipmaps/generate=false", "mipmaps/generate=true"))


# ---------------------------------------------------------------- 场景
def export_texture_set(material_name, prefix, out_dir):
    material = bpy.data.materials.get(material_name)
    if material is None or not material.node_tree:
        raise RuntimeError("terrain texture source material missing: " + material_name)
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
    return result


def export_room(out_dir):
    scene = bpy.context.scene
    folder = os.path.join(out_dir, "terrain")
    os.makedirs(folder, exist_ok=True)
    layout = bpy.data.collections["Layout"]
    used = sorted({obj.instance_collection.name for obj in layout.objects if obj.instance_collection})
    instances = []
    for obj in layout.objects:
        if obj.instance_collection is None:
            continue
        matrix = Matrix.LocRotScale(obj.location, obj.rotation_euler, obj.scale)
        instances.append({"asset": obj.instance_collection.name[2:], "m": [round(v, 5) for row in matrix for v in row]})
    data = json.loads(scene["forest_room"])
    data["assets"] = [name[2:] for name in used]
    # 场景可以换某一层的来源材质（自定义属性 forest_room_materials，JSON：{"clover": "材质名"}）
    sources = dict(TERRAIN_SOURCES)
    sources.update(json.loads(scene.get("forest_room_materials", "{}")))
    data["terrain_textures"] = {key: export_texture_set(name, key, folder) for key, name in sources.items()
                                if key not in OPTIONAL_SOURCES or name in bpy.data.materials}
    # 场景自己画的贴图（地面遮罩、落花……），在场景文件旁的 textures/ 里，原样拷过去
    import shutil
    for name in [n for n in scene.get("forest_room_textures", "").split(",") if n]:
        shutil.copy2(os.path.join(os.path.dirname(bpy.data.filepath), "textures", name), os.path.join(folder, name))
    data["instances"] = instances
    with open(os.path.join(out_dir, "layout.json"), "w", encoding="utf-8") as handle:
        json.dump(data, handle, separators=(",", ":"))
    # 地形集合里的网格（地面 Ground、水面 Brook、瀑布 Waterfall*……），不带材质：Godot 按名字前缀自己着色
    terrain = {obj.name for obj in bpy.data.collections["Terrain"].objects if obj.type == "MESH"}
    for obj in bpy.context.view_layer.objects:
        obj.select_set(obj.name in terrain)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "terrain.glb"), use_selection=True,
                              export_materials="NONE", export_tangents=False, **GLTF_COMMON)
    texture_import_settings(folder, fix_existing=False)
    print("EXPORT room", len(instances), "instances of", len(used), "assets to", out_dir)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    {"kit": export_kit, "room": export_room}[args[0]](args[1])
