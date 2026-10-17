import bpy, json
from pathlib import Path
R=Path('E:/ShopGame/source_assets/animations/nodachi/review_v001')
base=bpy.data.objects['Nodachi_Manny_Rig']
report=json.loads((R/'reports/locomotion_ue_export.json').read_text())
assert len(report['exports'])==194 and not report['errors']
row=next(r for r in report['exports'] if r['name']=='AS_Walk_Combat_Loop_F_0_Seq')
before=set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=row['file'],use_anim=True,automatic_bone_orientation=False)
arm=next(o for o in set(bpy.data.objects)-before if o.type=='ARMATURE')
a=arm.animation_data.action
missing=[b.name for b in arm.data.bones if b.name not in base.data.bones]
errors={b.name:max(abs(x-y) for r1,r2 in zip(b.matrix_local,base.data.bones[b.name].matrix_local) for x,y in zip(r1,r2)) for b in arm.data.bones if b.name in base.data.bones}
print('INSPECT_RESULT',json.dumps({'exports':len(report['exports']),'object_types':[(o.name,o.type) for o in set(bpy.data.objects)-before], 'base_bones':len(base.data.bones),'new_bones':len(arm.data.bones),'missing':missing,'max_rest_delta':max(errors.values()),'source_fps':bpy.context.scene.render.fps/bpy.context.scene.render.fps_base,'action':a.name,'range':list(a.frame_range),'slots':[s.identifier for s in a.slots],'seconds':row['sequence_length'],'source_transform':[list(arm.location),list(arm.rotation_euler),list(arm.scale)],'base_transform':[list(base.location),list(base.rotation_euler),list(base.scale)]}))
