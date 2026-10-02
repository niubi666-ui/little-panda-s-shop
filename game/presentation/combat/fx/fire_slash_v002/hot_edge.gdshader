shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 hot_color : source_color;
uniform vec4 edge_color : source_color;
uniform float edge_position;
uniform float edge_width;
uniform float energy;
uniform float height_offset;
uniform float heat_phase;
uniform float breakup_amount;
uniform float fade_exponent;
void vertex(){ VERTEX.y += height_offset; }
void fragment(){
    float ripple = sin(UV.x * 53.0 + heat_phase * 13.0) * sin(UV.x * 19.0 - heat_phase * 7.0);
    float distance_to_edge = abs(UV.y - edge_position - ripple * breakup_amount);
    float rim = 1.0 - smoothstep(edge_width, edge_width * 3.0, distance_to_edge);
    float core = 1.0 - smoothstep(0.0, edge_width, distance_to_edge);
    float tail = smoothstep(0.0, 0.22, UV.x);
    ALBEDO = mix(edge_color.rgb, hot_color.rgb, core) * energy;
    ALPHA = rim * tail * pow(COLOR.a, fade_exponent);
}
