extends Node
## Детская Ани (третья комната).
## Загадка: 5 рисунков Ани, на каждом цифра и цвет мелка. На музыкальной шкатулке
## 5 цветных клавиш — сыграть мелодию в порядке рисунков: жёлтый, красный, синий,
## зелёный, белый. Рисунок №5 лежит под кроватью — там скример.
## Ошибся — шкатулка фальшивит, а одна из игрушек, на которую ты не смотришь,
## поворачивается к тебе. Разгадал — финал демки.

var L: Node
const CODE := [0, 1, 2, 3, 4]
const KEY_NAMES := ["NUR_01", "NUR_02", "NUR_03", "NUR_04", "NUR_05"]
const CAPTIONS := [
	"NUR_06",
	"NUR_07",
	"NUR_08",
	"NUR_09",
	"NUR_10",
]
const NOTE := "NUR_11"

var progress := 0
var solved := false
var seen := {}
var viewer: TextureRect
var bed_scare_done := false
var toys := ["NBear", "NDuck", "NHorse", "NElephant", "NRockChair"]


func _ready() -> void:
	# цели для «E»
	for i in 5:
		var d: Node3D = L.get_node("Drawing%d" % (i + 1))
		L.targets.append({"id": "n_d%d" % (i + 1), "pos": d.global_position, "th": 0.35 if i < 4 else 0.45, "dist": 2.2})
		L.extra_hints["n_d%d" % (i + 1)] = "NUR_12" if i < 4 else "NUR_13"
	var mb: Node3D = L.get_node("MusicBox")
	L.targets.append({"id": "n_box", "pos": mb.global_position + Vector3(0, 0.05, -0.04), "th": 0.18, "dist": 1.8})
	L.extra_hints["n_box"] = "NUR_14"
	for k in 5:
		var key: Node3D = L.get_node("MusicBox/Key%d" % k)
		L.targets.append({"id": "n_k%d" % k, "pos": key.global_position, "th": 0.08, "dist": 1.6})
		L.extra_hints["n_k%d" % k] = ["NUR_15", KEY_NAMES[k]]
	# окно для просмотра рисунков
	viewer = TextureRect.new()
	viewer.set_anchors_preset(Control.PRESET_CENTER)
	viewer.custom_minimum_size = Vector2(640, 480)
	viewer.position = Vector2(-320, -270)
	viewer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	viewer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	viewer.visible = false
	L.hud.add_child(viewer)
	var hint := Label.new()
	hint.text = tr("NUR_16")
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hint.add_theme_constant_override("outline_size", 6)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 490)
	hint.size = Vector2(640, 30)
	viewer.add_child(hint)
	L.get_node("NightLight").light_energy = 0.0


## Рисунок закрывается на E или кнопкой мыши. Ловим ввод сами: пока рисунок
## открыт, игрок «заморожен», и player.gd не передаёт нажатие E дальше.
func _unhandled_input(e: InputEvent) -> void:
	if not viewer.visible:
		return
	var close := false
	if e is InputEventKey and e.pressed and not e.echo and (e.physical_keycode == KEY_E or e.physical_keycode == KEY_ESCAPE):
		close = true
	elif e is InputEventMouseButton and e.pressed:
		close = true
	if close:
		_close_viewer()
		get_viewport().set_input_as_handled()


func _close_viewer() -> void:
	viewer.visible = false
	L.player.frozen = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func target_ok(id: String) -> bool:
	if L.phase != "nursery" or solved or viewer.visible:
		return false
	if id.begins_with("n_k"):
		return seen.has("note")
	return true


# ---------------- танцующий призрак посреди комнаты ----------------
var dancing := false
var dance_t := 0.0
var dance_seen := 0.0
var dance_note := 0.0
var dance_i := 0
const DANCE_TUNE := [0, 2, 4, 2, 0, 1, 3, 1]


## Вошёл в детскую: посреди комнаты под шкатулку танцует девочка.
func start_dance() -> void:
	var g: Node3D = L.girl
	g.global_position = Vector3(0.1, 0, -21.4)
	L._face(g, L.player.global_position)
	g.visible = true
	L._sfx("girl_appear", -4.0)
	L._girl_anim(1.0)
	dancing = true
	dance_t = 0.0
	dance_seen = 0.0
	L.drone.volume_db = -30.0
	L._say("NUR_17", 3.5)


func _update_dance(delta: float) -> void:
	if not dancing:
		return
	dance_t += delta
	var g: Node3D = L.girl
	# кружится на месте, медленно поворачиваясь
	g.rotation.y += delta * 0.9
	# шкатулка сама наигрывает мелодию
	dance_note -= delta
	if dance_note <= 0.0:
		dance_note = 0.55
		_note(DANCE_TUNE[dance_i % DANCE_TUNE.size()], 0.92, -6.0)
		dance_i += 1
	var head: Vector3 = g.global_position + Vector3(0, 1.2, 0)
	var looking: bool = L.haunts._looking(head, 0.35) and L.player.is_light_lit()
	if looking:
		dance_seen += delta
	var d: float = L.haunts._dist(g.global_position)
	if d < 1.8 or dance_seen > 4.0 or dance_t > 25.0:
		_end_dance(d < 1.8)


