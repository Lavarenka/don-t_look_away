extends RefCounted
## Настройки графики: 0 — низкое, 1 — среднее, 2 — высокое, 3 — ультра, 4 — ультра+ (для мощных ПК).
## Сохраняются в user://settings.cfg (папка сохранений игры).

const NAMES := ["SET_01", "SET_02", "SET_03", "SET_04", "SET_05"]
const PATH := "user://settings.cfg"


static func get_quality() -> int:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		return clampi(int(cf.get_value("graphics", "quality", 2)), 0, 4)
	return 2


static func set_quality(q: int) -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("graphics", "quality", q)
	cf.save(PATH)


## Эффекты на общем выходе звука. Раньше уровень при каждой загрузке (меню → игра → меню → игра,
## перезапуск главы) добавлял ещё одну реверберацию — они копились и звук превращался в хрип
## до перезапуска игры. Теперь: ровно одна реверберация (если нужна) и лимитер последним.
static func master_fx(reverb: bool) -> void:
	for i in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
		var e := AudioServer.get_bus_effect(0, i)
		if e is AudioEffectReverb or e is AudioEffectHardLimiter:
			AudioServer.remove_bus_effect(0, i)
	if reverb:
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.7
		rev.wet = 0.25
		AudioServer.add_bus_effect(0, rev)
	var lim := AudioEffectHardLimiter.new()          # громкие наложения не клиппуют
	lim.ceiling_db = -0.5
	lim.pre_gain_db = 0.0
	AudioServer.add_bus_effect(0, lim)


static var _lut: ImageTexture3D

## Таблица цвета 32³ (LUT) — считается один раз. Вход: цвет после тонмаппинга, выход — «киношный».
static func film_lut() -> ImageTexture3D:
	if _lut:
		return _lut
	const N := 32
	var slices: Array[Image] = []
	for bi in N:
		var img := Image.create(N, N, false, Image.FORMAT_RGB8)
		for gi in N:
			for ri in N:
				img.set_pixel(ri, gi, film_grade(Color(ri / (N - 1.0), gi / (N - 1.0), bi / (N - 1.0))))
		slices.append(img)
	_lut = ImageTexture3D.new()
	_lut.create(Image.FORMAT_RGB8, N, N, N, false, slices)
	return _lut


static func film_grade(c: Color) -> Color:
	var v := Vector3(c.r, c.g, c.b)
	# мягкая S-кривая (контраст в средних тонах, не давит чёрное и белое)
	var s := v * v * (Vector3(3, 3, 3) - 2.0 * v)
	v = v.lerp(s, 0.2)
	var l := v.dot(Vector3(0.2126, 0.7152, 0.0722))
	# чуть приглушить цвет
	v = Vector3(l, l, l).lerp(v, 0.88)
	# раздельное тонирование: тени — в холодный сине-зелёный, света — в тёплый янтарь
	var sh := pow(1.0 - l, 2.0) * 0.32
	var hi := pow(l, 2.0) * 0.22
	v = v * (Vector3.ONE.lerp(Vector3(0.9, 1.0, 1.1), sh)) * (Vector3.ONE.lerp(Vector3(1.08, 1.0, 0.86), hi))
	# чёрное чуть приподнято — «плёнка», а не провал
	v = v * 0.985 + Vector3(0.012, 0.014, 0.018)
	return Color(clampf(v.x, 0, 1), clampf(v.y, 0, 1), clampf(v.z, 0, 1))


