"""Non-destructive Blender breeze review. Shared deformed prototype batches for dense flora.
Run in own background process. Original v003 remains untouched; no Godot scene replaced.
"""
import bpy,math,json,hashlib,collections,time
from pathlib import Path
from mathutils import Vector
assert bpy.app.background
R=Path(__file__).resolve().parents[1]
cfg=json.loads((R/'scripts/breeze_profile.json').read_text(encoding='utf-8'))
s=bpy.context.scene
assert Path(bpy.data.filepath).resolve()==Path(cfg['source']).resolve()
source_hash=hashlib.sha256(Path(cfg['source']).read_bytes()).hexdigest()
def coll(name):
 c=bpy.data.collections.new(name);s.collection.children.link(c);return c
protos=coll('WIND_INTERNAL_shared_sources');batches=coll('WIND_animated_flora_batches')
control=bpy.data.objects.new('BREEZE_controls',None);s.collection.objects.link(control)
control['strength']=1.0;control['description']='Natural breeze; 0=still, 1=review. Animation clock follows Blender timeline.'
control.id_properties_ui('strength').update(min=0,max=2.5,description='Wind strength; original geometry stays shared')
def geo_group(name,inputs):
 g=bpy.data.node_groups.new(name,'GeometryNodeTree')
 g.interface.new_socket(name='Geometry',in_out='INPUT',socket_type='NodeSocketGeometry')
 for name,typ,default in inputs:
  sk=g.interface.new_socket(name=name,in_out='INPUT',socket_type=typ);sk.default_value=default
 g.interface.new_socket(name='Geometry',in_out='OUTPUT',socket_type='NodeSocketGeometry')
 return g,g.nodes.new('NodeGroupInput'),g.nodes.new('NodeGroupOutput')
g,gi,go=geo_group('BREEZE_weighted_bend_v004',[('Amplitude','NodeSocketFloat',.05),('Phase','NodeSocketFloat',0.),('Direction','NodeSocketVector',(1,0,0))])
n=g.nodes;l=g.links
def put(inp,x):
 if hasattr(x,'is_output'):l.new(x,inp)
 else:inp.default_value=x
def mathnode(op,a,b=None):
 q=n.new('ShaderNodeMath');q.operation=op;put(q.inputs[0],a)
 if b is not None:put(q.inputs[1],b)
 return q.outputs[0]
tm=n.new('GeometryNodeInputSceneTime').outputs['Seconds']
wt=n.new('GeometryNodeInputNamedAttribute');wt.data_type='FLOAT';wt.inputs['Name'].default_value='breeze_weight'
w=mathnode('MULTIPLY',wt.outputs['Attribute'],wt.outputs['Attribute'])
phase=gi.outputs['Phase'];amp=gi.outputs['Amplitude']
clock=lambda f,p:mathnode('ADD',mathnode('MULTIPLY',tm,f),p)
wave=mathnode('ADD',mathnode('MULTIPLY',mathnode('SINE',clock(cfg['main_frequency'],phase)),.72),mathnode('MULTIPLY',mathnode('SINE',clock(cfg['secondary_frequency'],mathnode('MULTIPLY',phase,.71))),.28))
gust=mathnode('ADD',.78,mathnode('MULTIPLY',mathnode('SINE',clock(cfg['gust_frequency'],mathnode('MULTIPLY',phase,-.37))),.22))
pos=n.new('GeometryNodeInputPosition');dot=n.new('ShaderNodeVectorMath');dot.operation='DOT_PRODUCT';l.new(pos.outputs[0],dot.inputs[0]);dot.inputs[1].default_value=(1.8,2.2,2.5)
flutter=mathnode('MULTIPLY',mathnode('SINE',clock(cfg['flutter_frequency'],mathnode('ADD',phase,dot.outputs['Value']))),.10)
power=n.new('ShaderNodeValue');power.name='Breeze_strength';power.outputs[0].default_value=1
fc=power.outputs[0].driver_add('default_value');var=fc.driver.variables.new();var.name='strength';var.type='SINGLE_PROP';var.targets[0].id=control;var.targets[0].data_path='["strength"]';fc.driver.expression='strength'
amount=mathnode('MULTIPLY',mathnode('MULTIPLY',amp,w),mathnode('MULTIPLY',power.outputs[0],mathnode('ADD',mathnode('MULTIPLY',wave,gust),flutter)))
v=n.new('ShaderNodeVectorMath');v.operation='SCALE';l.new(gi.outputs['Direction'],v.inputs[0]);l.new(amount,v.inputs['Scale'])
sp=n.new('GeometryNodeSetPosition');l.new(gi.outputs['Geometry'],sp.inputs['Geometry']);l.new(v.outputs['Vector'],sp.inputs['Offset']);l.new(sp.outputs['Geometry'],go.inputs[0])
def setval(mod,name,value):
 # Blender 5.2 exposes modifier interfaces differently; node socket values are
 # stable and keep all bending logic in the single shared sub-group.
 if mod.node_group==g:
  wrap,wi,wo=geo_group('Breeze_settings_'+mod.id_data.name,[])
  bend=wrap.nodes.new('GeometryNodeGroup');bend.name='Breeze';bend.node_tree=g
  wrap.links.new(wi.outputs[0],bend.inputs[0]);wrap.links.new(bend.outputs[0],wo.inputs[0]);mod.node_group=wrap
 mod.node_group.nodes['Breeze'].inputs[name].default_value=value
