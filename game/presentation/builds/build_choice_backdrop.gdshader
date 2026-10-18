shader_type canvas_item;
// 三选一的背景：把身后的游戏画面模糊、压暗、四角加暗角。
// 场景仍然看得见（知道自己在哪、周围怎样），但不抢卡牌的视线；界面上的小字也被糊掉。
// 参数在 build_card_skin.tres；progress 由面板随弹出/关闭动画写入。
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float progress = 1.0;
uniform float blur_lod = 3.0;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 0.5);
uniform float vignette = 0.6;

void fragment() {
	vec3 scene = textureLod(screen_texture, SCREEN_UV, blur_lod * progress).rgb;
	vec3 colour = mix(scene, tint.rgb, tint.a * progress);
	vec2 from_centre = (SCREEN_UV - 0.5) * vec2(1.0, 1.25);
	colour *= 1.0 - vignette * progress * smoothstep(0.25, 0.85, length(from_centre));
	COLOR = vec4(colour, 1.0);
}
