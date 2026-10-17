import bpy,json
from pathlib import Path
ROOT=Path('E:/ShopGame/source_assets/animations/nodachi/roll_8dir_v001')
def ready():
    s=bpy.context.scene
    s.frame_set(1)
    s.use_preview_range=False
    s.sync_mode='FRAME_DROP'
    for win in bpy.context.window_manager.windows:
        for ar in win.screen.areas:
            if ar.type=='NLA_EDITOR':
                region=next((r for r in ar.regions if r.type=='WINDOW'),None)
                if region:
                    with bpy.context.temp_override(window=win,area=ar,region=region): bpy.ops.nla.view_all()
        with bpy.context.temp_override(window=win):
            if not win.screen.is_animation_playing: bpy.ops.screen.animation_play()
    (ROOT/'reports/live_playback.json').write_text(json.dumps({'file':bpy.data.filepath,'scene':s.name,
        'range':[s.frame_start,s.frame_end],'playing':any(w.screen.is_animation_playing for w in bpy.context.window_manager.windows)},indent=2))
    return None
bpy.app.timers.register(ready,first_interval=3)
