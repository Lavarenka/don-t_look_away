shader_type spatial;
render_mode cull_disabled;
// Аня v3: ночная рубашка. Подол чуть колышется (маска — цвет вершин, красный канал), по краю подола и манжет — рваная бахрома.
#include "res://shaders/anya3.gdshaderinc"
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic;   // альфа — рваный край
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D mask_tex : hint_default_white, filter_linear_mipmap;     // R — шероховатость, G — кровь (очередь), B — затенение в складках
uniform sampler2D weave_tex : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float weave_scale = 90.0;
uniform float weave_k = 0.30;
uniform vec3 base_color : source_color = vec3(1.0);
uniform float sway = 1.0;
uniform vec3 hem_drag = vec3(0.0);    // подол отстаёт от бёдер (оси модели)
varying float v_hem;

void vertex() {
	a3_h = VERTEX.y;
	v_hem = COLOR.r;
	float ph = VERTEX.x * 14.0 + VERTEX.z * 11.0;
	VERTEX += vec3(sin(TIME * 1.3 + ph), 0.0, cos(TIME * 1.1 + ph * 0.8)) * 0.007 * COLOR.r * sway;
	VERTEX += hem_drag * COLOR.r;
}

void fragment() {
	if (near_cut > 0.0 && length(VERTEX) < near_cut) discard;
	vec4 c = texture(albedo_tex, UV);
	if (c.a < 0.5) discard;
	vec3 col = c.rgb * base_color * tint.rgb;
	vec3 m = texture(mask_tex, UV).rgb;
	float rough = clamp(m.r, 0.3, 1.0);
	float k = a3_blood(m.g);
	a3_bleed(k, m.g, col, rough);
	// мокрая от крови ткань темнеет шире самого пятна
	col *= mix(1.0, 0.78, smoothstep(-0.12, 0.05, m.g + blood - 1.0) * step(0.01, m.g) * step(0.001, blood));
	vec2 n1 = texture(normal_tex, UV).rg * 2.0 - 1.0;
	vec2 n2 = texture(weave_tex, UV * weave_scale).rg * 2.0 - 1.0;
	if (!FRONT_FACING) NORMAL = -NORMAL;          // изнанка: нормаль — наружу с этой стороны
	NORMAL_MAP = vec3(clamp(n1 + n2 * weave_k * (1.0 - k), vec2(-0.98), vec2(0.98)) * 0.5 + 0.5, 1.0);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.2;
	AO = m.b;
	AO_LIGHT_AFFECT = 0.5;
	BACKLIGHT = vec3(0.16, 0.15, 0.13);
	RIM = rim;
	RIM_TINT = 0.2;
#ifdef GHOSTLY
	float gfr = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float breath = a3_noise(UV * 9.0 + vec2(TIME * 0.21, -TIME * 0.17)) * 0.6 + a3_noise(UV * 31.0 - TIME * 0.4) * 0.4;
	float a = mix(0.72, 0.28, ghost) + breath * 0.3 + gfr * 0.35;
	a *= smoothstep(0.0, 0.5, a3_h);
	ALPHA = clamp(a, 0.0, 1.0);
	ALPHA_HASH_SCALE = 1.0;
	EMISSION += vec3(0.4, 0.5, 0.65) * gfr * ghost * 0.35;
#endif
}