def weight_attr(me,values):
 a=me.attributes.get('breeze_weight') or me.attributes.new('breeze_weight','FLOAT','POINT')
 a.data.foreach_set('value',values)
def isplant(o):
 if o.name.startswith('Fern_clump_'):return 'fern'
 if o.name.startswith('White_meadow_flower_spray_'):return 'bellflower'
 if o.get('asset_role') in ['white_flower','purple_flower']:return 'flower'
 return None
original=list(s.objects);plants=[o for o in original if o.type=='MESH' and isplant(o)]
crown=[o for o in original if o.type=='MESH' and '__BakedCrownCluster_' in o.name]
whole={};by_mesh={};source_sets=collections.defaultdict(list)
for o in plants:
 kind=isplant(o);key=o.name.rsplit('_',1)[0] if kind!='flower' else o.name
 whole.setdefault(key,[]).append(o)
for parts in whole.values():
 height=max(v.co.z for o in parts for v in o.data.vertices)
 radius=max(math.hypot(v.co.x,v.co.y) for o in parts for v in o.data.vertices)
 for o in parts:
  if o.data.name in by_mesh:continue
  kind=isplant(o);by_mesh[o.data.name]=(o.data,height,radius,kind)
  vals=[]
  for vtx in o.data.vertices:
   p=vtx.co;z=max(0,p.z)/max(height,1e-6)
   weight=z if kind!='fern' else max(z*.60,math.hypot(p.x,p.y)/max(radius,1e-6)*.96)*min(1,max(0,p.z)/.10)
   vals.append(min(1,max(0,weight)))
  weight_attr(o.data,vals)
# All companion parts use the same whole-plant normalization and bucket.
direction=Vector(cfg['wind_direction']).normalized();nb=cfg['direction_buckets'];np=cfg['phase_buckets']
for o in plants:
 local=o.matrix_world.to_3x3().inverted()@direction
 angle=math.atan2(local.y,local.x);d=int(round(angle/math.tau*nb))%nb
 p=o.matrix_world.translation;phase=(p.x*.22+p.y*.15)%math.tau;k=int(phase/math.tau*np)%np
 source_sets[(o.data.name,d,k)].append(o)
source_objects={}
for name,(me,h,r,kind) in by_mesh.items():
 o=bpy.data.objects.new('WIND_SOURCE_'+name,me);protos.objects.link(o);o.hide_render=True;o.hide_set(True);source_objects[name]=o
def objinfo(nodes,links,obj):
 q=nodes.new('GeometryNodeObjectInfo');q.transform_space='ORIGINAL';q.inputs['Object'].default_value=obj;q.inputs['As Instance'].default_value=False
 return q.outputs['Geometry']
for (name,d,k),obs in source_sets.items():
 me,h,r,kind=by_mesh[name]
 pt=bpy.data.meshes.new('Breeze_points_'+name+'_'+str(d)+'_'+str(k));pt.from_pydata([o.matrix_world.translation for o in obs],[],[])
 rot=pt.attributes.new('breeze_rotation','FLOAT_VECTOR','POINT');sca=pt.attributes.new('breeze_scale','FLOAT_VECTOR','POINT')
 rot.data.foreach_set('vector',[f for o in obs for f in o.matrix_world.to_euler()]);sca.data.foreach_set('vector',[f for o in obs for f in o.matrix_world.to_scale()])
 draw=bpy.data.objects.new('Breeze_'+name+'_'+str(d)+'_'+str(k),pt);batches.objects.link(draw)
 ng,ing,outg=geo_group(draw.name,[]);nodes=ng.nodes;links=ng.links
 deform=nodes.new('GeometryNodeGroup');deform.node_tree=g;links.new(objinfo(nodes,links,source_objects[name]),deform.inputs['Geometry'])
 deform.inputs['Amplitude'].default_value=cfg[kind+'_amplitude']*(h if kind=='flower' else 1)
 deform.inputs['Phase'].default_value=(k+.5)/np*math.tau
 deform.inputs['Direction'].default_value=(math.cos(d/nb*math.tau),math.sin(d/nb*math.tau),0)
 inst=nodes.new('GeometryNodeInstanceOnPoints');links.new(ing.outputs['Geometry'],inst.inputs['Points']);links.new(deform.outputs[0],inst.inputs['Instance'])
 for attr_name,input_name in [('breeze_rotation','Rotation'),('breeze_scale','Scale')]:
  q=nodes.new('GeometryNodeInputNamedAttribute');q.data_type='FLOAT_VECTOR';q.inputs['Name'].default_value=attr_name;links.new(q.outputs['Attribute'],inst.inputs[input_name])
 links.new(inst.outputs[0],outg.inputs[0]);m=draw.modifiers.new('Shared prototype wind','NODES');m.node_group=ng
 for o in obs:o.hide_render=True;o.hide_set(True);o['breeze_original_retained']=True
