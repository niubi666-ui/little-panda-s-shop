"""Portable Blender 4.3 animation and GLB export for JACKAL SCOUT.

blender -b -t 2 --python animate_jackal.py -- --source path/to/base.blend --out path/to/out --preview
The original base is read only. Every generated file is placed in --out.
Authoring uses armature-space rest matrices and analytic two-bone IK, then
bakes quaternion keys. No constraints or external motion service are needed.
"""
import argparse, bpy, json, math, sys
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

parser=argparse.ArgumentParser()
parser.add_argument('--source',required=True)
parser.add_argument('--out',required=True)
parser.add_argument('--preview',action='store_true')
parser.add_argument('--export',action='store_true')
parser.add_argument('--samples',type=int,default=16)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
SOURCE=Path(args.source).resolve(); OUT=Path(args.out).resolve(); OUT.mkdir(parents=True,exist_ok=True)
(OUT/'previews').mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene=bpy.context.scene
rig=next(o for o in scene.objects if o.type=='ARMATURE')
meshes=[o for o in scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)]
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
rest_q={n:m.to_quaternion().normalized() for n,m in rest.items()}
inverse={n:m.inverted() for n,m in rest.items()}
length={b.name:b.length for b in rig.data.bones}
FPS=100
scene.render.fps=FPS; scene.render.fps_base=1
scene.render.engine='CYCLES'; scene.cycles.samples=args.samples; scene.cycles.use_denoising=False
scene.cycles.device='CPU'; scene.render.threads_mode='FIXED'; scene.render.threads=2
scene.render.resolution_x=576; scene.render.resolution_y=640; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'

def clamp(x,lo=0,hi=1):return min(hi,max(lo,x))
def smooth(x): x=clamp(x);return x*x*(3-2*x)

# Match the concealed pelvis/thigh skin transition to the shorts. The source
# body had full thigh weighting up to the waist, while the linen blends into
# Hips. A shared transition prevents the fur pushing through the waistband
# during bent-knee recoil and the central gusset folding into the crotch.
weight_fixes={'body_pelvis_vertices':0,'linen_gusset_vertices':0,'shorts_seam_vertices':0}
for o in meshes:
    vertex_materials=[set() for _ in o.data.vertices]
    for poly in o.data.polygons:
        mat=o.data.materials[poly.material_index]
        for ix in poly.vertices:vertex_materials[ix].add(mat.name if mat else '')
    group_names={g.index:g.name for g in o.vertex_groups}
    for vert in o.data.vertices:
        p=o.matrix_world@vert.co
        if not (.97<p.z<1.16) or abs(p.x)>.29:continue
        materials=vertex_materials[vert.index]
        names={group_names[g.group] for g in vert.groups}
        linen=any('linen knee shorts' in m for m in materials)
        seam=any('leather seam thread' in m for m in materials) and p.z<1.155
        fur=any(m.startswith(('01 |','02 |','03 |')) for m in materials) and any(n.startswith('UpperLeg.') or n=='Hips' for n in names)
        if not (linen or seam or fur):continue
        side='R' if p.x<0 else 'L'
        leg_weight=clamp((1.12-p.z)/.13)*smooth((abs(p.x)-.025)/.09)
        for group in list(vert.groups):o.vertex_groups[group_names[group.group]].remove([vert.index])
        for name,w in [('Hips',1-leg_weight),('UpperLeg.'+side,leg_weight)]:
            if w>1e-6:
                group=o.vertex_groups.get(name) or o.vertex_groups.new(name=name)
                group.add([vert.index],w,'REPLACE')
        label='linen_gusset_vertices' if linen else 'shorts_seam_vertices' if seam else 'body_pelvis_vertices'
        weight_fixes[label]+=1

