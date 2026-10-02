import bpy,json,math
from pathlib import Path
from mathutils import Vector,Matrix
BASE=Path('E:/ShopGame/source_assets/environments/dungeon/grand_forest_sanctuary/v001')
s=bpy.context.scene
objects=[o for o in s.objects if o.type=='MESH']
report={'source':bpy.data.filepath,'objects':[],'images':[]}
for image in bpy.data.images:
    report['images'].append({'name':image.name,'size':list(image.size),'packed':bool(image.packed_file),'path':image.filepath})
for i,o in enumerate(objects):
    report['objects'].append({'index':i,'name':o.name,'dimensions':list(o.dimensions),'rotation':list(o.rotation_euler),'scale':list(o.scale),'vertices':len(o.data.vertices),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'materials':[m.name for m in o.data.materials if m],'uv_layers':[u.name for u in o.data.uv_layers]})
(BASE/'reports/source_inventory.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
for o in s.objects:o.hide_render=True
world=bpy.data.worlds.new('Catalog neutral world');world.use_nodes=True
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.32,.37,.43,1);bg.inputs['Strength'].default_value=.5;s.world=world
for name,loc,power,size in [('Key',(3,-4,6),450,4),('Fill',(-3,-1,3),180,4)]:
    light=bpy.data.lights.new(name,'AREA');light.energy=power;light.shape='DISK';light.size=size
    obj=bpy.data.objects.new(name,light);s.collection.objects.link(obj);obj.location=loc;obj.rotation_euler=(-obj.location).to_track_quat('-Z','Y').to_euler()
camdata=bpy.data.cameras.new('Audit camera');cam=bpy.data.objects.new('Audit camera',camdata);s.collection.objects.link(cam)
cam.location=(4,-3.4,2.8);cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();camdata.type='ORTHO';camdata.ortho_scale=2.8;s.camera=cam
try:s.render.engine='CYCLES'
except TypeError:raise
s.cycles.samples=12;s.cycles.use_denoising=True
pref=bpy.context.preferences.addons['cycles'].preferences
if 'OPTIX' in [p[0] for p in pref.get_device_types(bpy.context)]:
    pref.compute_device_type='OPTIX';pref.refresh_devices()
    for device in pref.devices:device.use=device.type=='OPTIX'
    s.cycles.device='GPU'
s.render.resolution_x=384;s.render.resolution_y=384;s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG';s.render.film_transparent=False
for i,o in enumerate(objects):
    worldmat=o.matrix_world.copy();points=[worldmat@Vector(c) for c in o.bound_box]
    center=sum(points,Vector())/8;scale=2/max(o.dimensions)
    o.matrix_world=Matrix.Scale(scale,4)@Matrix.Translation(-center)@worldmat
    o.hide_render=False;s.render.filepath=str(BASE/'previews/catalog'/f'{i:02d}.png')
    bpy.ops.render.render(write_still=True);o.hide_render=True
print('SOURCE_AUDIT_COMPLETE',flush=True)

