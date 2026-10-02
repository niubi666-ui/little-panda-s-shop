import bpy, json
from pathlib import Path
base=Path(__file__).resolve().parents[1]
path=next((base/'original').rglob('TrailFXs_Blades.blend'))
bpy.ops.wm.open_mainfile(filepath=str(path),load_ui=False,use_scripts=False)
o=bpy.data.objects['Trail_Blade'];m=o.modifiers[0]
setattr(getattr(m.properties.inputs,'Input_3'),'value',bpy.data.objects['Blade_Reference'])
scene=bpy.context.scene
o.animation_data_clear()
o.hide_viewport=False
o.hide_set(False)
m.show_viewport=True
m.show_render=True
o.update_tag()
print('OBJECT',o.name,o.name in scene.objects,'REF',m.properties.inputs.Input_3.value,'RUN',m.properties.inputs.Input_2.value,'VISIBILITY',o.visible_get())
print('REF_VERTS',len(bpy.data.objects['Blade_Reference'].data.vertices))
print('SCENE',scene.frame_start,scene.frame_end)
for f in range(1,21):
 scene.frame_set(f)
 e=o.evaluated_get(bpy.context.evaluated_depsgraph_get())
 if f in [1,5,10,20]:print('FRAME',f,'VERTICES',len(e.data.vertices),'BOUNDS',list(e.dimensions))
print('BAKE_TARGET',[(p,[i.identifier for i in m.bl_rna.properties[p].enum_items]) for p in ['bake_target']])
for b in m.bakes:print('BAKE',[(p.identifier, str(getattr(b,p.identifier))) for p in b.bl_rna.properties])
print('NODES',[(n.type, n.bl_idname) for n in m.node_group.nodes if n.type in ['SIMULATION_INPUT','SIMULATION_OUTPUT']])
