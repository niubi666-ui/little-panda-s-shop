"""Deterministic, editable botanical geometry for the two combat-room studies.

No downloads, operators, particles, or billboards are used. Every public factory
returns an Empty in the Flora collection; all vertices below it are local. These
are Blender art-source assets, not gameplay placement or collision definitions.
"""
from math import sin, cos, pi, sqrt
from random import Random

import bpy
from mathutils import Vector


LEAF_MATS = ["leaf_0", "leaf_1", "leaf_2", "leaf_3", "leaf_4"]


class _Geometry:
    def __init__(self):
        self.verts = []
        self.faces = []
        self.materials = []

    def add(self, verts, faces, material=0):
        offset = len(self.verts)
        self.verts.extend(tuple(v) for v in verts)
        self.faces.extend(tuple(offset + i for i in face) for face in faces)
        self.materials.extend([material] * len(faces))

    def mesh(self, kit, name, root, mats, smooth=False):
        if not self.faces:
            return None
        obj = kit.mesh(name, self.verts, self.faces, mat=mats[0], group="Flora")
        for mat in mats[1:]:
            obj.data.materials.append(kit.mats[mat] if isinstance(mat, str) else mat)
        for poly, index in zip(obj.data.polygons, self.materials):
            poly.material_index = index
            poly.use_smooth = smooth
        obj.parent = root
        return obj


def _root(kit, name, loc, kind):
    obj = bpy.data.objects.new(name, None)
    kit.collection("Flora").objects.link(obj)
    obj.location = loc
    obj.empty_display_size = 0.18
    obj["asset_kind"] = kind
    obj["replaceable_art_asset"] = True
    obj["procedural_source"] = "room_foliage.py"
    return obj


def _unit(rng):
    z = rng.uniform(-1, 1)
    a = rng.uniform(0, 2 * pi)
    r = sqrt(max(0, 1 - z * z))
    return Vector((r * cos(a), r * sin(a), z))


def _frame(axis):
    axis = Vector(axis).normalized()
    reference = Vector((0, 0, 1)) if abs(axis.z) < 0.92 else Vector((0, 1, 0))
    side = axis.cross(reference).normalized()
    return side, axis.cross(side).normalized()


def _tube(geo, points, radii, segments=7, mat=0, phase=0):
    """A joined tapering branch; avoid separate object/draw call per segment."""
    points = [Vector(p) for p in points]
    if len(points) < 2:
        return
    verts, faces = [], []
    for i, point in enumerate(points):
        if i == 0:
            direction = points[1] - point
        elif i == len(points) - 1:
            direction = point - points[i - 1]
        else:
            direction = points[i + 1] - points[i - 1]
        side, normal = _frame(direction)
        for j in range(segments):
            a = 2 * pi * j / segments + phase
            # Slight fluting makes the trunk less like a smooth cylinder.
            r = radii[i] * (1 + 0.065 * sin(j * 2.71 + i * 0.53))
            verts.append(point + r * (side * cos(a) + normal * sin(a)))
    for i in range(len(points) - 1):
        for j in range(segments):
            a, b = i * segments + j, i * segments + (j + 1) % segments
            faces.append((a, b, b + segments, a + segments))
    faces.append(tuple(reversed(range(segments))))
    faces.append(tuple((len(points) - 1) * segments + j for j in range(segments)))
    geo.add(verts, faces, mat)


def _leaf(geo, base, direction, normal, length, width, material=0, heart=False):
    """Closed outline with a raised midrib; every leaf catches its own light."""
    base, axis, n = Vector(base), Vector(direction).normalized(), Vector(normal).normalized()
    side = axis.cross(n)
    if side.length < 0.05:
        side, n = _frame(axis)
    else:
        side.normalize()
        n = side.cross(axis).normalized()
    if heart:
        # Heart/ivy silhouette: lobed shoulders, narrower middle, pointed tip.
        outline = [(0.03, 0), (-0.07, -0.31), (0.17, -0.54),
                   (0.48, -0.38), (1.0, 0), (0.48, 0.38),
                   (0.17, 0.54), (-0.07, 0.31)]
    else:
        outline = [(0, 0), (0.2, -0.34), (0.50, -0.50),
                   (0.77, -0.29), (1.0, 0), (0.77, 0.29),
                   (0.50, 0.50), (0.2, 0.34)]
    verts = []
    for t, w in outline:
        curl = length * (0.025 * sin(t * pi) - 0.13 * t * t)
        verts.append(base + axis * (length * t) + side * (width * w) + n * curl)
    verts.append(base + axis * (length * 0.43) + n * (length * 0.075))
    geo.add(verts, [(8, (i + 1) % 8, i) for i in range(8)], material)


