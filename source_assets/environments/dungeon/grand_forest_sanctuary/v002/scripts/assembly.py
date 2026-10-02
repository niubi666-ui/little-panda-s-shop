"""Art-only assembly, loaded after source normalization in build_sanctuary.py."""
# All source instances share mesh data. Metres; Z up, shrine north (+Y).
groundmat=kit.mats['forest_ground'];gn=groundmat.node_tree.nodes;gl=groundmat.node_tree.links;gp=next(n for n in gn if n.type=='BSDF_PRINCIPLED')
oldcolor=gp.inputs['Base Color'].links[0].from_socket;tint=gn.new('ShaderNodeMixRGB');tint.blend_type='MULTIPLY';tint.inputs[0].default_value=.7;tint.inputs[2].default_value=(.53,.70,.32,1);gl.new(oldcolor,tint.inputs[1]);gl.new(tint.outputs[0],gp.inputs['Base Color'])
kit.box('Continuous_forest_earth',(0,0,-.26),(100,100,.28),'forest_ground',0,'Forest_Ground')
kit.box('Court_foundation_36x32',(0,0,-.19),(36,32,.20),'mortar',0,'Ground')
def pave(label,bounds,nx,ny):
 x0,x1,y0,y1=bounds;dx=(x1-x0)/nx;dy=(y1-y0)/ny
 for j in range(ny):
  for i in range(nx):
   turn=rng.randrange(4);dims=(dy+.025,dx+.025,.15) if turn%2 else (dx+.025,dy+.025,.15)
   asset('paving',f'{label}_{i}_{j}',(x0+(i+.5)*dx,y0+(j+.5)*dy,-.115),dim=dims,angle=math.pi/2*turn,group='Ground')
pave('Court_flagstones',(-18,18,-16,16),12,12)
pave('South_approach',(-2.6,2.6,-30,-16),2,5)
pave('West_lower_path',(-32,-18,-3.5,1),5,2)
pave('West_upper_path',(-32,-15,12.2,16),6,2)
pave('East_double_pillar_road',(18,34,6.4,12.8),6,2)
roundels=[(-6.4,2.4,3.8),(8.2,1.6,3.85),(.2,-8.5,3.9)]
for i,(x,y,r) in enumerate(roundels):
 asset('roundel',f'Six_leaf_medallion_{i}',(x,y,.013),dim=(2*r,2*r,.062),angle=.15,group='Ground')
 # Small real stone tesserae give the outer inlay the segmented relief of the concept.
 for band,(r0,r1) in enumerate([(.865,.904),(.927,.972)]):
  for k in range(96):
   a=math.tau*k/96+.002;b=math.tau*(k+1)/96-.002
   verts=[(x+rr*r*math.cos(t),y+rr*r*math.sin(t),.088+rng.uniform(-.001,.001)) for rr,t in [(r0,a),(r1,a),(r1,b),(r0,b)]]
   kit.mesh(f'Medallion_{i}_tessera_{band}_{k}',verts,[(0,1,2,3)],'mosaic' if k%8==0 else 'floor_'+str(rng.randrange(8)),'Ground')

wall_sites=[];lamp_sites=[];plant_sites=[];obstacle_islands=[]
def wall(label,a,b,height=1.1,lantern=False):
 dx=b[0]-a[0];dy=b[1]-a[1];length=math.hypot(dx,dy);angle=math.atan2(dy,dx)
 n=max(1,round(length/3.4))
 for i in range(n):
  t=(i+.5)/n;x=a[0]+dx*t;y=a[1]+dy*t
  asset('low_wall',f'{label}_course_{i}',(x,y,.018),dim=(length/n,.62,height),angle=angle)
 for i in range(n+1):
  t=i/n;x=a[0]+dx*t;y=a[1]+dy*t
  asset('pier',f'{label}_pier_{i}',(x,y,.02),dim=(.70,.70,height+.35))
  if lantern and i%2==0:lamp_sites.append((x,y,height+.38))
 for i in range(max(6,int(length*8))):
  t=rng.uniform(.025,.975);side=rng.choice([-1,1])*rng.uniform(.35,1.30)
  plant_sites.append((a[0]+dx*t-dy/length*side,a[1]+dy*t+dx/length*side))
 wall_sites.append((a,b))
