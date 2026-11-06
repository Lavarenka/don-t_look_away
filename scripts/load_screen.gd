extends Control
## Экран загрузки в стиле игры (поверх фона меню). Выбор — LOAD_STYLE в menu.gd:
##   1 «Фитиль»   — экран темнеет, тонкая тлеющая полоска с искрой на конце, совет — от руки
##   2 «Кассета»  — как запись на старой видеокассете: моноширинный счётчик, полосы помех, таймкод
##   3 «Записка»  — пожелтевший листок с советом от руки, под ним чернилами тянется черта
## Откатить: LOAD_STYLE = 0 в menu.gd — будет прежний экран.

const FN = preload("res://scripts/fonts.gd")

var style := 1
var hint_key := "MENU_04"
var value := 0.0              ## 0..100
var _t := 0.0
var _dim: ColorRect
var _hint: Label
# фитиль
var _fill: ColorRect
var _glow: ColorRect
var _spark: ColorRect
const W1 := 520.0
# кассета
var _pct: Label
var _blocks: Label
var _tc: Label
var _band: ColorRect
var _rec: Label
# записка
var _ink: Line2D
var _ink_pts: PackedVector2Array


func build(st: int, hint: String) -> void:
	style = st
	hint_key = hint
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	match style:
		1: _build_wick()
		2: _build_tape()
		3: _build_note()


func show_screen() -> void:
	visible = true
	var a := {1: 0.72, 2: 0.9, 3: 0.68}.get(style, 0.7) as float
	create_tween().tween_property(_dim, "color:a", a, 0.6)


func fail(text: String) -> void:
	if _hint:
		_hint.text = text


static func _lbl(text: String, font: Font, sz: int, col: Color, spacing := 0) -> Label:
	var l := Label.new()
	l.text = text
	if font:
		if spacing != 0:
			var fv := FontVariation.new()
			fv.base_font = font
			fv.spacing_glyph = spacing
			font = fv
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _centered(c: Control, y: float, w: float, h: float) -> void:
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.offset_left = -w * 0.5
	c.offset_right = w * 0.5
	c.offset_top = y
	c.offset_bottom = y + h


# ---------------- 1. фитиль ----------------
func _build_wick() -> void:
	var t := _lbl(tr("MENU_11").to_upper().replace("…", ""), FN.ENGRAVE, 24, Color(0.78, 0.72, 0.62), 9)
	_centered(t, 40, 700, 40)
	add_child(t)
	var line := Control.new()
	_centered(line, 100, W1, 14)
	add_child(line)
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.17, 0.15, 0.8)
	bg.position = Vector2(0, 6)
	bg.size = Vector2(W1, 1)
	line.add_child(bg)
	_glow = ColorRect.new()                    # тёплый ореол вокруг тлеющей части
	_glow.color = Color(0.9, 0.3, 0.08, 0.16)
	_glow.position = Vector2(0, 3)
	_glow.size = Vector2(0, 7)
	line.add_child(_glow)
	_fill = ColorRect.new()
	_fill.color = Color(0.72, 0.16, 0.06)
	_fill.position = Vector2(0, 5.5)
	_fill.size = Vector2(0, 2)
	line.add_child(_fill)
	_spark = ColorRect.new()                   # искра на конце — дрожит, как огонёк
	_spark.size = Vector2(6, 6)
	_spark.color = Color(1.0, 0.75, 0.35)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() { float d = length(UV - 0.5) * 2.0; COLOR.a *= clamp(1.0 - d, 0.0, 1.0); }"
	sm.shader = sh
	_spark.material = sm
	line.add_child(_spark)
	_hint = _lbl(tr(hint_key), FN.HAND, 27, Color(0.72, 0.67, 0.58))
	_centered(_hint, 130, 900, 50)
	add_child(_hint)


