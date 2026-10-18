"""樱花溪流山谷（只做 Blender，不进游戏）：唯美、有光影的童话森林山谷，真实水体、自然光、花瓣飘落、鸟。

    blender --background --factory-startup --python valley/build_stream.py [-- render <相机名,...> <宽> <采样>]

从空场景搭起，另存为 valley/sakura_stream.blend。可重复运行（随机数固定）。
素材：高精度原件链接自 lookdev/fairy_forest.blend（花树、森林树、蕨、花、扫描石头、蝴蝶）、
森林素材库 kit/forest_kit.blend（岩壁、地面材质），以及 valley/downloads/valley_downloads.blend
（BlenderKit 下载：Sakura Tree 主樱树、Grass Medium 草丛、苔藓石群、山雀）。

坐标：X 向东、Y 向北（上游）、Z 向上。溪流从北边的瀑布往南流向镜头。
"""
import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector, noise

HERE = os.path.dirname(os.path.abspath(__file__))
FOREST = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(FOREST, "tools"))
from cycles_graph import Graph  # noqa: E402
from room_build import ribbon  # noqa: E402

LOOKDEV = os.path.join(FOREST, "lookdev", "fairy_forest.blend")
LOOKDEV_OPT = os.path.join(FOREST, "lookdev", "fairy_forest_opt.blend")
KIT = os.path.join(FOREST, "kit", "forest_kit.blend")
DOWNLOADS = os.path.join(HERE, "downloads", "valley_downloads.blend")
OUT = os.path.join(HERE, "sakura_stream.blend")
rng = random.Random(7)
scene = bpy.context.scene

# ------------------------------------------------------------------ 地形与水的形状
X0, X1, Y0, Y1, STEP = -60.0, 60.0, -50.0, 125.0, 0.3
FALL_Y = 36.6          # 瀑布所在
RAPIDS_Y = 8.0         # 一道小跌水
SUN_DIR = Vector((-0.72, -0.22, 0.66)).normalized()      # 指向太阳：上午，西边约 40° 高，侧光照进山谷：亮面和树影都看得见（正面光会显得平、发灰）


def ss(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def gauss(v, c, w):
    return np.exp(-((v - c) / w) ** 2)


def xc(y):
    return 2.2 * np.sin(y * 0.05 + 0.3) + 1.0 * np.sin(y * 0.13 + 1.0)


def halfw(y):
    return 2.3 + 0.6 * np.sin(y * 0.11 + 0.7) + 1.8 * gauss(y, 33.0, 3.2) + 1.1 * gauss(y, 3.0, 3.5) - 0.7 * gauss(y, RAPIDS_Y, 1.5)


def wl(y):
    """水面高度：缓缓下降，小跌水处降 0.4 米，瀑布处降 2.8 米。"""
    return 0.012 * y + 0.4 * ss(RAPIDS_Y - 1.2, RAPIDS_Y + 1.0, y) + 2.8 * ss(FALL_Y - 0.5, FALL_Y + 0.7, y)


def wl_bank(y):
    """岸上地面跟着抬高，但比水面的台阶平缓得多（山坡慢慢爬上瀑布顶）。"""
    return 0.012 * y + 0.4 * ss(RAPIDS_Y - 4.0, RAPIDS_Y + 3.0, y) + 2.8 * ss(FALL_Y - 3.5, FALL_Y + 4.5, y)


def vnoise(px, py, scale, seed, octaves=3):
    out = np.zeros_like(px)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        s = scale * (2.03 ** o)
        a = 0.6 + o * 1.17 + seed * 0.31
        rx, ry = px * math.cos(a) - py * math.sin(a), px * math.sin(a) + py * math.cos(a)
        gx, gy = rx * s + seed * 17.3, ry * s - seed * 9.1
        ix, iy = np.floor(gx), np.floor(gy)
        fx, fy = gx - ix, gy - iy
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)

        def h(i, j):
            v = np.sin(i * 127.1 + j * 311.7 + seed) * 43758.5453
            return v - np.floor(v)
        out += ((h(ix, iy) * (1 - fx) + h(ix + 1, iy) * fx) * (1 - fy) + (h(ix, iy + 1) * (1 - fx) + h(ix + 1, iy + 1) * fx) * fy) * amp
        total += amp
        amp *= 0.5
    return out / total


def edge_offset(y, side):
    """两岸各自的宽窄起伏（左右不对称），岸线才不像水渠。"""
    return 0.45 * np.sin(y * 0.37 + side * 1.7) + 0.3 * np.sin(y * 0.83 + side * 0.4) + 0.2 * np.sin(y * 1.9 + side * 2.2)


def terrain_fields(px, py):
    a = np.abs(px - xc(py))
    side = np.sign(px - xc(py))
    hw = halfw(py) + edge_offset(py, side)
    d = a - hw                                         # 离开水边的距离（水里为负）
    depth = 0.22 + 0.5 * np.clip(1.0 - (a / hw) ** 2, 0.0, 1.0) + 0.7 * gauss(py, 33.5, 2.6) + 0.35 * gauss(py, 3.0, 3.0)
    bed = wl(py) - depth
    hills = (vnoise(px, py, 0.035, 2, 4) - 0.35) * 7.0
    bank = (wl_bank(py) + 0.06 + 0.32 * ss(0.0, 2.2, d) + 0.05 * d + 0.012 * np.maximum(d - 7.0, 0.0) ** 2
            + hills * ss(6.0, 18.0, d) + (vnoise(px, py, 0.4, 5) - 0.5) * 0.25 * ss(0.5, 3.0, d)
            + np.maximum(py - 95.0, 0.0) * 0.35)
    t = ss(-0.9, 0.45, d)
    h = bed * (1 - t) + bank * t
    under = 1.0 - ss(-0.25, 0.25, d)
    wet = (1.0 - ss(0.0, 0.6, d)) * (1 - under)
    moss = np.clip(ss(0.45, 0.75, vnoise(px, py, 0.08, 9)) + 0.6 * wet + 0.5 * ss(10, 25, d) * ss(0.4, 0.7, vnoise(px, py, 0.05, 3)), 0, 1)
    # 草：岸上开阔处多，水里、太陡的林地少
    grass = np.clip(ss(0.05, 0.9, d) * (1 - 0.7 * ss(12, 30, d)) * (0.55 + 0.45 * vnoise(px, py, 0.15, 4)), 0, 1)
    return dict(h=h, d=d, under=under, wet=wet, moss=moss, grass=grass)


# ------------------------------------------------------------------ 通用
def collection(name, parent=None, hide=False):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        (parent or scene.collection).children.link(col)
    if hide:
        bpy.context.view_layer.layer_collection.children[name].exclude = True
    return col


def set_attr(mesh, name, values):
    attr = mesh.attributes.get(name) or mesh.attributes.new(name, "FLOAT", "POINT")
    attr.data.foreach_set("value", np.ascontiguousarray(values, dtype=np.float32).ravel())


def grid(nx, ny, x0, x1, y0, y1, zfun):
    xs = np.linspace(x0, x1, nx)
    ys = np.linspace(y0, y1, ny)
    px, py = np.meshgrid(xs, ys)
    return px, py