# The source analytical skinning drops influences below 0.002, leaving a few
# pairs slightly short of one. Normalize the retained deform weights for an
# explicit, portable glTF skin. Blender's evaluated pose already normalizes
# them, so this keeps the accepted appearance while removing export ambiguity.
normalized_vertices=0
for o in meshes:
    groups={g.index:g for g in o.vertex_groups}
    for vert in o.data.vertices:
        ws=[(groups[g.group],g.weight) for g in vert.groups if groups[g.group].name in rest]
        total=sum(w for _,w in ws)
        if total<=0:raise RuntimeError('Unweighted vertex: '+o.name+' '+str(vert.index))
        if abs(total-1)>1e-6:
            for group,w in ws:group.add([vert.index],w/total,'REPLACE')
            normalized_vertices+=1
weight_fixes['normalized_source_vertices']=normalized_vertices

def v(x): return Vector(x)
def qx(a): return Quaternion((1,0,0),a)
def qy(a): return Quaternion((0,1,0),a)
def qz(a): return Quaternion((0,0,1),a)
def angles(x=0,y=0,z=0): return qz(z)@qy(y)@qx(x)
def lerp(a,b,t):return a+(b-a)*t
def keyed(t,keys,ease=True):
    if t<=keys[0][0]:return keys[0][1]
    if t>=keys[-1][0]:return keys[-1][1]
    for (ta,a),(tb,b) in zip(keys,keys[1:]):
        if ta<=t<=tb:
            u=(t-ta)/(tb-ta);u=smooth(u) if ease else u
            if isinstance(a,(list,tuple,Vector)):return v(a).lerp(v(b),u)
            return lerp(a,b,u)

# Foot contact samples are evaluated with the actual weighted vertices. This
# corrects sole height after knee bending and keeps skins on the studio ground.
soles={'R':[],'L':[]}
for o in meshes:
    groups={g.index:g.name for g in o.vertex_groups}
    for vert in o.data.vertices:
        p=o.matrix_world@vert.co
        if p.z<.11 and abs(p.x)>.08 and not o.name.startswith('MACHETE'):
            ws=[(groups[g.group],g.weight) for g in vert.groups if groups[g.group] in rest and g.weight>1e-6]
            if ws:soles['R' if p.x<0 else 'L'].append((p.copy(),ws))

solved={}
def put(name,position,rotation):
    m=rotation.to_matrix().to_4x4();m.translation=position;solved[name]=m
    b=rig.data.bones[name];p=rig.pose.bones[name]
    if b.parent:
        p.matrix_basis=b.convert_local_to_pose(m,b.matrix_local,parent_matrix=solved[b.parent.name],parent_matrix_local=b.parent.matrix_local,invert=True)
    else:p.matrix_basis=b.convert_local_to_pose(m,b.matrix_local,invert=True)

def relative(name,local_delta=None):
    b=rig.data.bones[name]
    pm=solved[b.parent.name]@inverse[b.parent.name] if b.parent else Matrix.Identity(4)
    h=pm@b.head_local
    skin_q=pm.to_quaternion().normalized()
    put(name,h,skin_q@(local_delta or Quaternion())@rest_q[name])

def skin_rotation(name):return solved[name].to_quaternion().normalized()@rest_q[name].inverted()
def deformed_head(name):
    b=rig.data.bones[name];return (solved[b.parent.name]@inverse[b.parent.name])@b.head_local

def two_bone(upper,lower,end_target,pole,base_skin=None):
    """Solve lengths and a bend plane without relying on Euler axis guesses."""
    h=deformed_head(upper);target=v(end_target);axis=target-h
    d=clamp(axis.length,abs(length[upper]-length[lower])+.003,length[upper]+length[lower]-.003)
    axis.normalize();target=h+axis*d
    bend=v(pole)-h;bend-=axis*bend.dot(axis)
    if bend.length<1e-5:bend=axis.cross(Vector((1,0,0)))
    bend.normalize()
    a=(length[upper]**2-length[lower]**2+d*d)/(2*d)
    height=math.sqrt(max(0,length[upper]**2-a*a))
    joint=h+axis*a+bend*height
    base_skin=base_skin or Quaternion()
    for name,start,end in [(upper,h,joint),(lower,joint,target)]:
        ref_dir=base_skin@(rest[name].to_3x3()@Vector((0,1,0)))
        direction=(end-start).normalized()
        swing=ref_dir.normalized().rotation_difference(direction)
        put(name,start,swing@base_skin@rest_q[name])
    return target,joint