# Segmented enclosure with four intentional openings; two independent west paths.
boundary=[((-2.6,-16),(-12,-16)),((-12,-16),(-18,-10)),((-18,-10),(-18,-3.5)),
 ((-18,1),(-18,11.8)),((-14,16),(-3.6,16)),((3.8,16),(14,16)),((14,16),(18,12.8)),
 ((18,6.4),(18,-9)),((18,-9),(12,-16)),((12,-16),(2.6,-16))]
for i,(a,b) in enumerate(boundary):wall('Boundary_'+str(i),a,b,1.08,i%2==0)
wall('South_entry_west',(-2.6,-16),(-2.6,-21),.83,True)
wall('South_entry_east',(2.6,-16),(2.6,-21),.83,True)
for name,a,b in [('West_lower',(-23,-3.5),(-18,-3.5)),('West_upper',(-23,16),(-15,16))]:wall(name,a,b,.8)
# Three low cover gardens rather than a forest of unrelated walls.
for name,a,b,c in [('West_cover',(-11.2,-6.3),(-6.5,-6.3),(-11.2,-3.6)),
                    ('Centre_cover',(1.0,5.9),(5.6,5.9),(5.6,8.0)),
                    ('East_cover',(9.5,-8.7),(14,-8.7),(14,-5.7))]:
 wall(name,a,b,1.02,True);wall(name+'_return',b,c,.78)
 obstacle_islands.append({'id':name,'a':a,'b':b,'return':c})
 # Dense garden behind each wall, with multiple leaf sizes.
 for j in range(35):plant_sites.append((rng.uniform(min(a[0],b[0])+.1,max(a[0],b[0])-.1),a[1]+rng.uniform(.35,1.55)))

# Supplied textured shrine, correct orientation and non-stretched guardian statue.
asset('shrine','North_Guardian_Shrine',(0,13.45,.02),dim=(5.1,1.95,6.15))
kit.box('Shrine_recess_stone_back',(0,14.05,3.0),(3.0,.16,4.5),'stone_dark',.02)
asset('statue','Robed_Guardian',(0,12.94,.67),height=3.8,group='Decor')
asset('steps','Shrine_approach_steps',(0,11.97,-.12),dim=(3.95,1.9,.85))
for x in [-3.15,3.15]:
 asset('pier','Shrine_lamp_pedestal',(x,12.0,.02),dim=(.88,.88,1.5));lamp_sites.append((x,12,1.54))
 asset('flowerpot','Shrine_offering_pot',(x,10.9,.03),height=.98,group='Decor')
 for j in range(25):plant_sites.append((x+rng.uniform(-1,1),12+rng.uniform(-.8,2.3)))
for x in [-2.3,2.3]:
 asset('ivy','Shrine_trailing_ivy',(x,12.57,2.65),height=3.35,group='Vegetation')

# East exit: only two monumental piers flanking the traversable road (7 m centres).
gate_positions=[(17.4,6.35),(17.4,13.15)]
for i,(x,y) in enumerate(gate_positions):
 asset('pier','East_gateway_tall_pillar_'+str(i),(x,y,.03),dim=(1.45,1.45,5.8))
 kit.banner('East_gateway_leaf_standard_'+str(i),(x,y-.66,5.23),.87,3.25)
 # A second face reads from the reverse east camera.
 kit.banner('East_gateway_reverse_standard_'+str(i),(x+.66,y,5.23),.87,3.25,math.pi/2)
 asset('ivy','Gateway_climbing_ivy_'+str(i),(x-.38,y-.57,1.95),height=3.8,group='Vegetation')
 asset('pier','Gateway_lamp_plinth_'+str(i),(x-1.15,y-.45,.03),dim=(.76,.76,1.3));lamp_sites.append((x-1.15,y-.45,1.36))
 for j in range(40):
  a=rng.uniform(0,math.tau);r=rng.uniform(.8,1.8);plant_sites.append((x+math.cos(a)*r,y+math.sin(a)*r))