# ---------------- 2. кассета ----------------
func _build_tape() -> void:
	var col := Color(0.82, 0.86, 0.8)
	_rec = _lbl("▶ PLAY", FN.MONO, 22, col)
	_rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_rec.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_rec.position = Vector2(60, 44)
	add_child(_rec)
	_tc = _lbl("00:00:00", FN.MONO, 22, col)
	_tc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tc.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tc.offset_left = -260
	_tc.offset_right = -60
	_tc.offset_top = 44
	add_child(_tc)
	_pct = _lbl("", FN.MONO, 26, col)
	_centered(_pct, -20, 800, 40)
	add_child(_pct)
	_blocks = _lbl("", FN.MONO, 22, col)
	_centered(_blocks, 26, 800, 34)
	add_child(_blocks)
	_hint = _lbl(tr(hint_key).to_upper(), FN.MONO, 17, Color(0.6, 0.63, 0.58))
	_centered(_hint, 84, 1000, 30)
	add_child(_hint)
	_band = ColorRect.new()                    # полоса помех ползёт по экрану
	_band.color = Color(1, 1, 1, 0.045)
	_band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_band.offset_bottom = 26
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)
	var lines := ColorRect.new()               # строки развёртки
	lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() { float l = step(0.5, fract(FRAGCOORD.y * 0.5)); COLOR = vec4(0.0, 0.0, 0.0, 0.18 * l); }"
	sm.shader = sh
	lines.material = sm
	add_child(lines)


# ---------------- 3. записка ----------------
func _build_note() -> void:
	var paper := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.8, 0.75, 0.62)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	paper.add_theme_stylebox_override("panel", sb)
	_centered(paper, -120, 560, 200)
	paper.pivot_offset = Vector2(280, 100)
	paper.rotation = -0.025
	add_child(paper)
	_hint = _lbl(tr(hint_key), FN.HAND, 30, Color(0.18, 0.13, 0.1))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.position = Vector2(30, 24)
	_hint.size = Vector2(500, 110)
	paper.add_child(_hint)
	_ink = Line2D.new()                       # черта от руки — растёт с загрузкой
	_ink.width = 2.6
	_ink.default_color = Color(0.16, 0.12, 0.2, 0.9)
	_ink.joint_mode = Line2D.LINE_JOINT_ROUND
	_ink.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_ink.end_cap_mode = Line2D.LINE_CAP_ROUND
	paper.add_child(_ink)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_ink_pts = PackedVector2Array()
	var y := 150.0
	for i in 61:
		y += rng.randf_range(-0.6, 0.6)
		_ink_pts.append(Vector2(60 + i * 7.3, y + sin(i * 0.4) * 1.2))
	var t := _lbl(tr("MENU_11"), FONTS_TEXT(), 20, Color(0.62, 0.58, 0.52))
	_centered(t, 110, 600, 30)
	add_child(t)


static func FONTS_TEXT() -> Font:
	return preload("res://fonts/Lora-Italic-Variable.ttf")


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	match style:
		1:
			var w := W1 * value / 100.0
			_fill.size.x = w
			_glow.size.x = w
			var fl := 0.7 + 0.3 * sin(_t * 23.0) * sin(_t * 7.3) + randf_range(-0.1, 0.1)
			_spark.position = Vector2(w - 3, 3)
			_spark.modulate.a = clampf(fl, 0.3, 1.0)
			_spark.scale = Vector2.ONE * (1.0 + 0.4 * fl)
			_glow.color.a = 0.12 + 0.06 * fl
		2:
			_pct.text = "%s  %03d%%" % [tr("MENU_11").to_upper().replace("…", ""), int(value)]
			var n := 24
			var k := int(round(value / 100.0 * n))
			_blocks.text = "█".repeat(k) + "░".repeat(n - k)
			var s := int(_t)
			_tc.text = "00:%02d:%02d" % [s / 60, s % 60]
			_rec.modulate.a = 1.0 if fmod(_t, 1.0) < 0.6 else 0.35
			var h := get_viewport_rect().size.y
			_band.offset_top = fmod(_t * 140.0, h + 60.0) - 40.0
			_band.offset_bottom = _band.offset_top + 22.0
		3:
			var m := clampi(int(value / 100.0 * (_ink_pts.size() - 1)) + 1, 1, _ink_pts.size())
			_ink.points = _ink_pts.slice(0, m)
