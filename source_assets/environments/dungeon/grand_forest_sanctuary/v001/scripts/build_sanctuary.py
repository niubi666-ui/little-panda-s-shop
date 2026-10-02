"""Blender-only sanctuary assembly. All numbers are art authoring dimensions in metres.
Run in a fresh background process; original library and Godot files remain read-only.
"""
import bpy, bmesh, math, random, json, sys, hashlib
from pathlib import Path
from mathutils import Vector, Matrix
import numpy as np
BASE=Path('E:/ShopGame/source_assets/environments/dungeon/grand_forest_sanctuary/v001')
SOURCE=BASE/'original/forest_yard_item.blend'
SHARED=Path('E:/ShopGame/source_assets/environments/dungeon/shared/scripts')
sys.path.insert(0,str(SHARED))
from room_kit import Kit,enum
from room_foliage import _Geometry,_leaf,fern,flower_patch
assert bpy.app.background
kit=Kit('grand_forest_sanctuary/v001',270929); s=kit.scene; rng=random.Random(270929)
s.name='Grand_Forest_Sanctuary_36x32m_v001'
inventory=json.loads((BASE/'reports/source_inventory.json').read_text(encoding='utf-8'))
INDEX={'rail':0,'broken_wall':1,'corner':2,'pier':3,'bridge':4,'chest':5,'mushrooms':6,'hive':7,'stump':8,'low_wall':9,'low_corner':10,'stone_chest':11,'bag':12,'fallen_column':13,'barrel':14,'crate':15,'moss_patch':16,'moss_cushion':17,'moss_seam':18,'litter':19,'oak':21,'ivy':22,'flowerpot':23,'white_flower':24,'purple_flower':25,'steps':26,'rock_flat':27,'roundel':28,'rock_medium':29,'rock_large':30,'paving':31,'curb':32,'statue':33,'shrine':34}
IDS={k:inventory['objects'][v]['name'] for k,v in INDEX.items()}
with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst):dst.objects=list(IDS.values())
loaded={o.name:o for o in dst.objects}; proto={};sizes={};use={k:0 for k in IDS}
for key,name in IDS.items():
 o=loaded[name];me=o.data.copy()
 rotation=Matrix.Rotation(-math.pi/2,4,'Y') if key=='roundel' else Matrix.Rotation(-math.pi/2,4,'Z')
 me.transform(rotation);me.update()
 low=Vector([min(v.co[a] for v in me.vertices) for a in range(3)]);high=Vector([max(v.co[a] for v in me.vertices) for a in range(3)])
 me.transform(Matrix.Translation(-Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))));me.update()
 sizes[key]=high-low;me.name='FY_'+key+'_shared';proto[key]=me
 bpy.data.objects.remove(o,do_unlink=True)

def asset(key,name,loc,dim=None,height=None,angle=0,group='Architecture'):
 o=bpy.data.objects.new(name,proto[key]);kit.collection(group).objects.link(o);o.location=loc;o.rotation_euler.z=angle
 if dim:o.scale=tuple(dim[a]/sizes[key][a] for a in range(3))
 elif height:o.scale=(height/sizes[key].z,)*3
 o['source_file']='forest_yard_item.blend';o['source_object']=IDS[key];o['asset_role']=key;use[key]+=1
 return o
def pbr(m):return next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
for key,me in proto.items():
 for i,source_mat in enumerate(list(me.materials)):
  m=source_mat.copy();me.materials[i]=m;m.name='Sanctuary_'+key+'_PBR';p=pbr(m);n=m.node_tree.nodes;l=m.node_tree.links
  for link in list(p.inputs['Normal'].links):l.remove(link)
  tex=n.new('ShaderNodeTexCoord');noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=110;noise.inputs['Detail'].default_value=3;l.new(tex.outputs['Generated'],noise.inputs['Vector'])
  bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.19;bump.inputs['Distance'].default_value=.004;l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal']);p.inputs['Roughness'].default_value=.76
  if key in ['white_flower','purple_flower','ivy']:
   p.inputs['Roughness'].default_value=.66
   out=next(x for x in n if x.type=='OUTPUT_MATERIAL');tr=n.new('ShaderNodeBsdfTranslucent');l.new(p.inputs['Base Color'].links[0].from_socket,tr.inputs[0]);mix=n.new('ShaderNodeMixShader');mix.inputs[0].default_value=.12;l.new(p.outputs[0],mix.inputs[1]);l.new(tr.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs['Surface'])