def minimum_sole(side):
    transforms={n:solved[n]@inverse[n] for n in solved}
    low=1000
    for p,ws in soles[side]:
        z=sum((transforms[n]@p).z*w for n,w in ws if n in transforms)
        low=min(low,z)
    return low

def leg(side,ankle,foot_pitch=0,foot_yaw=0,clearance=0,foot_roll=0):
    s=-1 if side=='R' else 1
    target=v(ankle);rotation=angles(foot_pitch,foot_roll,foot_yaw)
    for iteration in range(3):
        target,joint=two_bone('UpperLeg.'+side,'LowerLeg.'+side,target,(s*.17,-.57,.64),skin_rotation('Hips'))
        put('Foot.'+side,target,rotation@rest_q['Foot.'+side])
        relative('Toes.'+side)
        error=(-.009+clearance)-minimum_sole(side)
        if abs(error)<.0002:break
        target.z+=error
    return {'ankle':list(target),'knee':list(joint),'sole':minimum_sole(side),'clearance':clearance}

D0=Vector((0,-1,0))
HAND0=(rest['Hand.R'].to_3x3()@Vector((0,1,0))).normalized()
H0=(HAND0-D0*HAND0.dot(D0)).normalized()
N0=D0.cross(H0).normalized()
GRIP_REST=Matrix((D0,H0,N0)).transposed()
def grip_rotation(direction,forearm):
    d=v(direction).normalized();h=forearm-d*forearm.dot(d)
    if h.length<.01:h=Vector((0,0,-1))-d*d.z*-1
    h.normalize();n=d.cross(h).normalized()
    return (Matrix((d,h,n)).transposed()@GRIP_REST.inverted()).to_quaternion().normalized()

def arm(side,wrist,pole,blade=None,loose_curl=0):
    target,joint=two_bone('UpperArm.'+side,'LowerArm.'+side,wrist,pole,skin_rotation('Chest'))
    forearm=(target-joint).normalized()
    if side=='R':hand_skin=grip_rotation(blade or (0,-.95,-.3),forearm)
    else:hand_skin=skin_rotation('LowerArm.'+side)@qx(-.075)
    put('Hand.'+side,target,hand_skin@rest_q['Hand.'+side])
    for label in ['Thumb','Index','Middle','Ring','Little']:
        for i in range(1,4):
            # Anatomical RIGHT is modeled closed around the handle at rest;
            # leave those exact relative digit transforms intact.
            delta=qx(-loose_curl*(.5 if label=='Thumb' else 1)) if side=='L' else Quaternion()
            relative(label+str(i)+'.'+side,delta)
    return {'wrist':list(target),'elbow':list(joint),'wrist_bend_degrees':math.degrees(math.acos(clamp((hand_skin@HAND0).dot(forearm),-1,1)))}

def body(hips,hip_angles,spine_angles,chest_angles,neck_angles,head_angles):
    solved.clear();put('Root',rig.data.bones['Root'].head_local.copy(),rest_q['Root'])
    put('Hips',v(hips),angles(*hip_angles)@rest_q['Hips'])
    for name,a in [('Spine',spine_angles),('Chest',chest_angles),('Neck',neck_angles),('Head',head_angles)]:relative(name,angles(*a))
    for side in ['R','L']:relative('Shoulder.'+side)

