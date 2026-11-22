shader_type canvas_item;
// Drifting pixel mist. Two scrolling noise samples, posterised alpha,
// optional "edges only" mask for creeping fog at the village borders.

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 tint : source_color = vec4(0.72, 0.82, 0.88, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.35;
uniform float edge_only = 0.0;
uniform vec2 rect_size = vec2(480.0, 270.0);
uniform vec2 drift = vec2(0.010, 0.003);
uniform float pixel_size = 2.0;

void fragment() {
	vec2 p = floor(UV * rect_size / pixel_size) * pixel_size;
	vec2 uv1 = p / 160.0 + TIME * drift;
	vec2 uv2 = p / 97.0 + TIME * vec2(-drift.y * 1.7, drift.x * 0.6) + vec2(0.37, 0.11);
	float n = texture(noise_tex, uv1).r * 0.62 + texture(noise_tex, uv2).r * 0.38;
	float m = smoothstep(0.36, 0.80, n);
	float edge = 1.0;
	if (edge_only > 0.5) {
		vec2 d = min(p, rect_size - p);
		float dist = min(d.x, d.y);
		edge = 1.0 - smoothstep(20.0, 120.0, dist);
	}
	float a = m * density * edge;
	a = floor(a * 7.0 + 0.5) / 7.0;
	COLOR = vec4(tint.rgb, a * tint.a);
}
