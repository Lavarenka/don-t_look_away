extends Node
## ТЕСТ: в начале игры в прихожей стоит Аня v3 и по кругу показывает, что умеет: позы, движения, челюсть и лицо,
## волосы. Включается в level.gd (ANYA_TEST); для релиза — выключить.
## Каждый номер — несколько секунд, подпись внизу слева — что сейчас показывается.
## Клавиши: F7 — следующий номер, F6 — предыдущий, F5 — пауза (повторять текущий), F4 — подсветка вкл/выкл.

const HOME := Vector3(0.0, 0.0, 2.0)          ## где стоит: в прихожей, лицом к входной двери (к тебе)
const RUN_FROM := Vector3(0.0, 0.0, -1.9)     ## откуда бежит: из гостиной, через дверной проём
const PEEK_AT := Vector3(0.74, 0.0, -0.3)     ## за правым косяком двери в гостиную
const JAMB := Vector3(0.5, 1.36, -0.13)       ## запястье — у края косяка (стена — z от −0.1 до 0.1, край — x 0.5): пальцы видны из-за угла
## Убрать передние пряди с лица (корни прядей отводятся в стороны и назад, физика волос тянется следом) —
## в номерах про лицо, иначе его не видно.
const HAIR_PART := {"hair_f1L_0": Vector3(0.6, 0, 0.9), "hair_f1R_0": Vector3(0.6, 0, -0.9),
	"hair_f2L_0": Vector3(0.45, 0, 0.6), "hair_f2R_0": Vector3(0.45, 0, -0.6)}
const WALK_SPEED := 0.9                       ## м/с при анимации шага со скоростью 1
const RUN_SPEED := 4.4

## [раздел, что показывается, длительность (с), функция]
const SEGS := [
	["ПОЗЫ", "Стоит и следит за тобой: голова и глаза поворачиваются, моргает, дышит ртом", 7.0, "_s_idle"],
	["ПОЗЫ", "Голова медленно клонится набок — почти до плеча", 7.0, "_s_tilt"],
	["ПОЗЫ", "Сгорбилась, руки повисли, смотрит исподлобья", 7.0, "_s_hunch"],
	["ПОЗЫ", "Тянет руку к тебе — пальцы скрючены", 7.0, "_s_reach"],
	["ПОЗЫ", "Выглядывает из-за косяка и держится за него рукой (подойди ближе)", 7.5, "_s_peek"],
	["ПОЗЫ", "Парит над полом", 6.0, "_s_float"],
	["ДВИЖЕНИЯ", "Медленно идёт к тебе — и обратно", 10.0, "_s_walk"],
	["ДВИЖЕНИЯ", "Резко отворачивается и поворачивается обратно", 6.0, "_s_turn"],
	["ДВИЖЕНИЯ", "Бежит на тебя и резко замирает", 6.5, "_s_run"],
	["ДВИЖЕНИЯ", "Жутко покачивается", 6.0, "_s_sway"],
	["ДВИЖЕНИЯ", "Рывки головы", 6.0, "_s_jerks"],
	["ЧЕЛЮСТЬ И ЛИЦО", "Моргает: медленно, потом дважды быстро", 5.5, "_s_blink"],
	["ЧЕЛЮСТЬ И ЛИЦО", "Шепчет — губы шевелятся", 5.5, "_s_whisper"],
	["ЧЕЛЮСТЬ И ЛИЦО", "Челюсть медленно отвисает", 6.5, "_s_open"],
	["ЧЕЛЮСТЬ И ЛИЦО", "Челюсть съезжает вбок", 5.5, "_s_jaw_side"],
	["ЧЕЛЮСТЬ И ЛИЦО", "Кривая улыбка", 5.5, "_s_smile"],
	["ЧЕЛЮСТЬ И ЛИЦО", "Оскал", 5.0, "_s_snarl"],
	["ЧЕЛЮСТЬ И ЛИЦО", "Крик: челюсть, брови, зрачки в точку, пальцы-когти, волосы дыбом", 6.0, "_s_scream"],
	["ЧЕЛЮСТЬ И ЛИЦО", "Следит за тобой одними глазами — отойди в сторону", 7.0, "_s_eyes"],
	["ВОЛОСЫ", "Трясёт головой — пряди хлещут", 5.5, "_s_shake"],
	["ВОЛОСЫ", "Сквозняк — волосы сдувает вбок", 6.5, "_s_draft"],
	["ВОЛОСЫ", "Волосы всплывают, будто в воде", 6.0, "_s_lift"],
	["ВОЛОСЫ", "Наклоняется — волосы свисают и закрывают лицо", 8.5, "_s_hang"],
	["ЕЩЁ", "Кровь проступает", 7.0, "_s_blood"],
	["ЕЩЁ", "Полупрозрачная, призрачная", 5.0, "_s_ghost"],
]

