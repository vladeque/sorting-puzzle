shader_type canvas_item;
render_mode unshaded;

uniform vec4 shadow_color : source_color = vec4(0.24, 0.16, 0.09, 0.34);
uniform vec2 shadow_origin = vec2(0.0);
uniform vec2 shadow_axis = vec2(0.0, 1.0);
uniform float fade_distance : hint_range(1.0, 48.0, 0.5) = 22.0;

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float distance_from_edge = max(dot(local_position - shadow_origin, shadow_axis), 0.0);
	float falloff = 1.0 - smoothstep(0.0, fade_distance, distance_from_edge);
	COLOR = vec4(shadow_color.rgb, shadow_color.a * falloff);
}