def tail(lift,yaw,phase,amp=.035):
    for i in range(1,5):
        local=angles((lift if i==1 else lift*.10)+amp*math.sin(phase-(i-1)*.72),0,yaw/(i**.65)+amp*math.sin(phase-(i-1)*.86))
        relative('Tail'+str(i),local)

IDLE_R=Vector((-.445,-.105,1.005));IDLE_L=Vector((.445,-.135,1.02))
IDLE_POLE_R=Vector((-.405,.085,1.315));IDLE_POLE_L=Vector((.405,.085,1.315))
IDLE_BLADE=Vector((-.045,-.956,-.289)).normalized()
def idle(t):
    ph=2*math.pi*t/3
    breath=math.sin(ph)
    body((-.018+.003*math.sin(ph),.018,1.026+.003*breath),(.025,0,.025),( .035,0,-.015),(.025,0,.010),(-.025,0,0),(-.025,.022*math.sin(ph),-.025))
    legs=[leg('R',(-.233,.045,.235),foot_yaw=-.09),leg('L',(.234,-.105,.235),foot_yaw=.09)]
    r=IDLE_R+Vector((0,.006*breath,.003*breath));l=IDLE_L+Vector((0,.006*breath,.004*breath))
    arms=[arm('R',r,IDLE_POLE_R,IDLE_BLADE),arm('L',l,IDLE_POLE_L,loose_curl=.025)]
    tail(.16,.06,ph,.025)
    return {'legs':legs,'arms':arms}

def run_foot(p):
    # A flat/rolling stance occupies 42 percent of the cycle. It moves back
    # at constant treadmill velocity; the swing has a separate clearance arc.
    if p<=.42:
        y=lerp(-.34,.34,p/.42)
        pitch=keyed(p,[(0,-.13),(.09,0),(.26,.035),(.36,.40),(.42,.66)])
        return y,0,pitch,'stance'
    y=keyed(p,[(.42,.34),(.58,.28),(.75,-.10),(.92,-.355),(1,-.34)])
    clearance=keyed(p,[(.42,0),(.56,.255),(.75,.27),(.92,.055),(1,0)])
    pitch=keyed(p,[(.42,.66),(.57,.57),(.75,-.25),(.92,-.16),(1,-.13)])
    return y,clearance,pitch,'swing'

def run(t):
    p=(t/.8)%1;ph=2*math.pi*p
    z=keyed(p% .5,[(0,.997),(.11,.973),(.27,1.020),(.40,1.075),(.5,.997)])
    body((-.025*math.cos(ph),.025,z),(.10,.045*math.cos(ph),-.075*math.cos(ph)),(.115,-.02*math.cos(ph),.035*math.cos(ph)),(.075,-.025*math.cos(ph),.08*math.cos(ph)),(-.105,0,0),(-.10,0,-.035*math.cos(ph)))
    legs=[]
    for side,offset,s in [('R',0,-1),('L',.5,1)]:
        lp=(p+offset)%1;y,clearance,pitch,phase=run_foot(lp)
        ld=leg(side,(s*.182,y,.235+clearance),foot_pitch=pitch,foot_yaw=s*.065,clearance=clearance)
        ld.update({'phase':phase,'cycle_phase':lp});legs.append(ld)
    # Low weapon arm counterphase to its ipsilateral leg. Left hand is empty.
    rw=(-.365,.015+.22*math.cos(ph),1.105-.035*math.cos(ph))
    lw=(.335,.015-.31*math.cos(ph),1.205+.10*math.cos(ph))
    arms=[arm('R',rw,(-.385,.10,1.36),(-.08,-.935,-.345)),arm('L',lw,(.36,.10,1.39),loose_curl=.055)]
    tail(.49,-.07*math.cos(ph),ph-.65,.045)
    return {'legs':legs,'arms':arms}