func _end_dance(close: bool) -> void:
	dancing = false
	var g: Node3D = L.girl
	# замирает, поворачивается к игроку — свет мигает — её нет
	L._girl_anim(0.0)
	L._face(g, L.player.global_position)
	L._sfx("sting", -2.0 if close else -6.0)
	L.player.flicker = 0.45
	await get_tree().create_timer(0.25).timeout
	g.visible = false
	L.drone.volume_db = -8.0
	L._sfx("giggle", -4.0, 1.1)          # тихий детский смешок
	L._say("NUR_18", 3.0)


func _process(delta: float) -> void:
	_update_dance(delta)
	if L.phase == "nursery" and not solved:
		var nl: OmniLight3D = L.get_node("NightLight")
		nl.light_energy = 0.0 if randf() < 0.04 else 0.35 * randf_range(0.85, 1.0)


## Вызывается из level.gd на любое нажатие E, которое не забрали другие.
func interact(id: String) -> void:
	if viewer.visible:
		_close_viewer()
		return
	if not id.begins_with("n_"):
		return
	if id.begins_with("n_d"):
		var i := int(id.right(1)) - 1
		if i == 4 and not bed_scare_done:
			_under_bed()
		else:
			_show(i)
	elif id == "n_box":
		seen["note"] = true
		L._show_note(NOTE)
		L._set_objective("NUR_19")
		L.extra_hints["n_box"] = "NUR_20"
	elif id.begins_with("n_k"):
		_press(int(id.right(1)))


func _show(i: int) -> void:
	seen["d%d" % i] = true
	viewer.texture = L.get_node("Drawing%d" % (i + 1)).texture
	viewer.visible = true
	L.player.frozen = true
	L._sfx("creak", -20.0, 1.8)
	L._say(CAPTIONS[i], 4.0)


# ---------------- шкатулка ----------------
func _press(k: int) -> void:
	var key: Node3D = L.get_node("MusicBox/Key%d" % k)
	var tw := create_tween()
	tw.tween_property(key, "position:y", 0.1, 0.06)
	tw.tween_property(key, "position:y", 0.107, 0.12)
	_note(k)
	if k == CODE[progress]:
		progress += 1
		if progress == CODE.size():
			_solve()
	else:
		progress = 0
		L.busy = true
		await get_tree().create_timer(0.35).timeout
		for n in 5:                                       # фальшивый аккорд
			_note(n, randf_range(0.82, 0.9), -6.0)
		L.player.flicker = 0.5
		_turn_hidden_toy()
		L._say("NUR_21", 2.5)
		await get_tree().create_timer(1.0).timeout
		L.busy = false


func _note(k: int, pitch := 1.0, db := -2.0) -> void:
	var a := AudioStreamPlayer3D.new()
	a.stream = L._stream("mb_note%d" % k)
	a.pitch_scale = pitch
	a.volume_db = db
	L.add_child(a)
	a.global_position = L.get_node("MusicBox").global_position
	a.finished.connect(a.queue_free)
	a.play()


## Игрушка, на которую игрок не смотрит, поворачивается к нему.
func _turn_hidden_toy() -> void:
	var order := toys.duplicate()
	order.shuffle()
	for n in order:
		var toy: Node3D = L.get_node(n)
		if L.haunts._looking(toy.global_position + Vector3(0, 0.3, 0), 0.9):
			continue
		_face(toy)
		L.haunts._once3d("creak", toy.global_position, -10.0, 1.4)
		return


func _face(toy: Node3D) -> void:
	var d: Vector3 = L.player.global_position - toy.global_position
	var yaw := atan2(d.x, d.z)
	if toy.name == "NHorse":
		yaw += PI / 2      # у лошадки «перёд» смотрит вдоль оси X
	toy.rotation.y = yaw


