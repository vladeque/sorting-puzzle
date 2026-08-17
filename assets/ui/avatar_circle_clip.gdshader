shader_type canvas_item;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV) * COLOR;
	float distance_from_center = length(UV - vec2(0.5));
	float circle_alpha = 1.0 - smoothstep(0.47, 0.5, distance_from_center);
	tex_color.a *= circle_alpha;
	COLOR = tex_color;
}
