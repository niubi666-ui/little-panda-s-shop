"""日照林庭 v001 — editable source scene, not a Godot runtime room.

Executed by Blender in a separate background process through the project
room_kit. The main build owner owns rendering and validation. All dimensional
values in this file are art composition settings, not gameplay definitions.
"""
from pathlib import Path
import math
import random
import sys

import bpy
from mathutils import Vector

ROOT = Path('E:/ShopGame/source_assets/environments/dungeon')
sys.path.insert(0, str(ROOT / 'shared' / 'scripts'))
from room_kit import Kit
from room_foliage import tree, ivy, flower_patch, fern, pot


def orient_between(obj, a, b):
    direction = Vector(b) - Vector(a)
    obj.location = (Vector(a) + Vector(b)) * .5
    obj.rotation_euler = direction.to_track_quat('Z', 'Y').to_euler()


def statue(kit, center):
    """Recognisable robed keeper proxy; separate and explicitly replaceable."""
    sx, sy, sz = center
    made = []
    rings = [(0.0, .49, .33), (.18, .45, .29), (.65, .34, .24),
             (1.00, .28, .20), (1.35, .40, .22), (1.48, .32, .19)]
    vertices, faces = [], []
    n = 32
    for h, rx, ry in rings:
        for j in range(n):
            ang = math.tau * j / n
            fold = 1.0 + .055 * math.sin(ang * 9.0)
            vertices.append((sx + rx * math.cos(ang) * fold,
                             sy + ry * math.sin(ang) * fold, sz + h))
    for ring in range(len(rings) - 1):
        for j in range(n):
            j2 = (j + 1) % n
            faces.append((ring*n+j, ring*n+j2, (ring+1)*n+j2, (ring+1)*n+j))
    faces.extend([tuple(range(n - 1, -1, -1)),
                  tuple((len(rings) - 1)*n+j for j in range(n))])
    robe = kit.mesh('Keeper_Robed_Body_REPLACEABLE', vertices, faces,
                    'stone', 'Replacement_Props')
    made.append(robe)

    # Hood is open toward the camera, with an inset face rather than a sphere.
    hood_v, hood_f = [], []
    for back in (0.0, .22):
        for j in range(17):
            t = math.pi * j / 16
            hood_v.append((sx + .285*math.cos(t), sy + back-.035,
                           sz+1.61 + .35*math.sin(t)))
    for j in range(16):
        hood_f.append((j,j+1,18+j,17+j))
    hood_f += [(0,17,33,16)]
    made.append(kit.mesh('Keeper_Hood_REPLACEABLE', hood_v, hood_f,
                         'stone_dark', 'Replacement_Props'))
    face = kit.lathe('Keeper_Quiet_Face_REPLACEABLE', (sx,sy-.005,sz+1.46),
                     [(.13,0),(.19,.10),(.185,.28),(.12,.39),(.035,.42)],
                     mat='stone',segments=24,group='Replacement_Props')
    face.scale.y = .72
    made.append(face)
    for side in (-1,1):
        made.append(kit.curve('Keeper_Cloaked_Arm_REPLACEABLE',
            [(sx+side*.32,sy,sz+1.32),(sx+side*.39,sy-.12,sz+1.05),
             (sx+side*.16,sy-.31,sz+.98)], .105,'stone','Replacement_Props'))
        # Flowing raised folds catch the sun on the silhouette.
        for index in range(3):
            xx = side * (.11+index*.105)
            made.append(kit.curve('Keeper_Robe_Fold_REPLACEABLE',
                [(sx+xx*.7,sy-.19,sz+.97),
                 (sx+xx*.9,sy-.245,sz+.49),
                 (sx+xx*1.1,sy-.30,sz+.05)],.023,'stone_dark','Replacement_Props'))
    made.append(kit.lathe('Keeper_Held_Seed_REPLACEABLE',(sx,sy-.36,sz+.92),
        [(.02,0),(.11,.055),(.15,.17),(.075,.31),(0,.4)],
        'brass',16,'Replacement_Props'))
    for obj in made:
        obj['replaceable'] = True
        obj['replacement_asset_id'] = 'prop.forest_keeper_statue'
        obj['source_note'] = 'Procedural silhouette study. Replace with approved Tripo/sculpt asset.'
    return made