ATTACK_TIMES=[0,.28,.60,.75,.80,.83,.90,1.12,1.34,1.55]
ATTACK_RIGHT=[IDLE_R,(-.45,.035,1.285),(-.42,.025,1.615),(-.41,.025,1.645),(-.39,-.34,1.46),(-.105,-.54,1.295),(.19,-.38,1.10),(.155,-.23,1.105),(-.26,-.13,1.08),IDLE_R]
ATTACK_BLADE=[IDLE_BLADE,(-.10,-.87,.48),(-.62,-.64,.45),(-.62,-.64,.45),(-.25,-.94,.23),(.45,-.80,-.40),(.72,-.31,-.62),(.55,-.28,-.78),(.10,-.85,-.50),IDLE_BLADE]
def attack(t):
    coil=keyed(t,[(0,0),(.35,.48),(.60,.9),(.75,1),(.83,-.80),(.9,-.90),(1.12,-.45),(1.55,0)])
    shift=keyed(t,[(0,-.018),(.6,-.075),(.75,-.08),(.83,.055),(.9,.075),(1.16,.02),(1.55,-.018)])
    z=keyed(t,[(0,1.026),(.6,1.002),(.75,1.004),(.84,1.018),(.9,.991),(1.15,1.005),(1.55,1.026)])
    forward=keyed(t,[(0,0),(.75,-.075),(.83,.14),(.9,.18),(1.15,.09),(1.55,0)])
    body((shift,.018,z),(.025,0,.025-.15*coil),(.035+forward*.45,0,-.015-.22*coil),(.025+forward*.55,0,.010-.22*coil),(-.025,0,.08*coil),(-.025-forward*.55,0,.12*coil-.025))
    legs=[leg('R',(-.233,.045,.235),foot_yaw=-.09),leg('L',(.234,-.105,.235),foot_yaw=.09)]
    rw=keyed(t,list(zip(ATTACK_TIMES,ATTACK_RIGHT)))
    blade=keyed(t,list(zip(ATTACK_TIMES,ATTACK_BLADE)))
    lw=keyed(t,[(0,IDLE_L),(.6,(.52,-.21,1.20)),(.75,(.52,-.21,1.20)),(.85,(.54,.005,1.24)),(.9,(.55,.015,1.15)),(1.15,(.52,-.035,1.13)),(1.55,IDLE_L)])
    rp=keyed(t,[(0,IDLE_POLE_R),(.6,(-.53,.02,1.40)),(.75,(-.53,.02,1.40)),(.83,(-.37,-.45,1.48)),(.90,(-.39,-.30,1.27)),(1.12,(-.4,-.22,1.28)),(1.55,IDLE_POLE_R)])
    lp=IDLE_POLE_L.lerp(Vector((.47,.03,1.40)),clamp(abs(coil)))
    arms=[arm('R',rw,rp,blade),arm('L',lw,lp,loose_curl=.025+.015*abs(coil))]
    tail(.16+.15*abs(coil),.06+.17*coil,2*math.pi*t/1.55,.025)
    return {'legs':legs,'arms':arms,'attack_phase':'windup' if t<.75 else 'active' if t<=.90 else 'recovery'}

def hit(t):
    recoil=keyed(t,[(0,0),(.065,1),(.10,.85),(.18,.28),(.28,0)])
    body((-.018+.03*recoil,.018+.034*recoil,1.026-.045*recoil),(.025-.055*recoil,0,.025+.025*recoil),(.035-.17*recoil,-.025*recoil,-.015),(.025-.16*recoil,-.035*recoil,.01-.03*recoil),(-.025-.035*recoil,0,0),(-.025-.025*recoil,.025*recoil,-.025))
    legs=[leg('R',(-.233,.045,.235),foot_yaw=-.09),leg('L',(.234,-.105,.235),foot_yaw=.09)]
    rw=IDLE_R.lerp(Vector((-.47,.055,1.055)),recoil)
    lw=IDLE_L.lerp(Vector((.475,-.04,1.32)),recoil)
    rp=IDLE_POLE_R.lerp(Vector((-.49,.15,1.35)),recoil)
    lp=IDLE_POLE_L.lerp(Vector((.47,.08,1.39)),recoil)
    arms=[arm('R',rw,rp,IDLE_BLADE),arm('L',lw,lp,loose_curl=.025-.01*recoil)]
    tail(.16+.14*recoil,.06-.11*recoil,2*math.pi*t/.28,.025)
    return {'legs':legs,'arms':arms,'recoil':recoil}

