"""Reproducible Blender source for the elemental eruption presentation assets.
Run: blender --background --factory-startup --python this_file.py
OBJ files use +Y up, unit height and a root pivot; no external texture dependencies.
"""
import bpy, bmesh, math, random, json
from pathlib import Path
from mathutils import Vector

SOURCE = Path(__file__).resolve().parent
# Resolve project from source_assets/vfx/<set>/models.
RUNTIME = SOURCE.parents[3] / 'game' / 'assets' / 'vfx' / 'elemental_eruptions_v001' / 'models'
SOURCE.mkdir(parents=True, exist_ok=True)
RUNTIME.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def mat(name, rgb, metal, rough):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*rgb, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    return m

ice_mats = [mat('Ice_facets_%02d' % i, (0.055+k*0.16, 0.34+k*0.29, 0.57+k*0.32), .34, .2) for i,k in enumerate([0.0,.28,.5,.74,1.0])]
rock_mats = [mat('Basalt_layers_%02d' % i, (0.09+k*.105,.07+k*.085,.054+k*.065), .12, .67) for i,k in enumerate([0.0,.25,.5,.72,1.0])]

def column(verts, faces, n, rings, rng, phase=0.0, twist=0.0, oval=1.0, triangulate=False):
    """rings: z,cx,cy,radius. Independent radii make fractured faceted columns."""
    start = len(verts)
    corner_bias = [rng.uniform(.83,1.13) for _ in range(n)]
    for ri,(z,cx,cy,r) in enumerate(rings):
        for j in range(n):
            a = phase + j*math.tau/n + twist*ri
            radial = r*corner_bias[j]*rng.uniform(.97,1.03)
            verts.append((cx+math.cos(a)*radial,cy+math.sin(a)*radial*oval,z))
    faces.append(tuple(start+j for j in range(n-1,-1,-1)))
    for ri in range(len(rings)-1):
        for j in range(n):
            a=start+ri*n+j; b=start+ri*n+(j+1)%n
            c=start+(ri+1)*n+(j+1)%n; d=start+(ri+1)*n+j
            if triangulate and (ri+j)%3 == 0:
                faces.extend([(a,b,c),(a,c,d)])
            else:
                faces.append((a,b,c,d))
    faces.append(tuple(start+(len(rings)-1)*n+j for j in range(n)))

