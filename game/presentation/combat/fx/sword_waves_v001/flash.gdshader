shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color;
uniform float progress;
uniform float energy;
void vertex(){
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);
 MODELVIEW_NORMAL_MATRIX=mat3(MODELVIEW_MATRIX);
}
void fragment(){
 vec2 p=(UV-0.5)*2.0;
 float radius=length(p);
 float core=exp(-radius*radius*34.0);
 float streak=exp(-abs(p.y)*40.0)*exp(-abs(p.x)*2.6);
 float flare=exp(-abs(p.x+p.y*0.45)*55.0)*exp(-abs(p.y)*4.0);
 ALBEDO=tint.rgb; EMISSION=tint.rgb*energy;
 ALPHA=(core+streak*0.48+flare*0.28)*pow(1.0-progress,2.0);
}
