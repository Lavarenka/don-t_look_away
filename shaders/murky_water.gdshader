shader_type spatial;
render_mode cull_disabled;
// Стоячая тёмная вода в ванне: почти чёрная толща, зеркальная поверхность с медленной рябью
// (две карты нормалей плывут в разные стороны), отражения из ReflectionProbe, у бортов — мутная кайма.
// Форма — скруглённый прямоугольник по размеру ванны.

uniform vec2 size = vec2(0.66, 1.46);
uniform float radius = 0.29;
uniform vec3 deep : source_color = vec3(0.035, 0.03, 0.018);
uniform vec3 murk : source_color = vec3(0.11, 0.095, 0.055);
uniform sampler2D ripple_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ripple_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float ripple = 0.9;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
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
	vec3 na = texture(ripple_a, p * 1.6 + vec2(t * 0.012, t * 0.007)).rgb;
	vec3 nb = texture(ripple_b, p * 2.7 - vec2(t * 0.009, -t * 0.013)).rgb;
	vec3 n = normalize(mix(vec3(0.5, 0.5, 1.0), (na + nb) * 0.5, ripple));
	NORMAL_MAP = n;
	// у бортов вода мутнее и светлее, в середине — почти чёрная глубина
	float edge = smoothstep(-0.09, -0.005, d);
	ALBEDO = mix(deep, murk, edge * 0.8);
	ROUGHNESS = mix(0.07, 0.2, edge);
	METALLIC = 0.0;
	SPECULAR = 0.9;
	// чем более наискось смотришь, тем сильнее отражение (Френель уже в освещении, усиливаем немного)
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO *= 1.0 - fres * 0.6;
}
