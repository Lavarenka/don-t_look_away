shader_type canvas_item;
// Главное меню: пыльная дымка в луче фонаря поверх фоновой картинки — клубится, светится тёплым.
render_mode blend_add;
uniform float power = 1.0;
uniform vec2 center = vec2(0.63, 0.56);
uniform float radius = 0.24;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += vnoise(p) * a; p *= 2.03; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = (uv - center) * vec2(16.0 / 9.0, 1.0);
	float r = length(d) / radius;
	float beam = 1.0 - smoothstep(0.35, 1.05, r);
	float t = TIME * 0.035;
	float n = fbm(uv * vec2(5.0, 3.0) + vec2(t, -t * 0.6)) * 0.65 + fbm(uv * 11.0 - vec2(t * 1.7, t)) * 0.35;
	float fog = beam * smoothstep(0.35, 0.85, n);
	COLOR = vec4(vec3(0.85, 0.82, 0.74) * fog * 0.07 * power, 1.0);
}
