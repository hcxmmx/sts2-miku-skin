shader_type canvas_item;
render_mode blend_add;

uniform float effect_time = 0.0;
varying vec2 stage_position;

void vertex() {
	stage_position = VERTEX;
}

void fragment() {
	vec4 source = COLOR;
	float angle = mod(atan(stage_position.y / 42.0, stage_position.x / 182.0) + 1.57079633 + 6.28318531, 6.28318531) / 6.28318531;
	float floor_power = 1.0 - smoothstep(0.72 + angle * 0.55, 0.95 + angle * 0.55, effect_time);
	float backdrop_power = 1.0 - smoothstep(0.18, 0.85, effect_time);
	float backdrop = smoothstep(45.0, 80.0, -stage_position.y);
	float power = mix(floor_power, backdrop_power, backdrop);
	float dim = smoothstep(0.2, 1.3, effect_time);
	vec3 color = mix(source.rgb, source.rgb * vec3(0.5, 0.62, 0.78), dim);
	COLOR = vec4(color, source.a * power);
}