# Texture-backed floor: retain supplied UVs and shape; gently flatten for walkable paving.
kit.box('Main_court_36m_by_32m_foundation',(0,0,-.18),(36,32,.24),'mortar',0,'Ground')
# As in the approved first courtyard, the bridge centre supplies naturally chipped,
# staggered limestone. Preserve its UVs and remove both raised curbs.
bm=bmesh.new();bm.from_mesh(proto['bridge'])
for co,no in [((-.13,0,0),(1,0,0)),((.13,0,0),(-1,0,0)),((0,-.37,0),(0,1,0)),((0,.37,0),(0,-1,0)),((0,0,.185),(0,0,1)),((0,0,.245),(0,0,-1))]:
 bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=co,plane_no=no,clear_inner=True,dist=.00001)
me=bpy.data.meshes.new('Bridge_derived_paving_UV_preserved');bm.to_mesh(me);bm.free()
for v in me.vertices:v.co.z=(v.co.z-.218)*.7
me.materials.append(proto['bridge'].materials[0]);me.update()
for j in range(5):
 for i in range(10):
  o=bpy.data.objects.new(f'Continuous_paving_{i}_{j}',me);kit.collection('Ground').objects.link(o);o.location=(-18+i*4,-16+j*8,0);o.scale=(4/.26,8/.74,1);o.rotation_euler.z=math.pi*((i+j)%2);o['source_object']=IDS['bridge'];o['derived']='UV-preserving cropped bridge centre';use['bridge']+=1
for k,(x,y,r) in enumerate([(-5.8,2.5,3.7),(12.0,-2.0,3.9),(6.4,-9.5,3.5),(-7.5,12.2,3.4)]):
 asset('roundel',f'Six_leaf_inlaid_roundel_{k}',(x,y,-.026),dim=(r*2,r*2,.068),angle=.18+k*.43,group='Ground')

# Low obstacle islands, not a closed small arena.
obstacle_islands=[]
def garden_wall(label,center,length,angle=0):
 x,y=center;dx,dy=math.cos(angle),math.sin(angle)
 wall=asset('low_wall',label+'_wall',(x,y,-.018),dim=(length,.52,1.03),angle=angle)
 obstacle_islands.append({'center':[x,y],'length':length,'width':.75,'angle':angle})
 for end in [-1,1]:
  pos=(x+dx*length*.49*end,y+dy*length*.49*end,-.015)
  asset('pier',label+'_end_'+str(end),pos,dim=(.65,.65,1.32))
 return wall
garden_wall('West_cover',(-7,-5.6),4.6,-.08)
garden_wall('East_cover',(5.1,1.65),4.2,math.pi/2)
garden_wall('Lower_east_cover',(11.1,-9),4.6,.14)
garden_wall('Northwest_garden',(-11,11),5.3,.05)
garden_wall('Far_east_garden',(15.5,7),4,math.pi/2)
garden_wall('Far_southwest_garden',(-13,-13.6),4.1,.2)
asset('broken_wall','West_cover_broken_return',(-9.1,-4.6,-.02),dim=(2.3,.54,.9),angle=math.pi/2)
asset('broken_wall','East_cover_broken_return',(6.2,3.4,-.02),dim=(2.4,.58,1.08))
asset('fallen_column','North_garden_fallen_column',(-4.5,12.2,.02),height=.78,angle=.35)

