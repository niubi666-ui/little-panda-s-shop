import bpy,math,random,json
from pathlib import Path
from mathutils import Vector
B=Path('E:/ShopGame/source_assets/environments/shop');s=bpy.context.scene;R=random.Random(33)
collections={c.name:c for c in s.collection.children};active='Details'
def link(o,group=None):
 for c in list(o.users_collection):c.objects.unlink(o)
 collections[group or active].objects.link(o);return o
code=(B/'scripts/build_shop_v001.py').read_text(encoding='utf-8-sig');exec(code[code.index('def mat('):code.index('def texturemat(')]);exec(code[code.index('def box('):code.index('def prop(')])
wood=bpy.data.materials['Oak | grain'];iron=bpy.data.materials['Forged dark iron'];brass=bpy.data.materials['Antique brass'];cloth=bpy.data.materials['Forest green woven banner'];gold=bpy.data.materials['Embroidered ochre thread']
clays=[mat('Glazed ceramic '+str(i),c,.23) for i,c in enumerate([(.10,.16,.095),(.25,.10,.035),(.085,.125,.16),(.30,.20,.11)])]
label=mat('Jar parchment label',(.58,.43,.25),.85)
# Small lathed jars for the counter back shelf.
def jar(name,x,y,z,r,h,material):
 profile=[(r*.62,0),(r*.94,h*.08),(r,h*.3),(r*.93,h*.70),(r*.66,h*.85),(r*.60,h*.96),(r*.7,h)]
 verts=[];faces=[];N=16
 for rr,zz in profile:
  for i in range(N):
   a=i*2*math.pi/N;verts.append((x+rr*math.cos(a),y+rr*math.sin(a),z+zz))
 for k in range(len(profile)-1):
  for i in range(N):faces.append((k*N+i,k*N+(i+1)%N,(k+1)*N+(i+1)%N,(k+1)*N+i))
 faces.append(tuple(range(N-1,-1,-1)));faces.append(tuple((len(profile)-1)*N+i for i in range(N)))
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.materials.append(material)
 ob=bpy.data.objects.new(name,me);collections['Merchandise'].objects.link(ob)
 for p in me.polygons:p.use_smooth=True
 cylinder('Jar stopper',(x,y,z+h+.013),r*.73,.045,wood,16)
 box('Blank jar label',(x,y-r*.95,z+h*.48),(r*.85,.007,h*.27),label,.006)
for i in range(7):jar('Apothecary stock jar',1.28+i*.22,3.91,1.70,R.uniform(.065,.09),R.uniform(.19,.29),clays[i%4])
# One narrow top shelf with jars above the order board.
box('Upper stock shelf',(1.25,4.02,3.31),(2.45,.40,.09),wood,.02)
for i in range(6):jar('Upper stock jar',.31+i*.34,3.99,3.365,.09,R.uniform(.20,.30),clays[(i+1)%4])
# Round shield with metal rim and raised boss beside the weapon display.
o=cylinder('Round oak shield',(3.35,3.98,.77),.38,.10,wood,32);o.rotation_euler.x=math.pi/2
pts=[(3.35+.365*math.cos(i*math.pi/24),3.915,.77+.365*math.sin(i*math.pi/24)) for i in range(49)]
curve('Shield forged rim',pts,.025,iron)
bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=1,location=(3.35,3.86,.77));o=bpy.context.object;o.name='Shield boss';o.scale=(.11,.06,.11);o.data.materials.append(brass);link(o)
for a in [i*math.pi/4 for i in range(8)]:
 o=cylinder('Shield rivet',(3.35+.31*math.cos(a),3.90,.77+.31*math.sin(a)),.019,.018,brass,8);o.rotation_euler.x=math.pi/2
# Sharpen the distinct lattice silhouettes and preserve dark corners.
bpy.data.objects['Late afternoon sun'].data.angle=.010
for o in s.objects:
 if o.name.startswith('Afternoon window key'):o.data.size=.12
bpy.data.objects['Counter warm bounce'].data.energy=90
bpy.data.objects['Soft interior sky bounce'].data.energy=115
bpy.data.objects['Till lantern glow'].location=(-1.95,2.54,1.35)
bpy.data.objects['Display lantern glow'].location=(-1.14,-.5,1.22)
s.view_settings.exposure=.35
s.camera.data.ortho_scale=19.10;s.camera.rotation_euler=(Vector((0,.15,1.52))-s.camera.location).to_track_quat('-Z','Y').to_euler()
s.name='Shop_Interior_Art_v004'
s.render.resolution_x=1920;s.render.resolution_y=1200;s.cycles.samples=128
p=bpy.context.preferences.addons['cycles'].preferences;p.compute_device_type='OPTIX';p.refresh_devices()
for d in p.devices:d.use=d.type=='OPTIX'
s.cycles.device='GPU';s.render.filepath=str(B/'previews/shop_interior_v004.png')
# Save semantic source/placement manifest, not a gameplay placement configuration.
props=[]
for o in s.objects:
 if o.get('source_file'):
  props.append({'name':o.name,'source_object':o['source_object'],'location':list(o.location),'rotation_radians':list(o.rotation_euler),'scale':list(o.scale),'dimensions_m':list(o.dimensions)})
(B/'reports/shop_art_placement_manifest.json').write_text(json.dumps(props,indent=2))
# Validate the exact saved scene, including evaluated bevel geometry and packed textures.
dg=bpy.context.evaluated_depsgraph_get();triangles=0
for o in s.objects:
 if o.type in {'MESH','CURVE'}:
  ev=o.evaluated_get(dg);me=ev.to_mesh();triangles+=sum(len(p.vertices)-2 for p in me.polygons);ev.to_mesh_clear()
images=[{'name':im.name,'size':list(im.size),'packed':bool(im.packed_file)} for im in bpy.data.images if im.type=='IMAGE' and im.size[0]>0]
report={'scene':s.name,'objects':len(s.objects),'evaluated_triangles_including_presentation_helpers':triangles,'armatures':sum(o.type=='ARMATURE' for o in s.objects),'source_prop_instances':len(props),'source_types_used':len(set(p['source_object'] for p in props)),'texture_images':images,'missing_unpacked_images':[im['name'] for im in images if not im['packed']],'renderer':'Cycles / OptiX','resolution':[1920,1200],'samples':128,'godot_validated':False}
(B/'reports/shop_scene_validation.json').write_text(json.dumps(report,indent=2))
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(B/'blender/shop_interior_v004.blend'))
print('FINAL_SAVED',report['evaluated_triangles_including_presentation_helpers'],flush=True)
bpy.ops.render.render(write_still=True)
