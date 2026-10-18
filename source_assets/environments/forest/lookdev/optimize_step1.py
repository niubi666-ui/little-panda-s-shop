"""Optimisation step 1: blossom clusters and the dense grass clump become textured cards.

blender --background fairy_forest.blend --python optimize_step1.py

Saves the result as fairy_forest_opt.blend next to the source and leaves the source alone.
Each asset is photographed (front and top, flat white light, transparent film) into one
atlas, and replaced by a few quads that carry those photographs. The high-poly originals
stay in the file under the "HighPoly_originals" collection.
"""
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
TEXTURES = os.path.join(HERE, "textures")
os.makedirs(TEXTURES, exist_ok=True)


def enable_gpu(scene):
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


def local_bounds(obj):
    corners = [Vector(c) for c in obj.bound_box]
    low = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    high = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    return low, high


class Studio:
    """A throwaway scene that photographs one object in its own local space."""

    def __init__(self):
        self.scene = bpy.data.scenes.new("CardStudio")
        enable_gpu(self.scene)
        self.scene.cycles.samples = 48
        self.scene.cycles.use_denoising = False
        self.scene.render.film_transparent = True
        self.scene.render.image_settings.file_format = "PNG"
        self.scene.render.image_settings.color_mode = "RGBA"
        self.scene.view_settings.view_transform = "Standard"
        self.scene.view_settings.exposure = 0.0
        world = bpy.data.worlds.new("CardStudioWorld")
        world.use_nodes = True
        background = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
        background.inputs[0].default_value = (1, 1, 1, 1)
        background.inputs[1].default_value = 1.0
        self.scene.world = world
        cam_data = bpy.data.cameras.new("CardCam")
        cam_data.type = "ORTHO"
        self.camera = bpy.data.objects.new("CardCam", cam_data)
        self.scene.collection.objects.link(self.camera)
        self.scene.camera = self.camera

    def shoot(self, source, view, tile, path):
        """view: 'front' (looking +Y) or 'top' (looking -Z). Returns the world-space rectangle
        (centre, half_width, half_height) that the tile covers, in the object's local space."""
        subject = source.copy()
        subject.matrix_world.identity()
        subject.parent = None
        for psys_modifier in [m for m in subject.modifiers if m.type == "PARTICLE_SYSTEM"]:
            subject.modifiers.remove(psys_modifier)
        self.scene.collection.objects.link(subject)
        low, high = local_bounds(source)
        centre = (low + high) / 2.0
        size = high - low
        aspect = tile[0] / tile[1]
        if view == "front":
            width, height = size.x, size.z
        else:
            width, height = size.x, size.y
        extent_w = max(width, height * aspect) * 1.04
        extent_h = extent_w / aspect
        self.scene.render.resolution_x, self.scene.render.resolution_y = tile
        self.scene.render.resolution_percentage = 100
        self.camera.data.ortho_scale = max(extent_w, extent_h)
        self.camera.data.clip_start = 0.01
        self.camera.data.clip_end = 100.0
        if view == "front":
            self.camera.location = (centre.x, low.y - 20.0, centre.z)
            self.camera.rotation_euler = (math.pi / 2.0, 0.0, 0.0)
        else:
            self.camera.location = (centre.x, centre.y, high.z + 20.0)
            self.camera.rotation_euler = (0.0, 0.0, 0.0)
        self.scene.render.filepath = path
        window = bpy.context.window
        bpy.ops.render.render(write_still=True, scene=self.scene.name)
        bpy.data.objects.remove(subject, do_unlink=True)
        return centre, extent_w / 2.0, extent_h / 2.0

    def close(self):
        bpy.data.objects.remove(self.camera, do_unlink=True)
        bpy.data.scenes.remove(self.scene)


def read_pixels(path):
    image = bpy.data.images.load(path)
    width, height = image.size
    data = np.array(image.pixels[:], dtype=np.float32).reshape(height, width, 4)
    bpy.data.images.remove(image)
    return data


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


def save_atlas(name, size, tiles):
    """tiles: [(pixels, x, y)] in pixels from the bottom-left. Returns the image datablock."""
    atlas = np.zeros((size[1], size[0], 4), dtype=np.float32)
    for pixels, x, y in tiles:
        atlas[y:y + pixels.shape[0], x:x + pixels.shape[1]] = bleed(pixels)
    image = bpy.data.images.new(name, size[0], size[1], alpha=True)
    image.pixels.foreach_set(atlas.ravel())
    image.filepath_raw = os.path.join(TEXTURES, name + ".png")
    image.file_format = "PNG"
    image.save()
    return image


def card_material(name, image, translucency):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    out = tree.nodes.new("ShaderNodeOutputMaterial")
    texture = tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    surface = tree.nodes.new("ShaderNodeBsdfPrincipled")
    surface.inputs["Roughness"].default_value = 0.65
    through = tree.nodes.new("ShaderNodeBsdfTranslucent")
    lit = tree.nodes.new("ShaderNodeMixShader")
    lit.inputs[0].default_value = translucency
    clear = tree.nodes.new("ShaderNodeBsdfTransparent")
    cut = tree.nodes.new("ShaderNodeMixShader")
    tree.links.new(texture.outputs["Color"], surface.inputs[0])
    tree.links.new(texture.outputs["Color"], through.inputs[0])
    tree.links.new(surface.outputs[0], lit.inputs[1])
    tree.links.new(through.outputs[0], lit.inputs[2])
    tree.links.new(texture.outputs["Alpha"], cut.inputs[0])
    tree.links.new(clear.outputs[0], cut.inputs[1])
    tree.links.new(lit.outputs[0], cut.inputs[2])
    tree.links.new(cut.outputs[0], out.inputs["Surface"])
    material.surface_render_method = "DITHERED"
    return material


