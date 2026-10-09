"""Import a fresh GLB and verify its actual skin deformation and clip lengths."""
import argparse,bpy,json,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--glb',required=True);p.add_argument('--out',required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;scene.render.fps=100;scene.render.fps_base=1
bpy.ops.import_scene.gltf(filepath=str(Path(a.glb).resolve()))
rigs=[o for o in scene.objects if o.type=='ARMATURE']
if len(rigs)!=1:raise RuntimeError('Expected one imported rig')
rig=rigs[0]
meshes=[o for o in scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)]
for track in rig.animation_data.nla_tracks:track.mute=True
report={'glb':Path(a.glb).name,'bones':len(rig.data.bones),'mesh_objects':len(meshes),'imported_weighted_vertices':0,'maximum_influences':0,'unnormalized_vertices':0,'images':len(bpy.data.images),'importer_display_helpers_excluded':[o.name for o in scene.objects if o.type=='MESH' and o not in meshes],'actions':{}}
for o in meshes:
    if not any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers):raise RuntimeError('Missing imported skin modifier: '+o.name)
    names={g.index:g.name for g in o.vertex_groups}
    for vert in o.data.vertices:
        ws=[g.weight for g in vert.groups if names[g.group] in rig.data.bones]
        report['imported_weighted_vertices']+=bool(ws)
        report['maximum_influences']=max(report['maximum_influences'],len(ws))
        report['unnormalized_vertices']+=abs(sum(ws)-1)>1e-4

def capture(action,offset):
    rig.animation_data.action=action
    frame=action.frame_range[0]+offset*scene.render.fps
    scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    return {o.name:[o.evaluated_get(dg).matrix_world@vert.co for vert in o.evaluated_get(dg).data.vertices] for o in meshes}

for name,duration,sample in [('Idle',3,.75),('Run',.8,.2),('Attack',1.55,.75),('Hit',.28,.07)]:
    candidates=[act for act in bpy.data.actions if act.name==name or act.name.startswith(name+'_')]
    if len(candidates)!=1:raise RuntimeError('Missing or ambiguous imported action '+name)
    action=candidates[0]
    start=capture(action,0);peak=capture(action,sample);end=capture(action,duration)
    moves={n:max((x-y).length for x,y in zip(start[n],peak[n])) for n in start}
    loop=max((x-y).length for n in start for x,y in zip(start[n],end[n]))
    report['actions'][name]={'imported_name':action.name,'duration_seconds':(action.frame_range[1]-action.frame_range[0])/scene.render.fps,'mesh_max_displacement_meters':moves,'first_last_mesh_error_meters':loop}
report['passed']=all([report['bones']==56,report['mesh_objects']==2,report['unnormalized_vertices']==0,report['images']==17,len(bpy.data.actions)==4,all(abs(report['actions'][n]['duration_seconds']-d)<1e-5 and max(report['actions'][n]['mesh_max_displacement_meters'].values())>.005 and report['actions'][n]['first_last_mesh_error_meters']<1e-4 for n,d in [('Idle',3),('Run',.8),('Attack',1.55),('Hit',.28)])])
Path(a.out).write_text(json.dumps(report,indent=2));print('ROUNDTRIP_RESULT',json.dumps(report,indent=2),flush=True)
if not report['passed']:raise RuntimeError('Round-trip validation failed')
