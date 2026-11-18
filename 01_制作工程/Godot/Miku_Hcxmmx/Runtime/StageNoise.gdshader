shader_type canvas_item;
render_mode blend_add;

uniform float mood = 0.0;
uniform float effect_time = 0.0;
varying vec2 stage_position;

void vertex() {
	stage_position = VERTEX;
}

void fragment() {
	vec4 source = COLOR;
	float value = max(source.r, max(source.g, source.b));
	vec3 red = value * vec3(0.72, 0.10, 0.18);
	float row = floor(stage_position.y / 4.0);
	float noise = fract(sin(row * 31.17 + floor(effect_time * 28.0) * 17.31) * 43758.5453);
	float gaps = step(0.84, noise) * mood * 0.85;
	COLOR = vec4(mix(source.rgb, red, mood), source.a * (1.0 - gaps));
}
