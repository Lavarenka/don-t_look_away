extends RefCounted
## Настройки графики: 0 — низкое, 1 — среднее, 2 — высокое качество.
## Сохраняются в user://settings.cfg (папка сохранений игры).

const NAMES := ["SET_01", "SET_02", "SET_03"]
const PATH := "user://settings.cfg"


static func get_quality() -> int:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		return clampi(int(cf.get_value("graphics", "quality", 2)), 0, 2)
	return 2


static func set_quality(q: int) -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("graphics", "quality", q)
	cf.save(PATH)


## Применить к окружению уровня и к шейдеру «камеры».
static func apply(env: Environment, post: ShaderMaterial, q: int) -> void:
	if env:
		# мягкий отражённый свет (только «высокое»)
		env.sdfgi_enabled = q >= 2
		env.sdfgi_use_occlusion = true
		env.sdfgi_cascades = 2
		env.sdfgi_min_cell_size = 0.1
		env.sdfgi_energy = 0.9
		env.ssil_enabled = q >= 2
		env.ssil_intensity = 1.2
		env.ssao_enabled = q >= 1
		env.volumetric_fog_enabled = q >= 1
		env.glow_enabled = true
		env.glow_intensity = 0.9 if q >= 1 else 0.6
		env.glow_bloom = 0.08
		env.glow_hdr_threshold = 0.9
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	if post:
		post.set_shader_parameter("fx", 1.0 if q >= 1 else 0.6)
	var vp := Engine.get_main_loop() as SceneTree
	if vp:
		vp.root.positional_shadow_atlas_size = 4096 if q >= 1 else 2048
		vp.root.msaa_3d = Viewport.MSAA_2X if q >= 1 else Viewport.MSAA_DISABLED
		vp.root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q >= 2 else Viewport.SCREEN_SPACE_AA_DISABLED


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
static func voice(key: String) -> AudioStream:
	var l := TranslationServer.get_locale().substr(0, 2)
	for ext in ["ogg", "wav", "mp3"]:
		var p := "res://voice/%s/%s.%s" % [l, key, ext]
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


static func get_fullscreen() -> bool:
	return bool(get_val("video", "fullscreen", false))


## Громкость и экран — применяются сразу ко всей игре.
static func apply_general() -> void:
	var v := get_volume()
	AudioServer.set_bus_mute(0, v <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(max(v, 0.001)))
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if get_fullscreen() else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(want)


# ---------------- главы ----------------
const UNLOCK_ALL := true          ## тестовая версия: все главы открыты сразу. Для релиза — false.


static func reached() -> int:
	return int(get_val("progress", "chapter", 1))


static func reach(n: int) -> void:
	if n > reached():
		set_val("progress", "chapter", n)
