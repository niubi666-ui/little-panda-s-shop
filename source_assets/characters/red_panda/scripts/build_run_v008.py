import bpy,math,json
from mathutils import Vector,Matrix,Quaternion
from pathlib import Path
BASE=Path('E:/ShopGame/source_assets/characters/red_panda')
if bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_play()
src=bpy.data.scenes['KneePose_03_Passing'];scene=bpy.data.scenes.new('RedPanda_Run_v008');bpy.context.window.scene=scene
oldrig=next(o for o in src.objects if o.type=='ARMATURE');oldmesh=next(o for o in src.objects if o.type=='MESH')
rig=oldrig.copy();rig.data=oldrig.data.copy();rig.name='RedPanda_RunRig_v008';rig.animation_data_clear();scene.collection.objects.link(rig)
ob=oldmesh.copy();ob.data=oldmesh.data.copy();ob.name='RedPanda_RunMesh_v008';ob.animation_data_clear();scene.collection.objects.link(ob)
for m in ob.modifiers:
 if m.type=='ARMATURE':m.object=rig
# Half-cycle poses: contact, loading, passing and airborne recovery.
half=[(26,-26,-15,-58),(8,-17,-38,-92),(-14,42,-26,-96),(-30,44,-52,-35)]
full=half+[(b,a,d,c) for a,b,c,d in half]
previous={};records=[]
def direction(deg):
 a=math.radians(deg);return Vector((math.sin(a),0,-math.cos(a)))
def rotate(name,q):
 pb=rig.pose.bones[name];mat=pb.matrix.copy();loc=mat.translation.copy();mat=q.to_matrix().to_4x4()@mat;mat.translation=loc;pb.matrix=mat;bpy.context.view_layer.update()
def aim(name,d,child=None):
 pb=rig.pose.bones[name];cur=rig.pose.bones[child].head-pb.head if child else pb.tail-pb.head
 rotate(name,cur.normalized().rotation_difference(Vector(d).normalized()))
for frame in range(1,26):
 scene.frame_set(frame)
 for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4);pb.rotation_mode='QUATERNION'
 bpy.context.view_layer.update();phase=(frame-1)/24;theta=phase*math.tau;t=phase*8;i=int(t)%8;u=t-int(t);u=u*u*(3-2*u)
 lt,rt,lc,rc=[a*(1-u)+b*u for a,b in zip(full[i],full[(i+1)%8])]
 rotate('Waist',Quaternion((0,1,0),math.radians(8)))
 rotate('Spine02',Quaternion((0,0,1),math.radians(2*math.sin(theta))))
 rotate('Head',Quaternion((0,1,0),math.radians(-6)))
 for side,thigh,calf in [('L',lt,lc),('R',rt,rc)]:
  aim(side+'_Thigh',direction(thigh),side+'_Calf');aim(side+'_Calf',direction(thigh+calf),side+'_Foot')
  pb=rig.pose.bones[side+'_Foot'];loc=pb.matrix.translation.copy();mat=rig.data.bones[pb.name].matrix_local.copy()
  pitch=max(0,-thigh)*.28;mat=Quaternion((0,1,0),math.radians(pitch)).to_matrix().to_4x4()@mat;mat.translation=loc;pb.matrix=mat;bpy.context.view_layer.update()
 # Opposite arm to leading leg; shoulder swings back, elbow stays softly bent.
 for side,thigh in [('L',lt),('R',rt)]:
  sign=1 if side=='L' else -1;swing=-thigh*.75-10
  d=direction(swing);d.y=sign*.16;aim(side+'_Upperarm',d,side+'_Forearm')
  d=direction(swing+62);d.y=sign*.12;aim(side+'_Forearm',d,side+'_Hand')
  rig.pose.bones[side+'_Hand'].matrix_basis=Matrix.Identity(4);bpy.context.view_layer.update()
 rotate('Tail_01',Quaternion((0,0,1),math.radians(62+3*math.sin(theta-.45))))
 for j in range(2,6):
  rotate('Tail_%02d'%j,Quaternion((0,0,1),math.radians(1.4*math.sin(theta-.45-j*.3))))
  rotate('Tail_%02d'%j,Quaternion((0,1,0),math.radians(-2+1.2*math.sin(theta*2-j*.25))))
 ev=ob.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh();bottom=min(v.co.z for v in me.vertices);ev.to_mesh_clear()
 # In-place loop. Contact/loading touches ground; last quarter of each step is airborne.
 step=(phase*2)%1;air=.025*max(0,math.sin(math.pi*(step-.60)/.40)) if step>.60 else 0
 root=rig.pose.bones['Root'];mat=root.matrix.copy();mat.translation.z+=-bottom+air;root.matrix=mat;bpy.context.view_layer.update()
 for pb in rig.pose.bones:
  q=pb.rotation_quaternion.copy()
  if pb.name in previous and q.dot(previous[pb.name])<0:q.negate();pb.rotation_quaternion=q
  previous[pb.name]=q.copy()
  pb.keyframe_insert(data_path='location',frame=frame);pb.keyframe_insert(data_path='rotation_quaternion',frame=frame);pb.keyframe_insert(data_path='scale',frame=frame)
 records.append({'frame':frame,'right_hand_x':rig.pose.bones['R_Hand'].head.x,'right_shoulder_x':rig.pose.bones['R_Upperarm'].head.x,'floor_clearance':air})
action=rig.animation_data.action;action.name='RP_Run_New_v008';action.use_fake_user=True
curves=[fc for layer in action.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]
for fc in curves:
 for kp in fc.keyframe_points:kp.interpolation='LINEAR'
scene.render.fps=30;scene.frame_start=1;scene.frame_end=24;scene.frame_set(7)
scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
(BASE/'reports/run_v008_authoring.json').write_text(json.dumps(records,indent=2))
print({'action':action.name,'frames':list(action.frame_range),'fcurves':len(curves),'right_hand_backward_frames':[r['frame'] for r in records if r['right_hand_x']<r['right_shoulder_x']]})
print('modifier_types',[i.identifier for i in bpy.types.FModifier.bl_rna.properties['type'].enum_items])