## Применить к окружению уровня и к шейдеру «камеры».
static func apply(env: Environment, post: ShaderMaterial, q: int) -> void:
	if env:
		# мягкий отражённый свет (только «высокое»)
		env.sdfgi_enabled = q >= 2
		env.sdfgi_use_occlusion = true
		env.sdfgi_cascades = 4 if q >= 3 else 2
		env.sdfgi_min_cell_size = 0.1
		env.sdfgi_energy = 0.9
		# отражённый свет от стен и пола (SSIL) — с «среднего»; на «высоком» ещё и SDFGI
		env.ssil_enabled = q >= 1
		env.ssil_intensity = 1.5
		env.ssil_radius = 3.0
		env.ssil_sharpness = 0.98
		env.ssil_normal_rejection = 1.0
		# единый «киношный» цвет на всю игру (LUT): холодные тени, тёплые света, мягкая S-кривая
		env.adjustment_enabled = true
		env.adjustment_color_correction = film_lut()
		env.ssao_enabled = q >= 1
		env.volumetric_fog_enabled = q >= 1
		env.glow_enabled = true
		env.glow_intensity = 0.9 if q >= 1 else 0.6
		env.glow_bloom = 0.08
		env.glow_hdr_threshold = 0.9
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		# отражения в реальном времени (SSR): в лаковом полу, в чёрной воде, в стекле и фарфоре отражаются
		# свеча и луч фонаря — только то, что освещено, поэтому темнота остаётся темнотой
		env.ssr_enabled = q >= 2
		env.ssr_max_steps = 128 if q >= 4 else 64
		env.ssr_fade_in = 0.15
		env.ssr_fade_out = 2.0
		env.ssr_depth_tolerance = 0.25
		if q >= 4:
			env.sdfgi_cascades = 6
	if post:
		post.set_shader_parameter("fx", 1.0 if q >= 1 else 0.6)
	var vp := Engine.get_main_loop() as SceneTree
	if vp:
		var ultra := q >= 3
		vp.root.positional_shadow_atlas_size = 8192 if ultra else (4096 if q >= 1 else 2048)
		vp.root.msaa_3d = Viewport.MSAA_4X if ultra else (Viewport.MSAA_2X if q >= 1 else Viewport.MSAA_DISABLED)
		# ультра: временное сглаживание (TAA) вместо FXAA — без «лесенок» и мерцания мелких деталей
		vp.root.use_taa = ultra
		vp.root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q == 2 else Viewport.SCREEN_SPACE_AA_DISABLED
		vp.root.anisotropic_filtering_level = Viewport.ANISOTROPY_16X if ultra else Viewport.ANISOTROPY_4X
		vp.root.mesh_lod_threshold = 0.0 if ultra else 1.0          # ультра: модели всегда в полной детализации
		# ультра+: кадр считается в 1.3 раза крупнее и сжимается (суперсэмплинг), сглаживание 8×
		vp.root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.root.scaling_3d_scale = 1.3 if q >= 4 else 1.0
		if q >= 4:
			vp.root.msaa_3d = Viewport.MSAA_8X
		vp.root.use_debanding = q >= 3                               # без «ступенек» в тёмных градиентах
	# тени, затенение углов и объёмный туман — качество задаётся на весь рендер
	var hi := q >= 3
	RenderingServer.directional_shadow_atlas_set_size(8192 if hi else 4096, true)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH if hi else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH if hi else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_ULTRA if hi else RenderingServer.ENV_SSAO_QUALITY_MEDIUM, not hi, 0.5, 3 if hi else 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_HIGH if hi else RenderingServer.ENV_SSIL_QUALITY_MEDIUM, not hi, 0.5, 4, 50.0, 300.0)
	RenderingServer.environment_set_volumetric_fog_volume_size(192 if q >= 4 else (128 if hi else 64), 192 if q >= 4 else (128 if hi else 64))
	RenderingServer.environment_set_volumetric_fog_filter_active(q >= 3)       # столб света мягкий, без «зерна»
	RenderingServer.environment_set_ssr_roughness_quality(RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_HIGH if q >= 4 else RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_MEDIUM)
	if q >= 4:
		RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
		RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_64)


# ---------------- язык ----------------
const LANGS := ["en", "ru"]           ## английский — основной (игра для американского рынка)


static func get_lang() -> String:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		var l := str(cf.get_value("general", "lang", "en"))
		if l in LANGS:
			return l
	return "en"


static func set_lang(l: String) -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("general", "lang", l)
	cf.save(PATH)
	TranslationServer.set_locale(l)


static func apply_lang() -> void:
	TranslationServer.set_locale(get_lang())


