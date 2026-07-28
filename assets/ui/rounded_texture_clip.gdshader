shader_type canvas_item;

uniform vec2 rect_size = vec2(536.0, 522.0);
uniform float corner_radius : hint_range(0.0, 64.0, 1.0) = 16.0;
uniform float edge_softness : hint_range(0.5, 4.0, 0.25) = 1.25;

varying vec2 local_position;


void vertex() {
	local_position = VERTEX;
}


void fragment() {
	vec4 sampled_color = texture(TEXTURE, UV);
	vec2 half_size = rect_size * 0.5;
	vec2 corner_distance = abs(local_position - half_size) - half_size + vec2(corner_radius);
	float signed_distance = (
		length(max(corner_distance, vec2(0.0)))
		+ min(max(corner_distance.x, corner_distance.y), 0.0)
		- corner_radius
	);
	float rounded_alpha = 1.0 - smoothstep(-edge_softness, edge_softness, signed_distance);
	COLOR = vec4(sampled_color.rgb, sampled_color.a * rounded_alpha);
}
