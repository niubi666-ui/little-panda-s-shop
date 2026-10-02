"""Springwater Cloister v001 -- editable art scene, no gameplay geometry.

Run only from Blender through the parent room build workflow.
Reference: concepts/combat_rooms/v003/02_springwater_cloister.png.
All coordinates, population and light values here are source-art parameters.
"""
from pathlib import Path
import math
import random
import sys

import bpy
from mathutils import Vector

SHARED = Path('E:/ShopGame/source_assets/environments/dungeon/shared/scripts')
sys.path.insert(0, str(SHARED))
from room_kit import Kit
from room_foliage import tree, ivy, flower_patch, fern, pot

ROOM_DIR = Path('E:/ShopGame/source_assets/environments/dungeon/springwater_cloister')
kit = Kit('springwater_cloister', seed=260927)
kit.dir = ROOM_DIR
rng = random.Random(260927)
kit.mats['falling_water']=kit.mats['water'].copy()
kit.mats['falling_water'].name='Clear refractive flowing spring'
for node in kit.mats['falling_water'].node_tree.nodes:
    if node.type=='BSDF_PRINCIPLED':
        node.inputs['Base Color'].default_value=(.73,.92,.96,1)
        node.inputs['Transmission Weight'].default_value=.96
        node.inputs['Roughness'].default_value=.045
    elif node.type=='BUMP':
        node.inputs['Distance'].default_value=.004
        node.inputs['Strength'].default_value=.14


def relocate_collection(obj, name):
    collection = bpy.data.collections.get(name)
    if collection is None:
        collection = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(collection)
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)


