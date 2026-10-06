extends Node
## Мерцание надписи, как у лампы со сбоем. Добавьте узел ребёнком к Label (или любому CanvasItem).
## Меняет self_modulate, поэтому не мешает плавным появлениям через modulate.

const FONT := preload("res://fonts/CormorantSC-Light.ttf")   ## шрифт названия: тонкий, с большими промежутками
const BONE := Color(0.91, 0.88, 0.82)                          ## цвет «кость»

var _dim_until := 0.0
var _t := 0.0


## Сделать надпись «фирменной»: шрифт с потёками + мерцание.
static func style(l: Label, flicker := true) -> void:
	apply_font(l)
	l.add_theme_color_override("font_color", BONE)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", 14)
	if flicker:
		l.add_child(new())


## Только шрифт с разрядкой букв (≈0.32 высоты), без мерцания.
static func apply_font(l: Label) -> void:
	var fv := FontVariation.new()
	fv.base_font = FONT
	var sz := l.get_theme_font_size("font_size")
	fv.spacing_glyph = int(sz * 0.32)
	l.add_theme_font_override("font", fv)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF      # с переносом строк Godot неверно центрирует разреженный текст


func _process(delta: float) -> void:
	_t += delta
	var p := get_parent() as CanvasItem
	if p == null:
		return
	var a := randf_range(0.86, 1.0)
	if _t < _dim_until:
		a = randf_range(0.12, 0.35)           # провал: надпись почти гаснет
	elif randf() < 0.36 * delta:              # ~раз в 3 секунды
		_dim_until = _t + randf_range(0.05, 0.2)
	p.self_modulate.a = a
