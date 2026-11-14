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
var _gap: Control
const MENU_GAP := 150.0
const SHADOW_K := 0.6                 ## насколько темна тень Ани на фоне
var _shadow_rect: TextureRect
const FONT_TEXT := preload("res://fonts/Lora-Italic-Variable.ttf")
var _btn_font: FontVariation
var _haze_mat: ShaderMaterial
var _loading: VBoxContainer
## Экран загрузки: 0 — как был (полоска и совет), 1 — «фитиль», 2 — «кассета», 3 — «записка» (scripts/load_screen.gd)
const LOAD_STYLE := 1
var _ls = null
var _bar: ProgressBar
var _hint: Label
var _loading_started := false
var _t_load := 0.0
var _drone: AudioStreamPlayer


const SETTINGS = preload("res://scripts/settings.gd")
## Вид главного меню: 0 — как было (название слева сверху), 1 — «по центру», 2 — «кровь»,
## 3 — «старая фотография». Только оформление, кнопки и логика одинаковые.
const STYLE := 0
var _style := STYLE
const FLICKER = preload("res://scripts/flicker.gd")
var _grain_mat: ShaderMaterial

# ---- живой фон: заранее отрендеренный коридор + поверх него 3D-призрак в том же ракурсе ----
var CAM_XF: Transform3D = str_to_var("Transform3D(0.99782705, -0.0063137123, 0.06558462, 0, 0.9953982, 0.095825166, -0.06588782, -0.09561695, 0.99323523, -0.3, 1.65, 2.5)")
var FLASH_XF: Transform3D = str_to_var("Transform3D(0.9942423, 0.013865624, -0.10625452, 0, 0.9915928, 0.12939733, 0.10715539, -0.1286523, 0.98588353, -0.07921533, 1.4509205, 2.5046284)")
var GIRL_XF: Transform3D = str_to_var("Transform3D(0.98412704, 0, -0.17746553, 0, 1, 0, 0.17746553, 0, 0.98412704, 0.25, 0, -0.55)")
const FLASH_E := 7.0
## Фон меню (textures/menu/*.png, рендер из уровня — tools/render_menu_plate.gd):
## 0 — старый (до новых обоев), 1 — новая прихожая, свет как был, 2 — фонарь садится (темнее),
## 3 — фонаря нет, только луна из зала (Аня — силуэт), 4 — фонаря нет, в прихожей тлеет торшер.
const PLATE := 4
var _pl := PLATE
## img — картинка; flash — фонарь (0 — нет); ang — ширина луча; shade — затемнение поверх;
## rim — контровой свет на Аню из зала; lamp — тёплый свет торшера на неё; amb — общий свет на неё;
## dim — во сколько раз «сбои» слабее/медленнее (луна — облака, а не моргание)
const PLATES := [
	{"img": "res://textures/menu_plate.png", "flash": 7.0, "ang": 24.0, "shade": 0.45, "rim": 0.9, "lamp": 0.0, "amb": 0.1, "dim": 1.0},
	{"img": "res://textures/menu/plate_1.png", "flash": 7.0, "ang": 24.0, "shade": 0.4, "rim": 0.9, "lamp": 0.0, "amb": 0.08, "dim": 1.0},
	{"img": "res://textures/menu/plate_2.png", "flash": 4.8, "ang": 21.0, "shade": 0.35, "rim": 0.7, "lamp": 0.0, "amb": 0.05, "dim": 1.0},
	{"img": "res://textures/menu/plate_3.png", "flash": 0.0, "ang": 24.0, "shade": 0.2, "rim": 2.8, "lamp": 0.0, "amb": 0.03, "dim": 0.35},
	{"img": "res://textures/menu/plate_4.png", "flash": 0.0, "ang": 24.0, "shade": 0.25, "rim": 0.6, "lamp": 1.6, "amb": 0.04, "dim": 1.0},
]
var _cfg: Dictionary
var _lamp: OmniLight3D
var _rim: OmniLight3D
const GHOST_TINT := Color(0.74, 0.74, 0.8)     ## призрак темнее, будто в тени
## Позы: [позиция, поворот, анимация ("" — живая idle), секунда анимации, повороты костей, прячется за стеной]
var POSES: Array = [
	# стоит в глубине проёма (за порогом, косяки её частично закрывают)
	[Vector3(0.12, 0, -1.4), -0.12, "", 0.0, {}, true],
	# выглядывает из-за правого косяка и держится за него рукой
	[Vector3(0.95, 0, -0.9), -0.35, "idle", 1.0, {"Spine": Vector3(0, 0, 0.18), "Spine1": Vector3(0, 0, 0.14), "Spine2": Vector3(0, 0, 0.1),
		"Neck": Vector3(0, 0, 0.14), "Head": Vector3(0, 0, 0.3), "RightArm": Vector3(0.6, 0, -0.5), "RightForeArm": Vector3(0, 0, 1.5)}, true],
	# из-за правого косяка — только голова
	[Vector3(0.95, 0, -0.9), -0.35, "idle", 1.0, {"Spine": Vector3(0, 0, 0.18), "Spine1": Vector3(0, 0, 0.14), "Spine2": Vector3(0, 0, 0.1),
		"Neck": Vector3(0, 0, 0.14), "Head": Vector3(0, 0, 0.35)}, true],
	# из-за левого косяка, рука на косяке
	[Vector3(-0.8, 0, -0.9), 0.1, "idle", 1.0, {"Spine": Vector3(0, 0, -0.2), "Spine1": Vector3(0, 0, -0.15), "Spine2": Vector3(0, 0, -0.12),
		"Neck": Vector3(0, 0, -0.15), "Head": Vector3(0, 0, -0.3), "LeftArm": Vector3(0.6, 0, 0.5), "LeftForeArm": Vector3(0, 0, -1.5)}, true],
]
var _pose: SkeletonModifier3D
var _pose_i := 0
var _reach := {}                   ## Аня v3: ИК рук (spirit3_reach.gd), "L" и "R"
## Куда она кладёт ладонь на косяк (мир меню): правый и левый края проёма
const JAMB_R := Vector3(0.44, 1.25, -0.93)
const JAMB_L := Vector3(-0.26, 1.25, -0.93)
var _mask_mat: ShaderMaterial
## Слой призрака виден только внутри проёма двери (там, где за ним нет стены) — когда она за стеной.
## Проём в пикселях фона 1920×1080: верх-лево, верх-право, низ-право, низ-лево.
const MASK_SHADER := """
shader_type canvas_item;
uniform float masked = 0.0;
const vec2 A = vec2(970.0, 392.0);
const vec2 B = vec2(1257.0, 390.0);
const vec2 C = vec2(1240.0, 1080.0);
const vec2 D = vec2(968.0, 1080.0);
float side(vec2 p, vec2 a, vec2 b) { return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x); }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 p = UV * vec2(1920.0, 1080.0);
	bool inside = side(p, A, B) >= 0.0 && side(p, B, C) >= 0.0 && side(p, C, D) >= 0.0 && side(p, D, A) >= 0.0;
	if (masked > 0.5 && !inside) c.a = 0.0;
	COLOR = c;
}
"""
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
	SETTINGS.master_fx(false)                    # из игры вернулись в меню — реверберацию уровня убрать
	SETTINGS.apply_lang()
	preload("res://scripts/fonts.gd").apply_default()
	SETTINGS.apply_general()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# фон: перерисованный из уровня (tools/render_menu_plate.gd) — вариант PLATE
	if OS.has_environment("MENU_PLATE"):          # для снимков вариантов
		_pl = int(OS.get_environment("MENU_PLATE"))
	_cfg = PLATES[clampi(_pl, 0, PLATES.size() - 1)]
	var plate_path: String = _cfg.img
	if not ResourceLoader.exists(plate_path):
		plate_path = "res://textures/menu_plate.png" if ResourceLoader.exists("res://textures/menu_plate.png") else "res://textures/menu_plate.jpg"
	_plate = _cover(load(plate_path))
	add_child(_plate)
	_build_live()
	# дымка в луче фонаря: медленно плывёт, дышит вместе с фонарём
	var haze := ColorRect.new()
	haze.set_anchors_preset(Control.PRESET_FULL_RECT)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haze_mat = ShaderMaterial.new()
	_haze_mat.shader = load("res://shaders/menu_haze.gdshader")
	haze.material = _haze_mat
	haze.visible = _cfg.flash > 0.0             # дымка — в луче фонаря; без фонаря её нет
	add_child(haze)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, _cfg.shade)
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
	box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	box.position = Vector2(90, 40)
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	var title := _label("MENU_05", 50, Color(0.9, 0.86, 0.78))
	FLICKER.style(title)
	box.add_child(title)
	var sub := _label("MENU_06", 19, Color(0.55, 0.52, 0.47))
	sub.add_theme_font_override("font", FONT_TEXT)
	box.add_child(sub)
	_gap = Control.new()                # отступ: меню — в нижней части экрана, заголовок — наверху
	box.add_child(_gap)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	box.add_child(_buttons)
	_page_main()
	var keys := _label("MENU_10", 16, Color(0.5, 0.48, 0.44))
	keys.add_theme_font_override("font", FONT_TEXT)
	box.add_child(keys)
	if OS.has_environment("MENU_STYLE"):          # для снимков вариантов
		_style = int(OS.get_environment("MENU_STYLE"))
	_apply_style(box, title, sub, keys, shade, gm)

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
	var lst := int(OS.get_environment("MENU_LOAD")) if OS.has_environment("MENU_LOAD") else LOAD_STYLE   # для снимков
	if lst > 0:
		_ls = preload("res://scripts/load_screen.gd").new()
		_ls.visible = false
		add_child(_ls)
		_ls.build(lst, HINTS[randi() % HINTS.size()])
	if OS.has_environment("MENU_LOAD_PREVIEW"):     # снимок экрана загрузки без самой загрузки
		_buttons.get_parent().visible = false
		_bar.value = float(OS.get_environment("MENU_LOAD_PREVIEW"))
		if _ls:
			_ls.value = _bar.value
			_ls.show_screen()
		else:
			_loading.visible = true

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