CLIPS=[('Idle',3.0,idle),('Run',.8,run),('Attack',1.55,attack),('Hit',.28,hit)]
rig.animation_data_clear()
for old in list(bpy.data.actions):
    if old.name in [n for n,_,_ in CLIPS]:bpy.data.actions.remove(old)
for pb in rig.pose.bones:
    pb.rotation_mode='QUATERNION'
    for c in list(pb.constraints):pb.constraints.remove(c)

actions={};diagnostics={};prev_q={}
for name,duration,pose_fn in CLIPS:
    action=bpy.data.actions.new(name);action.use_fake_user=True
    rig.animation_data_create();rig.animation_data.action=action
    end=1+round(duration*FPS);prev_q={};frames=[]
    for f in range(1,end+1):
        t=(f-1)/FPS;data=pose_fn(t)
        for pb in rig.pose.bones:
            q=pb.rotation_quaternion.copy()
            if pb.name in prev_q and q.dot(prev_q[pb.name])<0:q.negate();pb.rotation_quaternion=q
            prev_q[pb.name]=q.copy()
            pb.keyframe_insert(data_path='location',frame=f,group=pb.name)
            pb.keyframe_insert(data_path='rotation_quaternion',frame=f,group=pb.name)
            # Constant scale is explicitly retained to avoid stale source poses.
            pb.scale=(1,1,1)
            pb.keyframe_insert(data_path='scale',frame=f,group=pb.name)
        if f in [1,end] or (name=='Attack' and f in [61,76,84,91]) or (name=='Run' and f in [11,26,41,51,66]) or (name=='Hit' and f in [7,11]):
            frames.append({'frame':f,'time_seconds':t,**data})
    for fc in action.fcurves:
        for kp in fc.keyframe_points:kp.interpolation='LINEAR'
    action['duration_seconds']=duration
    action['motion_style']='Native Blender keyframed, analytic limb pose solving, baked quaternion transforms'
    if name=='Run':action['loop']='Seamless in place, 42 percent stance per foot, treadmill ground contact'
    if name=='Attack':action['timing']='windup 0.75 s; active 0.15 s; recovery 0.65 s'
    actions[name]=action;diagnostics[name]={'duration_seconds':duration,'frame_start':1,'frame_end':end,'frames':frames}
    print('ACTION_COMPLETE',name,duration,end,flush=True)

# Retain all clips as independent named NLA strips while keeping editability.
# Muted tracks make direct action review and the saved Idle pose unambiguous.
for name,duration,pose_fn in CLIPS:
    track=rig.animation_data.nla_tracks.new();track.name=name
    strip=track.strips.new(name,1,actions[name]);strip.name=name;strip.blend_type='REPLACE';strip.extrapolation='NOTHING'
    track.mute=True
rig.animation_data.action=actions['Idle'];scene.frame_start=1;scene.frame_end=301;scene.frame_set(1)
bpy.context.view_layer.update()
rig['animation_notes']='Idle 3.00 s, Run 0.80 s loop, Attack 1.55 s (0.75+0.15+0.65), Hit 0.28 s. Root fixed; right-hand machete only.'
for name in ['ANIMATION NOTES | Jackal Scout']:
    old=bpy.data.texts.get(name)
    if old:bpy.data.texts.remove(old)
