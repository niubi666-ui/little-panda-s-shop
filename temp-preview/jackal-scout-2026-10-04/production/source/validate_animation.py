"""Read-only validation of an authored Jackal Scout .blend and animated GLB."""
import argparse, bpy, json, math, struct, sys
from pathlib import Path
from mathutils import Vector
parser=argparse.ArgumentParser();parser.add_argument('--blend',required=True);parser.add_argument('--glb',required=True);parser.add_argument('--out',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.open_mainfile(filepath=str(Path(args.blend).resolve()))
scene=bpy.context.scene;rig=next(o for o in scene.objects if o.type=='ARMATURE')
meshes=[o for o in scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)]
actions={n:bpy.data.actions[n] for n in ['Idle','Run','Attack','Hit']}
result={'blend':Path(args.blend).name,'glb':Path(args.glb).name,'checks':{},'clips':{}}
checks=result['checks'];checks['bones']=len(rig.data.bones);checks['mesh_objects']=len(meshes)
checks['weighted_vertices']=sum(len(o.data.vertices) for o in meshes)
weights=[];bad=[];weapon_good=True
for o in meshes:
    names={g.index:g.name for g in o.vertex_groups}
    for vert in o.data.vertices:
        ws=[g for g in vert.groups if names[g.group] in rig.data.bones]
        total=sum(g.weight for g in ws)
        if abs(total-1)>1e-4:bad.append((o.name,vert.index,total))
        weights.append(len(ws))
        if 'Machete' in o.name and (len(ws)!=1 or names[ws[0].group]!='Hand.R' or abs(ws[0].weight-1)>1e-5):weapon_good=False
checks['unweighted_or_unnormalized_vertices']=len(bad);checks['maximum_influences']=max(weights);checks['weapon_100_percent_Hand_R']=weapon_good

def capture(action,t):
    rig.animation_data.action=action;f=1+t*scene.render.fps
    scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
    return {p.name:p.matrix.copy() for p in rig.pose.bones}

neutral=capture(actions['Idle'],0)
root_rest=rig.data.bones['Root'].matrix_local.copy()
checks['root_max_matrix_error']=0
for name,duration in [('Idle',3.0),('Run',.8),('Attack',1.55),('Hit',.28)]:
    act=actions[name];a=capture(act,0);b=capture(act,duration)
    first_last=max(abs(a[n][row][col]-b[n][row][col]) for n in a for row in range(4) for col in range(4))
    channels={fc.data_path.split('"')[1] for fc in act.fcurves if fc.data_path.startswith('pose.bones[')}
    clip={'duration_seconds':(act.frame_range[1]-act.frame_range[0])/scene.render.fps,'keyed_bones':len(channels),'fcurves':len(act.fcurves),'first_last_max_matrix_error':first_last,'ground_samples':[]}
    if name in ['Attack','Hit']:
        clip['neutral_start_max_matrix_error']=max(abs(a[n][row][col]-neutral[n][row][col]) for n in a for row in range(4) for col in range(4))
    # Feet are measured from the evaluated skinned mesh rather than the IK
    # author's diagnostic matrices. Original sole vertex IDs are reused.
    sole_ids={}
    for o in meshes:
        sole_ids[o.name]={side:[vi.index for vi in o.data.vertices if (o.matrix_world@vi.co).z<.11 and ((o.matrix_world@vi.co).x<-.08 if side=='R' else (o.matrix_world@vi.co).x>.08)] for side in ['R','L']}
    sample_times=[duration*i/20 for i in range(21)]
    if name=='Attack':sample_times=sorted(set(sample_times+[.75,.83,.9]))
    if name=='Hit':sample_times=sorted(set(sample_times+[.065]))
    for t in sample_times:
        posed=capture(act,t)
        checks['root_max_matrix_error']=max(checks['root_max_matrix_error'],max(abs(posed['Root'][row][col]-root_rest[row][col]) for row in range(4) for col in range(4)))
        dg=bpy.context.evaluated_depsgraph_get();minimum={s:1000 for s in ['R','L']}
        for o in meshes:
            evaluated=o.evaluated_get(dg)
            for s in ['R','L']:
                for ix in sole_ids[o.name][s]:minimum[s]=min(minimum[s],(evaluated.matrix_world@evaluated.data.vertices[ix].co).z)
        clip['ground_samples'].append({'time_seconds':round(t,5),'right_sole_z':minimum['R'],'left_sole_z':minimum['L']})
    result['clips'][name]=clip

raw=Path(args.glb).read_bytes();magic,version,total=struct.unpack_from('<4sII',raw,0)
jslen,jstype=struct.unpack_from('<II',raw,12);gl=json.loads(raw[20:20+jslen])
checks['glb_header_valid']=magic==b'glTF' and version==2 and total==len(raw)
checks['glb_bytes']=len(raw);checks['glb_meshes']=len(gl.get('meshes',[]));checks['glb_skins']=len(gl.get('skins',[]));checks['glb_joints']=[len(s['joints']) for s in gl.get('skins',[])]
checks['glb_embedded_images']=len(gl.get('images',[]));checks['glb_external_resources']=[x.get('uri') for typ in ['images','buffers'] for x in gl.get(typ,[]) if x.get('uri')]
checks['glb_has_cameras_or_lights']=bool(gl.get('cameras')) or bool(gl.get('extensions',{}).get('KHR_lights_punctual'))
checks['glb_presentation_nodes']=[n.get('name') for n in gl.get('nodes',[]) if any(k in n.get('name','').lower() for k in ['studio ground','portrait camera','softbox','back edge','catchlight'])]
checks['glb_clip_names']=[a.get('name') for a in gl.get('animations',[])]
for a in gl.get('animations',[]):
    bounds=[gl['accessors'][s['input']] for s in a['samplers']]
    lo=min(x['min'][0] for x in bounds);hi=max(x['max'][0] for x in bounds)
    result['clips'][a['name']]['glb_time_min_seconds']=lo
    result['clips'][a['name']]['glb_time_max_seconds']=hi
    result['clips'][a['name']]['glb_duration_seconds']=hi-lo
    result['clips'][a['name']]['glb_channels']=len(a['channels'])
    checks.setdefault('glb_baked_keyframes',{})[a['name']]=max(x['count'] for x in bounds)
    paths={c['target']['path'] for c in a['channels']};result['clips'][a['name']]['glb_channel_paths']=sorted(paths)

checks['passed']=all([checks['bones']==56,checks['unweighted_or_unnormalized_vertices']==0,weapon_good,checks['root_max_matrix_error']<1e-5,checks['glb_header_valid'],checks['glb_meshes']==2,checks['glb_skins']==1,checks['glb_joints']==[56],not checks['glb_external_resources'],not checks['glb_has_cameras_or_lights'],not checks['glb_presentation_nodes'],sorted(checks['glb_clip_names'])==sorted(actions),all(c['keyed_bones']==56 and c['first_last_max_matrix_error']<1e-4 for c in result['clips'].values()),all(abs(result['clips'][n]['glb_time_min_seconds'])<1e-6 and abs(result['clips'][n]['glb_time_max_seconds']-d)<1e-5 for n,d in [('Idle',3.0),('Run',.8),('Attack',1.55),('Hit',.28)])])
Path(args.out).write_text(json.dumps(result,indent=2))
print('JACKAL_VALIDATION',json.dumps(checks,indent=2),flush=True)
if not checks['passed']:raise RuntimeError('Animation validation failed; read report')
