import bpy,math,random
from mathutils import Vector,Euler

def make_module(k,cluster_material,single_material,kit):
    verts=[];faces=[];uv=[];materials=[]
    def card(center,rot,width,length,variant,rows,cols,bend,twist,mi):
        base=len(verts)
        for j in range(rows+1):
            t=j/rows
            for i in range(cols+1):
                x=i/cols-.5
                # Real midrib fold, cup and tip curl, not planar subdivision.
                z=bend*math.sin(t*math.pi)-width*.17*abs(x)+twist*x*t
                p=rot@Vector((x*width,t*length,z))+center
                verts.append(p)
                col=variant%2;row=1-variant//2
                uv.append(((col+.012+i/cols*.976)/2,(row+.012+t*.976)/2))
        for j in range(rows):
            for i in range(cols):
                a=base+j*(cols+1)+i
                faces.append((a,a+1,a+cols+2,a+cols+1));materials.append(mi)
    # Small crossed branch cards provide internal body only.
    for c in range(7):
        center=Vector((random.uniform(-.3,.3),random.uniform(-.3,.3),random.uniform(-.2,.25)))
        rot=Euler((random.uniform(-1.4,1.4),random.uniform(-.9,.9),random.uniform(0,math.tau))).to_matrix()
        card(center,rot,.55,.59,(k+c)%4,4,3,.10,random.uniform(-.08,.08),0)
    # Independent curved leaf cards along 16 short, non-coplanar shoots.
    # Each leaf has its own silhouette, normal, rotation and shadow.
    for shoot in range(16):
        a=shoot*2.399963+random.uniform(-.35,.35)
        endpoint=Vector((math.cos(a)*random.uniform(.55,.87),math.sin(a)*random.uniform(.55,.87),random.uniform(-.48,.62)))
        start=Vector((0,0,0))
        axis=(endpoint-start).normalized()
        tangent=axis.cross(Vector((0,0,1))).normalized()
        cross=axis.cross(tangent).normalized()
        b=len(verts)
        for ring in range(3):
            t=ring/2
            for v in range(5):
                ang=v*math.tau/5;rad=.009*(1-t)+.002*t
                verts.append(start.lerp(endpoint,t)+(tangent*math.cos(ang)+cross*math.sin(ang))*rad)
                uv.append((v/5,t))
        for ring in range(2):
            for v in range(5):
                faces.append((b+ring*5+v,b+ring*5+(v+1)%5,b+(ring+1)*5+(v+1)%5,b+(ring+1)*5+v));materials.append(2)
        for j in range(18):
            t=.20+j*.044
            center=start.lerp(endpoint,t)
            side=1 if j%2 else -1
            yaw=a-math.pi/2+side*random.uniform(.55,1.5)
            rot=Euler((random.uniform(-1.2,1.2),random.uniform(-.8,.8),yaw)).to_matrix()
            length=random.uniform(.16,.24)
            card(center,rot,length*.87,length,(j+k+shoot)%4,3,2,length*random.uniform(.08,.23),length*random.uniform(-.14,.14),1)
    me=bpy.data.meshes.new('OakVolumeModule_%02d'%k)
    me.from_pydata(verts,[],faces);me.materials.append(cluster_material);me.materials.append(single_material)
    bark=bpy.data.materials.get('OakFineTwigs')
    if bark is None:
        bark=bpy.data.materials.new('OakFineTwigs');bark.use_nodes=True
        b=next(n for n in bark.node_tree.nodes if n.type=='BSDF_PRINCIPLED');b.inputs['Base Color'].default_value=(.13,.075,.028,1);b.inputs['Roughness'].default_value=.9
    me.materials.append(bark)
    layer=me.uv_layers.new(name='UVMap')
    for p in me.polygons:
        p.use_smooth=True;p.material_index=materials[p.index]
        for idx in p.loop_indices:layer.data[idx].uv=uv[me.loops[idx].vertex_index]
    ob=bpy.data.objects.new('Module_%02d'%k,me);kit.objects.link(ob)
    return me
