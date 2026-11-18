shader_type canvas_item;
render_mode blend_add;

#include "res://Miku_Hcxmmx/Portrait/PortraitMotion.gdshaderinc"

varying vec2 original_position;

void vertex() {
	original_position = VERTEX;
}

void fragment() {
	vec2 p = art_point(original_position - portrait_offset(original_position));
	vec3 color = vec3(0.0);
	float beat = music_beat();
	for (int index = 0; index < 2; index++) {
		vec2 center = index == 0 ? vec2(0.314, 0.614) : vec2(0.686, 0.520);
		vec2 q = (p - center) * art_bounds.zw;
		q.y *= 0.93;
		float radius = index == 0 ? 60.0 : 53.0;
		float radial = length(q);
		float life = fract(clock * 0.85 + float(index) * 0.5);
		float wave_radius = radius + life * 42.0;
		float wave = exp(-pow((radial - wave_radius) / 2.8, 2.0)) * pow(1.0 - life, 1.5) * 0.44;
		float rim = exp(-pow((radial - radius) / 4.0, 2.0)) * (0.15 + beat * 0.6);
		float halo = exp(-pow(radial / (radius * 1.4), 2.0)) * beat * 0.13;
		vec3 tint = index == 0 ? vec3(0.30, 0.95, 1.0) : vec3(0.95, 0.40, 0.90);
		color += tint * (wave + rim + halo);
	}
	for (int index = 0; index < 5; index++) {
		vec2 center = vec2(0.097, 0.337);
		if (index == 1) center = vec2(0.059, 0.473);
		if (index == 2) center = vec2(0.766, 0.112);
		if (index == 3) center = vec2(0.859, 0.154);
		if (index == 4) center = vec2(0.207, 0.757);
		vec2 q = (p - center) * art_bounds.zw;
		float pulse = pow(max(0.0, sin(clock * 1.8 + float(index) * 1.9)), 8.0);
		float size = 14.0 + pulse * 12.0;
		vec2 local = abs(q) / size;
		float star = exp(-local.x * 15.0 - local.y * 1.5) + exp(-local.y * 15.0 - local.x * 1.5);
		color += vec3(0.65, 1.0, 1.0) * star * pulse * 0.5;
	}
	float alpha = clamp(max(color.r, max(color.g, color.b)), 0.0, 1.0);
	COLOR = vec4(color / max(alpha, 0.0001), alpha * light_gain);
}
