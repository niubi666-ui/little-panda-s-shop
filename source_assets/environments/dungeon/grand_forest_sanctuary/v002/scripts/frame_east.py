import bpy
from mathutils import Vector
cam=bpy.data.objects['Camera_East_Gateway']
cam.location=(24,9.75,19);cam.rotation_euler=(Vector((-2,5,1))-cam.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