def tree(kit, name, loc, height=8, spread=4, seed=1):
    """An irregular branching broadleaf tree with thousands of separate leaves.

    ``spread`` is approximate crown radius. The trunk starts at local ground;
    branches/leaf sprays are one bark mesh and one multi-material foliage mesh.
    """
    rng = Random(seed)
    root = _root(kit, name, loc, "broadleaf_tree")
    root["art_seed"] = seed
    bark, foliage = _Geometry(), _Geometry()
    h = height
    lean = Vector((rng.uniform(-0.09, 0.09) * h, rng.uniform(-0.07, 0.07) * h, 0))
    trunk = [Vector((0, 0, 0))]
    for i in range(1, 10):
        t = i / 9
        trunk.append(lean * t + Vector((sin(t * 5) * h * 0.02,
                                       cos(t * 4) * h * 0.018, h * t * 0.88)))
    trunk_r = [h * (0.061 * (1 - i / 10) ** 1.1 + 0.004) for i in range(10)]
    _tube(bark, trunk, trunk_r, segments=13, phase=0.1)
    # Root flares anchor the tree in soil instead of balancing on a narrow pole.
    for i in range(7):
        a = i * 2 * pi / 7 + rng.uniform(-0.18, 0.18)
        radial = Vector((cos(a), sin(a), 0))
        _tube(bark, [Vector((0, 0, h * 0.045)), radial * h * 0.065,
                     radial * h * rng.uniform(0.13, 0.20) + Vector((0, 0, 0.02))],
              [h * 0.028, h * 0.028, h * 0.003], segments=7)
    # Alternate boughs with deliberately uneven heights and asymmetric tips.
    twig_tips = []
    for b in range(13):
        a = b * 2.399963 + rng.uniform(-0.25, 0.25)
        level = 0.38 + (b / 13) * 0.44
        start = lean * level + Vector((0, 0, h * level))
        radial = Vector((cos(a), sin(a), 0))
        lateral = Vector((-sin(a), cos(a), 0))
        reach = spread * rng.uniform(0.69, 1.11) * (1 - 0.27 * (level - 0.4))
        tip = start + radial * reach + Vector((0, 0, h * rng.uniform(0.12, 0.26)))
        midpoint = start.lerp(tip, 0.52) + lateral * reach * rng.uniform(-0.11, 0.11)
        midpoint.z -= h * 0.025
        _tube(bark, [start, start.lerp(midpoint, 0.35), midpoint, tip],
              [h * 0.027 * (1 - level * 0.5), h * 0.019, h * 0.011, h * 0.003], 8)
        for s in range(5):
            u = 0.40 + s * 0.14
            fork = start.lerp(tip, min(u, 1.0))
            sign = -1 if s % 2 else 1
            fork_dir = (radial * rng.uniform(0.28, 0.72) + lateral * sign * rng.uniform(0.50, 0.95)).normalized()
            second = fork + fork_dir * reach * rng.uniform(0.29, 0.48)
            second.z += h * rng.uniform(0.035, 0.12)
            _tube(bark, [fork, fork.lerp(second, 0.55), second],
                  [h * 0.009, h * 0.0045, h * 0.0015], 6)
            for k in range(3):
                origin = fork.lerp(second, 0.5 + k * 0.22)
                spray_dir = (fork_dir + _unit(rng) * 0.75).normalized()
                spray_dir.z = abs(spray_dir.z) * 0.7 + 0.10
                spray_dir.normalize()
                end = origin + spray_dir * reach * rng.uniform(0.17, 0.30)
                _tube(bark, [origin, end], [h * 0.003, h * 0.0007], 5)
                twig_tips.append((origin, end, spray_dir))
    # Each spray follows a twig with individual leaves distributed along it.
    # The varied planes remain legible from a high isometric camera.
    for origin, end, spray_dir in twig_tips:
        for j in range(29):
            u = rng.uniform(0.15, 1.18)
            p = origin.lerp(end, u) + _unit(rng) * rng.uniform(0.035, h * 0.043)
            axis = (_unit(rng) * 0.73 + spray_dir * 0.7).normalized()
            axis.z *= 0.55
            axis.normalize()
            n = (_unit(rng) * 0.42 + Vector((0, 0, 1))).normalized()
            size = h * rng.uniform(0.025, 0.050)
            color = rng.choices(range(5), [32, 32, 18, 12, 6])[0]
            _leaf(foliage, p, axis, n, size, size * rng.uniform(0.43, 0.65), color)
    bark.mesh(kit, name + "_TrunkBranches", root, ["bark"], smooth=True)
    foliage.mesh(kit, name + "_IndividualLeaves", root, LEAF_MATS)
    root["leaf_count"] = len(twig_tips) * 29
    return root


