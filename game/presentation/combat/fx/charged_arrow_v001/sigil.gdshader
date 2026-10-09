shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color;
uniform float energy;
uniform float opacity;
uniform float time_value;
uniform float spin_speed;
uniform float rune_count;
uniform float radial_width;
void fragment() {
 vec2 p=(clamp(UV,vec2(0.0),vec2(1.0))-0.5)*2.0;
 float r=length(p);
 float a=atan(p.y,p.x)+time_value*spin_speed;
 float outer=exp(-abs(r-0.87)*radial_width);
 float inner=exp(-abs(r-0.67)*radial_width)*0.45;
 float dotted=step(0.40,fract((a/6.2831853+1.0)*rune_count));
 float rune=exp(-abs(r-0.76)*radial_width*0.5)*pow(abs(cos(a*rune_count*0.5)),20.0);
 float cross=exp(-abs(p.x)*radial_width)*step(0.6,abs(p.y));
 ALBEDO=tint.rgb*energy;
 ALPHA=(outer*dotted+inner+rune*0.65+cross*0.3)*opacity*COLOR.a;
}