note=bpy.data.texts.new('ANIMATION NOTES | Jackal Scout')
note.write('JACKAL SCOUT — AUTHORED ANIMATION\n\n100 fps authoring gives exact game clip timings.\nIdle: 3.00 s, seamless breathing/weight shift loop.\nRun: 0.80 s, in-place loop; stance feet stay on ground.\nAttack: 1.55 s; windup 0.75, active 0.15, recovery 0.65.\nHit: 0.28 s, nonlethal recoil and recovery.\n\nAll 56 bones retain editable baked quaternion/location keys.\nMuted NLA tracks retain each independent named action.\nSelect an action in the Action Editor to review; no IK constraint dependency.\nSingle machete follows Hand.R and its finger grip.\nRoot stays fixed. Character faces source -Y.\nGLB excludes studio ground, cameras and lights.\n')

cam=scene.camera
if cam:
    cam.location=(-3.8,-6.4,3.05);target=Vector((0,-.02,1.15));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.82

stats={'source':SOURCE.name,'fps':FPS,'armature':rig.name,'bones':len(rig.data.bones),'deform_bones':sum(b.use_deform for b in rig.data.bones),'mesh_objects':len(meshes),'vertices':sum(len(o.data.vertices) for o in meshes),'weighted_vertices':sum(sum(bool(v.groups) for v in o.data.vertices) for o in meshes),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'clips':diagnostics,'packed_images':[im.name for im in bpy.data.images if im.packed_file],'root_in_place':True,'weapon_hand':'Hand.R','rest_front':'Blender -Y','local_skin_weight_corrections':weight_fixes}
(OUT/'animation_report.json').write_text(json.dumps(stats,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'jackal_scout_animated.blend'),compress=True)

if args.preview:
    poses=[('Idle',0,'idle'),('Run',0,'run_contact'),('Run',.20,'run_passing'),('Attack',.75,'attack_windup'),('Attack',.83,'attack_contact'),('Attack',1.12,'attack_recovery'),('Hit',.065,'hit_peak')]
    for name,t,label in poses:
        rig.animation_data.action=actions[name];scene.frame_set(1+round(t*FPS));bpy.context.view_layer.update()
        scene.render.filepath=str(OUT/'previews'/(label+'.png'))
        bpy.ops.render.render(write_still=True)
        print('PREVIEW_COMPLETE',label,flush=True)

if args.export:
    # ACTIONS exports the real named clip data once per rig. Materials/images
    # are embedded. Selection omits the presentation collection completely.
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
    for o in meshes:o.select_set(True)
    bpy.context.view_layer.objects.active=rig
    rig.animation_data.action=actions['Idle'];scene.frame_set(1)
    glb_kwargs=dict(filepath=str(OUT/'jackal_scout_animated.glb'),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_animations=True,export_skins=True,export_all_influences=False,export_force_sampling=True,export_frame_step=1,export_cameras=False,export_lights=False,export_extras=True)
    props=bpy.ops.export_scene.gltf.get_rna_type().properties
    if 'export_animation_mode' in props:glb_kwargs['export_animation_mode']='ACTIONS'
    if 'export_anim_slide_to_zero' in props:glb_kwargs['export_anim_slide_to_zero']=True
    if 'export_optimize_animation_size' in props:glb_kwargs['export_optimize_animation_size']=False
    if 'export_nla_strips' in props:glb_kwargs['export_nla_strips']=True
    if 'export_anim_single_armature' in props:glb_kwargs['export_anim_single_armature']=True
    if 'export_current_frame' in props:glb_kwargs['export_current_frame']=False
    bpy.ops.export_scene.gltf(**glb_kwargs)
    print('GLB_COMPLETE',OUT/'jackal_scout_animated.glb',flush=True)

rig.animation_data.action=actions['Idle'];scene.frame_start=1;scene.frame_end=301;scene.frame_set(1)
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'jackal_scout_animated.blend'),compress=True)
print('JACKAL_ANIMATIONS_COMPLETE',stats['bones'],stats['weighted_vertices'],stats['triangles'],flush=True)