def add_quad(bm, uv_layer, corners, rect, atlas_size):
    """corners: 4 points, bottom-left, bottom-right, top-right, top-left. rect: x, y, w, h in pixels."""
    x, y, w, h = rect
    uvs = ((x, y), (x + w, y), (x + w, y + h), (x, y + h))
    face = bm.faces.new([bm.verts.new(c) for c in corners])
    for loop, uv in zip(face.loops, uvs):
        loop[uv_layer].uv = (uv[0] / atlas_size[0], uv[1] / atlas_size[1])
    return face


def upright(bm, uv_layer, centre, half_w, half_h, yaw, rect, atlas_size):
    """A vertical card through the centre, turned about Z."""
    axis = Vector((math.cos(yaw), math.sin(yaw), 0.0)) * half_w
    up = Vector((0.0, 0.0, half_h))
    add_quad(bm, uv_layer, (centre - axis - up, centre + axis - up, centre + axis + up, centre - axis + up), rect, atlas_size)


def flat(bm, uv_layer, centre, half_w, half_h, rect, atlas_size):
    x, y = Vector((half_w, 0.0, 0.0)), Vector((0.0, half_h, 0.0))
    add_quad(bm, uv_layer, (centre - x - y, centre + x - y, centre + x + y, centre - x + y), rect, atlas_size)


def finish(bm, name, material, like):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    obj.matrix_world = like.matrix_world.copy()
    return obj


def originals():
    lib = bpy.data.collections["Library"]
    col = bpy.data.collections.get("HighPoly_originals")
    if col is None:
        col = bpy.data.collections.new("HighPoly_originals")
        lib.children.link(col)
    return col


def blossoms(studio):
    tree = bpy.data.objects["Blossom_Tree"]
    settings = tree.particle_systems[0].settings
    sources = list(settings.instance_collection.objects)
    tile = (512, 512)
    atlas_size = (tile[0] * len(sources), tile[1] * 2)
    shots, tiles = [], []
    for index, source in enumerate(sources):
        front_path = os.path.join(TEXTURES, "_tmp_blossom_%d_front.png" % index)
        top_path = os.path.join(TEXTURES, "_tmp_blossom_%d_top.png" % index)
        front = studio.shoot(source, "front", tile, front_path)
        top = studio.shoot(source, "top", tile, top_path)
        shots.append((source, front, top))
        tiles.append((read_pixels(front_path), index * tile[0], tile[1]))
        tiles.append((read_pixels(top_path), index * tile[0], 0))
        os.remove(front_path)
        os.remove(top_path)
    image = save_atlas("blossom_cards", atlas_size, tiles)
    material = card_material("BlossomCards", image, 0.35)
    cards = bpy.data.collections.new("Blossoms_cards")
    bpy.data.collections["Library"].children.link(cards)
    for index, (source, front, top) in enumerate(shots):
        bm = bmesh.new()
        uv_layer = bm.loops.layers.uv.verify()
        front_rect = (index * tile[0], tile[1], tile[0], tile[1])
        top_rect = (index * tile[0], 0, tile[0], tile[1])
        centre, half_w, half_h = front
        upright(bm, uv_layer, centre, half_w, half_h, 0.0, front_rect, atlas_size)
        upright(bm, uv_layer, centre, half_w, half_h, math.pi / 2.0, front_rect, atlas_size)
        flat(bm, uv_layer, top[0], top[1], top[2], top_rect, atlas_size)
        cards.objects.link(finish(bm, source.name + "_cards", material, source))
    settings.instance_collection = cards
    print("OPT blossom clusters -> cards:", len(shots), "atlas", atlas_size)


def grass(studio):
    source = bpy.data.objects["Realistic grass clump"]
    atlas_size = (1024, 1024)
    side_tile, top_tile = (1024, 512), (512, 512)
    side_path = os.path.join(TEXTURES, "_tmp_grass_side.png")
    top_path = os.path.join(TEXTURES, "_tmp_grass_top.png")
    side = studio.shoot(source, "front", side_tile, side_path)
    top = studio.shoot(source, "top", top_tile, top_path)
    image = save_atlas("grass_cards", atlas_size, [(read_pixels(side_path), 0, 512), (read_pixels(top_path), 0, 0)])
    os.remove(side_path)
    os.remove(top_path)
    material = card_material("GrassCards", image, 0.4)
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.verify()
    centre, half_w, half_h = side
    for yaw in (0.0, math.pi / 3.0, 2.0 * math.pi / 3.0):
        upright(bm, uv_layer, centre, half_w, half_h, yaw, (0, 512, 1024, 512), atlas_size)
    low, high = local_bounds(source)
    lifted = Vector((top[0].x, top[0].y, low.z + (high.z - low.z) * 0.45))
    flat(bm, uv_layer, lifted, top[1], top[2], (0, 0, 512, 512), atlas_size)
    cards = finish(bm, "grass_a_cards", material, source)
    home = bpy.data.collections["A_grass_a"]
    home.objects.link(cards)
    home.objects.unlink(source)
    originals().objects.link(source)
    print("OPT grass clump -> cards")


if __name__ == "__main__":
    source_path = bpy.data.filepath
    target = os.path.join(os.path.dirname(source_path), "fairy_forest_opt.blend")
    bpy.ops.wm.save_as_mainfile(filepath=target)
    studio = Studio()
    blossoms(studio)
    grass(studio)
    studio.close()
    bpy.ops.wm.save_mainfile()
    print("OPT saved", target)