# Shrine and an open monumental colonnade. The assembled module continues offscreen.
shrine=asset('shrine','Guardian_Shrine',(0.8,10.1,-.01),dim=(4.8,1.8,5.9))
kit.box('Shrine_recess_backing',(0.8,10.57,2.75),(2.75,.14,4.1),'stone_dark',.03)
statue=asset('statue','Robed_Guardian',(0.8,9.64,.62),height=3.68,group='Decor')
asset('steps','Shrine_three_approach_steps',(0.8,8.5,-.30),dim=(3.55,1.5,.87))
for x in [-2.05,3.63]:asset('flowerpot','Shrine_flower_offering',(x,8.56,.02),height=.81,group='Decor')
column_positions=[(5.7,10.5),(11.5,10.5),(17.3,10.5),(5.7,15.0),(11.5,15),(17.3,15)]
for i,(x,y) in enumerate(column_positions):
 asset('pier',f'Colonnade_carved_pier_{i}',(x,y,.015),dim=(1.38,1.38,5.5))
 kit.box(f'Colonnade_capital_{i}',(x,y,5.54),(1.65,1.65,.32),'stone',.08)
 asset('ivy',f'Colonnade_ivy_{i}',(x-.29,y-.52,2.36),height=3.13,group='Vegetation')
 for xoff in [-.48,.48]:asset('curb',f'Pier_base_course_{i}',(x+xoff,y,-.01),dim=(.22,1.65,.24),angle=0)
for row in [10.5,15]:
 for x in [8.6,14.4]:kit.box('Colonnade_overhead_lintel',(x,row,5.86),(5.85,1.12,.45),'stone',.085)
for x in [5.7,11.5,17.3]:kit.box('Colonnade_cross_lintel',(x,12.75,5.86),(1.12,4.55,.45),'stone',.08)

# Existing textured banners and lanterns from the approved first courtyard, reused as art assets.
OLD=Path('E:/ShopGame/source_assets/environments/dungeon/forest_courtyard/v001/blender/forest_courtyard_item2_v001.blend')
with bpy.data.libraries.load(str(OLD),link=False) as (src,dst):
 dst.objects=['Shrine_Left_Leaf_Banner','Shrine_Offering_Candle']
extra={o.name.split('.')[0]:o for o in dst.objects if o}
banner_proto=next(o for o in extra.values() if 'Banner' in o.name);lamp_proto=next(o for o in extra.values() if 'Candle' in o.name)
def extra_asset(source,name,loc,height,group='Decor'):
 me=source.data;o=bpy.data.objects.new(name,me);kit.collection(group).objects.link(o);o.location=loc
 zmin=min(v.co.z for v in me.vertices);zmax=max(v.co.z for v in me.vertices);o.scale=(height/(zmax-zmin),)*3
 o.location.z-=zmin*o.scale.z;o['source_file']=str(OLD);o['source_object']=source.name
 return o
for i,(x,y) in enumerate(column_positions[:3]):
 extra_asset(banner_proto,'Leaf_banner_on_colonnade_'+str(i),(x,y-.8,2.2),2.45)
for i,(x,y,z) in enumerate([(-2.25,8.68,1.37),(3.8,8.7,1.37),(-9.2,-5.42,1.32),(5.1,-.40,1.32),(5.1,3.7,1.32),(13.33,-8.68,1.32),(8.87,-9.32,1.32),(15.5,9,1.32),(-13.58,11,1.32)]):
 if i<2:asset('pier','Shrine_lamp_pedestal_'+str(i),(x,y,0),dim=(.76,.76,1.37))
 extra_asset(lamp_proto,'Bronze_lantern_'+str(i),(x,y,z),.58)
 kit.light('Candle_pool_'+str(i),'POINT',(x,y,z+.27),(1,.46,.10),20,.12)
for o in extra.values():bpy.data.objects.remove(o,do_unlink=True)
for i,(x,y,z,h) in enumerate([(-1.24,9.51,3.0,2.7),(2.65,9.52,3.3,2.45),(-9.3,-5.4,.12,1.2),(5.0,3.3,.19,1.28)]):
 asset('ivy','Shrine_and_wall_ivy_'+str(i),(x,y,z),height=h,group='Vegetation')