def mesh_from_grid(name, px, py, pz):
    ny, nx = px.shape
    verts = np.stack([px.ravel(), py.ravel(), pz.ravel()], axis=1)
    idx = np.arange(nx * ny).reshape(ny, nx)
    a, b, c, d = idx[:-1, :-1].ravel(), idx[:-1, 1:].ravel(), idx[1:, 1:].ravel(), idx[1:, :-1].ravel()
    faces = np.stack([a, b, c, d], axis=1)
    mesh = bpy.data.meshes.new(name)
    mesh.vertices.add(len(verts))
    mesh.vertices.foreach_set("co", verts.astype(np.float32).ravel())
    mesh.loops.add(len(faces) * 4)
    mesh.loops.foreach_set("vertex_index", faces.astype(np.int32).ravel())
    mesh.polygons.add(len(faces))
    mesh.polygons.foreach_set("loop_start", np.arange(0, len(faces) * 4, 4, dtype=np.int32))
    mesh.polygons.foreach_set("use_smooth", np.ones(len(faces), dtype=bool))
    mesh.update(calc_edges=True)
    mesh.validate()
    return mesh


def link_collections(path, names):
    with bpy.data.libraries.load(path, link=True, relative=True) as (src, dst):
        dst.collections = [n for n in names if n in src.collections]
    missing = [n for n in names if n not in bpy.data.collections]
    if missing:
        print("STREAM missing", path, missing)


def append_materials(path, names):
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.materials = [n for n in names if n in src.materials and n not in bpy.data.materials]
    for m in dst.materials:
        if m is not None:
            m.use_fake_user = True


def image_of(material_name, key):
    import forest_export
    m = bpy.data.materials[material_name]
    surface = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    socket = {"albedo": "Base Color", "normal": "Normal", "roughness": "Roughness"}[key]
    return forest_export.upstream_image(surface.inputs[socket], key)


# ------------------------------------------------------------------ 材质
def terrain_material():
    m = bpy.data.materials.new("ValleyGround")
    m.use_nodes = True
    tree = m.node_tree
    tree.nodes.clear()
    g = Graph(tree)
    split = g.node("ShaderNodeSeparateXYZ")
    g.feed(split.inputs[0], g.node("ShaderNodeNewGeometry").outputs["Position"])
    bx, by = split.outputs[0], split.outputs[1]

    def attr(name):
        return g.node("ShaderNodeAttribute", attribute_name=name).outputs["Fac"]
    grass = g.mix(g.image(image_of("Meadow Grass With Daisies", "albedo"), bx, by, 2.4), (0.95, 0.98, 0.66), 1.0, "MULTIPLY")
    moss = g.mix(g.image(image_of("Forest Floor Moss", "albedo"), bx, by, 3.0), (0.85, 0.92, 0.7), 1.0, "MULTIPLY")
    mud = g.mix(g.image(image_of("Muddy ground with moss", "albedo"), bx, by, 2.6), (0.55, 0.55, 0.5), 1.0, "MULTIPLY")
    bed = g.mix(g.image(image_of("BrookBedMat", "albedo"), bx, by, 1.6), (0.75, 0.78, 0.72), 1.0, "MULTIPLY")
    patch = g.smooth(g.add(g.noise(bx, by, 0.35, 3.0), g.mul(g.noise(bx, by, 2.0, 7.0), 0.25)), 0.45, 0.75)
    colour = g.mix(grass, moss, g.math("MAXIMUM", g.mul(attr("moss"), patch), g.mul(attr("moss"), 0.35)))
    colour = g.mix(colour, mud, attr("wet"))
    colour = g.mix(colour, bed, attr("under"))
    macro = g.add(0.82, g.mul(0.36, g.noise(bx, by, 0.06, 20.0)))
    colour = g.mix(colour, g.vec(macro, macro, macro), 1.0, "MULTIPLY")
    rough = g.mix_float(g.mix_float(0.85, 0.45, attr("wet")), 0.3, attr("under"))
    normal_colour = g.mix(g.mix(g.image(image_of("Meadow Grass With Daisies", "normal"), bx, by, 2.4),
                                g.image(image_of("Muddy ground with moss", "normal"), bx, by, 2.6), attr("wet")),
                          g.image(image_of("BrookBedMat", "normal"), bx, by, 1.6), attr("under"))
    for tex in [n for n in tree.nodes if n.type == "TEX_IMAGE"]:
        if tex.image is not None and tex.image.colorspace_settings.name != "sRGB":
            tex.interpolation = "Linear"
    normal = g.node("ShaderNodeNormalMap", space="TANGENT", uv_map="UVMap")
    normal.inputs["Strength"].default_value = 0.8
    g.feed(normal.inputs["Color"], normal_colour)
    surface = g.node("ShaderNodeBsdfPrincipled")
    g.feed(surface.inputs["Base Color"], colour)
    g.feed(surface.inputs["Roughness"], rough)
    g.feed(surface.inputs["Normal"], normal.outputs[0])
    out = g.node("ShaderNodeOutputMaterial")
    g.feed(out.inputs["Surface"], surface.outputs[0])
    return m


def water_material():
    """真实的水：完全透射、折射率 1.333，水体内部按深度吸收成青绿色；顺着水流方向拉长的细波纹；
    跌水和瀑布底下按网格上的 foam 属性混进白沫。"""
    m = bpy.data.materials.new("StreamWater")
    m.use_nodes = True
    tree = m.node_tree
    tree.nodes.clear()
    g = Graph(tree)
    pos = g.node("ShaderNodeNewGeometry").outputs["Position"]
    split = g.node("ShaderNodeSeparateXYZ")
    g.feed(split.inputs[0], pos)
    bx, by = split.outputs[0], split.outputs[1]
    # 波纹：沿水流（Y）拉长的两层噪声
    n1 = g.node("ShaderNodeTexNoise")
    n1.inputs["Scale"].default_value = 1.0
    n1.inputs["Detail"].default_value = 6.0
    n1.inputs["Roughness"].default_value = 0.55
    g.feed(n1.inputs["Vector"], g.vec(g.mul(bx, 2.6), g.mul(by, 0.7), 0.0))
    n2 = g.node("ShaderNodeTexNoise")
    n2.inputs["Scale"].default_value = 1.0
    n2.inputs["Detail"].default_value = 3.0
    g.feed(n2.inputs["Vector"], g.vec(g.mul(bx, 7.0), g.mul(by, 2.2), 3.3))
    height = g.add(n1.outputs["Fac"], g.mul(n2.outputs["Fac"], 0.35))
    foam_attr = g.node("ShaderNodeAttribute", attribute_name="foam").outputs["Fac"]
    bump = g.node("ShaderNodeBump")
    bump.inputs["Distance"].default_value = 0.02
    g.feed(bump.inputs["Strength"], g.add(0.18, g.mul(foam_attr, 0.5)))
    g.feed(bump.inputs["Height"], height)
    clear = g.node("ShaderNodeBsdfPrincipled")
    clear.inputs["Base Color"].default_value = (1, 1, 1, 1)
    clear.inputs["Roughness"].default_value = 0.02
    clear.inputs["IOR"].default_value = 1.333
    clear.inputs["Transmission Weight"].default_value = 1.0
    g.feed(clear.inputs["Normal"], bump.outputs[0])
    foam = g.node("ShaderNodeBsdfPrincipled")
    foam.inputs["Base Color"].default_value = (0.93, 0.96, 0.96, 1)
    foam.inputs["Roughness"].default_value = 0.55
    foam.inputs["Subsurface Weight"].default_value = 0.4
    foam.inputs["Subsurface Radius"].default_value = (0.3, 0.35, 0.4)
    g.feed(foam.inputs["Normal"], bump.outputs[0])
    streak = g.node("ShaderNodeTexNoise")
    streak.inputs["Scale"].default_value = 1.0
    streak.inputs["Detail"].default_value = 8.0
    g.feed(streak.inputs["Vector"], g.vec(g.mul(bx, 5.0), g.mul(by, 1.4), 7.0))
    mask = g.smooth(g.sub(g.mul(foam_attr, 1.25), g.mul(g.sub(1.0, streak.outputs["Fac"]), 0.9)), 0.0, 0.35)
    mix = g.node("ShaderNodeMixShader")
    g.feed(mix.inputs[0], mask)
    g.feed(mix.inputs[1], clear.outputs[0])
    g.feed(mix.inputs[2], foam.outputs[0])
    absorb = g.node("ShaderNodeVolumeAbsorption")
    absorb.inputs["Color"].default_value = (0.62, 0.86, 0.8, 1)
    absorb.inputs["Density"].default_value = 0.9
    out = g.node("ShaderNodeOutputMaterial")
    g.feed(out.inputs["Surface"], mix.outputs[0])
    g.feed(out.inputs["Volume"], absorb.outputs[0])
    return m


