shader_type canvas_item;
render_mode unshaded;

uniform float reveal_amount : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform float reveal_depth : hint_range(0.1, 0.5) = 0.38;
uniform float reveal_softness : hint_range(0.001, 0.08) = 0.025;


void fragment() {
	vec4 ice = texture(TEXTURE, UV);
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float frontier = reveal_amount * reveal_depth;
	float edge_reveal = 1.0 - smoothstep(frontier, frontier + reveal_softness, edge_distance);
	ice.a *= edge_reveal * opacity;
	COLOR = ice;
}
