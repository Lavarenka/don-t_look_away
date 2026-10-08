shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Длинные чёрные волосы в воде: каждая прядь — тонкая лента, свободный конец медленно колышется.
// UV.x — от корня (0) к кончику (1), COLOR.r — своя фаза у каждой пряди.

uniform float speed = 0.6;       // быстрее — «шевелятся», когда на них смотрят
uniform float sway = 0.03;

void vertex() {
	float ph = COLOR.r * 6.2832;
	float k = UV.x * UV.x;
	VERTEX.x += sin(TIME * speed + ph + UV.x * 5.0) * sway * k;
	VERTEX.z += cos(TIME * speed * 0.8 + ph * 1.3 + UV.x * 4.0) * sway * 0.8 * k;
	VERTEX.y += sin(TIME * speed * 0.6 + ph * 0.7) * sway * 0.3 * k;
}

void fragment() {
	ALBEDO = vec3(0.014, 0.011, 0.009);
	ALPHA = 0.9 * (1.0 - smoothstep(0.65, 1.0, UV.x));   // кончики растворяются в воде
	ROUGHNESS = 0.32;
	SPECULAR = 0.65;
	// тонкий блик вдоль пряди, как у мокрых волос
	RIM = 0.25;
	RIM_TINT = 0.4;
}
