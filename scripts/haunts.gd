extends Node
## «Живой» дом: предметы двигаются, звонит телефон, играет граммофон, хлопают двери.
##
## Как это работает: событие «взводится», когда игрок в нужном месте и фазе.
## Предмет подаёт тихий звук-приманку (скрип, щелчок, стук), а само событие
## происходит, только когда предмет у игрока ПЕРЕД ГЛАЗАМИ, в луче фонаря.
## Не посмотрел — приманка повторяется. Ушёл из комнаты — событие ждёт следующего раза.
## Призраки и скримеры — в level.gd.

var L: Node                    ## уровень (level.gd)
var done := {}                 ## какие события уже были
var t := 0.0
var last_t := -100.0
const GAP := 7.0               ## минимум секунд между событиями
const RECUE := 7.0             ## через сколько повторить приманку

var EV := []                   ## список событий
var armed: Dictionary = {}     ## событие, которое ждёт взгляда игрока
var armed_t := 0.0
var cues := 0

var tick: AudioStreamPlayer3D
var gram: AudioStreamPlayer3D
var ring: AudioStreamPlayer3D
var phone_state := ""          ## "" → "ringing" → "done"
var phone_t := 0.0
var living_t := 0.0            ## сколько секунд игрок провёл в зале
var last_phase := ""
## «За спиной» в зале (с телевизором): шаги и шёпот Ани прямо сзади. Откатить: BEHIND_HALL = false.
const BEHIND_HALL := true
## Звонок как катсцена: рука берёт трубку, Аня в трубке, потом — за спиной (scripts/phone_call.gd).
## false — прежний короткий звонок.
const PHONE_SCENE := true
var phone_scene: Node
var hall_t := 0.0             ## сколько секунд игрок провёл в зале после граммофона


func _ready() -> void:
	tick = _snd3d("clock_tick", _pos("Clock"), -16.0)
	tick.finished.connect(func(): if not done.has("clock_stop"): tick.play())
	tick.play()
	var shelf := Vector3(2.58, 1.8, -3.0)
	# id, когда взводится, куда смотреть, приманка, действие, угол, дальность, нужен ли фонарь
	EV = [
		_ev("front_knock", func(): return L.lamp_done and _in_hall() and _player().z < 3.2,
			func(): return Vector3(0, 1.1, 5.95), _cue_knock, _front_door_rattle, 0.45, 7.0, false),
		_ev("hall_painting", func(): return done.has("front_knock") and _in_hall(),
			func(): return _pos("HallPainting"), func(): _once3d("creak", _pos("HallPainting"), -6.0, 1.5), _hall_painting, 0.4, 5.0),
		_ev("gramophone", func(): return _in_living() and (L.phase == "intro" or L.phase == "hall") and living_t > 8.0,
			func(): return _pos("Gramophone") + Vector3(0, 0.3, 0), func(): _once3d("click", _pos("Gramophone"), -6.0, 0.7), _gramophone_start, 0.4, 5.0),
		_ev("books", func(): return _in_living() and L.lamp_done and done.has("gramophone"),
			func(): return shelf, func(): _once3d("thump", shelf, -12.0, 1.6), _books_fall, 0.4, 5.0),
		_ev("cup", func(): return _in_living() and done.has("books"),
			func(): return _pos("TeaGlass"), func(): _once3d("clink", _pos("TeaGlass"), -16.0, 1.4), _cup_slide, 0.35, 3.5),
		_ev("armchair", func(): return _in_living() and (L.phase == "key" or L.phase == "door") and done.has("phone") and _dist(_pos("Armchair")) > 1.6,
			func(): return _pos("Armchair") + Vector3(0, 0.6, 0), func(): _once3d("creak", _pos("Armchair"), -8.0, 0.7), _armchair_turn, 0.4, 6.0),
		_ev("tv_self", func(): return _in_living() and L.phase == "door" and not L.tv_on,
			func(): return L.tv_screen.global_position, func(): _once3d("click", L.tv_screen.global_position, -8.0, 0.8), _tv_self, 0.4, 6.0),
		_ev("drawer", func(): return _in_living() and L.phase == "door" and done.has("tv_self"),
			func(): return _pos("Desk/drawer_2"), func(): _once3d("knock", _pos("Desk/drawer_2"), -10.0, 1.8), _drawer_open, 0.4, 5.0),
		_ev("chandelier", func(): return _in_living() and L.phase == "door" and done.has("drawer"),
			func(): return _pos("Chandelier") + Vector3(0, -0.4, 0), func(): _once3d("creak", _pos("Chandelier"), -6.0, 0.6), _chandelier_swing, 0.5, 6.0, false),
		_ev("door_slam", func(): return L.phase == "corridor" and _player().z < -8.0 and L.door1.rotation.y > 1.0,
			func(): return L.door1.get_node("Body").global_position, func(): _once3d("creak", L.door1.get_node("Body").global_position, -4.0, 0.8), _door_slam, 0.45, 9.0),
		_ev("bulb", func(): return L.phase == "corridor" and _player().z < -9.0 and not L.bulb_dead,
			func(): return Vector3(1.1, 2.1, -11), func(): _once3d("buzz", L.bulb.global_position, -8.0), _bulb_pop, 0.55, 6.0, false),
		_ev("bottles", func(): return L.phase == "corridor" and _player().z > -12.6 and _player().z < -9.0,
			func(): return _pos("Bottle0") + Vector3(0, 0.15, 0), func(): _once3d("clink", _pos("Bottle0"), -14.0, 1.3), _bottles, 0.4, 5.0),
		# детская
		_ev("horse_rock", func(): return _in_nursery() and t > 0.0,
			func(): return _pos("NHorse") + Vector3(0, 0.35, 0), func(): _once3d("creak", _pos("NHorse"), -12.0, 1.3), _horse_rock, 0.4, 5.0),
		_ev("duck", func(): return _in_nursery() and done.has("horse_rock"),
			func(): return _pos("NDuck") + Vector3(0, 0.08, 0), func(): _once3d("squeak", _pos("NDuck"), -16.0, 0.9), _duck, 0.35, 4.0),
		_ev("chair_rock", func(): return _in_nursery() and done.has("duck"),
			func(): return _pos("NRockChair") + Vector3(0, 0.6, 0), func(): _once3d("creak", _pos("NRockChair"), -10.0, 0.9), _chair_rock, 0.4, 5.0),
		_ev("bear_fall", func(): return _in_nursery() and done.has("chair_rock"),
			func(): return _pos("NBear") + Vector3(0, 0.1, 0), func(): _once3d("thump", _pos("NBear"), -18.0, 1.6), _bear_fall, 0.35, 5.0),
		_ev("doll_door", func(): return _in_nursery() and done.has("doll_moved") and _player().z < -19.6,
			func(): return _pos("NDoll") + Vector3(0, 0.15, 0), func(): _once3d("creak", Vector3(0, 1.0, -18.0), -6.0, 0.7), _doll_door, 0.4, 7.0),
	]


