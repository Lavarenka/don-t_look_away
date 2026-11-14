shader_type spatial;
render_mode cull_back;
// Аня v3: глаза. Мутные, мёртвые; зрачок рисуется здесь (pupil — можно расширить в крике); в темноте чуть светятся (glow).
#include "res://shaders/anya3.gdshaderinc"
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform vec2 iris_a = vec2(0.7031, 0.7031);    // центры радужек на текстуре (UV)
uniform vec2 iris_b = vec2(0.2891, 0.2930);
uniform float iris_r = 0.113;
uniform float pupil = 0.33;           // радиус зрачка в долях радужки
uniform float glow = 0.45;            // свечение радужки (как прежние «точки глаз»)
uniform float glow_k = 0.10;          // сила свечения: вид 2 (как первая Аня) — глаза светятся в темноте
uniform vec3 glow_color : source_color = vec3(0.80, 0.86, 0.96);
uniform float lid = 0.0;              // для совместимости (веки закрываются костями)

void vertex() {
	a3_h = VERTEX.y;
}

void fragment() {
	vec3 col = texture(albedo_tex, UV).rgb * tint.rgb;
	float d = min(distance(UV, iris_a), distance(UV, iris_b)) / iris_r;
	float pm = 1.0 - smoothstep(pupil - 0.05, pupil + 0.04, d);
	col = mix(col, vec3(0.004), pm);
	float iris = (1.0 - smoothstep(0.86, 1.02, d)) * (1.0 - pm);
	ALBEDO = col;
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
	float pulse = 0.85 + 0.15 * sin(TIME * 2.3) * sin(TIME * 0.7 + 1.3);
	EMISSION = glow_color * iris * glow * glow_k * pulse * (0.6 + 0.8 * col.g) + vec3(1.0, 0.3, 0.2) * pm * glow * 0.01;
	RIM = rim;
#ifdef GHOSTLY
	ALPHA = clamp(mix(0.8, 0.4, ghost) * smoothstep(0.0, 0.5, a3_h), 0.0, 1.0);
	ALPHA_HASH_SCALE = 1.0;
#endif
}
