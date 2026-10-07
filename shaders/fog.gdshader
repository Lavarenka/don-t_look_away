shader_type spatial;
render_mode cull_disabled, shadows_disabled;
// Запотевшее зеркало ванной: туман (base_tex) и цифры кода, «стёртые» пальцем.
// Цифры берутся из атласа fog_digits.png (10 клеток 170×290), код задаётся из bathroom.gd.
// mirrored — надпись видна задом наперёд (как если бы писали с той стороны стекла).

uniform sampler2D base_tex : source_color, filter_linear_mipmap;
uniform sampler2D digits : filter_linear;
uniform vec3 code = vec3(3.0, 4.0, 7.0);
uniform bool mirrored = false;
uniform float fade = 0.0;

const vec2 TEX = vec2(640.0, 500.0);
const vec2 CELL = vec2(170.0, 290.0);

float digit_mask(vec2 uv, float slot_x, float d) {
	vec2 q = (uv * TEX - vec2(slot_x, 95.0)) / CELL;
	if (q.x < 0.0 || q.x > 1.0 || q.y < 0.0 || q.y > 1.0) return 0.0;
	q.x = clamp(q.x, 0.02, 0.98);
	return texture(digits, vec2((d + q.x) / 10.0, q.y)).r;
}

void fragment() {
	vec2 uv = UV;
	if (mirrored) uv.x = 1.0 - uv.x;
	vec4 b = texture(base_tex, uv);
	float m = max(max(digit_mask(uv, 65.0, code.x), digit_mask(uv, 235.0, code.y)), digit_mask(uv, 400.0, code.z));
	ALBEDO = b.rgb;
	ALPHA = b.a * (1.0 - 0.88 * m) * fade;
	ROUGHNESS = 0.9;
}
