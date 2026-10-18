"""程序生成几件素材，加进森林素材库（巨树根洞用，以后的森林场景也能用）：

  A_root_arch_a / A_root_arch_b   树根拱：几股粗根从地里拱起、越过头顶再扎回地里，可以从下面走过去（出口）
  A_root_coil                      贴地拱起的矮树根（装饰、绊脚的感觉）
  A_glow_mushroom                  一丛会发微光的小蘑菇
  A_fallen_trunk                   一根粗大的倒木，一头带断裂的根盘，表面长苔藓

    blender --background kit/forest_kit.blend --python tools/make_root_assets.py

可重复运行（同名素材先删再建）。树根用素材库里的“Mossy Tree Bark”贴图，沿根平铺；
蘑菇的菌盖自发光，进 Godot 后是带自发光的标准材质。
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from migrate_v2 import CATALOGS  # noqa: E402

rng = random.Random(7)
kit = bpy.data.collections["Kit"]
preview = bpy.data.collections["Preview"]


def tube(bm, uv_layer, points, radii, sides=10, uv_length=1.4, twist=0.0):
    """沿 points 扫一圈圆，radii 为每个点的半径。UV：u 绕一圈 0..1，v 沿长度每 uv_length 米一个周期。"""
    rings = []
    length = 0.0
    lengths = [0.0]
    for a, b in zip(points[:-1], points[1:]):
        length += (b - a).length
        lengths.append(length)
    for i, p in enumerate(points):
        tangent = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        side = tangent.cross(Vector((0, 0, 1)))
        if side.length < 1e-4:
            side = tangent.cross(Vector((1, 0, 0)))
        side.normalize()
        up = side.cross(tangent).normalized()
        ring = []
        for k in range(sides):
            a = k / sides * math.tau + twist * i
            # 截面略扁、带一点不规则，看起来像树根而不是水管
            r = radii[i] * (1.0 + 0.12 * noise.noise(p * 1.7 + Vector((k * 0.7, 0, 0))))
            offset = side * math.cos(a) * r * 1.15 + up * math.sin(a) * r * 0.9
            ring.append(bm.verts.new(p + offset))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            face = bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
            face.smooth = True
            for loop, (u, v) in zip(face.loops, ((k / sides, lengths[i]), ((k + 1) / sides, lengths[i]),
                                                 ((k + 1) / sides, lengths[i + 1]), (k / sides, lengths[i + 1]))):
                loop[uv_layer].uv = (u, v / uv_length)
    # 两端封口（埋在地里，看不见，封上免得从里面看到背面）
    for ring in (rings[0], rings[-1]):
        bm.faces.new(ring if ring is rings[-1] else list(reversed(ring)))


def arch_path(start, end, height, wobble, steps=28):
    """从 start 拱起到 end，最高 height。两端略往下扎进地里。"""
    points = []
    for i in range(steps + 1):
        t = i / steps
        p = start.lerp(end, t)
        lift = math.sin(t * math.pi) ** 0.8 * height
        jitter = Vector((noise.noise(p * 0.6 + Vector((1, 2, 3))), noise.noise(p * 0.6 + Vector((4, 5, 6))), 0)) * wobble
        points.append(Vector((p.x, p.y, -0.35 + lift)) + jitter * math.sin(t * math.pi))
    return points


def bark_material():
    name = "RootBark"
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    source = bpy.data.materials["Mossy Tree Bark"]
    images = {n.image.name: n.image for n in source.node_tree.nodes if n.type == "TEX_IMAGE" and n.image}
    out = tree.nodes.new("ShaderNodeOutputMaterial")
    bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
    tree.links.new(bsdf.outputs[0], out.inputs[0])
    for key, socket in (("BaseColor", "Base Color"), ("Roughness", "Roughness"), ("Normal", "Normal")):
        image = next(img for n, img in images.items() if key in n)
        tex = tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        if key == "Normal":
            image.colorspace_settings.name = "Non-Color"
            nm = tree.nodes.new("ShaderNodeNormalMap")
            tree.links.new(tex.outputs[0], nm.inputs["Color"])
            tree.links.new(nm.outputs[0], bsdf.inputs["Normal"])
        elif key == "Roughness":
            image.colorspace_settings.name = "Non-Color"
            tree.links.new(tex.outputs[0], bsdf.inputs["Roughness"])
        else:
            tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    return material


def glow_material():
    name = "GlowMushroomCap"
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.82, 0.86, 0.95, 1)
    bsdf.inputs["Roughness"].default_value = 0.5
    bsdf.inputs["Emission Color"].default_value = (0.55, 0.72, 1.0, 1)
    bsdf.inputs["Emission Strength"].default_value = 2.5
    stem = bpy.data.materials.get("GlowMushroomStem") or bpy.data.materials.new("GlowMushroomStem")
    stem.use_nodes = True
    sb = next(n for n in stem.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    sb.inputs["Base Color"].default_value = (0.85, 0.84, 0.78, 1)
    sb.inputs["Roughness"].default_value = 0.6
    return material, stem


def replace_asset(name, label):
    old = bpy.data.collections.get("A_" + name)
    if old is not None:
        for obj in list(old.all_objects):
            bpy.data.objects.remove(obj)
        for p in [o for o in preview.objects if o.instance_collection is None]:
            bpy.data.objects.remove(p)
        bpy.data.collections.remove(old)
    col = bpy.data.collections.new("A_" + name)
    kit.children.link(col)
    col.asset_mark()
    col.asset_data.description = label
    col.asset_data.catalog_id = CATALOGS["wood" if name.startswith("root") else "critters"][1]
    col.asset_data.tags.new("forest")
    index = len(preview.objects)
    empty = bpy.data.objects.new("P_" + name, None)
    empty.instance_type = "COLLECTION"
    empty.instance_collection = col
    empty.location = ((index % 7) * 9.0, -(index // 7) * 9.0, 0.0)
    preview.objects.link(empty)
    return col


def mesh_object(name, bm, material, col):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    return obj


def make_arch(name, label, span, height, strands, thickness):
    col = replace_asset(name, label)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for s in range(strands):
        spread = (s - (strands - 1) / 2) / max(strands - 1, 1)
        start = Vector((-span / 2 - rng.uniform(0.2, 1.0), spread * 1.2 + rng.uniform(-0.3, 0.3), 0))
        end = Vector((span / 2 + rng.uniform(0.2, 1.0), spread * 1.0 + rng.uniform(-0.3, 0.3), 0))
        h = height * rng.uniform(0.8, 1.05) * (1.0 - 0.25 * abs(spread))
        points = arch_path(start, end, h, 0.35)
        r = thickness * rng.uniform(0.55, 1.0)
        radii = [r * (1.0 + 1.1 * (1.0 - math.sin(i / (len(points) - 1) * math.pi)) ** 2) for i in range(len(points))]
        tube(bm, uv, points, radii, twist=rng.uniform(-0.05, 0.05))
    # 根脚：两端各分出几条细根爬在地上
    for end_x in (-span / 2, span / 2):
        for k in range(4):
            a = rng.uniform(0, math.tau)
            base = Vector((end_x, rng.uniform(-0.8, 0.8), 0))
            tip = base + Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(1.2, 2.4)
            points = arch_path(base, tip, 0.45, 0.15, steps=10)
            tube(bm, uv, points, [thickness * 0.35 * (1.0 - 0.6 * i / 10) + 0.03 for i in range(11)], sides=7)
    mesh_object(name, bm, bark_material(), col)
    print("ROOTS made", name)


def make_coil():
    col = replace_asset("root_coil", "贴地矮树根")
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for s in range(3):
        start = Vector((-1.8 + rng.uniform(-0.3, 0.3), s * 0.5 - 0.5, 0))
        end = Vector((1.8 + rng.uniform(-0.3, 0.3), s * 0.4 - 0.3, 0))
        points = arch_path(start, end, rng.uniform(0.55, 0.85), 0.2, steps=16)
        tube(bm, uv, points, [0.16 * (1.0 + 0.8 * (1.0 - math.sin(i / 16 * math.pi)) ** 2) for i in range(17)])
    mesh_object("root_coil", bm, bark_material(), col)
    print("ROOTS made root_coil")


def make_mushrooms():
    col = replace_asset("glow_mushroom", "发光小蘑菇丛")
    cap_mat, stem_mat = glow_material()
    caps = bmesh.new()
    stems = bmesh.new()
    for i in range(6):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.0, 0.14)
        x, y = math.cos(a) * d, math.sin(a) * d
        h = rng.uniform(0.05, 0.13)
        r = rng.uniform(0.018, 0.035)
        bmesh.ops.create_cone(stems, cap_ends=True, segments=8, radius1=r * 0.35, radius2=r * 0.28, depth=h,
                              matrix=__import__("mathutils").Matrix.Translation((x, y, h / 2)))
        result = bmesh.ops.create_uvsphere(caps, u_segments=10, v_segments=5, radius=r)
        for v in result["verts"]:
            v.co.z = max(v.co.z, -r * 0.15) * 0.55
            v.co += Vector((x, y, h))
    mesh_object("glow_mushroom_caps", caps, cap_mat, col)
    mesh_object("glow_mushroom_stems", stems, stem_mat, col)
    print("ROOTS made glow_mushroom")


def make_fallen_trunk():
    col = replace_asset("fallen_trunk", "粗大倒木")
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    length = 5.2
    steps = 22
    points = []
    for i in range(steps + 1):
        t = i / steps
        x = -length / 2 + t * length
        sag = 0.12 * math.sin(t * math.pi)
        points.append(Vector((x, 0.18 * noise.noise(Vector((x * 0.4, 1.3, 0))), 0.42 - sag)))
    radii = [0.46 * (1.0 + 0.35 * (1.0 - i / steps) ** 3) * (0.82 + 0.18 * (1.0 - i / steps)) for i in range(steps + 1)]
    tube(bm, uv, points, radii, sides=14, uv_length=1.6)
    # 根盘那头：几条短而粗的断根往外翘
    root_end = points[0]
    for k in range(7):
        a = k / 7 * math.tau + rng.uniform(-0.3, 0.3)
        tip = root_end + Vector((-0.5, math.cos(a) * 1.0, 0.42 + math.sin(a) * 0.9)) * rng.uniform(0.9, 1.3)
        seg = [root_end.lerp(tip, j / 5) for j in range(6)]
        tube(bm, uv, seg, [0.2 * (1.0 - 0.75 * j / 5) + 0.03 for j in range(6)], sides=7)
    # 细端：两根断枝
    for k in range(2):
        base = points[int(steps * rng.uniform(0.6, 0.9))]
        tip = base + Vector((rng.uniform(0.2, 0.6), rng.choice((-1, 1)) * rng.uniform(0.6, 1.0), rng.uniform(0.3, 0.7)))
        tube(bm, uv, [base.lerp(tip, j / 4) for j in range(5)], [0.1 * (1.0 - 0.7 * j / 4) + 0.02 for j in range(5)], sides=6)
    mesh_object("fallen_trunk", bm, bark_material(), col)
    print("ROOTS made fallen_trunk")


if __name__ == "__main__":
    make_fallen_trunk()
    make_arch("root_arch_a", "树根拱（大）", 5.6, 3.3, 5, 0.42)
    make_arch("root_arch_b", "树根拱（小）", 4.4, 2.7, 4, 0.36)
    make_coil()
    make_mushrooms()
    bpy.context.view_layer.layer_collection.children["Kit"].exclude = True
    bpy.ops.wm.save_mainfile(compress=False)
    blend1 = bpy.data.filepath + "1"
    if os.path.exists(blend1):
        os.remove(blend1)
    print("ROOTS saved")
