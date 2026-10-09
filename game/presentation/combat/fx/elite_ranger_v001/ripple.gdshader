shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color;
uniform float energy;
uniform float progress;
uniform float brokenness;
uniform vec2 area_center;
uniform float area_radius;
varying vec3 world_point;
void vertex(){ world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 vec2 p=(clamp(UV,vec2(0.0),vec2(1.0))-0.5)*2.0;
 float r=length(p);float a=atan(p.y,p.x);
 float radius=mix(0.12,0.87,progress);
 float wobble=sin(a*13.0+progress*10.0)*0.012+sin(a*29.0)*0.008;
 float line=exp(-pow((r-radius+wobble)/0.018,2.0));
 float skirt=exp(-pow((r-radius+0.065)/0.07,2.0))*0.32;
 float cuts=mix(1.0,smoothstep(-0.6,0.4,sin(a*9.0+r*32.0)),brokenness);
 float glow=(line+skirt)*pow(1.0-progress,1.3)*cuts;
 if(area_radius>0.0)glow*=step(length(world_point.xz-area_center),area_radius);
 ALBEDO=tint.rgb*energy;
 ALPHA=glow*tint.a;
}