var L: Node
var g: Node3D                    ## Аня (spirit.gd)
var bend: SkeletonModifier3D     ## наклон спины (spirit_bend.gd)
var pose: SkeletonModifier3D     ## добавочные повороты костей (menu_pose.gd)
var reach: SkeletonModifier3D    ## правая рука к точке (spirit3_reach.gd)
var label: Label
var lights: Array[Light3D] = []
var idx := -1
var paused := false              ## F5: текущий номер повторяется
var auto := true                 ## false — номера сами не меняются (для проверок)
var _gen := 0                    ## номер «поколения»: прерванный номер не продолжает свои ожидания
var _tws: Array[Tween] = []
var _t := 0.0                    ## секунд с начала номера
var _face_player := true
var _tick := Callable()          ## что номер делает каждый кадр


func setup(level: Node) -> void:
	L = level
	process_priority = 10        # после spirit.gd — то, что номер задаёт лицу, ложится поверх её «живости»
	g = preload("res://scripts/spirit.gd").new()
	L.add_child(g)
	g.global_position = HOME
	if not g.v3:
		push_warning("anya_showcase: показ рассчитан на Аню v3 (spirit.gd: ANYA_V3 = true)")
		_make_label()
		label.text = "Аня v3 выключена (spirit.gd: ANYA_V3 = false) — показ только для новой модели"
		return
	bend = preload("res://scripts/spirit_bend.gd").new()
	bend.chain = [["spine05", 0.3], ["spine04", 0.3], ["spine03", 0.25], ["spine02", 0.15]]
	bend.arm_names = [["upperarm01_L", "lowerarm01_L", "wrist_L"], ["upperarm01_R", "lowerarm01_R", "wrist_R"]]
	bend.amount = 0.0
	g.sk.add_child(bend)
	g.sk.move_child(bend, g.life.get_index())        # до «живости»: взгляд считается по согнутой спине
	pose = preload("res://scripts/menu_pose.gd").new()
	pose.v3 = true
	g.sk.add_child(pose)
	g.sk.move_child(pose, g.face.get_index())
	reach = preload("res://scripts/spirit3_reach.gd").new()
	reach.side = "R"
	g.sk.add_child(reach)
	g.sk.move_child(reach, g.face.get_index())
	_make_lights()
	_make_label()
	go(0)


## Подсветка (только для показа): холодный свет сверху спереди и контровой сзади — в прихожей после начала темно.
func _make_lights() -> void:
	var key := SpotLight3D.new()
	key.light_color = Color(0.86, 0.9, 1.0)
	key.light_energy = 2.4
	key.spot_range = 7.0
	key.spot_angle = 36.0
	key.spot_angle_attenuation = 0.8
	key.shadow_enabled = true
	key.light_volumetric_fog_energy = 0.0
	key.light_bake_mode = Light3D.BAKE_DISABLED
	L.add_child(key)
	key.look_at_from_position(Vector3(0.55, 2.55, 3.9), Vector3(0.0, 1.1, 1.7))
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.55, 0.65, 0.95)
	rim.light_energy = 0.9
	rim.omni_range = 3.0
	rim.light_volumetric_fog_energy = 0.0
	rim.light_bake_mode = Light3D.BAKE_DISABLED
	L.add_child(rim)
	rim.global_position = Vector3(-0.3, 2.1, 0.3)
	lights = [key, rim]


