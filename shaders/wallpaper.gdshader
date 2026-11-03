shader_type spatial;
// Стены прихожей и зала (пак Vintage Living Room): дерево панелей и карнизы — из атласа пака,
// а штукатурка заклеена старыми советскими обоями. Обои ложатся по координатам мира (полотна 0.53 м,
// не тянутся вместе с масштабом стены), всё старение считается здесь же и нигде не повторяется:
// выцветание, жёлтые разводы протечек с бурой каймой, плесень у пола и в углах, расходящиеся швы,
// отклеенные куски (под ними штукатурка), засаленная полоса над панелью, копоть под потолком,
// невыцветшие прямоугольники от снятых рамок.
render_mode depth_draw_opaque;

uniform sampler2D atlas_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D atlas_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D atlas_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
// две комнаты — двое обоев; какая комната, решается по точке перед стеной (а не по куску стены:
// у перегородок обе стороны — разные комнаты)
uniform sampler2D paper_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paper_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paper_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paper2_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paper2_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paper2_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 room2 = vec4(-2.86, 2.86, -5.86, -0.14);
uniform float seed2 = 7.9;
uniform float seam_ofs2 = 0.37;
uniform float plaster_v = 0.725;         // ниже этой строки атласа — штукатурка (её и заклеиваем)
uniform vec2 roll = vec2(0.53, 1.06);    // размер рапорта, м
uniform float seam_ofs = 0.0;            // сдвиг полотен, м (у каждой комнаты свой)
uniform float seed = 0.0;
uniform vec4 room = vec4(-1.06, 1.06, 0.14, 5.86);   // xmin, xmax, zmin, zmax — внутренние грани стен
uniform float ceil_y = 2.8;
uniform float panel_y = 0.92;            // верх деревянной панели
uniform float age = 1.0;                 // 0 — новые обои, 1 — как в заброшенном доме
uniform vec4 ghost_a[4];                 // снятые рамки: центр (x, y, z), w — ширина
uniform float ghost_h[4];                //   высота (0 — нет)
uniform int debug = 0;

varying vec3 v_wp;
varying vec3 v_wn;

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5; float s = 0.0;
	for (int i = 0; i < 5; i++) { s += a * vnoise(p); p = p * 2.03 + 17.1; a *= 0.5; }
	return s;
}

