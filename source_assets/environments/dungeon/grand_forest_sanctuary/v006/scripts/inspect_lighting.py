import bpy,json
from pathlib import Path
assert bpy.app.background
R=Path(__file__).resolve().parents[1]
s=bpy.context.scene
report={'engine':s.render.engine,'view_transform':s.view_settings.view_transform,'look':s.view_settings.look,'exposure':s.view_settings.exposure,'lights':[],'materials':[],'world':[]}
for o in s.objects:
 if o.type=='LIGHT':report['lights'].append({'name':o.name,'type':o.data.type,'energy':o.data.energy,'color':list(o.data.color),'location':list(o.location),'rotation':list(o.rotation_euler),'angle':getattr(o.data,'angle',None),'use_shadow':o.data.use_shadow})
for m in bpy.data.materials:
 if not m.use_nodes:continue
 refs=[o.name for o in s.objects if o.type=='MESH' and m in list(o.data.materials)]
 if not refs:continue
 principled=[{'name':n.name,'inputs':{i.name:list(i.default_value) if hasattr(i.default_value,'__len__') else i.default_value for i in n.inputs if hasattr(i,'default_value') and isinstance(i.default_value,(int,float,str)) or hasattr(i,'default_value') and hasattr(i.default_value,'__len__')},'linked':[i.name for i in n.inputs if i.is_linked]} for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED']
 report['materials'].append({'name':m.name,'users':m.users,'refs':refs[:4],'principled':principled,'nodes':[(n.name,n.type) for n in m.node_tree.nodes],'links':[(l.from_node.name,l.from_socket.name,l.to_node.name,l.to_socket.name) for l in m.node_tree.links]})
for n in s.world.node_tree.nodes:
 if n.type=='BACKGROUND':report['world'].append({'name':n.name,'color':list(n.inputs['Color'].default_value),'strength':n.inputs['Strength'].default_value})
report['eevee_properties']=[p.identifier for p in s.eevee.bl_rna.properties] if hasattr(s,'eevee') else []
report['material_properties']=[p.identifier for p in bpy.types.Material.bl_rna.properties]
(R/'reports/source_lighting.json').write_text(json.dumps(report,indent=2,ensure_ascii=False,default=str),encoding='utf-8')
print('INSPECT_LIGHTING',len(report['materials']),report['world'],flush=True)
