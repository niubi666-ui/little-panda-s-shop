import bpy,math,json
from mathutils import Vector,Matrix,Quaternion
from pathlib import Path
BASE=Path('E:/ShopGame/source_assets/characters/red_panda')
if bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_play()
source=bpy.data.objects['RedPanda_ARP_Rig_v003'];srcmesh=bpy.data.objects['RedPanda_ARP_Mesh_v003']
poses=[('01_Contact',28,-28,-12,-55,0.00,0),('02_Down',10,-15,-42,-95,-.045,-3),('03_Passing',-15,48,-28,-110,-.005,2),('04_Flight',-35,52,-65,-38,.045,5)]
def direction(angle):
    a=math.radians(angle);return Vector((math.sin(a),0,-math.cos(a)))
results=[]
for label,lt,rt,lc,rc,height,tail in poses:
    scene=bpy.data.scenes.new('RunPose_'+label);bpy.context.window.scene=scene
    rig=source.copy();rig.data=source.data.copy();rig.name='PoseRig_'+label;rig.animation_data_clear();scene.collection.objects.link(rig)
    ob=srcmesh.copy();ob.data=srcmesh.data.copy();ob.name='PoseMesh_'+label;ob.animation_data_clear();scene.collection.objects.link(ob)
    for mod in ob.modifiers:
        if mod.type=='ARMATURE':mod.object=rig
    for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4);pb.rotation_mode='QUATERNION'
    bpy.context.view_layer.update()
    def rotate(name,quat):
        pb=rig.pose.bones[name];mat=pb.matrix.copy();loc=mat.translation.copy();mat=quat.to_matrix().to_4x4()@mat;mat.translation=loc;pb.matrix=mat;bpy.context.view_layer.update()
    def aim(name,d,child=None):
        pb=rig.pose.bones[name];current=(rig.pose.bones[child].head-pb.head) if child else (pb.tail-pb.head)
        rotate(name,current.normalized().rotation_difference(Vector(d).normalized()))
    # Independently authored poses from rest; no source action evaluation or keyframes.
    rotate('Waist',Quaternion((0,1,0),math.radians(10)))
    rotate('Head',Quaternion((0,1,0),math.radians(-7)))
    for side,t,c in [('L',lt,lc),('R',rt,rc)]:
        aim(side+'_Thigh',direction(t),side+'_Calf');aim(side+'_Calf',direction(t+c),side+'_Foot')
        aim(side+'_Foot',(1,0,-.08 if t>0 else -.3))
    for side,swing in [('L',-lt*.65),('R',-rt*.65)]:
        sign=1 if side=='L' else -1
        d=direction(swing);d.y=sign*.20
        aim(side+'_Upperarm',d,side+'_Forearm')
        d=direction(swing+85);d.y=sign*.12
        aim(side+'_Forearm',d,side+'_Hand')
        aim(side+'_Hand',(d.x,sign*.08,d.z-.15))
    rotate('Tail_01',Quaternion((0,0,1),math.radians(62+tail)))
    for i in range(2,6):rotate('Tail_%02d'%i,Quaternion((0,1,0),math.radians(-2+tail*.2)))
    # Place each pose relative to a shared ground datum, with flight clearance.
    ev=ob.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh();bottom=min(v.co.z for v in me.vertices);ev.to_mesh_clear()
    mat=rig.pose.bones['Root'].matrix.copy();mat.translation.z+=-bottom+max(height,0);rig.pose.bones['Root'].matrix=mat;bpy.context.view_layer.update()
    scene['review_only']='Static running pose. No action or interpolation; awaiting user approval.'
    scene['pose_design']=label
    scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    scene.render.image_settings.media_type='IMAGE';scene.render.image_settings.file_format='PNG'
    results.append(scene.name)
print(results)
