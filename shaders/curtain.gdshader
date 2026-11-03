shader_type spatial;
// Шторы зала: плотные портьеры и тюль. Ткань висит складками (меш строит scripts/curtains.gd),
// а тут — колышется от сквозняка из старого окна: низ сильнее верха, изредка порыв.
// UV меша — в метрах: x — вдоль ткани (развёрнутой), y — вниз от карниза.
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_nrm = false;
uniform float tile = 0.5;               // метров на текстуру
uniform bool tulle = false;             // тюль: прозрачная сетка
uniform float cloth_len = 2.25;         // длина полотна
uniform float sway = 1.0;               // сила сквозняка
uniform float gust = 0.0;               // 0..1 — порыв (скрипт может дёрнуть шторы)
uniform float seed = 0.0;
uniform float age = 1.0;

varying float v_h;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	float h = clamp(UV.y / cloth_len, 0.0, 1.0);
	v_h = h;
	float t = TIME + seed * 13.0;
	float k = pow(h, 1.4) * sway * (tulle ? 1.8 : 1.0);
	// дыхание сквозняка + волна вдоль ткани + редкий сам собой порыв
	float breath = sin(t * 0.55 + UV.x * 1.7) * 0.6 + sin(t * 0.23 + UV.x * 0.6 + 1.3) * 0.4;
	float auto_g = pow(max(0.0, sin(t * 0.071 + seed)), 12.0);
	float g = max(gust, auto_g);
	float ripple = sin(t * 2.3 - UV.y * 3.0 + UV.x * 5.0) * g;
	VERTEX.z += (breath * 0.012 + g * 0.06 + ripple * 0.02) * k;
	VERTEX.x += sin(t * 0.4 + UV.y * 1.1 + seed) * 0.006 * k + ripple * 0.01 * k;
}

void fragment() {
	vec2 uv = UV / tile;
	vec4 c = texture(tex, uv);
	vec3 col = c.rgb;
	// выгорело полосами по складкам, пыль сверху, грязный подол
	float n = vnoise(UV * vec2(2.0, 0.6) + seed);
	col = mix(col, col * vec3(1.12, 1.08, 0.95) + 0.03, smoothstep(0.55, 0.9, n) * 0.45 * age);
	col = mix(col, vec3(0.45, 0.43, 0.4), smoothstep(0.25, 0.0, UV.y) * 0.35 * age);
	col *= 1.0 - 0.3 * smoothstep(cloth_len - 0.25, cloth_len, UV.y) * age;
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	// свет сквозь ткань (луна из окна)
	BACKLIGHT = tulle ? vec3(0.22) : col * 0.35;
	if (has_nrm) NORMAL_MAP = texture(nrm, uv).xyz;
#ifdef TULLE
	// тюль — отдельный вариант шейдера (scripts/curtains.gd): полупрозрачный, смешивается с фоном
	ALBEDO *= 0.8;
	ALPHA = c.a * 0.5;
#endif
}
