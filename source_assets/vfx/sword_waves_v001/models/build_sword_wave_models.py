"""Deterministic Blender source for thin, transverse sword-wave meshes.

Run with a NEW Blender process:
  blender --background --factory-startup --python build_sword_wave_models.py
Runtime OBJ basis: +Y up, forward -Z, crescent span X=-1..1.
UV.x is the left/right arc parameter; UV.y is leading edge 0 -> trailing edge 1.
"""
import bpy, bmesh, math, random, json
from pathlib import Path
from mathutils import Vector
from collections import Counter

SOURCE=Path(__file__).resolve().parent
RUNTIME=SOURCE.parents[3]/'game/assets/vfx/sword_waves_v001/models'
SOURCE.mkdir(parents=True,exist_ok=True); RUNTIME.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0

def material(name,rgb,metal,rough,emission=0.0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*rgb,1); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*rgb,1)
    bs.inputs['Metallic'].default_value=metal; bs.inputs['Roughness'].default_value=rough
    bs.inputs['Emission Color'].default_value=(*rgb,1); bs.inputs['Emission Strength'].default_value=emission
    return m

normal_material=material('Pearl gold blade',(0.75,.49,.18),.68,.21,.16)
ice_materials=[material('Crystal plane %02d'%i,(.065+k*.25,.33+k*.39,.58+k*.4),.34,.17,.08) for i,k in enumerate([0,.25,.45,.68,.85,1])]

def mesh_object(name,positions,faces,vertex_uv,icy=False):
    # Convert the authored Godot basis into Blender's Z-up basis.
    vertices=[(x,-z,y) for x,y,z in positions]
    mesh=bpy.data.meshes.new(name+'_mesh'); mesh.from_pydata(vertices,[],faces); mesh.update()
    bm=bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
    bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
    bm.to_mesh(mesh); bm.free(); mesh.update()
    uv=mesh.uv_layers.new(name='WaveUV')
    for loop in mesh.loops:
        uv.data[loop.index].uv=vertex_uv[loop.vertex_index]
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    mats=ice_materials if icy else [normal_material]
    for m in mats: mesh.materials.append(m)
    rng=random.Random(741 if icy else 740)
    for poly in mesh.polygons:
        poly.use_smooth=not icy
        poly.material_index=rng.randrange(len(mats))
    obj['runtime_up']='Y'; obj['runtime_forward']='-Z'; obj['uv_contract']='U=left/right arc; V=leading(0)/trailing(1)'
    obj['presentation_only']=True
    return obj

def crescent(name,icy):
    segments=48
    lanes=[0,.12,.32,.57,.83,1]
    positions=[]; uv=[]; faces=[]; rings=[]
    rng=random.Random(5903 if icy else 5901)
    # One vertex at each wing tip avoids degenerate zero-width end faces.
    positions.append((-1,0,.22)); uv.append((0,.5))
    for s in range(1,segments):
        t=-1+2*s/segments; envelope=max(0.0,1-t*t)
        leading=-.45+.67*abs(t)**1.82
        chord=.22*envelope**.66
        center_y=.017*envelope
        ridge=.031*envelope**.62
        if icy:
            leading+=(rng.uniform(-.012,.007))*envelope
            # Controlled broken trailing edge; still thin, never a chunky icon.
            notch=[0.007,-.015,.011,-.009,.036,-.014,.003][s%7]
            chord=(.218+notch)*envelope**.66
            ridge=(.036+rng.uniform(-.006,.007))*envelope**.60
            center_y=.019*envelope+rng.uniform(-.006,.006)*envelope
        ring=[]
        for li,v in enumerate(lanes):
            cross=math.sin(v*math.pi)**.72
            height=center_y+ridge*cross
            if li==0 or li==len(lanes)-1: height=center_y
            idx=len(positions); positions.append((t,height,leading+chord*v)); uv.append(((t+1)/2,v)); ring.append(idx)
        for li in range(len(lanes)-2,0,-1):
            v=lanes[li]; cross=math.sin(v*math.pi)**.72
            idx=len(positions); positions.append((t,center_y-ridge*.86*cross,leading+chord*v)); uv.append(((t+1)/2,v)); ring.append(idx)
        rings.append(ring)
    right=len(positions); positions.append((1,0,.22)); uv.append((1,.5))
    perimeter=len(rings[0])
    for k in range(perimeter): faces.append((0,rings[0][k],rings[0][(k+1)%perimeter]))
    for prev,nxt in zip(rings,rings[1:]):
        for k in range(perimeter): faces.append((prev[k],nxt[k],nxt[(k+1)%perimeter],prev[(k+1)%perimeter]))
    for k in range(perimeter): faces.append((right,rings[-1][(k+1)%perimeter],rings[-1][k]))
    obj=mesh_object(name,positions,faces,uv,icy)
    obj['span_m']=2.; obj['root_pivot']='center of the wave, local origin'; obj['render_hint']='Render shell with supplied normals; UV fade can sharpen the edge further'
    return obj

