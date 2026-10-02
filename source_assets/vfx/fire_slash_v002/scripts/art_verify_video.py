import bpy,json
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene;editor=s.sequence_editor_create()
strip=editor.strips.new_movie('Verify actual render',str(BASE/'blender_previews/fire_slash_v002_motion.mp4'),channel=1,frame_start=1)
data={'frames':strip.frame_duration,'fps':strip.fps,'width':strip.elements[0].orig_width,'height':strip.elements[0].orig_height}
assert data['frames']==96 and data['width']==960 and data['height']==600,data
(BASE/'reports/art_video_validation.json').write_text(json.dumps(data,indent=2),encoding='utf-8');print(data)
