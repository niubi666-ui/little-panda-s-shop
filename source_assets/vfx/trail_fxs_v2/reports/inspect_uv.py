import bpy
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(BASE/'blender/trail_study_amber_v002.blend'))
s=bpy.context.scene;s.frame_set(99)
o=bpy.data.objects['FX_01_Flowing_Blade'];e=o.evaluated_get(bpy.context.evaluated_depsgraph_get());a=e.data.attributes['BladeUVs']
print('UV',[(i,list(e.data.vertices[i].co),list(a.data[i].vector)) for i in [0,10,11,21,len(e.data.vertices)-1,len(e.data.vertices)-11]])
mat=o.modifiers[0].properties.inputs.Input_9.value
for n in mat.node_tree.nodes:
 if n.type in ['OUTPUT_MATERIAL','BSDF_PRINCIPLED','MIX_SHADER','EMISSION','BSDF_TRANSPARENT','ATTRIBUTE']:
  print('NODE',n.name,n.type,getattr(n,'attribute_name',''))
  print('LINKS',[(l.from_node.name,l.from_socket.name,l.to_node.name,l.to_socket.name) for l in mat.node_tree.links if l.to_node==n or l.from_node==n])
