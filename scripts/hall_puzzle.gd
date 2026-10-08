extends Node
## Загадки зала и коридора.
##
## Зал — «Шоу Гостя»: кресло Гостя стоит отвернувшись. Листаешь каналы — на «его» передаче
## пустое кресло со скрипом поворачивается к экрану (каналы 3, 7 и 5, в любом порядке).
## Когда он «посмотрел» все три — сервант открывается. Задержался на чужом канале — пугалка.
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
var _uv_k := Vector2.ONE
var _turn_t := 0.0
var _tv_mist := 0
var _tv_last := -100.0
var _candle_mist := 0
var _chair_tv := 0.0
var _anya: Node3D
var _anya_seen := 0.0
var _anya_step := 0
var _anya_gone := false        ## скример в осколке уже был
var _anya_alive := false
var _anya_lunge := false
var _corr_hint_t := -1.0


var stash_portrait := 1        ## за каким портретом спрятан ключик от шкатулки (1 Вера, 2 Степан, 3 Аня)
var clock_open := false
var _no_match := 0
var _behind_done := {}


func _ready() -> void:
	_setup_chair()
	_build_mirror_world()
	_build_shard()
	_setup_extras()


## Спички в часах зала, ключик от шкатулки за одним из портретов (подсказка — сажей, только в осколке).
func _setup_extras() -> void:
	stash_portrait = randi_range(1, 3)
	var clock := L.get_node("Clock") as Node3D
	L.targets.append({"id": "h_clock", "pos": clock.global_position + Vector3(0, -0.05, 0.1), "th": 0.35, "dist": 2.3})
	L.extra_hints["h_clock"] = "H_CLOCK"
	for i in 3:
		var p := L.get_node("Portrait%d" % (i + 1)) as Node3D
		L.targets.append({"id": "h_p%d" % (i + 1), "pos": p.global_position + Vector3(0.05, 1.7, 0), "th": 0.28, "dist": 2.0})
		L.extra_hints["h_p%d" % (i + 1)] = "H_PORTRAIT"
	var soot := Label3D.new()
	soot.text = tr("H_SOOT2_%d" % stash_portrait)
	soot.font_size = 64
	soot.pixel_size = 0.0028
	soot.modulate = Color(0.16, 0.02, 0.015, 0.9)
	soot.outline_size = 0
	soot.shaded = true
	soot.layers = MIRROR_LAYER
	soot.position = Vector3(1.06, 1.05, -11.0)
	soot.rotation.y = -PI / 2
	soot.rotation.z = -0.05
	L.add_child(soot)


## Смотрит ли игрок сквозь поднятый осколок примерно на точку p.
func looking_through(p: Vector3, ang := 0.35) -> bool:
	return holding and _raise >= 1.0 and L.player.forward().angle_to(p - L.player.cam.global_position) < ang


## Свечу нечем зажечь, пока нет спичек.
func need_matches() -> bool:
	if L.inv.has("matches"):
		return false
	_no_match += 1
	L._sfx("click", -14.0, 0.5)
	L._say("H_MATCHES_NONE" if _no_match < 2 else "H_MATCHES_HINT", 3.5)
	return true


# ---------------- зал: телепрограмма, часы, будильник ----------------


const CHAIR_AWAY := 1.25          ## на сколько кресло отвёрнуто от телевизора в начале


func _setup_chair() -> void:
	var chair := L.get_node_or_null("Armchair") as Node3D
	if chair:
		_chair_tv = chair.rotation.y
		chair.rotation.y = _chair_tv + CHAIR_AWAY


func target_ok(id: String) -> bool:
	if L.busy:
		return false
	if id == "h_clock":
		return not clock_open
	if id.begins_with("h_p"):
		return L.phase in ["corridor", "nursery"] and not L.inv.has("mb_key") and not _behind_done.has(id) and not L.nursery.solved
	return false


func interact(id: String) -> void:
	if not id.begins_with("h_"):
		return
	if id == "h_clock":
		_open_clock()
	elif id.begins_with("h_p"):
		_look_behind(int(id.right(1)))


## Дверца часов скрипит — на полочке за маятником коробок спичек.
func _open_clock() -> void:
	clock_open = true
	var clock := L.get_node("Clock") as Node3D
	L._sfx3d("creak", clock.global_position, -8.0, 1.7)
	var tw := create_tween()
	tw.tween_property(clock, "rotation:z", 0.04, 0.12)
	tw.tween_property(clock, "rotation:z", 0.0, 0.3)
	await tw.finished
	L._sfx("pickup", -6.0)
	L.inv.add("matches")


