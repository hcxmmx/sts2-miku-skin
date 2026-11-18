uniform float clock = 0.0;
uniform float motion_gain = 1.0;
uniform float light_gain = 1.0;
uniform vec4 art_bounds = vec4(-758.0, -1341.0, 1459.0, 1343.0);

vec2 art_point(vec2 position) {
	return (position - art_bounds.xy) / art_bounds.zw;
}

float soft_area(vec2 point, vec2 center, vec2 radius) {
	vec2 q = (point - center) / radius;
	return exp(-dot(q, q) * 2.0);
}

float music_beat() {
	return pow(max(0.0, sin(clock * TAU * 1.7)), 6.0);
}

vec2 portrait_offset(vec2 position) {
	vec2 p = art_point(position);
	float root_weight = smoothstep(0.20, 0.29, p.y);
	float breath = sin(clock * TAU / 4.8);
	float torso = soft_area(p, vec2(0.52, 0.34), vec2(0.20, 0.24)) * root_weight;
	vec2 offset = vec2((p.x - 0.52) * 22.0, -6.0) * breath * torso;
	float left_x = 0.42 - 0.37 * smoothstep(0.17, 0.66, p.y);
	float right_x = 0.59 + 0.32 * smoothstep(0.18, 0.70, p.y);
	float growing = smoothstep(0.25, 0.55, p.y) * (1.0 - smoothstep(0.86, 0.98, p.y));
	float left = exp(-pow((p.x - left_x) / 0.10, 2.0)) * growing;
	float right = exp(-pow((p.x - right_x) / 0.10, 2.0)) * growing;
	left = max(left, soft_area(p, vec2(0.19, 0.79), vec2(0.22, 0.13)));
	right = max(right, soft_area(p, vec2(0.74, 0.82), vec2(0.23, 0.13)));
	float speakers = max(soft_area(p, vec2(0.314, 0.614), vec2(0.11, 0.12)),
		soft_area(p, vec2(0.686, 0.520), vec2(0.10, 0.11)));
	left *= 1.0 - speakers;
	right *= 1.0 - speakers;
	offset += vec2(sin(clock * 1.35 + p.y * 4.5) * 13.0, cos(clock * 1.1 + p.y * 3.0) * 3.8) * left;
	offset += vec2(sin(clock * 1.17 - p.y * 4.0 + 1.6) * 15.0, sin(clock * 1.25 + p.y * 4.0) * 3.8) * right;
	float hem = soft_area(p, vec2(0.52, 0.44), vec2(0.19, 0.085));
	offset += vec2(sin(clock * 1.4 + p.x * 8.0) * 4.2, cos(clock * 1.3 + p.x * 6.0) * 2.0) * hem;
	return offset * motion_gain;
}

vec2 speaker_uv_offset(vec2 p) {
	vec2 shift = vec2(0.0);
	float pulse = music_beat() * light_gain;
	for (int index = 0; index < 2; index++) {
		vec2 center = index == 0 ? vec2(0.314, 0.614) : vec2(0.686, 0.520);
		vec2 radius = index == 0 ? vec2(0.045, 0.050) : vec2(0.040, 0.045);
		float weight = soft_area(p, center, radius);
		shift -= (p - center) * pulse * 0.12 * weight;
	}
	return shift;
}

float score_light(vec2 p, vec3 color) {
	vec2 q = p - vec2(0.50, 0.56);
	float angle = 0.64;
	q = vec2(cos(angle) * q.x - sin(angle) * q.y, sin(angle) * q.x + cos(angle) * q.y);
	q /= vec2(0.59, 0.20);
	float ribbon = 1.0 - smoothstep(0.06, 0.24, abs(length(q) - 1.0));
	float phase = atan(q.y, q.x) / TAU + 0.5;
	float travel = fract(phase - clock * 0.12);
	float head = exp(-pow((travel - 0.20) / 0.065, 2.0));
	head += exp(-pow((travel - 0.70) / 0.055, 2.0)) * 0.75;
	float maximum = max(color.r, max(color.g, color.b));
	float minimum = min(color.r, min(color.g, color.b));
	float saturation = (maximum - minimum) / max(maximum, 0.001);
	float vivid = smoothstep(0.35, 0.60, saturation) * smoothstep(0.35, 0.70, maximum);
	return ribbon * vivid * (head * 1.9 + music_beat() * 0.14) * light_gain;
}
