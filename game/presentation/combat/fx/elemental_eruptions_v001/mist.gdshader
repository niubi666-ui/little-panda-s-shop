shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color;
uniform vec4 highlight : source_color;
uniform float opacity;
uniform float progress;
uniform float particle_seed;
uniform float luminous;
varying vec2 sprite_uv;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);
 MODELVIEW_NORMAL_MATRIX=mat3(MODELVIEW_MATRIX);
 sprite_uv=UV;
}
void fragment(){
 vec2 p=sprite_uv*2.0-1.0;
 vec2 q=p*2.6+vec2(particle_seed,progress*0.9);
 float n=noise(q)*0.55+noise(q*2.13)*0.3+noise(q*4.27)*0.15;
 float r=length(p*vec2(0.88,1.1));
 float body=1.0-smoothstep(0.27,0.94,r+(n-0.5)*0.45);
 float wisps=smoothstep(0.15,0.9,n);
 float life=smoothstep(0.0,0.12,progress)*(1.0-smoothstep(0.35,1.0,progress));
 ALBEDO=mix(tint.rgb,highlight.rgb,n*0.7+(1.0-UV.y)*0.2);
 EMISSION=highlight.rgb*luminous*body*0.2;
 ALPHA=body*wisps*life*opacity;
}
