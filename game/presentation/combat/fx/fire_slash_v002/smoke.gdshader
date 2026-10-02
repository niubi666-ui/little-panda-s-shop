shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 smoke_tint : source_color;
uniform float opacity;
varying float age;
float hash21(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float cloud(vec2 p){
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash21(i),hash21(i+vec2(1.0,0.0)),f.x),mix(hash21(i+vec2(0.0,1.0)),hash21(i+vec2(1.0)),f.x),f.y);
}
void vertex(){
    vec3 s=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
    MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*s.x,INV_VIEW_MATRIX[1]*s.y,INV_VIEW_MATRIX[2]*s.z,MODEL_MATRIX[3]);
    MODELVIEW_NORMAL_MATRIX=mat3(MODELVIEW_MATRIX);
    float a=INSTANCE_CUSTOM.x;
    VERTEX.xy=mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)))*VERTEX.xy;
    age=INSTANCE_CUSTOM.y;
}
void fragment(){
    vec2 p=(UV-0.5)*2.0;
    float n=cloud(UV*7.0+vec2(age*2.0,-age*3.0));
    float mask=(1.0-smoothstep(0.35,1.0,length(p)+n*0.24))*smoothstep(0.15,0.7,n);
    float envelope=smoothstep(0.12,0.32,age)*(1.0-smoothstep(0.58,1.0,age));
    ALBEDO=smoke_tint.rgb;
    ALPHA=mask*envelope*opacity*COLOR.a;
}
