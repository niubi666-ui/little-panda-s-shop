shader_type canvas_item;
render_mode unshaded;
uniform sampler2D region_mask : filter_linear, repeat_disable;
uniform int effect_kind;
uniform float motion_clock;
uniform float phase;
uniform float strength;
uniform float period;
uniform float flow_px;
uniform vec2 flow_direction;
uniform float flow_speed_px;
uniform float flow_emission;
uniform float glow_variation;
uniform vec2 noise_scale;
uniform float noise_speed;
uniform vec4 tint : source_color;
uniform float mist_opacity;
uniform float mist_speed_px;
uniform sampler2D mist_noise : filter_linear, repeat_enable;
uniform vec4 mist_puffs[12];
uniform int mist_puff_count;
uniform float mist_lifetime;
uniform vec2 mist_velocity;
uniform vec2 mist_radius_start;
uniform vec2 mist_radius_end;
uniform float mist_sway_px;
uniform float mist_sway_hz;
uniform vec4 mist_color : source_color;
uniform float mist_max_alpha;
uniform vec2 uv_per_pixel;
varying vec4 inherited_color;

void vertex() {
	inherited_color = COLOR;
}

float cold_mist(vec2 uv, float t) {
	float clear_fraction = 1.0;
	for (int i = 0; i < 12; i++) {
		if (i >= mist_puff_count) { break; }
		vec4 puff = mist_puffs[i];
		float age = fract(t/mist_lifetime + puff.z);
		vec2 radius = mix(mist_radius_start,mist_radius_end,age);
		vec2 center_drift = mist_velocity * age * mist_lifetime;
		center_drift.x += sin(age*TAU*mist_sway_hz + puff.w*TAU) * mist_sway_px * age;
		vec2 q = ((uv-puff.xy)/uv_per_pixel-center_drift)/radius;
		float distance_squared = dot(q,q);
		if (distance_squared >= 1.0) { continue; }
		vec2 cloud_uv = q*0.5 + vec2(puff.w,puff.z) + vec2(t,-t)*mist_speed_px*uv_per_pixel;
		float cloud = texture(mist_noise,cloud_uv).r;
		float feather = 1.0-smoothstep(0.12,1.0,distance_squared);
		float density = feather * smoothstep(0.15,0.8,cloud) * sin(age*PI);
		clear_fraction *= 1.0-clamp(density*mist_opacity*strength,0.0,1.0);
	}
	return min(1.0-clear_fraction,mist_max_alpha);
}

void fragment() {
	vec2 uv = UV;
	vec3 mask = texture(region_mask,uv).rgb;
	vec4 base = texture(TEXTURE,uv);
	float t = motion_clock + phase;
	float pulse = sin(t * TAU / period);
	float drift = sin(dot(uv,noise_scale) - t * noise_speed);
	float region = max(mask.r,mask.g);
	vec3 color = base.rgb;
	if (effect_kind == 0) {
		// The authored mask excludes the blade, hilt and background. Warm color
		// is only a secondary restriction INSIDE that mask, never a full-image key.
		float warm = smoothstep(0.0,0.18,base.r-base.b);
		region *= warm;
		vec2 ripple = vec2(drift, -sin(dot(uv,noise_scale.yx)-t*noise_speed));
		// Two advected samples crossfade across their wrap, so flame detail flows
		// along the blade continuously while the authored metal silhouette stays still.
		float travel = fract(t / period);
		float alternate = fract(travel + 0.5);
		vec2 drift_uv = normalize(flow_direction) * uv_per_pixel * flow_speed_px * period;
		vec2 ripple_uv = ripple * uv_per_pixel * flow_px * region * strength;
		vec3 first = texture(TEXTURE,uv - drift_uv*(travel-0.5)*strength + ripple_uv).rgb;
		vec3 second = texture(TEXTURE,uv - drift_uv*(alternate-0.5)*strength + ripple_uv).rgb;
		color = mix(first,second,abs(travel*2.0-1.0));
		color *= 1.0 + pulse * glow_variation * strength;
		float crest = pow(max(0.0,drift),3.0);
		color += tint.rgb * crest * flow_emission * strength;
	} else if (effect_kind == 1) {
		// Rigid artwork, with separate vapor born along the blade and drifting
		// away. Composite fog alpha separately so it stays visible outside the mask.
		float sheen = pow(max(0.0,sin(dot(uv,noise_scale) - t*noise_speed)), 8.0);
		color += tint.rgb * mask.r*sheen*glow_variation * strength;
		float fog = cold_mist(uv,t);
		float combined_alpha = region*(1.0-fog)+fog;
		color = (color*region*(1.0-fog)+mist_color.rgb*fog)/max(combined_alpha,0.00001);
		region = combined_alpha;
	} else {
		float current = pow(max(0.0,drift),8.0);
		color += tint.rgb * current * mask.r * glow_variation * strength;
	}
	COLOR = vec4(color,clamp(region,0.0,1.0)*base.a) * inherited_color;
}
