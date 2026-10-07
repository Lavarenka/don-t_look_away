shader_type spatial;
// Мутная стоячая вода в ванне: тёмно-бурая, с маслянистой плёнкой у краёв и лёгкой рябью.
// Форма — скруглённый прямоугольник по размеру ванны (всё, что снаружи, отбрасывается).

uniform vec2 size = vec2(0.66, 1.46);
uniform float radius = 0.29;
uniform vec3 deep : source_color = vec3(0.03, 0.028, 0.018);
uniform vec3 murk : source_color = vec3(0.13, 0.11, 0.06);
uniform vec3 scum : source_color = vec3(0.32, 0.29, 0.2);
uniform float ripple = 1.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float sd_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = lp.xz;
	float d = sd_box(p, size * 0.5, radius);
	if (d > 0.0) discard;
	float t = TIME;
	// рябь: несколько медленных волн
	vec2 g = vec2(sin(p.x * 31.0 + t * 1.1) + sin((p.x + p.y) * 23.0 - t * 0.8),
	              cos(p.y * 27.0 + t * 0.9) + sin((p.y - p.x) * 19.0 + t * 0.6)) * 0.035 * ripple;
	NORMAL_MAP = normalize(vec3(0.5 + g.x, 0.5 + g.y, 1.0));
	float n = noise(p * 7.0 + vec2(t * 0.03, 0.0)) * 0.6 + noise(p * 19.0 - t * 0.02) * 0.4;
	vec3 c = mix(deep, murk, n * 0.7);
	// плёнка и грязная пена у бортов
	float edge = smoothstep(-0.06, -0.005, d);
	float film = smoothstep(0.45, 0.8, noise(p * 13.0 + 3.0)) * 0.5 + edge * 0.6;
	c = mix(c, scum, clamp(film, 0.0, 1.0) * 0.28);
	ALBEDO = c;
	ROUGHNESS = mix(0.05, 0.45, clamp(film, 0.0, 1.0));
	SPECULAR = 0.6;
}