# Textured bronze lamps from approved courtyard (packed source reused read-only).
OLD=Path('E:/ShopGame/source_assets/environments/dungeon/forest_courtyard/v001/blender/forest_courtyard_item2_v001.blend')
with bpy.data.libraries.load(str(OLD),link=False) as (src,dst):dst.objects=['Shrine_Offering_Candle']
lamp_proto=dst.objects[0];lamp_mesh=lamp_proto.data
lo=min(v.co.z for v in lamp_mesh.vertices);hi=max(v.co.z for v in lamp_mesh.vertices)
for i,(x,y,z) in enumerate(lamp_sites):
 o=bpy.data.objects.new('Bronze_votive_'+str(i),lamp_mesh);kit.collection('Decor').objects.link(o);o.scale=(.64/(hi-lo),)*3;o.location=(x,y,z-lo*o.scale.z)
 kit.light('Votive_warm_light_'+str(i),'POINT',(x,y,z+.30),(1,.50,.13),32,.14)
bpy.data.objects.remove(lamp_proto,do_unlink=True)

# Approved v005 sacred oak. Preserve all mesh/material/UV content and source transforms.
TREE=Path('E:/ShopGame/source_assets/environments/dungeon/sunlit_forest_court/tree_foliage_v005/blender/sacred_oak_balanced_v005.blend')
with bpy.data.libraries.load(str(TREE),link=False) as (src,dst):
 dst.objects=[n for n in src.objects if n=='SacredOak_Trunk_Preserved' or n.startswith('BakedCrownCluster_')]
tree_parts=[o for o in dst.objects if o]
# Unlinked library objects have no evaluated world matrix. These are unparented;
# their authored local TRS matrix is the correct source transform.
assert all(o.parent is None for o in tree_parts)
tree_matrices={o:o.matrix_basis.copy() for o in tree_parts}
assert len(tree_parts)==62,len(tree_parts)
def oak(name,loc,scale,angle):
 root=kit.root(name,loc,'Trees');root.scale=(scale,)*3;root.rotation_euler.z=angle
 for source in tree_parts:
  o=bpy.data.objects.new(name+'__'+source.name,source.data);kit.collection('Trees').objects.link(o);o.parent=root;o.matrix_basis=tree_matrices[source]
  o['tree_source']='sacred_oak_balanced_v005';o['tree_triangles']=29768
 return root
hero=oak('Hero_Sacred_Oak_v005',(-12.7,7.5,-.08),1.28,-.22)
forest_positions=[(-24,6,1.05),(-24,20,1.2),(-14,25,1.2),(-3,25,1.0),(8,26,1.2),(22,24,1.15),(30,17,1.0),(29,2,1.1),(26,-12,1.1),(-25,-11,1.0),(-24,-23,.9),(23,-25,.95)]
for i,(x,y,scale) in enumerate(forest_positions):oak('Forest_oak_'+str(i),(x,y,-.18),scale,rng.uniform(0,math.tau))
for o in tree_parts:bpy.data.objects.remove(o,do_unlink=True)
# Root garden: irregular arcs keep the tree exposed, with a soft transition to paving.
for i in range(190):
 a=rng.uniform(0,math.tau);r=rng.uniform(2.2,5.4);plant_sites.append((-12.7+math.cos(a)*r,7.5+math.sin(a)*r))
for i,(x,y,scale) in enumerate(forest_positions):
 for j in range(26):
  a=rng.uniform(0,math.tau);r=rng.uniform(1,5);plant_sites.append((x+math.cos(a)*r,y+math.sin(a)*r))
# Continuous understory outside the court: conceal bare rectangular construction edges.
for j in range(1250):
 x=rng.uniform(-31,31);y=rng.uniform(-25,28)
 if abs(x)<18.5 and -16.5<y<17:continue
 if (abs(x)<3.1 and y<-14) or (x>15 and 6<y<13.5) or (x<-16 and (-4<y<1.5 or 11.7<y<16.5)):continue
 plant_sites.append((x,y))

# Reusable fern geometry: six variants; duplicated mesh blocks, never rebuilt per plant.
fern_meshes=[]
for j in range(6):
 root=fern(kit,'Fern_module_'+str(j),(0,0,0),1.0,292000+j)
 bpy.context.view_layer.update()
 for child in list(root.children):
  if child.type=='MESH':fern_meshes.append((child.data,child.matrix_world.copy()))
  bpy.data.objects.remove(child,do_unlink=True)
 bpy.data.objects.remove(root,do_unlink=True)
