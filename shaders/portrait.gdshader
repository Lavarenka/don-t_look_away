shader_type spatial;
// Портрет в овальной раме: старый снимок/холст под лаком. Овал — по UV (плоскость размером с проём рамы),
// за краем — отброшено (кромку закрывает рама). Сепия, виньетка, кракелюр, лёгкий блик лака.
render_mode cull_back;
uniform sampler2D img : source_color, filter_linear_mipmap;
uniform float sepia = 0.85;
uniform float dark = 1.0;          // 0..1 — «мигнуло»: при смене позы холст на миг темнеет

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q);
	if (r > 1.0) discard;
	vec3 c = texture(img, UV).rgb;
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	vec3 sp = vec3(l * 1.05, l * 0.9, l * 0.68);
	c = mix(c, sp, sepia);
	// пожелтевший лак, тёмные края
	c *= mix(1.0, 0.35, smoothstep(0.55, 1.0, r));
	c = mix(c, c * vec3(1.0, 0.86, 0.62), 0.35);
	// кракелюр: тонкие тёмные трещины-ячейки
	float n = vnoise(UV * vec2(38.0, 52.0)) + 0.5 * vnoise(UV * vec2(90.0, 120.0));
	float crack = smoothstep(0.03, 0.0, abs(n - 0.75));
	c *= 1.0 - crack * 0.35;
	c *= 0.9 + 0.1 * vnoise(UV * 300.0);
	ALBEDO = c * dark;
	ROUGHNESS = 0.5 + 0.25 * vnoise(UV * 14.0);
	SPECULAR = 0.3;
}
