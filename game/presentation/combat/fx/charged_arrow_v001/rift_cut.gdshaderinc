// Two visual generations: at most 8 active areas plus finite closing tails.
uniform vec4 rift_origins[16];
uniform vec4 rift_paths[16];
uniform sampler2D rift_contours : filter_linear, repeat_disable;
bool inside_rift(vec3 world){
 for(int i=0;i<16;i++){
  vec4 o=rift_origins[i];vec4 d=rift_paths[i];
  if(o.z<=0.0)continue;
  vec2 p=world.xz-o.xy;
  float x=dot(p,d.xy),y=dot(p,vec2(-d.y,d.x));
  float count=float(textureSize(rift_contours,0).x);
  float u=(clamp(x/d.z,0.0,1.0)*(count-1.0)+0.5)/count;
  vec2 c=texture(rift_contours,vec2(u,(float(i)+0.5)/16.0)).rg*o.z;
  if(x>0.0 && x<o.w && abs(y-c.x)<c.y && world.y<d.w+1.0)return true;
 }
 return false;
}