done=set()
for o in crown:
 if o.data.name not in done:
  a=o.data.color_attributes.get('wind_rgba');assert a
  weight_attr(o.data,[x.color[0] for x in a.data]);done.add(o.data.name)
 m=o.modifiers.new('Gentle canopy microbend','NODES');m.node_group=g
 local=o.matrix_world.to_3x3().inverted()@direction
 p=o.matrix_world.translation
 setval(m,'Amplitude',cfg['canopy_amplitude']);setval(m,'Phase',(p.x*.22+p.y*.15)%math.tau);setval(m,'Direction',local.normalized())
# A separate field on the shadow proxy coordinates softly drifting dappled light.
o=s.objects['LIGHTING_ONLY_overhead_leaf_shadows'];weight_attr(o.data,[1.0]*len(o.data.vertices))
m=o.modifiers.new('Soft canopy shadow drift','NODES');m.node_group=g
setval(m,'Amplitude',cfg['shadow_amplitude']);setval(m,'Phase',.75);setval(m,'Direction',direction);assert not o.visible_camera
s.render.fps=cfg['fps'];s.frame_start=1;s.frame_end=cfg['fps']*cfg['seconds'];s.frame_set(1)
s.camera=s.objects['Camera_Panorama']
def camera(name,loc,target,width):
 d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=width;d.clip_end=250;return o
camera('Camera_Breeze_Flowers',(8,-1,5.5),(4.7,6.2,.65),5.5)
camera('Camera_Breeze_Canopy',(0,-15,19),(-12.4,7.5,7.1),14)
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.overlay.show_overlays=False;area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL'
s['breeze_stage']='v004 visual review: shared deformed flora prototypes, canopy vertex bend, shadow proxy drift; not integrated into Godot game'
s['breeze_source_sha256']=source_hash
s.render.engine='CYCLES';s.cycles.device='GPU';s.cycles.samples=cfg['render_samples'];s.cycles.use_denoising=True;s.render.use_persistent_data=True
s.render.resolution_x=cfg['render_resolution'][0];s.render.resolution_y=cfg['render_resolution'][1];s.render.resolution_percentage=100
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.refresh_devices()
for dev in prefs.devices:dev.use=dev.type=='OPTIX'
out=R/'blender/grand_forest_sanctuary_v004_breeze.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(out))
report={'source':cfg['source'],'source_sha256':source_hash,'output':str(out),'flora_objects':len(plants),'shared_flora_meshes':len(by_mesh),'deformed_instance_batches':len(source_sets),'canopy_modules':len(crown),'canopy_unique_meshes':len(done),'shadow_proxy_animated':True,'static':'Trunks, roots, architecture, moss and grounded litter retain original shape. No topology changes. Original flora retained hidden, replaced for drawing by instanced deformation batches.','limits':'Blender prototype batches quantize plant wind direction into 8 sectors and phase into 3 cohorts to retain instancing; separate Godot shader uses continuous instance/world phase. Not a runtime performance claim.','profile':cfg}
(R/'reports/breeze_build.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
assert hashlib.sha256(Path(cfg['source']).read_bytes()).hexdigest()==source_hash
print('BREEZE_BUILT',json.dumps(report),flush=True)
# One still verifies preservation of original materials and instances before animation.
s.camera=s.objects['Camera_Breeze_Flowers'];s.render.filepath=str(R/'previews/flowers_check.png')
start=time.perf_counter();bpy.ops.render.render(write_still=True);print('BREEZE_FIRST_RENDER_SECONDS',time.perf_counter()-start,flush=True)