## Озвучка: если есть файл res://voice/<язык>/<ключ>.ogg (или .wav), вернуть его.
## Ключ — тот же, что у субтитра в lang/strings.csv.
## Озвучка реплики: сначала на языке игры, иначе — английская (озвучка пока только английская,
## русские игроки слышат её с русскими субтитрами). VOICE_FALLBACK_EN = false — без подмены.
const VOICE_FALLBACK_EN := true


static func voice(key: String) -> AudioStream:
	var l := TranslationServer.get_locale().substr(0, 2)
	var langs := [l]
	if VOICE_FALLBACK_EN and l != "en":
		langs.append("en")
	for lang in langs:
		for ext in ["ogg", "wav", "mp3"]:
			var p := "res://voice/%s/%s.%s" % [lang, key, ext]
			if ResourceLoader.exists(p):
				return load(p)
	return null


# ---------------- звук, мышь, экран ----------------
const VOLUMES := [1.0, 0.8, 0.6, 0.4, 0.2, 0.0]
const SENS := [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]


static func get_val(sec: String, key: String, def):
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		return cf.get_value(sec, key, def)
	return def


static func set_val(sec: String, key: String, v) -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value(sec, key, v)
	cf.save(PATH)


static func get_volume() -> float:
	return float(get_val("audio", "volume", 1.0))


static func get_sens() -> float:
	return float(get_val("input", "sens", 1.0))


## По умолчанию — полный экран (в редакторе Godot — окно, чтобы было удобно тестировать).
static func get_fullscreen() -> bool:
	return bool(get_val("video", "fullscreen", not OS.has_feature("editor")))


## Размер окна (в полноэкранном режиме — всегда разрешение монитора).
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]


static func get_resolution() -> int:
	return clampi(int(get_val("video", "res", 2)), 0, RESOLUTIONS.size() - 1)


## Масштаб 3D-картинки: меньше 100% — рендер в меньшем разрешении с чётким растягиванием AMD FSR
## (больше FPS на слабых видеокартах); больше 100% — суперсэмплинг: рендер крупнее экрана и сжатие,
## гладкие края и мелкие детали без ряби (для мощных видеокарт). Интерфейс всегда в полном разрешении.
const RENDER_SCALES := [1.0, 1.25, 1.5, 0.85, 0.75, 0.6]


static func get_render_scale() -> float:
	return float(get_val("video", "scale", 1.0))


## Счётчик FPS в углу экрана (F3 или галочка в настройках).
static func get_show_fps() -> bool:
	return bool(get_val("video", "fps", false))


## Громкость и экран — применяются сразу ко всей игре.
static func apply_general() -> void:
	var tr0 := Engine.get_main_loop() as SceneTree
	if tr0:
		var fc := tr0.root.get_node_or_null("FpsCounter")
		if fc == null:
			fc = preload("res://scripts/fps_counter.gd").new()
			fc.name = "FpsCounter"
			tr0.root.add_child.call_deferred(fc)
		else:
			fc.visible = get_show_fps()
	var v := get_volume()
	AudioServer.set_bus_mute(0, v <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(max(v, 0.001)))
	if DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if get_fullscreen() else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
	if want == DisplayServer.WINDOW_MODE_WINDOWED:
		# окно выбранного размера (но не больше экрана), по центру
		var scr := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var sz: Vector2i = RESOLUTIONS[get_resolution()]
		sz = Vector2i(mini(sz.x, scr.size.x), mini(sz.y, scr.size.y))
		if DisplayServer.window_get_size() != sz:
			DisplayServer.window_set_size(sz)
			DisplayServer.window_set_position(scr.position + (scr.size - sz) / 2)
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		var sc := get_render_scale()
		tree.root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if sc < 0.999 else Viewport.SCALING_3D_MODE_BILINEAR
		tree.root.scaling_3d_scale = clampf(sc, 0.25, 2.0)
		tree.root.fsr_sharpness = 0.3


# ---------------- главы ----------------
const UNLOCK_ALL := true          ## тестовая версия: все главы открыты сразу. Для релиза — false.


static func reached() -> int:
	return int(get_val("progress", "chapter", 1))


static func reach(n: int) -> void:
	if n > reached():
		set_val("progress", "chapter", n)