## Заглянуть за портрет: там ключик — или портрет «оживает».
func _look_behind(i: int) -> void:
	_behind_done["h_p%d" % i] = true
	var p := L.get_node("Portrait%d" % i) as Node3D
	var fr := p.get_node("Frame") as Node3D
	L.busy = true
	L._sfx3d("creak", fr.global_position, -10.0, 1.5)
	var tw := create_tween()
	tw.tween_method(_tilt.bind(p), 0.0, 0.22, 0.35).set_trans(Tween.TRANS_SINE)
	await tw.finished
	if i == stash_portrait:
		L._sfx("pickup", -6.0)
		L.inv.add("mb_key")
		var back := create_tween()
		back.tween_method(_tilt.bind(p), 0.22, 0.0, 0.4)
	else:
		# не тот: лицо на портрете темнеет кровью, рама бьётся о стену, шёпот у самого уха
		var pic := p.get_node("Picture") as Sprite3D
		pic.modulate = Color(0.4, 0.04, 0.03)
		L._sfx("sting", -6.0, 0.8)
		L._sfx("whisper_harsh", -4.0)
		L.player.flicker = 0.7
		L.player.shake = 0.35
		var bang := create_tween()
		for k in 5:
			bang.tween_method(_tilt.bind(p), randf_range(-0.12, 0.12), randf_range(-0.12, 0.12), 0.06)
		bang.tween_method(_tilt.bind(p), 0.05, randf_range(-0.08, 0.08), 0.1)
		L._sfx3d("knock", fr.global_position, -4.0, 1.6)
		create_tween().tween_property(pic, "modulate", Color.WHITE, 1.8).set_delay(0.6)
		await get_tree().create_timer(0.8).timeout
	L.busy = false


## Сбился порядок: кресло со скрипом отворачивается обратно.
func tv_reset() -> void:
	var chair := L.get_node_or_null("Armchair") as Node3D
	L._sfx3d("creak", Vector3(-0.3, 0.8, -3), -2.0, 0.45)
	if chair:
		create_tween().tween_property(chair, "rotation:y", _chair_tv + CHAIR_AWAY, 0.8).set_trans(Tween.TRANS_SINE)


## Нашли его передачу: кресло поворачивается к экрану на треть.
func tv_found(n: int) -> void:
	var chair := L.get_node_or_null("Armchair") as Node3D
	L._sfx3d("creak", Vector3(-0.3, 0.8, -3), 0.0, 0.55)
	if chair:
		var to := _chair_tv + CHAIR_AWAY * (1.0 - n / 3.0)
		create_tween().tween_property(chair, "rotation:y", to, 1.4).set_trans(Tween.TRANS_SINE)


## Неверный канал: каждый раз что-то новое, и дом всё злее.
func tv_mistake() -> void:
	# не чаще раза в 15 секунд, иначе листание каналов превращается в сплошной шум
	if L.channel == 1 and _tv_mist == 0:   # только что включил — это ещё не ошибка
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _tv_last < 15.0:
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
		# в серванте кто-то стучит изнутри, лампочки фонаря захлёбываются
		for t in [0.0, 0.3, 0.3, 0.5]:
			await get_tree().create_timer(t).timeout
			L._sfx3d("knock", Vector3(2.5, 1.2, -3), 2.0, 1.2)
		L._sfx("whisper", -6.0)
		L.player.flicker = 0.5
	else:
		# дыхание за спиной: призрак стоит сзади, пока не обернёшься
		L._sfx("heartbeat", -6.0)
		L._glance_ghost()
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


func _next_spot() -> void:
	_anya_step += 1
	var spots := [Vector3(-0.55, 0, -9.55), Vector3(0.55, 0, -13.2), Vector3(-0.4, 0, -16.6)]
	_anya.position = spots[_anya_step % spots.size()]
	L._sfx3d("giggle", _anya.position + Vector3(0, 1.2, 0), -10.0)


## В осколке она вдруг оказывается вплотную к лицу — и через миг снова на своём месте.
func _face_pop() -> void:
	_anya_lunge = true
	var cam: Camera3D = L.player.cam
	var fwd: Vector3 = L.player.forward()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var at := cam.global_position + fwd * 0.62
	_anya.global_position = Vector3(at.x, cam.global_position.y - 1.6, at.z)
	_anya.rotation.y = atan2(-fwd.x, -fwd.z)
	_anya.play_from("idle", 1.0, 0.3)
	_anya.set_blood(1.0)
	var face := OmniLight3D.new()
	face.light_color = Color(0.75, 0.82, 1.0)
	face.light_energy = 2.0
	face.omni_range = 1.4
	face.position = Vector3(0, 1.5, 0.45)
	_anya.add_child(face)
	# резко и громко: удар, короткий крик, злой шёпот, тряска, красная вспышка
	L._sfx("sting", 3.0, 0.9)
	L._sfx("scream", -2.0, 1.35)
	L._sfx("whisper_harsh", 0.0)
	L._sfx("heartbeat", -2.0, 1.25)
	L.player.shake = 0.9
	L.red_flash.color.a = 0.3
	create_tween().tween_property(L.red_flash, "color:a", 0.0, 0.8)
	await get_tree().create_timer(0.7).timeout
	face.queue_free()
	L.player.flicker = 0.3
	_anya_seen = 0.0
	_anya_alive = false
	_anya.play("idle", 0.4)
	_anya.set_blood(0.3)
	_next_spot()
	_anya_lunge = false


