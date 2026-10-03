Natural breeze GPU preview v001
==============================

Run (from repository root; no Release/export is required):
"E:/GoDot/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe" --path game res://presentation/environment_wind_v001/breeze_preview.tscn

The source asset is res://assets/environment_wind_v001/breeze_samples.glb.
It must already be imported by Godot. This developer preview loads it through
the profile's path; it is not wired into gameplay or a production export.

Controls:
  Space: freeze/resume the wind clock (camera remains available).
  1 / 2 / 3: Gentle / Natural / Stronger wind.
  Tab: cycle all samples and the exported sample root groups.
  Mouse wheel: zoom. Right mouse drag: orbit.
  R: reset wind time to zero. H: show/hide developer labels. Esc: exit.

All adjustable wind/camera parameters are in natural_breeze.tres.
  direction_xz: one shared world-space wind direction.
  sway_amplitude_m: slow tip displacement scale, in metres.
  sway_frequency_hz: two long-period oscillations.
  steady_push_ratio: mean deflection relative to sway amplitude.
  gust_amplitude_m / gust_frequency_hz: weaker, slower gust envelope.
  flutter_amplitude_m / flutter_frequency_hz: small crosswind movement.
  spatial_phase_per_m / instance_phase_spread: spatial phase variation.
  normal_bend_reference_m: reference span for approximate normal/tangent bending.
  strength_levels: three user-selectable multipliers; default index is 1.

Input mesh contract:
  Meshes provide COLOR.r from zero at fixed roots to one at flexible tips.
  The shader squares this weight. COLOR is never multiplied into albedo.
  Actual geometry needs subdivisions along the bend (a shader cannot create
  silhouette segments). Static geometry can carry all-zero weights.
  Supported materials are StandardMaterial3D opaque or alpha scissor (glTF MASK).
  Source albedo color/texture, UV transform, normal texture/scale, roughness,
  metallic, packed texture channels, specular, alpha threshold and cull mode
  are copied into shader parameters. Culling uses one cached shader per mode.
  Unsupported material types or missing weights fail visibly; no fallback
  material conceals an asset contract error.

Implementation:
  GPU vertex displacement uses world XZ direction, spatial/instance phase,
  long sway, weak gust and small flutter. Roots with weight zero do not move.
  One wind_group_origin instance uniform is assigned once to each sample's
  meshes so stems, leaves and attached bells share their plant phase origin.
  An approximate small bend rotation updates normals and tangent frames.
  Godot's cull mode handles back-face normal orientation; the shader does not
  flip it a second time. Normal maps use the engine's normal-map/TBN path.
  CPU geometry is never rebuilt. One ShaderMaterial is cached per source
  material, and per-frame CPU work updates only wind_time on this small set.
  Bounds receive a one-time culling margin for the configured maximum movement.
  Pause freezes the explicit wind_time uniform; the shader does not use TIME.
  No gameplay randomness, autoload, scene switching or class cache is used.

Preview lighting/framing revision after the first Forward+ poster:
  The environment now explicitly uses AMBIENT_SOURCE_COLOR (enum 2), with
  sky contribution zero. The prior enum 3 requested an absent sky resource.
  Ambient energy is 0.60; the main light is near-neutral at 1.10, side fill
  0.35, and a soft low-angle fill 0.16. Main-light shadows remain enabled.
  SSAO radius/intensity are 0.22/0.65 to keep contact detail readable.
  Camera fitting projects each mesh's local AABB corners, avoiding fictitious
  empty corners from a scene-wide AABB. Fit margin is 1.10; the strongest
  wind displacement is included in framing. Focus height is measured within
  the projected frame. Current all-samples orthographic size is about 4.996 m.

Capture helpers (after --):
  --breeze-paused --breeze-time=4.5 --breeze-strength=1 --breeze-focus=0 --breeze-hide-ui
  Strength/focus indices are zero-based; focus zero is all samples.
  Script methods set_wind_time(), set_wind_paused(), set_wind_strength_index()
  and focus_sample() are available to a separate capture harness.

Movie/PNG sequence capture uses Godot's built-in MovieWriter (no extra driver):
  --resolution 1280x800 --write-movie <absolute-output.avi> --fixed-fps 30
  --quit-after 360 res://presentation/environment_wind_v001/breeze_preview.tscn
  -- --breeze-time=0 --breeze-strength=1 --breeze-hide-ui
  Use .png instead of .avi for a PNG sequence. Do not use --headless for pixels.
  Actual sample focus indices: 0 all, 1 Bellflower, 2 Fern, 3 OakCluster.

Validation on 2026-10-02:
  Godot 4.7.2 headless --check-only: preview script parsed with exit code 0.
  breeze_smoke_check.gd: failures=0. Checked source material parameters,
  all three cull modes (including headless shader uniform metadata parsing),
  shared clock pause/resume and strength changes.
  Run this narrow check with --headless --path game --script
  res://presentation/environment_wind_v001/breeze_smoke_check.gd.
  breeze_asset_check.gd checks the imported GLB, actual weights/materials,
  three shared group phase origins, all focus bounds and frozen host time.
  Actual imported asset check: failures=0; 6 meshes / 12 surfaces / 7 shared
  wind materials / three groups. There are 255 zero-weight vertices and
  17,355 flexible vertices. All four focus bounds fit the preview viewport.
  Both canopy materials import as MASK with threshold 0.42; atlas normal
  scale is 0.72. An initial material-name suffix that forced alpha blending
  was removed by the asset exporter, and the corrected asset was reimported.
  The integrator recorded 240 Forward+ frames before the lighting/framing
  correction. The current lighting/framing revision passes both headless
  checks, including explicit ambient enum and all mesh-frame corner checks;
  its GPU visual result still needs to be recorded by the integrating task.
  Headless checks do not prove GPU shader rendering or subjective wind quality.
  Forward+ visual checks and video capture are the integrating task's responsibility.
