import bpy
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(BASE/'blender/trail_study_amber_v002.blend'))
o=bpy.data.objects['FX_01_Flowing_Blade'];m=o.modifiers[0]
for i in m.node_group.interface.items_tree:
 if i.item_type=='SOCKET' and i.in_out=='INPUT': print('INPUT',i.name,i.identifier,str(getattr(m.properties.inputs,i.identifier).value))
print('REFS',[(o.name,o.animation_data is not None,len(o.data.vertices)) for o in bpy.data.objects if 'Reference' in o.name or 'REFERENCE' in o.name])
print('DRIVERS',o.animation_data.drivers[:] if o.animation_data else None)
ref=bpy.data.objects['REFERENCE_Sword_Edge']
for x in [o,ref]:
 print('DETAIL',x.name,'parent',x.parent,'constraints',[(c.name,c.type) for c in x.constraints],'mods',[(m.name,m.type) for m in x.modifiers])
 print('RAW', [list(v.co) for v in x.data.vertices][:12])
 print('EVAL',[list(v.co) for v in x.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices][:12])
for n in m.node_group.nodes:
 if n.type in ['OBJECT_INFO','TRANSFORM_GEOMETRY','SIMULATION_INPUT','SIMULATION_OUTPUT','SET_POSITION']:
  print('NODE',n.name,n.type,'space',getattr(n,'transform_space',''),[(i.name,str(i.default_value)) for i in n.inputs if hasattr(i,'default_value') and not i.is_linked])
  for l in m.node_group.links:
   if l.to_node==n or l.from_node==n: print('LINK',l.from_node.name,l.from_socket.name,'->',l.to_node.name,l.to_socket.name)
print('WEAPONS',[(o.name,list(o.location),list(o.dimensions)) for o in bpy.context.scene.objects if o.name.startswith('Weapon')])
