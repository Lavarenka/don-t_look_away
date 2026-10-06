extends Control
## Главное меню и экран загрузки.

const GAME_SCENE := "res://scenes/main.tscn"
const HINTS := [
	"MENU_01",
	"MENU_02",
	"MENU_03",
	"MENU_04",
]

var _buttons: VBoxContainer
var _loading: VBoxContainer
var _bar: ProgressBar
var _hint: Label
var _loading_started := false
var _t_load := 0.0
var _drone: AudioStreamPlayer


const SETTINGS = preload("res://scripts/settings.gd")
const FLICKER = preload("res://scripts/flicker.gd")
var _grain_mat: ShaderMaterial

# ---- живой фон: заранее отрендеренный коридор + поверх него 3D-призрак в том же ракурсе ----
var CAM_XF: Transform3D = str_to_var("Transform3D(0.99782705, -0.0063137123, 0.06558462, 0, 0.9953982, 0.095825166, -0.06588782, -0.09561695, 0.99323523, -0.3, 1.65, 2.5)")
var FLASH_XF: Transform3D = str_to_var("Transform3D(0.9942423, 0.013865624, -0.10625452, 0, 0.9915928, 0.12939733, 0.10715539, -0.1286523, 0.98588353, -0.07921533, 1.4509205, 2.5046284)")
var GIRL_XF: Transform3D = str_to_var("Transform3D(0.98412704, 0, -0.17746553, 0, 1, 0, 0.17746553, 0, 0.98412704, 0.25, 0, -0.55)")
const FLASH_E := 7.0
var _plate: TextureRect
var _live: TextureRect
var _flash: SpotLight3D
var _girl: Node3D
var _fl := 1.0            ## яркость фонарика 0..1
var _fl_t := 0.0
var _next_fl := 4.0       ## когда следующий сбой фонарика
var _burst := 0.0         ## сколько ещё длится сбой
var _deep := false        ## глубокий сбой: фонарик гаснет почти полностью


func _ready() -> void:
	SETTINGS.apply_lang()
	SETTINGS.apply_general()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate = _cover(load("res://textures/menu_plate.jpg"))
	add_child(_plate)
	_build_live()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var grain := ColorRect.new()
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/grain.gdshader")
	grain.material = gm
	_grain_mat = gm
	add_child(grain)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	box.position = Vector2(90, -170)
	box.add_theme_constant_override("separation", 26)
	add_child(box)
	var title := _label("MENU_05", 50, Color(0.9, 0.86, 0.78))
	FLICKER.style(title)
	box.add_child(title)
	box.add_child(_label("MENU_06", 18, Color(0.55, 0.52, 0.47)))

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	box.add_child(_buttons)
	_page_main()
	box.add_child(_label("MENU_10", 15, Color(0.5, 0.48, 0.44)))

	_loading = VBoxContainer.new()
	_loading.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_loading.position = Vector2(-300, -170)
	_loading.custom_minimum_size = Vector2(600, 0)
	_loading.add_theme_constant_override("separation", 12)
	_loading.visible = false
	add_child(_loading)
	var lt := _label("MENU_11", 26, Color(0.85, 0.82, 0.75))
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading.add_child(lt)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(600, 6)
	var bgs := StyleBoxFlat.new(); bgs.bg_color = Color(0.15, 0.14, 0.13)
	var fgs := StyleBoxFlat.new(); fgs.bg_color = Color(0.6, 0.08, 0.05)
	_bar.add_theme_stylebox_override("background", bgs)
	_bar.add_theme_stylebox_override("fill", fgs)
	_loading.add_child(_bar)
	_hint = _label(HINTS[randi() % HINTS.size()], 18, Color(0.6, 0.57, 0.52))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading.add_child(_hint)

	_drone = AudioStreamPlayer.new()
	_drone.stream = load("res://audio/drone.wav")
	_drone.volume_db = -10.0
	add_child(_drone)
	_drone.finished.connect(_drone.play)
	_drone.play()
	if Engine.has_meta("menu_page"):
		Engine.remove_meta("menu_page")
		_page_settings()
	# вернулись из заставки — сразу загружаем уровень
	if Engine.has_meta("after_intro"):
		Engine.remove_meta("after_intro")
		_start()


