extends Node3D
## Тестовый уровень: прихожая → зал (головоломка с телевизором) → коридор (головоломка со свечами).
## Никто не гоняется за игроком: только призраки, которые появляются и исчезают, загадки и скримеры.

var CHANNEL_CODE := [3, 7, 5]        ## «шоу Гостя»: каналы с оборотов фото 1975→1976→1977 (каждую игру новые)
const CANDLE_CODE := [2, 3, 1]       ## Степан (1991) → Аня (2004) → Вера (2026)
const VINTAGE = preload("res://scripts/vintage.gd")
const SETTINGS = preload("res://scripts/settings.gd")

@onready var player: CharacterBody3D = $Player
@onready var guest: Node3D = $Guest
@onready var shade: Node3D = $GhostBlood
@onready var girl: Node3D = $GhostGirl
@onready var mask: Node3D = $Player/Head/Camera3D/ScareMask
@onready var hall_lamp: OmniLight3D = $HallLamp
@onready var candle_light: OmniLight3D = $CandleLight
@onready var tv_screen: MeshInstance3D = $TV/Screen
@onready var tv_light: OmniLight3D = $TV/TVLight
@onready var tv_label: Label3D = $TV/ChannelLabel
@onready var servant_door: Node3D = $ServantDoor
@onready var servant_door2: Node3D = $ServantDoor2
@onready var key_node: Node3D = $Key
@onready var door1: Node3D = $Door1
@onready var exit_door: Node3D = $ExitDoor
@onready var bulb: OmniLight3D = $CorridorBulb
@onready var zombie: Node3D = $Zombie
var zombie_anim: AnimationPlayer
var zombie_run := false
var zombie_step_t := 0.0

var phase := "intro"
var time_now := 0.0
var busy := false
var lamp_done := false
var has_key := false
var door1_open := false
var exit_unlocked := false
var tv_on := false
var channel := 1
var dwell := 0.0
var dwell_done := false
var code_progress := 0
var tv_found := []          ## какие «его» каналы уже найдены
var candle_progress := 0
var candles_lit := [false, false, false]
var next_amb := 10.0
var scare_t := -1.0
var scare_done: Callable
var extra_hints := {}        ## подсказки для целей из haunts.gd
var bulb_dead := false
var exit_lamp_on := true
var corr_glow: StandardMaterial3D
var hall_glow: StandardMaterial3D
var exit_glow: StandardMaterial3D
var haunts: Node
var nursery: Node
var attic: Node
var floor2: Node
var furn: Node             ## мебель с механикой (furniture.gd)
var hallp: Node            ## загадки зала и коридора, осколок зеркала
var inv: Node              ## инвентарь (Tab)
var bath: Node             ## ванная второго этажа
var doors: Node            ## двери, которые открываются и закрываются по E
var bedroom: Node          ## спальня бабушки Веры
var hush := false          ## в спальне Веры: все звуки дома выключены (bedroom.gd); свои звуки там — с force = true
var events := {}            ## какие сценки уже случились
var shade_mode := ""        ## что сейчас делает призрак
var shade_t := 0.0
var shade_seen_t := 0.0
var guest_hidden_t := -1.0

# HUD
var hud: CanvasLayer
var obj_label: Label
var hint_label: Label
var msg_label: Label
var msg_timer := 0.0
var note_panel: PanelContainer
var note_label: Label
var fade: ColorRect
var scare_rect: TextureRect
var red_flash: ColorRect
var grain_mat: ShaderMaterial
var end_box: VBoxContainer
var end_title: Label
var end_text: Label

var drone: AudioStreamPlayer
var amb_layers := {}
var tv_static: AudioStreamPlayer3D
var sfx_cache := {}
var last_loud := -100.0      ## когда звучал последний громкий звук (крик, скример, удар)
const RUNNER_ON := false     ## бегущий призрак в коридоре (пока выключен)
const TEST_GRAB := true      ## ПРОБНЫЙ скример в прихожей: новая Аня держит за голову и кричит в лицо (scripts/test_grab.gd)
const LOUD := ["scream", "scream_mask", "sting", "bang", "whisper_harsh", "girl_appear", "phone_call", "gurgle", "pipes", "heartbeat", "far_moan", "far_whisper", "far_scream"]
var tv_mat: ShaderMaterial

const NOTE_TEXT := "LVL_01"
const NOTE2_TEXT := "LVL_02"

var targets := []
const HINTS := {
	"note": "LVL_03",
	"note2": "LVL_03",
	"photo1": "LVL_04",
	"photo2": "LVL_04",
	"photo3": "LVL_04",
	"tv": "LVL_05",
	"tv_off": "LVL_06",
	"servant": "LVL_07",
	"key": "LVL_08",
	"door1": "LVL_09",
	"candle1": "LVL_10",
	"candle2": "LVL_10",
	"candle3": "LVL_10",
	"exit": "LVL_09",
}


## Озвучка: если в res://voice/<язык>/ лежит файл с именем ключа — проиграть его.
var voice_player: AudioStreamPlayer


func _voice(key: String) -> void:
	var st := SETTINGS.voice(key)
	if st == null:
		return
	if voice_player == null:
		voice_player = AudioStreamPlayer.new()
		voice_player.bus = "Master"
		add_child(voice_player)
	voice_player.stream = st
	voice_player.play()


## Надписи и картинки с текстом под выбранный язык.
func _localize_scene() -> void:
	for i in 3:
		var pl := get_node_or_null("Portrait%d/Plaque" % (i + 1)) as Label3D
		if pl:
			pl.text = tr("LVL_PORTRAIT_%d" % (i + 1))
	if not TranslationServer.get_locale().begins_with("en"):
		return
	for n in ["DecalNeSmotri", "DecalOnZdes"]:
		var d := get_node_or_null(n) as Decal
		if d and d.texture_albedo:
			d.texture_albedo = load(d.texture_albedo.resource_path.replace(".png", "_en.png"))
	for i in 5:
		var s := get_node_or_null("Drawing%d" % (i + 1)) as Sprite3D
		if s and s.texture:
			s.texture = load(s.texture.resource_path.replace(".png", "_en.png"))


## Подсказка может быть ключом или парой [ключ формата, ключ аргумента].
func _hint_text(h) -> String:
	if h is Array:
		return tr(h[0]) % tr(h[1])
	return tr(str(h))


