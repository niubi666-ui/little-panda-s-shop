"""Render a saved room in an isolated process, recording actual output metrics."""
import bpy,sys,time,json
from pathlib import Path
from mathutils import Vector

args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
mode=args[0] if args else 'final'
s=bpy.context.scene
room=s['room_id'];base=Path(bpy.data.filepath).parent.parent
start=time.time()
if mode=='draft':
    s.render.resolution_x=1100;s.render.resolution_y=619;s.cycles.samples=32
else:
    s.render.resolution_x=1920;s.render.resolution_y=1080;s.cycles.samples=112
s.render.resolution_percentage=100
s.cycles.use_denoising=True
pref=bpy.context.preferences.addons['cycles'].preferences
try:
    ids=[item[0] for item in pref.get_device_types(bpy.context)]
    print('CYCLES_AVAILABLE',ids,flush=True)
    if 'OPTIX' in ids:
        pref.compute_device_type='OPTIX';pref.refresh_devices()
        for dev in pref.devices:dev.use=dev.type=='OPTIX'
        if 'GPU' in [i.identifier for i in s.cycles.bl_rna.properties['device'].enum_items]:s.cycles.device='GPU'
except Exception as e:print('DEVICE_NOTE',str(e),flush=True)
print('RENDER_DEVICE',s.cycles.device,flush=True)
if mode=='detail':
    if room=='sunlit_forest_court':camera=(5,-8,9);target=(-3.1,7.0,2.3);scale=12.2
    else:camera=(3.6,-3,7.2);target=(7.4,7.6,2.05);scale=10.4
    s.camera.location=camera;s.camera.rotation_euler=(Vector(target)-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=scale
    s.render.resolution_x=1600;s.render.resolution_y=1000;s.cycles.samples=96
suffix='_draft' if mode=='draft' else '_detail' if mode=='detail' else ''
output=base/'previews'/f'{room}_v001{suffix}.png'
s.render.filepath=str(output)
bpy.ops.render.render(write_still=True)
report={'room_id':room,'mode':mode,'engine':s.render.engine,'device':s.cycles.device,'samples':s.cycles.samples,'resolution':[s.render.resolution_x,s.render.resolution_y],'seconds':round(time.time()-start,2),'output':str(output),'output_exists':output.exists(),'godot_runtime':False}
(base/'reports'/f'render_{mode}_v001.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('RENDER_COMPLETE',json.dumps(report),flush=True)
