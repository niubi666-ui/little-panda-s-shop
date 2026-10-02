import bpy,json
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene;s.render.fps=30;s.render.resolution_x=1280;s.render.resolution_y=720;s.render.resolution_percentage=50
s.render.image_settings.file_format='PNG'
s.view_settings.view_transform='Standard'
ed=s.sequence_editor_create();rows=[]
for label in ['01_Golden_Filaments','02_Ember_Brush']:
 p=BASE/'previews/final'/(label+'.mp4')
 strip=ed.strips.new_movie(name=label,filepath=str(p),channel=1,frame_start=1)
 rows.append({'file':str(p),'bytes':p.stat().st_size,'frames':strip.frame_duration,'fps':strip.fps,'width':strip.elements[0].orig_width,'height':strip.elements[0].orig_height})
 s.frame_set(99);s.render.filepath=str(BASE/'previews/final'/(label+'_video_check.png'));bpy.ops.render.render(write_still=True)
 ed.strips.remove(strip)
(BASE/'reports/video_validation.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
print(json.dumps(rows))