# Hero tree, with true individual leaves layered over the supplied low-poly canopy.
tree=asset('oak','Hero_Ancient_Oak',(-11.5,3.8,-.12),height=13.8,angle=-.25,group='Trees')
tree.scale.z*=1.42
me=proto['oak'];me.update();im=next(n.image for n in me.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
pixels=np.empty(len(im.pixels),dtype=np.float32);im.pixels.foreach_get(pixels);pixels=pixels.reshape(im.size[1],im.size[0],4)
sites=[]
for p in me.polygons:
 if p.center.z<sizes['oak'].z*.39:continue
 uv=me.uv_layers.active.data[p.loop_indices[0]].uv
 c=pixels[min(im.size[1]-1,max(0,int(uv.y*im.size[1]))),min(im.size[0]-1,max(0,int(uv.x*im.size[0])))]
 if c[1]>c[0]*.84 and c[1]>c[2]*1.3:sites.append(p.center.copy())
leafgeo=_Geometry()
for i in range(18000):
 c=rng.choice(sites)+Vector((rng.uniform(-.022,.022),rng.uniform(-.025,.025),rng.uniform(-.008,.030)))
 a=rng.uniform(0,math.tau);_leaf(leafgeo,c,(math.cos(a),math.sin(a),rng.uniform(-.4,.4)),(0,0,1),rng.uniform(.009,.018),rng.uniform(.004,.009),rng.randrange(5))
leaves=kit.mesh('Ancient_oak_individual_leaves',leafgeo.verts,leafgeo.faces,'leaf_0','Trees')
for j in range(1,5):leaves.data.materials.append(kit.mats['leaf_'+str(j)])
for p,mi in zip(leaves.data.polygons,leafgeo.materials):p.material_index=mi
leaves.parent=tree
for i,(x,y,h) in enumerate([(-21,14,14),(-19,-7,12),(22,13,14),(2,24,15),(-12,24,15),(17,24,16),(-23,-19,13),(23,-18,14)]):
 t=asset('oak','Surrounding_forest_oak_'+str(i),(x,y,-.2),height=h,angle=rng.uniform(0,math.tau),group='Trees')
 o=bpy.data.objects.new('Forest_individual_leaves_'+str(i),leaves.data);kit.collection('Trees').objects.link(o);o.parent=t

# Offscreen high branches give broken leaf shadows without filling walking lanes.
over=_Geometry()
for center in [(-8,9,10),(-4,12,10.7),(1,14,11),(8,14,11.8),(-15,0,8.5),(-8,8,7),(-4,10,7),(3,12,7),(6,10,8)]:
 for j in range(1300):
  pos=Vector(center)+Vector((rng.gauss(0,1.55),rng.gauss(0,.9),rng.gauss(0,.22)))
  a=rng.uniform(0,math.tau);_leaf(over,pos,(math.cos(a),math.sin(a),.1),(0,0,1),rng.uniform(.13,.29),rng.uniform(.055,.12),rng.randrange(5))
o=kit.mesh('High_canopy_light_filter_leaves',over.verts,over.faces,'leaf_0','Trees')
for j in range(1,5):o.data.materials.append(kit.mats['leaf_'+str(j)])
for p,mi in zip(o.data.polygons,over.materials):p.material_index=mi
o.visible_camera=False

# Varied clustered flower beds only around roots, columns and cover. Clear centre.
plant_sites=[]
for i in range(105):
 a=rng.uniform(0,math.tau);r=rng.uniform(3.2,5.2);x=-11.5+math.cos(a)*r;y=3.8+math.sin(a)*r
 plant_sites.append((x,y))
for island in obstacle_islands:
 x,y=island['center'];a=island['angle'];dx,dy=math.cos(a),math.sin(a)
 for i in range(24):
  t=rng.uniform(-.52,.52)*island['length'];side=rng.choice([-1,1])*rng.uniform(.36,.83)
  plant_sites.append((x+dx*t-dy*side,y+dy*t+dx*side))
for x,y in column_positions+[(-1.9,9),(3.65,9)]:
 for j in range(14):
  a=rng.uniform(0,math.tau);r=rng.uniform(.5,1.28);plant_sites.append((x+math.cos(a)*r,y+math.sin(a)*r))
for i,(x,y) in enumerate(plant_sites):
 kind='white_flower' if rng.random()<.76 else 'purple_flower'
 asset(kind,f'Flower_bed_{i:03d}_{kind}',(x,y,.015),height=rng.uniform(.41,.68),angle=rng.uniform(0,math.tau),group='Vegetation')
 if i%9==0:fern(kit,'Fern_bed_'+str(i),(x+.15,y,.013),rng.uniform(.65,1.05),270000+i)
 if i%7==0:flower_patch(kit,'Meadow_accent_'+str(i),(x,y,.016),extent=(.92,.72),count=15,seed=284000+i)
 if i%3==0:asset('moss_patch','Bed_moss_'+str(i),(x,y,-.002),dim=(rng.uniform(.48,.85),rng.uniform(.4,.7),.038),angle=rng.uniform(0,math.tau),group='Ground_Details')

# Sparse ground growth, with softer large-scale breaks in repeated source paving.
for i in range(240):
 x=rng.uniform(-17.8,17.8);y=rng.uniform(-15.8,15.8)
 if rng.random()<.45 and abs(x)<5 and -7<y<6:continue
 kind=rng.choice(['moss_seam','moss_patch','moss_cushion']);w=rng.uniform(.3,1.25)
 asset(kind,'Paving_moss_'+str(i),(x,y,.006),dim=(w,w*rng.uniform(.55,1.3),rng.uniform(.016,.031)),angle=rng.uniform(0,math.tau),group='Ground_Details')
for i in range(65):
 asset('litter','Dry_leaf_litter_'+str(i),(rng.uniform(-17,17),rng.uniform(-15,15),.014),dim=(rng.uniform(.18,.4),rng.uniform(.18,.4),.025),angle=rng.uniform(0,math.tau),group='Ground_Details')

# Props are separate objects for later art replacement and interaction setup.
for i,(x,y,w) in enumerate([(-8,7.9,.92),(-7.03,8.0,.76),(-8.4,1.0,.85),(4.33,3.7,.81),(14.0,11.1,.95),(-14,-12,.9)]):
 asset('crate','Breakable_crate_'+str(i),(x,y,.02),dim=(w,w,w),angle=rng.uniform(-.3,.3),group='Interactive_Props')
for i,(x,y) in enumerate([(-9.35,8.25),(4.5,4.5),(6.0,2.85),(11.8,-8.0),(-12,-12.5)]):asset('barrel','Breakable_barrel_'+str(i),(x,y,.02),height=.98,angle=rng.uniform(0,6),group='Interactive_Props')
asset('chest','Searchable_hero_chest',(10,-8.05,.02),height=.94,angle=.22,group='Interactive_Props')
asset('stone_chest','Searchable_relic_cache',(-14,11.4,.015),height=.77,group='Interactive_Props')
for i,(x,y,w) in enumerate([(-9.6,4.4,2.0),(-12,-.3,2.2),(14.8,8.3,1.8),(-12.8,-4.3,1.6)]):
 asset('rock_medium','Garden_limestone_boulder_'+str(i),(x,y,-.02),dim=(w,w*.8,w*.5),angle=rng.uniform(0,6),group='Decor')
asset('mushrooms','Oak_small_mushroom_cluster',(-9.8,5.8,.015),height=.42,group='Vegetation')

# Thin rainwater at the architecture edge; the walkable centre stays dry.
water=bpy.data.materials.new('Shallow_rainwater_Fresnel_reflection');water.use_nodes=True;n=water.node_tree.nodes;l=water.node_tree.links;n.clear()
out=n.new('ShaderNodeOutputMaterial');tr=n.new('ShaderNodeBsdfTransparent');ref=n.new('ShaderNodeBsdfPrincipled');ref.inputs['Base Color'].default_value=(.73,.85,.92,1);ref.inputs['Metallic'].default_value=1;ref.inputs['Roughness'].default_value=.052
fres=n.new('ShaderNodeFresnel');fres.inputs['IOR'].default_value=1.4;mix=n.new('ShaderNodeMixShader');boost=n.new('ShaderNodeMath');boost.operation='MULTIPLY';boost.inputs[1].default_value=2.5;boost.use_clamp=True;l.new(fres.outputs[0],boost.inputs[0]);l.new(boost.outputs[0],mix.inputs[0]);l.new(tr.outputs[0],mix.inputs[1]);l.new(ref.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs['Surface'])
for i,(x,y,rx,ry) in enumerate([(9.0,10.1,1.8,.85),(-9.4,-3.7,.85,.43),(13.6,9.6,1.1,.65)]):
 vv=[(x,y,.034)];N=80
 for j in range(N):
  a=j*math.tau/N;r=1+.12*math.sin(7*a+i)+.055*math.sin(13*a);vv.append((x+rx*r*math.cos(a),y+ry*r*math.sin(a),.034))
 kit.mesh('Peripheral_rainwater_'+str(i),vv,[(0,j+1,(j+1)%N+1) for j in range(N)],water,'Water')

# Read-only copy of the actual game protagonist, using its current visual scale.
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath='E:/ShopGame/game/assets/characters/red_panda/red_panda_v008.glb')
imported=[o for o in bpy.data.objects if o not in before]
player_root=kit.root('Player_scale_reference',(1.3,-2.7,.03),'Scale_Reference');player_root.scale=(1.20058629,)*3;player_root.rotation_euler.z=.35
for o in imported:
 for col in list(o.users_collection):col.objects.unlink(o)
 kit.collection('Scale_Reference').objects.link(o)
 if not o.parent:o.parent=player_root
 if o.animation_data:
  for track in o.animation_data.nla_tracks:track.mute=True
  action=next((a for a in bpy.data.actions if a.name.lower().startswith('idle')),None)
  if action:
   o.animation_data.action=action
   if action.slots:o.animation_data.action_slot=action.slots[0]
