from pathlib import Path
p=Path(__file__).parent/'build_tree.py'
s=p.read_text(encoding='utf-8')
s=s.replace("nm.inputs['Strength'].default_value=.85","nm.inputs['Strength'].default_value=.72")
start=s.index('random.seed(491)')
s=s[:start]+'''# Brighten leaf surfaces only; retain original lighting, bark and alpha.
def brighten_leaf_material(material):
    nodes=material.node_tree.nodes;links=material.node_tree.links
    texture=next(n for n in nodes if n.type=='TEX_IMAGE' and n.image.colorspace_settings.name!='Non-Color')
    destinations=[link.to_socket for link in list(texture.outputs['Color'].links)]
    for link in list(texture.outputs['Color'].links):links.remove(link)
    gamma=nodes.new('ShaderNodeGamma');gamma.name='Leaf_Midtone_Lift';gamma.inputs['Gamma'].default_value=.82
    hue=nodes.new('ShaderNodeHueSaturation');hue.inputs['Saturation'].default_value=.94;hue.inputs['Value'].default_value=1.12
    balance=nodes.new('ShaderNodeVectorMath');balance.operation='MULTIPLY';balance.inputs[1].default_value=(1.0,1.08,.98)
    links.new(texture.outputs['Color'],gamma.inputs['Color']);links.new(gamma.outputs['Color'],hue.inputs['Color']);links.new(hue.outputs['Color'],balance.inputs[0])
    for socket in destinations:links.new(balance.outputs[0],socket)
brighten_leaf_material(mat)
brighten_leaf_material(single)
'''+s[start:]
a=s.index('    for v in range(4):');b=s.index("    me=bpy.data.meshes.new",a)
s=s[:a]+'''    for v in range(4):
        rec=next(r for r in views if r['module']==k and r['view']==v)
        rot=Euler(rec['rotation']).to_matrix();base=len(vs);size=rec['size']
        rows=4;cols=3
        for j in range(rows+1):
            for i in range(cols+1):
                x=(i/cols-.5)*size;y=(j/rows-.5)*size
                z=.24*(1-(x/1.2)**2)*(1-(y/1.2)**2)+.08*math.sin(y*2.2+v)*x
                vs.append(rot@Vector((x,y,z)))
                uv.append(((k+i/cols)/6,(v+j/rows)/4))
        for j in range(rows):
            for i in range(cols):
                a=base+j*(cols+1)+i;fs.append((a,a+1,a+cols+2,a+cols+1));mi.append(0)
    # Twenty individually folded edge leaves, four triangles each.
    for j in range(20):
        a=j*2.399963;center=Vector((math.cos(a)*random.uniform(.58,.94),math.sin(a)*random.uniform(.58,.94),random.uniform(-.35,.58)))
        rot=Euler((random.uniform(-1.1,1.1),random.uniform(-.7,.7),a)).to_matrix();length=random.uniform(.16,.24);base=len(vs)
        for row in range(3):
            t=row/2
            for i in range(2):
                x=i-.5
                vs.append(center+rot@Vector((x*length*.85,t*length,.045*math.sin(t*math.pi))))
                uv.append((((k+j)%2+i)/2,(1-((k+j)%4)//2+t)/2))
        fs.extend([(base,base+1,base+3,base+2),(base+2,base+3,base+5,base+4)]);mi.extend([1,1])
'''+s[b:]
s=s.replace("'BakedModule_%02d'","'BalancedModule_%02d'")
s=s.replace('assert len(me.loop_triangles)==48','assert len(me.loop_triangles)==176')
s=s.replace('assert lowtri<=3000', 'assert lowtri+19032<=30000')
s=s.replace("'triangles_per_module':48","'triangles_per_module':176,'whole_tree_triangles':lowtri+19032,'budget_scope':'whole tree <= 30000 triangles','leaf_color_adjustment':{'gamma':.82,'value':1.12,'saturation':.94,'rgb_multiplier':[1.0,1.08,.98]}")
s=s.replace('sacred_oak_foliage_low_v004.blend','sacred_oak_balanced_v005.blend')
s=s.replace('low_hero.png','tree_hero.png').replace('low_gameplay_angle.png','tree_gameplay_angle.png')
p.write_text(s,encoding='utf-8')