func _ev(id: String, when: Callable, at: Callable, cue: Callable, act: Callable, ang: float, maxd: float, light := true) -> Dictionary:
	return {"id": id, "when": when, "at": at, "cue": cue, "act": act, "ang": ang, "maxd": maxd, "light": light}


# ---------------- помощники ----------------
func _pos(n: String) -> Vector3:
	return (L.get_node(n) as Node3D).global_position


func _snd3d(n: String, p: Vector3, db := 0.0, pitch := 1.0) -> AudioStreamPlayer3D:
	var a := AudioStreamPlayer3D.new()
	a.stream = L._stream(n)
	a.volume_db = db
	a.pitch_scale = pitch
	a.unit_size = 3.0
	L.add_child(a)
	a.global_position = p
	return a


func _once3d(n: String, p: Vector3, db := 0.0, pitch := 1.0) -> void:
	var a := _snd3d(n, p, db, pitch)
	a.finished.connect(a.queue_free)
	a.play()


func _player() -> Vector3:
	return L.player.global_position


func _dist(p: Vector3) -> float:
	var d: Vector3 = p - _player()
	d.y = 0.0
	return d.length()


func _in_living() -> bool:
	var p := _player()
	return p.z < -0.2 and p.z > -5.9 and abs(p.x) < 2.9


## Смотрит ли игрок в сторону точки (без проверки препятствий).
func _looking(p: Vector3, ang := 0.6) -> bool:
	return L.player.forward().angle_to(p - L.player.cam.global_position) < ang


func _in_nursery() -> bool:
	return L.phase == "nursery" and _player().z < -18.3 and not L.nursery.solved


func _in_hall() -> bool:
	var p := _player()
	return p.z > 0.3 and p.z < 5.9


