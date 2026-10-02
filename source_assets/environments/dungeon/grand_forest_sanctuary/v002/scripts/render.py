import bpy,sys,time,json
from pathlib import Path
BASE=Path(bpy.data.filepath).parent.parent;s=bpy.context.scene
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['draft']
mode=args[0]
cams={'draft':'Camera_Panorama','panorama':'Camera_Panorama','gameplay':'Camera_Gameplay','east':'Camera_East_Gateway','north':'Camera_North_Reverse','detail':'Camera_Shrine_Detail'}
s.camera=bpy.data.objects[cams[mode]]
s.render.resolution_x=1400 if mode=='draft' else 2560;s.render.resolution_y=875 if mode=='draft' else 1600
s.cycles.samples=40 if mode=='draft' else 144;s.cycles.use_denoising=True
p=bpy.context.preferences.addons['cycles'].preferences;p.compute_device_type='OPTIX';p.refresh_devices()
for d in p.devices:d.use=d.type=='OPTIX'
s.cycles.device='GPU';s.render.resolution_percentage=100;s.render.filepath=str(BASE/'previews'/('sanctuary_'+mode+'.png'))
start=time.time();bpy.ops.render.render(write_still=True)
(BASE/'reports'/('render_'+mode+'.json')).write_text(json.dumps({'mode':mode,'camera':s.camera.name,'resolution':[s.render.resolution_x,s.render.resolution_y],'samples':s.cycles.samples,'seconds':time.time()-start,'device':s.cycles.device},indent=2))
