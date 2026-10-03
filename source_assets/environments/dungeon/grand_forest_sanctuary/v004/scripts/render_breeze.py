import bpy,json,time,sys,math,hashlib
from pathlib import Path
assert bpy.app.background
R=Path(__file__).resolve().parents[1];s=bpy.context.scene
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
mode=args[0] if args else 'all'
start_index=int(args[1]) if len(args)>1 else 0
end_index=int(args[2]) if len(args)>2 else 100000
engine=args[3] if len(args)>3 else 'cycles'
pref=bpy.context.preferences.addons['cycles'].preferences;pref.compute_device_type='OPTIX';pref.refresh_devices()
for d in pref.devices:d.use=d.type=='OPTIX'
s.render.engine='CYCLES';s.cycles.device='GPU';s.cycles.samples=24;s.cycles.use_denoising=True;s.cycles.use_animated_seed=False;s.cycles.seed=19
s.render.use_persistent_data=True;s.render.resolution_x=960;s.render.resolution_y=600;s.render.resolution_percentage=100
if engine=='eevee':
 s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=32
s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGB';s.render.image_settings.compression=15
clips=[('flowers','Camera_Breeze_Flowers',72),('canopy','Camera_Breeze_Canopy',72),('panorama','Camera_Panorama',54)]
if mode!='all':clips=[c for c in clips if c[0]==mode]
if engine=='eevee':clips=[c for c in clips if c[0]!='flowers']
report={'renderer':s.render.engine,'fps':18,'samples':32 if engine=='eevee' else 24,'resolution':[960,600],'clips':{}}
for label,camera,count in clips:
 folder=R/'previews'/('frames_'+label+('_eevee' if engine=='eevee' else ''));folder.mkdir(exist_ok=True)
 s.camera=s.objects[camera];durations=[]
 for i in range(start_index,min(count,end_index)):
  out=folder/('%04d.png'%i)
  if out.exists():continue
  # Time sampling is 18 Hz while the authored Blender timeline remains 24 Hz.
  f=1+i*24/18;s.frame_set(int(f),subframe=f-int(f));s.render.filepath=str(out)
  start=time.perf_counter();bpy.ops.render.render(write_still=True);durations.append(time.perf_counter()-start)
  print('BREEZE_FRAME',label,i,round(durations[-1],3),flush=True)
 report['clips'][label]={'requested_frames':count,'completed_frames':len(list(folder.glob('*.png'))),'camera':camera,'mean_render_seconds':sum(durations)/len(durations) if durations else None}
 (R/'reports'/('render_'+mode+'_'+engine+'.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
print('BREEZE_RENDER_DONE',json.dumps(report),flush=True)
