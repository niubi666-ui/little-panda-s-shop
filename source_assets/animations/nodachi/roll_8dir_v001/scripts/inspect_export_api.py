import bpy,json
props=bpy.ops.export_scene.gltf.get_rna_type().properties
for p in props:
    if any(s in p.identifier for s in ('anim','nla','frame','skin','bone','select','yup','extras')):
        print(p.identifier,p.type,p.default if p.type not in ('COLLECTION','POINTER') else '',[(x.identifier,x.description) for x in p.enum_items] if p.type=='ENUM' else '',p.description)
