shader_type canvas_item;
// Ghostly look for echoes: cool tint, gentle flicker and scanlines.

uniform vec4 tint : source_color = vec4(0.55, 0.86, 1.0, 1.0);
uniform float alpha = 0.8;
uniform float glow = 1.45;

void fragment() {
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 col = mix(vec3(l), tint.rgb, 0.6) * glow;
	float line = step(0.5, fract(FRAGCOORD.y * 0.5 + TIME * 1.3));
	float flick = 0.9 + 0.1 * sin(TIME * 11.0 + FRAGCOORD.x * 0.05);
	COLOR = vec4(col * (0.88 + 0.12 * line), c.a * alpha * flick);
}
