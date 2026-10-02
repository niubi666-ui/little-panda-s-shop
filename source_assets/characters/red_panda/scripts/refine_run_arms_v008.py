import bpy,math
from mathutils import Matrix,Vector,Quaternion
rig=bpy.data.objects['RedPanda_RunRig_v008'];s=bpy.data.scenes['RedPanda_Run_v008'];bpy.context.window.scene=s
for o in bpy.context.selected_objects:o.select_set(False)
rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
names=['Upperarm','UpperarmTwist01','UpperarmTwist02','Forearm','ForearmTwist01','ForearmTwist02','Hand']
for name in names:
 l=rig.data.edit_bones['L_'+name];r=rig.data.edit_bones['R_'+name]
 r.head=Vector((l.head.x,-l.head.y,l.head.z));r.tail=Vector((l.tail.x,-l.tail.y,l.tail.z))
 # Preserve existing roll; re-aiming below works from the revised rest frame.
bpy.ops.object.mode_set(mode='OBJECT')
half=[(26,-26,-15,-58),(8,-17,-38,-92),(-14,42,-26,-96),(-30,44,-52,-35)];full=half+[(b,a,d,c) for a,b,c,d in half]
def direction(deg):
 a=math.radians(deg);return Vector((math.sin(a),0,-math.cos(a)))
def aim(name,d,child):
 pb=rig.pose.bones[name];cur=rig.pose.bones[child].head-pb.head;q=cur.normalized().rotation_difference(d.normalized());mat=pb.matrix.copy();pos=mat.translation.copy();mat=q.to_matrix().to_4x4()@mat;mat.translation=pos;pb.matrix=mat;bpy.context.view_layer.update()
prev={}
for frame in range(1,26):
 s.frame_set(frame);t=(frame-1)/3;i=int(t)%8;u=t-int(t);u=u*u*(3-2*u);lt,rt,_,_=[a*(1-u)+b*u for a,b in zip(full[i],full[(i+1)%8])]
 for side in ('L','R'):
  for n in names:rig.pose.bones[side+'_'+n].matrix_basis=Matrix.Identity(4)
 bpy.context.view_layer.update()
 for side,thigh in [('L',lt),('R',rt)]:
  sign=1 if side=='L' else -1;swing=-thigh*.75-10;d=direction(swing);d.y=sign*.16;aim(side+'_Upperarm',d,side+'_Forearm');d=direction(swing+78);d.y=sign*.12;aim(side+'_Forearm',d,side+'_Hand')
  for n in names:
   pb=rig.pose.bones[side+'_'+n];q=pb.rotation_quaternion.copy()
   if pb.name in prev and q.dot(prev[pb.name])<0:q.negate();pb.rotation_quaternion=q
   prev[pb.name]=q.copy()
   for path in ('location','rotation_quaternion','scale'):pb.keyframe_insert(data_path=path,frame=frame)
s.frame_set(19)
print('Revised right-arm rest joint placement in v008 only, and rebaked both arms with bent elbows')