for i,(x,y) in enumerate(plant_sites):
 # Keep east gate centre and the south entry clear.
 if 15.8<x<27 and 7.6<y<11.9:continue
 kind='white_flower' if rng.random()<.83 else 'purple_flower'
 asset(kind,'Flower_drift_'+str(i),(x,y,.045),height=rng.uniform(.43,.85),angle=rng.uniform(0,math.tau),group='Vegetation')
 if i%2==0:
  variant=(i//2)%6;loc=(x+rng.uniform(-.35,.35),y+rng.uniform(-.35,.35),.04);rot=rng.uniform(0,math.tau);sc=rng.uniform(.75,1.2)
  for part in range(2):
   me,m=fern_meshes[variant*2+part];o=bpy.data.objects.new('Fern_clump_'+str(i)+'_'+str(part),me);kit.collection('Vegetation').objects.link(o)
   o.location=loc;o.rotation_euler.z=rot;o.scale=(sc,)*3
 if i%4==0:
  asset('moss_patch','Garden_moss_'+str(i),(x,y,.015),dim=(1.0,.85,.055),angle=rng.uniform(0,math.tau),group='Ground_Details')
# Natural rocks around boundary and roots, deliberately varied orientation and proportion.
for i in range(90):
 if i<22:
  a=rng.uniform(0,math.tau);r=rng.uniform(3.5,5.4);x=-12.7+math.cos(a)*r;y=7.5+math.sin(a)*r
 else:
  a=rng.uniform(0,math.tau);x=math.cos(a)*rng.uniform(19,22);y=math.sin(a)*rng.uniform(17,20)
 if (abs(x)<4 and y<-14) or (x>15 and 6<y<14) or (x<-16 and (-4<y<1.5 or 11<y<17)):continue
 w=rng.uniform(.65,2.4);asset(rng.choice(['rock_flat','rock_medium','rock_large']),'Mossy_limestone_'+str(i),(x,y,-.08),dim=(w,w*rng.uniform(.65,.95),w*rng.uniform(.35,.6)),angle=rng.uniform(0,math.tau),group='Decor')

# Broken islands of creeping moss; thin heights avoid floating turf rugs.
for i in range(420):
 x=rng.uniform(-18,18);y=rng.uniform(-16,16)
 if any(math.hypot(x-cx,y-cy)<r*.84 for cx,cy,r in roundels):continue
 w=rng.uniform(.24,1.25)
 asset(rng.choice(['moss_seam','moss_patch']),'Flagstone_moss_'+str(i),(x,y,.047),dim=(w,w*rng.uniform(.55,1.4),.018),angle=rng.uniform(0,math.tau),group='Ground_Details')
for i in range(70):asset('litter','Fallen_leaves_'+str(i),(rng.uniform(-17,17),rng.uniform(-15,15),.046),dim=(.32,.3,.025),angle=rng.uniform(0,math.tau),group='Ground_Details')
# Fine leaf litter and seam shoots at true leaf size, not large floating moss patches.
groundgeo=_Geometry()
for i in range(13500):
 x=rng.uniform(-18,18);y=rng.uniform(-16,16)
 if any(math.hypot(x-cx,y-cy)<r*.90 for cx,cy,r in roundels) and rng.random()<.85:continue
 a=rng.uniform(0,math.tau);length=rng.uniform(.035,.105)
 _leaf(groundgeo,(x,y,.071),(math.cos(a),math.sin(a),.03),(0,0,1),length,length*.58,rng.randrange(5))
leaflitter=kit.mesh('Small_fallen_oak_leaves',groundgeo.verts,groundgeo.faces,'leaf_0','Ground_Details')
for j in range(1,5):leaflitter.data.materials.append(kit.mats['leaf_'+str(j)])
for p,mi in zip(leaflitter.data.polygons,groundgeo.materials):p.material_index=mi
# Raised white flower spikes read against the darker fern carpet at gameplay distance.
flower_meshes=[]
from room_foliage import _tube
def bellflower_module(j):
 stems=_Geometry();leaves=_Geometry();bells=_Geometry()
 for stem in range(13):
  x=rng.uniform(-.48,.48);y=rng.uniform(-.38,.38);h=rng.uniform(.4,.77);a=rng.uniform(0,math.tau)
  base=Vector((x,y,0));axis=Vector((math.cos(a),math.sin(a),0))
  _tube(stems,[base,base+Vector((0,0,h*.65)),base+axis*.12+Vector((0,0,h))],[.008,.005,.002],5)
  for k in range(4):
   t=.45+k*.145;side=axis if k%2 else -axis;center=base+Vector((0,0,h*t))+side*(.07+.025*k)
   _tube(stems,[base+Vector((0,0,h*t)),center+Vector((0,0,.02))],[.003,.0015],4)
   radius=rng.uniform(.032,.052);offset=len(bells.verts);verts=[]
   # Hanging cup profile, opening faces down; rounded shoulders and scalloped lip.
   for row,(rr,z) in enumerate([(0.18,.058),(.78,.045),(1.,.012),(.81,-.029),(1.12,-.040)]):
    for q in range(10):
     theta=math.tau*q/10;verts.append(center+Vector((math.cos(theta)*radius*rr,math.sin(theta)*radius*rr,z+(math.cos(theta*5)*.007 if row==4 else 0))))
   faces=[(row*10+q,row*10+(q+1)%10,(row+1)*10+(q+1)%10,(row+1)*10+q) for row in range(4) for q in range(10)]
   bells.add(verts,faces,0)
  for k in range(3):
   a2=a+k*2.4;_leaf(leaves,base+Vector((0,0,.03)),(math.cos(a2),math.sin(a2),.75),(0,0,1),rng.uniform(.2,.4),.10,k%4)
 root=kit.root('Bellflower_module_'+str(j),group='Flora')
 stems.mesh(kit,'Bellflower_stems',root,['leaf_0']);leaves.mesh(kit,'Bellflower_leaves',root,['leaf_0','leaf_1','leaf_2','leaf_3']);bells.mesh(kit,'Ivory_hanging_bells',root,['flower_white'],smooth=True)
 return root
for j in range(3):
 root=bellflower_module(j)
 parts=[]
 for child in list(root.children):
  if child.type=='MESH':parts.append(child.data)
  if child.type=='MESH' and j<2:
   for mi,mat in enumerate(list(child.data.materials)):
    if mat==kit.mats['flower_purple']:child.data.materials[mi]=kit.mats['flower_white']
  bpy.data.objects.remove(child,do_unlink=True)
 bpy.data.objects.remove(root,do_unlink=True);flower_meshes.append(parts)
for i,(x,y) in enumerate(plant_sites):
 if i%4 or (15.8<x<27 and 7.6<y<11.9):continue
 rot=rng.uniform(0,math.tau);scale=rng.uniform(.95,1.45)
 for j,me in enumerate(flower_meshes[(i//4)%3]):
  ob=bpy.data.objects.new('White_meadow_flower_spray_'+str(i)+'_'+str(j),me);kit.collection('Vegetation').objects.link(ob);ob.location=(x,y,.12);ob.rotation_euler.z=rot;ob.scale=(scale,)*3
for i,(x,y,w) in enumerate([(-8.3,9,.9),(-7.5,9.2,.72),(-8.3,2.1,.83),(4.8,7.1,.85)]):asset('crate','Loose_crate_'+str(i),(x,y,.06),dim=(w,w,w),angle=rng.uniform(-.3,.3),group='Interactive_Props')
for i,(x,y) in enumerate([(-9.4,9.4),(-7,-5.2),(4.7,5.0),(13.3,-7.7)]):asset('barrel','Loose_barrel_'+str(i),(x,y,.05),height=.97,group='Interactive_Props')
asset('chest','Searchable_treasure_chest',(12.3,-7.7,.045),height=1.02,angle=-.12,group='Interactive_Props')
asset('mushrooms','Root_mushrooms',(-10.8,5.1,.05),height=.43,group='Vegetation')
exec((BASE/'scripts/player_reference.py').read_text(encoding='utf-8'))

# High shadow branches are a labelled lighting rig, excluded from camera rays.
geo=_Geometry()
for xx in [-24,-17,-10,-3,4,11]:
 for yy in [-22,-15,-8,-1,6,13]:
  center=(xx+rng.uniform(-1,1),yy+rng.uniform(-1,1),10)
  for j in range(650):
   pos=Vector(center)+Vector((rng.gauss(0,1.7),rng.gauss(0,1.7),rng.gauss(0,.45)));a=rng.uniform(0,math.tau)
   _leaf(geo,pos,(math.cos(a),math.sin(a),rng.uniform(-.3,.3)),(0,0,1),rng.uniform(.23,.49),rng.uniform(.11,.25),0)
o=kit.mesh('LIGHTING_ONLY_overhead_leaf_shadows',geo.verts,geo.faces,'leaf_1','Lighting_Gobos');o.visible_camera=False
o['purpose']='Art lighting gobo; not a gameplay obstacle or runtime asset'
sun=kit.light('Warm_golden_sun','SUN',(-15,-10,22),(1,.72,.36),5.0,target=(0,2,0));sun.data.angle=.012
kit.light('Broad_cool_skylight','AREA',(3,-8,20),(.62,.78,1),1000,22,(0,1,0))
kit.light('Warm_tree_bounce','AREA',(-14,-2,14),(1,.83,.59),1450,10,(-8,5,3))
world=bpy.data.worlds.new('Soft_forest_sky');world.use_nodes=True
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(.45,.60,.79,1);bg.inputs[1].default_value=.28;s.world=world
fog=bpy.data.materials.new('Fine_golden_forest_air');fog.use_nodes=True;n=fog.node_tree.nodes;n.clear();out=n.new('ShaderNodeOutputMaterial');v=n.new('ShaderNodeVolumePrincipled');v.inputs['Density'].default_value=.0028;v.inputs['Anisotropy'].default_value=.45;fog.node_tree.links.new(v.outputs[0],out.inputs['Volume'])
kit.box('Atmosphere_bounds',(0,0,13),(100,100,35),fog,0,'Atmosphere')
def camera(name,loc,target,width):
 d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);kit.collection('Cameras').objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=width;d.clip_end=250;return o
s.camera=camera('Camera_Panorama',(7,-34,31),(0,1.5,1.4),47)
camera('Camera_Gameplay',(7,-18,24),(0,2,0),26)
camera('Camera_East_Gateway',(24,9.75,19),(-2,5,1),41)
camera('Camera_North_Reverse',(-5,34,29),(0,0,0),43)
camera('Camera_Shrine_Detail',(8,-6,12),(0,12,2.4),17)
s.render.engine='CYCLES';s.cycles.samples=144;s.cycles.use_denoising=True;s.cycles.max_bounces=8;s.cycles.transparent_max_bounces=16
pref=bpy.context.preferences.addons['cycles'].preferences;pref.compute_device_type='OPTIX';pref.refresh_devices()
for d in pref.devices:d.use=d.type=='OPTIX'
s.cycles.device='GPU';s.render.resolution_x=2560;s.render.resolution_y=1600;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG'
s.view_settings.exposure=.65
try:s.view_settings.look='AgX - Medium High Contrast'
except TypeError:pass
s['art_stage']='Blender concept reconstruction, pending user visual review; no Godot integration'
s['court_dimensions_m']=[36.,32.];s['court_area_m2']=1152.;s['area_ratio']=4.;s['tree_version']='tree_foliage_v005';s['player_height_m']=player_height
s['layout_authority']='reference/01-panorama-east-gateway.png';s['west_paths']=2;s['east_gateway_clear_width_m']=5.5
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.overlay.show_overlays=False;area.spaces.active.shading.type='MATERIAL'
exec((BASE/'scripts/refinements.py').read_text(encoding='utf-8'))
for im in bpy.data.images:
 if im.packed_file:
  data=bytes(im.packed_file.data);ext='.png' if data.startswith(b'\x89PNG') else '.jpg';path=BASE/'textures'/(im.name+ext);path.write_bytes(data);im.unpack(method='REMOVE');im.filepath=str(path);im.reload();im.pack()
bpy.ops.file.pack_all()
path=BASE/'blender/grand_forest_sanctuary_v002.blend';bpy.ops.wm.save_as_mainfile(filepath=str(path))
report={'output':str(path),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'tree_source':str(TREE),'tree_sha256':hashlib.sha256(TREE.read_bytes()).hexdigest(),'court_m':[36,32],'area_m2':1152,'previous_area_m2':288,'ratio':4,'player_height_m':player_height,'objects':len(s.objects),'base_triangles_instanced':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in s.objects if o.type=='MESH'),'source_roles_used':use,'roundels':roundels,'obstacle_islands':obstacle_islands,'west_exits':2,'godot_changed':False,'status':'pending visual review'}
(BASE/'reports/build_report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
print('SANCTUARY_V002_BUILD_COMPLETE',flush=True)
