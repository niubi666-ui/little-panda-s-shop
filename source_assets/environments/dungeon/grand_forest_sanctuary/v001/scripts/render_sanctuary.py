import bpy,sys,json,time
from pathlib import Path
BASE=Path(bpy.data.filepath).parent.parent;s=bpy.context.scene
mode=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'draft'
s.cycles.use_denoising=True
if mode=='draft':s.render.resolution_x=1280;s.render.resolution_y=720;s.cycles.samples=40
elif mode=='hero':s.render.resolution_x=2560;s.render.resolution_y=1440;s.cycles.samples=160
elif mode=='topdown':
    s.camera=bpy.data.objects['Camera_Whole_Room_Topdown'];s.render.resolution_x=1800;s.render.resolution_y=1800;s.cycles.samples=64
    bpy.data.collections['Layout_Review_Guides'].hide_viewport=False;bpy.data.collections['Layout_Review_Guides'].hide_render=False
    bpy.data.collections['Trees'].hide_render=True
    bpy.data.collections['Atmosphere'].hide_render=True
    for o in s.objects:
        if 'lintel' in o.name:o.hide_render=True
elif mode=='detail':s.camera=bpy.data.objects['Camera_Shrine_Detail'];s.render.resolution_x=1920;s.render.resolution_y=1200;s.cycles.samples=128
elif mode=='material':s.camera=bpy.data.objects['Camera_Oak_Detail'];s.render.resolution_x=1600;s.render.resolution_y=1000;s.cycles.samples=96
elif mode=='neutral':
    s.render.resolution_x=1600;s.render.resolution_y=900;s.cycles.samples=64
    for o in bpy.data.collections['Atmosphere'].objects:o.hide_render=True
    for o in s.objects:
        if o.type=='LIGHT':
            if o.data.type=='SUN':o.data.color=(1,1,1);o.data.energy=2.2
            elif o.data.type=='POINT':o.hide_render=True
    bg=next(n for n in s.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.65,.65,.65,1);bg.inputs['Strength'].default_value=.5
s.render.resolution_percentage=100
pref=bpy.context.preferences.addons['cycles'].preferences
if 'OPTIX' in [p[0] for p in pref.get_device_types(bpy.context)]:
    pref.compute_device_type='OPTIX';pref.refresh_devices()
    for d in pref.devices:d.use=d.type=='OPTIX'
    s.cycles.device='GPU'
s.render.filepath=str(BASE/'previews'/f'sanctuary_{mode}.png');start=time.time()
bpy.ops.render.render(write_still=True)
report={'mode':mode,'output':s.render.filepath,'resolution':[s.render.resolution_x,s.render.resolution_y],'samples':s.cycles.samples,'seconds':time.time()-start,'engine':s.render.engine,'device':s.cycles.device}
(BASE/'reports'/f'render_{mode}.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print('RENDER_COMPLETE',report,flush=True)

