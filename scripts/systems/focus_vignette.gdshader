shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.47, 0.5);

void fragment() {
	vec2 d = (UV - center) * vec2(1.6, 1.0);
	float r = length(d);
	float v = smoothstep(0.16, 0.72, r);
	// slight warm tint so it reads as "tunnel vision" not a black frame
	COLOR = vec4(0.03, 0.015, 0.0, v * strength);
}
