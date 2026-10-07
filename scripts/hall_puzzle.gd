extends Node
## Загадки зала и коридора.
##
## Зал — «Шоу Гостя»: в телепрограмме 1977 года шесть часов эфира, Гость смотрел только музыку
## (подсказки на обороте фото), а три вещи в зале остановились на «его» времени:
## наручные часы (19:30), будильник (21:00), настенные часы (22:45).
## Музыка в эти часы идёт на каналах 3 → 7 → 5. За неверный канал — пугалка.
##
## Коридор — осколок зеркала (Q или правая кнопка мыши): в нём видно «отражённый дом».
## Только там на табличках под портретами есть годы, на стене — надпись сажей, а в коридоре стоит Аня.
## Свечи зажигать в порядке ухода: Степан (1991) → Аня (2004) → Вера (2026).
## Пока свечи горят, нельзя поворачиваться к портретам спиной — задуют.

const MIRROR_LAYER := 1 << 10   ## видно только в осколке
const REAL_LAYER := 1 << 11     ## видно только без осколка
const TURN_LIMIT := 3.0         ## сколько секунд можно стоять спиной к горящим свечам

var L: Node
var has_shard := false
var holding := false
var _raise := 0.0               ## 0 — осколок опущен, 1 — поднят
var _shard_used := false
var _view: SubViewport
var _cam2: Camera3D
var _poly: Polygon2D
var _edge: Line2D
var _shine: Polygon2D
var _pts := PackedVector2Array()
var _turn_t := 0.0
var _tv_mist := 0
var _tv_last := -100.0
var _candle_mist := 0
var _anya: Node3D
var _anya_seen := 0.0
var _anya_step := 0
var _corr_hint_t := -1.0


func _ready() -> void:
	_build_props()
	_build_mirror_world()
	_build_shard()


# ---------------- зал: телепрограмма, часы, будильник ----------------
func _build_props() -> void:
	# телепрограмма на чайном столике
	var guide := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.26, 0.004, 0.36)
	guide.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_texture = load("res://textures/tv_guide.png")
	gmat.roughness = 0.95
	guide.material_override = gmat
	guide.position = Vector3(-0.92, 0.934, -4.78)
	guide.rotation.y = -0.35
	L.add_child(guide)

	# наручные часы Гостя на подлокотнике кресла
	var watch := Node3D.new()
	watch.position = Vector3(-0.3, 0.0, -3.0) + WATCH_OFS
	L.add_child(watch)
	var band := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.022, 0.004, 0.17)
	band.mesh = bm
	band.material_override = _mat(Color(0.12, 0.07, 0.04), 0.7)
	watch.add_child(band)
	var face := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.019
	fm.bottom_radius = 0.019
	fm.height = 0.008
	face.mesh = fm
	face.position.y = 0.004
	face.material_override = _mat(Color(0.75, 0.62, 0.35), 0.35, 0.8)
	watch.add_child(face)
	var dial := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.015
	dm.bottom_radius = 0.015
	dm.height = 0.002
	dial.mesh = dm
	dial.position.y = 0.0085
	dial.material_override = _mat(Color(0.85, 0.82, 0.74), 0.6)
	watch.add_child(dial)
	watch.rotation.y = 0.3

	# будильник на столе у телефона: стрелки на девяти
	var alarm := Node3D.new()
	alarm.position = Vector3(1.66, 0.93, -5.42)
	alarm.rotation.y = -0.25
	L.add_child(alarm)
	var metal := _mat(Color(0.45, 0.12, 0.1), 0.4, 0.6)
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.055
	cm.bottom_radius = 0.055
	cm.height = 0.04
	body.mesh = cm
	body.rotation.x = PI / 2
	body.position.y = 0.075
	body.material_override = metal
	alarm.add_child(body)
	var adial := MeshInstance3D.new()
	var adm := CylinderMesh.new()
	adm.top_radius = 0.047
	adm.bottom_radius = 0.047
	adm.height = 0.002
	adial.mesh = adm
	adial.rotation.x = PI / 2
	adial.position = Vector3(0, 0.075, 0.021)
	adial.material_override = _mat(Color(0.86, 0.83, 0.75), 0.7)
	alarm.add_child(adial)
	for s in [-1, 1]:
		var bell := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.022
		sm.height = 0.03
		bell.mesh = sm
		bell.position = Vector3(0.035 * s, 0.13, 0)
		bell.rotation.z = -0.5 * s
		bell.material_override = metal
		alarm.add_child(bell)
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.008, 0.03, 0.008)
		leg.mesh = lm
		leg.position = Vector3(0.03 * s, 0.015, 0)
		leg.rotation.z = 0.4 * s
		leg.material_override = metal
		alarm.add_child(leg)
	# стрелки: часовая на 9, минутная на 12
	var hand_mat := _mat(Color(0.05, 0.05, 0.05), 0.8)
	for h in [[Vector3(0.016, 0.003, 0.002), Vector3(-0.009, 0.075, 0.023)], [Vector3(0.003, 0.03, 0.002), Vector3(0, 0.089, 0.023)]]:
		var hand := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = h[0]
		hand.mesh = hm
		hand.position = h[1]
		hand.material_override = hand_mat
		alarm.add_child(hand)

	# стрелки настенных часов: без четверти одиннадцать
	for h in [[Vector3(0.006, 0.045, 0.003), -PI * 2.0 * (10.75 / 12.0)], [Vector3(0.004, 0.065, 0.003), -PI * 2.0 * 0.75]]:
		var piv := Node3D.new()
		piv.position = CLOCK_C
		piv.rotation.z = h[1]
		L.add_child(piv)
		var hand := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = h[0]
		hand.mesh = hm
		hand.position.y = h[0].y * 0.5
		hand.material_override = hand_mat
		piv.add_child(hand)

	L.targets.append({"id": "h_guide", "pos": guide.global_position, "th": 0.35, "dist": 2.0})
	L.targets.append({"id": "h_watch", "pos": watch.global_position, "th": 0.3, "dist": 1.8})
	L.targets.append({"id": "h_alarm", "pos": alarm.global_position + Vector3(0, 0.08, 0), "th": 0.3, "dist": 2.0})
	L.targets.append({"id": "h_clock", "pos": CLOCK_C, "th": 0.3, "dist": 3.0})
	L.extra_hints["h_guide"] = "PZ_GUIDE_H"
	L.extra_hints["h_watch"] = "PZ_WATCH_H"
	L.extra_hints["h_alarm"] = "PZ_ALARM_H"
	L.extra_hints["h_clock"] = "PZ_CLOCK_H"


