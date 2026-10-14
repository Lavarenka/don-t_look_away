shader_type spatial;
// Пламя свечи: капля с голубоватым низом и жёлто-белой сердцевиной, дрожит; всегда к камере (по вертикали).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

void vertex() {
	vec3 up = normalize(MODEL_MATRIX[1].xyz);
	vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz);
	vec3 right = normalize(cross(up, to_cam));
	vec3 fwd = cross(right, up);
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * sx, 0.0), vec4(up * sy, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;                                      // +1 — верх
	float t = TIME;
	p.x += sin(t * 13.0 + p.y * 3.0) * 0.06 * (p.y + 1.0);
	float w = mix(0.55, 0.05, smoothstep(-0.6, 1.0, p.y)) * (1.0 - smoothstep(0.6, 1.0, p.y) * 0.4);
	float body = 1.0 - smoothstep(w * 0.7, w, abs(p.x));
	body *= smoothstep(-1.0, -0.55, p.y) * (1.0 - smoothstep(0.75, 1.0, p.y));
	float core = (1.0 - smoothstep(0.0, w * 0.45, abs(p.x))) * smoothstep(-0.7, -0.3, p.y) * (1.0 - smoothstep(0.1, 0.6, p.y));
	vec3 c = vec3(1.0, 0.55, 0.15) * body * 1.6 + vec3(1.0, 0.9, 0.7) * core * 2.0;
	c += vec3(0.15, 0.25, 0.8) * body * (1.0 - smoothstep(-0.9, -0.5, p.y)) * 1.5;   // синеватый низ
	ALBEDO = c;
}