def falls_material():
    """瀑布水帘：沿下落方向拉长的白水条纹，条纹之间透出清水；两侧边缘渐隐。"""
    m = bpy.data.materials.new("FallsWater")
    m.use_nodes = True
    tree = m.node_tree
    tree.nodes.clear()
    g = Graph(tree)
    uv = g.node("ShaderNodeTexCoord").outputs["UV"]
    split = g.node("ShaderNodeSeparateXYZ")
    g.feed(split.inputs[0], uv)
    u, v = split.outputs[0], split.outputs[1]
    streak = g.node("ShaderNodeTexNoise")
    streak.inputs["Scale"].default_value = 1.0
    streak.inputs["Detail"].default_value = 10.0
    streak.inputs["Roughness"].default_value = 0.6
    g.feed(streak.inputs["Vector"], g.vec(g.mul(u, 14.0), g.mul(v, 1.6), 0.0))
    white = g.smooth(streak.outputs["Fac"], 0.42, 0.62)
    white = g.math("MAXIMUM", white, g.smooth(g.sub(1.0, v), 0.75, 1.0))
    edge = g.mul(g.smooth(u, 0.0, 0.12), g.smooth(u, 1.0, 0.88))
    clear = g.node("ShaderNodeBsdfPrincipled")
    clear.inputs["Roughness"].default_value = 0.05
    clear.inputs["IOR"].default_value = 1.333
    clear.inputs["Transmission Weight"].default_value = 1.0
    foam = g.node("ShaderNodeBsdfPrincipled")
    foam.inputs["Base Color"].default_value = (0.94, 0.97, 0.98, 1)
    foam.inputs["Roughness"].default_value = 0.45
    foam.inputs["Subsurface Weight"].default_value = 0.5
    water = g.node("ShaderNodeMixShader")
    g.feed(water.inputs[0], white)
    g.feed(water.inputs[1], clear.outputs[0])
    g.feed(water.inputs[2], foam.outputs[0])
    hole = g.node("ShaderNodeBsdfTransparent")
    final = g.node("ShaderNodeMixShader")
    g.feed(final.inputs[0], g.math("MULTIPLY", edge, g.add(0.35, g.mul(white, 0.65)), clamp=True))
    g.feed(final.inputs[1], hole.outputs[0])
    g.feed(final.inputs[2], water.outputs[0])
    out = g.node("ShaderNodeOutputMaterial")
    g.feed(out.inputs["Surface"], final.outputs[0])
    return m


def petal_material():
    m = bpy.data.materials.new("SakuraPetal")
    m.use_nodes = True
    tree = m.node_tree
    tree.nodes.clear()
    g = Graph(tree)
    coord = g.node("ShaderNodeTexCoord").outputs["UV"]
    split = g.node("ShaderNodeSeparateXYZ")
    g.feed(split.inputs[0], coord)
    # 每片深浅略不同：按物体随机数
    rand = g.node("ShaderNodeObjectInfo").outputs["Random"]
    base = g.mix((1.0, 0.74, 0.83), (0.93, 0.5, 0.68), g.add(g.mul(rand, 0.6), g.mul(split.outputs[1], 0.5)))
    surface = g.node("ShaderNodeBsdfPrincipled")
    g.feed(surface.inputs["Base Color"], base)
    surface.inputs["Roughness"].default_value = 0.45
    surface.inputs["Subsurface Weight"].default_value = 0.35
    surface.inputs["Subsurface Radius"].default_value = (0.08, 0.04, 0.05)
    translucent = g.node("ShaderNodeBsdfTranslucent")
    g.feed(translucent.inputs["Color"], base)
    mix = g.node("ShaderNodeMixShader")
    mix.inputs[0].default_value = 0.35
    g.feed(mix.inputs[1], surface.outputs[0])
    g.feed(mix.inputs[2], translucent.outputs[0])
    out = g.node("ShaderNodeOutputMaterial")
    g.feed(out.inputs["Surface"], mix.outputs[0])
    return m


