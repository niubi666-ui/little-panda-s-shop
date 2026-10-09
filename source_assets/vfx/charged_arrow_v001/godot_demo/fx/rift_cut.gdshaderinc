uniform bool rift_active;
uniform vec2 rift_origin;
uniform vec2 rift_direction;
uniform float rift_travel;
uniform float rift_half_width;
uniform sampler2D rift_contour : filter_linear, repeat_disable;
uniform float rift_length;
bool inside_rift(vec3 world){
 if(!rift_active)return false;
 vec2 p=world.xz-rift_origin;
 float x=dot(p,rift_direction);
 float y=dot(p,vec2(-rift_direction.y,rift_direction.x));
 float count=float(textureSize(rift_contour,0).x);
 float u=(clamp(x/rift_length,0.0,1.0)*(count-1.0)+0.5)/count;
 vec2 contour=texture(rift_contour,vec2(u,0.5)).rg*rift_half_width;
 return x>0.0 && x<rift_travel && abs(y-contour.x)<contour.y && world.y<1.0;
}
