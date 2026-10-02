"""Blender-only sanctuary assembly. All numbers are art authoring dimensions in metres.
Run in a fresh background process; original library and Godot files remain read-only.
"""
import bpy, bmesh, math, random, json, sys, hashlib
from pathlib import Path
from mathutils import Vector, Matrix
import numpy as np
BASE=Path('E:/ShopGame/source_assets/environments/dungeon/grand_forest_sanctuary/v002')
SOURCE=BASE/'original/forest_yard_item.blend'
SHARED=Path('E:/ShopGame/source_assets/environments/dungeon/shared/scripts')
sys.path.insert(0,str(SHARED))
from room_kit import Kit,enum
from room_foliage import _Geometry,_leaf,fern,flower_patch
assert bpy.app.background
kit=Kit('grand_forest_sanctuary/v002',270929); s=kit.scene; rng=random.Random(270929)
s.name='Grand_Forest_Sanctuary_36x32m_v002'
inventory=json.loads((BASE/'reports/source_inventory.json').read_text(encoding='utf-8'))
INDEX={'rail':0,'broken_wall':1,'corner':2,'pier':3,'bridge':4,'chest':5,'mushrooms':6,'hive':7,'stump':8,'low_wall':9,'low_corner':10,'stone_chest':11,'bag':12,'fallen_column':13,'barrel':14,'crate':15,'moss_patch':16,'moss_cushion':17,'moss_seam':18,'litter':19,'oak':21,'ivy':22,'flowerpot':23,'white_flower':24,'purple_flower':25,'steps':26,'rock_flat':27,'roundel':28,'rock_medium':29,'rock_large':30,'paving':31,'curb':32,'statue':33,'shrine':34}
IDS={k:inventory['objects'][v]['name'] for k,v in INDEX.items()}
with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst):dst.objects=list(IDS.values())
loaded={o.name:o for o in dst.objects}; proto={};sizes={};use={k:0 for k in IDS}
for key,name in IDS.items():
 o=loaded[name];me=o.data.copy()
 rotation=Matrix.Rotation(-math.pi/2,4,'Y') if key=='roundel' else Matrix.Rotation(-math.pi/2,4,'Z')
 me.transform(rotation);me.update()
 low=Vector([min(v.co[a] for v in me.vertices) for a in range(3)]);high=Vector([max(v.co[a] for v in me.vertices) for a in range(3)])
 me.transform(Matrix.Translation(-Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))));me.update()
 sizes[key]=high-low;me.name='FY_'+key+'_shared';proto[key]=me
 bpy.data.objects.remove(o,do_unlink=True)

def asset(key,name,loc,dim=None,height=None,angle=0,group='Architecture'):
 o=bpy.data.objects.new(name,proto[key]);kit.collection(group).objects.link(o);o.location=loc;o.rotation_euler.z=angle
 if dim:o.scale=tuple(dim[a]/sizes[key][a] for a in range(3))
 elif height:o.scale=(height/sizes[key].z,)*3
 o['source_file']='forest_yard_item.blend';o['source_object']=IDS[key];o['asset_role']=key;use[key]+=1
 return o
def pbr(m):return next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
for key,me in proto.items():
 for i,source_mat in enumerate(list(me.materials)):
  m=source_mat.copy();me.materials[i]=m;m.name='Sanctuary_'+key+'_PBR';p=pbr(m);n=m.node_tree.nodes;l=m.node_tree.links
  for link in list(p.inputs['Normal'].links):l.remove(link)
  tex=n.new('ShaderNodeTexCoord');noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=110;noise.inputs['Detail'].default_value=3;l.new(tex.outputs['Generated'],noise.inputs['Vector'])
  bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.19;bump.inputs['Distance'].default_value=.004;l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal']);p.inputs['Roughness'].default_value=.76
  if key in ['white_flower','purple_flower','ivy']:
   p.inputs['Roughness'].default_value=.66
   out=next(x for x in n if x.type=='OUTPUT_MATERIAL');tr=n.new('ShaderNodeBsdfTranslucent');l.new(p.inputs['Base Color'].links[0].from_socket,tr.inputs[0]);mix=n.new('ShaderNodeMixShader');mix.inputs[0].default_value=.12;l.new(p.outputs[0],mix.inputs[1]);l.new(tr.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs['Surface'])

exec((BASE/'scripts/assembly.py').read_text(encoding='utf-8'))
