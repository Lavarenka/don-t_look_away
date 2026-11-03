shader_type spatial;
// Потолок советской квартиры: побелка по бетонным плитам перекрытия. Швы между плитами
// с трещиной и тенью, побелка местами осыпалась (под ней серый бетон), пожелтела от времени
// и табачного дыма — сильнее у стен и над лампой, мелкие трещинки, разводы.
render_mode depth_draw_opaque;

uniform sampler2D base_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 room = vec4(-1.06, 1.06, 0.14, 5.86);    // xmin, xmax, zmin, zmax
uniform vec4 room2 = vec4(-2.86, 2.86, -5.86, -0.14);
uniform float slab = 1.2;                // ширина плиты перекрытия, м
uniform bool slab_along_x = false;       // швы идут вдоль X (иначе вдоль Z)
uniform vec3 lamp = vec3(0.0, 2.8, 3.0); // над лампой — жёлтое пятно от тепла
uniform vec3 lamp2 = vec3(-0.4, 2.8, -3.0);
uniform float age = 1.0;
uniform float seed = 0.0;

varying vec3 v_wp;

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5; float s = 0.0;
	for (int i = 0; i < 5; i++) { s += a * vnoise(p); p = p * 2.05 + 11.7; a *= 0.5; }
	return s;
}
float crack(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float d1 = 8.0; float d2 = 8.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		float d = length(g + hash2(i + g) - f);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return d2 - d1;
}

void fragment() {
	vec2 q = v_wp.xz + seed * 5.1;
	vec3 base = texture(base_tex, UV).rgb;
	float bl = dot(base, vec3(0.3, 0.59, 0.11));
	float n_big = fbm(q * 0.8);
	float n_mid = fbm(q * 4.0);
	float n_fine = vnoise(q * 60.0);
	// побелка: тёплый грязно-белый, кистью неровно (полосы от кисти вдоль одной оси)
	float brush = vnoise(vec2(q.x * 2.0, q.y * 40.0)) * 0.5 + vnoise(vec2(q.x * 6.0, q.y * 90.0)) * 0.5;
	vec3 wash = vec3(0.74, 0.72, 0.66) * mix(0.9, 1.04, brush) * mix(0.92, 1.03, bl * 1.4);
	// расстояние до ближайшей стены (своей комнаты)
	bool in2 = v_wp.x > room2.x - 0.1 && v_wp.x < room2.y + 0.1 && v_wp.z > room2.z - 0.1 && v_wp.z < room2.w + 0.1;
	vec4 rm = in2 ? room2 : room;
	float wd = min(min(v_wp.x - rm.x, rm.y - v_wp.x), min(v_wp.z - rm.z, rm.w - v_wp.z));
	wd = max(wd, 0.0);
	// желтизна: от стен (табачный дым оседает по краям), над лампой, большими разводами
	float yel = clamp(smoothstep(0.9, 0.0, wd) * 0.6 + n_big * 0.5, 0.0, 1.0);
	vec3 lp = in2 ? lamp2 : lamp;
	float near_lamp = smoothstep(0.9, 0.0, length(v_wp.xz - lp.xz));
	yel = max(yel, near_lamp * 0.8);
	vec3 col = mix(wash, wash * vec3(0.86, 0.76, 0.56), yel * age);
	col *= mix(0.86, 1.0, n_mid);                                  // неровно, пятнами
	col *= 1.0 - 0.25 * smoothstep(0.35, 0.0, wd) * age;          // в углах — серо от пыли
	// швы плит перекрытия: тонкая тёмная линия, рядом побелка треснула
	float sa = slab_along_x ? v_wp.z : v_wp.x;
	float sl = sa / slab + 0.37 + hash(vec2(seed, 1.0));
	float sd = abs(fract(sl) - 0.5) * 2.0;                       // 1 — на шве
	float seam = smoothstep(0.975, 0.995, sd + (vnoise(q * 12.0) - 0.5) * 0.012);
	float seam_crack = smoothstep(0.96, 1.0, sd) * smoothstep(0.4, 0.8, vnoise(q * 3.0 + 7.0));
	col = mix(col, col * 0.35, seam * age);
	col = mix(col, col * 0.8, seam_crack * age * 0.6);
	// трещинки в побелке
	float cr = crack(q * 7.0);
	float crk = (1.0 - smoothstep(0.01, 0.04, cr)) * smoothstep(0.4, 0.65, n_mid) * age;
	col = mix(col, col * 0.55, crk);
	// осыпалась побелка: пятна серого бетона с белым краем
	float fl_n = fbm(q * 2.2 + 3.0) + seam_crack * 0.15 + near_lamp * 0.05;
	float flake = smoothstep(0.66, 0.68, fl_n) * age;
	float flake_rim = smoothstep(0.63, 0.66, fl_n) * (1.0 - flake);
	vec3 concrete = vec3(0.46, 0.45, 0.43) * mix(0.8, 1.1, n_fine);
	col = mix(col, concrete, flake);
	col = mix(col, col * 1.06 + 0.02, flake_rim * age);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.9, flake);
	SPECULAR = 0.3;
	// рельеф: шов вдавлен, край осыпи приподнят
	vec3 bn = texture(base_normal, UV).xyz;
	NORMAL_MAP = mix(bn, vec3(0.5, 0.5, 1.0), 0.5);
}
