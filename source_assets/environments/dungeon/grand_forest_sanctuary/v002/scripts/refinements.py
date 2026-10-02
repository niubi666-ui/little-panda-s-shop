"""Final corner shaping and local background sunlight; operates only on v002."""
import bmesh
from mathutils import Vector
planes=[((-12,-16,0),(1,1,0)),((12,-16,0),(-7,6,0)),((14,16,0),(-1,-1,0))]
for ob in list(s.objects):
 if not ob.name.startswith('Court_flagstones_'):continue
 bpy.context.view_layer.update()
 if all(all((ob.matrix_world@Vector(c)-Vector(co)).dot(Vector(no))>=-.001 for c in ob.bound_box) for co,no in planes):continue
 me=ob.data.copy();me.transform(ob.matrix_world);bm=bmesh.new();bm.from_mesh(me)
 for co,no in planes:bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=co,plane_no=no,clear_inner=True,dist=.00001)
 bm.to_mesh(me);bm.free();me.update();ob.data=me;ob.matrix_world=Matrix.Identity(4)
foundation=bpy.data.objects.get('Court_foundation_36x32')
if foundation:bpy.data.objects.remove(foundation,do_unlink=True)
outline=[(-12,-16),(12,-16),(18,-9),(18,12),(14,16),(-18,16),(-18,-10)]
kit.mesh('Shaped_court_mortar_foundation',[(x,y,-.095) for x,y in outline],[tuple(range(len(outline)))],'mortar','Ground')
# Warm shafts behind the oak. Real shadowed spot lights interacting with scene haze.
for i in range(3):
 o=kit.light('Forest_canopy_sunshaft_'+str(i),'SPOT',(-19+i*3,15+i,19),(1,.78,.39),6500,.10,(-10+i*3,0,0))
 o.data.spot_size=.30;o.data.spot_blend=.42
kit.light('Oak_warm_rim_bounce','AREA',(-13,14,16),(1,.78,.38),1600,7,(-12,6,6))