def stone_sphere(name, loc, scale, mat='stone', group='Replacement_Props', detail=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=detail, radius=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(kit.mats[mat])
    relocate_collection(obj, group)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    if group == 'Replacement_Props':
        obj['replaceable'] = True
        obj['replacement_family'] = 'lion_head_fountain'
    return obj


def ring(name, center, radius, tube=.014, mat='brass', plane='XY', group='Decor', start=0, end=math.tau):
    points = []
    samples = max(16, round(64 * abs(end - start) / math.tau))
    for i in range(samples + 1):
        a = start + (end - start) * i / samples
        if plane == 'XY':
            delta = (math.cos(a) * radius, math.sin(a) * radius, 0)
        elif plane == 'XZ':
            delta = (math.cos(a) * radius, 0, math.sin(a) * radius)
        else:
            delta = (0, math.cos(a) * radius, math.sin(a) * radius)
        points.append(tuple(center[k] + delta[k] for k in range(3)))
    return kit.curve(name, points, tube, mat, group)


def coursed_wall(name, x0, x1, y, z0, z1, thickness=.52):
    row = 0
    z = z0
    while z < z1 - .01:
        height = min(.46, z1 - z)
        x = x0
        while x < x1 - .01:
            width = min(rng.uniform(.76, 1.16), x1 - x)
            material = 'stone' if rng.random() > .12 else 'floor_2'
            kit.box(f'{name}_r{row}_{x:.2f}', (x + width / 2, y, z + height / 2),
                    (max(.03, width - .018), thickness, height - .015), material, .035)
            x += width
        row += 1
        z += height


def column_detail(name, x, y, base_z=.0, height=5.0):
    """Stepped dressed piers and attached slim shafts catch warm edge light."""
    for z, width, depth, h in [(.12, 1.2, 1.18, .24), (.31, 1.03, 1.02, .16),
                               (.45, .88, .9, .16), (.58, .8, .84, .11),
                               (height - .2, .84, .86, .18), (height - .05, 1.08, 1.0, .14)]:
        kit.box(f'{name}_moulding_{z:.2f}', (x, y, base_z + z), (width, depth, h),
                'stone', .035)
    # Square masonry core uses visible bed joints instead of one featureless block.
    for i in range(8):
        h = (height - .8) / 8
        kit.box(f'{name}_shaft_course_{i}', (x, y, base_z + .67 + h * (i + .5)),
                (.73, .77, h - .02), 'stone', .028)
    for dx in [-.30, .30]:
        kit.cylinder(f'{name}_attached_shaft_{dx}', (x + dx, y - .42, base_z + height / 2),
                     .105, height - .82, 'stone', 16, 'Architecture')
        for z in [.50, height - .34]:
            kit.cylinder(f'{name}_attached_ring_{dx}_{z}', (x + dx, y - .42, base_z + z),
                         .15, .11, 'stone', 16, 'Architecture')


def stone_planter(name, center, dim=(1.35, .75, .56)):
    x, y, z = center
    width, depth, height = dim
    kit.box(f'{name}_body', (x, y, z + height / 2), (width, depth, height), 'stone_dark', .06, 'Props')
    kit.box(f'{name}_lip_front', (x, y - depth / 2, z + height), (width + .12, .16, .13), 'stone', .025, 'Props')
    kit.box(f'{name}_lip_back', (x, y + depth / 2, z + height), (width + .12, .16, .13), 'stone', .025, 'Props')
    for side in [-1, 1]:
        kit.box(f'{name}_lip_side_{side}', (x + side * width / 2, y, z + height), (.16, depth, .13), 'stone', .025, 'Props')
    kit.box(f'{name}_soil', (x, y, z + height - .025), (width - .17, depth - .17, .07), 'soil', .0, 'Props')
    flower_patch(kit, f'{name}_flowers', (x, y, z + height + .03), extent=(width * .7, depth * .8), count=24, seed=int(abs(x * 200 + y * 30)) + 80)


def water_jet(name, x, y, top_z, target_y, target_z, thickness=.035):
    points = []
    for i in range(16):
        t = i / 15
        points.append((x + math.sin(t * 13) * .012, y + (target_y - y) * t,
                       top_z + (target_z - top_z) * t * t))
    kit.curve(name, points, thickness, 'falling_water', 'Water_Detail')


def basin(name, loc, radius, depth=.35):
    # Cross-section doubles back down the inside: real hollow basin, not filled cylinder.
    x, y, z = loc
    profile = [(.12, -.16), (radius * .45, -.15), (radius * .58, -.08),
               (radius * .68, .08), (radius * .91, depth * .6), (radius, depth),
               (radius * 1.02, depth + .08), (radius * .97, depth + .13),
               (radius * .87, depth + .13), (radius * .84, depth + .03),
               (radius * .72, depth * .55), (.1, .06)]
    kit.lathe(name, loc, profile, 'stone', 48, 'Architecture')
    kit.cylinder(name + '_water', (x, y, z + depth + .035), radius * .85, .025, 'water', 64, 'Water_Detail')
    for a in range(0, 360, 30):
        ar = math.radians(a)
        kit.curve(name + f'_flute_{a}',
                  [(x + radius * .61 * math.cos(ar), y + radius * .61 * math.sin(ar), z),
                   (x + radius * .91 * math.cos(ar), y + radius * .91 * math.sin(ar), z + depth * .62),
                   (x + radius * .96 * math.cos(ar), y + radius * .96 * math.sin(ar), z + depth)],
                  .014, 'stone_dark', 'Decor')


def lion_fountain(x, y):
    """Individual editable stone masses make a readable ornamental lion proxy."""
    kit.box('Fountain_Wall_Backplate', (x, y + .20, 2.04), (2.70, .52, 3.92), 'stone_dark', .07)
    kit.box('Fountain_Recess_Shadow', (x, y - .081, 2.04), (1.79, .11, 2.52), 'mortar', .12)
    kit.arch('Fountain_Carved_Niche', center=(x, y - .08, .36), width=1.90,
             spring=2.34, thickness=.27, depth=.35)
    # Narrow concentric archivolt and keystone embellishments.
    ring('Fountain_Niche_Inner_Rib', (x, y - .29, 2.7), 1.02, .029, 'stone', 'XZ', 'Decor', 0, math.pi)
    for side in [-1, 1]:
        kit.box(f'Fountain_Niche_Edge_{side}', (x + side * 1.09, y - .08, 1.66), (.19, .35, 2.54), 'stone', .035)
        kit.box(f'Fountain_Niche_Pilaster_Base_{side}', (x + side * 1.10, y - .10, .40), (.40, .48, .24), 'stone', .035)
    kit.box('Fountain_Carved_Crown', (x, y + .01, 4.02), (.34, .44, .52), 'stone', .065)
    ring('Fountain_Crown_Gold_Seal', (x, y - .25, 4.05), .09, .012, 'brass', 'XZ')

    lion_z = 2.53
    stone_sphere('Lion_Mane_Base_REPLACEABLE', (x, y - .40, lion_z), (.64, .22, .70))
    for i in range(17):
        a = math.tau * i / 17
        dx, dz = math.cos(a) * .48, math.sin(a) * .56
        lobe = stone_sphere(f'Lion_Mane_Curl_{i:02d}_REPLACEABLE', (x + dx, y - .50, lion_z + dz),
                            (.18, .20, .27), detail=2)
        lobe.rotation_euler[1] = -.5 * math.sin(a)
        # Small carved curls within the mane, darker inset material.
        if i % 2 == 0:
            ring(f'Lion_Carved_Mane_Line_{i}', (x + dx, y - .695, lion_z + dz), .091, .009,
                 'stone_dark', 'XZ', 'Replacement_Props', -.3, math.pi * 1.25)
    stone_sphere('Lion_Forehead_REPLACEABLE', (x, y - .67, lion_z + .15), (.39, .28, .43))
    for side in [-1, 1]:
        stone_sphere(f'Lion_Ear_{side}_REPLACEABLE', (x + .40 * side, y - .46, lion_z + .42), (.17, .16, .20))
        stone_sphere(f'Lion_Eye_Recess_{side}_REPLACEABLE', (x + .20 * side, y - .913, lion_z + .12), (.10, .019, .065), 'stone_dark')
        brow = stone_sphere(f'Lion_Brow_{side}_REPLACEABLE', (x + .20 * side, y - .906, lion_z + .23), (.18, .054, .076))
        brow.rotation_euler[1] = side * -.24
        stone_sphere(f'Lion_Muzzle_{side}_REPLACEABLE', (x + .13 * side, y - .94, lion_z - .20), (.20, .19, .20))
    stone_sphere('Lion_Nose_REPLACEABLE', (x, y - 1.073, lion_z - .055), (.13, .10, .105), 'stone_dark')
    stone_sphere('Lion_Open_Mouth_REPLACEABLE', (x, y - 1.071, lion_z - .32), (.14, .08, .10), 'mortar')
    stone_sphere('Lion_Lower_Jaw_REPLACEABLE', (x, y - .84, lion_z - .40), (.235, .19, .12))

    basin('Fountain_Upper_Fluted_Bowl', (x, y - .86, .72), .82, .39)
    kit.lathe('Fountain_Bowl_Pedestal', (x, y - .86, .06), [(.39, 0), (.44, .12), (.25, .24), (.21, .62), (.44, .71)], 'stone', 32, 'Architecture')
    water_jet('Lion_Mouth_Falling_Water', x, y - 1.15, lion_z - .32, y - 1.10, 1.17, .047)
    # Overflow fans into the channel on the front side of the raised bowl.
    for i in range(9):
        dx = (i - 4) * .058
        water_jet(f'Fountain_Bowl_Overflow_{i}', x + dx, y - 1.61, 1.14, y - 1.86, .08, .018)
    # A corrugated transparent veil joins the small jets; it has real thickness.
    vertices=[];faces=[];columns=12;rows=22
    for row in range(rows+1):
        t=row/rows
        for col in range(columns+1):
            u=col/columns-.5
            vertices.append((x+u*(.49+.10*t),y-1.61-.25*t+.007*math.sin(col*2.8+t*7),1.14-1.06*t*t))
    for row in range(rows):
        for col in range(columns):
            a=row*(columns+1)+col;faces.append((a,a+columns+1,a+columns+2,a+1))
    veil=kit.mesh('Fountain_Clear_Overflow_Veil',vertices,faces,'falling_water','Water_Detail')
    for face in veil.data.polygons:face.use_smooth=True
    veil.modifiers.new('Thin water film thickness','SOLIDIFY').thickness=.003
    for cx, cy, cz, radii in [(x, y - 1.86, .077, [.065, .10, .14, .18]),
                               (x, y - 1.10, 1.159, [.08, .14, .21])]:
        for j, rad in enumerate(radii):
            ring(f'Fountain_Ripple_{cz}_{j}', (cx, cy, cz), rad, .005 if j > 1 else .009,
                 'falling_water', 'XY', 'Water_Detail', .16 + j * .7, math.tau - .24)
    for i in range(16):
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(.03, .24)
        stone_sphere(f'Fountain_Splash_Droplet_{i}',
                     (x + math.cos(a) * rr, y - 1.86 + math.sin(a) * rr, .09 + rng.random() * .24),
                     (.011, .011, .02), 'water', 'Water_Detail', 1)
    # Everything in this named collection is swap-friendly, including carve lines.
    coll = bpy.data.collections.get('Replacement_Props')
    if coll:
        for obj in coll.objects:
            if obj.name.startswith('Lion_'):
                obj['replaceable'] = True
                obj['replacement_family'] = 'lion_head_fountain'


def lily(name, x, y, radius, angle):
    # A notched water-lily silhouette with a modeled central vein.
    verts = [(x, y, .088)]
    for i in range(19):
        a = angle + .22 + (math.tau - .44) * i / 18
        verts.append((x + math.cos(a) * radius, y + math.sin(a) * radius, .086 + .009 * math.sin(a * 3)))
    faces = [(0, i, i + 1) for i in range(1, 19)]
    kit.mesh(name, verts, faces, 'leaf_2', 'Water_Detail')
    kit.curve(name + '_vein', [(x, y, .10), (x - math.cos(angle) * radius * .8, y - math.sin(angle) * radius * .8, .10)], .004, 'leaf_3', 'Water_Detail')


# CONTINUOUS GROUND: the paving and woodland continue outside the hero camera.
kit.box('Continuous_Earth_Substrate', (0, 1.5, -.72), (56, 48, .80), 'forest_ground', .04, 'Terrain')
kit.box('Courtyard_Masonry_Foundation', (0, -.3, -.44), (25.5, 25.0, .44), 'mortar', .06, 'Terrain')
kit.tile_floor(bounds=(-22, 9.45, -24.0, 6.34), step=(1.13, .87), z=0)
kit.tile_floor(bounds=(10.98, 17, -24, 11.2), step=(1.13, .87), z=0)
kit.tile_floor(bounds=(9.45, 10.98, -24, -7.7), step=(1.13, .87), z=0)
kit.tile_floor(bounds=(-13.5, 11.0, 8.45, 11.2), step=(1.13, .87), z=.32)
kit.tile_floor(bounds=(-13.5, -3.05, 6.3, 8.45), step=(1.13, .87), z=0)
kit.medallion(center=(-.15, -1.8), radius=3.08, z=.077, style='cloister')

# Channel is entirely peripheral and its masonry has a real bottom and sides.
kit.box('Back_Channel_Bed', (3.91, 7.39, -.235), (14.16, 2.06, .16), 'stone_dark', .022, 'Water_Architecture')
kit.box('Right_Channel_Bed', (10.19, -.3, -.235), (1.48, 14.98, .16), 'stone_dark', .022, 'Water_Architecture')
kit.water_surface('Clear_Spring_Back_Channel', bounds=(-3.05, 10.97, 6.52, 8.30), z=.060)
kit.water_surface('Clear_Spring_Right_Channel', bounds=(9.58, 10.86, -7.45, 6.52), z=.060)
for name, loc, dim in [
    ('Back_Channel_Inner_Coping', (3.93, 6.39, .030), (14.17, .25, .400)),
    ('Back_Channel_Outer_Coping', (3.93, 8.36, .130), (14.17, .25, .600)),
    ('Right_Channel_Inner_Coping', (9.46, -.57, .0225), (.24, 13.7, .385)),
    ('Right_Channel_Outer_Coping', (10.98, -.57, .090), (.24, 13.7, .520)),
    ('Back_Channel_West_End', (-3.07, 7.38, .0275), (.20, 1.96, .395)),
    ('Right_Channel_South_End', (10.2, -7.53, .0275), (1.70, .24, .395)),
]:
    kit.box(name, loc, dim, 'stone', .035, 'Water_Architecture')
# Coping joints are dark fine cuts; tiny caps above retain dressed-stone detail.
for x in range(-3, 11):
    kit.box(f'Back_Channel_Coping_Joint_{x}', (x, 6.39, .233), (.019, .257, .008), 'stone_dark', .0, 'Water_Architecture')
for y in range(-7, 7):
    kit.box(f'Right_Channel_Coping_Joint_{y}', (9.46, y, .220), (.249, .017, .008), 'stone_dark', .0, 'Water_Architecture')

# Back arcade: four tall openings; the first is a broad stair-linked exit.
back_y = 9.32
arch_centers = [-8.10, -2.72, 2.66, 8.04]
for i, x in enumerate(arch_centers):
    kit.arch(f'North_Arcade_{i:02d}', center=(x, back_y, .38), width=4.34,
             spring=4.31, thickness=.53, depth=.80)
    if i > 1:
        kit.balustrade(f'North_Balustrade_{i:02d}', a=(x - 1.92, back_y - .12), b=(x + 1.92, back_y - .12), height=1.31)
    # Continuous upper cornice, with no roof over the battle area.
    kit.box(f'North_Cornice_Lower_{i:02d}', (x, back_y, 6.96), (5.38, 1.02, .19), 'stone', .035)
    kit.box(f'North_Cornice_Upper_{i:02d}', (x, back_y, 7.16), (5.43, 1.13, .18), 'stone', .035)
for i, x in enumerate([-10.79, -5.41, -.03, 5.35, 10.73]):
    column_detail(f'North_Pier_{i:02d}', x, back_y, .37, 4.41)
    # Elevated blocks above piers stitch the arches into one architectural wall.
    coursed_wall(f'North_Pier_Upper_{i:02d}', x - .48, x + .48, back_y, 4.77, 6.92, .80)
    if i in [1, 2, 4]:
        kit.banner(f'North_Green_Gold_Banner_{i:02d}', (x, back_y - .68, 5.66), width=.89, height=2.62)
# A closed bay gives the reference's rhythm of solid masonry and open woodland
# windows. It sits just behind the arch rather than filling the structural opening.
coursed_wall('North_Second_Bay_Stone_Infill', -4.85, -.55, 9.89, .38, 6.91, .30)
kit.box('North_Second_Bay_Plinth', (-2.70, 9.68, .65), (4.37, .39, .54), 'stone', .032)
kit.box('North_Second_Bay_Plinth_Cap', (-2.70, 9.64, .96), (4.43, .46, .13), 'stone', .025)
kit.banner('North_Second_Bay_Heraldic_Banner', (-2.72, 9.46, 5.71), width=.95, height=2.67)
ivy(kit, 'North_Solid_Bay_Left_Ivy', (-4.53, 9.53, 6.63), length=3.18, width=.80, seed=4821)
ivy(kit, 'North_Solid_Bay_Right_Ivy', (-.86, 9.53, 6.78), length=4.07, width=.76, seed=4822)
kit.stairs('Wide_Northwest_Exit_Stairs', center=(-8.1, 7.73), width=4.52,
           run=2.06, rise=.55, steps=4)
kit.box('Exit_Threshold', (-8.1, 9.06, .37), (4.35, .78, .22), 'stone', .04)
kit.tile_floor(bounds=(-10.3, -5.9, 10.4, 17.4), step=(1.13, .87), z=.34)

# East arcade stands beyond the water channel; foreground bay remains open.
for i, y in enumerate([-4.28, 1.10, 6.48]):
    arch_root = kit.arch(f'East_Arcade_{i:02d}', center=(11.87, y, .0), width=4.34,
                         spring=4.31, thickness=.53, depth=.80, angle=math.pi / 2)
    lower_cornice = kit.box(f'East_Cornice_Lower_{i:02d}', (11.87, y, 6.58), (1.03, 5.38, .20), 'stone', .035)
    upper_cornice = kit.box(f'East_Cornice_Upper_{i:02d}', (11.87, y, 6.78), (1.15, 5.43, .19), 'stone', .035)
    if i == 0:
        # Reversible hero-preview cutaway: preserve every source object. The low
        # balustrade, channel, and two farther bays remain fully visible.
        for obj in [arch_root, *arch_root.children_recursive, lower_cornice, upper_cornice]:
            obj.hide_render = True
            obj['preview_cutaway'] = True
            obj['preview_cutaway_reason'] = 'Foreground east arch obscures peripheral water and fountain in hero camera'
            obj['preview_cutaway_restore'] = 'Set hide_render=False to restore complete architecture'
    kit.balustrade(f'East_Balustrade_{i:02d}', a=(11.84, y - 1.98), b=(11.84, y + 1.98), height=1.13)
for i, y in enumerate([-6.97, -1.59, 3.79, 9.17]):
    column_detail(f'East_Pier_{i:02d}', 11.87, y, .0, 4.41)
    if i in [1, 2]:
        # Banner face turns toward the central floor.
        kit.banner(f'East_Green_Gold_Banner_{i:02d}', (11.30, y, 5.4), width=.84, height=2.40, angle=-math.pi / 2)

# Sparse west edge: a partial wall/column silhouette and open courtyard extension.
column_detail('West_Entry_Pier', -11.5, 1.9, .0, 4.8)
kit.arch('West_Entry_Arch_Partial', center=(-11.5, 4.55, 0), width=4.34, spring=4.35,
         thickness=.53, depth=.8, angle=math.pi / 2)
kit.balustrade('West_Low_Garden_Rail', a=(-11.4, -6.8), b=(-11.4, .1), height=1.1)
kit.post('West_Garden_Lamp_Post', (-11.4, -6.9, 0), height=1.04, width=.85)
kit.lantern('West_Garden_Lantern', (-11.4, -6.9, 1.08), scale=.95)

# Hero water feature remains a modular prop assembly, front-facing in hero view.
lion_fountain(7.90, 8.57)

# Low lantern piers, corner flowers and foliage concentrate detail at the edges.
for i, (x, y, h) in enumerate([(-10.52, 6.51, .73), (-5.39, 6.51, .73),
                              (-2.35, 7.97, .75), (2.54, 7.98, .77),
                              (5.50, 7.98, .80), (10.70, 6.91, .77),
                              (10.71, 1.20, .77), (10.72, -4.40, .77)]):
    kit.post(f'Lantern_Plinth_{i:02d}', (x, y, 0), height=h, width=.70)
    kit.lantern(f'Warm_Amber_Lantern_{i:02d}', (x, y, h + .12), scale=.82)

for i, (x, y, z, width, length) in enumerate([
    (-10.8, 8.82, 6.8, 1.15, 4.1), (-5.43, 8.80, 6.75, 1.2, 3.5),
    (-.06, 8.79, 6.7, 1.0, 4.1), (5.28, 8.79, 6.6, 1.1, 3.4),
    (10.59, 8.82, 6.9, 1.6, 4.4), (10.95, 3.89, 6.3, 1.1, 3.8),
    (11.14, -1.48, 5.6, 1.0, 3.7), (-11.35, 1.48, 6.1, 1.1, 4.1),
]):
    ivy(kit, f'Living_Ivy_Cascade_{i:02d}', (x, y, z), length=length, width=width, seed=390 + i)

for i, (x, y, sx, sy, count) in enumerate([
    (-11.35, 5.75, 1.5, 1.2, 42), (-5.28, 8.22, .85, .65, 25),
    (-.20, 8.32, 1.2, .6, 28), (4.75, 8.19, 1.0, .72, 27),
    (9.35, 8.09, .60, .66, 23), (11.14, 4.13, .65, 1.3, 29),
    (11.20, -2.35, .6, 1.1, 25), (-12.05, -4.8, 1.5, 2.0, 54),
]):
    flower_patch(kit, f'Cloister_Edge_White_Flowers_{i:02d}', (x, y, .16),
                 extent=(sx, sy), count=count, seed=550 + i)

for i, (x, y) in enumerate([(-10.68, 5.72), (-5.30, 8.13), (-.75, 8.13),
                           (3.70, 8.15), (10.79, 3.72), (10.80, -.45),
                           (10.77, -6.25), (-11.64, -1.1)]):
    fern(kit, f'Moist_Edge_Fern_{i:02d}', (x, y, .16), scale=.65 + rng.random() * .20, seed=630 + i)
for i, (x, y) in enumerate([(-5.20, 9.76), (-.16, 9.81), (10.77, 9.78)]):
    pot(kit, f'Arcade_Stone_Pot_{i:02d}', (x, y, .38), scale=.76, seed=675 + i)

stone_planter('Northwest_Herb_Planter', (-11.17, 8.11, .02), (1.25, .72, .55))
stone_planter('North_White_Flower_Planter', (.51, 9.94, .37), (1.37, .70, .58))

for i in range(36):
    if i < 23:
        x, y = rng.uniform(-2.6, 10.5), rng.choice([6.73, 8.05]) + rng.uniform(-.12, .12)
    else:
        x, y = rng.uniform(9.74, 10.60), rng.uniform(-7.1, 5.8)
    # Leave the fountain splash open to read the falling water.
    if abs(x - 7.9) < .85 and y > 6.7:
        continue
    lily(f'Floating_Lily_Pad_{i:02d}', x, y, rng.uniform(.08, .16), rng.uniform(0, math.tau))
for i in range(18):
    x, y = rng.uniform(-2.5, 10.4), rng.choice([6.69, 8.05])
    for stem in range(5):
        dx, dy = rng.uniform(-.12, .12), rng.uniform(-.11, .11)
        h = rng.uniform(.35, .75)
        kit.curve(f'Spring_Reed_{i}_{stem}', [(x + dx, y + dy, -.05),
                  (x + dx + .06, y + dy, h * .58), (x + dx + .12, y + dy + .055, h)],
                  .014, 'leaf_0', 'Foliage')

# Forest depth visible through the arcades. Trees on the camera's east approach
# are beyond the frame: no foreground leaf canopy may mask the hero fountain.
for i, (x, y, h, spread) in enumerate([
    (-16, 15.0, 10.5, 4.8), (-11, 19, 12.0, 4.8), (-4, 17.2, 11.4, 4.4),
    (3, 20.0, 12.5, 4.8), (9, 17.5, 11.5, 4.4), (17.0, 15.5, 11.4, 4.3),
    (26.0, 5.0, 9.8, 3.3), (27.0, -3.5, 9.0, 3.0), (-17, -1.8, 10.5, 4.5),
    (-16.3, 7.2, 10.6, 4.3),
    # Second row creates trunk parallax and foliage depth beyond each arch bay.
    (-16.8, 23.0, 12.8, 4.6), (-7.4, 23.6, 11.7, 4.0),
    (-.6, 24.0, 13.0, 4.6), (7.2, 24.6, 11.9, 4.0), (15.0, 23.1, 13.3, 4.9),
    # Smaller trees stand farther behind the openings; lower trunks stay readable.
    (-3.0, 14.5, 7.3, 2.6), (4.4, 15.0, 7.9, 2.9), (12.4, 16.2, 7.1, 2.6),
]):
    tree(kit, f'Woodland_Beyond_Arcade_{i:02d}', (x, y, -.23), height=h, spread=spread, seed=740 + i)
for i, (x, y) in enumerate([(-14, 12.0), (-8.0, 14.2), (-2, 13.1), (4.5, 14.3),
                           (11.1, 13.1), (15, 7.0), (15.2, -.6), (-14.5, -5.2)]):
    flower_patch(kit, f'Woodland_Low_Growth_{i:02d}', (x, y, -.18), extent=(3.5, 2.7), count=45, seed=840 + i)

# Knee-low planting immediately beyond the arcade softens the bare soil without
# plugging the openings. The northwest exit path is kept visibly open.
for i, (x, y) in enumerate([(-12.1, 11.8), (-4.2, 11.8), (-1.9, 12.6),
                           (.6, 11.9), (3.2, 12.6), (5.8, 11.9), (8.4, 12.5),
                           (10.8, 11.9), (13.3, 12.0), (14.4, 8.8),
                           (14.4, 5.0), (14.4, 1.2), (14.4, -3.0)]):
    fern(kit, f'Low_Arcade_Backdrop_Fern_{i:02d}', (x, y, -.18),
         scale=1.05 + .13 * (i % 3), seed=880 + i)
    flower_patch(kit, f'Low_Arcade_Backdrop_Flowers_{i:02d}', (x + .4, y + .35, -.18),
                 extent=(2.2, 1.6), count=65, seed=920 + i)

# Massed short grass provides a continuous woodland carpet through the arches.
# All blades are batched into only three editable meshes, not thousands of objects.
grass_rng = random.Random(26092719)
grass_batches = {name: [[], []] for name in ['leaf_0', 'leaf_1', 'leaf_3']}
for i in range(4200):
    x, y = grass_rng.uniform(-18.0, 20.0), grass_rng.uniform(11.35, 25.0)
    if -10.42 < x < -5.77 and y < 18.0:
        continue
    mat = grass_rng.choices(['leaf_0', 'leaf_1', 'leaf_3'], [.55, .36, .09])[0]
    verts, faces = grass_batches[mat]
    z = -.31
    for blade in range(3):
        a = grass_rng.uniform(0, math.tau)
        height = grass_rng.uniform(.10, .34)
        halfwidth = grass_rng.uniform(.014, .030)
        lean = grass_rng.uniform(.03, .12)
        start = len(verts)
        verts.extend([(x - math.cos(a) * halfwidth, y - math.sin(a) * halfwidth, z),
                      (x + math.cos(a) * halfwidth, y + math.sin(a) * halfwidth, z),
                      (x + math.sin(a) * lean, y - math.cos(a) * lean, z + height)])
        faces.append((start, start + 1, start + 2))
for mat, (verts, faces) in grass_batches.items():
    kit.mesh('Woodland_Grass_Carpet_' + mat, verts, faces, mat, 'Foliage')
for i, (x, y) in enumerate([(-12.0, 13.2), (-4.5, 12.8), (1.6, 14.1),
                           (5.7, 13.0), (10.3, 13.9), (14.6, 9.8)]):
    stone_sphere(f'Woodland_Mossy_Stone_{i:02d}', (x, y, -.25),
                 (.55 + .13 * (i % 3), .43, .30 + .07 * (i % 2)),
                 'stone_dark', 'Terrain', 2)

# Sparse small leaves on the edge tiles; no arena-center clutter.
for i in range(42):
    side = rng.choice(['west', 'north', 'east'])
    if side == 'west':
        x, y = rng.uniform(-11.5, -9.25), rng.uniform(-9, 6)
    elif side == 'north':
        x, y = rng.uniform(-4, 9.1), rng.uniform(5.55, 6.17)
    else:
        x, y = rng.uniform(8.60, 9.13), rng.uniform(-8, 5.4)
    a, r = rng.uniform(0, math.tau), rng.uniform(.05, .1)
    vertices = [(x - math.cos(a) * r, y - math.sin(a) * r, .061),
                (x - math.sin(a) * r * .42, y + math.cos(a) * r * .42, .068),
                (x + math.cos(a) * r, y + math.sin(a) * r, .061),
                (x + math.sin(a) * r * .42, y - math.cos(a) * r * .42, .063)]
    kit.mesh(f'Loose_Botanical_Leaf_{i:02d}', vertices, [(0, 1, 2, 3)], 'leaf_3', 'Decor')

kit.scene['room_role'] = 'wide_open_combat_courtyard_visual_source'
kit.scene['concept_reference'] = 'concepts/combat_rooms/v003/02_springwater_cloister.png'
kit.scene['central_clear_area'] = 'x -8.8..8.5, y -8.5..5.4; no gameplay obstacles authored'
kit.scene['water_policy'] = 'perimeter only; rear and east channel; modeled base and banks'
kit.scene['replaceable_props'] = 'Replacement_Props/Lion_* ; lion fountain sculpture'
kit.scene['gameplay_status'] = 'art_source_only_not_imported_or_collision_validated'
kit.finish(camera=(9, -34, 30), target=(.10, 3.15, 1.55), ortho=30.7,
           sun=(-11, -9, 18), sun_energy=3.5, warmth=(1.0, .87, .66), volume=.0036)