## Картинка на весь экран с обрезкой по краям (как фон).
func _cover(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Призрак в дверном проёме: свой маленький 3D-мир с прозрачным фоном,
## камера и фонарик стоят ровно там, где снимался фон, — она «вписана» в картинку.
func _build_live() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.5)
	env.ambient_light_energy = 0.1
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.75
	env.adjustment_contrast = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 68.0
	cam.transform = CAM_XF
	vp.add_child(cam)
	_flash = SpotLight3D.new()
	_flash.transform = FLASH_XF
	_flash.light_color = Color(1, 0.94, 0.82)
	_flash.light_energy = FLASH_E
	_flash.shadow_enabled = true
	_flash.shadow_bias = 0.08
	_flash.shadow_normal_bias = 2.5
	_flash.spot_range = 18.0
	_flash.spot_attenuation = 1.2
	_flash.spot_angle = 24.0
	_flash.spot_angle_attenuation = 1.5
	vp.add_child(_flash)
	_girl = Node3D.new()
	_girl.set_script(load("res://scripts/spirit.gd"))
	_girl.transform = GIRL_XF
	vp.add_child(_girl)
	_girl.play("idle", 0.4)
	_girl.set_blood(0.35)
	_girl.ap.seek(randf() * 3.0, true)
	# пылинки в луче фонарика
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.2, 1.0, 1.6)
	pm.gravity = Vector3(0, -0.015, 0)
	pm.initial_velocity_max = 0.05
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.3
	var dm := StandardMaterial3D.new()
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.9, 0.88, 0.8, 0.5)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var q := QuadMesh.new()
	q.size = Vector2(0.008, 0.008)
	q.material = dm
	var dust := GPUParticles3D.new()
	dust.amount = 250
	dust.lifetime = 10.0
	dust.preprocess = 10.0
	dust.process_material = pm
	dust.draw_pass_1 = q
	dust.position = Vector3(0, 1.4, 0.6)
	dust.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	vp.add_child(dust)
	_live = _cover(vp.get_texture())
	add_child(_live)


## Фонарик: почти всегда ровный, иногда коротко «моргает»,
## изредка гаснет — и в темноте призрак меняет позу или исчезает.
func _flicker(delta: float) -> void:
	_fl_t += delta
	var target := 1.0 - 0.04 * sin(_fl_t * 1.7) * sin(_fl_t * 4.3)
	if _burst > 0.0:
		_burst -= delta
		if randf() < delta * 22.0:
			_fl = randf_range(0.0, 0.25) if _deep else randf_range(0.25, 0.85)
		if _burst <= 0.0:
			if _deep and randf() < 0.5:
				_ghost_shift()
			_deep = false
			_next_fl = _fl_t + randf_range(3.0, 8.0)
	else:
		_fl = move_toward(_fl, target, delta * 6.0)
		if _fl_t > _next_fl:
			_deep = randf() < 0.3
			_burst = randf_range(0.5, 0.9) if _deep else randf_range(0.12, 0.35)
	_flash.light_energy = FLASH_E * _fl
	var c := Color(_fl, _fl, _fl)
	_plate.modulate = c


## Пока фонарик моргает, она успевает «перемениться».
func _ghost_shift() -> void:
	if not _girl.visible:
		_girl.visible = true
		_girl.play("idle", 0.4, 0.0)
	elif randf() < 0.3:
		_girl.visible = false
	elif randf() < 0.5:
		_girl.play_from("zidle", randf() * 2.0, 0.5)
	else:
		_girl.play("idle", 0.4, 0.0)


func _clear() -> void:
	for c in _buttons.get_children():
		_buttons.remove_child(c)
		c.queue_free()


func _page_main() -> void:
	_clear()
	_button("MENU_07", func(): get_tree().change_scene_to_file("res://scenes/intro.tscn"))
	_button("MENU_CHAPTERS", _page_chapters)
	_button("MENU_SETTINGS", _page_settings)
	_button("MENU_09", func(): get_tree().quit())


## Выбор главы: сразу загружает уровень (без заставки) и переносит в начало главы.
func _page_chapters() -> void:
	_clear()
	for n in range(1, 6):
		var open: bool = SETTINGS.UNLOCK_ALL or n <= SETTINGS.reached()
		var b := _button("CH_%d" % n if open else "CH_LOCKED", func():
			Engine.set_meta("chapter", n)
			_start())
		b.disabled = not open
	_button("MENU_BACK", _page_main)


