"""程序生成遗迹类素材，加进森林素材库（神木圣坛用，以后的圣殿场景也能用）：

  A_broken_column   一截断柱：方形基座 + 带凹槽的柱身，顶上是参差的断口（约 1.4 米高）
  A_column_drum     一节倒在地上的柱段（侧躺，约 1 米长）

    blender --background kit/forest_kit.blend --python tools/make_ruin_assets.py

用素材库里的“Natural Eroded Limestone”贴图（和圣坛石台同一种石头），柱面按圆柱展开 UV。可重复运行。
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_root_assets import replace_asset  # noqa: E402  （同名素材先删再建、标记资产、加进预览）

rng = random.Random(5)
FLUTES = 16


def limestone():
    name = "RuinLimestone"
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    source = bpy.data.materials["Natural Eroded Limestone"]
    images = {n.image.name: n.image for n in source.node_tree.nodes if n.type == "TEX_IMAGE" and n.image}
    out = tree.nodes.new("ShaderNodeOutputMaterial")
    bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
    tree.links.new(bsdf.outputs[0], out.inputs[0])
    for key, socket in (("BaseColor", "Base Color"), ("Roughness", "Roughness"), ("Normal", "Normal")):
        image = next(img for n, img in images.items() if key in n)
        tex = tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        if key == "Normal":
            nm = tree.nodes.new("ShaderNodeNormalMap")
            tree.links.new(tex.outputs[0], nm.inputs["Color"])
            tree.links.new(nm.outputs[0], bsdf.inputs["Normal"])
        elif key == "Roughness":
            tree.links.new(tex.outputs[0], bsdf.inputs["Roughness"])
        else:
            tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    return material


def fluted_shaft(bm, uv, radius, z0, z1, rings, broken_top=False, segments=FLUTES * 4):
    """带凹槽的柱身。broken_top：顶端一圈点按噪声高低错落，再封一个凹凸的断面。"""
    grid = []
    for r in range(rings + 1):
        t = r / rings
        row = []
        for k in range(segments):
            a = k / segments * math.tau
            flute = 1.0 - 0.06 * max(0.0, math.cos(a * FLUTES)) ** 2
            rr = radius * flute * (1.0 - 0.04 * t)
            z = z0 + (z1 - z0) * t
            if broken_top and r == rings:
                z += 0.1 * noise.noise(Vector((math.cos(a) * 1.3, math.sin(a) * 1.3, 4.2))) - 0.16 * max(0.0, math.sin(a + 0.6)) - 0.03 * math.sin(a * 7.0)
            row.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z)))
        grid.append(row)
    for r in range(rings):
        for k in range(segments):
            k2 = (k + 1) % segments
            face = bm.faces.new((grid[r][k], grid[r][k2], grid[r + 1][k2], grid[r + 1][k]))
            face.smooth = True
            for loop in face.loops:
                co = loop.vert.co
                a = math.atan2(co.y, co.x) % math.tau
                if k2 == 0 and a < 0.5:
                    a += math.tau
                loop[uv].uv = (a / math.tau * radius * math.tau / 1.2, co.z / 1.2)
    # 顶面：从柱心往外一圈圈，断面高低不平
    top = grid[-1]
    centre_z = sum(v.co.z for v in top) / len(top) - 0.05
    centre = bm.verts.new((0.0, 0.0, centre_z))
    for k in range(segments):
        k2 = (k + 1) % segments
        face = bm.faces.new((top[k], top[k2], centre))
        for loop in face.loops:
            co = loop.vert.co
            loop[uv].uv = (co.x / 1.2 + 0.5, co.y / 1.2 + 0.5)
    return grid


def plinth(bm, uv, half, z0, z1):
    result = bmesh.ops.create_cube(bm, size=1.0)
    for v in result["verts"]:
        v.co = Vector((v.co.x * half * 2, v.co.y * half * 2, z0 + (v.co.z + 0.5) * (z1 - z0)))
    for face in [f for f in bm.faces if all(v in result["verts"] for v in f.verts)]:
        for loop in face.loops:
            co = loop.vert.co
            n = face.normal
            loop[uv].uv = (co.x + co.y, co.z) if abs(n.z) < 0.5 else (co.x, co.y)


def finish(name, bm, col):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(limestone())
    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    return obj


def make_broken_column():
    col = replace_asset("broken_column", "断柱（矮）")
    col.asset_data.catalog_id = "8f2a1b10-0000-4000-8000-000000000006"
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    plinth(bm, uv, 0.62, 0.0, 0.28)
    plinth(bm, uv, 0.54, 0.28, 0.42)
    fluted_shaft(bm, uv, 0.42, 0.42, 1.45, 8, broken_top=True)
    finish("broken_column", bm, col)
    print("RUINS made broken_column")


def make_column_drum():
    col = replace_asset("column_drum", "倒地柱段")
    col.asset_data.catalog_id = "8f2a1b10-0000-4000-8000-000000000006"
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    fluted_shaft(bm, uv, 0.42, 0.0, 1.0, 5, broken_top=True)
    # 底端也封上
    bottom = [v for v in bm.verts if abs(v.co.z) < 1e-4]
    bottom.sort(key=lambda v: math.atan2(v.co.y, v.co.x))
    bm.faces.new(list(reversed(bottom)))
    # 侧躺：沿 X 方向，压在地上一点
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=(-0.5, 0.0, 0.36))
    finish("column_drum", bm, col)
    print("RUINS made column_drum")


make_broken_column()
make_column_drum()
bpy.context.view_layer.layer_collection.children["Kit"].exclude = True
bpy.ops.wm.save_mainfile(compress=False)
blend1 = bpy.data.filepath + "1"
if os.path.exists(blend1):
    os.remove(blend1)
print("RUINS saved")
