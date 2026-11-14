shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Аня v3: волосы — ленты с альфа-текстурой прядей. Цвет вершин: R — от корня (0) к кончику (1), G — случайное число пряди,
// B — нижний плотный слой. Форму и движение даёт физика костей (spirit.gd), здесь — только мелкая дрожь кончиков.
// Нормали у лент сглажены «по объёму» причёски (tools/anya3/s4_prep.py), поэтому для изнанки их не переворачиваем.
#include "res://shaders/anya3.gdshaderinc"
uniform sampler2D strand_tex : hint_default_white, filter_linear_mipmap_anisotropic;   // R — яркость пряди, G — её сухость, A — сами пряди
uniform vec3 base_color : source_color = vec3(0.022, 0.019, 0.020);
uniform float alpha_cut = 0.40;
uniform float sway = 1.0;
uniform float lift = 0.0;             // испуг: пряди чуть топорщатся (основной подъём — физикой)
varying float v_t;
varying float v_seed;
varying float v_under;

void vertex() {
	a3_h = VERTEX.y;
	v_t = COLOR.r;
	v_seed = COLOR.g;
	v_under = COLOR.b;
	float ph = COLOR.g * 40.0;
	vec3 w = vec3(sin(TIME * 0.9 + ph + VERTEX.y * 6.0), 0.0, cos(TIME * 0.7 + ph * 1.3 + VERTEX.y * 5.0));
	VERTEX += w * 0.004 * COLOR.r * COLOR.r * sway;
	VERTEX += NORMAL * 0.02 * lift * COLOR.r;
}

void fragment() {
	if (near_cut > 0.0 && length(VERTEX) < near_cut) discard;
	vec4 s = texture(strand_tex, UV);
	// вдали (на мелких уровнях текстуры) пряди не должны редеть
	vec2 px = UV * vec2(textureSize(strand_tex, 0));
	float lod = max(0.0, 0.5 * log2(max(dot(dFdx(px), dFdx(px)), dot(dFdy(px), dFdy(px)))));
	float a = s.a * (1.0 + 0.25 * lod);
	a = mix(a, max(a, 0.8), v_under * (1.0 - v_t * v_t));          // нижний слой плотнее
	if (a < alpha_cut) discard;
	float shade = mix(0.5, 1.0, smoothstep(0.0, 0.22, v_t)) * mix(1.0, 0.6, v_under);   // у корней и в глубине темнее
	ALBEDO = base_color * (0.5 + 1.0 * s.r) * mix(0.8, 1.25, v_seed) * shade * tint.rgb;
	// каждая прядь блестит по-своему: нормаль чуть наклонена поперёк пряди — блик дробится на волоски
	NORMAL = normalize(NORMAL + TANGENT * (s.r - 0.5) * 0.8);
	ROUGHNESS = mix(0.40, 0.66, s.g);
	SPECULAR = 0.32 * (0.5 + s.r);
	ANISOTROPY = 0.6;
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
#ifdef GHOSTLY
	float gfr = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float al = mix(0.75, 0.3, ghost) + gfr * 0.3;
	al *= smoothstep(0.0, 0.5, a3_h);
	ALPHA = clamp(al, 0.0, 1.0);
	ALPHA_HASH_SCALE = 1.0;
#endif
}