## Настройки: каждая кнопка переключает значение по кругу и сразу применяет его.
func _page_settings() -> void:
	_clear()
	var gb := _button("", func(): pass)
	var upd := func(): gb.text = tr("MENU_08") + tr(SETTINGS.NAMES[SETTINGS.get_quality()])
	upd.call()
	gb.pressed.connect(func():
		SETTINGS.set_quality((SETTINGS.get_quality() + 2) % 3)   # высокое → среднее → низкое → высокое
		upd.call()
		SETTINGS.apply(null, _grain_mat, SETTINGS.get_quality()))
	var vb := _button("", func(): pass)
	var vupd := func(): vb.text = tr("MENU_VOL") + "%d%%" % roundi(SETTINGS.get_volume() * 100.0)
	vupd.call()
	vb.pressed.connect(func():
		var i: int = SETTINGS.VOLUMES.find(snappedf(SETTINGS.get_volume(), 0.01))
		SETTINGS.set_val("audio", "volume", SETTINGS.VOLUMES[(i + 1) % SETTINGS.VOLUMES.size()])
		SETTINGS.apply_general()
		vupd.call())
	var sb := _button("", func(): pass)
	var supd := func(): sb.text = tr("MENU_SENS") + "%d%%" % roundi(SETTINGS.get_sens() * 100.0)
	supd.call()
	sb.pressed.connect(func():
		var i: int = SETTINGS.SENS.find(snappedf(SETTINGS.get_sens(), 0.01))
		SETTINGS.set_val("input", "sens", SETTINGS.SENS[(i + 1) % SETTINGS.SENS.size()])
		supd.call())
	var fb := _button("", func(): pass)
	var fupd := func(): fb.text = tr("MENU_FS") + tr("MENU_ON" if SETTINGS.get_fullscreen() else "MENU_OFF")
	fupd.call()
	fb.pressed.connect(func():
		SETTINGS.set_val("video", "fullscreen", not SETTINGS.get_fullscreen())
		SETTINGS.apply_general()
		fupd.call())
	# язык: English ⇄ Русский (меню перезагружается, чтобы обновить все надписи)
	_button("MENU_LANG", func():
		var i := SETTINGS.LANGS.find(SETTINGS.get_lang())
		SETTINGS.set_lang(SETTINGS.LANGS[(i + 1) % SETTINGS.LANGS.size()])
		Engine.set_meta("menu_page", "settings")
		get_tree().reload_current_scene())
	_button("MENU_BACK", _page_main)


func _label(t: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = tr(t)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = tr(t)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(320, 48)
	b.add_theme_font_size_override("font_size", 26)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.content_margin_left = 6
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.45, 0.04, 0.02, 0.55)
	hover.content_margin_left = 16
	for st in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, normal)
	for st in ["hover", "pressed"]:
		b.add_theme_stylebox_override(st, hover)
	b.add_theme_color_override("font_color", Color(0.78, 0.75, 0.68))
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.9))
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_color_override("font_disabled_color", Color(0.38, 0.36, 0.33))
	b.mouse_entered.connect(func(): _click(-14.0))
	b.pressed.connect(func(): _click(-6.0); cb.call())
	_buttons.add_child(b)
	return b


func _click(db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://audio/click.wav")
	p.volume_db = db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _start() -> void:
	if _loading_started:
		return
	_loading_started = true
	_buttons.get_parent().visible = false
	_loading.visible = true
	ResourceLoader.load_threaded_request(GAME_SCENE)


func _process(delta: float) -> void:
	_flicker(delta)
	if not _loading_started:
		return
	_t_load += delta
	var prog := []
	var st := ResourceLoader.load_threaded_get_status(GAME_SCENE, prog)
	if prog.size() > 0:
		_bar.value = lerp(_bar.value, float(prog[0]) * 100.0, 0.2)
	if st == ResourceLoader.THREAD_LOAD_LOADED and _t_load > 1.2:
		var scene: PackedScene = ResourceLoader.load_threaded_get(GAME_SCENE)
		_loading_started = false
		get_tree().change_scene_to_packed(scene)
	elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_hint.text = tr("MENU_12")
		_loading_started = false