## Оформление меню (см. STYLE).
func _apply_style(box: VBoxContainer, title: Label, sub: Label, keys: Label, shade: ColorRect, gm: ShaderMaterial) -> void:
	if _style == 0:
		return
	var over := ColorRect.new()                   # цветовой тон поверх фона (под надписями)
	over.set_anchors_preset(Control.PRESET_FULL_RECT)
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(over)
	move_child(over, shade.get_index() + 1)
	match _style:
		1:  # по центру: название крупно посередине сверху с тонкой красной чертой, кнопки — слева внизу
			over.color = Color(0, 0, 0, 0.18)
			var vw := get_viewport_rect().size.x
			var head := VBoxContainer.new()
			head.custom_minimum_size = Vector2(900, 0)
			head.position = Vector2((vw - 900.0) * 0.5, 50)
			head.add_theme_constant_override("separation", 10)
			add_child(head)
			for l in [title, sub]:
				l.reparent(head, false)
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			title.add_theme_font_size_override("font_size", 66)
			FLICKER.apply_font(title)
			sub.text = tr("MENU_06").to_upper()
			var line := ColorRect.new()
			line.color = Color(0.55, 0.05, 0.03, 0.8)
			line.custom_minimum_size = Vector2(0, 2)
			head.add_child(line)
			head.move_child(line, 1)
			box.position = Vector2(90, 140)
		2:  # кровь: название шрифтом с потёками, тёмно-красное, багровый тон
			over.color = Color(0.25, 0.0, 0.0, 0.28)
			var f := FontVariation.new()
			f.base_font = load("res://fonts/RubikWetPaint-Regular.ttf")
			f.spacing_glyph = 4
			title.add_theme_font_override("font", f)
			title.add_theme_font_size_override("font_size", 72)
			title.add_theme_color_override("font_color", Color(0.55, 0.03, 0.02))
			title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
			sub.add_theme_color_override("font_color", Color(0.6, 0.15, 0.12))
			box.position = Vector2(90, 30)
			for b in _buttons.get_children():
				(b as Button).add_theme_color_override("font_color", Color(0.75, 0.62, 0.58))
		3:  # старая фотография: сепия, рамка-кайма, название внизу слева, кнопки над ним
			over.color = Color(0.32, 0.22, 0.1, 0.32)
			shade.color = Color(0, 0, 0, 0.35)
			var vs := get_viewport_rect().size
			title.add_theme_font_size_override("font_size", 40)
			FLICKER.apply_font(title)
			title.add_theme_color_override("font_color", Color(0.86, 0.8, 0.66))
			# порядок: кнопки, подсказка, потом название внизу — как подпись под фото
			box.move_child(title, box.get_child_count() - 1)
			box.move_child(sub, box.get_child_count() - 1)
			box.move_child(_gap, 0)
			_gap.custom_minimum_size.y = 0
			box.position = Vector2(80, vs.y - 400.0)
			for b in _buttons.get_children():
				(b as Button).add_theme_font_size_override("font_size", 26)
			var fr := ReferenceRect.new()
			fr.set_anchors_preset(Control.PRESET_FULL_RECT)
			fr.offset_left = 24; fr.offset_top = 24; fr.offset_right = -24; fr.offset_bottom = -24
			fr.border_color = Color(0.75, 0.68, 0.55, 0.35)
			fr.border_width = 2.0
			fr.editor_only = false
			fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(fr)


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
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.5)
	env.ambient_light_energy = _cfg.amb
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
	_flash.spot_angle = _cfg.ang
	_flash.spot_angle_attenuation = 1.5
	vp.add_child(_flash)
	_lamp = OmniLight3D.new()                   # торшер в прихожей (вариант 4): тёплый свет сбоку-спереди
	_lamp.light_color = Color(1.0, 0.55, 0.3)
	_lamp.light_energy = _cfg.lamp
	_lamp.omni_range = 4.5
	_lamp.omni_attenuation = 1.6
	_lamp.position = Vector3(-0.75, 1.38, 0.75)
	_lamp.visible = _cfg.lamp > 0.0
	vp.add_child(_lamp)
	_shadow_catcher(vp)
	var rim := OmniLight3D.new()                # холодный контровой свет из комнаты за ней — силуэт отделяется от темноты
	rim.light_color = Color(0.55, 0.65, 0.9)
	rim.light_energy = _cfg.rim
	rim.omni_range = 2.6 if _cfg.rim < 1.5 else 3.2
	_rim = rim
	rim.position = Vector3(0.1, 1.5, -2.6)
	vp.add_child(rim)
	_girl = Node3D.new()
	_girl.set_script(load("res://scripts/spirit.gd"))
	_girl.transform = GIRL_XF
	vp.add_child(_girl)
	_girl.play("idle", 0.4)
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
	add_child(_shadow_rect)
	_live = _cover(vp.get_texture())
	var sh := Shader.new()
	sh.code = MASK_SHADER
	_mask_mat = ShaderMaterial.new()
	_mask_mat.shader = sh
	_live.material = _mask_mat
	add_child(_live)
	# поза поверх анимации (выглядывает из-за косяка) и темнее, «в тени»
	_pose = preload("res://scripts/menu_pose.gd").new()
	_pose.v3 = _girl.v3
	_girl.sk.add_child(_pose)
	if _girl.v3:                                 # у Ани v3 руку на косяк кладёт ИК; поза и рука — до мимики и физики волос
		_girl.sk.move_child(_pose, _girl.face.get_index())
		for sd in ["L", "R"]:
			var r: SkeletonModifier3D = preload("res://scripts/spirit3_reach.gd").new()
			r.side = sd
			_girl.sk.add_child(r)
			_girl.sk.move_child(r, _girl.face.get_index())
			_reach[sd] = r
	_girl._p("tint", GHOST_TINT)
	_girl.set_blood(0.25)
	_shadow_twin()
	_set_pose(0, true)


