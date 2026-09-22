shader_type canvas_item;
render_mode unshaded;

uniform vec4 shadow_color : source_color = vec4(0.16, 0.10, 0.06, 0.24);
uniform vec2 fade_axis = vec2(0.0, 1.0);

void fragment() {
	float distance_from_contact = clamp(dot(UV, fade_axis), 0.0, 1.0);
	float falloff = 1.0 - smoothstep(0.0, 1.0, distance_from_contact);
	COLOR = vec4(shadow_color.rgb, shadow_color.a * falloff);
}
