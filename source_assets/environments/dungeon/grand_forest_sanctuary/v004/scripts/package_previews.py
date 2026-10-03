"""Encode actual rendered frames and verify deliverable media/links."""
import json,subprocess,re
from pathlib import Path
import imageio_ffmpeg
R=Path(__file__).resolve().parents[1];P=R/'previews';ff=imageio_ffmpeg.get_ffmpeg_exe()
clips=[('flowers','frames_flowers',72,18,'Cycles'),('canopy','frames_canopy_eevee',72,18,'EEVEE'),('panorama','frames_panorama_eevee',54,18,'EEVEE')]
manifest={'source':'Actual rendered scene animation, no AI-generated imagery','videos':[]}
for label,folder,count,fps,engine in clips:
 assert all((P/folder/('%04d.png'%i)).is_file() for i in range(count)),folder
 out=P/('breeze_'+label+'.mp4')
 subprocess.run([ff,'-y','-loglevel','error','-framerate',str(fps),'-i',str(P/folder/'%04d.png'),'-frames:v',str(count),'-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(out)],check=True)
 manifest['videos'].append({'file':out.name,'engine':engine,'frames':count,'fps':fps,'seconds':count/fps,'resolution':[960,600]})
subprocess.run([ff,'-y','-loglevel','error','-i',str(P/'breeze_gpu.avi'),'-an','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(P/'breeze_gpu.mp4')],check=True)
manifest['videos'].append({'file':'breeze_gpu.mp4','engine':'Godot 4.7.2 Forward+ Vulkan','frames':240,'fps':30,'seconds':8,'resolution':[1280,800],'scope':'Three asset groups, not full-room game performance'})
for item in manifest['videos']:
 path=P/item['file']
 result=subprocess.run([ff,'-v','error','-i',str(path),'-an','-f','framemd5','-'],capture_output=True,text=True,check=True)
 hashes=[line.split(',')[-1].strip() for line in result.stdout.splitlines() if line and not line.startswith('#')]
 assert len(hashes)==item['frames'],(item['file'],len(hashes))
 assert len(set(hashes))>1,(item['file'],'no frame changes')
 item['decoded_frames_verified']=len(hashes);item['different_decoded_frame_hashes']=len(set(hashes));item['bytes']=path.stat().st_size
broken=[]
for link in re.findall(r'(?:src|href|poster)="([^"]+)"',(P/'index.html').read_text(encoding='utf-8')):
 if not (P/link).resolve().exists():broken.append(link)
assert not broken,broken
manifest['local_links_verified']=True
(R/'reports/preview_delivery.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
# Keep incomplete Cycles diagnostics explicitly distinguished from delivery.
q=R/'reports/render_canopy.json'
if q.exists():
 old=json.loads(q.read_text());c=old['clips']['canopy'];c['requested_frames']=c.pop('frames');c['completed_frames']=len(list((P/'frames_canopy').glob('*.png')));old['status']='Partial timing diagnostic; delivery uses EEVEE clip';q.write_text(json.dumps(old,indent=2),encoding='utf-8')
print(json.dumps(manifest,indent=2))
