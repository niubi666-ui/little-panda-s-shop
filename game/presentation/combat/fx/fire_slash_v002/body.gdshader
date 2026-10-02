shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D emission_0 : filter_linear_mipmap, repeat_disable;
uniform sampler2D emission_1 : filter_linear_mipmap, repeat_disable;
uniform sampler2D emission_2 : filter_linear_mipmap, repeat_disable;
uniform sampler2D emission_3 : filter_linear_mipmap, repeat_disable;
uniform sampler2D mask_0 : filter_linear_mipmap, repeat_disable;
uniform sampler2D mask_1 : filter_linear_mipmap, repeat_disable;
uniform sampler2D mask_2 : filter_linear_mipmap, repeat_disable;
uniform sampler2D mask_3 : filter_linear_mipmap, repeat_disable;
uniform float frame_phase;
uniform float energy_scale;
uniform float opacity;
void fragment() {
    // Blender bake V=0 is the tip. Saved images place that row at the bottom.
    // Runtime tip is UV.y=1, so this bake uses native texture V, without a second flip.
    vec2 uv=UV;
    // Ping-pong phases preserve the source animated noise without a loop seam.
    float phase=3.0-abs(mod(frame_phase,6.0)-3.0);
    vec3 e0=texture(emission_0,uv).rgb;
    vec3 e1=texture(emission_1,uv).rgb;
    vec3 e2=texture(emission_2,uv).rgb;
    vec3 e3=texture(emission_3,uv).rgb;
    float m0=texture(mask_0,uv).r;
    float m1=texture(mask_1,uv).r;
    float m2=texture(mask_2,uv).r;
    float m3=texture(mask_3,uv).r;
    vec3 radiance; float coverage;
    if(phase<1.0){radiance=mix(e0,e1,phase);coverage=mix(m0,m1,phase);}
    else if(phase<2.0){radiance=mix(e1,e2,phase-1.0);coverage=mix(m1,m2,phase-1.0);}
    else{radiance=mix(e2,e3,phase-2.0);coverage=mix(m2,m3,phase-2.0);}
    ALBEDO=radiance*energy_scale;
    EMISSION=vec3(0.0);
    ALPHA=clamp(coverage*COLOR.a*opacity,0.0,1.0);
}
