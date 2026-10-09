shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
// Старое стекло: тёмное и прозрачное в лоб; по поверхности бегут узкие блики, изломанные
// волнами раковистого скола; кромка на сломе светится зеленцой.
// Отражения подделаны (у осколка нет настоящего окружения): полоса «окна» по отражённому вектору.
// edge = 1 — материал торца.

uniform vec3 tint : source_color = vec3(0.70, 0.86, 0.80);
uniform float edge = 0.0;
uniform float shine = 1.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	// волны излома: концентрические кольца от точки удара + мелкая рябь
	vec2 q = lp.xz * 1.0;
	float ring = sin(length(q - vec2(-0.05, 0.01)) * 260.0) * 0.5 + sin(q.x * 150.0 + q.y * 90.0) * 0.25;
	vec3 n = normalize(NORMAL + (VIEW_MATRIX * vec4(ring * 0.03, 0.0, ring * 0.02, 0.0)).xyz * (1.0 - edge));
	float facing = clamp(abs(dot(n, VIEW)), 0.0, 1.0);
	float f = pow(1.0 - facing, 3.0);
	vec3 r = reflect(-VIEW, n * sign(dot(n, VIEW) + 1e-4));
	// узкая полоса «окна» сверху и тёплый отблеск сбоку
	float band = (1.0 - smoothstep(0.0, 0.06, abs(r.y - 0.62 - ring * 0.04))) * 0.7;
	float side = (1.0 - smoothstep(0.0, 0.04, abs(r.x - 0.8 - ring * 0.04))) * 0.35;   // узкий тёплый отблеск
	vec3 refl = vec3(0.9, 0.95, 1.0) * band + vec3(1.0, 0.8, 0.55) * side;
	ALBEDO = mix(tint * 0.12, vec3(0.12, 0.28, 0.2), edge);
	ROUGHNESS = mix(0.02, 0.12, edge);
	SPECULAR = 0.12;          // настоящее окружение в осколке почти не отражаем — только наши блики
	METALLIC = 0.0;
	EMISSION = (refl * shine + tint * f * 0.4) * (1.0 - edge * 0.5) + vec3(0.25, 0.45, 0.35) * edge * (0.4 + f);
	ALPHA = clamp(mix(0.10 + f * 0.6 + max(band, side) * 0.6, 0.9, edge), 0.0, 1.0);
}
