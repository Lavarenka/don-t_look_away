shader_type spatial;
render_mode cull_back;
// Аня v3: кожа (голова, руки, ноги). Текстуры — tools/anya3 (процедурные): цвет, рельеф, маска.
#include "res://shaders/anya3.gdshaderinc"
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D mask_tex : hint_default_white, filter_linear_mipmap;     // R — шероховатость, G — кровь (очередь), B — затенение в складках
uniform sampler2D pore_tex : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float pore_scale = 70.0;
uniform float pore_k = 0.35;
uniform vec3 base_color : source_color = vec3(1.0);
uniform float translucency = 0.25;   // свет чуть проходит насквозь (уши, пальцы)

void vertex() {
	a3_h = VERTEX.y;
}

void fragment() {
	if (near_cut > 0.0 && length(VERTEX) < near_cut) discard;
	vec3 col = texture(albedo_tex, UV).rgb * base_color * tint.rgb;
	vec3 m = texture(mask_tex, UV).rgb;
	float rough = clamp(m.r, 0.2, 1.0);
	float k = a3_blood(m.g);
	a3_bleed(k, m.g, col, rough);
	// карты рельефа хранят только наклон (два канала) — третий движок восстановит сам
	vec2 n1 = texture(normal_tex, UV).rg * 2.0 - 1.0;
	vec2 n2 = texture(pore_tex, UV * pore_scale).rg * 2.0 - 1.0;
	NORMAL_MAP = vec3(clamp(n1 + n2 * pore_k * (1.0 - k), vec2(-0.98), vec2(0.98)) * 0.5 + 0.5, 1.0);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	AO = m.b;
	AO_LIGHT_AFFECT = 0.6;
	BACKLIGHT = vec3(0.30, 0.08, 0.06) * translucency;
	RIM = rim;
	RIM_TINT = 0.3;
#ifdef GHOSTLY
	float gfr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float breath = a3_noise(UV * 9.0 + vec2(TIME * 0.21, -TIME * 0.17)) * 0.6 + a3_noise(UV * 31.0 - TIME * 0.4) * 0.4;
	float a = mix(0.72, 0.28, ghost) + breath * 0.3 + gfr * 0.35;
	a *= smoothstep(0.0, 0.5, a3_h);
	ALPHA = clamp(a, 0.0, 1.0);
	ALPHA_HASH_SCALE = 1.0;
	EMISSION += vec3(0.4, 0.5, 0.65) * gfr * ghost * 0.35;
#endif
}