## Предмет прямо перед глазами: близко к центру экрана, не загорожен стеной
## и (если нужно) освещён фонарём.
func _sees(p: Vector3, ang: float, maxd: float, light: bool) -> bool:
	var cam: Vector3 = L.player.cam.global_position
	var to := p - cam
	if to.length() > maxd or L.player.forward().angle_to(to) > ang:
		return false
	if light and not L.player.is_light_lit():
		return false
	var q := PhysicsRayQueryParameters3D.create(cam, p)
	q.exclude = [L.player.get_rid()]
	var hit: Dictionary = L.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or (hit.position as Vector3).distance_to(p) < 0.8


func _free() -> bool:
	return not L.busy and not L.shade.visible and not L.note_panel.visible


func _wait(sec: float) -> Signal:
	return get_tree().create_timer(sec).timeout


# ---------------- цикл ----------------
func _process(delta: float) -> void:
	t += delta
	if L.phase == "end":
		return
	if _in_living():
		living_t += delta

	# часы бьют три раза, когда берёшь ключ, и замолкают
	if L.phase == "door" and last_phase == "key" and not done.has("clock_stop"):
		_clock_strike()
	# телефон звонит после разгаданного телевизора
	if L.phase == "key" and not done.has("phone") and _free() and t - last_t > GAP:
		_phone_start()
	last_phase = L.phase
	if BEHIND_HALL and not done.has("hall_behind") and done.has("gramophone") and _in_living() and _free() \
			and armed.is_empty() and t - last_t > GAP:
		hall_t += delta
		if hall_t > 8.0:
			_hall_behind()
	_update_gramophone()
	_update_phone(delta)

	if done.has("chair_rock") and not done.has("doll_moved") and _in_nursery() and not L.busy:
		var doll: Node3D = L.get_node("NRockChair/NDoll")
		if not _looking(doll.global_position, 1.0) and _dist(doll.global_position) > 1.5 and _player().z < -19.8:
			done["doll_moved"] = true
			doll.reparent(L, true)
			doll.global_position = Vector3(0.35, 0.0, -18.45)
			var d := _player() - doll.global_position
			doll.rotation = Vector3(0, atan2(d.x, d.z), 0)

	if armed.is_empty():
		if t - last_t < GAP or not _free():
			return
		for e in EV:
			if not done.has(e.id) and e.when.call():
				armed = e
				armed_t = 0.0
				cues = 0
				break
		return

	# событие взведено: ждём, когда игрок посмотрит
	if not armed.when.call() and not done.has(armed.id):
		armed = {}                     # ушёл — подождём следующего раза
		return
	armed_t += delta
	if armed_t >= (0.6 if cues == 0 else RECUE) and cues < 4:
		cues += 1
		armed_t = 0.01
		armed.cue.call()
	if cues > 0 and _free() and _sees(armed.at.call(), armed.ang, armed.maxd, armed.light):
		var e: Dictionary = armed
		armed = {}
		done[e.id] = true
		last_t = t
		e.act.call()


# ---------------- за спиной ----------------
## Детские шаги подкрадываются сзади, у самого уха — шёпот Ани (или смешок, пока нет озвучки).
## Обернулся — никого, только фонарь дрогнул. Не обернулся — дыхание в затылок.
func _hall_behind() -> void:
	done["hall_behind"] = true
	last_t = t
	var fw: Vector3 = L.player.forward()
	fw.y = 0.0
	fw = fw.normalized()
	var back: Vector3 = _player() - fw * 1.1
	back.x = clampf(back.x, -2.6, 2.6)
	back.z = clampf(back.z, -5.6, -0.4)
	back.y = 0.0
	for s in ["step1", "step2", "step0"]:
		_once3d(s, back + fw * 0.4 + Vector3(0, 0.05, 0), -14.0, 1.45)   # лёгкие, детские
		await _wait(0.42)
		back += fw * 0.15
	await _wait(0.6)
	var head := back + Vector3(0, 1.15, 0)
	var vo: AudioStream = preload("res://scripts/settings.gd").voice("HAUNT_10")
	var dur := 2.5
	if vo:
		var a := AudioStreamPlayer3D.new()
		a.stream = vo
		a.volume_db = 3.0
		a.unit_size = 2.0
		L.add_child(a)
		a.global_position = head
		a.finished.connect(a.queue_free)
		a.play()
		dur = vo.get_length()
		L.msg_label.text = tr("HAUNT_10")              # реплика — субтитр без второго, «плоского» голоса
		L.msg_label.modulate.a = 1.0
		L.msg_timer = dur
	else:
		_once3d("giggle", head, -4.0, 1.05)
	_once3d("breath_dark", head, -10.0, 1.15)
	var waited := 0.0
	while waited < dur + 1.5:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if _looking(head, 0.75):
			L.player.flicker = 0.35                       # обернулся — пусто, фонарь дрогнул
			_once3d("whoosh", head, -14.0, 0.8)
			return
	_once3d("breath_dark", _player() + Vector3(0, 1.5, 0) - fw * 0.3, -6.0, 0.95)