## Тень от Ани на фоне. В её же 3D-мире стоят невидимые пол и стены (слой CATCH_LAYER) и свой
## «теневой» свет, который освещает только их, а тень отбрасывает только Аня. Отдельная камера снимает
## эти поверхности: всё белое, кроме её тени, — и этот снимок умножается на фон (плату).
const CATCH_LAYER := 1 << 15
const SHADOW_TWIN := 1 << 16          ## невидимый двойник Ани (тот же меш на том же скелете) — только отбрасывает тень


## Двойник для тени: свет «ловцов» не должен освещать саму Аню, поэтому тень даёт копия её меша,
## привязанная к тому же скелету (двигается точно так же), видимая только как тень.
func _shadow_twin() -> void:
	for mi in _girl.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.skin == null:
			continue
		var tw := MeshInstance3D.new()
		tw.mesh = m.mesh
		tw.skin = m.skin
		m.get_parent().add_child(tw)
		tw.transform = m.transform
		tw.skeleton = tw.get_path_to(m.get_node(m.skeleton))
		tw.layers = SHADOW_TWIN
		tw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
func _shadow_catcher(vp: SubViewport) -> void:
	var white := ShaderMaterial.new()            # белый, свет без учёта наклона: темнеет только в тени
	var wsh := Shader.new()
	wsh.code = "shader_type spatial;\nrender_mode specular_disabled, cull_disabled;\nvoid fragment() { ALBEDO = vec3(1.0); }\nvoid light() { DIFFUSE_LIGHT += vec3(ATTENUATION); }\n"
	white.shader = wsh
	for b in [[Vector3(14, 0.02, 16), Vector3(0, -0.01, -3.5)],                     # пол коридора и комнаты за дверью
			[Vector3(4.0, 3.0, 0.06), Vector3(-2.3, 1.5, -0.95)],                  # стена слева от проёма
			[Vector3(4.0, 3.0, 0.06), Vector3(2.48, 1.5, -0.95)],                  # стена справа
			[Vector3(0.8, 0.8, 0.06), Vector3(0.09, 2.5, -0.95)],                  # над проёмом
			[Vector3(8.0, 3.0, 0.06), Vector3(0, 1.5, -5.6)]]:                     # дальняя стена комнаты
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b[0]
		mi.mesh = bm
		mi.position = b[1]
		mi.material_override = white
		mi.layers = CATCH_LAYER
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		vp.add_child(mi)
	var sl := DirectionalLight3D.new()           # параллельный свет со стороны фонаря, чуть сверху-справа
	sl.transform = FLASH_XF
	sl.rotate_object_local(Vector3.UP, 0.12)
	sl.rotate_object_local(Vector3.RIGHT, -0.1)
	sl.light_energy = 4.0
	sl.shadow_enabled = true
	sl.shadow_blur = 2.0
	sl.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sl.directional_shadow_max_distance = 12.0
	sl.light_cull_mask = CATCH_LAYER | SHADOW_TWIN    # освещает только «ловцов»; тень — от двойника Ани
	sl.shadow_caster_mask = SHADOW_TWIN
	sl.layers = CATCH_LAYER                         # камера тени видит этот свет, главная — нет
	vp.add_child(sl)
	_flash.light_cull_mask = ~(CATCH_LAYER | SHADOW_TWIN)
	for c in vp.get_children():
		if c is Camera3D:
			(c as Camera3D).cull_mask &= ~(CATCH_LAYER | SHADOW_TWIN)      # сами «ловцы» в кадре не видны
	var vp2 := SubViewport.new()
	vp2.size = Vector2i(960, 540)
	vp2.world_3d = vp.find_world_3d()           # у vp свой мир (own_world_3d) — берём именно его
	vp2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp2)
	var c2 := Camera3D.new()
	c2.fov = 68.0
	c2.transform = CAM_XF
	c2.cull_mask = CATCH_LAYER | SHADOW_TWIN       # двойник только отбрасывает тень (сам не рисуется)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	c2.environment = env
	vp2.add_child(c2)
	c2.current = true
	var r := _cover(vp2.get_texture())
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
render_mode blend_mul;
uniform float k = 0.6;
void fragment() {
	float l = 0.0;                               // мягкий край тени: размытие 5×5
	for (int x = -2; x <= 2; x++)
		for (int y = -2; y <= 2; y++)
			l += texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE * 1.6).r;
	l = clamp(l / 25.0, 0.0, 1.0);
	COLOR = vec4(vec3(mix(1.0, l, k)), 1.0);
}
"""
	sm.shader = sh
	sm.set_shader_parameter("k", SHADOW_K)
	r.material = sm
	_shadow_rect = r


## Фонарик: почти всегда ровный, иногда коротко «моргает»,
## изредка гаснет — и в темноте призрак меняет позу или исчезает.
func _flicker(delta: float) -> void:
	_fl_t += delta
	var target := 1.0 - 0.04 * sin(_fl_t * 1.7) * sin(_fl_t * 4.3)
	var dim: float = _cfg.dim
	if dim < 1.0:
		# луна: не моргает, а медленно меркнет — по ней идут облака; в темноте Аня «меняется»
		var was := _burst > 0.0
		_burst -= delta
		if was and _burst <= 0.0 and _deep:
			_ghost_shift()
		if _burst <= 0.0 and _fl_t > _next_fl:
			_burst = randf_range(1.8, 2.8)
			_deep = randf() < 0.45
			_next_fl = _fl_t + randf_range(7.0, 12.0)
		var goal := (0.12 if _deep else 0.55) if _burst > 0.0 else target
		_fl = move_toward(_fl, goal, delta * 0.9)
		_apply_fl()
		return
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
	_apply_fl()


func _apply_fl() -> void:
	var fe: float = _cfg.flash
	_flash.light_energy = fe * _fl
	_lamp.light_energy = float(_cfg.lamp) * _fl
	_rim.light_energy = float(_cfg.rim) * (_fl if fe == 0.0 and _cfg.lamp == 0.0 else 1.0)
	var c := Color(_fl, _fl, _fl)
	_plate.modulate = c
	_haze_mat.set_shader_parameter("power", _fl)
	# тень Ани на стене — от фонаря; без фонаря её нет
	(_shadow_rect.material as ShaderMaterial).set_shader_parameter("k", SHADOW_K * _fl if fe > 0.0 else 0.0)


## Пока фонарик моргает, она успевает «перемениться»: то стоит в проёме,
## то выглядывает из-за косяка (держится за него рукой), то её нет.
func _ghost_shift() -> void:
	if _girl.visible and randf() < 0.2:
		_girl.visible = false
		return
	_girl.visible = true
	var i := _pose_i
	while i == _pose_i:
		i = randi() % POSES.size()
	_set_pose(i, true)


func _set_pose(i: int, instant := false) -> void:
	_pose_i = i
	var p: Array = POSES[i]
	_girl.transform = Transform3D(Basis(Vector3.UP, p[1]), p[0])
	if p[2] == "":
		_girl.play("idle", 0.4, 0.0)
		_girl.ap.seek(randf() * 3.0, true)
	else:
		_girl.freeze(p[2], p[3])
	_pose.target = p[4]
	if _girl.v3:
		_reach["R"].target = JAMB_R
		_reach["R"].weight = 1.0 if (p[4] as Dictionary).has("RightArm") else 0.0
		_reach["L"].target = JAMB_L
		_reach["L"].weight = 1.0 if (p[4] as Dictionary).has("LeftArm") else 0.0
		_girl.face.claw = 0.45 if ((p[4] as Dictionary).has("LeftArm") or (p[4] as Dictionary).has("RightArm")) else 0.0   # пальцы держатся за косяк
		_girl.hair_sim.reset()
	if instant:
		_pose.snap()
	_mask_mat.set_shader_parameter("masked", 1.0 if p[5] else 0.0)


func _clear() -> void:
	var box := _buttons.get_parent() as Control
	box.position.y = 40.0
	_gap.custom_minimum_size.y = MENU_GAP
	_fit_box.call_deferred()
	for c in _buttons.get_children():
		_buttons.remove_child(c)
		c.queue_free()


## Длинная страница (настройки) не должна вылезать за экран — сдвигаем блок меню.
func _fit_box() -> void:
	await get_tree().process_frame
	var box := _buttons.get_parent() as Control
	box.reset_size()                     # контейнер сам не уменьшается после длинной страницы — иначе меню «уезжало» вверх
	await get_tree().process_frame
	var vh := get_viewport_rect().size.y
	var r := box.get_global_rect()
	if r.end.y > vh - 40.0:                       # длинная страница — сначала убираем отступ
		_gap.custom_minimum_size.y = maxf(8.0, MENU_GAP - (r.end.y - (vh - 40.0)))
		await get_tree().process_frame
		r = box.get_global_rect()
	if r.end.y > vh - 16.0:
		box.position.y -= r.end.y - (vh - 16.0)
	r = box.get_global_rect()
	if r.position.y < 16.0:
		box.position.y += 16.0 - r.position.y


func _page_main() -> void:
	_clear()
	_button("MENU_07", func(): get_tree().change_scene_to_file("res://scenes/intro.tscn"))
	_button("MENU_CHAPTERS", _page_chapters)
	_button("MENU_SETTINGS", _page_settings)
	_button("MENU_09", func(): get_tree().quit())


## Выбор главы: сразу загружает уровень (без заставки) и переносит в начало главы.
func _page_chapters() -> void:
	_clear()
	for n in range(1, 8):
		if n == 7 and not SETTINGS.UNLOCK_ALL:
			continue                                    # глава 7 — только для теста
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
		SETTINGS.set_quality((SETTINGS.get_quality() + 4) % 5)   # ультра+ → ультра → высокое → среднее → низкое → ультра+
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
	var rb := _button("", func(): pass)
	var rupd := func():
		var r: Vector2i = SETTINGS.RESOLUTIONS[SETTINGS.get_resolution()]
		rb.text = tr("MENU_RES") + ("%d×%d" % [r.x, r.y]) + (tr("MENU_RES_FS") if SETTINGS.get_fullscreen() else "")
	rupd.call()
	rb.pressed.connect(func():
		SETTINGS.set_val("video", "res", (SETTINGS.get_resolution() + 1) % SETTINGS.RESOLUTIONS.size())
		SETTINGS.apply_general()
		rupd.call())
	fb.pressed.connect(rupd)
	var cb := _button("", func(): pass)
	var cupd := func():
		var sc: float = SETTINGS.get_render_scale()
		cb.text = tr("MENU_SCALE") + "%d%%" % roundi(sc * 100.0) + (" (FSR)" if sc < 0.999 else (" (SSAA)" if sc > 1.001 else ""))
	cupd.call()
	cb.pressed.connect(func():
		var i: int = SETTINGS.RENDER_SCALES.find(snappedf(SETTINGS.get_render_scale(), 0.01))
		SETTINGS.set_val("video", "scale", SETTINGS.RENDER_SCALES[(i + 1) % SETTINGS.RENDER_SCALES.size()])
		SETTINGS.apply_general()
		cupd.call())
	var pb := _button("", func(): pass)
	var pupd := func(): pb.text = tr("MENU_FPS") + tr("MENU_ON" if SETTINGS.get_show_fps() else "MENU_OFF")
	pupd.call()
	pb.pressed.connect(func():
		SETTINGS.set_val("video", "fps", not SETTINGS.get_show_fps())
		SETTINGS.apply_general()
		pupd.call())
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
	b.custom_minimum_size = Vector2(320, 50)
	b.add_theme_font_size_override("font_size", 31)
	if _btn_font == null:                       # шрифт как у названия и заставки, с разрядкой
		_btn_font = FontVariation.new()
		_btn_font.base_font = FLICKER.FONT
		_btn_font.spacing_glyph = 3
	b.add_theme_font_override("font", _btn_font)
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


var _load_t0 := 0


func _start() -> void:
	if _loading_started:
		return
	_loading_started = true
	_buttons.get_parent().visible = false
	if _ls:
		_ls.show_screen()
	else:
		_loading.visible = true
	ResourceLoader.load_threaded_request(GAME_SCENE)
	_load_t0 = Time.get_ticks_msec()


func _process(delta: float) -> void:
	_flicker(delta)
	if not _loading_started:
		return
	_t_load += delta
	var prog := []
	var st := ResourceLoader.load_threaded_get_status(GAME_SCENE, prog)
	if prog.size() > 0:
		_bar.value = lerp(_bar.value, float(prog[0]) * 100.0, 0.2)
		if _ls:
			_ls.value = _bar.value
	if st == ResourceLoader.THREAD_LOAD_LOADED and _t_load > 1.2:
		var scene: PackedScene = ResourceLoader.load_threaded_get(GAME_SCENE)
		Engine.set_meta("load_scene_ms", Time.get_ticks_msec() - _load_t0)
		_loading_started = false
		get_tree().change_scene_to_packed(scene)
	elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_hint.text = tr("MENU_12")
		if _ls:
			_ls.fail(tr("MENU_12"))
		_loading_started = false