s.frame_set(1)
bpy.context.view_layer.update()
rig=next(o for o in imported if o.type=='ARMATURE')
hand_position=rig.matrix_world@rig.pose.bones['R_Hand'].head
# Bake just the preview actor's evaluated meshes; retain sources elsewhere untouched.
player_meshes=[]
for o in imported:
 if o.type=='MESH' and o.name.startswith('RedPandaMesh'):
  dep=bpy.context.evaluated_depsgraph_get();ev=o.evaluated_get(dep);me=bpy.data.meshes.new_from_object(ev,depsgraph=dep)
  clone=bpy.data.objects.new('Player_reference_'+o.name,me);kit.collection('Scale_Reference').objects.link(clone);clone.matrix_world=o.matrix_world.copy();player_meshes.append(clone)
for o in imported:bpy.data.objects.remove(o,do_unlink=True)
bpy.data.objects.remove(player_root,do_unlink=True)
points=[o.matrix_world@v.co for o in player_meshes for v in o.data.vertices]
player_min=min(v.z for v in points);player_max=max(v.z for v in points)
for o in player_meshes:o.location.z+=.035-player_min
player_height=player_max-player_min
hand_position.z+=.035-player_min
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath='E:/ShopGame/game/assets/weapons/longsword_v001/longsword.glb')
weapon_objects=[o for o in bpy.data.objects if o not in before]
rotation=Vector((0,1,0)).rotation_difference(Vector((.72,-.58,-.38)).normalized()).to_matrix().to_4x4()
transform=Matrix.Translation(hand_position)@rotation@Matrix.Translation((0,.675,0))
for o in weapon_objects:
 for c in list(o.users_collection):c.objects.unlink(o)
 kit.collection('Scale_Reference').objects.link(o);o.matrix_world=transform@o.matrix_world;o.name='Player_sword_'+o.name
 o['source_file']='game/assets/weapons/longsword_v001/longsword.glb';o['purpose']='Read-only visual scale reference'

