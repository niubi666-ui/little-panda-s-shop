"""Sakura grove training court: cherry trees, low mossy walls, wooden gate, stone lanterns.

The flagstone court, grass, petals, dappled light and light shafts are Godot-side
(presentation/rooms/sakura_grove); this file only produces the props around them.

Run:  blender --background --factory-startup --python build_sakura_grove.py -- <out.glb> [<out.blend>]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector

import sg_lib as sg

HX, HY = 10.0, 8.5          # wall centre lines; the walkable rectangle is 9.5 x 8.0 (play_half in the room script)
rng = random.Random(20261012)

STONE_A = sg.srgb("#6f6d78")
STONE_B = sg.srgb("#a09ca6")
STONE_MOSS = sg.srgb("#6f8558")
BARK_A = sg.srgb("#33211f")
BARK_B = sg.srgb("#6b4a42")
GATE_A = sg.srgb("#6a2f2a")
GATE_B = sg.srgb("#a8483a")
BLOOMS = [
    (sg.srgb("#d9719d"), sg.srgb("#ffd6e4")),
    (sg.srgb("#e186ab"), sg.srgb("#ffe6ee")),
    (sg.srgb("#cf6594"), sg.srgb("#ffc6da")),
    (sg.srgb("#e79ab8"), sg.srgb("#fff2f6")),
]
BUSH = (sg.srgb("#2b5f47"), sg.srgb("#6fa85a"))
ROCK = (sg.srgb("#5f5d68"), sg.srgb("#a6a2ab"))
INDIGO = sg.srgb("#3b4a86")
INDIGO_DARK = sg.srgb("#28335f")
CREAM = sg.srgb("#f3e6cf")
GLOW = sg.srgb("#ffd596")
FLOWERS = [sg.srgb("#f6f2ee"), sg.srgb("#f0a8c4"), sg.srgb("#c9b6ee"), sg.srgb("#f3d37a")]


def stone_color(moss=0.18):
    c = sg.mix(STONE_A, STONE_B, rng.uniform(0.2, 0.9))
    if rng.random() < moss:
        c = sg.mix(c, STONE_MOSS, rng.uniform(0.35, 0.7))
    return c


def wall_run(part, a, b, height_at, thickness=0.8, row_h=0.4, moss=0.22):
    """Courses of loose stone blocks from a to b. height_at(t) gives the ruin profile."""
    a, b = Vector(a), Vector(b)
    length = (b - a).length
    direction = (b - a).normalized()
    yaw = math.atan2(direction.y, direction.x)
    rows = int(math.ceil(max(height_at(i / 20.0) for i in range(21)) / row_h))
    for row in range(rows):
        cursor = -rng.uniform(0.0, 0.5) if row % 2 else 0.0
        while cursor < length:
            block = rng.uniform(0.7, 1.25)
            start, end = max(cursor, 0.0), min(cursor + block, length)
            cursor += block
            if end - start < 0.25:
                continue
            mid = (start + end) / 2.0
            if (row + 1) * row_h > height_at(mid / length) + row_h * 0.5:
                continue
            center = a + direction * mid
            size = (end - start - 0.03, thickness * rng.uniform(0.88, 1.05), row_h - 0.02)
            part.box(size, (center.x, center.y, row * row_h + row_h / 2.0), stone_color(moss),
                     rot=(rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), yaw + rng.uniform(-0.03, 0.03)),
                     bevel=0.05, grad=(0.82, 1.05))


def stone_lantern(stone, glow, x, y, index, scale=1.0):
    """A squat toro: plinth, post, light box, pyramid roof."""
    s = scale
    stone.box((0.7 * s, 0.7 * s, 0.16 * s), (x, y, 0.08 * s), stone_color(0.4), bevel=0.03)
    stone.cyl(0.14 * s, 0.11 * s, 0.75 * s, (x, y, 0.16 * s), stone_color(0.2), segs=8)
    stone.box((0.56 * s, 0.56 * s, 0.1 * s), (x, y, 0.96 * s), stone_color(0.1), bevel=0.02)
    for dx in (-0.2, 0.2):
        for dy in (-0.2, 0.2):
            stone.box((0.07 * s, 0.07 * s, 0.34 * s), (x + dx * s, y + dy * s, 1.18 * s), stone_color(0.0))
    glow.box((0.3 * s, 0.3 * s, 0.3 * s), (x, y, 1.18 * s), GLOW, grad=(1, 1), jitter=0.0)
    stone.box((0.86 * s, 0.86 * s, 0.26 * s), (x, y, 1.48 * s), stone_color(0.35), bevel=0.02, taper=0.28)
    stone.ball((0.07 * s, 0.07 * s, 0.09 * s), (x, y, 1.66 * s), stone_color(0.0), sub=1)
    sg.empty("Lantern_%02d" % index, (x, y, 1.2 * s))


def sakura(trunk, bloom, x, y, height, spread):
    base = Vector((x, y, 0.0))
    lean = Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 0.0))
    fork = base + lean + Vector((0, 0, height * rng.uniform(0.34, 0.42)))
    radius = 0.2 + spread * 0.05
    trunk.cyl(radius * 1.9, radius * 1.15, 0.5, base, BARK_A, top=BARK_B, segs=9, smooth=True, grad=(0.7, 0.95))
    trunk.limb(base + Vector((0, 0, 0.35)), fork, radius * 1.15, radius * 0.85, BARK_A, top=BARK_B, segs=9, smooth=True, grad=(0.85, 1.05))
    dark, light = rng.choice(BLOOMS)
    tips = []
    count = rng.randint(3, 5)
    start = rng.uniform(0, math.tau)
    for i in range(count):
        a = start + math.tau * i / count + rng.uniform(-0.35, 0.35)
        reach = spread * rng.uniform(0.5, 0.85)
        tip = fork + Vector((math.cos(a) * reach, math.sin(a) * reach, height * rng.uniform(0.3, 0.48)))
        elbow = fork.lerp(tip, 0.55) + Vector((0, 0, height * 0.08))
        trunk.limb(fork, elbow, radius * 0.75, radius * 0.5, BARK_A, top=BARK_B, segs=7, smooth=True, grad=(0.9, 1.05))
        trunk.limb(elbow, tip, radius * 0.5, radius * 0.22, BARK_A, top=BARK_B, segs=6, smooth=True, grad=(0.9, 1.05))
        tips.append(tip)
    tips.append(fork + Vector((0, 0, height * 0.55)))
    for tip in tips:
        for j in range(rng.randint(5, 7)):
            a = rng.uniform(0, math.tau)
            d = spread * rng.uniform(0.0, 0.5)
            r = spread * rng.uniform(0.22, 0.36)
            shade = rng.uniform(0.0, 0.25)
            bloom.ball((r, r, r * rng.uniform(0.55, 0.72)),
                       (tip.x + math.cos(a) * d, tip.y + math.sin(a) * d, tip.z + rng.uniform(-0.35, 0.45)),
                       sg.mix(dark, light, shade), top=light, sub=2, lump=0.22, lump_scale=1.5,
                       smooth=True, grad=(0.78, 1.06))


def bush(leaf, small, x, y, size):
    dark, light = BUSH
    for i in range(rng.randint(2, 4)):
        r = size * rng.uniform(0.55, 1.0)
        px, py = x + rng.uniform(-size, size) * 0.6, y + rng.uniform(-size, size) * 0.6
        leaf.ball((r, r, r * 0.72), (px, py, r * 0.5), dark, top=light, sub=2, lump=0.22, smooth=True, grad=(0.7, 1.05))
        if rng.random() < 0.45:      # azalea dots
            color = rng.choice(FLOWERS[:3])
            for k in range(rng.randint(4, 8)):
                a, b = rng.uniform(0, math.tau), rng.uniform(0.2, 1.2)
                small.ball((0.07, 0.07, 0.05), (px + math.cos(a) * math.sin(b) * r, py + math.sin(a) * math.sin(b) * r, r * 0.5 + math.cos(b) * r * 0.72),
                           color, sub=1, smooth=True, grad=(0.95, 1.05), jitter=0.0)


def rock(part, x, y, size):
    for i in range(rng.randint(1, 3)):
        s = size * rng.uniform(0.5, 1.0)
        part.ball((s * rng.uniform(0.9, 1.4), s * rng.uniform(0.8, 1.2), s * rng.uniform(0.55, 0.85)),
                  (x + rng.uniform(-size, size) * 0.5, y + rng.uniform(-size, size) * 0.5, s * 0.3),
                  ROCK[0], top=sg.mix(ROCK[1], STONE_MOSS, rng.uniform(0.0, 0.5)), rot=(0, 0, rng.uniform(0, math.tau)),
                  sub=1, lump=0.28, lump_scale=1.6, smooth=False, grad=(0.75, 1.08))


def flowers(part, x, y, spread):
    color = rng.choice(FLOWERS)
    for i in range(rng.randint(4, 9)):
        px, py = x + rng.uniform(-spread, spread), y + rng.uniform(-spread, spread)
        h = rng.uniform(0.14, 0.3)
        part.cyl(0.012, 0.01, h, (px, py, 0.0), sg.srgb("#3f7a45"), segs=4)
        part.ball((0.07, 0.07, 0.045), (px, py, h), color, sub=1, smooth=True, grad=(0.9, 1.05), jitter=0.0)


def inside_court(x, y, margin):
    return abs(x) < HX + margin and abs(y) < HY + margin


def scatter(count, zone, spacing, taken, margin):
    points = []
    guard = 0
    while len(points) < count and guard < 5000:
        guard += 1
        x = rng.uniform(zone[0], zone[1])
        y = rng.uniform(zone[2], zone[3])
        if inside_court(x, y, margin):
            continue
        if abs(x) < 2.6 and abs(y) > HY:        # keep both gate paths open
            continue
        if any((x - px) ** 2 + (y - py) ** 2 < spacing ** 2 for px, py in taken + points):
            continue
        points.append((x, y))
    taken.extend(points)
    return points


def build():
    sg.reset_scene()
    stone = sg.Part("Stone", "VC", seed=3)
    wood = sg.Part("Wood", "VC", seed=4)
    trunk = sg.Part("Trunks", "VC", seed=5)
    bloom = sg.Part("Blossom", "Blossom", seed=6)
    leaf = sg.Part("Leaves", "Leaf", seed=11)
    rocks = sg.Part("Rocks", "VC", seed=7)
    cloth = sg.Part("Cloth", "Cloth", seed=8)
    glow = sg.Part("LanternGlow", "Glow", seed=9)
    small = sg.Part("Flowers", "VC", seed=10)

    # --- boundary: a low, mossy, broken wall. Tall only on the far (north) side ------------
    def north_profile(t):
        return 0.8 + 0.75 * (0.5 + 0.5 * math.sin(t * 19.0 + 0.7)) + (0.4 if rng.random() < 0.1 else 0.0)
    wall_run(stone, (-HX, HY, 0), (-2.9, HY, 0), north_profile, thickness=0.85)
    wall_run(stone, (2.9, HY, 0), (HX, HY, 0), north_profile, thickness=0.85)
    for side in (-1, 1):
        wall_run(stone, (side * HX, -HY, 0), (side * HX, HY, 0),
                 lambda t: 0.4 + 0.4 * (0.5 + 0.5 * math.sin(t * 27.0 + side)) , thickness=0.75)
    for a, b in ((-HX, -2.4), (2.4, HX)):
        wall_run(stone, (a, -HY, 0), (b, -HY, 0), lambda t: 0.28, thickness=0.65, row_h=0.28)
    for sx in (-1, 1):
        for sy in (-1, 1):
            stone.box((1.15, 1.15, 0.9 if sy < 0 else 1.5), (sx * HX, sy * HY, 0.45 if sy < 0 else 0.75), stone_color(0.3), bevel=0.07, taper=0.9)
            stone.box((1.35, 1.35, 0.2), (sx * HX, sy * HY, 0.95 if sy < 0 else 1.55), stone_color(0.4), bevel=0.05)

    # --- wooden gate on the far side, with a banner ----------------------------------------
    for side in (-1, 1):
        stone.box((0.8, 0.8, 0.3), (side * 2.6, HY, 0.15), stone_color(0.2), bevel=0.05)
        wood.cyl(0.24, 0.2, 3.9, (side * 2.6, HY, 0.25), GATE_A, top=GATE_B, segs=10, smooth=True, grad=(0.75, 1.05))
    wood.box((7.2, 0.42, 0.3), (0, HY, 4.2), GATE_A, top=GATE_B, bevel=0.05)
    wood.box((7.8, 0.5, 0.16), (0, HY, 4.43), sg.srgb("#2c2326"), bevel=0.04)
    wood.box((5.9, 0.26, 0.24), (0, HY, 3.45), GATE_A, top=GATE_B, bevel=0.04)
    w, face = 1.7, HY - 0.16
    cloth.quad([(-w / 2, face, 3.3), (w / 2, face, 3.3), (w / 2, face, 1.95), (-w / 2, face, 1.95)], INDIGO_DARK, top=INDIGO, grad=(0.9, 1.05))
    cloth.quad([(-w / 2, face, 1.95), (w / 2, face, 1.95), (0, face, 1.55)], INDIGO_DARK, grad=(0.9, 0.95))
    cloth.cyl(0.4, 0.4, 0.02, (0, face - 0.02, 2.65), CREAM, rot=(math.pi / 2, 0, 0), segs=20, grad=(1, 1), jitter=0)
    cloth.cyl(0.14, 0.14, 0.02, (0, face - 0.045, 2.58), INDIGO_DARK, rot=(math.pi / 2, 0, 0), segs=14, grad=(1, 1), jitter=0)
    for dx, dz in ((-0.18, 0.15), (-0.06, 0.25), (0.06, 0.25), (0.18, 0.15)):
        cloth.cyl(0.052, 0.052, 0.02, (dx, face - 0.045, 2.58 + dz), INDIGO_DARK, rot=(math.pi / 2, 0, 0), segs=10, grad=(1, 1), jitter=0)

    # --- stone lanterns: just outside the wall so they never block the fight ---------------
    index = 0
    for side in (-1, 1):
        for y in (-5.2, 0.0, 5.2):
            stone_lantern(stone, glow, side * (HX + 1.0), y, index)
            index += 1
        stone_lantern(stone, glow, side * 4.3, HY + 1.0, index, scale=1.2)
        index += 1
        stone_lantern(stone, glow, side * 3.6, -HY - 0.9, index, scale=0.9)
        index += 1

    # --- cherry trees ------------------------------------------------------------------------
    taken = []
    # hand-placed: two framing trees at the near corners, a row behind the far wall
    sx, ny = HX + 2.5, HY + 2.7
    authored = [(-sx + 0.4, -HY - 1.9, 6.2, 3.3), (sx - 0.1, -HY - 1.5, 6.0, 3.2),
                (-HX * 0.75, ny, 6.6, 3.5), (-HX * 0.34, ny + 1.2, 7.2, 3.7), (HX * 0.38, ny + 0.8, 6.9, 3.6), (HX * 0.8, ny - 0.2, 6.4, 3.4),
                (-sx, HY * 0.34, 6.4, 3.4), (sx + 0.2, HY * 0.46, 6.6, 3.5), (-sx - 0.4, -HY * 0.44, 5.8, 3.1), (sx + 0.1, -HY * 0.38, 5.9, 3.2)]
    for x, y, h, s in authored:
        sakura(trunk, bloom, x, y, h, s)
        taken.append((x, y))
    for x, y in scatter(16, (-30, 30, HY + 5.0, 30), 5.2, taken, 2.6):
        sakura(trunk, bloom, x, y, rng.uniform(5.6, 8.2), rng.uniform(3.0, 4.0))
    for zone in ((-32, -HX - 6.0, -14, 15), (HX + 6.0, 32, -14, 15)):
        for x, y in scatter(6, zone, 5.0, taken, 2.6):
            sakura(trunk, bloom, x, y, rng.uniform(5.4, 7.6), rng.uniform(2.9, 3.8))
    taken_small = [(x, y) for x, y in taken]
    for x, y in scatter(30, (-24, 24, -15, 20), 2.0, taken_small, 1.0):
        bush(leaf, small, x, y, rng.uniform(0.45, 0.95))
    for x, y in scatter(30, (-24, 24, -16, 20), 1.6, taken_small, 0.8):
        rock(rocks, x, y, rng.uniform(0.3, 0.9))
    for x, y in scatter(70, (-20, 20, -15, 17), 0.9, taken_small, 0.7):
        flowers(small, x, y, rng.uniform(0.25, 0.6))

    for part in (stone, wood, trunk, bloom, leaf, rocks, cloth, glow, small):
        part.finish()


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build()
    if len(args) > 1:
        bpy.ops.wm.save_as_mainfile(filepath=args[1])
    if args:
        os.makedirs(os.path.dirname(args[0]), exist_ok=True)
        sg.export_glb(args[0])
        print("EXPORTED", args[0])
