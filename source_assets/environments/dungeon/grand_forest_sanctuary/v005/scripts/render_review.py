import bpy,sys,json,time
from pathlib import Path
assert bpy.app.background
R=Path(__file__).resolve().parents[1];s=bpy.context.scene
assert Path(bpy.data.filepath).parent.parent==R
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.refresh_devices()
for d in prefs.devices:d.use=d.type=='OPTIX'
s.render.engine='CYCLES';s.cycles.device='GPU';s.cycles.use_denoising=True;s.render.use_persistent_data=True
s.render.image_settings.file_format='PNG';s.render.resolution_percentage=100
jobs=[('Camera_Panorama','sanctuary_v005_overview',1800,1238),('Camera_V005_Root_Routes','sanctuary_v005_root_routes',1600,1100),('Camera_V005_Shrine_Gateway','sanctuary_v005_shrine_gateway',1800,1100)]
if '--draft-detail' in sys.argv:jobs=[('Camera_V005_Root_Routes','draft_root',1000,688),('Camera_V005_Shrine_Gateway','draft_gate',1100,672),('Camera_Shrine_Detail','draft_shrine',900,900)]
s.cycles.samples=24 if '--draft-detail' in sys.argv else 96;s.cycles.adaptive_threshold=.10 if '--draft-detail' in sys.argv else .025
for camera,name,x,y in jobs:
    start=time.perf_counter();s.camera=s.objects[camera];s.render.resolution_x=x;s.render.resolution_y=y;s.render.filepath=str(R/'previews'/f'{name}.png')
    bpy.ops.render.render(write_still=True);print('REVIEW_RENDER',name,round(time.perf_counter()-start,2),flush=True)