# Warm sunlight and cool sky; all lamps are real scene lights.
sun=kit.light('Golden_sun_through_oak','SUN',(-10,12,19),(1,.76,.46),4.7,target=(0,-1,0));sun.data.angle=.022
kit.light('Canopy_warm_bounce','AREA',(-8,7,13),(1,.82,.60),450,7,(0,-2,0))
kit.light('Open_sky_soft_fill','AREA',(2,-5,17),(.63,.79,1),650,16,(0,2,0))
world=bpy.data.worlds.new('Forest_cool_skylight');world.use_nodes=True;bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(.42,.57,.82,1);bg.inputs[1].default_value=.5;s.world=world
fog=bpy.data.materials.new('Subtle_sunlit_forest_haze');fog.use_nodes=True;n=fog.node_tree.nodes;l=fog.node_tree.links;n.clear();out=n.new('ShaderNodeOutputMaterial');v=n.new('ShaderNodeVolumePrincipled');v.inputs['Density'].default_value=.0018;v.inputs['Anisotropy'].default_value=.35;l.new(v.outputs[0],out.inputs['Volume']);kit.box('Forest_air',(0,0,13),(90,90,35),fog,0,'Atmosphere')
kit.box('Continuous_forest_earth',(0,0,-.3),(95,95,.2),'forest_ground',0,'Forest_Ground')
def camera(name,location,target,width):
 data=bpy.data.cameras.new(name);ob=bpy.data.objects.new(name,data);kit.collection('Cameras').objects.link(ob);ob.location=location;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=width;data.clip_end=220;return ob
