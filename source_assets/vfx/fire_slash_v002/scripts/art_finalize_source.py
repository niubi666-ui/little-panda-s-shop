"""Persist editable sweep animation and restore a visible atlas-source pose."""
import bpy,math
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(BASE/'blender/fire_slash_v002.blend'),load_ui=False,use_scripts=False)
s=bpy.context.scene;arc=bpy.data.objects['FIRE_Main_Arc'];pivot=bpy.data.objects['Sword_Swing_Control'];clusters=bpy.data.objects['FIRE_Worldspace_Clusters']
if arc.data.shape_keys is not None:arc.shape_key_clear()
arc.shape_key_add(name='Basis')
poses=[]
for i in range(11):
    p=i/10;key=arc.shape_key_add(name=f'Sweep_{i:02d}')
    for j,v in enumerate(key.data):
        col=j//33;rad=j%33;u=col/144;vv=rad/32;r=2.2-vv*1.62;a=math.radians(-155+160*p*u)
        v.co=(math.cos(a)*r,math.sin(a)*r,1+.12*math.sin(a*1.2)*vv)
    poses.append(key)
mat=arc.data.materials[0];nodes=mat.node_tree.nodes;links=mat.node_tree.links;mix=next(n for n in nodes if n.type=='MIX_SHADER');source=mix.inputs[0].links[0].from_socket
life=nodes.new('ShaderNodeMath');life.name='SHOT_LIFETIME';life.label='Editable swing tail fade';life.operation='MULTIPLY';links.new(source,life.inputs[0]);links.new(life.outputs[0],mix.inputs[0])
for f in range(1,97):
    cyc=(f-1)%48;t=cyc/47;progress=max(0,min(1,(t-.12)/(.22 if f<=48 else .48)));fade=max(0,min(1,(1-t)/.19))
    pivot.rotation_euler[2]=math.radians(-155+160*progress);pivot.keyframe_insert(data_path='rotation_euler',frame=f)
    coord=progress*10
    for i,key in enumerate(poses):key.value=max(0,1-abs(i-coord));key.keyframe_insert(data_path='value',frame=f)
    arc.hide_render=progress<.025 or fade<.01;arc.keyframe_insert(data_path='hide_render',frame=f)
    life.inputs[1].default_value=fade;life.inputs[1].keyframe_insert(data_path='default_value',frame=f)
    for child in clusters.children:
        i=int(child.name.split('SlashFlame')[1][0]);a=[-129,-100,-69,-40,-17][i]
        child.hide_render=a>(-155+160*progress) or fade<.15;child.keyframe_insert(data_path='hide_render',frame=f)
        material=child.data.materials[0]
        material.node_tree.nodes['FLAME_PHASE'].outputs[0].default_value=f*.075;material.node_tree.nodes['FLAME_PHASE'].outputs[0].keyframe_insert(data_path='default_value',frame=f)
        material.node_tree.nodes['DISSOLVE'].outputs[0].default_value=(1-fade)*.65;material.node_tree.nodes['DISSOLVE'].outputs[0].keyframe_insert(data_path='default_value',frame=f)
s.frame_set(28);s['playback']='Frames 1-48 quick 160-degree swing; 49-96 slower readable sweep; tail dissolves at the end of each cycle.'
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'blender/fire_slash_v002.blend'))
# The atlas source must open in a visible state rather than the transparent last
# output frame. It remains editable and can regenerate all frames via art_build.
bpy.ops.wm.open_mainfile(filepath=str(BASE/'blender/flame_atlas_source.blend'),load_ui=False,use_scripts=False)
for mat in bpy.data.materials:
    if mat.node_tree:
        if 'DISSOLVE' in mat.node_tree.nodes:mat.node_tree.nodes['DISSOLVE'].outputs[0].default_value=.03
        if 'FLAME_PHASE' in mat.node_tree.nodes:mat.node_tree.nodes['FLAME_PHASE'].outputs[0].default_value=.75
for o in bpy.data.objects:
    if o.type=='MESH':o.scale=(1,1,1);o.location.z=0
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'blender/flame_atlas_source.blend'))
print('EDITABLE_SWEEP_AND_ATLAS_SOURCE_READY')