## Скример: призрак резко прыгает в лицо и пропадает. g — узел spirit.gd.
func ghost_lunge(g: Node3D, after := Callable(), keep_pos := false) -> void:
	var cam: Camera3D = L.player.cam
	var fwd: Vector3 = L.player.forward()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var feet_y: float = cam.global_position.y - 1.52
	g.set_layer(1 | MIRROR_LAYER)          # теперь её видно и без осколка
	g.visible = true
	if not keep_pos:                       # иначе прыгает оттуда, где уже стоит
		var from := cam.global_position + fwd * 1.3
		g.global_position = Vector3(from.x, feet_y, from.z)
	else:
		var d: Vector3 = g.global_position - cam.global_position
		d.y = 0.0
		fwd = d.normalized()
	g.rotation.y = atan2(-fwd.x, -fwd.z)
	g.play_from("reach", 1.2, 1.4)
	g.set_blood(1.0)
	# мертвенный свет на лице — чтобы в темноте её было видно целиком
	var face := OmniLight3D.new()
	face.light_color = Color(0.75, 0.82, 1.0)
	face.light_energy = 1.6
	face.omni_range = 1.6
	face.position = Vector3(0, 1.45, 0.55)
	g.add_child(face)
	L._sfx("scream", 0.0, 1.25)
	L._sfx("sting", 0.0)
	var to := cam.global_position + fwd * 0.38
	create_tween().tween_property(g, "global_position", Vector3(to.x, feet_y + 0.06, to.z), 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	L.player.shake = 1.0
	L.red_flash.color.a = 0.3
	create_tween().tween_property(L.red_flash, "color:a", 0.0, 0.9)
	await get_tree().create_timer(0.75).timeout
	L.player.flicker = 0.7
	g.visible = false
	face.queue_free()
	if after.is_valid():
		after.call()


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
	# «стекло» рендерится в реальном разрешении окна (интерфейс может быть растянут)
	_uv_k = Vector2(DisplayServer.window_get_size()) / sz if DisplayServer.get_name() != "headless" else Vector2.ONE
	_view.size = Vector2i(sz * _uv_k)
	var c := Vector2(sz.x * 0.5, sz.y * 0.52)
	_pts = PackedVector2Array()
	for p in SHAPE:
		_pts.append(c + p * sz.y)


func got_shard(say := true) -> void:
	has_shard = true
	L.inv.add("shard", null, say)
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
		var uvs := PackedVector2Array()
		for q in pts:
			uvs.append(q * _uv_k)
		_poly.uv = uvs
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
	if _anya_lunge:
		return
	# пока в коридоре показывается обычный призрак — Ани в осколке нет (не дублируются)
	_anya.visible = L.events.has("corridor") and not L.shade.visible
	_anya.look_at(Vector3(L.player.global_position.x, 0, L.player.global_position.z), Vector3.UP, true)
	# подсказка, если игрок долго не поднимает осколок
	if _corr_hint_t < 0.0:
		_corr_hint_t = 0.0
	if not _shard_used:
		_corr_hint_t += delta
		if _corr_hint_t > 25.0:
			_corr_hint_t = -1000.0
			L._say("PZ_SHARD_NAG", 4.5)
	# Аня в осколке: пока на неё смотришь — оживает (жуткая поза, кровь), но не подходит.
	# Первый раз, если смотреть долго, — внезапно оказывается прямо у лица (только в стекле).
	# Опустил стекло — она уже в другом месте и снова ждёт в осколке.
	if _anya_lunge or not _anya.visible:
		pass
	elif _raise >= 1.0 and L._sees(_anya.global_position + Vector3(0, 1.2, 0), 0.3, false):
		_anya_seen += delta
		if _anya_seen > 0.6 and not _anya_alive:
			_anya_alive = true
			_anya.play_from("zidle", 0.3, 0.55)
			_anya.set_blood(0.6)
			L._sfx("heartbeat", -8.0)
		if _anya_seen > 2.4 and not _anya_gone:
			_anya_gone = true          # «у лица» — один раз за игру
			_face_pop()
	elif _anya_seen > 0.6 and _raise <= 0.0:
		_anya_seen = 0.0
		_anya_alive = false
		_anya.play("idle", 0.4)
		_anya.set_blood(0.3)
		_next_spot()
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