func _make_label() -> void:
	label = Label.new()
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	label.position = Vector2(22, -104)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	L.hud.add_child(label)


func _update_label() -> void:
	var s: Array = SEGS[idx]
	var near := "   — подойди ближе, лицо видно между прядей" if s[0] == "ЧЕЛЮСТЬ И ЛИЦО" else ""
	label.text = "Аня v3 — показ   %d / %d   %s%s%s\n%s\nF7 дальше · F6 назад · F5 пауза · F4 подсветка" % [
		idx + 1, SEGS.size(), s[0], near, "   (пауза — повтор)" if paused else "", s[1]]


func _unhandled_input(e: InputEvent) -> void:
	if g == null or bend == null or not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.physical_keycode:
		KEY_F7:
			go(idx + 1)
		KEY_F6:
			go(idx - 1)
		KEY_F5:
			paused = not paused
			_update_label()
		KEY_F4:
			for l in lights:
				l.visible = not l.visible
		_:
			return
	get_viewport().set_input_as_handled()


## Перейти к номеру i (по кругу).
func go(i: int) -> void:
	idx = posmod(i, SEGS.size())
	_reset()
	_gen += 1
	_t = 0.0
	_update_label()
	call(SEGS[idx][3], _gen)


func _process(delta: float) -> void:
	if g == null or bend == null:
		return
	_t += delta
	if _face_player:
		_turn_to(L.player.global_position, delta * 1.5)
	if _tick.is_valid():
		_tick.call(delta)
	if auto and _t >= float(SEGS[idx][2]):
		go(idx if paused else idx + 1)


## Всё — в исходное: стоит на месте лицом к тебе, без наклонов, крови, подсветки волос и т. п.
func _reset() -> void:
	for tw in _tws:
		if tw and tw.is_valid():
			tw.kill()
	_tws.clear()
	_tick = Callable()
	_face_player = true
	var moved: bool = g.global_position.distance_to(HOME) > 0.3
	g.global_position = HOME
	g.play("idle", 1.0, 0.3)
	g.set_lift(0.0)
	g.set_blood(0.0)
	g.set_ghostly(0.0)
	g.float_h = 0.0
	g.mouth = 0.0
	g.grimace = 0.0
	g.murmur = true
	g.watch = true
	g.watch_head = true
	g.hair_loose = -1.0
	g.set_eyes(0.45)
	g.set_shiver(0.0)
	g.life.life = 1.0
	g.face.extra = {}
	g.face.claw = 0.0
	g.hair_sim.external_force = Vector3.ZERO
	bend.amount = 0.0
	bend.angle = 1.0
	bend.arms = 1.0
	bend.reach_to = Vector3.INF
	pose.target = {}
	pose.speed = 6.0
	reach.weight = 0.0
	if moved:
		_turn_to(L.player.global_position, 1.0)
		g.hair_sim.reset()


func _tw() -> Tween:
	var tw := create_tween()
	_tws.append(tw)
	return tw


## Подождать sec секунд; false — номер уже сменился (дальше не продолжать).
func _wait(sec: float, gen: int) -> bool:
	await get_tree().create_timer(sec, false).timeout
	return gen == _gen and is_instance_valid(g)


func _turn_to(p: Vector3, k: float) -> void:
	var d := p - g.global_position
	d.y = 0.0
	if d.length() < 0.05:
		return
	g.rotation.y = lerp_angle(g.rotation.y, atan2(d.x, d.z), clampf(k, 0.0, 1.0))


func _head() -> Vector3:
	return g.global_position + Vector3(0, 1.55, 0)


func _near() -> bool:
	return L.player.global_position.distance_to(g.global_position) < 14.0


# ======================== ПОЗЫ ========================
func _s_idle(_gen_: int) -> void:
	pass


func _s_tilt(gen: int) -> void:
	pose.speed = 1.1
	pose.target = {"Head": Vector3(0, 0, 1.05)}
	if not await _wait(4.6, gen):
		return
	pose.target = {}