def shrine(kit, center=(-3.75,8.30,.02)):
    x,y,z = center
    kit.stairs('Shrine_Shallow_Stair',(x,y-1.28,z),3.72,1.45,.52,4)
    kit.box('Shrine_Upper_Landing',(x,y-.10,z+.47),(3.75,1.70,.18),'stone')
    kit.box('Shrine_Plinth_Foot',(x,y+.18,z+.67),(3.22,1.25,.28),'stone_dark')
    kit.box('Shrine_Base_Coping',(x,y+.15,z+.87),(3.42,1.44,.13),'stone')
    # The niche is built in front of a stone backing, not a black painted arch.
    kit.box('Shrine_Back_Masonry',(x,y+.61,z+2.22),(3.48,.60,3.80),'stone_dark')
    for row in range(8):
        for col in range(4):
            kit.box('Shrine_Individual_Facing_Block',
                    (x-1.30+col*.87,y+.255,z+1.15+row*.38),
                    (.84,.17,.355),'stone',.025)
    kit.arch('Shrine_Carved_Niche',(x,y-.025,z+.88),2.32,1.84,.31,.45)
    # A shallow sill and inset face planes create a quiet shaded recess.
    kit.box('Shrine_Niche_Inset',(x,y+.105,z+2.08),(1.78,.08,2.11),'stone_dark',.10)
    for side in (-1,1):
        xx=x+side*1.67
        kit.box('Shrine_Flanking_Pier',(xx,y+.17,z+2.05),(.48,.75,3.38),'stone')
        for level in (1.00,1.78,2.58,3.46):
            kit.box('Shrine_Pier_Horizontal_Joint',(xx,y-.245,z+level),(.48,.025,.04),'mortar',.005)
        kit.box('Shrine_Pier_Lower_Shoe',(xx,y+.17,z+.79),(.69,.97,.25),'stone_dark')
        kit.box('Shrine_Pier_Capital',(xx,y+.17,z+3.89),(.68,.97,.20),'stone')
    kit.box('Shrine_Frieze_Shadow',(x,y+.22,z+4.05),(4.02,1.10,.22),'stone_dark')
    kit.box('Shrine_Overhanging_Cornice',(x,y+.22,z+4.23),(4.29,1.30,.20),'stone')
    kit.box('Shrine_Capstone',(x,y+.23,z+4.38),(4.08,1.17,.15),'stone')
    # Pediment triangle and inset botanical relief.
    vv=[(x-1.84,y-.30,z+4.37),(x+1.84,y-.30,z+4.37),(x,y-.30,z+5.14),
        (x-1.84,y+.37,z+4.37),(x+1.84,y+.37,z+4.37),(x,y+.37,z+5.14)]
    kit.mesh('Shrine_Stone_Pediment',vv,[(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)])
    kit.curve('Shrine_Pediment_Raking_Mould',
        [(x-1.92,y-.39,z+4.39),(x,y-.39,z+5.20),(x+1.92,y-.39,z+4.39)],.07,'stone')
    kit.curve('Shrine_Leaf_Relief_Stem',[(x,y-.352,z+4.45),(x+.015,y-.352,z+4.89)],.022,'brass')
    for side in (-1,1):
        kit.curve('Shrine_Leaf_Relief',[(x,y-.354,z+4.55),
            (x+side*.21,y-.354,z+4.67),(x+side*.15,y-.354,z+4.88),
            (x,y-.354,z+4.66)],.020,'brass')
    kit.lathe('Shrine_Statue_Pedestal',(x,y-.08,z+.95),
        [(.62,0),(.62,.13),(.48,.18),(.45,.48),(.54,.54),(.54,.63)],
        mat='stone',segments=24)
    statue(kit,(x,y-.09,z+1.59))
    for side in (-1,1):
        kit.lantern('Shrine_Warm_Offering_Lantern',(x+side*1.29,y-.47,z+.91),.48)
        pot(kit,'Shrine_White_Purple_Offering',(x+side*2.03,y-1.03,z+.02),.85,46+side)
        # Unequal, narrow cascades leave the inset sculpture and pier faces visible.
        ivy(kit,'Shrine_Draped_Ivy',(x+side*1.48,y-.47,z+4.29),
            3.05 if side < 0 else 2.20,.65 if side < 0 else .50,12+side)
    fern(kit,'Shrine_Roof_Fern',(x-1.36,y+.15,z+4.48),.95,66)
    flower_patch(kit,'Shrine_Roof_Garden',(x+.79,y+.17,z+4.48),(.85,.45),12,68)
    kit.banner('Shrine_Banner_Left',(x-2.37,y-.08,z+4.06),.83,2.26)
    kit.banner('Shrine_Banner_Right',(x+2.37,y-.08,z+4.06),.83,2.26)


