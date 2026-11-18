shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform vec4 edge_color : source_color = vec4(0.1, 0.85, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 fraction = fract(p);
	vec2 blend = fraction * fraction * (3.0 - 2.0 * fraction);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float grain = noise(p * 12.0 + seed) * 0.62 + noise(p * 31.0 - seed) * 0.38;
	float spokes = pow(abs(cos(angle * 5.0 + seed)), 12.0);
	float edge = 0.46 + spokes * 0.38 + sin(angle * 13.0 + seed) * 0.055 + grain * 0.12;
	float shape = 1.0 - smoothstep(edge - 0.06, edge, radius);
	float dissolve = 1.0 - smoothstep(grain - 0.08, grain + 0.14, progress * 1.18);
	float core = exp(-radius * radius * 30.0);
	vec3 color = mix(edge_color.rgb, vec3(1.0), core * 0.94);
	float alpha = shape * dissolve * pow(1.0 - progress, 0.65) * (0.42 + core * 0.58);
	COLOR = vec4(color, alpha) * COLOR;
}