s.camera=camera('Camera_Gameplay_Hero',(10,-21,24),(0,1.3,0),25.8)
camera('Camera_Whole_Room_Topdown',(0,0,50),(0,0,0),43)
camera('Camera_Shrine_Detail',(9,-6,10),(1,9,2),13)
camera('Camera_Oak_Detail',(-1,-10,12),(-10,5,3),17)
s.render.engine='CYCLES';s.cycles.samples=160;s.cycles.use_denoising=True;s.cycles.max_bounces=8;s.cycles.transparent_max_bounces=12
pref=bpy.context.preferences.addons['cycles'].preferences
if 'OPTIX' in [p[0] for p in pref.get_device_types(bpy.context)]:
 pref.compute_device_type='OPTIX';pref.refresh_devices()
 for dev in pref.devices:dev.use=dev.type=='OPTIX'
 s.cycles.device='GPU'
s.render.resolution_x=2560;s.render.resolution_y=1440;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.filepath=str(BASE/'previews/sanctuary_hero.png')
s.view_settings.exposure=.35
try:s.view_settings.look='AgX - Medium High Contrast'
except TypeError:pass
s['art_stage']='Editable Blender art; no Godot integration';s['court_width_m']=36.0;s['court_length_m']=32.0;s['court_area_m2']=1152.0;s['previous_court_area_m2']=288.0;s['area_ratio']=4.0;s['reference']=str(BASE/'reference/01-grand-forest-sanctuary.png')
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.overlay.show_overlays=False;area.spaces.active.shading.type='MATERIAL'
for im in bpy.data.images:
 if im.packed_file:
  data=bytes(im.packed_file.data);ext='.png' if data.startswith(b'\x89PNG') else '.jpg';path=BASE/'textures'/(im.name+ext);path.write_bytes(data);im.unpack(method='REMOVE');im.filepath=str(path);im.reload();im.pack()
bpy.ops.file.pack_all()
path=BASE/'blender/grand_forest_sanctuary_v001.blend';bpy.ops.wm.save_as_mainfile(filepath=str(path))
report={'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'output':str(path),'roles_used':use,'source_ids':IDS,'court_dimensions_m':[36,32],'court_area_m2':1152,'previous_area_m2':288,'area_ratio':4,'player_height_m':player_height,'player_game_scale':1.20058629,'player_static_reference_only':True,'obstacle_islands':obstacle_islands,'objects':len(s.objects),'packed_images':sum(bool(im.packed_file) for im in bpy.data.images)}
(BASE/'reports/build_report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
print('SANCTUARY_BUILD_COMPLETE',flush=True)