func _s_hunch(gen: int) -> void:
	bend.angle = 0.85
	_tw().tween_property(bend, "amount", 1.0, 1.6).set_trans(Tween.TRANS_SINE)
	if not await _wait(5.2, gen):
		return
	_tw().tween_property(bend, "amount", 0.0, 1.5).set_trans(Tween.TRANS_SINE)


func _s_reach(gen: int) -> void:
	reach.pole = Vector3(0.5, -1.0, -0.3)
	_tick = func(_d: float): reach.target = L.player.cam.global_position - g.global_basis.x * 0.3 + Vector3(0, -0.45, 0)
	var tw := _tw().set_parallel()
	tw.tween_property(reach, "weight", 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(g.face, "claw", 0.85, 1.6)
	if not await _wait(5.0, gen):
		return
	var tb := _tw().set_parallel()
	tb.tween_property(reach, "weight", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	tb.tween_property(g.face, "claw", 0.0, 1.4)


func _s_peek(gen: int) -> void:
	_face_player = false
	g.global_position = PEEK_AT
	var d: Vector3 = L.player.global_position - PEEK_AT
	g.rotation.y = clampf(atan2(d.x, d.z), -0.5, 0.2)
	g.hair_sim.reset()
	pose.speed = 3.0
	pose.target = {"Spine": Vector3(0, 0, 0.18), "Spine1": Vector3(0, 0, 0.14), "Spine2": Vector3(0, 0, 0.1),
		"Neck": Vector3(0, 0, 0.16), "Head": Vector3(0, 0, 0.36)}
	reach.target = JAMB
	reach.pole = Vector3(1.0, -0.3, -0.5)     # локоть — в сторону и назад, за стену
	var tw := _tw().set_parallel()
	tw.tween_property(reach, "weight", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(g.face, "claw", 0.55, 0.8)


func _s_float(gen: int) -> void:
	g.float_h = 0.38
	if not await _wait(4.4, gen):
		return
	g.float_h = 0.0


# ======================== ДВИЖЕНИЯ ========================
func _s_walk(gen: int) -> void:
	_face_player = false
	var pz: float = L.player.global_position.z
	var to := Vector3(HOME.x, 0.0, clampf(pz - 1.3, HOME.z + 0.6, HOME.z + 1.6))
	if not await _walk_to(to, gen):
		return
	g.play("idle", 1.0, 0.4)
	if not await _wait(1.0, gen):
		return
	_tw().tween_property(g, "rotation:y", g.rotation.y + PI, 0.9).set_trans(Tween.TRANS_SINE)
	if not await _wait(0.9, gen):
		return
	if not await _walk_to(HOME, gen):
		return
	g.play("idle", 1.0, 0.4)
	_face_player = true


## Шагом в точку to (лицом по ходу); false — номер сменился.
func _walk_to(to: Vector3, gen: int) -> bool:
	var from: Vector3 = g.global_position
	var dist := from.distance_to(to)
	if dist < 0.05:
		return true
	_tw().tween_property(g, "rotation:y", atan2(to.x - from.x, to.z - from.z), 0.4)
	g.play("walk", 1.0, 0.35)
	var dur := dist / WALK_SPEED
	_tw().tween_property(g, "global_position", to, dur)
	for k in int(dur / 0.55):
		get_tree().create_timer(0.3 + k * 0.55, false).timeout.connect(func():
			if gen == _gen and _near():
				L._sfx3d("step%d" % (randi() % 4), g.global_position, -16.0, 0.9))
	return await _wait(dur, gen)


func _s_turn(gen: int) -> void:
	_face_player = false
	if not await _wait(0.6, gen):
		return
	var y0: float = g.rotation.y
	_tw().tween_property(g, "rotation:y", y0 + PI, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if not await _wait(1.9, gen):
		return
	_tw().tween_property(g, "rotation:y", y0 + TAU, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if not await _wait(0.4, gen):
		return
	g.rotation.y = wrapf(g.rotation.y, -PI, PI)


func _s_run(gen: int) -> void:
	_face_player = false
	g.global_position = RUN_FROM
	g.rotation.y = 0.0
	g.hair_sim.reset()
	g.play("idle", 1.0, 0.0)
	if not await _wait(0.6, gen):
		return
	var pz: float = L.player.global_position.z
	var stop := Vector3(0.0, 0.0, clampf(pz - 1.4, RUN_FROM.z + 1.5, HOME.z + 1.4))
	var dur: float = RUN_FROM.distance_to(stop) / RUN_SPEED
	g.play("run", 1.3, 0.1)
	_tw().tween_property(g, "global_position", stop, dur)
	for k in int(dur / 0.21):
		get_tree().create_timer(0.1 + k * 0.21, false).timeout.connect(func():
			if gen == _gen and _near():
				L._sfx3d("thump", g.global_position, -9.0, randf_range(1.3, 1.5)))
	if not await _wait(dur, gen):
		return
	g.play("idle", 1.0, 0.12)                  # замерла как вкопанная — волосы по инерции летят вперёд
	g.set_shiver(0.5)
	_face_player = true
	if not await _wait(1.2, gen):
		return
	g.set_shiver(0.0)


func _s_sway(_gen_: int) -> void:
	g.play("zidle", 0.9, 0.5)


func _s_jerks(gen: int) -> void:
	for k in 7:
		if not await _wait(0.75, gen):
			return
		g.life._next = 0.0                     # spirit_life.gd: рывок головы прямо сейчас


# ======================== ЧЕЛЮСТЬ И ЛИЦО ========================
## Номера про лицо: передние пряди отведены, чтобы лицо было видно.
func _face_on(extra_pose := {}) -> void:
	var t := HAIR_PART.duplicate()
	t.merge(extra_pose, true)
	pose.speed = 4.0
	pose.target = t


func _s_blink(_gen_: int) -> void:
	_face_on()
	g.murmur = false
	_tick = func(_d: float):
		var t := _t
		var b := 0.0
		if t > 0.6 and t < 1.3:
			b = (t - 0.6) / 0.7                # медленно закрывает
		elif t >= 1.3 and t < 2.2:
			b = 1.0
		elif t >= 2.2 and t < 2.9:
			b = 1.0 - (t - 2.2) / 0.7          # медленно открывает
		for t0 in [3.6, 4.0]:                  # и дважды быстро
			if t >= t0 and t < t0 + 0.06:
				b = (t - t0) / 0.06
			elif t >= t0 + 0.06 and t < t0 + 0.16:
				b = 1.0 - (t - t0 - 0.06) / 0.1
		g.face.blink = clampf(b, 0.0, 1.0)


func _s_whisper(_gen_: int) -> void:
	_face_on()
	g.murmur = false
	if _near():
		L._sfx3d("whisper", _head(), -12.0, 1.0)
	_tick = func(_d: float):
		g.face.murmur = 0.09 + 0.13 * absf(sin(_t * 7.3) * sin(_t * 3.1 + 1.0))


func _s_open(gen: int) -> void:
	_face_on()
	g.murmur = false
	_tw().tween_method(func(v: float): g.face.extra = {"JawDrop": v}, 0.0, 1.15, 2.4).set_trans(Tween.TRANS_SINE)
	if not await _wait(4.0, gen):
		return
	_tw().tween_method(func(v: float): g.face.extra = {"JawDrop": v}, 1.15, 0.0, 1.6).set_trans(Tween.TRANS_SINE)


func _s_jaw_side(_gen_: int) -> void:
	_face_on()
	g.murmur = false
	_tick = func(_d: float):
		var k := smoothstep(0.3, 1.0, _t) * (1.0 - smoothstep(4.4, 5.2, _t))
		var w := sin(_t * 2.4)
		g.face.extra = {"JawDrop": 0.35 * k, "ChinLeft": maxf(w, 0.0) * k, "ChinRight": maxf(-w, 0.0) * k,
			"MouthMoveLeft": maxf(w, 0.0) * 0.6 * k, "MouthMoveRight": maxf(-w, 0.0) * 0.6 * k}


func _s_smile(gen: int) -> void:
	g.murmur = false
	_tw().tween_method(func(v: float): g.face.extra = {"MouthLeftPullUp": v, "LeftCheekUp": 0.7 * v, "MouthRightPullDown": 0.25 * v}, 0.0, 1.0, 1.4)
	_face_on({"Head": Vector3(0, 0, -0.22)})
	if not await _wait(1.6, gen):
		return
	if _near():
		L._sfx3d("giggle", _head(), -6.0, 1.0)
	if not await _wait(2.4, gen):
		return
	_face_on()
	_tw().tween_method(func(v: float): g.face.extra = {"MouthLeftPullUp": v, "LeftCheekUp": 0.7 * v, "MouthRightPullDown": 0.25 * v}, 1.0, 0.0, 1.0)


func _s_snarl(gen: int) -> void:
	_face_on()
	g.murmur = false
	var tw := _tw().set_parallel()
	tw.tween_property(g, "grimace", 1.0, 1.0)
	tw.tween_method(func(v: float): g.face.extra = {"UpperLipUp": v, "UpperLipStretched": 0.4 * v}, 0.0, 0.7, 1.0)
	if not await _wait(3.4, gen):
		return
	var tb := _tw().set_parallel()
	tb.tween_property(g, "grimace", 0.0, 1.2)
	tb.tween_method(func(v: float): g.face.extra = {"UpperLipUp": v, "UpperLipStretched": 0.4 * v}, 0.7, 0.0, 1.2)


func _s_scream(gen: int) -> void:
	_face_on()
	if not await _wait(0.6, gen):
		return
	g.scream(1.6)
	g.set_lift(0.4)
	if _near():
		L._sfx3d("scream", _head(), -8.0, 1.0)
	if not await _wait(2.2, gen):
		return
	_tw().tween_method(func(v: float): g.set_lift(v), 0.4, 0.0, 1.5)


func _s_eyes(_gen_: int) -> void:
	_face_on()
	_face_player = false
	g.watch_head = false
	var d: Vector3 = L.player.global_position - g.global_position
	g.rotation.y = atan2(d.x, d.z)


# ======================== ВОЛОСЫ ========================
func _s_shake(_gen_: int) -> void:
	pose.speed = 22.0
	_tick = func(_d: float):
		var k := smoothstep(0.5, 0.8, _t) * (1.0 - smoothstep(2.6, 2.8, _t))
		pose.target = {"Head": Vector3(0, sin(_t * 15.0) * 0.5 * k, sin(_t * 7.5) * 0.12 * k)} if k > 0.0 else {}


func _s_draft(_gen_: int) -> void:
	_tick = func(_d: float):
		var k := smoothstep(0.4, 1.4, _t) * (1.0 - smoothstep(4.4, 5.4, _t))
		var gust := 0.75 + 0.25 * sin(_t * 5.3) * sin(_t * 1.7 + 0.6)
		g.hair_sim.external_force = Vector3(1.8, 0.15, 0.5) * k * gust


func _s_lift(gen: int) -> void:
	_tw().tween_method(func(v: float): g.set_lift(v), 0.0, 0.55, 1.8).set_trans(Tween.TRANS_SINE)
	if not await _wait(3.4, gen):
		return
	_tw().tween_method(func(v: float): g.set_lift(v), 0.55, 0.0, 1.8).set_trans(Tween.TRANS_SINE)


func _s_hang(gen: int) -> void:
	g.watch = false                           # голова — вместе со спиной, лицом вниз
	bend.angle = 1.3
	bend.arms = 0.7
	_tw().tween_property(bend, "amount", 1.0, 2.0).set_trans(Tween.TRANS_SINE)
	if not await _wait(4.8, gen):
		return
	_tw().tween_property(bend, "amount", 0.0, 2.2).set_trans(Tween.TRANS_SINE)
	if not await _wait(1.4, gen):
		return
	g.watch = true


# ======================== ЕЩЁ ========================
func _s_blood(gen: int) -> void:
	_tw().tween_method(func(v: float): g.set_blood(v), 0.0, 0.9, 3.5)
	if not await _wait(5.6, gen):
		return
	_tw().tween_method(func(v: float): g.set_blood(v), 0.9, 0.0, 1.2)


func _s_ghost(_gen_: int) -> void:
	g.set_ghostly(0.55)
