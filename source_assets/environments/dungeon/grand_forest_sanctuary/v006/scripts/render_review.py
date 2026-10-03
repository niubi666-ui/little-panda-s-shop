"""Render the saved v006 lighting version without changing the .blend file."""
import bpy, json, sys, time
from pathlib import Path

assert bpy.app.background
root = Path(__file__).resolve().parents[1]
assert Path(bpy.data.filepath).resolve() == (root / 'blender/grand_forest_sanctuary_v006_golden_canopy.blend').resolve()
scene = bpy.context.scene
prefs = bpy.context.preferences.addons['cycles'].preferences
prefs.compute_device_type = 'OPTIX'
prefs.refresh_devices()
for device in prefs.devices:
    device.use = device.type == 'OPTIX'
scene.cycles.device = 'GPU'
scene.cycles.samples = 96
scene.cycles.use_adaptive_sampling = True
scene.cycles.adaptive_threshold = .025
scene.cycles.use_denoising = True
scene.render.use_persistent_data = True
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.frame_set(1)
jobs = [
    ('CYCLES', 'Camera_Panorama', 'sanctuary_v006_overview', 1800, 1238),
    ('CYCLES', 'Camera_Gameplay', 'sanctuary_v006_gameplay', 1920, 1080),
    ('CYCLES', 'Camera_V005_Shrine_Gateway', 'sanctuary_v006_shrine_gateway', 1800, 1100),
    ('BLENDER_EEVEE', 'Camera_Gameplay', 'sanctuary_v006_eevee_gameplay', 1600, 900),
]
if '--eevee' in sys.argv:
    jobs = [job for job in jobs if job[0] == 'BLENDER_EEVEE']
results = []
for engine, camera, name, width, height in jobs:
    started = time.perf_counter()
    scene.render.engine = engine
    scene.eevee.taa_render_samples = 96
    scene.camera = scene.objects[camera]
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.filepath = str(root / 'previews' / (name + '.png'))
    bpy.ops.render.render(write_still=True)
    result = dict(image=name + '.png', engine=engine, camera=camera,
                  width=width, height=height, frame=1,
                  samples=96, seconds=round(time.perf_counter() - started, 2))
    results.append(result)
    print('REVIEW_RENDER', json.dumps(result), flush=True)
(root / 'reports/render_review.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
