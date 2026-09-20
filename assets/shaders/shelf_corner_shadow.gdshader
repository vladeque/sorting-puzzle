shader_type canvas_item;
render_mode unshaded;

uniform vec4 shadow_color : source_color = vec4(0.18, 0.11, 0.06, 0.34);
uniform vec2 corner_origin = vec2(-104.0, 16.0);
uniform vec2 fade_span = vec2(24.0, 22.0);

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 safe_span = max(abs(fade_span), vec2(0.001));
	vec2 distance_from_corner = max((local_position - corner_origin) / safe_span, vec2(0.0));
	float falloff = 1.0 - smoothstep(0.0, 1.0, distance_from_corner.x + distance_from_corner.y);
	COLOR = vec4(shadow_color.rgb, shadow_color.a * falloff);
}