func _ready() -> void:
	SETTINGS.apply_lang()
	randomize()
	# три разных канала Гостя (не первый — на нём телевизор включается)
	var chans := [2, 3, 4, 5, 6, 7, 8, 9]
	chans.shuffle()
	CHANNEL_CODE = chans.slice(0, 3)
	# портреты в коридоре висят каждый раз в другом порядке (годы те же — порядок свечей тот же)
	var spots: Array = [$Portrait1.position, $Portrait2.position, $Portrait3.position]
	spots.shuffle()
	for i in 3:
		get_node("Portrait%d" % (i + 1)).position = spots[i]
	_localize_scene()
	_build_hud()
	SETTINGS.apply($WorldEnvironment.environment, grain_mat, SETTINGS.get_quality())
	# у каждой лампочки свой материал свечения, чтобы гасить их отдельно
	corr_glow = _own_mat($CorrBulbMesh)
	hall_glow = _own_mat($HallBulbMesh)
	exit_glow = _own_mat($ExitLampPanel)
	add_child(preload("res://scripts/pause.gd").new())
	if TEST_GRAB:
		var tg := preload("res://scripts/test_grab.gd").new()
		tg.L = self
		add_child(tg)
	# ключ в серванте — модель из Blender вместо кольца и стержня
	for nm in ["Ring", "Shaft"]:
		(key_node.get_node(nm) as Node3D).visible = false
	var km: Node3D = load("res://models/props/key_hall.glb").instantiate()
	km.name = "KeyModel"
	key_node.add_child(km)
	# осколок стекла рядом с ключом — тоже из Blender
	var old_shard := key_node.get_node("Shard") as Node3D
	old_shard.visible = false
	var gs: Node3D = preload("res://scripts/inventory.gd").glass_shard()
	gs.transform = old_shard.transform
	key_node.add_child(gs)
	inv = preload("res://scripts/inventory.gd").new()
	inv.L = self
	add_child(inv)
	_setup_audio()
	player.step.connect(_on_step)
	player.action.connect(_interact)
	player.toggled_light.connect(func(): _sfx("click", -6.0))
	guest.visible = false
	preload("res://scripts/door_kit.gd").apply_all(self)     # двери из набора вместо фанерных
	_setup_house()
	_setup_girl()
	shade.visible = false
	tv_mat = ShaderMaterial.new()
	tv_mat.shader = preload("res://shaders/crt.gdshader")
	_tv_pic(Color(0.02, 0.02, 0.025))
	tv_screen.material_override = tv_mat
	tv_light.light_energy = 0.0
	tv_label.visible = false
	targets = [
		{"id": "note", "pos": $Note.global_position, "th": 0.4, "dist": 2.2},
		{"id": "note2", "pos": $Note2.global_position, "th": 0.35, "dist": 2.0},
		{"id": "photo1", "pos": $Photo1.global_position, "th": 0.35, "dist": 2.2},
		{"id": "photo2", "pos": $Photo2.global_position, "th": 0.35, "dist": 2.2},
		{"id": "photo3", "pos": $Photo3.global_position, "th": 0.35, "dist": 2.2},
		{"id": "tv", "pos": tv_screen.global_position, "th": 0.3, "dist": 2.6},
		{"id": "tv_off", "pos": $TV/PowerButton.global_position, "th": 0.25, "dist": 2.6},
		{"id": "servant", "pos": $Servant.global_position + Vector3(0, 1.0, 0), "th": 0.45, "dist": 2.2},
		{"id": "key", "pos": key_node.global_position, "th": 0.35, "dist": 2.0},
		{"id": "door1", "pos": Vector3(0, 1.1, -6), "th": 0.5, "dist": 2.2},
		{"id": "candle1", "pos": $Portrait1/Candle.global_position, "th": 0.35, "dist": 1.8},
		{"id": "candle2", "pos": $Portrait2/Candle.global_position, "th": 0.35, "dist": 1.8},
		{"id": "candle3", "pos": $Portrait3/Candle.global_position, "th": 0.35, "dist": 1.8},
		{"id": "exit", "pos": Vector3(0, 1.1, -18), "th": 0.5, "dist": 2.2},
	]
	_set_objective("LVL_11")
	haunts = preload("res://scripts/haunts.gd").new()
	haunts.L = self
	add_child(haunts)
	nursery = preload("res://scripts/nursery.gd").new()
	nursery.L = self
	add_child(nursery)
	attic = preload("res://scripts/attic.gd").new()
	attic.L = self
	add_child(attic)
	var distant := preload("res://scripts/distant.gd").new()
	distant.L = self
	add_child(distant)
	hallp = preload("res://scripts/hall_puzzle.gd").new()
	hallp.L = self
	add_child(hallp)
	floor2 = preload("res://scripts/floor2.gd").new()
	add_child(floor2)
	floor2.setup(self)
	bath = preload("res://scripts/bathroom.gd").new()
	add_child(bath)
	bath.setup(self)
	doors = preload("res://scripts/doors.gd").new()
	doors.L = self
	add_child(doors)
	doors.add("door1", door1, 0.0, 1.6, Vector3(0, 1.1, -6), func(): return door1_open)
	doors.add("exit", exit_door, 0.0, 1.6, Vector3(0, 1.1, -18), func(): return events.has("nursery_open"))
	doors.add("land", get_node("F2LandPivot"), 0.0, 1.6, Vector3(3.0, -2.4, -34.2), func(): return phase == "floor2")
	doors.add("bath", bath.door_pivot, 0.0, bath.door_angle, Vector3(-0.8, -2.4, -36.8), func(): return bath.unlocked)
	doors.add("bath_in", bath.inner_pivot, bath.INNER_CLOSED, bath.INNER_OPEN, bath.INNER_C, func(): return phase == "floor2")
	bedroom = preload("res://scripts/bedroom.gd").new()
	add_child(bedroom)
	bedroom.setup(self)
	var atmo := preload("res://scripts/atmosphere.gd").new()     # туман по полу, пыль, облака на луне, мелкие события
	add_child(atmo)
	atmo.setup(self)
	furn = preload("res://scripts/furniture.gd").new()          # мебель чердака и полочки холла (ящики, дверцы, крышки)
	add_child(furn)
	furn.setup(self)
	var dec := preload("res://scripts/decals.gd").new()          # подтёки, пятна, плесень по дому
	add_child(dec)
	dec.setup(self)
	# тяжёлый подсвечник в прихожей издалека (со второго этажа сквозь стены) не нужен — экономим отрисовку
	for mi in get_node("HallCandlestick").find_children("*", "GeometryInstance3D", true, false):
		mi.visibility_range_end = 20.0
	_setup_zombie()
	player.mouse_sens *= SETTINGS.get_sens()
	SETTINGS.apply_general()
	# выбрана глава в меню — переносим в её начало
	if Engine.has_meta("chapter"):
		var ch: int = Engine.get_meta("chapter")
		Engine.remove_meta("chapter")
		jump_chapter.call_deferred(ch)


