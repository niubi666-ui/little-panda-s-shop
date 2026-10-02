shader_type spatial;

render_mode unshaded,world_vertex_coords,cull_disabled;

uniform sampler2D tex : repeat_enable, source_color, hint_default_white;
uniform sampler2D mask : hint_default_white;
uniform float mask_strength = 1.0;
uniform vec2 uv_offset = vec2(0);
uniform sampler2D color_ramp : repeat_disable, source_color, hint_default_white;
uniform sampler2D curve : repeat_disable, hint_default_white;
uniform mat4 emmission_transform = mat4(1);
uniform int flags = 0;
/*uniform bool vertical_texture = false;
uniform bool use_red_as_alpha = false;
uniform bool billboard = false;
uniform bool dewiggle = false;
uniform bool snap_to_transform = false;*/

#define vertical_texture  bool(flags & 1)
#define use_red_as_alpha  bool(flags & 2)
#define billboard		  bool(flags & 4)
#define dewiggle 		  bool(flags & 8)
#define snap_to_transform bool(flags & 16)
#define clip_overlaps bool(flags & 32)


varying float scale_interp;
varying vec2 clip;
varying vec2 mesh_uv;
void vertex(){
	mesh_uv = UV;

	mat4 my_model_matrix = MODEL_MATRIX;
	if(snap_to_transform && INSTANCE_CUSTOM.w==2.0){
		my_model_matrix[1] = emmission_transform * vec4(0,1,0,1);
		my_model_matrix[2] = emmission_transform * vec4(0,-1,0,1);
	}

	if(billboard){
		vec3 t0 = my_model_matrix[0].xyz-my_model_matrix[3].xyz;
		vec3 t1 = my_model_matrix[1].xyz-my_model_matrix[2].xyz;

		//vec3 up1 = up0;
		vec3 up0 = length(t0)*normalize(
			cross(
				my_model_matrix[3].xyz-INV_VIEW_MATRIX[3].xyz,
				//-INV_VIEW_MATRIX[2].xyz,
				t0));
		vec3 up1 = length(t1)*normalize(
			cross(
				my_model_matrix[2].xyz-INV_VIEW_MATRIX[3].xyz,
				//-INV_VIEW_MATRIX[2].xyz,
				t1));

		my_model_matrix[0] = my_model_matrix[3];
		my_model_matrix[1] = my_model_matrix[2];

		my_model_matrix[0].xyz += up0;
		my_model_matrix[3].xyz -= up0;

		my_model_matrix[1].xyz += up1;
		my_model_matrix[2].xyz -= up1;
	}

	vec3 a = mix(my_model_matrix[1].xyz,my_model_matrix[0].xyz,UV.x);
	vec3 b = mix(my_model_matrix[2].xyz,my_model_matrix[3].xyz,UV.x);

	UV.x = (UV.x + INSTANCE_CUSTOM.w-1.0 - 2.0)/(INSTANCE_CUSTOM.z-1.0);

	float h = textureLod(curve, vec2(UV.x), 0.0).x;//h=1.0;

	VERTEX = mix(a,b,(UV.y-0.5)*h + 0.5);

	if(dewiggle){
		scale_interp = h;
		UV *= scale_interp;
	}


	clip.x = dot(VERTEX - INV_VIEW_MATRIX[3].xyz,cross(my_model_matrix[1].xyz - INV_VIEW_MATRIX[3].xyz,my_model_matrix[2].xyz - INV_VIEW_MATRIX[3].xyz));
	clip.y = dot(VERTEX - INV_VIEW_MATRIX[3].xyz,cross(my_model_matrix[3].xyz - INV_VIEW_MATRIX[3].xyz,my_model_matrix[0].xyz - INV_VIEW_MATRIX[3].xyz));
}


uniform vec4 core_color : source_color;
uniform vec4 fire_color : source_color;
uniform vec4 edge_color : source_color;
uniform float energy;
uniform float core_width;
uniform float flame_speed;
uniform vec2 flame_frequency;
uniform float effect_opacity;
uniform float flame_time;
float hash_fire(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise_fire(vec2 p) {
    vec2 cell=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash_fire(cell),hash_fire(cell+vec2(1,0)),f.x),mix(hash_fire(cell+vec2(0,1)),hash_fire(cell+vec2(1,1)),f.x),f.y);
}
void fragment() {
    vec2 uv=UV;
    float n=noise_fire(vec2(uv.x*flame_frequency.x-flame_time*flame_speed,uv.y*flame_frequency.y));
    float n2=noise_fire(vec2(uv.x*flame_frequency.x*2.0+flame_time,uv.y*flame_frequency.y*2.0));
    float outer=0.86+0.14*n;
    float body=smoothstep(0.08,0.35,uv.y)*(1.0-smoothstep(outer-0.08,outer,uv.y));
    float ribs=smoothstep(0.22,0.72,n*0.75+n2*0.25);
    float core=exp(-pow((uv.y-0.82)/core_width,2.0));
    float along=smoothstep(0.0,0.18,uv.x)*smoothstep(1.0,0.90,uv.x);
    vec3 fire=mix(edge_color.rgb,fire_color.rgb,ribs);
    fire=mix(fire,core_color.rgb,clamp(core+pow(ribs,4.0)*0.28,0.0,1.0));
    ALBEDO=fire;
    EMISSION=fire*energy;
    ALPHA=clamp(body*(0.2+0.55*ribs)+core*0.8,0.0,0.92)*along*effect_opacity;
}
