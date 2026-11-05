extends RefCounted
## Надписи «в мире»: текст запекается в текстуру и ложится прямо на поверхность, а не висит в воздухе
## плоской игровой табличкой (Label3D).
##   soot()   — сажей по стене: декаль (проецируется на обои, повторяет стену), края размыты, сажа неровная
##   paper()  — листок на двери, детские буквы восковым мелком, по углам скотч
##   enamel() — эмалированная табличка на двери: тёмно-синие буквы на кремовой эмали, сколы по краю
## Текст запекается один раз при загрузке на видеокарте (два SubViewport: буквы → обработка шейдером).
## Текст берётся через tr() — работает и на русском, и на английском.
## Откатить: ENABLED = false (вернутся прежние Label3D — см. hall_puzzle.gd, floor2.gd; надписи кровью в
## коридоре снова станут как были по глубине декали — level.gd, _localize_scene).

const ENABLED := true
const FONTS = preload("res://scripts/fonts.gd")

const NOISE := """
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fb(vec2 p) { return vn(p) * 0.55 + vn(p * 2.1) * 0.3 + vn(p * 4.3) * 0.15; }
"""

## Сажа: размытая кайма + неровная густота (где пальцем прошлись гуще, где сажи мало).
const FX_SOOT := """
shader_type canvas_item;
render_mode blend_disabled;
uniform float seed = 1.0;
%s
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 p = UV / px;
	float a = texture(TEXTURE, UV).a;
	float s = 0.0;
	for (int i = -3; i <= 3; i++)
		for (int j = -3; j <= 3; j++)
			s += texture(TEXTURE, UV + vec2(float(i), float(j)) * px * 4.0).a;
	s /= 49.0;
	float g = fb(p * 0.09 + seed);
	float b = fb(p * 0.012 + seed * 3.1);
	float k = clamp(a * (0.45 + 0.75 * g) * (0.6 + 0.6 * b) + s * 0.4 * b, 0.0, 1.0);
	COLOR = vec4(1.0, 1.0, 1.0, k);
}
"""

## Листок: пожелтевшая бумага (края темнее), буквы восковым мелком — с просветами.
const FX_CRAYON := """
shader_type canvas_item;
render_mode blend_disabled;
uniform float seed = 1.0;
uniform vec4 ink : source_color;
uniform vec4 paper : source_color;
%s
void fragment() {
	vec2 p = UV / TEXTURE_PIXEL_SIZE;
	float a = texture(TEXTURE, UV).a;
	float g = vn(p * 0.35 + seed);
	float f = fb(p * 0.02 + seed * 2.0);
	float e = clamp(min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)) * 9.0, 0.0, 1.0);
	vec3 pc = paper.rgb * (0.82 + 0.18 * e) * (0.9 + 0.14 * f);
	float k = a * clamp((g - 0.2) * 2.6, 0.4, 1.0);
	COLOR = vec4(mix(pc, ink.rgb, k * 0.95), 1.0);
}
"""

## Эмаль: кремовая, синяя рамка и буквы, у края — сколы до ржавой жести.
const FX_ENAMEL := """
shader_type canvas_item;
render_mode blend_disabled;
uniform float seed = 1.0;
%s
void fragment() {
	vec2 sz = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 p = UV * sz;
	float a = texture(TEXTURE, UV).a;
	vec3 cream = vec3(0.86, 0.84, 0.76) * (0.9 + 0.12 * fb(p * 0.015 + seed));
	vec3 ink = vec3(0.1, 0.16, 0.32);
	vec3 rust = vec3(0.24, 0.14, 0.08);
	float bd = min(min(p.x, sz.x - p.x), min(p.y, sz.y - p.y));
	vec3 c = (bd >= 9.0 && bd <= 13.0) ? ink : cream;
	c = mix(c, ink, a);
	float ch = fb(p * 0.05 + seed * 5.0);
	if (bd < 18.0 && ch > 0.66 + bd * 0.012)
		c = rust * (0.8 + 0.4 * ch);
	COLOR = vec4(c, 1.0);
}
"""


## Каракули жирнее обычного (Caveat — вариативный шрифт, толщина 700): мелок и палец толстые.
static func _bold() -> Font:
	var fv := FontVariation.new()
	fv.base_font = FONTS.SCRAWL
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	return fv


## Текст → обработка шейдером → ImageTexture. Корутина.
## sz = ZERO — размер картинки по тексту; иначе шрифт уменьшается, чтобы текст влез с полями.
static func _bake(host: Node, text: String, font: Font, fsize: int, sz: Vector2i, line_sp: int, fx: String, params: Dictionary) -> ImageTexture:
	var ts := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
	ts.y += line_sp * text.count("\n")
	if sz == Vector2i.ZERO:
		sz = Vector2i(int(ts.x + fsize * 0.6), int(ts.y + fsize * 0.5))
	else:
		var k := minf(sz.x * 0.86 / ts.x, sz.y * 0.8 / ts.y)
		if k < 1.0:
			fsize = int(fsize * k)
			line_sp = int(line_sp * k)
	var vp1 := SubViewport.new()
	vp1.size = sz
	vp1.transparent_bg = true
	vp1.disable_3d = true
	vp1.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var l := Label.new()
	l.text = text
	l.size = Vector2(sz)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_constant_override("line_spacing", line_sp)
	vp1.add_child(l)
	host.add_child(vp1)
	var vp2 := SubViewport.new()
	vp2.size = sz
	vp2.transparent_bg = true
	vp2.disable_3d = true
	vp2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var rect := TextureRect.new()
	rect.texture = vp1.get_texture()
	rect.size = Vector2(sz)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = fx % NOISE
	sm.shader = sh
	for k in params:
		sm.set_shader_parameter(k, params[k])
	rect.material = sm
	vp2.add_child(rect)
	host.add_child(vp2)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var im := vp2.get_texture().get_image()
	vp1.queue_free()
	vp2.queue_free()
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)


