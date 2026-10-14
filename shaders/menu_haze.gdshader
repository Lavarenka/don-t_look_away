shader_type canvas_item;
// Главное меню: луч фонаря в пыльном воздухе поверх фоновой картинки —
// клубящаяся дымка в пятне света и еле заметные «лучи» от фонаря, которые медленно плывут.
render_mode blend_add;
uniform float power = 1.0;
uniform vec2 center = vec2(0.63, 0.56);     // центр пятна фонаря на фоне
uniform vec2 source = vec2(0.66, 1.15);     // откуда светит (фонарь у камеры, чуть ниже кадра)
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
	float beam = 1.0 - smoothstep(0.35, 1.1, r);
	float t = TIME * 0.035;
	float n = fbm(uv * vec2(5.0, 3.0) + vec2(t, -t * 0.6)) * 0.65 + fbm(uv * 11.0 - vec2(t * 1.7, t)) * 0.35;
	float fog = beam * smoothstep(0.35, 0.85, n);
	// лучи: полосы, расходящиеся от фонаря, гаснут к краю пятна
	vec2 s = (uv - source) * vec2(16.0 / 9.0, 1.0);
	float ang = atan(s.x, -s.y);
	float rays = fbm(vec2(ang * 18.0, TIME * 0.06)) * fbm(vec2(ang * 41.0 + 3.0, TIME * 0.09 + 5.0));
	rays = smoothstep(0.18, 0.5, rays);
	float cone = (1.0 - smoothstep(0.25, 1.25, r)) * smoothstep(0.0, 0.5, length(s));
	vec3 c = vec3(0.85, 0.82, 0.74) * (fog * 0.07 + rays * cone * 0.05);
	COLOR = vec4(c * power, 1.0);
}