def volume_material(name, colour, density, aniso, height_falloff=None, noise_amount=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    tree = m.node_tree
    tree.nodes.clear()
    g = Graph(tree)
    vol = g.node("ShaderNodeVolumePrincipled")
    vol.inputs["Color"].default_value = (*colour, 1)
    vol.inputs["Anisotropy"].default_value = aniso
    dens = density
    if height_falloff is not None or noise_amount > 0:
        split = g.node("ShaderNodeSeparateXYZ")
        g.feed(split.inputs[0], g.node("ShaderNodeNewGeometry").outputs["Position"])
        dens = density
        if height_falloff is not None:
            lo, hi = height_falloff
            dens = g.mul(density, g.smooth(split.outputs[2], lo, hi, rising=False))
        if noise_amount > 0:
            n = g.node("ShaderNodeTexNoise")
            n.inputs["Scale"].default_value = 0.08
            n.inputs["Detail"].default_value = 3.0
            g.feed(n.inputs["Vector"], g.node("ShaderNodeNewGeometry").outputs["Position"])
            dens = g.mul(dens, g.add(1.0 - noise_amount, g.mul(g.smooth(n.outputs["Fac"], 0.35, 0.7), noise_amount * 2)))
    g.feed(vol.inputs["Density"], dens)
    out = g.node("ShaderNodeOutputMaterial")
    g.feed(out.inputs["Volume"], vol.outputs[0])
    return m


# ------------------------------------------------------------------ 网格
def build_terrain(env):
    nx, ny = int((X1 - X0) / STEP) + 1, int((Y1 - Y0) / STEP) + 1
    px, py = grid(nx, ny, X0, X1, Y0, Y1, None)
    f = terrain_fields(px, py)
    mesh = mesh_from_grid("Valley", px, py, f["h"])
    uv = mesh.uv_layers.new(name="UVMap")
    co = np.zeros(len(mesh.vertices) * 3, dtype=np.float32)
    mesh.vertices.foreach_get("co", co)
    loops = np.zeros(len(mesh.loops), dtype=np.int32)
    mesh.loops.foreach_get("vertex_index", loops)
    uv.data.foreach_set("uv", co.reshape(-1, 3)[loops][:, :2].ravel())
    for key in ("under", "wet", "moss", "grass"):
        set_attr(mesh, key, f[key])
    # 落花多的地方：樱树下（树位置由摆放时写回）和溪边
    obj = bpy.data.objects.new("Valley", mesh)
    env.objects.link(obj)
    mesh.materials.append(terrain_material())
    return obj, f


def build_water(env):
    ys = np.arange(Y0, Y1 + 1e-6, 0.15)
    cols = 30
    s = np.linspace(-1.0, 1.0, cols)
    py = np.repeat(ys[:, None], cols, axis=1)
    hw = halfw(ys)[:, None] + 1.7
    px = xc(ys)[:, None] + s[None, :] * hw
    pz = wl(py)
    mesh = mesh_from_grid("Stream", px, py, pz)
    slope = np.abs(np.gradient(wl(ys), ys))[:, None] * np.ones_like(px)
    foam = np.clip(slope * 6.0, 0, 1) * (py < FALL_Y - 0.4) + 0.95 * gauss(py, FALL_Y - 1.1, 1.3) + 0.55 * gauss(py, FALL_Y - 3.0, 1.6) + 0.75 * gauss(py, RAPIDS_Y - 0.6, 0.9)
    foam *= 0.75 + 0.25 * vnoise(px, py, 0.8, 12)
    set_attr(mesh, "foam", np.clip(foam, 0, 1))
    # 水面上漂的花瓣：缓流的潭里多
    calm = np.clip(1.0 - np.clip(foam * 2, 0, 1), 0, 1) * (0.35 + 0.65 * (gauss(py, 30.5, 3.5) + gauss(py, 2.0, 4.0) + 0.4 * gauss(py, -15, 8)))
    set_attr(mesh, "petals", np.clip(calm * (1 - np.abs(s[None, :]) ** 4), 0, 1))
    bm = bmesh.new()
    bm.from_mesh(mesh)
    steep = [f for f in bm.faces if FALL_Y - 0.45 < f.calc_center_median().y < FALL_Y + 0.7]
    bmesh.ops.delete(bm, geom=steep, context="FACES")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Stream", mesh)
    env.objects.link(obj)
    mesh.materials.append(water_material())
    solid = obj.modifiers.new("Volume", "SOLIDIFY")
    solid.thickness = 1.2
    solid.offset = -1.0
    solid.use_even_offset = True
    # 瀑布水帘
    lip_y = FALL_Y + 0.75
    lip = Vector((float(xc(lip_y)), lip_y, float(wl(lip_y)) + 0.03))
    drop = float(wl(lip_y) - wl(FALL_Y - 0.8)) + 0.15
    hw = float(halfw(lip_y))
    material = falls_material()
    falls = []
    for k, (offset, width, reach) in enumerate(((-0.62, 0.42, 0.7), (0.05, 0.62, 0.95), (0.66, 0.3, 0.6))):
        strand = ribbon("Falls_%d" % k, lip + Vector((offset * hw, 0.0, 0.0)), width * hw * 2, drop, reach, rows=40, cols=16, spread=0.35)
        strand.data.materials.append(material)
        env.objects.link(strand)
        falls.append(strand)
    return obj, falls


def build_petal_mesh(hidden):
    """一片樱花瓣：倒卵形、顶端一个小缺口、略向上卷，约 2.4 厘米。"""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rings = 5
    seg = 18
    centre = bm.verts.new((0, 0, 0))
    prev = None
    verts_rings = []
    for r in range(1, rings + 1):
        t = r / rings
        ring = []
        for k in range(seg):
            a = k / seg * math.tau
            # 倒卵形：根部窄（-Y），头部宽（+Y），头部中间有缺口
            rr = 0.012 * t * (0.75 + 0.25 * math.sin(a))
            notch = 1.0 - 0.28 * math.exp(-((a - math.pi / 2) / 0.25) ** 2) * t
            x = math.cos(a) * rr * 0.85
            y = math.sin(a) * rr * notch + 0.004 * t
            z = 0.004 * (x / 0.01) ** 2 + 0.002 * t        # 两侧向上卷
            ring.append(bm.verts.new((x, y, z)))
        verts_rings.append(ring)
    for k in range(seg):
        k2 = (k + 1) % seg
        bm.faces.new((centre, verts_rings[0][k], verts_rings[0][k2]))
        for r in range(rings - 1):
            bm.faces.new((verts_rings[r][k], verts_rings[r + 1][k], verts_rings[r + 1][k2], verts_rings[r][k2]))
    for f in bm.faces:
        f.smooth = True
        for loop in f.loops:
            co = loop.vert.co
            loop[uv].uv = (co.x / 0.024 + 0.5, co.y / 0.024 + 0.5)
    mesh = bpy.data.meshes.new("Petal")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(petal_material())
    obj = bpy.data.objects.new("Petal", mesh)
    hidden.objects.link(obj)
    return obj


# ------------------------------------------------------------------ 几何节点散布
def rv_out(node, index):
    """Random Value 节点的输出：旧版按类型分几个输出，新版只有一个。"""
    outs = [o for o in node.outputs if o.enabled]
    return outs[0] if len(node.outputs) == 1 or len(outs) == 1 else node.outputs[index]


def scatter(name, target, pick, attr, density, scale, seed, parent, align=0.0, z_offset=0.0, tilt=0.0, flat=False):
    """在 target 物体表面按属性 attr 的浓度散布 pick（集合，每个子物体一种）的实例。
    density：每平方米最多几个；scale：(最小, 最大)；align：0 = 保持竖直，1 = 顺着地面法线；flat：平躺并随机转（花瓣）。"""
    tree = bpy.data.node_groups.new(name, "GeometryNodeTree")
    tree.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    tree.interface.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    n = tree.nodes
    L = tree.links
    out = n.new("NodeGroupOutput")
    info = n.new("GeometryNodeObjectInfo")
    info.transform_space = "RELATIVE"
    info.inputs["Object"].default_value = target
    dist = n.new("GeometryNodeDistributePointsOnFaces")
    dist.distribute_method = "RANDOM"
    dist.inputs["Density"].default_value = density
    dist.inputs["Seed"].default_value = seed
    named = n.new("GeometryNodeInputNamedAttribute")
    named.data_type = "FLOAT"
    named.inputs["Name"].default_value = attr
    L.new(info.outputs["Geometry"], dist.inputs["Mesh"])
    # 用浓度做“选择”：随机数 < 浓度 才保留（RANDOM 分布没有密度因子输入时也能用）
    keep_rand = n.new("FunctionNodeRandomValue")
    keep_rand.data_type = "FLOAT"
    keep_rand.inputs["Seed"].default_value = seed + 1
    cmp = n.new("FunctionNodeCompare")
    cmp.data_type = "FLOAT"
    cmp.operation = "LESS_THAN"
    L.new(rv_out(keep_rand, 1), cmp.inputs[0])
    L.new(named.outputs["Attribute"], cmp.inputs[1])
    coll = n.new("GeometryNodeCollectionInfo")
    coll.inputs["Collection"].default_value = pick
    coll.inputs["Separate Children"].default_value = True
    coll.inputs["Reset Children"].default_value = True
    inst = n.new("GeometryNodeInstanceOnPoints")
    inst.inputs["Pick Instance"].default_value = True
    L.new(dist.outputs["Points"], inst.inputs["Points"])
    L.new(cmp.outputs[0], inst.inputs["Selection"])
    L.new(coll.outputs[0], inst.inputs["Instance"])
    idx = n.new("FunctionNodeRandomValue")
    idx.data_type = "INT"
    idx.inputs["Min"].default_value = 0
    idx.inputs["Max"].default_value = 1000
    idx.inputs["Seed"].default_value = seed + 2
    L.new(rv_out(idx, 2), inst.inputs["Instance Index"])
    rot = n.new("FunctionNodeRandomValue")
    rot.data_type = "FLOAT_VECTOR"
    rot.inputs["Min"].default_value = (-tilt, -tilt, 0.0) if not flat else (-0.35, -0.35, 0.0)
    rot.inputs["Max"].default_value = (tilt, tilt, math.tau) if not flat else (0.35, 0.35, math.tau)
    rot.inputs["Seed"].default_value = seed + 3
    if align > 0:
        # 先顺法线，再绕自身 Z 随机转：用 Align Rotation to Vector
        align_node = n.new("FunctionNodeAlignRotationToVector")
        align_node.axis = "Z"
        align_node.inputs["Factor"].default_value = align
        L.new(dist.outputs["Normal"], align_node.inputs["Vector"])
        rotz = n.new("FunctionNodeRotateRotation")
        rotz.rotation_space = "LOCAL"
        L.new(align_node.outputs[0], rotz.inputs["Rotation"])
        L.new(rv_out(rot, 0), rotz.inputs["Rotate By"])
        L.new(rotz.outputs[0], inst.inputs["Rotation"])
    else:
        L.new(rv_out(rot, 0), inst.inputs["Rotation"])
    sc = n.new("FunctionNodeRandomValue")
    sc.data_type = "FLOAT"
    sc.inputs["Min"].default_value = scale[0]
    sc.inputs["Max"].default_value = scale[1]
    sc.inputs["Seed"].default_value = seed + 4
    L.new(rv_out(sc, 1), inst.inputs["Scale"])
    last = inst.outputs[0]
    if z_offset:
        tr = n.new("GeometryNodeTranslateInstances")
        tr.inputs["Translation"].default_value = (0, 0, z_offset)
        L.new(last, tr.inputs["Instances"])
        last = tr.outputs[0]
    L.new(last, out.inputs[0])
    holder = bpy.data.objects.new(name, bpy.data.meshes.new(name + "_mesh"))
    parent.objects.link(holder)
    mod = holder.modifiers.new(name, "NODES")
    mod.node_group = tree
    return holder


def pick_collection(name, hidden, sources):
    """散布用的挑选集合：每个来源一个子物体放在原点。来源可以是网格数据（直接引用）或集合（用空物体实例）。"""
    col = bpy.data.collections.new(name)
    hidden.children.link(col)
    for i, src in enumerate(sources):
        if isinstance(src, bpy.types.Mesh):
            obj = bpy.data.objects.new("%s_%d" % (name, i), src)
        elif isinstance(src, bpy.types.Object):
            obj = bpy.data.objects.new("%s_%d" % (name, i), src.data)
            for slot_index, slot in enumerate(src.material_slots):
                pass
        else:
            obj = bpy.data.objects.new("%s_%d" % (name, i), None)
            obj.instance_type = "COLLECTION"
            obj.instance_collection = src
        col.objects.link(obj)
    return col


# ------------------------------------------------------------------ 摆放
class Placer:
    def __init__(self, layout, ground):
        self.layout = layout
        self.ground = ground

    def z(self, x, y):
        f = terrain_fields(np.array([[x]]), np.array([[y]]))
        return float(f["h"][0, 0])

    def put(self, tag, x, y, scale=1.0, yaw=None, tilt=0.0, sink=0.0, z=None, name=None):
        col = bpy.data.collections.get(tag)
        if col is None:
            print("STREAM missing", tag)
            return None
        obj = bpy.data.objects.new(name or "%s_%04d" % (tag, len(self.layout.objects)), None)
        obj.instance_type = "COLLECTION"
        obj.instance_collection = col
        obj.empty_display_size = 0.3
        obj.location = (x, y, (self.z(x, y) - sink) if z is None else z)
        obj.rotation_euler = (rng.uniform(-tilt, tilt), rng.uniform(-tilt, tilt), rng.uniform(0, math.tau) if yaw is None else yaw)
        obj.scale = (scale,) * 3
        self.layout.objects.link(obj)
        return obj


def info(x, y):
    f = terrain_fields(np.array([[x]]), np.array([[y]]))
    return {k: float(v[0, 0]) for k, v in f.items()}


def build_layout(layout, trees_col, place):
    put = place.put
    # --- 樱树：两岸排开，主樱树在镜头右前方，逆光透粉 ------------------------------------------
    hero = []
    for y, side, off, s in ((-17.0, 1, 3.2, 1.05), (-6.0, -1, 3.6, 1.0), (4.5, 1, 4.6, 1.15), (14.0, -1, 3.8, 0.95), (21.0, 1, 3.4, 1.1),
                            (28.0, -1, 5.5, 1.2), (43.0, 1, 4.5, 1.1), (48.0, -1, 4.0, 1.0), (60.0, 1, 6.0, 1.2), (-27.0, -1, 5.0, 1.0)):
        x = float(xc(y)) + side * (float(halfw(y)) + off)
        put("A_sakura", x, y, s, sink=0.15)
        hero.append((x, y, s))
    for y, side, off, s in ((-11.0, 1, 7.5, 1.0), (9.0, -1, 8.0, 1.05), (25.0, 1, 9.0, 0.95), (37.0, -1, 7.5, 1.1), (52.0, 1, 10.0, 1.0),
                            (70.0, -1, 8.0, 1.1), (-2.0, 1, 11.0, 0.9), (33.0, 1, 12.5, 1.0)):
        x = float(xc(y)) + side * (float(halfw(y)) + off)
        put("A_blossom", x, y, s, sink=0.1)
        hero.append((x, y, s * 0.8))
    # --- 森林：山坡上的高树，越远越密；镜头前方的山谷中线不放 ------------------------------------
    taken = [(x, y) for x, y, _ in hero]
    count, guard = 0, 0
    while count < 150 and guard < 20000:
        guard += 1
        x, y = rng.uniform(-58, 58), rng.uniform(-45, 120)
        f = info(x, y)
        if f["d"] < 9.0 or (y < -18 and abs(x) < 28):
            continue
        if not all((x - tx) ** 2 + (y - ty) ** 2 > 4.6 ** 2 for tx, ty in taken):
            continue
        taken.append((x, y))
        put(rng.choice(("A_tree_a", "A_tree_a", "A_tree_c")), x, y, rng.uniform(0.9, 1.3), tilt=0.03, sink=0.3)
        count += 1
    # --- 瀑布：顶上苔藓石群，两侧岩壁，潭边大石 ---------------------------------------------------------
    lip_y = FALL_Y + 0.75
    cx = float(xc(lip_y))
    hw = float(halfw(lip_y))
    # 瀑布背后的岩壁，水从岩石之间分三股落下
    put("A_cliff_wall", cx, lip_y + 1.5, 0.2, yaw=math.radians(-8), z=float(wl(FALL_Y - 1.0)) - 0.5, name="falls_back")
    for ox in (-0.3, 0.38):
        put(rng.choice(("A_moss_stone", "A_boulder")), cx + ox * hw, lip_y + 0.15, rng.uniform(0.7, 0.9), tilt=0.2, z=float(wl(lip_y)) - 0.45)
    # 瀑布口两侧沿着岩沿摆一排苔藓石，打断平直的水平线（不然像人工堰坝）
    for side in (-1, 1):
        for k in range(5):
            ox = side * (0.95 + k * 0.42) * hw
            put(rng.choice(("A_moss_stone", "A_boulder", "A_mossy_rock", "A_moss_stone")), cx + ox, lip_y + rng.uniform(-0.1, 0.5),
                rng.uniform(0.55, 0.95), tilt=0.25, z=float(wl(lip_y)) - rng.uniform(0.25, 0.5))
    put("A_rock_group", cx - hw - 3.2, lip_y + 0.8, 0.55, yaw=math.radians(20), sink=0.6)
    put("A_rock_group", cx + hw + 3.0, lip_y + 1.2, 0.5, yaw=math.radians(200), sink=0.6)
    for k, (ox, oy, s, yaw) in enumerate(((-hw - 1.0, 0.2, 0.13, -8), (hw + 1.2, 0.0, 0.12, 190), (-hw - 6.5, 1.5, 0.16, 12), (hw + 6.8, 1.8, 0.16, 175),
                                          (-hw - 12.0, 3.0, 0.18, 20), (hw + 12.5, 3.2, 0.18, 165))):
        put("A_cliff_wall", cx + ox, lip_y + oy, s, yaw=math.radians(yaw), z=float(wl(FALL_Y - 1.0)) - 0.6, name="falls_wall_%d" % k)
    for a in np.linspace(0.3, math.pi - 0.3, 9):
        x = cx + math.cos(a) * (hw + 1.2) * 1.15
        y = FALL_Y - 1.4 - math.sin(a) * 2.2
        put(rng.choice(("A_moss_stone", "A_boulder", "A_mossy_rock")), x, y, rng.uniform(0.6, 1.1), tilt=0.25, sink=0.25)
    # --- 溪里溪边的石头 --------------------------------------------------------------------------------------
    for y in np.arange(-40, 95, 1.6):
        hwv = float(halfw(y))
        for side in (-1, 1):
            if rng.random() < 0.85:
                x = float(xc(y)) + side * (hwv + float(edge_offset(y, side)) + rng.uniform(-0.5, 0.5))
                put(rng.choice(("A_rock", "A_rock", "A_moss_stone", "A_forest_rock", "A_mossy_rock")), x, y + rng.uniform(-0.6, 0.6),
                    rng.uniform(0.35, 0.9), tilt=0.35, sink=0.18)
        if rng.random() < 0.18:
            put("A_river_rocks", float(xc(y)) + rng.uniform(-0.5, 0.5) * hwv, y, rng.uniform(0.6, 0.9), z=float(wl(y)) - 0.55)
    # 小跌水：一排石头横在溪里
    for k in range(7):
        t = (k / 6 - 0.5) * 2
        x = float(xc(RAPIDS_Y)) + t * float(halfw(RAPIDS_Y)) * 0.95
        put(rng.choice(("A_rock", "A_moss_stone", "A_forest_rock")), x, RAPIDS_Y + rng.uniform(-0.3, 0.3), rng.uniform(0.45, 0.75),
            tilt=0.3, z=float(wl(RAPIDS_Y - 0.3)) - 0.25)
    # --- 倒木、树桩 ------------------------------------------------------------------------------------------
    for y, side, off, tag in ((-9.0, -1, 1.6, "A_log_a"), (18.0, 1, 2.2, "A_stump"), (40.0, -1, 3.5, "A_log_b"), (-22.0, 1, 2.5, "A_stump")):
        put(tag, float(xc(y)) + side * (float(halfw(y)) + off), y, rng.uniform(0.9, 1.2), sink=0.1)
    # --- 蕨和灌木：溪边、树下 ----------------------------------------------------------------------------------
    for i in range(520):
        y = rng.uniform(-42, 100)
        side = rng.choice((-1, 1))
        d = rng.triangular(0.4, 14.0, 1.5)
        x = float(xc(y)) + side * (float(halfw(y)) + d)
        if y < -24 and abs(x - float(xc(y))) < 6:
            continue
        tag = rng.choice(("A_fern_a", "A_fern_a", "A_fern_b", "A_fern_a", "A_bush", "A_shrub")) if d > 3 else rng.choice(("A_fern_a", "A_fern_b"))
        put(tag, x, y, rng.uniform(0.7, 1.4), tilt=0.08)
    # --- 野花：单色成片 -------------------------------------------------------------------------------------------
    colours = ("A_flowers_white", "A_flowers_violet", "A_flowers_pink", "A_flowers_gold", "A_flowers_blue", "A_daisies", "A_flowers_white", "A_daisies")
    for k in range(90):
        y = rng.uniform(-30, 70) if k % 3 else rng.uniform(-28, -8)
        side = rng.choice((-1, 1))
        d = rng.uniform(0.3, 5.0)
        cxp = float(xc(y)) + side * (float(halfw(y)) + d)
        tag = colours[k % len(colours)]
        for i in range(rng.randint(10, 22)):
            x, yy = cxp + rng.gauss(0, 1.0), y + rng.gauss(0, 1.3)
            if info(x, yy)["d"] < 0.25:
                continue
            put(tag, x, yy, rng.uniform(0.6, 1.0) if tag != "A_daisies" else rng.uniform(1.0, 1.5))
    # 毒蝇伞几处
    for k in range(6):
        y = rng.uniform(-20, 60)
        x = float(xc(y)) + rng.choice((-1, 1)) * (float(halfw(y)) + rng.uniform(2, 6))
        for i in range(rng.randint(3, 6)):
            put("A_toadstool", x + rng.uniform(-0.5, 0.5), y + rng.uniform(-0.5, 0.5), rng.uniform(0.6, 1.3), tilt=0.15)
    # --- 鸟：几只山雀停在溪边石头和倒木上；蝴蝶在花上 ------------------------------------------------------------
    birds = []
    for y, side, off, h, yaw in ((-19.5, 1, -0.3, 0.55, 200), (-15.0, -1, -0.2, 0.42, 30), (-8.8, -1, 1.6, 0.62, 110), (5.0, 1, 0.1, 0.5, 250),
                                 (-12.0, 1, 0.6, 0.35, 160)):
        x = float(xc(y)) + side * (float(halfw(y)) + off)
        b = put("A_tit", x, y, 1.0, yaw=math.radians(yaw), z=place.z(x, y) + h)
        birds.append(b)
    put("A_moss_stone", -2.5, -13.5, 0.45, yaw=0.4, sink=0.12, name="bird_rock")
    put("A_tit", -2.45, -13.45, 1.0, yaw=math.radians(120), z=place.z(-2.5, -13.5) + 0.27, name="bird_near")
    for k in range(18):
        y = rng.uniform(-30, 50)
        x = float(xc(y)) + rng.choice((-1, 1)) * (float(halfw(y)) + rng.uniform(1, 6))
        b = put("A_butterfly", x, y, rng.uniform(0.9, 1.4), z=place.z(x, y) + rng.uniform(0.4, 1.8))
        b.rotation_euler = (rng.uniform(-0.5, 0.5), rng.uniform(-0.4, 0.4), rng.uniform(0, math.tau))
    print("STREAM layout objects:", len(layout.objects))
    return hero, birds


# ------------------------------------------------------------------ 光、雾、相机
def build_lights(env):
    world = bpy.data.worlds.new("ValleySky")
    world.use_nodes = True
    nodes = world.node_tree.nodes
    bg = next(n for n in nodes if n.type == "BACKGROUND")
    sky = nodes.new("ShaderNodeTexSky")
    for name, value in (("sky_type", "MULTIPLE_SCATTERING"), ("sky_type", "NISHITA")):
        try:
            sky.sky_type = value
            break
        except TypeError:
            continue
    sky.sun_disc = False
    sky.sun_elevation = math.asin(SUN_DIR.z)
    sky.sun_rotation = math.atan2(SUN_DIR.x, SUN_DIR.y) * -1.0
    try:
        sky.air_density = 1.0
        sky.dust_density = 0.6
    except AttributeError:
        pass
    world.node_tree.links.new(sky.outputs[0], bg.inputs[0])
    bg.inputs[1].default_value = 0.12     # 物理天空很亮：太强会把阴影全填平、画面发灰
    scene.world = world
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 5.4
    sun_data.color = (1.0, 0.91, 0.76)
    sun_data.angle = math.radians(1.0)
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = SUN_DIR.to_track_quat("Z", "Y").to_euler()
    env.objects.link(sun)
    # 整个山谷的薄雾（逆光下出光柱）+ 贴着水面的晨雾
    for name, loc, size, mat in (
            ("Atmosphere", (0, 35, 14), (130, 185, 30), volume_material("Haze", (0.95, 0.97, 1.0), 0.0011, 0.5, noise_amount=0.3)),
            ("GroundMist", (0, 20, 1.2), (18, 150, 2.4), volume_material("Mist", (1.0, 1.0, 1.0), 0.005, 0.5, height_falloff=(0.2, 1.4), noise_amount=0.7)),
            ("FallsSpray", (float(xc(FALL_Y)), FALL_Y - 1.0, 1.4), (9, 6, 3.5), volume_material("Spray", (1.0, 1.0, 1.0), 0.09, 0.6, height_falloff=(0.4, 2.6), noise_amount=0.7))):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
        box = bpy.context.active_object
        box.name = name
        box.scale = size
        for c in list(box.users_collection):
            c.objects.unlink(box)
        env.objects.link(box)
        box.data.materials.append(mat)
        box.display_type = "WIRE"
        box.visible_shadow = False


def build_cameras(env):
    cams = {}
    for name, loc, target, lens in (("Cam_Hero", (-2.3, -27.0, 1.1), (2.0, 12.0, 2.4), 24),
                                    ("Cam_Falls", (2.6, 22.5, 1.6), (-0.4, 37.0, 2.6), 32),
                                    ("Cam_Wide", (9.0, -38.0, 9.5), (-1.0, 18.0, 1.0), 24),
                                    ("Cam_Bank", (-4.5, -11.0, 0.9), (1.5, -18.0, 0.6), 35)):
        data = bpy.data.cameras.new(name)
        data.lens = lens
        data.clip_end = 600
        data.dof.use_dof = name in ("Cam_Bank",)
        cam = bpy.data.objects.new(name, data)
        cam.location = loc
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        env.objects.link(cam)
        cams[name] = cam
    scene.camera = cams["Cam_Hero"]
    return cams


def build_petal_fall(env, petal, hero):
    """飘落的花瓣：每棵樱树冠下一个发射面，花瓣带着随机翻转慢慢落下，风把它们吹向下游。"""
    settings = bpy.data.particles.new("FallingPetals")
    settings.type = "EMITTER"
    settings.count = 22000
    settings.frame_start = 1
    settings.frame_end = 900
    settings.lifetime = 420
    settings.lifetime_random = 0.4
    settings.emit_from = "FACE"
    settings.normal_factor = 0.0
    settings.factor_random = 0.2
    settings.physics_type = "NEWTON"
    settings.mass = 1.0
    settings.drag_factor = 0.0
    settings.damping = 0.03          # 每帧速度衰减：花瓣慢慢飘（约 0.5 米/秒），质量设得极小再加空气阻力会算出无效数值
    settings.brownian_factor = 0.06
    settings.effector_weights.gravity = 0.035
    settings.use_rotations = True
    settings.rotation_mode = "NONE"
    settings.rotation_factor_random = 1.0
    settings.phase_factor_random = 2.0
    settings.angular_velocity_mode = "RAND"
    settings.angular_velocity_factor = 4.0
    settings.use_dynamic_rotation = True
    settings.render_type = "OBJECT"
    settings.instance_object = petal
    settings.particle_size = 1.6
    settings.size_random = 0.35
    settings.display_percentage = 30
    bm = bmesh.new()
    for x, y, s in hero:
        for i in range(4):
            cx, cy = x + rng.uniform(-2.5, 2.5) * s, y + rng.uniform(-2.5, 2.5) * s
            z = info(x, y)["h"] + 5.2 * s
            r = 1.6 * s
            v = [bm.verts.new((cx - r, cy - r, z)), bm.verts.new((cx + r, cy - r, z)), bm.verts.new((cx + r, cy + r, z)), bm.verts.new((cx - r, cy + r, z))]
            bm.faces.new(v)
    # 镜头前方低处多放几片：近处的花瓣才看得出在飘（远处的花瓣小于一个像素）
    for cx, cy, r, z in ((0.0, -20.0, 5.0, 4.5), (0.5, -10.0, 6.0, 5.5), (1.5, 2.0, 7.0, 6.0),
                         (-1.5, -22.5, 3.0, 3.2), (0.5, -21.0, 3.0, 3.5), (-1.8, -14.5, 2.5, 3.0), (0.6, 27.0, 3.0, 4.0),
                         (-1.0, -24.0, 2.0, 2.8), (1.0, -23.5, 2.0, 2.6)):
        v = [bm.verts.new((cx - r, cy - r, z)), bm.verts.new((cx + r, cy - r, z)), bm.verts.new((cx + r, cy + r, z)), bm.verts.new((cx - r, cy + r, z))]
        bm.faces.new(v)
    mesh = bpy.data.meshes.new("PetalEmitter")
    bm.to_mesh(mesh)
    bm.free()
    emitter = bpy.data.objects.new("PetalEmitter", mesh)
    env.objects.link(emitter)
    emitter.modifiers.new("Petals", "PARTICLE_SYSTEM")
    emitter.particle_systems[0].settings = settings
    # 粒子用的花瓣原型必须在参与计算的集合里（被排除的集合里粒子拿不到它）：放到地下看不见的地方
    proto = bpy.data.objects.new("PetalParticle", petal.data)
    proto.location = (0.0, 0.0, -60.0)
    env.objects.link(proto)
    settings.instance_object = proto
    emitter.particle_systems[0].seed = 11
    emitter.show_instancer_for_render = False
    emitter.show_instancer_for_viewport = False
    # 风：顺着山谷往下游（-Y）轻轻吹；湍流让花瓣打旋
    def field(kind, name, loc, rot, **settings):
        bpy.ops.object.effector_add(type=kind, location=loc, rotation=rot)
        obj = bpy.context.active_object
        obj.name = name
        for c in list(obj.users_collection):
            c.objects.unlink(obj)
        env.objects.link(obj)
        for key, value in settings.items():
            setattr(obj.field, key, value)
        return obj
    field("WIND", "Wind", (0, 40, 6), (math.radians(90), 0, math.radians(180)), strength=0.25, noise=0.6)
    field("TURBULENCE", "Turbulence", (0, 10, 4), (0, 0, 0), strength=0.6, size=2.5, flow=0.0)
    return emitter


def render_settings():
    scene.render.engine = "CYCLES"
    c = scene.cycles
    c.samples = 192
    c.use_denoising = True
    c.max_bounces = 8
    c.transmission_bounces = 8
    c.volume_bounces = 1
    c.transparent_max_bounces = 16
    c.volume_step_rate = 2.0
    c.caustics_refractive = True
    c.caustics_reflective = False
    c.blur_glossy = 1.0
    scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    scene.view_settings.exposure = 1.3
    scene.frame_start, scene.frame_end, scene.frame_current = 1, 900, 300     # 第 300 帧时花瓣已经满天飘
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for kind in ("OPTIX", "CUDA"):
        try:
            prefs.compute_device_type = kind
            prefs.get_devices()
            for device in prefs.devices:
                device.use = True
            c.device = "GPU"
            break
        except Exception:
            continue


# ------------------------------------------------------------------ 主流程
def build():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    env = collection("Environment")
    layout = collection("Layout")
    scatter_col = collection("Scatter")
    hidden = collection("ScatterSources")
    lookdev_names = ["A_" + n for n in ("tree_a", "tree_c", "blossom", "fern_a", "fern_b", "bush", "shrub", "rock", "moss_stone", "boulder",
                                        "river_rocks", "log_a", "log_b", "stump", "toadstool", "butterfly", "flowers_white", "flowers_violet",
                                        "flowers_pink", "flowers_gold", "flowers_blue", "daisies", "grass_b")]
    link_collections(LOOKDEV, lookdev_names)
    link_collections(KIT, ["A_cliff_wall"])
    link_collections(DOWNLOADS, ["A_sakura", "A_tit", "A_rock_group", "A_mossy_rock", "A_forest_rock", "A_grass_med"])
    append_materials(KIT, ["Meadow Grass With Daisies", "Muddy ground with moss"])
    append_materials(LOOKDEV, ["Forest Floor Moss"])
    append_materials(LOOKDEV_OPT, ["BrookBedMat"])
    render_settings()
    terrain, fields = build_terrain(env)
    water, falls = build_water(env)
    petal = build_petal_mesh(hidden)
    place = Placer(layout, terrain)
    hero, birds = build_layout(layout, None, place)
    # 樱树下的落花：写进地形的 petals 属性
    mesh = terrain.data
    co = np.zeros(len(mesh.vertices) * 3, dtype=np.float32)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    petals = np.zeros(len(co))
    for x, y, s in hero:
        petals = np.maximum(petals, (1.0 - ss(1.0, 5.5 * s, np.hypot(co[:, 0] - x, co[:, 1] - y))) * 0.9)
    under = np.zeros(len(co))
    mesh.attributes["under"].data.foreach_get("value", under) if False else None
    set_attr(mesh, "petals", petals)
    # 散布：草丛（Grass Medium 的 LOD0）、小草、地上的花瓣、水面上的花瓣
    grass_meshes = [o.data for o in bpy.data.collections["A_grass_med"].all_objects if o.type == "MESH" and o.name.endswith("LOD0")]
    grass_pick = pick_collection("Pick_Grass", hidden, grass_meshes + [bpy.data.collections["A_grass_b"]] * 4)
    petal_pick = pick_collection("Pick_Petal", hidden, [petal.data])
    scatter("Grass", terrain, grass_pick, "grass", 22.0, (1.1, 2.1), 3, scatter_col, align=0.4, tilt=0.06)
    scatter("GroundPetals", terrain, petal_pick, "petals", 120.0, (0.8, 1.2), 5, scatter_col, align=1.0, z_offset=0.004, flat=True)
    scatter("WaterPetals", water, petal_pick, "petals", 14.0, (0.8, 1.2), 9, scatter_col, align=1.0, z_offset=0.003, flat=True)
    build_lights(env)
    build_cameras(env)
    build_petal_fall(env, petal, hero)
    soft_glow()
    # 把花瓣下落预先算好存到硬盘（sakura_stream.blend 旁边的 blendcache 文件夹），在 Blender 里拖时间轴就能看
    bpy.ops.wm.save_as_mainfile(filepath=OUT, relative_remap=True, compress=False)
    emitter = bpy.data.objects["PetalEmitter"]
    cache = emitter.particle_systems[0].point_cache
    cache.use_disk_cache = True
    cache.frame_start, cache.frame_end = 1, 900
    try:
        with bpy.context.temp_override(object=emitter, active_object=emitter, point_cache=cache):
            bpy.ops.ptcache.bake(bake=True)
        print("STREAM petals baked")
    except Exception as e:
        print("STREAM petal bake skipped", e)
    scene.frame_set(300)
    bpy.context.view_layer.layer_collection.children["ScatterSources"].exclude = True
    bpy.ops.wm.save_as_mainfile(filepath=OUT, relative_remap=True, compress=False)
    print("STREAM saved", OUT)


def soft_glow():
    """合成：给亮处加一层很淡的柔光（Fog Glow），阳光和花瓣更通透。Blender 版本不同接口不同，失败就跳过。"""
    try:
        tree = getattr(scene, "compositing_node_group", None)
        if tree is None and hasattr(bpy.data, "node_groups"):
            tree = bpy.data.node_groups.new("ValleyComposite", "CompositorNodeTree")
            scene.compositing_node_group = tree
            tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        tree.nodes.clear()
        rl = tree.nodes.new("CompositorNodeRLayers")
        glare = tree.nodes.new("CompositorNodeGlare")
        for key, value in (("glare_type", "FOG_GLOW"), ("quality", "HIGH")):
            try:
                setattr(glare, key, value)
            except Exception:
                pass
        for name, value in (("Type", "Fog Glow"), ("Threshold", 1.2), ("Strength", 0.25), ("Size", 0.6)):
            if name in glare.inputs:
                try:
                    glare.inputs[name].default_value = value
                except Exception:
                    pass
        out = tree.nodes.new("NodeGroupOutput")
        tree.links.new(rl.outputs["Image"], glare.inputs["Image"])
        tree.links.new(glare.outputs["Image"], out.inputs[0])
        print("STREAM glow on")
    except Exception as e:
        print("STREAM glow skipped", e)


def render(cameras, width, samples, out_dir):
    scene.render.resolution_x = width
    scene.render.resolution_y = int(width * 9 / 16)
    scene.cycles.samples = samples
    os.makedirs(out_dir, exist_ok=True)
    # 粒子要从第 1 帧一步步模拟过来，花瓣才会在空中
    target = scene.frame_current
    for frame in range(scene.frame_start, target + 1):
        scene.frame_set(frame)
    for name in cameras:
        scene.camera = bpy.data.objects[name]
        scene.render.filepath = os.path.join(out_dir, "%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("STREAM rendered", scene.render.filepath)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if args and args[0] == "render":
        render_settings()
        render(args[1].split(","), int(args[2]), int(args[3]), args[4] if len(args) > 4 else os.path.join(HERE, "renders"))
    else:
        build()
