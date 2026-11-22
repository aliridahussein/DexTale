shader_type canvas_item;
// Pixel dissolve used when a memory fades away (Ending: The Keeper).

uniform sampler2D noise_tex : repeat_enable, filter_nearest;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.85, 0.55, 1.0);
uniform vec2 tex_size = vec2(168.0, 104.0);

void fragment() {
	vec4 c = COLOR;
	vec2 p = floor(UV * tex_size / 2.0) * 2.0 / 64.0;
	float n = texture(noise_tex, p).r;
	if (n < progress) {
		c.a = 0.0;
	} else if (n < progress + 0.05) {
		c.rgb = edge_color.rgb;
	}
	COLOR = c;
}
