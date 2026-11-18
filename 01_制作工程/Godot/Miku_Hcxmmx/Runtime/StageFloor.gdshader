shader_type canvas_item;
render_mode blend_add;

uniform vec2 radius = vec2(182.0, 42.0);
uniform float clock = 0.0;
uniform float activation = 0.0;
uniform float emphasis = 0.0;
uniform float entrance_time = -1.0;
uniform float wave_motion = 0.0;
uniform float sweep_angle = 0.0;
uniform float sweep_strength = 0.0;
uniform float music_bands[8];
uniform float mood = 0.0;
uniform float effect_time = 0.0;
uniform float shutdown_time = -1.0;
varying vec2 position;
varying vec4 inherited_color;

const vec3 CYAN = vec3(0.208, 0.898, 0.949);
const vec3 PINK = vec3(1.0, 0.408, 0.812);
const vec3 WHITE = vec3(0.863, 1.0, 1.0);

void vertex() {
 position = VERTEX;
 inherited_color = COLOR;
}

float reveal(float delay, float length) {
 return entrance_time < 0.0 ? 1.0 : smoothstep(delay, delay + length, entrance_time);
}

float band(float r, float inner, float outer, float aa) {
 return smoothstep(inner - aa, inner + aa, r) * (1.0 - smoothstep(outer - aa, outer + aa, r));
}

float line(float distance, float width) {
 return 1.0 - smoothstep(width * 0.5 - 0.5, width * 0.5 + 0.5, distance);
}

float arc(float angle, float start, float length, float aa) {
 float phase = mod(angle - start + TAU * 2.0, TAU);
 return smoothstep(0.0, aa, phase) * (1.0 - smoothstep(length - aa, length, phase));
}