## Матовость для декали (ORM: AO=1, шероховатость, металл=0) — сажа и засохшая кровь не блестят,
## иначе блик обоев просвечивает сквозь надпись и она кажется бледной.
static func matte(rough := 0.95) -> ImageTexture:
	var im := Image.create(4, 4, false, Image.FORMAT_RGB8)
	im.fill(Color(1.0, rough, 0.0))
	return ImageTexture.create_from_image(im)


## Базис для поверхности: into — направление в стену (нормаль наружу = -into), текст читается слева направо.
static func _basis(into: Vector3, tilt: float) -> Basis:
	var y := -into.normalized()
	var z := Vector3.DOWN
	var x := y.cross(z).normalized()
	return Basis(x, y, z).rotated(y, tilt)


# ---------------- сажа на стене ----------------
## pos — точка на самой стене (центр надписи); letter_h — высота строки, м;
## layer — слой видимости (например, только в зеркале).
static func soot(host: Node3D, text: String, pos: Vector3, into: Vector3, letter_h: float, col: Color, layer := 1, tilt := 0.0, seed := 1) -> Decal:
	var d := Decal.new()
	d.layers = layer
	d.modulate = col
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	d.size = Vector3(0.01, 0.2, 0.01)
	d.texture_orm = matte()
	host.add_child(d)
	d.global_transform = Transform3D(_basis(into, tilt), pos)
	_fill_soot(d, host, text, letter_h, seed)
	return d


static func _fill_soot(d: Decal, host: Node, text: String, letter_h: float, seed: int) -> void:
	var fs := 110
	var tex := await _bake(host, text, _bold(), fs, Vector2i.ZERO, -20, FX_SOOT, {"seed": float(seed)})
	if not is_instance_valid(d):
		return
	var sz := tex.get_size()
	var mpp := letter_h / fs                      # метров на пиксель
	d.size = Vector3(sz.x * mpp, 0.2, sz.y * mpp)
	d.texture_albedo = tex


# ---------------- листок на двери (детские буквы мелком) ----------------
## holder — узел на поверхности двери (его -Z смотрит в дверь, +Z — на игрока).
static func paper(holder: Node3D, text: String, col: Color, w := 0.3, h := 0.22, seed := 3) -> void:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	q.mesh = qm
	q.position = Vector3(0, 0, 0.0015)
	q.rotation.z = 0.05
	var m := StandardMaterial3D.new()
	m.roughness = 0.95
	m.albedo_color = Color(0.74, 0.7, 0.58)
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(q)
	# скотч по верхним углам
	for sx in [-1.0, 1.0]:
		var t := MeshInstance3D.new()
		var tm := QuadMesh.new()
		tm.size = Vector2(0.07, 0.022)
		t.mesh = tm
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color(0.85, 0.75, 0.45, 0.55)
		tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tmat.roughness = 0.3
		t.material_override = tmat
		t.position = Vector3(sx * (w * 0.5 - 0.02), h * 0.5 - 0.012, 0.0025)
		t.rotation.z = 0.05 - sx * 0.6
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(t)
	_fill_paper(m, holder, text, col, seed)


static func _fill_paper(m: StandardMaterial3D, host: Node, text: String, col: Color, seed: int) -> void:
	var tex := await _bake(host, text, _bold(), 130, Vector2i(600, 440), -22, FX_CRAYON,
			{"seed": float(seed), "ink": col, "paper": Color(0.74, 0.7, 0.58)})
	m.albedo_color = Color.WHITE
	m.albedo_texture = tex


# ---------------- эмалированная табличка ----------------
static func enamel(holder: Node3D, text: String, w := 0.2, h := 0.07, seed := 5) -> void:
	var back := MeshInstance3D.new()                # жестяная основа — видна толщина
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, 0.003)
	back.mesh = bm
	var mb := StandardMaterial3D.new()
	mb.albedo_color = Color(0.82, 0.8, 0.72)
	mb.roughness = 0.35
	back.material_override = mb
	back.position = Vector3(0, 0, 0.0015)
	holder.add_child(back)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	q.mesh = qm
	q.position = Vector3(0, 0, 0.0031)
	var m := StandardMaterial3D.new()
	m.roughness = 0.22
	m.albedo_color = Color(0.85, 0.83, 0.75)
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(q)
	_fill_enamel(m, holder, text, w / h, seed)


static func _fill_enamel(m: StandardMaterial3D, host: Node, text: String, aspect: float, seed: int) -> void:
	var tex := await _bake(host, text, FONTS.UI, 96, Vector2i(int(180 * aspect), 180), 0, FX_ENAMEL, {"seed": float(seed)})
	m.albedo_color = Color.WHITE
	m.albedo_texture = tex