const CLOCK_C := Vector3(1.555, 1.932, -5.785)   ## центр циферблата настенных часов
const WATCH_OFS := Vector3(-0.05, 0.62, 0.4)


func _mat(c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func target_ok(id: String) -> bool:
	return id in ["h_guide", "h_watch", "h_alarm", "h_clock"] and L.phase in ["intro", "hall", "key", "door"]


func interact(id: String) -> void:
	match id:
		"h_guide":
			L._show_note("PZ_GUIDE")
		"h_watch":
			L._sfx("pickup", -14.0, 1.4)
			L._say("PZ_WATCH", 4.5)
		"h_alarm":
			L._sfx("clink", -12.0, 1.3)
			L._say("PZ_ALARM", 4.5)
		"h_clock":
			L._say("PZ_CLOCK", 4.0)


## Неверный канал: каждый раз что-то новое, и дом всё злее.
func tv_mistake() -> void:
	# не чаще раза в 8 секунд, иначе листание каналов превращается в сплошной шум
	if L.channel == 1 and _tv_mist == 0:   # только что включил — это ещё не ошибка
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _tv_last < 8.0:
		L._sfx("whisper", -14.0)
		return
	_tv_last = now
	_tv_mist += 1
	var kind := (_tv_mist - 1) % 3
	if kind == 0:
		# взрыв помех: экран вспыхивает, шипение на всю громкость, фонарь мигает
		L.tv_static.volume_db += 12.0
		L.player.flicker = 0.6
		L._sfx("sting", -10.0, 0.8)
		L.dwell = 0.0          # телевизор снова «шипит» помехами полторы секунды
		await get_tree().create_timer(1.4).timeout
		L.tv_static.volume_db -= 12.0
	elif kind == 1:
		# кресло Гостя со скрипом поворачивается к игроку — и так и остаётся
		var chair := L.get_node_or_null("Armchair") as Node3D
		L._sfx3d("creak", Vector3(-0.3, 0.8, -3), 0.0, 0.6)
		L._sfx("whisper", -6.0)
		if chair:
			var to: Vector3 = L.player.global_position - chair.global_position
			var yaw := atan2(to.x, to.z) - PI / 2
			create_tween().tween_property(chair, "rotation:y", lerp_angle(chair.rotation.y, yaw, 0.45), 0.5).set_trans(Tween.TRANS_BACK)
		L.player.shake = 0.25
	else:
		# дыхание за спиной: призрак стоит сзади, пока не обернёшься
		L._sfx("heartbeat", -6.0)
		if not L.shade.visible:
			L._shade_show(L._behind_player(1.1), "behind")
			L._sfx("whisper_harsh", -4.0)


## Неверная свеча: портреты темнеют и трясутся в рамах, со второго раза — висят криво.
func candle_mistake() -> void:
	_candle_mist += 1
	L._sfx("sting", -6.0, 0.7)
	L._sfx("whisper_harsh", -4.0)
	L.player.flicker = 0.9
	L.player.shake = 0.35
	for i in 3:
		var p: Node3D = L.get_node("Portrait%d" % (i + 1))
		var pic := p.get_node("Picture") as Sprite3D
		pic.modulate = Color(0.35, 0.05, 0.04)
		create_tween().tween_property(pic, "modulate", Color.WHITE, 1.6).set_delay(0.4)
		var fr := p.get_node("Frame") as Node3D
		var tw := create_tween()
		for k in 6:
			tw.tween_method(_tilt.bind(p), fr.rotation.x, randf_range(-0.08, 0.08), 0.05)
		var rest := 0.0 if _candle_mist < 2 else randf_range(-0.12, 0.12)
		tw.tween_method(_tilt.bind(p), randf_range(-0.05, 0.05), rest, 0.1)
		L._sfx3d("knock", fr.global_position, -6.0, randf_range(1.4, 1.8))


## Наклон портрета в раме (рамка и картинка вместе).
func _tilt(v: float, p: Node3D) -> void:
	(p.get_node("Frame") as Node3D).rotation.x = v
	(p.get_node("Picture") as Node3D).rotation.z = v


# ---------------- коридор: «отражённый дом» ----------------
func _build_mirror_world() -> void:
	L.player.cam.cull_mask &= ~MIRROR_LAYER
	for i in 3:
		var pl := L.get_node_or_null("Portrait%d/Plaque" % (i + 1)) as Label3D
		if pl == null:
			continue
		pl.layers = REAL_LAYER
		var m := pl.duplicate() as Label3D
		m.name = "PlaqueMirror"
		m.text = tr("LVL_PORTRAIT_%dR" % (i + 1))
		m.layers = MIRROR_LAYER
		m.modulate = Color(0.95, 0.85, 0.75)
		pl.get_parent().add_child(m)
	# надпись сажей на стене напротив портретов
	var soot := Label3D.new()
	soot.text = tr("PZ_SOOT")
	soot.font_size = 80
	soot.pixel_size = 0.003
	soot.modulate = Color(0.16, 0.02, 0.015, 0.9)
	soot.outline_size = 0
	soot.shaded = true
	soot.layers = MIRROR_LAYER
	soot.position = Vector3(1.06, 1.35, -15.2)
	soot.rotation.y = -PI / 2
	soot.rotation.z = 0.06
	L.add_child(soot)
	# Аня: в коридоре её видно только в осколке
	_anya = preload("res://scripts/spirit.gd").new()
	_anya.position = Vector3(-0.55, 0, -9.55)
	L.add_child(_anya)
	_anya.set_layer(MIRROR_LAYER)
	_anya.play("idle", 0.4)
	_anya.set_blood(0.3)
	_anya.visible = false


func _build_shard() -> void:
	_view = SubViewport.new()
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view.msaa_3d = Viewport.MSAA_2X
	add_child(_view)   # мир общий с игрой: тот же дом, но камера видит и «отражённый» слой
	_cam2 = Camera3D.new()
	# то же, что видит игрок (без его собственного тела), плюс «отражённый» слой
	_cam2.cull_mask = (L.player.cam.cull_mask | MIRROR_LAYER) & ~REAL_LAYER
	_view.add_child(_cam2)
	var layer := CanvasLayer.new()
	layer.layer = 0    # под пост-эффектом: зерно и виньетка ложатся и на осколок
	add_child(layer)
	_poly = Polygon2D.new()
	_poly.texture = _view.get_texture()
	_poly.color = Color(0.6, 0.68, 0.78)   # стекло чуть холоднее и темнее: «тот» дом
	_poly.visible = false
	layer.add_child(_poly)
	_shine = Polygon2D.new()
	_shine.color = Color(0.8, 0.9, 1.0, 0.07)
	_shine.visible = false
	layer.add_child(_shine)
	_edge = Line2D.new()
	_edge.width = 2.5
	_edge.default_color = Color(0.75, 0.85, 0.95, 0.75)
	_edge.closed = true
	_edge.visible = false
	layer.add_child(_edge)
	get_viewport().size_changed.connect(_resize)
	_resize()


## Форма осколка: неровный клин в центре экрана (в долях высоты экрана).
const SHAPE := [Vector2(-0.15, -0.31), Vector2(0.03, -0.35), Vector2(0.08, -0.24), Vector2(0.14, -0.2),
	Vector2(0.2, 0.06), Vector2(0.11, 0.33), Vector2(-0.06, 0.37), Vector2(-0.1, 0.25),
	Vector2(-0.18, 0.17), Vector2(-0.22, -0.07)]


func _resize() -> void:
	var sz: Vector2 = get_viewport().get_visible_rect().size
	_view.size = Vector2i(sz)
	var c := Vector2(sz.x * 0.5, sz.y * 0.52)
	_pts = PackedVector2Array()
	for p in SHAPE:
		_pts.append(c + p * sz.y)


func got_shard(say := true) -> void:
	has_shard = true
	if say:
		await get_tree().create_timer(3.8).timeout
		L._say("PZ_SHARD_H", 4.0)


func candles_solved() -> void:
	_anya.visible = false


func _unhandled_input(e: InputEvent) -> void:
	if not has_shard:
		return
	var pressed := -1
	if e is InputEventKey and e.physical_keycode == KEY_Q and not e.echo:
		pressed = 1 if e.pressed else 0
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT:
		pressed = 1 if e.pressed else 0
	if pressed < 0:
		return
	var want: bool = pressed == 1 and not L.player.frozen and L.phase != "end"
	if want and not holding:
		L._sfx("glass", -16.0, 1.6)
	holding = want


func _process(delta: float) -> void:
	if holding and (L.player.frozen or L.busy and L.scare_t >= 0.0):
		holding = false
	_raise = move_toward(_raise, 1.0 if holding else 0.0, delta * 5.0)
	var on := _raise > 0.001
	_poly.visible = on
	_edge.visible = on
	_shine.visible = on
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if on:
		var sz: Vector2 = get_viewport().get_visible_rect().size
		var e := 1.0 - pow(1.0 - _raise, 3.0)
		var off := Vector2(sz.x * 0.08 * (1.0 - e), sz.y * 0.75 * (1.0 - e))
		var pts := PackedVector2Array()
		for p in _pts:
			pts.append(p + off)
		_poly.polygon = pts
		_poly.uv = pts
		_edge.points = pts
		# блик по краю стекла
		_shine.polygon = PackedVector2Array([pts[0], pts[1], pts[2], pts[9]])
		_cam2.global_transform = L.player.cam.global_transform
		_cam2.fov = L.player.cam.fov
		_cam2.h_offset = L.player.cam.h_offset
		_cam2.v_offset = L.player.cam.v_offset
		if _raise >= 1.0 and not _shard_used:
			_shard_used = true
			L._say("PZ_SHARD_1", 3.5)
	_update_corridor(delta)


func _update_corridor(delta: float) -> void:
	if L.phase != "corridor" or L.exit_unlocked:
		_anya.visible = false
		_turn_t = 0.0
		return
	_anya.visible = true
	_anya.look_at(Vector3(L.player.global_position.x, 0, L.player.global_position.z), Vector3.UP, true)
	# подсказка, если игрок долго не поднимает осколок
	if _corr_hint_t < 0.0:
		_corr_hint_t = 0.0
	if not _shard_used:
		_corr_hint_t += delta
		if _corr_hint_t > 25.0:
			_corr_hint_t = -1000.0
			L._say("PZ_SHARD_NAG", 4.5)
	# Аня в осколке: увидел — опусти стекло, и она уже в другом месте
	if _raise >= 1.0 and L._sees(_anya.global_position + Vector3(0, 1.2, 0), 0.25, false):
		_anya_seen += delta
	elif _anya_seen > 0.8 and _raise <= 0.0:
		_anya_seen = 0.0
		_anya_step += 1
		var spots := [Vector3(-0.55, 0, -9.55), Vector3(0.55, 0, -13.2), Vector3(-0.4, 0, -16.6)]
		_anya.position = spots[_anya_step % spots.size()]
		L._sfx3d("giggle", _anya.position + Vector3(0, 1.2, 0), -10.0)
	# горящие свечи нельзя оставлять за спиной
	var lit := false
	var facing := false
	var fwd: Vector3 = L.player.forward()
	fwd.y = 0.0
	for i in 3:
		if not L.candles_lit[i]:
			continue
		lit = true
		var to: Vector3 = (L.get_node("Portrait%d/Candle" % (i + 1)) as Node3D).global_position - L.player.global_position
		to.y = 0.0
		if fwd.angle_to(to) < 1.6:   # чуть больше 90° — уже спиной
			facing = true
	if not lit or facing or L.busy:
		_turn_t = 0.0
		return
	_turn_t += delta
	if _turn_t > TURN_LIMIT:
		_turn_t = 0.0
		for i in 3:
			L._set_candle(i + 1, false)
		L.candle_progress = 0
		L._sfx("whoosh", -6.0, 0.8)
		L._sfx("whisper", -4.0)
		L.player.flicker = 0.5
		L._say("PZ_TURNED", 3.5)