void fragment() {
 vec2 center = vec2(0.0, -3.0);
 vec2 r = radius * (1.0 + activation * 0.025 + emphasis * 0.065);
 vec2 p = position - center;
 vec2 q = p / r;
 float radial = length(q);
 float angle = mod(atan(q.y, q.x) + TAU, TAU);
 float aa = max(fwidth(radial) * 0.65, 0.0001);
 float angle_aa = clamp(fwidth(angle), 0.0001, 0.04);
 float progress = reveal(0.015, 0.32);
 float phase = mod(angle + PI * 0.5, TAU) / TAU;
 float angular = progress >= 0.999 ? 1.0 : clamp((progress - phase) / 0.025, 0.0, 1.0);
 float fill = reveal(0.12, 0.34);
 float edge = r.x * 0.96 * (fill * 2.0 - 1.0);
 float filled = 1.0 - smoothstep(edge - 0.5, edge + 0.5, p.x);
 vec3 color = CYAN * (1.0 - smoothstep(0.96 - aa, 0.96 + aa, radial)) * filled * (0.055 + activation * 0.075 + emphasis * 0.075);

 // Seven flowing score lines, using the same phase and amplitude as the stage.
 for (int row = 0; row < 7; row++) {
  float depth = (float(row) - 3.0) / 4.5;
  float span = r.x * 0.86 * sqrt(1.0 - depth * depth);
  float x = p.x / span;
  float envelope = pow(max(0.0, 1.0 - x * x), 0.65);
  int frequency = clamp(int((x + 1.0) * 3.5), 0, 7);
  float wave = sin(x * 12.0 + float(row) * 0.8 - clock * 2.8 - wave_motion);
  wave += sin(x * 23.0 + float(row) + clock * 1.9 - wave_motion * 0.7) * 0.35;
  float y = depth * r.y + wave * (1.7 + activation * (1.5 + music_bands[frequency] * 3.5) + emphasis * 3.0) * envelope;
  float distance = abs(p.y - y);
  float alpha = (0.28 + activation * 0.3 + emphasis * 0.32) * step(abs(x), 1.0) * filled;
  vec3 tint = row == 1 || row == 5 ? PINK : CYAN;
  color += tint * line(distance, 8.0) * alpha * 0.12;
  color += mix(tint, WHITE, emphasis * 0.65) * line(distance, 1.8) * alpha;
  float light_phase = clock * 0.2 + float(row) * 0.13;
  float light_x = abs(fract(((x + 1.0) * 0.5 - light_phase) * 3.0 + 0.5) - 0.5) * span * 2.0 / 3.0;
  color += WHITE * line(length(vec2(light_x, distance)), (1.8 + emphasis) * 2.0) * alpha * 0.9;
  float front = line(length(vec2(p.x - edge, p.y - y)), 3.0) * step(abs(x), 1.0);
  color += WHITE * front * (fill < 0.999 ? 0.85 : 0.0);
 }

 float rim = band(radial, 0.94, 1.035, aa) * mix(1.0, 0.4, clamp((radial - 0.94) / 0.095, 0.0, 1.0));
 color += CYAN * rim * angular * (0.3 + activation * 0.32 + emphasis * 0.35);
 vec2 lower_q = (p - vec2(0.0, 6.0)) / r;
 float lower_r = length(lower_q);
 float lower_angle = mod(atan(lower_q.y, lower_q.x) + TAU, TAU);
 float lower = band(lower_r, 0.99, 1.045, aa) * mix(1.0, 0.4, clamp((lower_r - 0.99) / 0.055, 0.0, 1.0));
 color += PINK * lower * arc(lower_angle, 0.05, PI - 0.1, angle_aa) * angular * (0.24 + activation * 0.2 + emphasis * 0.25);
 float radial_pixel = max(length(q / r) / max(radial, 0.001), 0.0001);
 color += WHITE * line(abs(radial - 0.91) / radial_pixel, 2.1) * angular * (0.28 + activation * 0.22 + emphasis * 0.3);
 color += CYAN * line(abs(radial - 0.76) / radial_pixel, 2.0) * angular * (0.13 + activation * 0.22 + emphasis * 0.25);
 float segment_width = TAU / 28.0;
 int segment = int(floor(angle / segment_width));
 float segment_phase = mod(angle, segment_width);
 float segment_mask = smoothstep(0.015, 0.015 + angle_aa, segment_phase) * (1.0 - smoothstep(segment_width - 0.03 - angle_aa, segment_width - 0.03, segment_phase));
 vec3 segment_tint = segment % 7 < 2 ? PINK : CYAN;
 float segment_alpha = 0.25 + activation * (0.2 + music_bands[segment % 8] * 0.4) + emphasis * 0.25;
 float segments = band(radial, 0.84, 0.895, aa) * mix(1.0, 0.4, clamp((radial - 0.84) / 0.055, 0.0, 1.0));
 color += mix(segment_tint, WHITE, emphasis * 0.65) * segments * segment_mask * angular * segment_alpha;
 float tick_angle = abs(mod(angle + PI / 12.0, TAU / 12.0) - PI / 12.0);
 float tick_distance = tick_angle * length(vec2(-sin(angle), cos(angle)) * r);
 color += WHITE * line(tick_distance, 2.0) * band(radial, 0.94, 1.04, aa) * angular * (0.2 + activation * 0.24 + emphasis * 0.35);
 if (progress > 0.001 && progress < 0.999) {
  color += WHITE * band(radial, 0.92, 1.065, aa) * arc(angle, -PI / 2.0 + progress * TAU - 0.2, 0.2, angle_aa) * 0.95;
 }
 float travel = 1.03 + (1.0 - emphasis) * 0.2;
 color += WHITE * band(length(p / radius), travel - 0.025, travel, aa) * emphasis * 0.7;
 color += CYAN * band(radial, 0.92, 1.055, aa) * arc(angle, sweep_angle - 1.2, 1.2, angle_aa) * sweep_strength * 0.85;
 color += WHITE * band(radial, 0.95, 1.065, aa) * arc(angle, sweep_angle - 0.2, 0.2, angle_aa) * sweep_strength;

 float value = max(color.r, max(color.g, color.b));
 color = mix(color, value * vec3(0.72, 0.1, 0.18), mood);
 float noise = fract(sin(floor(position.y / 4.0) * 31.17 + floor(effect_time * 28.0) * 17.31) * 43758.5453);
 color *= 1.0 - step(0.84, noise) * mood * 0.85;
 if (shutdown_time >= 0.0) {
  float shutdown_angle = mod(atan(position.y / radius.y, position.x / radius.x) + PI / 2.0 + TAU, TAU) / TAU;
  color *= 1.0 - smoothstep(0.72 + shutdown_angle * 0.55, 0.95 + shutdown_angle * 0.55, shutdown_time);
  color *= mix(vec3(1.0), vec3(0.5, 0.62, 0.78), smoothstep(0.2, 1.3, shutdown_time));
 }
 float opacity = clamp(max(color.r, max(color.g, color.b)), 0.0, 1.0);
 COLOR = vec4(color / max(opacity, 0.00001), opacity) * inherited_color;
}
