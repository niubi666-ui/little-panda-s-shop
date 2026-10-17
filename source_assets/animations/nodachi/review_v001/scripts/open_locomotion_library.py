import bpy,json
from pathlib import Path
ROOT=Path('E:/ShopGame/source_assets/animations/nodachi/review_v001')
def ready():
    s=bpy.data.scenes['00_Overview']
    for win in bpy.context.window_manager.windows:
        win.scene=s
        s.frame_set(1)
        s.use_preview_range=False
        s.sync_mode='FRAME_DROP'
        rig=next(o for o in s.objects if o.type=='ARMATURE')
        s.view_layers[0].objects.active=rig
        rig.select_set(True,view_layer=s.view_layers[0])
        for ar in win.screen.areas:
            if ar.type=='NLA_EDITOR':
                region=next((r for r in ar.regions if r.type=='WINDOW'),None)
                if region:
                    with bpy.context.temp_override(window=win,area=ar,region=region): bpy.ops.nla.view_all()
        with bpy.context.temp_override(window=win):
            if not win.screen.is_animation_playing: bpy.ops.screen.animation_play()
    (ROOT/'reports/locomotion_live_playback.json').write_text(json.dumps({'file':bpy.data.filepath,
        'scene':s.name,'range':[s.frame_start,s.frame_end],'fps':s.render.fps,
        'playing':any(w.screen.is_animation_playing for w in bpy.context.window_manager.windows)},indent=2))
    return None
bpy.app.timers.register(ready,first_interval=3)
