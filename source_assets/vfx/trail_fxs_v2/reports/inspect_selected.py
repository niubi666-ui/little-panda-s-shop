import bpy,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(next((root/'original').rglob('TrailFXs_Blades.blend'))),load_ui=False,use_scripts=False)
def val(x):
    if isinstance(x,(str,int,float,bool)):return x
    try:return list(x)
    except:return str(x)
def tree(t):
    out={'name':t.name,'nodes':[],'links':[]}
    for n in t.nodes:
        d={'name':n.name,'type':n.bl_idname,'inputs':[{ 'index':i,'name':s.name,'value':val(s.default_value)} for i,s in enumerate(n.inputs) if hasattr(s,'default_value')],'outputs':[{ 'index':i,'name':s.name,'value':val(s.default_value)} for i,s in enumerate(n.outputs) if hasattr(s,'default_value')],'attrs':{k:val(getattr(n,k)) for k in ['operation','blend_type','data_type','gradient_type','noise_dimensions','normalize','attribute_name','vector_type','interpolation_type','clamp'] if hasattr(n,k)}}
        if n.type=='VALTORGB': d['ramp']={'interpolation':n.color_ramp.interpolation,'elements':[(e.position,list(e.color)) for e in n.color_ramp.elements]}
        if n.type=='GROUP':d['group']=tree(n.node_tree)
        out['nodes'].append(d)
    for l in t.links:out['links'].append([l.from_node.name,l.from_socket.name,l.to_node.name,l.to_socket.name])
    return out
report={name:tree(bpy.data.materials[name].node_tree) for name in ['Trail_Blade_01','Trail_Blade_06']}
report['objects']=[{'name':o.name,'type':o.type,'modifiers':[{'name':m.name,'type':m.type,'group':m.node_group.name if m.type=='NODES' else ''} for m in o.modifiers]} for o in bpy.data.objects]
mod=bpy.data.objects['Trail_Blade'].modifiers[0]
try: report['modifier']={k:val(mod[k]) for k in mod.keys()}
except TypeError: report['modifier']='Legacy IDProperties unavailable in Blender 5.2; interface defaults inspected.'
report['interface']=[{'name':s.name,'id':s.identifier,'default':val(getattr(s,'default_value',None))} for s in mod.node_group.interface.items_tree if s.item_type=='SOCKET']
report['geometry']=tree(mod.node_group)
(root/'reports/selected_nodes.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('INSPECTED')