# ---------------- под кроватью ----------------
func _under_bed() -> void:
	bed_scare_done = true
	L.busy = true
	var p = L.player
	p.frozen = true
	var head: Node3D = p.head
	var base_y := head.position.y
	# присел у кровати и заглянул в щель под ней
	var eyes: Node3D = L.get_node("BedEyes")
	var spot := Vector3(0.25, p.global_position.y, -22.55)
	var to := eyes.global_position - (spot + Vector3(0, 0.45, 0))
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var tw := create_tween().set_parallel()
	tw.tween_property(p, "global_position", spot, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(p, "rotation:y", p.rotation.y + wrapf(yaw - p.rotation.y, -PI, PI), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(head, "position:y", 0.45, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(head, "rotation:x", pitch, 0.6)
	await tw.finished
	L._sfx("creak", -16.0, 1.6)
	await get_tree().create_timer(1.0).timeout
	eyes.visible = true
	L._sfx("whisper", 0.0, 1.3)
	L._say("NUR_22", 2.5)
	await get_tree().create_timer(1.3).timeout
	eyes.visible = false
	p.flicker = 0.4
	# встаёт — а она уже стоит прямо перед ним
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(head, "position:y", base_y, 0.45).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(head, "rotation:x", 0.0, 0.45)
	await tw2.finished
	var girl: Node3D = L.girl
	var f: Vector3 = p.forward()
	f.y = 0.0
	girl.global_position = p.global_position + f.normalized() * 0.6
	L._face(girl, p.global_position)
	girl.visible = true
	L._girl_anim(1.2)
	L._sfx("sting", 2.0)
	L._sfx("scream", 0.0, 1.25)
	p.shake = 0.9
	L.red_flash.color.a = 0.5
	create_tween().tween_property(L.red_flash, "color:a", 0.0, 0.8)
	await get_tree().create_timer(0.55).timeout
	girl.visible = false
	L._girl_anim(0.0)
	await get_tree().create_timer(0.6).timeout
	L.busy = false
	p.frozen = false
	_show(4)


# ---------------- разгадано: финал демки ----------------
func _solve() -> void:
	solved = true
	L.busy = true
	var p = L.player
	L._sfx3d("mb_windup", L.get_node("MusicBox").global_position, -2.0)   # шкатулка заводится сама
	await get_tree().create_timer(1.6).timeout
	# шкатулка играет мелодию сама, все игрушки разом поворачиваются к игроку
	for rep in 2:
		for k in CODE:
			_note(k, 1.0 - rep * 0.06, -2.0)
			await get_tree().create_timer(0.5 + rep * 0.15).timeout
		if rep == 0:
			for n in toys:
				_face(L.get_node(n))
			p.flicker = 0.3
			L._sfx("creak", -6.0, 0.8)
			L._say("NUR_23", 3.0)
	await get_tree().create_timer(1.0).timeout
	# свет уходит
	for n in ["MoonNW", "MoonNE", "NursFill"]:
		create_tween().tween_property(L.get_node(n), "light_energy", 0.0, 2.0)
	L.get_node("NightLight").light_energy = 0.0
	L.drone.stop()
	await get_tree().create_timer(1.5).timeout
	L._sfx("whisper", 0.0, 1.2)
	L._say("NUR_24", 3.0)
	await get_tree().create_timer(2.2).timeout
	# она стоит у кровати и считает
	var girl: Node3D = L.girl
	var f: Vector3 = p.forward()
	f.y = 0.0
	girl.global_position = p.global_position + f.normalized() * 2.6
	L._face(girl, p.global_position)
	girl.visible = true
	L._sfx("girl_appear", -2.0)
	_lock_door()
	for word in ["NUR_25", "NUR_26", "NUR_27"]:
		L._sfx("whisper", -4.0, 1.4)
		L._say(word, 1.2)
		p.flicker = 0.35
		await get_tree().create_timer(1.3).timeout
		girl.global_position = girl.global_position.lerp(p.global_position, 0.35)
		L._face(girl, p.global_position)
	p.light_on = false
	girl.visible = false
	await get_tree().create_timer(1.2).timeout
	# она касается: свет вспыхивает — девочка вплотную, крик (без маски — маска была один раз в коридоре)
	p.frozen = true
	f = p.forward()
	f.y = 0.0
	girl.global_position = p.global_position + f.normalized() * 0.55
	L._face(girl, p.global_position)
	girl.global_position.y += 0.4            # приподнята: лицо прямо на уровне глаз
	girl.visible = true
	L._girl_anim(0.0)
	p.light_on = true
	p.flicker = 0.0               # фонарь вспыхивает — она прямо перед лицом
	p.shake = 1.0
	L._sfx("sting", 2.0)
	L._sfx("scream", 0.0, 1.15)
	L.red_flash.color.a = 0.3
	create_tween().tween_property(L.red_flash, "color:a", 0.0, 0.9)
	await get_tree().create_timer(0.9).timeout
	girl.visible = false
	L.fade.color.a = 1.0
	# она забрала тебя к себе — 4-й уровень, чердак
	L.attic.enter()


## Дверь в детскую захлопывается — бежать некуда.
func _lock_door() -> void:
	var p = L.player
	var pos: Vector3 = p.global_position
	if pos.z > -18.05:                       # игрок успел выйти — затянуть обратно в комнату
		p.teleport(Vector3(0.0, 0.05, -19.4), p.rotation.y)
	elif pos.z > -19.0 and pos.x < 0.6:      # стоит там, где проходит полотно двери — шаг вглубь
		p.teleport(Vector3(pos.x, pos.y, -19.2), p.rotation.y)
	var tw := create_tween()
	tw.tween_property(L.exit_door, "rotation:y", 0.0, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	L._sfx3d("knock", L.exit_door.global_position + Vector3(0.43, 1.0, 0), 4.0, 0.8)
	L._sfx3d("door", L.exit_door.global_position, -4.0, 1.3)
	p.shake = 0.4
