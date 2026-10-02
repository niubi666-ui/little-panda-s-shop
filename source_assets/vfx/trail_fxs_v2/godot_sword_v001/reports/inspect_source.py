import bpy,json
from pathlib import Path
base=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(base/'blender/sword_trail_study.blend'),load_ui=False,use_scripts=False)
s=bpy.context.scene;s.frame_set(99)
o=bpy.data.objects['FX_01_Flowing_Blade'];e=o.evaluated_get(bpy.context.evaluated_depsgraph_get())
report={'material':o.modifiers[0].properties.inputs.Input_9.value.name,'attributes':{},'nodes':[]}
uv=e.data.attributes['BladeUVs']
report['uv_tip_check']=[]
for i,d in enumerate(uv.data):
 if d.vector.x>.999 and (d.vector.y<.001 or d.vector.y>.999):
  report['uv_tip_check'].append({'uv':list(d.vector),'world':list(e.matrix_world@e.data.vertices[i].co)})
ref=bpy.data.objects['REFERENCE_Sword_Edge']
report['reference_vertices']=[list(ref.matrix_world@v.co) for v in ref.data.vertices]
for a in e.data.attributes:
 if a.name in ['Speed','Hue','Glow','Glow2','BladeUVs','UseGlowColors']:
  field={'FLOAT':'value','BOOLEAN':'value','FLOAT_VECTOR':'vector','FLOAT_COLOR':'color'}.get(a.data_type)
  if field:
   v=getattr(a.data[0],field)
   report['attributes'][a.name]=list(v) if hasattr(v,'__len__') else v
mat=bpy.data.materials['01_Golden_Filaments']
for n in mat.node_tree.nodes:
 if n.type in ['OUTPUT_MATERIAL','MIX_SHADER','EMISSION','ATTRIBUTE']:
  report['nodes'].append({'name':n.name,'type':n.type,'attribute':getattr(n,'attribute_name',None),'links':[(l.from_node.name,l.from_socket.name,l.to_node.name,l.to_socket.name) for l in mat.node_tree.links if l.to_node==n or l.from_node==n]})
Path(__file__).with_name('source_inspection.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
