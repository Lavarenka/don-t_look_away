shader_type spatial;
// Глаз призрака сквозь волосы: жёлто-белая точка с багровым ореолом, чуть «прищуренная»,
// неровно мерцает. Всегда повёрнута к камере; волосы перед лицом её закрывают (depth test).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float power = 0.45;
uniform float seed = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y *= 1.7;                                    // вытянута вбок — как щель между веками
	float r = length(p);
	float core = smoothstep(0.2, 0.0, r);
	float halo = smoothstep(1.0, 0.05, r);
	halo *= halo;
	float fl = 0.8 + 0.2 * sin(TIME * 11.0 + seed) * sin(TIME * 4.7 + seed * 2.3);
	vec3 c = vec3(1.0, 0.93, 0.7) * core * 2.2 + vec3(0.7, 0.04, 0.02) * halo;
	ALBEDO = c * power * fl;
}