def shard():
    # Long, flat, off-axis crystal for separately animated shards. Length is +Y.
    rng=random.Random(812); vertices=[]; faces=[]; uv=[]
    profiles=[(-.5,-.028,0,.004),(-.32,-.013,0,.069),(.10,.007,.006,.088),(.29,.023,.004,.056),(.5,.06,.006,.002)]
    n=7
    for j,(y,cx,cz,r) in enumerate(profiles):
        for k in range(n):
            a=math.tau*k/n+.17
            vertices.append((cx+math.cos(a)*r,y,cz+math.sin(a)*r*.51)); uv.append((k/n,(y+.5)))
    faces.append(tuple(range(n-1,-1,-1)))
    for j in range(len(profiles)-1):
        for k in range(n): faces.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
    faces.append(tuple((len(profiles)-1)*n+k for k in range(n)))
    obj=mesh_object('frost_shard',vertices,faces,uv,True)
    obj['long_axis']='Y'; obj['root_pivot']='centered for tumbling'; obj['nominal_length_m']=1.
    return obj

objects=[crescent('normal_crescent',False),crescent('frost_crescent',True),shard()]

def export_obj(obj):
    mesh=obj.data; mesh.calc_loop_triangles(); uv=mesh.uv_layers.active
    coords=[(v.co.x,v.co.z,-v.co.y) for v in mesh.vertices]
    lines=['# Godot basis: +Y up, forward -Z; clean UV mapped sword-wave mesh','o '+obj.name]
    lines.extend('v %.8f %.8f %.8f'%v for v in coords)
    lines.extend('vt %.8f %.8f'%tuple(d.uv) for d in uv.data)
    normals=[]
    for loop in mesh.loops:
        no=mesh.corner_normals[loop.index].vector
        normals.append((no.x,no.z,-no.y))
    lines.extend('vn %.8f %.8f %.8f'%n for n in normals)
    edges=Counter(); volume=0.0; minimum_area=100.; tris=[]
    for tri in mesh.loop_triangles:
        lines.append('f '+' '.join('%d/%d/%d'%(mesh.loops[loop].vertex_index+1,loop+1,loop+1) for loop in tri.loops))
        ids=tuple(tri.vertices); tris.append(ids)
        a,b,c=(Vector(coords[v]) for v in ids)
        area=(b-a).cross(c-a).length*.5; minimum_area=min(minimum_area,area)
        assert area>1e-10,(obj.name,'degenerate face')
        volume+=a.dot(b.cross(c))/6
        for k in range(3): edges[tuple(sorted((ids[k],ids[(k+1)%3])))]+=1
    assert all(count==2 for count in edges.values()),obj.name
    assert volume>0,obj.name
    assert all(math.isfinite(x) for p in coords for x in p)
    path=RUNTIME/(obj.name+'.obj'); path.write_text('\n'.join(lines)+'\n',encoding='utf-8')
    minima=[min(p[k] for p in coords) for k in range(3)]; maxima=[max(p[k] for p in coords) for k in range(3)]
    return {'file':str(path),'name':obj.name,'vertices':len(coords),'triangles':len(tris),'bounds_min':minima,'bounds_max':maxima,'dimensions':[b-a for a,b in zip(minima,maxima)],'closed_manifold':True,'outward_winding':True,'minimum_triangle_area':minimum_area,'volume':volume,'UV':'U=arc parameter, V=leading0/trailing1' if 'crescent' in obj.name else 'U=radial, V=long axis Y','basis':'Y up / forward -Z','pivot':'local center'}

manifest=[export_obj(o) for o in objects]
(SOURCE/'asset_manifest.json').write_text(json.dumps({'assets':manifest,'texture_dependencies':[],'export_method':'manual OBJ with normals and UV; Blender-generated geometry'},indent=2),encoding='utf-8')

# Source studio is separate from the exported local-space meshes.
objects[0].location=(0,.72,.10); objects[1].location=(0,-.70,.10)
objects[2].location=(1.6,-.0,.37); objects[2].rotation_euler=(0,.5,.3); objects[2].scale=(.58,.58,.58)
floor=material('Studio ink',(.014,.02,.03),.06,.58)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.035)); bpy.context.object.name='Studio floor'; bpy.context.object.data.materials.append(floor)
def area(name,pos,power,color,size):
    ld=bpy.data.lights.new(name,'AREA'); ob=bpy.data.objects.new(name,ld); bpy.context.collection.objects.link(ob)
    ob.location=pos; ob.rotation_euler=(Vector((0,0,0))-ob.location).to_track_quat('-Z','Y').to_euler(); ld.energy=power; ld.color=color; ld.size=size
area('Soft overhead',(-2,-1,5),950,(.76,.86,1),4)
area('Icy edge',(2,2,3),1150,(.12,.60,1),3)
area('Gold rim',(-3,2,2),800,(1,.6,.23),3)
cd=bpy.data.cameras.new('Model overview'); cam=bpy.data.objects.new('Model overview',cd); bpy.context.collection.objects.link(cam)
cam.location=(.35,-2.8,6.5); cam.rotation_euler=(Vector((.18,0,.07))-cam.location).to_track_quat('-Z','Y').to_euler(); cd.type='ORTHO'; cd.ortho_scale=4.5
scene=bpy.context.scene; scene.camera=cam; scene.render.engine='CYCLES'; scene.cycles.samples=48; scene.cycles.use_denoising=True
scene.world.color=(.035,.035,.035); scene.render.resolution_x=1500; scene.render.resolution_y=1200; scene.render.resolution_percentage=100; scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'; scene.render.filepath=str(SOURCE/'asset_overview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'sword_wave_models_v001.blend'))
bpy.ops.render.render(write_still=True)
print('ASSET_MANIFEST='+json.dumps(manifest))