def irregular_patch(kit,name,center,radius,mat,seed):
    rng=random.Random(seed)
    x,y,z=center
    vertices=[(x,y,z)]
    for j in range(28):
        a=math.tau*j/28
        r=radius*(.78+.23*rng.random())
        vertices.append((x+math.cos(a)*r,y+math.sin(a)*r*.59,z))
    return kit.mesh(name,vertices,[(0,j+1,(j+1)%28+1) for j in range(28)],mat,'Ground_Detail')


def natural_rock(kit,name,center,scale,seed):
    rng=random.Random(seed)
    x,y,z=center
    vv=[]
    for zz,rr in ((0,.78),(.37,1),(.89,.58),(1.03,.26)):
        for j in range(9):
            a=math.tau*j/9
            rad=rr*(.87+.23*rng.random())
            vv.append((x+scale[0]*rad*math.cos(a),y+scale[1]*rad*math.sin(a),z+scale[2]*zz))
    ff=[]
    for ring in range(3):
        for j in range(9):
            ff.append((ring*9+j,ring*9+(j+1)%9,(ring+1)*9+(j+1)%9,(ring+1)*9+j))
    ff.append(tuple(27+j for j in range(9)))
    return kit.mesh(name,vv,ff,'stone_dark','Forest_Exterior')


