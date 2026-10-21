shader_type spatial;
// Стеклянный глаз куклы: белок, голубая радужка с тёмной каймой, зрачок; блестит как стекло.
varying vec3 lp;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	vec3 d = normalize(lp);
	float a = acos(clamp(d.z, -1.0, 1.0));
	vec3 c = vec3(0.86, 0.83, 0.78);
	if (a < 0.62) {
		c = mix(vec3(0.07, 0.17, 0.38), vec3(0.22, 0.38, 0.62), smoothstep(0.2, 0.55, a));
		c = mix(c, vec3(0.03, 0.05, 0.08), smoothstep(0.52, 0.62, a));
	}
	if (a < 0.24) {
		c = vec3(0.01);
	}
	ALBEDO = c;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
}