## В коридоре на тебя бежит не зомби, а девочка-призрак (spirit.gd, анимация бега).
var run_girl: Node3D
func _setup_zombie() -> void:
	zombie.visible = false
	for c in zombie.get_children():
		c.queue_free()
	run_girl = preload("res://scripts/spirit.gd").new()
	zombie.add_child(run_girl)
	zombie_anim = null


func _zombie_start() -> void:
	events["zombie"] = true
	zombie_run = true
	zombie.global_position = Vector3(0, 0, -17.2)
	zombie.rotation.y = 0.0
	zombie.visible = true
	run_girl.play("run", 2.0, 0.0)
	run_girl.set_blood(0.8)
	_sfx("scream", -2.0, 1.35)
	run_girl.scream(1.2)
	player.flicker = 0.15
	bulb.light_energy = 0.0


func _update_zombie(delta: float) -> void:
	if not zombie_run:
		return
	var to: Vector3 = player.global_position - zombie.global_position
	to.y = 0
	var d := to.length()
	zombie.rotation.y = atan2(to.x, to.z)
	zombie.global_position += to / max(d, 0.001) * 7.5 * delta
	zombie_step_t -= delta
	if zombie_step_t <= 0.0:
		zombie_step_t = 0.27
		_sfx3d("thump", zombie.global_position, -2.0, randf_range(1.3, 1.5))
	player.shake = max(player.shake, clamp(1.0 - d / 10.0, 0.0, 1.0) * 0.4)
	if d < 1.3:
		# в последний момент исчезает
		zombie_run = false
		zombie.visible = false
		if zombie_anim:
			zombie_anim.stop()
		player.flicker = 0.35
		player.shake = 1.0
		red_flash.color.a = 0.6
		create_tween().tween_property(red_flash, "color:a", 0.0, 0.8)
		_sfx("sting", 0.0)
		_sfx("scream", -6.0, 0.8)


# ---------------- HUD ----------------
func _build_hud() -> void:
	var post := CanvasLayer.new()
	post.layer = 1
	add_child(post)
	var grain := ColorRect.new()
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grain_mat = ShaderMaterial.new()
	grain_mat.shader = load("res://shaders/grain.gdshader")
	grain.material = grain_mat
	post.add_child(grain)

	hud = CanvasLayer.new()
	hud.layer = 2
	add_child(hud)
	obj_label = _label(18, Color(0.6, 0.57, 0.5))
	obj_label.position = Vector2(20, 16)
	hud.add_child(obj_label)
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.45)
	dot.size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position -= Vector2(2, 2)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dot)
	hint_label = _label(18, Color(0.85, 0.82, 0.75))
	hint_label.set_anchors_preset(Control.PRESET_CENTER)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.position = Vector2(-200, 30)
	hint_label.size = Vector2(400, 30)
	hud.add_child(hint_label)
	msg_label = _label(22, Color(0.9, 0.87, 0.8))
	msg_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_label.position = Vector2(-400, -120)
	msg_label.size = Vector2(800, 80)
	hud.add_child(msg_label)

	note_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.84, 0.8, 0.69)
	sb.set_content_margin_all(28)
	note_panel.add_theme_stylebox_override("panel", sb)
	note_panel.set_anchors_preset(Control.PRESET_CENTER)
	note_panel.position = Vector2(-260, -230)
	note_panel.size = Vector2(520, 460)
	note_label = _label(19, Color(0.17, 0.13, 0.09))
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	note_label.custom_minimum_size = Vector2(464, 0)
	note_panel.add_child(note_label)
	note_panel.visible = false
	hud.add_child(note_panel)

	red_flash = ColorRect.new()
	red_flash.color = Color(0.6, 0, 0, 0)
	red_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	red_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(red_flash)
	scare_rect = TextureRect.new()
	scare_rect.texture = load("res://textures/scare_face.png")
	scare_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scare_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	scare_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	scare_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scare_rect.visible = false
	hud.add_child(scare_rect)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 2.0)

	end_box = VBoxContainer.new()
	end_box.set_anchors_preset(Control.PRESET_CENTER)
	end_box.position = Vector2(-300, -80)
	end_box.size = Vector2(600, 160)
	end_title = _label(48, Color(0.64, 0.08, 0.05))
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_text = _label(20, Color(0.7, 0.66, 0.6))
	end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preload("res://scripts/flicker.gd").apply_font(end_title)
	end_box.add_child(end_title)
	end_box.add_child(end_text)
	end_box.visible = false
	hud.add_child(end_box)


