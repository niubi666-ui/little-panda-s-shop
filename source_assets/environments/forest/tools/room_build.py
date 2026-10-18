"""森林系列场景布景脚本共用的零件（樱花溪谷、巨树根洞、神木圣坛……）：

- 距离场与噪声（numpy）：seg_dist / poly_dist / smoothstep / fbm（每层旋转，避免方块状斑块）
- 贴图：save_png（行 0 = 北）、build_bloom（落花平铺图）
- 网格：grid_mesh（地形）、ribbon（瀑布水帘）、disc（白沫圆盘）
- 材质：waterfall_material、ground_material（Cycles 对照，公式同 Godot terrain.gdshader 遮罩模式）、material_image
- 素材：link_kit（从素材库链接）、Placer（往 Layout 里摆实例）

坐标：Blender X 向东、Y 向北（Godot 的 x、-z）。
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector, noise

TOOLS = os.path.dirname(os.path.abspath(__file__))
FOREST = os.path.dirname(TOOLS)
KIT = os.path.join(FOREST, "kit", "forest_kit.blend")
if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)
from cycles_graph import Graph  # noqa: E402


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy), 0.0, 1.0)
    return np.hypot(px - (ax + t * dx), py - (ay + t * dy))


def poly_dist(px, py, points):
    d = np.full(np.shape(px), 1e9)
    for (ax, ay), (bx, by) in zip(points[:-1], points[1:]):
        d = np.minimum(d, seg_dist(px, py, ax, ay, bx, by))
    return d


def smoothstep(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def fbm(px, py, scale, seed):
    """numpy 上的值噪声（两层），0..1。"""
    out = np.zeros(np.shape(px))
    amp, total = 1.0, 0.0
    for octave in range(3):
        s = scale * (2.03 ** octave)
        # 每层转一个角度：值噪声沿网格方向的痕迹（方方正正的斑块）就看不出来了
        angle = 0.6 + octave * 1.17 + seed * 0.31
        ca, sa = math.cos(angle), math.sin(angle)
        rx, ry = px * ca - py * sa, px * sa + py * ca
        gx, gy = rx * s + seed * 17.3, ry * s - seed * 9.1
        ix, iy = np.floor(gx), np.floor(gy)
        fx, fy = gx - ix, gy - iy
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)

        def h(a, b):
            v = np.sin(a * 127.1 + b * 311.7 + seed) * 43758.5453
            return v - np.floor(v)
        n = (h(ix, iy) * (1 - fx) + h(ix + 1, iy) * fx) * (1 - fy) + (h(ix, iy + 1) * (1 - fx) + h(ix + 1, iy + 1) * fx) * fy
        out += n * amp
        total += amp
        amp *= 0.5
    return out / total


def save_png(array, path):
    """array[row, col, 4]，row 0 = 北（图片上方）。"""
    h, w = array.shape[:2]
    image = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    image.pixels.foreach_set(np.ascontiguousarray(array[::-1]).astype(np.float32).ravel())
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    return image


def grid_mesh(name, size, step, height_fn=None):
    count = int(size / step)
    axis = np.linspace(-size / 2, size / 2, count + 1)
    px, py = np.meshgrid(axis, axis)
    pz = height_fn(px, py) if height_fn else np.zeros_like(px)
    mesh = bpy.data.meshes.new(name)
    verts = np.stack([px.ravel(), py.ravel(), pz.ravel()], axis=1)
    faces = []
    w = count + 1
    for j in range(count):
        for i in range(count):
            a = j * w + i
            faces.append((a, a + 1, a + w + 1, a + w))
    mesh.from_pydata(verts.tolist(), [], faces)
    mesh.polygons.foreach_set("use_smooth", [True] * len(faces))
    uv = mesh.uv_layers.new(name="UVMap")
    co = np.zeros(len(mesh.vertices) * 3)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    loops = np.zeros(len(mesh.loops), dtype=np.int64)
    mesh.loops.foreach_get("vertex_index", loops)
    uv.data.foreach_set("uv", co[loops][:, :2].ravel())
    return mesh


def ribbon(name, lip, width, drop, reach, rows=26, cols=8, spread=0.5):
    """瀑布水帘：从 lip 落下 drop 米，同时向前（南）冲出 reach 米；上窄下宽。UV：u 横向、v 自上而下。"""
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")
    grid = []
    for r in range(rows + 1):
        t = r / rows
        forward = reach * (1.0 - (1.0 - t) ** 2)
        z = lip.z - drop * t ** 1.35
        half = width / 2 * (1.0 + spread * t)
        row = []
        for c in range(cols + 1):
            s = c / cols
            x = lip.x + (s - 0.5) * 2 * half
            bulge = 0.12 * math.sin(s * math.pi)
            row.append(bm.verts.new((x, lip.y - forward - bulge, z)))
        grid.append(row)
    for r in range(rows):
        for c in range(cols):
            face = bm.faces.new((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]))
            face.smooth = True
            for loop, (uu, vv) in zip(face.loops, ((c / cols, r / rows), ((c + 1) / cols, r / rows), ((c + 1) / cols, (r + 1) / rows), (c / cols, (r + 1) / rows))):
                loop[uv_layer].uv = (uu, 1.0 - vv)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return bpy.data.objects.new(name, mesh)


def disc(name, centre, radius, z, segments=32):
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")
    rings = []
    for ring in range(5):
        rr = radius * ring / 4
        rings.append([bm.verts.new((centre[0] + math.cos(a) * rr * 1.25, centre[1] + math.sin(a) * rr * 0.8, z))
                      for a in [k * math.tau / segments for k in range(segments)]])
    for ring in range(4):
        for k in range(segments):
            k2 = (k + 1) % segments
            face = bm.faces.new((rings[ring][k], rings[ring][k2], rings[ring + 1][k2], rings[ring + 1][k]))
            for loop in face.loops:
                co = loop.vert.co
                loop[uv_layer].uv = ((co.x - centre[0]) / radius * 0.5 + 0.5, (co.y - centre[1]) / radius * 0.5 + 0.5)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return bpy.data.objects.new(name, mesh)


def waterfall_material():
    material = bpy.data.materials.get("WaterfallMat") or bpy.data.materials.new("WaterfallMat")
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    g = Graph(tree)
    coord = g.node("ShaderNodeTexCoord").outputs["UV"]
    split = g.node("ShaderNodeSeparateXYZ")
    g.feed(split.inputs[0], coord)
    u, v = split.outputs[0], split.outputs[1]
    streaks = g.node("ShaderNodeTexNoise")
    streaks.inputs["Detail"].default_value = 4.0
    g.feed(streaks.inputs["Vector"], g.vec(g.mul(u, 9.0), g.mul(v, 0.9)))
    streaks.inputs["Scale"].default_value = 3.0
    edge = g.mul(g.smooth(u, 0.0, 0.18), g.smooth(u, 1.0, 0.82))
    alpha = g.math("MULTIPLY", g.mul(g.smooth(streaks.outputs["Fac"], 0.35, 0.7), edge), 0.95, clamp=True)
    surface = g.node("ShaderNodeBsdfPrincipled")
    surface.inputs["Base Color"].default_value = (0.86, 0.93, 0.95, 1.0)
    surface.inputs["Roughness"].default_value = 0.35
    g.feed(surface.inputs["Alpha"], alpha)
    out = g.node("ShaderNodeOutputMaterial")
    g.feed(out.inputs["Surface"], surface.outputs[0])
    return material


def build_bloom(folder, size=1024, seed=7, petals=170, flowers=55, petal_colour=(0.98, 0.58, 0.70)):
    """落花贴图（可平铺，约 1.4 米一块）：樱花花瓣 + 三叶草的小白花，透明底。"""
    r = np.random.default_rng(seed)
    ss = 2
    n = size * ss
    rgba = np.zeros((n, n, 4), dtype=np.float32)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)

    def stamp(cx, cy, half_len, half_wid, angle, colour, notch=True):
        x0, x1 = int(cx - half_len - 2), int(cx + half_len + 3)
        y0, y1 = int(cy - half_len - 2), int(cy + half_len + 3)
        for ox in (-n, 0, n):            # 平铺：越界的部分从另一边画回来
            for oy in (-n, 0, n):
                xa, xb = max(x0 + ox, 0), min(x1 + ox, n)
                ya, yb = max(y0 + oy, 0), min(y1 + oy, n)
                if xa >= xb or ya >= yb:
                    continue
                lx = xx[ya:yb, xa:xb] - (cx + ox)
                ly = yy[ya:yb, xa:xb] - (cy + oy)
                u = (lx * math.cos(angle) + ly * math.sin(angle)) / half_len
                v = (-lx * math.sin(angle) + ly * math.cos(angle)) / half_wid
                shape = 1.0 - np.clip((u * u + v * v * (1.0 + 0.4 * u)) - 0.85, 0.0, 0.15) / 0.15
                if notch:
                    shape *= np.clip((np.hypot(u - 1.0, v * 0.6) - 0.18) / 0.12, 0.0, 1.0)
                shade = 0.9 + 0.1 * u
                a = np.clip(shape, 0.0, 1.0)
                region = rgba[ya:yb, xa:xb]
                for c in range(3):
                    region[..., c] = region[..., c] * (1 - a) + colour[c] * shade * a
                region[..., 3] = np.maximum(region[..., 3], a)

    for i in range(petals):              # 樱花瓣
        tone = r.uniform(0.0, 1.0)
        colour = (petal_colour[0], petal_colour[1] + 0.16 * tone, petal_colour[2] + 0.12 * tone)
        stamp(r.uniform(0, n), r.uniform(0, n), r.uniform(15, 22) * ss, r.uniform(9, 13) * ss, r.uniform(0, math.tau), colour)
    for i in range(flowers):             # 小白花：五瓣
        cx, cy = r.uniform(0, n), r.uniform(0, n)
        base = r.uniform(0, math.tau)
        size_px = r.uniform(5, 7) * ss
        for k in range(5):
            a = base + k * math.tau / 5
            stamp(cx + math.cos(a) * size_px, cy + math.sin(a) * size_px, size_px, size_px * 0.6, a, (0.97, 0.97, 0.93), notch=False)
        stamp(cx, cy, size_px * 0.45, size_px * 0.45, 0.0, (0.95, 0.82, 0.35), notch=False)
    small = rgba.reshape(size, ss, size, ss, 4).mean(axis=(1, 3))
    # 透明处的颜色外扩成花瓣色，远处 mipmap 不会发黑
    covered = small[..., 3] > 0.05
    mean = small[covered][:, :3].mean(axis=0) if covered.any() else np.array([1.0, 0.8, 0.85])
    alpha = small[..., 3:4]
    small[..., :3] = np.where(alpha > 0.001, small[..., :3] / np.maximum(alpha, 1e-3), mean)
    return save_png(small, os.path.join(folder, "bloom.png"))


def material_image(name, key):
    import forest_export
    material = bpy.data.materials[name]
    surface = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    socket = {"albedo": "Base Color", "normal": "Normal", "roughness": "Roughness"}[key]
    return forest_export.upstream_image(surface.inputs[socket], key)


def ground_material(mask, bloom, grass, grass_tint, grass_scale, bloom_scale, water_z, mask_half, name="RoomGround"):
    """Cycles 对照用的地面材质，公式同 Godot terrain.gdshader 的遮罩模式。"""
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    g = Graph(tree)
    split = g.node("ShaderNodeSeparateXYZ")
    g.feed(split.inputs[0], g.node("ShaderNodeNewGeometry").outputs["Position"])
    bx, by, bz = split.outputs[0], split.outputs[1], split.outputs[2]
    mask_tex = g.node("ShaderNodeTexImage", image=mask, interpolation="Linear", extension="EXTEND")
    g.feed(mask_tex.inputs["Vector"], g.vec(g.math("DIVIDE", g.add(bx, mask_half), mask_half * 2), g.math("DIVIDE", g.add(by, mask_half), mask_half * 2)))
    channels = g.node("ShaderNodeSeparateColor")
    g.feed(channels.inputs[0], mask_tex.outputs["Color"])
    wobble = g.mul(g.sub(g.noise(bx, by, 0.7, 0.0), 0.5), 0.9)
    bed = g.smooth(g.add(channels.outputs[1], g.mul(wobble, 0.25)), 0.25, 0.75)
    path = g.smooth(g.add(channels.outputs[0], g.mul(wobble, 0.35)), 0.25, 0.75)
    blend = g.add(g.mul(g.noise(bx, by, 0.16, 9.0), 0.6), g.mul(g.noise(bx, by, 0.55, 3.0), 0.4))
    patches = g.mul(g.smooth(blend, 0.62, 0.8), 0.4)
    litter = g.math("MULTIPLY", g.math("MAXIMUM", path, patches), g.sub(1.0, bed), clamp=True)
    clover = g.mul(g.mul(g.smooth(g.add(channels.outputs[2], g.mul(wobble, 0.4)), 0.2, 0.8), g.sub(1.0, litter)), g.sub(1.0, bed))
    bloom_amount = mask_tex.outputs["Alpha"]
    moss = g.image(material_image("Forest Floor Moss", "albedo"), bx, by, 3.0)
    macro = g.add(1.0 - 0.18, g.mul(0.36, g.noise(bx, by, 0.09, 20.0)))
    moss = g.mix(moss, g.vec(macro, macro, macro), 1.0, "MULTIPLY")
    clover_colour = g.mix(g.image(material_image(grass, "albedo"), bx, by, grass_scale), grass_tint, 1.0, "MULTIPLY")
    litter_colour = g.image(material_image("Mossy Ground", "albedo"), bx, by, 2.5)
    pebbles = g.mix(g.image(material_image("BrookBedMat", "albedo"), bx, by, 1.8), (0.34, 0.4, 0.38), 1.0, "MULTIPLY")
    colour = g.mix(g.mix(g.mix(moss, clover_colour, clover), litter_colour, litter), pebbles, bed)
    petals = g.node("ShaderNodeTexImage", image=bloom)
    g.feed(petals.inputs["Vector"], g.vec(g.math("DIVIDE", bx, bloom_scale), g.math("DIVIDE", by, bloom_scale)))
    cover = g.math("MULTIPLY", g.mul(petals.outputs["Alpha"], bloom_amount), g.sub(1.0, bed), clamp=True)
    colour = g.mix(colour, petals.outputs["Color"], cover)
    wet = g.smooth(bz, water_z, water_z + 0.18, rising=False)
    shade = g.mix_float(1.0, 0.6, wet)
    colour = g.mix(colour, g.vec(shade, shade, shade), 1.0, "MULTIPLY")
    rough = g.mix_float(g.mix_float(0.85, 0.25, bed), 0.22, wet)
    normal_colour = g.mix(g.mix(g.mix(g.image(material_image("Forest Floor Moss", "normal"), bx, by, 3.0),
                                      g.image(material_image(grass, "normal"), bx, by, grass_scale), clover),
                                g.image(material_image("Mossy Ground", "normal"), bx, by, 2.5), litter),
                          g.image(material_image("BrookBedMat", "normal"), bx, by, 1.8), bed)
    for tex in [n for n in tree.nodes if n.type == "TEX_IMAGE"]:
        if tex.image is not None and tex.image.colorspace_settings.name != "sRGB":
            tex.interpolation = "Linear"
    normal = g.node("ShaderNodeNormalMap", space="TANGENT", uv_map="UVMap")
    g.feed(normal.inputs["Color"], normal_colour)
    surface = g.node("ShaderNodeBsdfPrincipled")
    g.feed(surface.inputs["Base Color"], colour)
    g.feed(surface.inputs["Roughness"], rough)
    g.feed(surface.inputs["Normal"], normal.outputs[0])
    out = g.node("ShaderNodeOutputMaterial")
    g.feed(out.inputs["Surface"], surface.outputs[0])
    return material


def link_kit(names, materials=()):
    """从素材库链接素材集合；地面贴图来源材质整份追加进来（加假用户，导出时要读它们的贴图）。"""
    with bpy.data.libraries.load(KIT, link=True, relative=True) as (source, target):
        target.collections = [n for n in source.collections if n in names and n not in bpy.data.collections]
    with bpy.data.libraries.load(KIT, link=False) as (source, target):
        target.materials = [n for n in materials if n in source.materials and n not in bpy.data.materials]
    for material in target.materials:
        if material is not None:
            material.use_fake_user = True


class Placer:
    """往 Layout 集合里摆素材实例（集合实例，指向素材库里的 A_<名字>）。"""

    def __init__(self, layout, rng, ground_z):
        self.layout = layout
        self.rng = rng
        self.ground_z = ground_z

    def place(self, tag, x, y, scale=1.0, yaw=None, tilt=0.0, sink=0.0, z=None, name=None):
        rng = self.rng
        col = bpy.data.collections.get("A_" + tag)
        if col is None:
            print("ROOM missing asset", tag)
            return None
        obj = bpy.data.objects.new(name or "%s_%04d" % (tag, len(self.layout.objects)), None)
        obj.instance_type = "COLLECTION"
        obj.instance_collection = col
        obj.empty_display_size = 0.2
        obj.location = (x, y, (self.ground_z(x, y) - sink) if z is None else z)
        obj.rotation_euler = (rng.uniform(-tilt, tilt), rng.uniform(-tilt, tilt), rng.uniform(0, math.tau) if yaw is None else yaw)
        obj.scale = (scale,) * 3
        self.layout.objects.link(obj)
        return obj