def ivy(kit, name, anchor, length=2, width=1, seed=1):
    """Hanging ivy, default in the XZ wall plane and facing negative Y.

    Rotate the returned Empty for another wall. Anchor is the top center; leaves
    fall toward local -Z with local negative-Y displacement away from the wall.
    """
    rng = Random(seed)
    root = _root(kit, name, anchor, "hanging_ivy")
    stems, foliage = _Geometry(), _Geometry()
    strands = max(4, int(width * 5))
    for s in range(strands):
        x = (s / max(1, strands - 1) - 0.5) * width
        reach = length * rng.uniform(0.64, 1.0)
        sway = rng.uniform(-0.20, 0.20) * width
        phase = rng.uniform(0, 2 * pi)
        points = []
        count = max(12, int(reach * 17))
        for i in range(count + 1):
            t = i / count
            p = Vector((x + sin(t * 9 + phase) * width * 0.07 + sway * t,
                        -0.04 - sin(t * 7 + phase) * 0.045 - 0.075 * t,
                        -reach * t))
            points.append(p)
        _tube(stems, points, [0.018 * (1 - 0.68 * i / count) for i in range(count + 1)], 5)
        for i in range(count):
            for side in [-1, 1]:
                p = points[i] + Vector((rng.uniform(-0.035, 0.035), -0.02, rng.uniform(-0.03, 0.03)))
                axis = Vector((side * rng.uniform(0.35, 0.8), rng.uniform(-0.45, 0.05), -rng.uniform(0.45, 0.9))).normalized()
                size = rng.uniform(0.12, 0.23) * min(1.15, max(0.7, length / 2))
                size *= 1 - 0.22 * i / count
                _leaf(foliage, p, axis, (0, -1, rng.uniform(-0.2, 0.2)), size, size * 0.94,
                      rng.choices(range(5), [22, 30, 28, 15, 5])[0], heart=True)
    stems.mesh(kit, name + "_Vines", root, ["bark"], smooth=True)
    foliage.mesh(kit, name + "_HeartLeaves", root, LEAF_MATS)
    return root


def flower_patch(kit, name, center, extent=(2, 1), count=30, seed=1):
    """A loose ground-level clump of white and purple five-petal wildflowers."""
    rng = Random(seed)
    root = _root(kit, name, center, "wildflower_patch")
    stems, foliage, flowers = _Geometry(), _Geometry(), _Geometry()
    for i in range(count):
        # Elliptical distribution with clumping; extent denotes full width/depth.
        a, radius = rng.uniform(0, 2 * pi), sqrt(rng.random())
        p = Vector((cos(a) * radius * extent[0] * 0.5,
                    sin(a) * radius * extent[1] * 0.5, 0))
        height = rng.uniform(0.20, 0.58)
        lean = Vector((rng.uniform(-0.08, 0.08), rng.uniform(-0.08, 0.08), height))
        tip = p + lean
        _tube(stems, [p, p + lean * 0.5 + Vector((0.01, 0, 0)), tip], [0.009, 0.006, 0.004], 5)
        for k in range(4):
            angle = a + k * 2.3
            axis = Vector((cos(angle), sin(angle), rng.uniform(0.05, 0.45)))
            size = rng.uniform(0.09, 0.18)
            _leaf(foliage, p + lean * (0.14 + k * 0.17), axis, (0, 0, 1), size, size * 0.4, rng.randrange(4))
        tilt = Vector((rng.uniform(-0.18, 0.18), rng.uniform(-0.18, 0.18), 1)).normalized()
        side, front = _frame(tilt)
        petal_r = rng.uniform(0.042, 0.075)
        flower_color = 0 if rng.random() < 0.58 else 1
        petals = 5 if flower_color == 0 else 6
        for k in range(petals):
            angle = k * 2 * pi / petals + a
            direction = cos(angle) * side + sin(angle) * front
            across = tilt.cross(direction)
            # Spoon-shaped petals with raised outer rim and a central dip.
            verts = [tip + tilt * 0.004,
                     tip + direction * petal_r * 0.45 - across * petal_r * 0.38,
                     tip + direction * petal_r * 0.95 - across * petal_r * 0.32 + tilt * 0.025,
                     tip + direction * petal_r * 1.10 + tilt * 0.032,
                     tip + direction * petal_r * 0.95 + across * petal_r * 0.32 + tilt * 0.025,
                     tip + direction * petal_r * 0.45 + across * petal_r * 0.38,
                     tip + direction * petal_r * 0.58 + tilt * 0.002]
            flowers.add(verts, [(6, n, (n + 1) % 6) for n in range(6)], flower_color)
        # Golden center as a tiny domed ring, within the same multi-material mesh.
        center_points = [tip + tilt * 0.021]
        center_points += [tip + petal_r * 0.26 * (cos(k * pi / 4) * side + sin(k * pi / 4) * front) + tilt * 0.012 for k in range(8)]
        flowers.add(center_points, [(0, k + 1, (k + 1) % 8 + 1) for k in range(8)], 2)
    stems.mesh(kit, name + "_Stems", root, ["leaf_0"], smooth=True)
    foliage.mesh(kit, name + "_Leaves", root, LEAF_MATS)
    flowers.mesh(kit, name + "_Flowers", root, ["flower_white", "flower_purple", "gold"], smooth=True)
    return root


