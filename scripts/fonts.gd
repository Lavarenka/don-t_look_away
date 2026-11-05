extends RefCounted
## Шрифты по ролям (все — OFL, с кириллицей; лицензии в fonts/OFL_*.txt).
##   UI      — PT Serif: субтитры, подсказки, задания, пауза, всё, где раньше был шрифт Godot по умолчанию
##   HAND    — Marck Script: записки и бумажки, написанные от руки взрослым
##   SCRAWL  — Caveat: каракули сажей и кровью на стенах и зеркале
##   ENGRAVE — Cormorant SC: гравировка на латунных табличках рамок
##   MONO    — PT Mono: цифры на экране телевизора
## Надписи в 3D (Label3D) — через MSDF: чёткие вблизи, не «мылятся».
## Откатить: ENABLED = false — всё вернётся как было (шрифт Godot по умолчанию).

const ENABLED := true
const UI := preload("res://fonts/PTSerif-Regular.ttf")
const UI_ITALIC := preload("res://fonts/PTSerif-Italic.ttf")
const HAND := preload("res://fonts/MarckScript-Regular.ttf")
const SCRAWL := preload("res://fonts/Caveat-Variable.ttf")
const ENGRAVE := preload("res://fonts/CormorantSC-Light.ttf")
const MONO := preload("res://fonts/PTMono-Regular.ttf")

static var _msdf := {}


## Шрифт по умолчанию для всего интерфейса (и для Label3D без своего шрифта).
static func apply_default() -> void:
	if not ENABLED:
		return
	var th := ThemeDB.get_default_theme()
	if th and th.default_font != UI:
		th.default_font = UI


## Субтитры и подсказки поверх игры: мягкая тёмная обводка + тень — читаются и на светлом.
static func subtitle(l: Label) -> void:
	if not ENABLED:
		return
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)


## Свой шрифт для обычной надписи интерфейса (size_k — рукописные мельче на вид, их чуть увеличиваем).
static func set_font(l: Control, f: Font, size_k := 1.0) -> void:
	if not ENABLED:
		return
	l.add_theme_font_override("font", f)
	if size_k != 1.0 and l.has_theme_font_size_override("font_size"):
		l.add_theme_font_size_override("font_size", int(round(l.get_theme_font_size("font_size") * size_k)))


## Надпись в 3D: шрифт с MSDF (резкие края на любом расстоянии). У Caveat (вариативный шрифт,
## контуры букв накладываются) MSDF даёт мусорные штрихи — его рисуем обычным способом.
static func label3d(l: Label3D, f: FontFile, size_k := 1.0) -> void:
	if not ENABLED or l == null:
		return
	if f == SCRAWL:
		l.font = f
	elif not _msdf.has(f):
		var d := f.duplicate() as FontFile
		d.multichannel_signed_distance_field = true
		d.msdf_pixel_range = 14
		d.msdf_size = 64
		_msdf[f] = d
	if f != SCRAWL:
		l.font = _msdf[f]
	if size_k != 1.0:
		l.font_size = int(round(l.font_size * size_k))
