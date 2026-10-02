import bpy,json
p='E:/ShopGame/source_assets/environments/dungeon/sunlit_forest_court/tree_foliage_v005/blender/sacred_oak_balanced_v005.blend'
with bpy.data.libraries.load(p,link=False) as (a,b):b.objects=[n for n in a.objects if n=='SacredOak_Trunk_Preserved' or n.startswith('BakedCrownCluster_')]
for o in b.objects:bpy.context.scene.collection.objects.link(o)
bpy.context.view_layer.update()
for o in b.objects[:3]+b.objects[-1:]:print(o.name,'loc',list(o.location),'scale',list(o.scale),'basis',list(o.matrix_basis),'world',list(o.matrix_world),'parent',o.parent,'hide',o.hide_render)