def fern(kit, name, loc, scale=1, seed=1):
    """Arching feathered fern, with true paired leaflets instead of planes."""
    rng = Random(seed)
    root = _root(kit, name, loc, "fern")
    stems, foliage = _Geometry(), _Geometry()
    for f in range(12):
        a = f * 2.399963 + rng.uniform(-0.18, 0.18)
        reach = scale * rng.uniform(0.50, 0.91)
        crown_h = scale * rng.uniform(0.40, 0.66)
        outward = Vector((cos(a), sin(a), 0))
        lateral = Vector((-sin(a), cos(a), 0))
        points = []
        steps = 21
        for k in range(steps + 1):
            t = k / steps
            z = crown_h * sin(t * pi * 0.87) + scale * 0.035
            points.append(outward * reach * t ** 0.80 + Vector((0, 0, z)))
        _tube(stems, points, [scale * 0.009 * (1 - 0.8 * k / steps) for k in range(steps + 1)], 5)
        for k in range(3, steps):
            t = k / steps
            leaflet = scale * (0.22 * sin(t * pi) ** 0.8 + 0.018) * rng.uniform(0.87, 1.1)
            for sign in [-1, 1]:
                axis = (lateral * sign * 0.93 + outward * (0.34 + 0.32 * t) + Vector((0, 0, 0.08))).normalized()
                _leaf(foliage, points[k], axis, (0, 0, 1), leaflet, leaflet * 0.31, rng.choice([0, 1, 1, 2, 3]))
        _leaf(foliage, points[-2], outward, (0, 0, 1), scale * 0.09, scale * 0.025, 2)
    stems.mesh(kit, name + "_FrondRibs", root, ["leaf_0"], smooth=True)
    foliage.mesh(kit, name + "_PinnateLeaves", root, LEAF_MATS)
    return root


def _terracotta_material():
    name = "Botanical_WarmWeatheredTerracotta"
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (0.27, 0.13, 0.055, 1)
    mat.use_nodes = True
    nt = mat.node_tree
    shader = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (0.27, 0.13, 0.055, 1)
    shader.inputs["Roughness"].default_value = 0.78
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 13
    noise.inputs["Detail"].default_value = 3
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.12, 0.058, 0.025, 1)
    ramp.color_ramp.elements[1].color = (0.40, 0.23, 0.11, 1)
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], shader.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.22
    bump.inputs["Distance"].default_value = 0.035
    nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    return mat


def pot(kit, name, loc, scale=1, seed=1):
    """Weathered hollow terracotta pot, real soil surface, and a fern crown."""
    root = _root(kit, name, loc, "potted_fern")
    material = _terracotta_material()
    profile = [(0.20, 0), (0.24, 0.025), (0.23, 0.08), (0.29, 0.18),
               (0.34, 0.37), (0.355, 0.50), (0.39, 0.52), (0.395, 0.57),
               (0.38, 0.60), (0.335, 0.60), (0.327, 0.55), (0.30, 0.44),
               (0.23, 0.09), (0.0, 0.09), (0.0, 0.0), (0.20, 0.0)]
    obj = kit.lathe(name + "_ClayVessel", (0, 0, 0), [(r * scale, z * scale) for r, z in profile],
                    mat=material, segments=40, group="Flora")
    obj.parent = root
    for poly in obj.data.polygons:
        poly.use_smooth = True
    soil = _Geometry()
    verts = [(0, 0, 0.515 * scale)] + [(cos(i * 2 * pi / 32) * 0.32 * scale,
             sin(i * 2 * pi / 32) * 0.32 * scale, 0.515 * scale) for i in range(32)]
    soil.add(verts, [(0, i + 1, (i + 1) % 32 + 1) for i in range(32)])
    soil.mesh(kit, name + "_Soil", root, ["soil"])
    crown = fern(kit, name + "_Fern", (0, 0, 0.52 * scale), scale=scale * 0.74, seed=seed)
    crown.parent = root
    return root