void fragment() {
	vec4 at = texture(atlas_albedo, UV);
	vec3 col = at.rgb;
	float rough = texture(atlas_rough, UV).g;
	vec3 nm = texture(atlas_normal, UV).xyz;
	float paper = step(plaster_v, UV.y);
	// в какой комнате эта сторона стены
	vec3 probe = v_wp + normalize(v_wn) * 0.25;
	bool in1 = probe.x > room.x - 0.05 && probe.x < room.y + 0.05 && probe.z > room.z - 0.05 && probe.z < room.w + 0.05;
	bool in2 = probe.x > room2.x - 0.05 && probe.x < room2.y + 0.05 && probe.z > room2.z - 0.05 && probe.z < room2.w + 0.05;
	if (!in1 && !in2) paper = 0.0;                    // сторона в коридор и т.п. — как было
	vec4 rm = in2 && !in1 ? room2 : room;
	float sd_ = in2 && !in1 ? seed2 : seed;
	float so_ = in2 && !in1 ? seam_ofs2 : seam_ofs;
	// ось вдоль стены и координата по ней
	bool xw = abs(v_wn.x) > abs(v_wn.z);
	float u = xw ? v_wp.z : v_wp.x;
	vec3 T = xw ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
	float y = v_wp.y;
	// расстояние до угла комнаты вдоль стены
	float cd = xw ? min(v_wp.z - rm.z, rm.w - v_wp.z) : min(v_wp.x - rm.x, rm.y - v_wp.x);
	cd = max(cd, 0.0);
	vec2 wq = vec2(u + sd_ * 13.7, y);              // точка на стене для шумов
	float n_big = fbm(wq * 0.7 + sd_);
	float n_mid = fbm(wq * 3.1 + sd_ * 2.0);
	float n_fine = vnoise(wq * 40.0);

	// старение дерева панелей и карнизов: пыль в порах, затёртости
	vec3 wood = col * mix(0.82, 1.0, n_mid);
	wood = mix(wood, wood * 0.7, smoothstep(0.25, 0.0, y) * age);   // у пола темнее (швабра, грязь)

	// --- обои
	float pu = u + so_;
	float strip = floor(pu / roll.x);
	float lu = pu - strip * roll.x;                   // позиция внутри полотна
	// полотна наклеены чуть криво и с разным сдвигом по вертикали
	float vs = hash(vec2(strip, sd_)) * 0.3;
	vec2 puv = vec2(lu / roll.x, -(y + vs) / roll.y);
	bool second = in2 && !in1;
	vec3 pc0 = second ? texture(paper2_albedo, puv).rgb : texture(paper_albedo, puv).rgb;
	vec3 pc = pc0;
	// только RG: при импорте как карта нормалей синий канал может пропасть — восстанавливаем
	vec2 pnxy = (second ? texture(paper2_normal, puv).xy : texture(paper_normal, puv).xy) * 2.0 - 1.0;
	vec3 pn = vec3(pnxy, sqrt(max(1.0 - dot(pnxy, pnxy), 0.0)));
	float pr = second ? texture(paper2_rough, puv).r : texture(paper_rough, puv).r;
	// выцветание: большими пятнами, сильнее у окон и выше (солнце), краска бледнеет и желтеет
	float fade = clamp(0.35 + 0.5 * n_big + 0.15 * smoothstep(0.8, 2.4, y), 0.0, 1.0) * age;
	float pl = dot(pc, vec3(0.3, 0.59, 0.11));
	pc = mix(pc, vec3(pl) * vec3(1.06, 1.0, 0.82) + 0.04, fade * 0.7);
	// краска узора села в бумагу, всё слегка посерело и пожелтело от времени и табачного дыма
	pc = mix(pc, vec3(dot(pc, vec3(0.33))), 0.2 * age) * mix(vec3(1.0), vec3(0.9, 0.84, 0.7), (0.5 + 0.5 * n_big) * age);
	// снятые рамки: прямоугольник ярче и насыщеннее (не выгорел), по краю — пыльная кайма
	float gmask = 0.0; float gedge = 0.0;
	for (int i = 0; i < 4; i++) {
		if (ghost_h[i] <= 0.0) continue;
		vec3 c = ghost_a[i].xyz;
		float gu = xw ? v_wp.z - c.z : v_wp.x - c.x;
		float gn = xw ? abs(v_wp.x - c.x) : abs(v_wp.z - c.z);
		if (gn > 0.25) continue;
		vec2 dd = abs(vec2(gu, y - c.y)) - vec2(ghost_a[i].w, ghost_h[i]) * 0.5;
		float inside = 1.0 - smoothstep(-0.008, 0.004, max(dd.x, dd.y));
		gmask = max(gmask, inside);
		gedge = max(gedge, smoothstep(0.02, 0.0, abs(max(dd.x, dd.y))) * (0.6 + 0.4 * n_fine));
	}
	pc = mix(pc, pc0 * vec3(1.0, 0.98, 0.94), gmask * age);
	pc = mix(pc, pc * 0.62, gedge * age);
	// протечки: жёлто-бурые разводы с тёмной «береговой линией», текут сверху и от углов
	float leak_src = smoothstep(0.9, 0.0, (ceil_y - y) / 1.4) * (0.4 + 0.6 * smoothstep(0.8, 0.0, cd)) + smoothstep(0.6, 0.0, y - panel_y) * 0.25;
	float lk = fbm(vec2(u * 1.6, y * 0.9) + sd_ * 3.0 + vec2(0.0, n_mid * 0.6));
	float lv = lk + leak_src * 0.4 - 0.08;
	float leak = smoothstep(0.62, 0.68, lv) * age;
	float ring = smoothstep(0.62, 0.635, lv) - smoothstep(0.64, 0.67, lv);
	pc = mix(pc, pc * vec3(0.8, 0.66, 0.44), leak * 0.85);
	// потёки воды сверху: вертикальные полосы, тают книзу
	float run = smoothstep(0.72, 0.9, vnoise(vec2(u * 9.0 + sd_, y * 0.35))) * smoothstep(0.3, 1.6, y - panel_y) * smoothstep(1.8, 0.0, ceil_y - y) * age;
	pc = mix(pc, pc * vec3(0.78, 0.68, 0.5), run * 0.6);
	pc = mix(pc, pc * vec3(0.55, 0.42, 0.28), ring * age * 0.9);
	// плесень: тёмно-зелёные крапинки внизу и в углах
	float mold_zone = smoothstep(0.7, 0.0, cd) * (smoothstep(1.4, panel_y, y) + smoothstep(ceil_y - 0.7, ceil_y, y));
	float mold = smoothstep(0.55, 0.85, vnoise(wq * 26.0) * 0.6 + vnoise(wq * 7.0) * 0.6) * mold_zone * age;
	pc = mix(pc, vec3(0.16, 0.18, 0.12), mold * 0.85);
	// засаленная полоса над панелью (руки, спины) и копоть под потолком
	pc *= 1.0 - 0.25 * smoothstep(0.45, 0.0, y - panel_y) * (0.6 + 0.4 * n_mid) * age;
	pc *= 1.0 - 0.3 * smoothstep(0.6, 0.0, ceil_y - y) * (0.5 + 0.5 * n_big) * age;
	// в углах — темнее (пыль, сырость, туда не доходит свет)
	pc *= 1.0 - 0.28 * smoothstep(0.45, 0.0, cd) * age;
	// швы между полотнами: расходятся, края чуть отстают и темнеют
	float sd = min(lu, roll.x - lu);
	float gap = (0.0015 + 0.003 * vnoise(vec2(strip, y * 3.0))) * age;
	float seam = 1.0 - smoothstep(gap, gap + 0.004, sd);
	// отклеенные куски: у шва, местами, сильнее у потолка и над панелью — под ними штукатурка
	float peel_n = vnoise(vec2(strip * 3.7 + sd_, y * 2.2));
	float peel_w = (smoothstep(0.8, 0.95, peel_n) * smoothstep(1.7, ceil_y - 0.1, y) + smoothstep(0.86, 0.97, peel_n) * smoothstep(0.35, 0.0, y - panel_y)) * 0.08 * age;
	float edge_u = (lu < roll.x * 0.5) ? lu : roll.x - lu;
	float peel = 1.0 - smoothstep(peel_w * 0.85, peel_w, edge_u + n_fine * 0.004);
	float lip = smoothstep(peel_w * 0.6, peel_w, edge_u) * (1.0 - smoothstep(peel_w, peel_w * 1.25 + 0.003, edge_u)) * step(0.001, peel_w);
	vec3 plaster = col * vec3(0.95, 0.93, 0.9) * mix(0.8, 1.0, n_mid);
	plaster *= 1.0 - 0.35 * smoothstep(0.012, 0.0, abs(edge_u - peel_w));   // тень от отставшего края
	vec3 paperc = mix(pc, pc * 0.55, seam);
	paperc = mix(paperc, plaster, peel);
	paperc = mix(paperc, paperc * 1.12, lip * (1.0 - peel));              // загнутый край ловит свет
	float paper_rough_v = mix(pr, 0.95, max(peel, leak * 0.3));
	paper_rough_v = mix(paper_rough_v, 0.55, mold * 0.0);

	col = mix(wood, paperc, paper);
	rough = mix(rough, paper_rough_v, paper);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = mix(0.5, 0.35, paper);
	// нормали: дерево — из атласа (касательные меша), обои — рельеф бумаги в осях стены
	vec3 Nw = normalize(v_wn);
	float lift = (seam + lip) * 0.4 * (1.0 - peel);
	vec3 pnw = normalize(Nw * max(pn.z, 0.2) + T * (pn.x + lift * sign(lu - roll.x * 0.5)) * 0.9 + vec3(0.0, 1.0, 0.0) * pn.y * 0.9);
	if (paper > 0.5) {
		NORMAL = normalize((VIEW_MATRIX * vec4(pnw, 0.0)).xyz);
	} else {
		NORMAL_MAP = nm;
	}
	if (debug == 1) ALBEDO = vec3(paper, peel, leak);
	if (debug == 2) ALBEDO = vec3(fract(puv), 0.0);
}