func _label(sz: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _set_objective(t: String) -> void:
	obj_label.text = tr("LVL_12") + tr(t)


func _say(t: String, sec := 3.5) -> void:
	msg_label.text = tr(t)
	_voice(t)
	msg_label.modulate.a = 1.0
	msg_timer = sec


# ---------------- звук ----------------
func _setup_audio() -> void:
	SETTINGS.master_fx(true)                     # одна реверберация + лимитер (не копятся при перезагрузке)
	# нагнетающий фон: тихий тревожный гул (звуки — Sonniss GDC 2026, см. CREDITS.txt)
	drone = AudioStreamPlayer.new()
	drone.stream = _loop_stream("dread")
	drone.volume_db = -8.0
	add_child(drone)
	drone.play()
	# дом «живёт»: дождь по окнам, ветер в трубе, гул старой проводки
	for l in [["rain_window", -13.0], ["chimney", -15.0], ["house_hum", -16.0]]:
		var a := AudioStreamPlayer.new()
		a.stream = _loop_stream(l[0])
		a.volume_db = l[1]
		add_child(a)
		a.play()
		amb_layers[l[0]] = a
	tv_static = AudioStreamPlayer3D.new()
	tv_static.stream = load("res://audio/tv_static.wav")
	tv_static.volume_db = -14.0
	$TV.add_child(tv_static)
	tv_static.finished.connect(func(): if tv_on: tv_static.play())


func _loop_stream(n: String) -> AudioStream:
	var st: AudioStreamOggVorbis = load("res://audio/house/%s.ogg" % n)
	st.loop = true
	return st


## Вокруг тихо уже sec секунд: нет громких звуков, катсцен и скримеров.
func quiet_for(sec: float) -> bool:
	return time_now - last_loud > sec and not busy and scare_t < 0.0 and not shade.visible


## Звук по имени; если есть варианты (giggle_2.wav, giggle_3.wav…) — каждый раз случайный.
func _stream(n: String) -> AudioStream:
	if not sfx_cache.has(n):
		var v := [load("res://audio/%s.wav" % n)]
		for i in range(2, 6):
			var pth := "res://audio/%s_%d.wav" % [n, i]
			if ResourceLoader.exists(pth):
				v.append(load(pth))
		sfx_cache[n] = v
	var arr: Array = sfx_cache[n]
	return arr[randi() % arr.size()]


func _sfx(n: String, db := 0.0, pitch := 1.0, force := false) -> void:
	if hush and not force:
		return
	if n in LOUD and db > -12.0:
		last_loud = time_now
	var p := AudioStreamPlayer.new()
	p.stream = _stream(n)
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _sfx3d(n: String, pos: Vector3, db := 0.0, pitch := 1.0, force := false) -> void:
	if hush and not force:
		return
	if n in LOUD and db > -12.0:
		last_loud = time_now
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(n)
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = 3.0
	add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func _on_step() -> void:
	_sfx("step%d" % (randi() % 4), -10.0, randf_range(0.9, 1.1), true)     # свои шаги слышны всегда
	if randf() < 0.07:
		_sfx("creak", -18.0, randf_range(0.8, 1.2))


# ---------------- взаимодействие ----------------
func _target() -> String:
	var cam_pos: Vector3 = player.cam.global_position
	var fwd: Vector3 = player.forward()
	var best := ""
	var best_a := 9.0
	for t in targets:
		if not _target_ok(t.id):
			continue
		var d: Vector3 = t.pos - cam_pos
		if d.length() > t.dist:
			continue
		var a: float = fwd.angle_to(d)
		if a < t.th and a < best_a:
			best_a = a
			best = t.id
	return best


func _target_ok(id: String) -> bool:
	if id.begins_with("n_"):
		return nursery.target_ok(id)
	if id.begins_with("a_"):
		return attic.target_ok(id)
	if id.begins_with("fn_"):
		return furn.target_ok(id)
	if id.begins_with("f_"):
		return floor2.target_ok(id)
	if id.begins_with("h_"):
		return hallp.target_ok(id)
	if id.begins_with("b_"):
		return bath.target_ok(id)
	if id.begins_with("d_"):
		return doors.target_ok(id)
	if id.begins_with("v_"):
		return bedroom.vroom.target_ok(id)
	match id:
		"tv_off": return tv_on
		"servant": return phase == "intro" or phase == "hall"
		"key": return key_node.visible and phase == "key"
		"note2": return phase != "intro" and phase != "hall"
		"door1": return not door1_open
		"phone": return extra_hints.has("phone")
		"exit": return not events.has("nursery_open")
		"candle1", "candle2", "candle3": return phase == "corridor" and not candles_lit[int(id.right(1)) - 1]
	return true


func _interact() -> void:
	if busy:
		return
	if note_panel.visible:
		note_panel.visible = false
		return
	var t := _target()
	match t:
		"note":
			_show_note(NOTE_TEXT)
		"note2":
			_show_note(NOTE2_TEXT)
		"photo1", "photo2", "photo3":
			# фото с подписью на обороте — и в инвентарь, во вкладку записок
			var n := int(t.right(1)) - 1
			var key := "LVL_%d" % (13 + n)
			var txt: String = tr(key) % CHANNEL_CODE[n]
			_say(txt, 5.0)
			inv.add_note(key, txt)
		"tv":
			_tv_next()
		"tv_off":
			_tv_power(false)
		"servant":
			_sfx("knock", -14.0, 1.6)
			_say("LVL_16")
		"key":
			key_node.visible = false
			has_key = true
			inv.add("key")
			_sfx("pickup", -6.0)
			_say("LVL_17")
			hallp.got_shard()
			_set_objective("LVL_18")
			phase = "door"
		"door1":
			if not has_key:
				_sfx("knock", -10.0)
				_say("LVL_19")
			else:
				door1_open = true
				inv.remove("key")
				_sfx("door", -4.0)
				create_tween().tween_property(door1, "rotation:y", 1.6, 1.6).set_trans(Tween.TRANS_SINE)
				phase = "corridor"
				SETTINGS.reach(2)
				_set_objective("LVL_20")
		"candle1", "candle2", "candle3":
			if not hallp.need_matches():
				_light_candle(int(t.right(1)))
		"exit":
			if not exit_unlocked:
				_sfx("knock", -10.0)
				_say("LVL_21")
			else:
				_open_nursery()
		_:
			haunts.interact(t)
			nursery.interact(t)
			attic.interact(t)
			floor2.interact(t)
			hallp.interact(t)
			bath.interact(t)
			doors.interact(t)
			bedroom.vroom.interact(t)
			furn.interact(t)


func _show_note(text: String) -> void:
	inv.add_note(text)
	note_label.text = tr(text)
	_sfx("page", -6.0)
	_voice(text)
	note_panel.visible = true
	_sfx("creak", -20.0, 1.5)


# ---------------- призрак: появления и исчезновения ----------------
func _sees(p: Vector3, max_angle := 0.5, need_light := true) -> bool:
	var to: Vector3 = p - player.cam.global_position
	if player.forward().angle_to(to) > max_angle:
		return false
	var q := PhysicsRayQueryParameters3D.create(player.cam.global_position, p)
	q.exclude = [player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return false
	return player.is_light_lit() or not need_light or to.length() < 2.0


## Призрак «краем глаза»: сбоку, в поле зрения, но не там, куда смотришь.
## Шёпот с его стороны и мигание фонаря цепляют взгляд; посмотрел прямо — исчез.
func _glance_ghost() -> void:
	if shade.visible:
		return
	var fwd: Vector3 = player.forward()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var best := Vector3.ZERO
	var best_room := 0.0
	for a in [0.62, -0.62, 0.5, -0.5, 0.75, -0.75]:
		var dir := fwd.rotated(Vector3.UP, a)
		var r := _room_toward(dir, 2.8)
		if r > best_room + 0.05:
			best_room = r
			best = dir
	if best_room < 1.2:
		return
	var pos := player.global_position + best * best_room
	_shade_show(Vector3(pos.x, player.global_position.y, pos.z), "glance")
	_sfx3d("whisper", pos + Vector3(0, 1.4, 0), 2.0, 1.15)
	player.flicker = 0.2


## Первое появление: за проёмом зала, сгорбившись, медленно проходит полупрозрачная фигура
## (через весь проём, слева направо) и растворяется. Отдельный призрак — shade не трогаем.
## Создаётся заранее (_prep_pass_ghost), чтобы в момент появления не было подгрузки и компиляции шейдера.
var pass_g: Node3D
var pass_lamp: OmniLight3D
const PASS_A := Vector3(-1.4, 0, -1.6)
const PASS_B := Vector3(1.6, 0, -1.6)


func _prep_pass_ghost() -> void:
	pass_g = preload("res://scripts/spirit.gd").new()
	add_child(pass_g)
	pass_g.set_ghostly(0.55)
	pass_g.set_blood(0.2)
	pass_g.set_eyes(0.0)
	pass_g.mat.set_shader_parameter("rim", 0.18)
	pass_lamp = OmniLight3D.new()          # еле заметный холодный отсвет — видно и без фонаря
	pass_lamp.light_color = Color(0.6, 0.7, 1.0)
	pass_lamp.light_energy = 0.0
	pass_lamp.omni_range = 1.8
	pass_lamp.position = Vector3(0, 1.3, 0.3)
	pass_g.add_child(pass_lamp)
	# «прогрев»: пару кадров рисуем её крошечной в проёме — шейдер скомпилируется сейчас, а не в момент появления
	pass_g.global_position = PASS_A.lerp(PASS_B, 0.5) + Vector3(0, 1.2, 0)
	pass_g.scale = Vector3.ONE * 0.001
	pass_g.play("walk", 0.9, 0.0)
	for i in 3:
		await get_tree().process_frame
	pass_g.visible = false
	pass_g.scale = Vector3.ONE
	pass_g.set_process(false)
	pass_g.ap.stop()


func _doorway_pass() -> void:
	var g := pass_g
	g.global_position = PASS_A
	g.rotation.y = atan2(PASS_B.x - PASS_A.x, PASS_B.z - PASS_A.z)
	g.set_ghostly(0.55)
	g.play("walk", 1.9, 0.0)
	g.visible = true
	g.set_process(true)
	pass_lamp.light_energy = 0.35
	var dur := 1.7
	var tw := create_tween()
	tw.tween_property(g, "global_position", PASS_B, dur)
	tw.parallel().tween_method(func(v: float): g.set_ghostly(v), 0.55, 0.95, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(pass_lamp, "light_energy", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): g.visible = false; g.ap.stop(); g.set_process(false))
	_sfx3d("whisper", Vector3(0.2, 1.4, -1.5), -10.0, 0.9)
	for k in 4:
		get_tree().create_timer(0.2 + k * 0.38).timeout.connect(func(): _sfx3d("step%d" % (randi() % 4), PASS_A.lerp(PASS_B, (0.2 + k * 0.38) / dur), -14.0, 0.9))


func _shade_show(pos: Vector3, mode: String) -> void:
	_shade_light(mode == "glance")
	shade.global_position = pos
	shade.visible = true
	_face(shade, player.global_position)
	shade_mode = mode
	shade_t = 0.0
	shade_seen_t = 0.0


## Слабый холодный свет на призраке — чтобы его было видно вне луча фонаря.
var _shade_lamp: OmniLight3D
func _shade_light(on: bool) -> void:
	if _shade_lamp == null:
		_shade_lamp = OmniLight3D.new()
		_shade_lamp.light_color = Color(0.6, 0.7, 1.0)
		_shade_lamp.omni_range = 2.2
		_shade_lamp.position = Vector3(0, 1.5, 0.5)
		shade.add_child(_shade_lamp)
	_shade_lamp.light_energy = 0.7 if on else 0.0


func _shade_hide(sting := false, flicker := true) -> void:
	if flicker:
		player.flicker = 0.25
		_sfx("click", -8.0)
	shade.visible = false
	shade_mode = ""
	_shade_light(false)
	if sting:
		_sfx("sting", -4.0)
		player.shake = 0.5


func _update_shade(delta: float) -> void:
	if not shade.visible:
		return
	shade_t += delta
	var head: Vector3 = shade.global_position + Vector3(0, 1.5, 0)
	var seen := _sees(head, 0.55)
	if seen:
		shade_seen_t += delta
	var dist: float = (shade.global_position - player.global_position).length()
	match shade_mode:
		"doorway":
			# стоит в проёме зала, исчезает, когда на него посветили или подошли
			if shade_seen_t > 0.7 or dist < 2.8:
				_shade_hide(false)
				_sfx("whisper", -10.0)
		"behind":
			# стоит за спиной: исчезает, как только игрок обернулся
			if _sees(head, 0.6, false):
				_shade_hide(true)
			elif shade_t > 7.0:
				_shade_hide(false, false)
				_sfx("whisper", -6.0)
		"corridor_far":
			# в конце коридора; при мигании фонаря становится ближе, потом исчезает
			if shade_seen_t > 1.2 and not events.has("corridor_step"):
				events["corridor_step"] = true
				player.flicker = 0.5
				_sfx("click", -8.0)
				shade.global_position = Vector3(0, 0, -12.5)
				_face(shade, player.global_position)
				shade_seen_t = 0.0
				_sfx("drag", -4.0)
			elif events.has("corridor_step") and (shade_seen_t > 0.8 or dist < 3.0):
				_shade_hide(true)
		"flash":
			if shade_t > 1.6 or dist < 2.0:
				_shade_hide(false)
		"glance":
			# краем глаза: посмотрел прямо — исчез со щелчком фонаря
			if _sees(head, 0.3, false):
				_shade_hide(true)
			elif shade_t > 8.0:
				_shade_hide(false, false)
		"peek":
			if shade_seen_t > 0.35:
				_shade_hide(false)
				_sfx("whisper", -6.0)
			elif shade_t > 12.0:
				_shade_hide(false, false)
	_face(shade, player.global_position)


func _face(n: Node3D, target: Vector3) -> void:
	var d := target - n.global_position
	n.rotation.y = atan2(d.x, d.z)


func _behind_player(d := 1.3) -> Vector3:
	var back: Vector3 = -player.forward()
	back.y = 0
	back = back.normalized()
	# не ставить призрака в стену: сзади стена близко — пробуем чуть вбок, где больше места
	var best := back
	var room := _room_toward(back, d)
	if room < d:
		for a in [0.7, -0.7, 1.2, -1.2]:
			var dir := back.rotated(Vector3.UP, a)
			var r := _room_toward(dir, d)
			if r > room + 0.05:
				room = r
				best = dir
	return player.global_position + best * clampf(room, 0.45, d)


## Сколько места (до стены) в направлении dir, не больше d.
func _room_toward(dir: Vector3, d: float) -> float:
	var from: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (d + 0.45))
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return d
	return from.distance_to(hit.position) - 0.45


func _check_events() -> void:
	# за креслом стоит женщина в окровавленном платье — пока на неё не смотрят
	if events.has("peek_wait") and not events.has("peek") and not shade.visible and phase == "hall":
		var chair := Vector3(-0.3, 1.2, -3.0)
		if player.forward().angle_to(chair - player.cam.global_position) > 1.2:
			events["peek"] = true
			_shade_show(Vector3(-0.35, 0, -3.75), "peek")
			_sfx3d("creak", chair, -4.0, 0.7)
	# 1. силуэт в проёме зала, когда игрок впервые смотрит туда после отключения света
	if lamp_done and not events.has("doorway") and player.global_position.z < 4.5:
		var p := Vector3(0.2, 0, -1.2)
		if player.forward().angle_to(p + Vector3(0, 1.4, 0) - player.cam.global_position) < 0.35:
			events["doorway"] = true
			_doorway_pass()
	# 3. зомби: игрок светит в конец коридора — он с рёвом несётся из темноты
	if RUNNER_ON and phase == "corridor" and events.has("corridor_step") and not shade.visible and not events.has("zombie") \
			and player.global_position.z > -11.0 and player.forward().z < -0.85 and player.is_light_lit():
		if not events.has("zombie_wait"):
			events["zombie_wait"] = time_now
		elif time_now - float(events["zombie_wait"]) > 1.5:
			_zombie_start()
	# 2. в коридоре: фигура в самом конце
	if phase == "corridor" and not events.has("corridor") and player.global_position.z < -6.6:
		events["corridor"] = true
		_shade_show(Vector3(0, 0, -16.8), "corridor_far")
		_sfx("sting", -8.0)


# ---------------- телевизор и Гость ----------------
func _tv_next() -> void:
	if not tv_on:
		_tv_power(true)
	else:
		channel = channel % 9 + 1
	_sfx("click", -4.0)
	dwell = 0.0
	dwell_done = false
	tv_label.text = str(channel)


func _tv_power(on: bool) -> void:
	tv_on = on
	tv_label.visible = on
	tv_label.text = str(channel)
	tv_light.light_energy = 0.0
	if on:
		tv_static.play()
		if phase == "intro":
			phase = "hall"
			_set_objective("LVL_22")
	else:
		tv_static.stop()
		_tv_pic(Color(0.02, 0.02, 0.025))
		_sfx("click", -4.0)


## Картинка на экране телевизора: цвет передачи и сколько «снега».
func _tv_pic(col: Color, noise := 0.0) -> void:
	tv_mat.set_shader_parameter("tint", col)
	tv_mat.set_shader_parameter("noise_amt", noise)


## Изображение поверх передачи (лицо при скримере); null — убрать.
func _tv_img(tex: Texture2D) -> void:
	tv_mat.set_shader_parameter("img", tex)
	tv_mat.set_shader_parameter("has_img", 1.0 if tex else 0.0)


func _update_tv(delta: float) -> void:
	if not tv_on:
		return
	dwell += delta
	if dwell < 1.5:
		var g := randf_range(0.25, 0.7)
		_tv_pic(Color(g, g, g * 1.05), 1.0)
		tv_light.light_energy = g * 1.5
		return
	_tv_pic(Color.from_hsv(channel / 9.0, 0.35, 0.55), 0.12)
	tv_light.light_energy = 0.9
	if dwell_done:
		return
	dwell_done = true
	if code_progress >= CHANNEL_CODE.size():   # загадка уже решена — каналы можно листать просто так
		return
	if channel == CHANNEL_CODE[code_progress]:
		# его передача (по порядку лет на фото): пустое кресло поворачивается к экрану
		tv_found.append(channel)
		code_progress = tv_found.size()
		_sfx3d("knock", $Servant.global_position, -6.0, 2.0)
		hallp.tv_found(code_progress)
		if code_progress == 1 and not events.has("behind"):
			# дыхание за спиной: призрак стоит прямо за игроком
			events["behind"] = true
			await get_tree().create_timer(2.5).timeout
			_glance_ghost()
		elif code_progress == 2 and not events.has("chair"):
			events["chair"] = true
			events["peek_wait"] = true
		elif code_progress >= CHANNEL_CODE.size():
			await get_tree().create_timer(1.6).timeout
			_solve_tv()
	elif channel in CHANNEL_CODE and code_progress > 0 and not tv_found.has(channel):
		# его канал, но не по порядку — кресло со скрипом отворачивается обратно
		tv_found.clear()
		code_progress = 0
		hallp.tv_reset()
	elif not channel in CHANNEL_CODE:
		if code_progress > 0:
			tv_found.clear()
			code_progress = 0
			hallp.tv_reset()
		hallp.tv_mistake()


func _update_guest(delta: float) -> void:
	return
	if not guest.visible and guest_hidden_t < 0.0:
		return
	# после второго верного канала: кресло пустеет, пока на него не смотрят, и Гость возвращается, когда отвернёшься
	if guest_hidden_t >= 0.0:
		var chair := Vector3(-0.3, 1.0, -3)
		var looking: bool = player.forward().angle_to(chair - player.cam.global_position) < 0.7
		if guest_hidden_t == 0.0 and not looking:
			guest.visible = false
			guest_hidden_t = 0.001
		elif guest_hidden_t > 0.0:
			if looking:
				guest_hidden_t += delta
			elif guest_hidden_t > 1.2:
				guest.visible = true
				guest_hidden_t = -1.0
				_sfx3d("creak", chair, -6.0, 0.8)


func _solve_tv() -> void:
	busy = true
	guest.visible = true
	guest_hidden_t = -1.0
	_tv_pic(Color(0.8, 0.75, 0.7), 0.15)
	_tv_img(load("res://textures/scare_face.png"))
	tv_light.light_energy = 3.0
	_sfx("scream", -6.0, 1.3)
	_sfx("sting", -2.0)
	player.shake = 0.6
	await get_tree().create_timer(0.9).timeout
	_tv_img(null)
	_tv_power(false)
	guest.visible = false
	_sfx("whisper", -8.0)
	_sfx3d("door", $Servant.global_position, -6.0, 1.4)
	create_tween().tween_property(servant_door, "rotation:y", 1.7, 1.2)
	create_tween().tween_property(servant_door2, "rotation:y", -1.7, 1.2)
	_set_objective("LVL_24")
	phase = "key"
	busy = false


# ---------------- свечи в коридоре ----------------
func _set_candle(i: int, on: bool) -> void:
	candles_lit[i - 1] = on
	get_node("Portrait%d/Flame" % i).visible = on
	get_node("Portrait%d/Light" % i).light_energy = 0.7 if on else 0.0


func _light_candle(i: int) -> void:
	_set_candle(i, true)
	_sfx("click", -10.0, 0.6)
	if i == CANDLE_CODE[candle_progress]:
		candle_progress += 1
		if candle_progress == 2 and not events.has("candle_flash"):
			events["candle_flash"] = true
			await get_tree().create_timer(0.8).timeout
			_shade_show(Vector3(0.3, 0, -17.0), "flash")
		elif candle_progress >= CANDLE_CODE.size():
			_solve_candles()
	else:
		busy = true
		await get_tree().create_timer(0.6).timeout
		for k in 3:
			_set_candle(k + 1, false)
		candle_progress = 0
		hallp.candle_mistake()
		busy = false


func _solve_candles() -> void:
	busy = true
	_sfx3d("knock", Vector3(0, 1.2, -18), -2.0, 1.5)
	exit_unlocked = true
	inv.remove("matches")             # свечи горят — спички больше не нужны
	hallp.candles_solved()
	_set_objective("LVL_27")
	drone.volume_db = -40.0
	await get_tree().create_timer(2.0).timeout
	busy = false
	# главный скример: стоит обернуться — и он прямо перед лицом
	events["wait_turn"] = true


func _check_turn_scare() -> void:
	if not events.has("wait_turn") or events.has("turn_done"):
		return
	if player.forward().z > 0.5:   # игрок посмотрел назад, в сторону зала
		events["turn_done"] = true
		_shade_show(player.global_position + player.forward() * 0.7, "flash")
		await get_tree().create_timer(0.15).timeout
		_screamer(func():
			shade.visible = false
			drone.volume_db = -8.0
			_say("LVL_28")
		)


# ---------------- скримеры и финал ----------------
func _screamer(after: Callable) -> void:
	busy = true
	player.frozen = true
	scare_t = 0.0
	scare_done = after
	mask.visible = true
	fade.color.a = 0.0
	_sfx("scream_mask", 2.0)       # маска: прежний звук
	player.shake = 1.0


func _update_scare(delta: float) -> void:
	if scare_t < 0.0:
		return
	scare_t += delta
	var s := 1.0 + scare_t * 0.35 + randf_range(-0.03, 0.03)
	mask.position = Vector3(randf_range(-0.012, 0.012), -0.03 + randf_range(-0.012, 0.012), -0.4 + scare_t * 0.12)
	mask.rotation = Vector3(randf_range(-0.06, 0.06), randf_range(-0.08, 0.08), randf_range(-0.1, 0.1))
	mask.scale = Vector3.ONE * s
	red_flash.color.a = randf_range(0.1, 0.35)
	if scare_t > 1.4:
		scare_t = -1.0
		mask.visible = false
		red_flash.color.a = 0.0
		player.frozen = false
		busy = false
		if scare_done.is_valid():
			scare_done.call()


## Дверь в конце коридора ведёт в детскую Ани.
func _open_nursery() -> void:
	events["nursery_open"] = true
	busy = true
	_sfx("door", -4.0, 0.8)
	create_tween().tween_property(exit_door, "rotation:y", 1.6, 2.2).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(1.5).timeout
	phase = "nursery"
	SETTINGS.reach(3)
	busy = false
	_set_objective("LVL_29")
	nursery.start_dance()


## Старый финал (девочка за дверью) — сейчас не используется.
func _finale() -> void:
	# дверь в конце коридора медленно открывается, за ней темнота и девочка
	busy = true
	player.frozen = true
	_sfx("door", -4.0, 0.8)
	create_tween().tween_property(exit_door, "rotation:y", 1.5, 3.0).set_trans(Tween.TRANS_SINE)
	girl.global_position = Vector3(0, 0, -18.9)
	_face(girl, player.global_position)
	girl.visible = true
	_sfx("girl_appear", -1.0)
	_girl_anim(0.0)
	await get_tree().create_timer(2.2).timeout
	_sfx("whisper", 0.0)
	_girl_anim(0.5)
	await get_tree().create_timer(1.6).timeout
	bulb.light_energy = 0.0
	exit_lamp_on = false
	_sfx3d("buzz", $ExitLamp.global_position, -4.0)
	door1_open = false          # лампочка больше не мигает
	player.flicker = 0.8
	_sfx("click", -6.0)
	await get_tree().create_timer(0.5).timeout
	girl.visible = false
	drone.stop()
	await get_tree().create_timer(1.2).timeout
	_screamer(func():
		player.frozen = true
		fade.color.a = 1.0
		end_title.text = tr("LVL_30")
		end_text.text = tr("LVL_31")
		end_box.visible = true
		phase = "end"
	)


# ---------------- дом из пака Vintage Living Room ----------------
func _own_mat(mi: MeshInstance3D) -> StandardMaterial3D:
	var m: StandardMaterial3D = mi.get_surface_override_material(0).duplicate()
	mi.set_surface_override_material(0, m)
	return m


func _setup_house() -> void:
	# материалы для всех моделей пака
	for n in find_children("*", "Node3D", true, false):
		if n.scene_file_path.contains("/vintage/"):
			VINTAGE.apply(n)
	# дверные полотна из модулей стен становятся настоящими дверями на петлях
	_hinge("Door1Wall", door1)
	_hinge("ExitWall", exit_door)
	# в межкомнатных проёмах дверей нет
	for w in ["DwHall", "DwLiving", "DwCorr", "DwNursery"]:
		get_node(w + "/small_door").visible = false


func _hinge(wall: String, pivot: Node3D) -> void:
	var leaf: Node3D = get_node(wall + "/small_door")
	pivot.global_position = leaf.global_position
	leaf.reparent(pivot, true)


## Девочка-призрак: вместо старой модели — spirit.gd (лицензия CC BY).
var girl_sp: Node3D
func _setup_girl() -> void:
	girl.visible = false
	for c in girl.get_children():
		c.queue_free()
	girl_sp = preload("res://scripts/spirit.gd").new()
	girl.add_child(girl_sp)
	# призрак, который мелькает в доме (shade) — та же девочка, того же роста
	for c in shade.get_children():
		c.queue_free()
	var sh: Node3D = preload("res://scripts/spirit.gd").new()
	shade.add_child(sh)
	sh.play("idle", 0.4)
	sh.set_blood(0.35)
	_prep_pass_ghost()


func _girl_anim(speed: float) -> void:
	girl_sp.set_speed(speed)


# ---------------- цикл ----------------
func _process(delta: float) -> void:
	time_now += delta
	if msg_timer > 0.0:
		msg_timer -= delta
		if msg_timer < 1.0:
			msg_label.modulate.a = max(0.0, msg_timer)

	# вступление: через пару секунд выбивает свет
	if not lamp_done and time_now > 2.5:
		if time_now < 3.4:
			hall_lamp.light_energy = 1.8 if randf() > 0.4 else 0.0
		else:
			lamp_done = true
			hall_lamp.light_energy = 0.0
			_sfx("bang", -8.0, 0.7)
			_say("LVL_32")
			_set_objective("LVL_33")

	candle_light.light_energy = 0.6 + sin(time_now * 7.0) * 0.08 + randf() * 0.08
	if door1_open and not bulb_dead:
		bulb.light_energy = 0.0 if randf() < 0.05 else 1.0 * randf_range(0.8, 1.0)

	# свечение лампочек повторяет их свет; аварийная лампа иногда мигает
	corr_glow.emission_energy_multiplier = bulb.light_energy * 6.0
	hall_glow.emission_energy_multiplier = hall_lamp.light_energy * 3.0
	var el: SpotLight3D = $ExitLamp
	el.light_energy = (0.0 if randf() < 0.025 else 1.6 * randf_range(0.9, 1.0)) if exit_lamp_on else 0.0
	exit_glow.emission_energy_multiplier = el.light_energy * 4.0

	# случайные звуки дома
	if time_now > next_amb and phase != "end":
		next_amb = time_now + randf_range(10.0, 20.0)
		var r := randf()
		var p: Vector3 = player.global_position + Vector3(randf_range(-6, 6), 1.5, randf_range(-6, 6))
		if r < 0.22:
			_sfx3d("knock", p, -8.0, randf_range(0.9, 1.1))
		elif r < 0.44:
			_sfx3d("creak", p, -8.0, randf_range(0.8, 1.2))
		elif r < 0.56:
			_sfx3d("whisper", p, -10.0)
		elif r < 0.70:
			# кто-то ходит в соседней комнате: 3–4 шага подряд
			for k in randi_range(3, 4):
				get_tree().create_timer(k * 0.55).timeout.connect(func(): _sfx3d("step%d" % (randi() % 4), p + Vector3(k * 0.5, 0, 0), -2.0, 0.85))
		elif r < 0.80:
			_sfx("thunder_far", -6.0, randf_range(0.9, 1.05))
		elif r < 0.88:
			_sfx3d("scratch", p, -8.0, randf_range(0.8, 1.0))
		elif r < 0.95 and phase != "intro":
			_sfx3d("cry", p + Vector3(0, 0, -4), -10.0)
		else:
			_sfx3d("giggle", p, -12.0, randf_range(0.95, 1.1))

	_check_events()
	_check_turn_scare()
	_update_tv(delta)
	_update_guest(delta)
	_update_shade(delta)
	_update_zombie(delta)
	_update_scare(delta)

	if not busy and not note_panel.visible:
		var tg := _target()
		hint_label.text = _hint_text(HINTS.get(tg, extra_hints.get(tg, "")))
	else:
		hint_label.text = ""


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if phase == "end" and e.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
	elif e.physical_keycode == KEY_F10 and not busy and phase != "nursery" and phase != "end":
		jump_chapter(3)
	elif e.physical_keycode == KEY_F11 and not busy and phase != "attic" and phase != "end":
		jump_chapter(4)
	elif e.physical_keycode == KEY_F9 and not busy and phase != "corridor" and phase != "end":
		jump_chapter(2)


## Перейти в начало главы (меню «Главы» и тестовые клавиши F9/F10/F11).
func jump_chapter(n: int) -> void:
	match n:
		2:
			_cheat_corridor()
		3:
			_cheat_corridor()
			exit_unlocked = true
			events["nursery_open"] = true
			events["wait_turn"] = true
			events["turn_done"] = true
			exit_door.rotation.y = 1.6
			phase = "nursery"
			SETTINGS.reach(3)
			player.teleport(Vector3(0, 0.05, -18.9), 0.0)
			_set_objective("LVL_29")
			_say("LVL_34", 2.0)
			inv.add("mb_key", null, false)
			nursery.start_dance()
		4:
			_cheat_corridor()
			events["nursery_open"] = true
			exit_door.rotation.y = 0.0
			_say("LVL_41", 2.0)
			attic.enter()
		5:
			_cheat_corridor()
			events["nursery_open"] = true
			exit_door.rotation.y = 0.0
			floor2.enter_direct()
		6:      # спальня бабушки: стоишь у её двери с ключом Веры
			_cheat_corridor()
			events["nursery_open"] = true
			exit_door.rotation.y = 0.0
			floor2.enter_direct()
			bath.skip_solved()
			inv.add("bedkey", null, false)
			player.teleport(Vector3(-3.4, -3.35, -35.5), PI / 2)
			_set_objective("B_OBJ4")

## Чит для теста: F9 — сразу в коридор со свечами.
func _cheat_corridor() -> void:
	shade.visible = false
	shade_mode = ""
	note_panel.visible = false
	lamp_done = true
	hall_lamp.light_energy = 0.0
	key_node.visible = false
	has_key = true
	hallp.got_shard(false)
	door1_open = true
	door1.rotation.y = 1.6
	servant_door.rotation.y = 1.7
	servant_door2.rotation.y = -1.7
	player.frozen = false
	player.teleport(Vector3(0, 0.05, -6.8), 0.0)
	phase = "corridor"
	SETTINGS.reach(2)
	_set_objective("LVL_20")
	_say("LVL_35", 2.0)


# ---------------- автоснимки для проверки (запуск с аргументом -- shots) ----------------
func _enter_tree() -> void:
	if "shots" in OS.get_cmdline_user_args():
		_shots.call_deferred()
	if "trailer" in OS.get_cmdline_user_args():       # режим трейлера (scripts/trailer.gd)
		var tr := preload("res://scripts/trailer.gd").new()
		tr.L = self
		add_child.call_deferred(tr)


func _shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png("user://%s.png" % n)


func _shots() -> void:
	await get_tree().create_timer(3.5).timeout
	var cams := [
		["a_prihozhaya", Vector3(0, 0.05, 5.3), 0.0, -0.05],
		["b_zal_vhod", Vector3(0.3, 0.05, 0.9), deg_to_rad(15), -0.12],
		["c_zal_tv", Vector3(0.6, 0.05, -1.4), deg_to_rad(55), -0.15],
		["d_zal_servant", Vector3(-0.9, 0.05, -1.6), deg_to_rad(-60), -0.1],
		["e_zal_sever", Vector3(-0.2, 0.05, -1.0), deg_to_rad(5), -0.1],
		["f_koridor", Vector3(0.3, 0.05, -7.0), deg_to_rad(8), -0.05],
	]
	for c in cams:
		player.teleport(c[1], c[2])
		player.head.rotation.x = c[3]
		await get_tree().create_timer(0.6).timeout
		_shot(c[0])
	# финал: дверь открыта, за ней девочка
	player.teleport(Vector3(0, 0.05, -16.3), 0.0)
	exit_door.rotation.y = 1.5
	girl.global_position = Vector3(0, 0, -18.9)
	_face(girl, player.global_position)
	girl.visible = true
	await get_tree().create_timer(0.6).timeout
	_shot("g_final")
	get_tree().quit()
