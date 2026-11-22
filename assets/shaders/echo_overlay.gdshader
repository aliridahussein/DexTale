shader_type canvas_item;
// "Listen to the Echo": desaturate the world and wash it in violet-blue.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.58, 0.55, 1.0, 1.0);

void fragment() {
	vec4 c = texture(screen_tex, SCREEN_UV);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 desat = mix(c.rgb, vec3(l), 0.85);
	vec3 tinted = desat * mix(vec3(1.0), tint.rgb * 1.3, 0.65) + vec3(0.015, 0.02, 0.06);
	vec2 d = (SCREEN_UV - vec2(0.5)) * vec2(1.6, 1.0);
	float vig = smoothstep(0.8, 0.2, length(d));
	vec3 outc = mix(tinted * 0.65, tinted * 1.08, vig);
	COLOR = vec4(mix(c.rgb, outc, strength), 1.0);
}