def main():
    kit=Kit('sunlit_forest_court',seed=260926)
    rng=random.Random(260926)
    # Courtyard rainwater has a separate optical treatment from the spring room.
    # It is a nearly flat clear film, with the actual sky providing its colour.
    puddle=kit.mats['water'].copy()
    puddle.name='Clear shallow rainwater on limestone'
    for node in puddle.node_tree.nodes:
        if node.type=='BSDF_PRINCIPLED':
            node.inputs['Base Color'].default_value=(.78,.89,.96,1)
            node.inputs['Transmission Weight'].default_value=.92
            node.inputs['Roughness'].default_value=.045
        elif node.type=='BUMP':
            node.inputs['Distance'].default_value=.003
            node.inputs['Strength'].default_value=.05
    kit.mats['court_puddle']=puddle
    kit.mats['forest_litter']=kit.textured('Moss mixed with forest leaf litter',
        (.028,.040,.014),(.080,.111,.034),5.4,.97,.16,.014)
    kit.scene['concept_reference']='concepts/combat_rooms/v003/01_sunlit_forest_court.png'
    kit.scene['asset_stage']='editable_blender_art_prototype_not_gameplay_ready'
    kit.scene['combat_clear_region_m']='x[-7.8,7.5], y[-6.8,5.9]; shallow ground inlay only'
    # Continuous environment, with paving extending beyond the camera foreground.
    kit.box('Continuous_Forest_Terrain',(0,3,-.68),(75,75,1.0),'forest_ground',0,'Forest_Exterior')
    kit.box('Court_Stone_Foundation',(0,.1,-.24),(21.0,17.0,.42),'stone_dark',.03)
    kit.tile_floor((-10,10,-8,8),(1.10,.88),0)
    kit.tile_floor((-9.6,9.6,-18,-8),(1.10,.88),-.015)
    kit.tile_floor((-9.70,-6.02,8,19),(1.08,.88),.03)
    kit.tile_floor((4.12,9.85,8,19),(1.12,.87),.03)
    # Inset stone strips visually frame the floor without vertical gameplay obstacles.
    for x in (-9.72,9.72):
        for j in range(18):
            kit.box('Court_Perimeter_Coping',(x,-7.65+j*.89,.025),(.28,.855,.09),'stone',.015)
    for x in range(-9,10):
        kit.box('Rear_Edge_Coping',(x,7.77,.02),(.96,.26,.08),'stone',.01)
    kit.medallion((.3,-.35),2.75,.068,'leaf')
    # Peripheral pools are shallow decorative patches; most paving stays dry.
    for i,(x,y,rad) in enumerate([(-8.3,-5.1,1.02),(-8.0,-2.0,.70),
                                  (8.1,-3.9,.81),(7.4,4.8,.72),(-6.6,5.9,.45)]):
        irregular_patch(kit,'Edge_Shallow_Rain_Pool',(x,y,.038),rad,'court_puddle',90+i)
    # Cracks and moss are concentrated at edges, preserving a readable fighting center.
    for i in range(75):
        x=rng.uniform(-9.6,9.6)
        y=rng.uniform(-7.6,7.6)
        if abs(x)<6.7 and abs(y)<5.4:
            continue
        length=rng.uniform(.20,.68)
        kit.curve('Moss_In_Perimeter_Joints',[(x,y,.045),
            (x+length*.38,y+.055,.046),(x+length,y+.03,.045)],
            rng.uniform(.014,.029),'leaf_1','Ground_Detail')

    # Side balustrades are low, and front sections terminate early for gameplay views.
    segments=[((-10,-8),(-10,-3.6)),((-10,-3.6),(-10,1.0)),
              ((-10,1),(-10,6.8)),((10,-7.4),(10,-2.5)),
              ((10,-2.5),(10,2.7)),((10,2.7),(10,7.8)),
              ((-5.8,8.2),(-.8,8.2)),((-.8,8.2),(3.5,8.2))]
    for i,(a,b) in enumerate(segments):
        kit.balustrade('Court_Low_Stone_Rail_%02d'%i,a,b,1.12)
    # Short foreground returns provide depth without closing the continuous floor.
    # The middle 13.4 m stays open and no tall foreground architecture is added.
    kit.balustrade('Foreground_Left_Low_Rail',(-10,-8),(-6.7,-8),.75)
    kit.balustrade('Foreground_Right_Low_Rail',(6.7,-8),(10,-8),.75)
    kit.balustrade('Foreground_Right_Return',(10,-8),(10,-7.4),.75)
    for side in (-1,1):
        kit.post('Foreground_Opening_End_Pier',(side*6.7,-8,0),1.03,.60)
        ivy(kit,'Foreground_Rail_Leaf_Drape',(side*8.52,-8.27,.79),
            .88 if side<0 else 1.05,1.32,1410+side)
    posts=[(-10,-8),(-10,-3.6),(-10,1),(-10,6.8),
           (10,-7.4),(10,-2.5),(10,2.7),(10,7.8),(-5.8,8.2),(-.8,8.2),(3.5,8.2)]
    for i,(x,y) in enumerate(posts):
        h=1.38 if i%3 else 1.54
        kit.post('Court_Balustrade_Square_Pier_%02d'%i,(x,y,0),h,.74)
        if i in (0,2,3,4,6,7,8,10):
            kit.lantern('Court_Caged_Brass_Lantern_%02d'%i,(x,y,h+.13),.98)
    # Rear right entrance is broad and open, with path visible beyond it.
    kit.arch('East_Path_Grand_Arch',(7.05,8.38,.02),5.15,3.40,.52,.86)
    for side in (-1,1):
        xx=7.05+side*2.84
        kit.box('Gate_Pier_Foot',(xx,8.38,.17),(.96,1.09,.36),'stone_dark')
        kit.box('Gate_Pier_Coping',(xx,8.38,3.30),(1.01,1.06,.21),'stone')
        kit.post('Gate_Outer_Banner_Post',(xx+side*.68,8.42,0),4.5,.59)
        kit.banner('Gate_Forest_Gold_Standard',(xx+side*.70,7.94,4.43),.86,2.40)
        ivy(kit,'Gate_Ivy_Cascade',(xx+side*.13,7.82,4.36),
            3.30 if side < 0 else 2.65,.55 if side < 0 else .62,144+side)
    kit.stairs('East_Exit_Threshold',(7.05,9.10,.01),4.67,1.15,.18,3)
    # Additional rail and posts make the exits read as connected architecture.
    for xx in (-9.83,-5.88):
        kit.balustrade('Northwest_Path_Rail',(xx,8.4),(xx,16.5),1.07)
        for yy in (10.5,14.0,16.5):
            kit.post('Northwest_Path_Pier',(xx,yy,.02),1.32,.65)
    for xx in (4.10,10.03):
        kit.balustrade('Northeast_Path_Rail',(xx,10),(xx,16.0),1.01)
    shrine(kit)

    # Flags at the near side articulate the edges but stay below the far gate skyline.
    for i,(x,y,angle) in enumerate([(-10.28,2.7,0),(10.33,-5.2,-.30)]):
        pole=kit.cylinder('Courtyard_Banner_Pole',(x,y,1.73),.065,3.46,'brass',16)
        kit.curve('Courtyard_Banner_Crossbar',[(x-.15,y,3.33),(x+1.03,y,3.33)],.051,'brass')
        kit.banner('Courtyard_Green_Gold_Banner',(x+.44,y-.035,3.24),.87,1.91,angle)
        kit.lathe('Courtyard_Banner_Finial',(x,y,3.40),[(.03,0),(.10,.12),(.04,.27),(0,.39)],'brass',16)

    # Foliage is a layered perimeter garden. No planters or trees in the central arena.
    beds=[(-9.06,-6.9,(.73,1.02)),(-9.10,-3.7,(.73,1.50)),
          (-9.08,.30,(.75,1.24)),(-9.07,3.65,(.72,1.45)),
          (-8.67,7.08,(.94,.47)),(-5.55,6.74,(1.1,.54)),
          (-1.23,7.10,(1.45,.54)),(1.88,7.15,(1.44,.51)),
          (3.62,6.70,(.78,.49)),(9.01,5.1,(.68,1.1)),
          (9.08,1.34,(.65,1.42)),(9.02,-2.42,(.72,1.10)),
          (8.90,-6.57,(.71,1.07))]
    for i,(x,y,extent) in enumerate(beds):
        # Soil stays underneath the roots, not as a large black disc around them.
        irregular_patch(kit,'Garden_Edge_Soil',(x,y,.036),min(extent)*.42,'soil',220+i)
        spread=(extent[0]*1.22,extent[1]*1.30)
        flower_patch(kit,'Court_White_Purple_Wildflowers_%02d'%i,(x,y,.055),spread,50,330+i)
        for k in range(2):
            along=(k-.5)*.49
            fx=x+rng.uniform(-.13,.13) if abs(x)>7.5 else x+along
            fy=y+along if abs(x)>7.5 else y+rng.uniform(-.13,.13)
            fern(kit,'Court_Lacy_Fern_%02d_%d'%(i,k),(fx,fy,.055),
                 rng.uniform(.46,.68),430+i*2+k)
    # Interstitial clumps connect the hero beds into a narrow railing-foot garden.
    # This border stays outside the clear central combat area.
    edge_fill=[(-9.36,y) for y in (-5.28,-1.71,1.98,5.35)]
    edge_fill += [(9.38,y) for y in (-4.53,-.51,3.23)]
    for i,(x,y) in enumerate(edge_fill):
        flowers=flower_patch(kit,'Rail_Foot_Continuous_Wildflowers_%02d'%i,
            (x,y,.045),(.78,2.25),48,540+i)
        flowers.scale.z=.72
        fern(kit,'Rail_Foot_Low_Fern_%02d'%i,(x,y+.33,.045),.46,560+i)
    for i,x in enumerate((-.15,1.95,3.23)):
        flower_patch(kit,'Rear_Rail_Continuous_Wildflowers_%02d'%i,
            (x,7.65,.045),(1.85,.69),48,578+i)
    for i,side in enumerate((-1,1)):
        flower_patch(kit,'Foreground_Corner_Low_Wildflowers_%d'%i,
            (side*8.50,-7.69,.045),(2.30,.66),48,1430+i)
    # A handful of larger fronds breaks the even height of the border garden.
    # Their roots remain outside the main movement rectangle.
    larger_edge_ferns=[(-9.40,-7.06,1.12),(-9.35,-3.35,1.07),
                       (-9.42,1.17,1.20),(-8.55,-7.59,.99),
                       (9.43,-6.77,1.16),(9.32,-2.94,1.08),
                       (9.34,3.10,1.12),(8.25,-7.60,.96)]
    for i,(x,y,scale) in enumerate(larger_edge_ferns):
        fern(kit,'Perimeter_Hero_Fern_%02d'%i,(x,y,.046),scale,1450+i)
    for i,(x,y) in enumerate([(-10.1,-5.6),(-10.1,-.8),(-10.1,4.9),
                             (10.05,-5.8),(10.05,-.9),(10.05,4.0),(.3,8.12)]):
        vines=ivy(kit,'Rail_Trailing_Ivy_%02d'%i,(x,y,1.22),
            1.32+.18*(i%3),.88+.13*(i%2),610+i)
        if abs(x)>8:
            vines.rotation_euler.z=math.pi*.5 if x<0 else -math.pi*.5
    for i,(x,y,s) in enumerate([(-8.96,6.37,.72),(2.87,7.03,.70),
                               (9.10,6.3,.70),(-1.29,8.69,.90)]):
        pot(kit,'Perimeter_Herb_Pot_%02d'%i,(x,y,.045),s,700+i)
    # Sun-side tree overhang casts branch shadows, with a second forest layer behind.
    tree_specs=[(-16.0,-7.0,12.0,4.8),(-13.4,4.8,10.9,5.4),(-12.0,13.1,10.1,4.3),
                (-4.5,15.9,12.2,4.6),(2.4,17.4,12.4,4.7),
                (13.7,14.4,11.4,4.4),(18.5,8.0,10.1,3.4),
                (-17.5,20.5,14.8,5.4),(9.4,26.0,15.0,5.7),
                (20.2,24.3,14.4,5.3),(-1.0,27.5,14.5,5.6)]
    for i,(x,y,h,s) in enumerate(tree_specs):
        tree(kit,'Forest_Mature_Tree_%02d'%i,(x,y,-.12),h,s,850+i)
    # Conceal bare terrain around the sun-side root flare with layered low plants.
    for i,(x,y,scale) in enumerate([(-12.1,4.55,1.42),(-13.3,3.50,1.32),
                                   (-14.3,5.60,1.55)]):
        fern(kit,'Sun_Tree_Root_Underplanting_%02d'%i,(x,y,-.145),scale,1490+i)
    flower_patch(kit,'Sun_Tree_Root_Low_Flowers',(-12.75,3.96,-.14),
                 (2.65,1.35),48,1500)
    # A low, connected forest floor breaks up the exposed loam between rear trees.
    # Patches stay between/outside the two paved exits and below the balustrades.
    understory=[(-3.1,10.9,2.6),(.2,11.9,2.8),(-2.6,15.1,2.9),
                (.5,17.3,2.7),(-12.1,9.4,2.2),(-12.9,14.2,2.8),
                (12.0,10.0,2.1),(13.1,15.6,2.8)]
    for i,(x,y,r) in enumerate(understory):
        irregular_patch(kit,'Forest_Low_Moss_And_Litter_%02d'%i,
            (x,y,-.171),r,'forest_litter',1210+i)
        root=flower_patch(kit,'Forest_Low_Whiteflower_Meadow_%02d'%i,
            (x,y,-.14),(r*1.62,r*.99),50,1240+i)
        root.scale.z=.69
        for k in range(3):
            a=math.tau*k/3+.4*i
            fern(kit,'Forest_Soft_Understory_%02d_%d'%(i,k),
                (x+math.cos(a)*r*.58,y+math.sin(a)*r*.40,-.14),
                .64+.11*(k%2),1280+i*3+k)
    for i in range(24):
        side=-1 if i%2 else 1
        x=side*rng.uniform(11.5,21.2)
        y=rng.uniform(-3.0,25.0)
        natural_rock(kit,'Forest_Edge_Natural_Boulder_%02d'%i,(x,y,-.24),
                     (rng.uniform(.45,1.28),rng.uniform(.40,1.08),rng.uniform(.48,1.3)),950+i)
        fern(kit,'Forest_Understory_Fern_%02d'%i,(x+.35,y,-.16),rng.uniform(.80,1.50),1050+i)
        if i%3==0:
            flower_patch(kit,'Forest_Exterior_Flowers_%02d'%i,(x-.3,y,-.14),(1.3,1.0),15,1150+i)

    # Visual assembly markers only; no navigation or spawn promises.
    marker_collection=bpy.data.collections.new('Art_Layout_Markers_NONEXPORT')
    kit.scene.collection.children.link(marker_collection)
    for name,loc,description in [
        ('ART_Exit_Northwest',(-7.8,9.9,.10),'Connected path, nominal clear width 3.5 m'),
        ('ART_Exit_Northeast',(7.05,9.8,.10),'Arch exit, nominal clear width 4.8 m'),
        ('ART_Combat_Open_Center',(.3,-.35,.10),'Clear center; not gameplay navigation data')]:
        obj=bpy.data.objects.new(name,None)
        marker_collection.objects.link(obj)
        obj.location=loc
        obj.empty_display_type='PLAIN_AXES'
        obj.empty_display_size=.6
        obj.hide_render=True
        obj['note']=description
    kit.finish(camera=(15,-33,30),target=(0,3.0,1.15),ortho=29.4,
               sun=(-14,-8,14),sun_energy=4.1,warmth=(1.0,.73,.41),volume=.004)


if __name__=='__main__':
    main()
