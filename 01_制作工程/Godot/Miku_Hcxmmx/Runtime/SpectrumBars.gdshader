shader_type canvas_item;
render_mode blend_add;

uniform float mood = 0.0;
uniform float effect_time = 0.0;
uniform float shutdown_time = -1.0;
varying vec4 bar_tint;
varying vec4 bar_data;

void vertex() {
	bar_tint = COLOR;
	bar_data = INSTANCE_CUSTOM;
}

void fragment() {
	float width = bar_data.x;
	float height = max(bar_data.y, 1.0);
	float x = (UV.x - 0.5) * width * 3.2;
	float y = UV.y * height;
	float radius = width * 0.5;
	float distance = length(vec2(x, min(y - radius, 0.0)));
	float solid = 1.0 - smoothstep(radius - 0.5, radius + 0.5, distance);
	float halo = exp(-pow(x / max(width * 0.9, 0.1), 2.0)) * 0.09;
	float gradient = mix(1.0, 0.18, UV.y);
	float cap = (1.0 - smoothstep(width * 0.23, width * 0.3, abs(x))) * step(2.0, y) * step(y, min(15.0, height));
	vec3 color = mix(bar_tint.rgb, vec3(0.86, 1.0, 1.0), cap * bar_data.z);
	float value = max(color.r, max(color.g, color.b));
	color = mix(color, value * vec3(0.72, 0.1, 0.18), mood);
	float noise = fract(sin(floor(y / 4.0) * 31.17 + floor(effect_time * 28.0) * 17.31) * 43758.5453);
	float alpha = bar_tint.a * (solid * gradient + halo) * (1.0 - step(0.84, noise) * mood * 0.85);
	if (shutdown_time >= 0.0) {
		alpha *= 1.0 - smoothstep(0.18, 0.85, shutdown_time);
	}
	COLOR = vec4(color, alpha);
}