def create(name, seed, variant, kind):
    rng=random.Random(seed); verts=[]; faces=[]
    if kind=='ice':
        # A long chisel point, offset planes and short secondary splinters.
        lean=[(.12,-.03),(-.17,.05),(.22,.05)][variant]
        lx,ly=lean; n=[7,8,6][variant]
        column(verts,faces,n,[(0,0,0,.22),(.10,.0,.0,.255),(.38,lx*.24,ly*.25,.235),(.74,lx*.72,ly*.70,.172),(.92,lx*.9,ly*.9,.065),(1.0,lx,ly,.002)],rng,.12+variant*.55,.025, .73, True)
        for j in range(3):
            a=variant*.7+j*math.tau/3
            bx=math.cos(a)*.19; by=math.sin(a)*.16
            h=[.45,.61,.34][j]+variant*.02
            dx=math.cos(a)*.13; dy=math.sin(a)*.10
            column(verts,faces,5,[(.012,bx,by,.105),(.13,bx+dx*.2,by+dy*.2,.11),(h*.76,bx+dx*.8,by+dy*.8,.065),(h,bx+dx,by+dy,.002)],rng,a,.03,.77,True)
    elif kind=='rock':
        # Broken sediment/basalt wedges. Neck changes alternate to form real ledges.
        n=[7,8,7][variant]; lx=[.24,-.16,.13][variant]
        column(verts,faces,n,[(0,0,0,.30),(.12,.025,0,.33),(.15,.03,0,.285),(.36,lx*.32,.005,.27),(.40,lx*.39,.005,.245),(.67,lx*.69,.01,.205),(.72,lx*.78,.01,.17),(.91,lx,.015,.07),(1.0,lx+.08,.03,.006)],rng,.3+variant*.39,.008,.67,True)
        for j in range(2):
            a=variant+j*2.9
            bx=math.cos(a)*.23; by=math.sin(a)*.17
            h=.34+j*.09
            column(verts,faces,5,[(.0,bx,by,.135),(.16,bx*.94,by*.97,.12),(h,bx+.10,by*.95,.02)],rng,a,.08,.76,True)
    else:
        # Chunk silhouettes are oblique prisms rather than spheres.
        column(verts,faces,6,[(0,-.1,0,.24),(.19,-.025,0,.42),(.64,.1,-.015,.33),(1,.17,.02,.045)],rng,.2,.16,.68,True)
    mesh=bpy.data.meshes.new(name+'_mesh'); mesh.from_pydata(verts,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active=obj; obj.select_set(True)
    bm=bmesh.new(); bm.from_mesh(mesh); bmesh.ops.recalc_face_normals(bm,faces=bm.faces); bm.to_mesh(mesh); bm.free()
    if kind=='rock':
        bevel=obj.modifiers.new('Shallow fracture bevel','BEVEL'); bevel.width=.006; bevel.segments=1; bevel.affect='EDGES'; bevel.limit_method='ANGLE'; bevel.angle_limit=.50
        bpy.ops.object.modifier_apply(modifier=bevel.name)
    mesh=obj.data
    zmin=min(v.co.z for v in mesh.vertices); zmax=max(v.co.z for v in mesh.vertices)
    scale=1/(zmax-zmin)
    for v in mesh.vertices:
        v.co.z=(v.co.z-zmin)*scale; v.co.x*=scale; v.co.y*=scale
    # Normalize horizontal span to retain a useful broad hero silhouette.
    span=max(max(v.co.x for v in mesh.vertices)-min(v.co.x for v in mesh.vertices),max(v.co.y for v in mesh.vertices)-min(v.co.y for v in mesh.vertices))
    xy_scale=min(1.0,.78/span)
    for v in mesh.vertices: v.co.x*=xy_scale; v.co.y*=xy_scale
    materials=ice_mats if name.startswith('ice') else rock_mats
    for m in materials: mesh.materials.append(m)
    for p in mesh.polygons:
        p.use_smooth=False
        p.material_index=rng.randrange(len(materials))
    obj['asset_role']='eruption_mesh' if 'spire' in name else 'particle_chunk'
    obj['source_up']='Z'; obj['export_up']='Y'; obj['nominal_height_m']=1.0
    obj['root_pivot']='ground center'; obj['runtime_material']='overridden by presentation shader'
    obj.select_set(False)
    return obj

objects=[]
for i in range(3): objects.append(create('ice_spire_%02d'%(i+1),180+i,i,'ice'))
for i in range(3): objects.append(create('rock_spire_%02d'%(i+1),220+i,i,'rock'))
objects.append(create('ice_chip',801,0,'chip'))
objects.append(create('rock_chip',802,0,'chip'))

def export_obj(obj):
    mesh=obj.data; mesh.calc_loop_triangles()
    p=RUNTIME/(obj.name+'.obj')
    # This basis has determinant +1; winding is preserved. Blender Z -> Godot Y.
    lines=['# Elemental eruptions v001; generated in Blender; +Y up, height 1, root pivot','o '+obj.name]
    coords=[(v.co.x,v.co.z,-v.co.y) for v in mesh.vertices]
    lines.extend('v %.7f %.7f %.7f'%v for v in coords)
    for tri in mesh.loop_triangles:
        normal=tri.normal
        lines.append('vn %.7f %.7f %.7f'%(normal.x,normal.z,-normal.y))
    for i,tri in enumerate(mesh.loop_triangles):
        lines.append('f '+' '.join('%d//%d'%(j+1,i+1) for j in tri.vertices))
    p.write_text('\n'.join(lines)+'\n',encoding='utf-8')
    return {'name':obj.name,'vertices':len(mesh.vertices),'triangles':len(mesh.loop_triangles),'up_axis':'Y','bounds_min':[round(min(v[i] for v in coords),6) for i in range(3)],'bounds_max':[round(max(v[i] for v in coords),6) for i in range(3)],'obj':str(p)}

manifest=[export_obj(o) for o in objects]
(SOURCE/'asset_manifest.json').write_text(json.dumps({'generator':'Blender Python / deterministic geometry','unit_height':1,'pivot':'ground root','runtime_material_override':True,'assets':manifest},indent=2),encoding='utf-8')

# A studio overview is included in the source .blend, separate from the runtime OBJ.
for i,o in enumerate(objects):
    if i<3: o.location=((i-1)*1.35,.85,0)
    elif i<6: o.location=((i-4)*1.35,-.65,0)
    else: o.location=((i-6)*1.1-.55,-1.65,0); o.scale=(.42,.42,.42)
groundmat=mat('Studio charcoal',(0.017,.024,.034),.0,.62)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.025)); bpy.context.object.name='Studio_Backdrop'; bpy.context.object.data.materials.append(groundmat)
def area(name,pos,energy,color,size):
    ld=bpy.data.lights.new(name,'AREA'); lo=bpy.data.objects.new(name,ld); bpy.context.collection.objects.link(lo); lo.location=pos; lo.rotation_euler=(Vector((0,0,.35))-lo.location).to_track_quat('-Z','Y').to_euler(); ld.energy=energy; ld.color=color; ld.shape='DISK'; ld.size=size
area('Cool key',(-3,-4,6),1000,(.62,.83,1),5)
area('Glacial rim',(2,3,4),1250,(.22,.71,1),3)
area('Amber rock fill',(-3,-1,2),650,(1,.61,.30),3)
camera_data=bpy.data.cameras.new('Asset inspection'); camera=bpy.data.objects.new('Asset inspection',camera_data); bpy.context.collection.objects.link(camera); camera.location=(3,-6,4.3); camera.rotation_euler=(Vector((0,0,.42))-camera.location).to_track_quat('-Z','Y').to_euler(); camera_data.type='ORTHO'; camera_data.ortho_scale=5.6
scene=bpy.context.scene; scene.camera=camera; scene.render.engine='CYCLES'; scene.cycles.samples=48; scene.cycles.use_denoising=True
scene.world.color=(.055,.055,.055); scene.render.resolution_x=1600; scene.render.resolution_y=1200; scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'; scene.render.image_settings.file_format='PNG'; scene.render.filepath=str(SOURCE/'asset_overview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'elemental_eruption_models_v001.blend'))
bpy.ops.render.render(write_still=True)
print('ASSET_MANIFEST='+json.dumps(manifest))