# ---------------- приманки и события ----------------
func _cue_knock() -> void:
	for k in 3:
		_once3d("knock", Vector3(0, 1.3, 6.0), 2.0, 0.9)
		await _wait(0.45)


func _front_door_rattle() -> void:
	# дверь прямо на глазах трясётся, будто в неё ломятся
	var leaf: Node3D = L.get_node("FrontDoorWall/small_door")
	var base := leaf.rotation.y
	_once3d("creak", Vector3(0, 1.0, 6.0), 0.0, 1.6)
	for k in 10:
		leaf.rotation.y = base + randf_range(0.015, 0.04) * (1 if k % 2 == 0 else -1)
		if k % 3 == 0:
			_once3d("knock", Vector3(0, 1.3, 6.0), 4.0, randf_range(0.6, 0.8))
		await _wait(0.08)
	leaf.rotation.y = base
	L.player.shake = 0.3
	await _wait(0.5)


func _hall_painting() -> void:
	var pic: Node3D = L.get_node("HallPainting")
	# сначала медленно перекашивается, потом срывается
	var tw := create_tween()
	tw.tween_property(pic, "rotation:z", 0.12, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pic, "rotation:z", 0.3, 0.9).set_trans(Tween.TRANS_SINE)
	await tw.finished
	await _wait(0.3)
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(pic, "global_position:y", 0.5, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw2.tween_property(pic, "rotation:z", 0.08, 0.35)
	await tw2.finished
	_once3d("thump", pic.global_position, 2.0)
	_once3d("glass", pic.global_position, -6.0, 0.8)


func _gramophone_start() -> void:
	# граммофон сам поворачивает рупор к игроку и начинает играть
	var g: Node3D = L.get_node("Gramophone")
	var d := _player() - g.global_position
	create_tween().tween_property(g, "rotation:y", atan2(d.x, d.z), 1.4).set_trans(Tween.TRANS_SINE)
	_once3d("creak", g.global_position, -6.0, 1.8)
	await _wait(1.0)
	gram = _snd3d("gramophone", g.global_position + Vector3(0, 0.4, 0), -3.0)
	gram.finished.connect(func(): if gram: gram.queue_free(); gram = null)
	gram.play()


func _update_gramophone() -> void:
	# подошёл близко — пластинка «плывёт» и обрывается
	if gram and gram.playing and _dist(gram.global_position) < 1.3 and not done.has("gram_stop"):
		done["gram_stop"] = true
		var g := gram
		var gp := g.global_position
		var tw := create_tween()
		tw.tween_property(g, "pitch_scale", 0.35, 1.2)
		await tw.finished
		# пластинка могла доиграть сама, пока «плыла», — тогда плеер уже удалён
		if is_instance_valid(g):
			g.stop()
		_once3d("click", gp, 0.0, 0.6)
		L.player.flicker = 0.3


func _books_fall() -> void:
	# книги по одной выезжают с полки и падают
	for n in ["Servant/Book3", "Servant/Book4", "Servant/Book5"]:
		var b: Node3D = L.get_node(n)
		b.reparent(L, true)
		var out := b.global_position + Vector3(-0.28, 0, 0)
		_once3d("drag", b.global_position, -16.0, 2.4)
		var tw := create_tween()
		tw.tween_property(b, "global_position", out, 0.6).set_trans(Tween.TRANS_SINE)
		await tw.finished
		var to := Vector3(randf_range(1.75, 2.0), 0.03, b.global_position.z + randf_range(-0.2, 0.2))
		var tw2 := create_tween().set_parallel()
		tw2.tween_property(b, "global_position", to, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw2.tween_property(b, "rotation", Vector3(PI / 2, randf_range(-PI, PI), 0), 0.45)
		await tw2.finished
		_once3d("book%d" % (randi() % 2), to, 0.0, randf_range(0.9, 1.1))
		await _wait(0.5)


func _cup_slide() -> void:
	var cup: Node3D = L.get_node("TeaGlass")
	var c := _pos("TeaTable")
	var dir := Vector3(cup.global_position.x - c.x, 0, cup.global_position.z - c.z).normalized()
	_once3d("drag", cup.global_position, -12.0, 2.2)
	var tw := create_tween()
	tw.tween_property(cup, "global_position", cup.global_position + dir * 0.17, 2.2)
	await tw.finished
	await _wait(0.4)
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(cup, "global_position", cup.global_position + dir * 0.3 + Vector3(0, -0.9, 0), 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw2.tween_property(cup, "rotation:x", 2.0, 0.4)
	await tw2.finished
	_once3d("glass", cup.global_position, 0.0)
	cup.visible = false


func _phone_start() -> void:
	done["phone"] = true
	last_t = t
	phone_state = "ringing"
	phone_t = 0.0
	ring = _snd3d("phone_ring", _pos("Phone") + Vector3(0, 0.1, 0), 0.0)
	ring.play()
	if PHONE_SCENE and phone_scene == null:
		phone_scene = preload("res://scripts/phone_call.gd").new()
		add_child(phone_scene)
		phone_scene.prepare(L, L.get_node("Phone"))
		phone_scene.preload_body()
	L.targets.append({"id": "phone", "pos": _pos("Phone") + Vector3(0, 0.08, 0), "th": 0.4, "dist": 2.0})
	L.extra_hints["phone"] = "HAUNT_03"


func _update_phone(delta: float) -> void:
	if phone_state != "ringing":
		return
	phone_t += delta
	if not ring.playing:
		if phone_t < 30.0:
			ring.play()
		else:
			phone_state = "done"
			L.extra_hints.erase("phone")


## Вызывается из level.gd, когда игрок нажал E на «своей» цели.
func interact(id: String) -> void:
	if id == "phone" and phone_state == "ringing":
		phone_state = "done"
		ring.stop()
		L.extra_hints.erase("phone")
		if phone_scene:
			await phone_scene.run()
			return
		L.busy = true
		_once3d("click", _pos("Phone"), -4.0)
		await _wait(0.6)
		# в трубке: треск линии, тяжёлое дыхание, детский шёпот, смешок — и обрыв
		L._sfx("phone_call", 0.0)
		await _wait(3.6)
		L._say("HAUNT_05", 3.4)
		await _wait(3.2)
		L.player.shake = 0.3
		await _wait(1.5)
		L.busy = false


func _armchair_turn() -> void:
	# кресло медленно, со скрипом, поворачивается к игроку
	var ch: Node3D = L.get_node("Armchair")
	var d := _player() - ch.global_position
	var target := atan2(d.x, d.z)
	var diff := wrapf(target - ch.rotation.y, -PI, PI)
	_once3d("creak", ch.global_position + Vector3(0, 0.5, 0), 0.0, 0.6)
	var tw := create_tween()
	tw.tween_property(ch, "rotation:y", ch.rotation.y + diff * 0.3, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.4)
	tw.tween_property(ch, "rotation:y", ch.rotation.y + diff, 1.1).set_trans(Tween.TRANS_SINE)
	await tw.finished
	L.player.flicker = 0.25


func _drawer_open() -> void:
	var dr: Node3D = L.get_node("Desk/drawer_2")
	for k in 2:                             # сначала дёргается изнутри
		create_tween().tween_property(dr, "position:z", dr.position.z + 0.03, 0.06)
		await _wait(0.12)
		create_tween().tween_property(dr, "position:z", dr.position.z - 0.03, 0.06)
		_once3d("knock", dr.global_position, -6.0, 1.6)
		await _wait(0.3)
	_once3d("drawer", dr.global_position, -4.0, 1.0)
	create_tween().tween_property(dr, "position:z", dr.position.z + 0.32, 1.2).set_trans(Tween.TRANS_SINE)


func _chandelier_swing() -> void:
	var ch: Node3D = L.get_node("Chandelier")
	_once3d("creak", ch.global_position, 0.0, 0.6)
	var tw := create_tween()
	for a in [0.18, -0.15, 0.12, -0.08, 0.05, -0.025, 0.0]:
		tw.tween_property(ch, "rotation:z", a, 0.7).set_trans(Tween.TRANS_SINE)
	L.player.flicker = 0.25


func _clock_strike() -> void:
	done["clock_stop"] = true
	tick.stop()
	await _wait(2.0)            # часы просто замолкают (бой убран)


func _tv_self() -> void:
	L._tv_power(true)
	for k in 6:
		L.tv_light.light_energy = randf_range(0.6, 2.0)
		L.tv_label.text = str(randi_range(1, 9))
		await _wait(0.4)
	L.tv_label.text = tr("HAUNT_08")
	L.tv_light.light_energy = 1.5
	await _wait(1.5)
	if L.tv_on:
		L._tv_power(false)


func _door_slam() -> void:
	# дверь на глазах чуть приоткрывается... и захлопывается
	create_tween().tween_property(L.door1, "rotation:y", L.door1.rotation.y + 0.15, 0.6).set_trans(Tween.TRANS_SINE)
	await _wait(0.8)
	create_tween().tween_property(L.door1, "rotation:y", 0.0, 0.2).set_ease(Tween.EASE_IN)
	await _wait(0.2)
	L._sfx("bang", 0.0, 0.8)
	L.player.shake = 0.5
	L.player.flicker = 0.4


func _bulb_pop() -> void:
	L.bulb_dead = true
	for k in 5:
		L.bulb.light_energy = randf_range(0.0, 1.6)
		await _wait(0.07)
	L.bulb.light_energy = 3.5
	await _wait(0.08)
	L.bulb.light_energy = 0.0
	_once3d("glass", L.bulb.global_position, -2.0, 1.3)
	L.player.flicker = 0.5


func _bottles() -> void:
	# бутылки падают по одной, как домино
	for k in 3:
		var b: Node3D = L.get_node("Bottle%d" % k)
		if b.rotation.x > 1.0:
			continue
		var tw := create_tween().set_parallel()
		tw.tween_property(b, "rotation:x", 1.5708, 0.35).set_ease(Tween.EASE_IN)
		tw.tween_property(b, "position:y", 0.04, 0.35)
		await _wait(0.35)
		_once3d("clink", b.global_position, 0.0, randf_range(0.9, 1.2))
		await _wait(0.35)


# ---------------- детская ----------------
func _rock(n: Node3D, axis: String, amp: float, swings: int, per: float) -> void:
	var tw := create_tween()
	var a := amp
	for k in swings:
		tw.tween_property(n, "rotation:" + axis, a, per).set_trans(Tween.TRANS_SINE)
		tw.tween_property(n, "rotation:" + axis, -a * 0.8, per).set_trans(Tween.TRANS_SINE)
		a *= 0.85
	tw.tween_property(n, "rotation:" + axis, 0.0, per).set_trans(Tween.TRANS_SINE)
	for k in swings:
		_once3d("creak", n.global_position, -8.0, randf_range(1.1, 1.4))
		await _wait(per * 2.0)


func _horse_rock() -> void:
	_rock(L.get_node("NHorse"), "z", 0.16, 5, 0.45)


func _chair_rock() -> void:
	_rock(L.get_node("NRockChair"), "x", 0.13, 6, 0.55)


func _duck() -> void:
	var dk: Node3D = L.get_node("NDuck")
	var d := _player() - dk.global_position
	_once3d("squeak", dk.global_position, -2.0)
	var tw := create_tween()
	tw.tween_property(dk, "position:y", 0.06, 0.1)
	tw.parallel().tween_property(dk, "rotation:y", atan2(d.x, d.z), 0.2)
	tw.tween_property(dk, "position:y", 0.0, 0.12)
	await tw.finished
	await _wait(0.6)
	_once3d("squeak", dk.global_position, -6.0, 0.8)


func _bear_fall() -> void:
	var b: Node3D = L.get_node("NBear")
	var tw := create_tween()
	tw.tween_property(b, "rotation:x", 0.35, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.25)
	tw.tween_property(b, "global_position", b.global_position + Vector3(0.75, -0.78, 0.25), 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(b, "rotation:x", 1.5, 0.4)
	await tw.finished
	_once3d("thump", b.global_position, -4.0, 1.5)


func _doll_door() -> void:
	# кукла стоит в дверях; когда её увидел — падает лицом вперёд
	L._sfx("sting", -6.0)
	L.player.flicker = 0.3
	await _wait(0.6)
	var dl: Node3D = L.get_node("NDoll")
	var tw := create_tween()
	tw.tween_property(dl, "rotation:x", 1.45, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	_once3d("thump", dl.global_position, -6.0, 1.7)
