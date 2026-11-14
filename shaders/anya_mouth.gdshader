shader_type spatial;
render_mode cull_back;
// Аня v3: зубы, дёсны, язык — без текстур (цвет по развёртке). kind: 0 — язык и дёсны, 1 — зубы.
#include "res://shaders/anya3.gdshaderinc"
uniform int kind = 0;
uniform vec3 flesh : source_color = vec3(0.23, 0.05, 0.05);
uniform vec3 enamel : source_color = vec3(0.50, 0.47, 0.37);

void vertex() {
	a3_h = VERTEX.y;
}

void fragment() {
	if (near_cut > 0.0 && length(VERTEX) < near_cut) discard;
	vec3 col;
	float rough;
	if (kind == 1) {
		// зуб: у десны тёмный налёт, к краю светлее; на каждом зубе свой оттенок
		float t = UV.y;
		float seed = a3_hash(vec2(floor(UV.x * 28.57), 3.0));
		col = enamel * mix(0.42, 1.0, smoothstep(0.02, 0.5, t)) * mix(0.8, 1.05, seed);
		col = mix(col, vec3(0.16, 0.10, 0.05), (1.0 - smoothstep(0.0, 0.22, t)) * 0.7);
		col *= 0.9 + 0.2 * a3_noise(UV * vec2(600.0, 30.0));
		rough = 0.28;
	} else if (kind == 2) {
		col = vec3(0.012);
		rough = 0.5;
	} else {
		col = flesh * (0.8 + 0.4 * a3_noise(UV * 90.0));
		rough = 0.22;
	}
	float k = (kind == 2) ? 0.0 : clamp(blood * 1.4 - 0.25, 0.0, 0.85);      // кровь во рту
	col = mix(col, vec3(0.12, 0.006, 0.006), k * (kind == 1 ? 0.55 : 0.8));
	ALBEDO = col * tint.rgb;
	ROUGHNESS = rough;
	SPECULAR = 0.5;
#ifdef GHOSTLY
	ALPHA = clamp(mix(0.8, 0.4, ghost) * smoothstep(0.0, 0.5, a3_h), 0.0, 1.0);
	ALPHA_HASH_SCALE = 1.0;
#endif
}
