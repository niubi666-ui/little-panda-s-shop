shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color;
uniform float energy;
uniform float opacity;
uniform float visual_time;
uniform float edge_power;
uniform float grain_frequency;
void fragment() {
 vec2 uv = clamp(UV, vec2(0.0), vec2(1.0));
 float edge = pow(max(0.0, 1.0 - abs(uv.y * 2.0 - 1.0)), edge_power);
 float grain = 0.78 + 0.22 * sin(uv.x * grain_frequency - visual_time * 20.0);
 ALBEDO = tint.rgb * energy;
 ALPHA = edge * grain * opacity * COLOR.a;
}
