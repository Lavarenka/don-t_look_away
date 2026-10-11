extends CanvasLayer
## Счётчик кадров в правом верхнем углу: FPS, время кадра, качество графики.
## Живёт в корне дерева (переживает смену сцен), создаётся из settings.gd → apply_general().
## Вкл/выкл — галочка в настройках или F3 (запоминается).

const SETTINGS = preload("res://scripts/settings.gd")

var label: Label
var _t := 0.0
var _frames := 0
var _worst := 0.0


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	label = Label.new()
	label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.position = Vector2(-330, 10)
	label.size = Vector2(320, 30)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.75))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	visible = SETTINGS.get_show_fps()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_frames += 1
	_worst = maxf(_worst, delta)
	if _t >= 0.5:               # два раза в секунду: среднее и худший кадр за полсекунды
		var fps := _frames / _t
		label.text = "FPS %d   %.1f ms (max %.0f)   %s" % [roundi(fps), 1000.0 * _t / _frames, 1000.0 * _worst, tr(SETTINGS.NAMES[SETTINGS.get_quality()])]
		var c := Color(0.85, 0.95, 0.75) if fps >= 55 else (Color(1.0, 0.85, 0.4) if fps >= 30 else Color(1.0, 0.45, 0.4))
		label.add_theme_color_override("font_color", c)
		_t = 0.0
		_frames = 0
		_worst = 0.0


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F3:
		SETTINGS.set_val("video", "fps", not visible)
		visible = not visible
		_t = 0.0
		_frames = 0
