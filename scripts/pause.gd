extends CanvasLayer
## Меню паузы по Esc: Продолжить / В главное меню / Выход.

var box: Control


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	box = Control.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.visible = false
	add_child(box)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.custom_minimum_size = Vector2(320, 0)
	v.add_theme_constant_override("separation", 14)
	box.add_child(v)
	var t := Label.new()
	t.text = tr("PAUSE_01")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", Color(0.75, 0.1, 0.08))
	preload("res://scripts/flicker.gd").apply_font(t)
	v.add_child(t)
	_btn(v, "PAUSE_02", resume)
	_btn(v, "PAUSE_03", func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	_btn(v, "MENU_09", func(): get_tree().quit())


func _btn(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = tr(text)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color(0.72, 0.7, 0.66))
	b.add_theme_color_override("font_hover_color", Color(0.9, 0.15, 0.1))
	b.pressed.connect(cb)
	parent.add_child(b)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE:
		if box.visible:
			resume()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	box.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	box.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
