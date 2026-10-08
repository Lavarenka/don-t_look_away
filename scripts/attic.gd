extends Node
## 4-й уровень: чердак. Девочка коснулась — игрок приходит в себя здесь, среди манекенов и хлама.
## Пока: пробуждение, осмотр, люк в полу заперт снизу → конец демо. Загадку и манекены «оживим» дальше.

var L: Node

## Манекены-люди: позы и голова — костями (без анимаций).
## Пока на манекен не смотришь — его голова поворачивается к тебе, а иногда он меняет позу и место.
## У каждого своя зона, и близко друг к другу они не встают.
const MQ = preload("res://scripts/mannequin.gd")
const POSE_LIST := ["stand", "tilt", "point", "reach", "slump", "twist"]
const ZONES := [Rect2(-3.6, -38.0, 2.9, 7.4), Rect2(0.7, -38.0, 2.9, 7.4), Rect2(-3.2, -40.9, 6.4, 2.6)]   ## x, z, ширина, глубина
const MIN_GAP := 1.8          ## не ближе друг к другу
const MIN_PLAYER := 2.3       ## не ближе к игроку
var men := []                 # {q, cool, stare, zone, pose}
var next_snd := 6.0           ## когда следующий звук чердака
## Жуть без скримеров: каждое событие — один раз, в случайном порядке, когда игрок в подходящем месте.
var events := ["steps", "knock_hatch", "chair", "frame", "closet", "ball", "lamp", "form", "giggle", "chandelier", "crate", "books", "drag", "whisper"]
var next_ev := 12.0
var roof: AudioStreamPlayer


func _setup_men() -> void:
	var start := ["stand", "slump", "tilt"]
	for i in 3:
		var n: Node3D = L.get_node_or_null("Attic/HMan%d" % (i + 1))
		if n == null:
			continue
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.25
		cap.height = 1.75
		cs.shape = cap
		cs.position.y = 0.88
		body.add_child(cs)
		n.add_child(body)
		var q = MQ.new(n)
		q.set_pose(start[i])
		men.append({"q": q, "body": body, "cool": randf_range(6.0, 10.0), "stare": 0.0, "zone": ZONES[i], "pose": start[i]})


## Видит ли игрок точку (в поле зрения камеры).
func _seen(pos: Vector3) -> bool:
	var p = L.player
	return p.forward().angle_to(pos - p.cam.global_position) < 0.95


## Свободно ли место: внутри зоны, далеко от других манекенов и игрока, не в мебели.
func _free_spot(m: Dictionary, pos: Vector3) -> bool:
	var z: Rect2 = m.zone
	if not z.has_point(Vector2(pos.x, pos.z)):
		return false
	var pp: Vector3 = L.player.global_position
	if Vector2(pos.x - pp.x, pos.z - pp.z).length() < MIN_PLAYER:
		return false
	for o in men:
		if o != m:
			var on: Vector3 = o.q.node.global_position
			if Vector2(pos.x - on.x, pos.z - on.z).length() < MIN_GAP:
				return false
	var sh := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.6
	sh.shape = cap
	sh.transform = Transform3D(Basis(), pos + Vector3(0, 0.9, 0))
	sh.exclude = [m.body.get_rid()]
	return L.get_world_3d().direct_space_state.intersect_shape(sh, 1).is_empty()


## Звуки чердака: скрип балок над головой, мыши, шорох простыней, что-то падает вдали.
func _attic_sounds(delta: float) -> void:
	next_snd -= delta
	if next_snd > 0.0:
		return
	next_snd = randf_range(9.0, 18.0)
	var pp: Vector3 = L.player.global_position
	var r := randf()
	if r < 0.35:
		L._sfx3d("beam_creak", Vector3(pp.x + randf_range(-2, 2), 3.6, pp.z + randf_range(-3, 3)), -4.0, randf_range(0.85, 1.1))
	elif r < 0.6:
		var a := randf() * TAU
		L._sfx3d("mouse", pp + Vector3(cos(a), 0, sin(a)) * randf_range(2.5, 5.0) + Vector3(0, 0.1, 0), -6.0, randf_range(0.9, 1.15))
	elif r < 0.85:
		var covers := ["CovMirror", "BSofa", "BChair", "BCloset"]
		var c: Node3D = L.get_node("Attic/" + covers[randi() % covers.size()])
		L._sfx3d("sheet_rustle", c.global_position + Vector3(0, 0.8, 0), -4.0, randf_range(0.8, 1.0))
	else:
		L._sfx3d("attic_thud", Vector3(randf_range(-4, 4), 0.5, randf_range(-42, -30)), -6.0, randf_range(0.8, 1.0))


## Подогнать модель под размер: metadata fit_w (ширина) или fit_h (высота); низ — на пол, центр — в точку узла.
func _fit(h: Node3D) -> void:
	var m: Node3D = h.get_node("Model")
	var inv := h.global_transform.affine_inverse()
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := -lo
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var t: Transform3D = inv * (mi as MeshInstance3D).global_transform
		for v in (mi as MeshInstance3D).mesh.get_faces():
			var w: Vector3 = t * v
			lo = lo.min(w)
			hi = hi.max(w)
	var sz := hi - lo
	var k: float = (h.get_meta("fit_w") / max(sz.x, sz.z)) if h.has_meta("fit_w") else (h.get_meta("fit_h") / sz.y)
	m.scale *= k
	var c := (lo + hi) * 0.5 * k
	m.position = Vector3(-c.x, -lo.y * k, -c.z)


## Краем глаза: предмет либо вне взгляда, либо на самом краю поля зрения.
func _corner(pos: Vector3) -> bool:
	var p = L.player
	return p.forward().angle_to(pos - p.cam.global_position) > 0.5


func _dist(path: String) -> float:
	var n: Node3D = L.get_node(path)
	var pp: Vector3 = L.player.global_position
	return Vector2(n.global_position.x - pp.x, n.global_position.z - pp.z).length()


func _ev_ok(e: String) -> bool:
	match e:
		"knock_hatch": return _dist("Attic/Hatch") > 3.0 and _dist("Attic/Hatch") < 10.0
		"chair": var d := _dist("Attic/BChair"); return d > 2.5 and d < 8.0 and _corner(L.get_node("Attic/BChair").global_position + Vector3(0, 0.5, 0))
		"ball": var d := _dist("Attic/BSofa"); return d > 2.5 and d < 8.0
		"lamp": var d := _dist("Attic/ALamp"); return d > 1.5 and d < 7.0 and _corner(L.get_node("Attic/ALamp").global_position + Vector3(0, -1.0, 0))
		"form":
			for f in ["DressForm1", "DressForm2"]:
				var n: Node3D = L.get_node("Attic/" + f)
				if _dist("Attic/" + f) > 2.5 and _dist("Attic/" + f) < 9.0 and not _seen(n.global_position + Vector3(0, 1.2, 0)):
					return true
			return false
		"frame": return _dist("Attic/FrameGirl") > 2.5 and not _seen(L.get_node("Attic/FrameGirl").global_position + Vector3(0, 0.4, 0))
		"closet": var d := _dist("Attic/BCloset"); return d > 2.0 and d < 8.0
		"chandelier": return _dist("AChandelier") < 6.0
	return true


func _attic_events(delta: float) -> void:
	if board_open:
		return
	next_ev -= delta
	if next_ev > 0.0:
		return
	if events.is_empty():
		events = ["steps", "knock_hatch", "drag", "whisper", "giggle"]
	var ok := events.filter(_ev_ok)
	if ok.is_empty():
		next_ev = 4.0
		return
	var e: String = ok.pick_random()
	events.erase(e)
	next_ev = randf_range(13.0, 24.0)
	_event(e)


func _event(e: String) -> void:
	var p = L.player
	var pp: Vector3 = p.global_position
	var back: Vector3 = -p.forward()
	back.y = 0.0
	back = back.normalized()
	match e:
		"steps":       # кто-то медленно идёт сзади и останавливается совсем рядом
			for i in 6:
				var dpos: Vector3 = L.player.global_position - L.player.forward().normalized() * (5.0 - i * 0.65)
				L._sfx3d("step%d" % (i % 4), Vector3(dpos.x, 0.05, dpos.z), -7.0 + i, randf_range(0.85, 0.95))
				await get_tree().create_timer(0.75 + i * 0.08).timeout
		"knock_hatch": # стук в люк снизу
			var h: Vector3 = L.get_node("Attic/Hatch").global_position
			for t in [0.0, 0.6, 0.6, 1.8, 0.35]:
				await get_tree().create_timer(t).timeout
				L._sfx3d("knock", h, -2.0, randf_range(0.72, 0.8))
		"chair":       # кресло отъехало, пока не смотрел — скрежет по доскам
			var ch: Node3D = L.get_node("Attic/BChair")
			var to: Vector3 = L.player.global_position - ch.global_position
			to.y = 0.0
			L._sfx3d("drag", ch.global_position + Vector3(0, 0.2, 0), -2.0, 0.65)
			var tw := create_tween().set_parallel()
			tw.tween_property(ch, "position", ch.position + to.normalized() * 0.35, 0.7).set_trans(Tween.TRANS_SINE)
			tw.tween_property(ch, "rotation:y", ch.rotation.y + 0.35, 0.7)
		"frame":       # картина падает лицом вниз
			var fr: Node3D = L.get_node("Attic/FrameGirl")
			L._sfx3d("creak", fr.global_position + Vector3(0, 0.5, 0), -12.0, 1.6)
			await get_tree().create_timer(0.4).timeout
			create_tween().tween_property(fr, "rotation:z", -1.5, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			await get_tree().create_timer(0.43).timeout
			L._sfx3d("bang", fr.global_position, -6.0, 0.9)
			L._sfx3d("thump", fr.global_position, 0.0, 1.0)
		"closet":      # в шкафу тихо играет пластинка… обрывается — и изнутри стучат
			var cl: Node3D = L.get_node("Attic/BCloset")
			var cp: Vector3 = cl.global_position + Vector3(0, 1.0, 0.1)
			var ap := AudioStreamPlayer3D.new()
			ap.stream = L._stream("gramophone")
			ap.volume_db = -9.0
			ap.pitch_scale = 0.74
			ap.unit_size = 2.0
			add_child(ap)
			ap.global_position = cp
			ap.play()
			await get_tree().create_timer(5.5).timeout
			ap.stop()
			ap.queue_free()
			L._sfx3d("scratch", cp, -6.0, 0.8)
			await get_tree().create_timer(2.0).timeout
			for t in [0.0, 0.5, 0.5]:
				await get_tree().create_timer(t).timeout
				L._sfx3d("knock", cp, -1.0, 0.9)
		"mirror":      # простыня сползает с зеркала
			if sheet_down:
				return
			sheet_down = true
			var cm: Node3D = L.get_node("Attic/CovMirror")
			L._sfx3d("sheet_rustle", cm.global_position + Vector3(0, 1.2, 0), 0.0, 0.85)
			L._sfx3d("whoosh", cm.global_position + Vector3(0, 1.0, 0), -10.0, 0.7)
			# ткань оседает и сползает вперёд, собираясь в кучу у подножия
			create_tween().tween_method(func(t: float): sheet.mesh = _sheet_mesh(t), 0.0, 1.0, 1.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			mirror_fx.open = true
		"ball":        # из-под дивана выкатывается детский мячик — прямо к тебе
			var b := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.09
			sm.height = 0.18
			b.mesh = sm
			var bm := StandardMaterial3D.new()
			bm.albedo_color = Color(0.45, 0.06, 0.05)
			bm.roughness = 0.6
			b.material_override = bm
			L.get_node("Attic").add_child(b)
			var so: Node3D = L.get_node("Attic/BSofa")
			var start: Vector3 = so.global_position + so.global_basis.z * 0.45 + Vector3(0, 0.09, 0)
			var to: Vector3 = pp - start
			to.y = 0.0
			var end: Vector3 = start + to.normalized() * minf(to.length() - 1.0, 3.0)
			b.global_position = start
			L._sfx3d("squeak", start, -10.0, 1.4)
			L._sfx3d("thump", start, -12.0, 1.6)
			var axis: Vector3 = Vector3.UP.cross(to.normalized())
			var dist: float = start.distance_to(end)
			create_tween().tween_method(func(k: float):
				b.global_position = start.lerp(end, k)
				b.global_basis = Basis(axis, dist * k / 0.09), 0.0, 1.0, 2.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		"lamp":        # голая лампочка на проводе начинает раскачиваться и на миг загорается
			var lp: Node3D = L.get_node("Attic/ALamp")
			var bulb: OmniLight3D = lp.get_node("Glow")
			var bmat: StandardMaterial3D = (lp.get_node("Bulb") as MeshInstance3D).get_surface_override_material(0)
			L._sfx3d("creak", lp.global_position, -8.0, 1.7)
			create_tween().tween_method(func(t: float):
				var a := 0.32 * sin(t * 3.1) * exp(-t * 0.28)
				lp.rotation = Vector3(a, 0.0, a * 0.45), 0.0, 12.0, 12.0)
			await get_tree().create_timer(1.6).timeout
			L._sfx3d("buzz", bulb.global_position, -10.0, 1.0)
			for k in [0.0, 0.08, 0.15, 0.05, 0.5, 0.12]:
				bulb.light_energy = 1.4 if bulb.light_energy == 0.0 else 0.0
				bmat.emission_energy_multiplier = 3.0 if bulb.light_energy > 0.0 else 0.0
				await get_tree().create_timer(k + 0.06).timeout
			bulb.light_energy = 0.0
			bmat.emission_energy_multiplier = 0.0
			L._sfx3d("spark", bulb.global_position, -10.0, 1.2)
		"form":        # старый портновский манекен развернулся к тебе, пока не смотрел
			for f in ["DressForm1", "DressForm2"]:
				var n: Node3D = L.get_node("Attic/" + f)
				if _dist("Attic/" + f) > 2.5 and _dist("Attic/" + f) < 9.0 and not _seen(n.global_position + Vector3(0, 1.2, 0)):
					var d: Vector3 = pp - n.global_position
					n.rotation.y = atan2(d.x, d.z)
					L._sfx3d("creak", n.global_position + Vector3(0, 0.6, 0), -14.0, 0.8)
					break
		"giggle":      # детский смешок из дальнего тёмного угла
			var c := Vector3(-4.3 if pp.x > 0 else 4.3, 0.6, -42.0 if pp.z > -36.0 else -30.0)
			L._sfx3d("giggle", c, -9.0, 0.88)
		"chandelier":  # хрусталь звенит, будто кто-то задел
			var ch: Vector3 = L.get_node("AChandelier").global_position + Vector3(0, 0.4, 0)
			for i in 4:
				L._sfx3d("clink", ch, -8.0, randf_range(1.2, 1.7))
				await get_tree().create_timer(randf_range(0.15, 0.4)).timeout
		"crate":       # ящик рядом дёрнулся, будто изнутри
			var best: Node3D = null
			for i in 8:
				var c: Node3D = L.get_node_or_null("Attic/Crate%d" % i)
				if c and _dist("Attic/Crate%d" % i) > 2.0 and _dist("Attic/Crate%d" % i) < 7.0:
					best = c
					break
			if best == null:
				return
			var r0 := best.rotation
			L._sfx3d("thump", best.global_position, -2.0, 0.7)
			var tw := create_tween()
			tw.tween_property(best, "rotation", r0 + Vector3(0.05, 0.0, -0.06), 0.08)
			tw.tween_property(best, "rotation", r0 + Vector3(-0.03, 0.0, 0.04), 0.1)
			tw.tween_property(best, "rotation", r0, 0.15)
		"books":       # где-то в темноте рухнула стопка книг
			L._sfx3d("books_pile", pp + back * 5.0 + Vector3(0, 0.6, 0), -2.0, 0.9)
		"drag":        # что-то тяжёлое тащат по полу — в темноте за спиной
			var dp: Vector3 = pp + back * 6.0
			for i in 3:
				L._sfx3d("drag", Vector3(dp.x, 0.1, dp.z), -5.0, randf_range(0.7, 0.8))
				await get_tree().create_timer(1.4).timeout
		"whisper":     # шёпот у самого уха
			var side: Vector3 = p.forward().cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
			L._sfx3d("whisper", p.cam.global_position + side * 0.5, -12.0, 0.85)


func _process(delta: float) -> void:
	if L.phase != "attic":
		return
	_update_carry()
	if L.busy:
		return
	_attic_sounds(delta)
	_attic_events(delta)
	# подошёл к зеркалу и смотришь на него — простыня сама сползает
	if not sheet_down:
		var mc: Vector3 = L.get_node("Attic/CovMirror").global_position + Vector3(0, 1.0, 0)
		if _dist("Attic/CovMirror") < 2.8 and _seen(mc):
			mirror_look += delta
			if mirror_look > 0.7:
				_event("mirror")
		else:
			mirror_look = 0.0
	var p = L.player
	var eye: Vector3 = p.cam.global_position
	for m in men:
		var q = m.q
		var n: Node3D = q.node
		var chest := n.global_position + Vector3(0, 1.4, 0)
		var dist := Vector2(n.global_position.x - p.global_position.x, n.global_position.z - p.global_position.z).length()
		var seen := _seen(chest)
		# голова: пока не смотришь — поворачивается к тебе; смотришь — замирает.
		# Но если долго смотреть вблизи при свете — медленно, со скрипом, поворачивает голову прямо на глазах.
		if seen and dist < 3.5 and p.is_light_lit():
			m.stare += delta
		else:
			m.stare = 0.0
		var aim: Vector2 = q.aim_at(eye)
		if not seen and dist < 9.0:
			q.turn_head(aim, 1.4, delta)
		elif m.stare > 3.0:
			if q.turn_head(aim, 0.25, delta) and m.stare < 3.1:
				L._sfx3d("creak", chest + Vector3(0, 0.2, 0), -14.0, 1.7)
		# смена места и позы — только когда на него не смотрят
		m.cool -= delta
		if m.cool > 0.0 or seen or dist < MIN_PLAYER + 0.2:
			continue
		m.cool = randf_range(8.0, 14.0)
		var dir := Vector3(p.global_position.x - n.global_position.x, 0, p.global_position.z - n.global_position.z).normalized()
		var old := n.global_position
		for attempt in 8:
			var step := dir * randf_range(0.6, 1.4) + dir.cross(Vector3.UP) * randf_range(-0.9, 0.9)
			if attempt >= 4:
				step = Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))   # не вышло ближе — просто в сторону
			var target := old + step
			if _free_spot(m, target):
				n.global_position = target
				n.rotation.y = atan2(dir.x, dir.z)
				var pose: String = POSE_LIST[randi() % POSE_LIST.size()]
				if pose == m.pose:
					pose = POSE_LIST[(POSE_LIST.find(pose) + 1) % POSE_LIST.size()]
				m.pose = pose
				q.yaw = 0.0
				q.pitch = 0.0
				q.set_pose(pose)
				if randf() < 0.6:
					L._sfx3d("step%d" % (randi() % 4), old.lerp(target, 0.5), -8.0, 0.8)
				break


# ---------------- загадка «Примерка» ----------------
## Какая вещь на каком манекене (как на фотографии бабушки, слева направо).
const WEAR := {1: "Dress", 2: "Scarf", 3: "Bow", 4: "Shoes"}
const ITEM_KEY := {"Dress": "ITEM_DRESS", "Scarf": "ITEM_SCARF", "Bow": "ITEM_BOW", "Shoes": "ITEM_SHOES"}
var carry := ""              ## что в руках — вещь, выбранная в инвентаре (см. _process)
var trunk_open := false
var dressed := {}
var solved := false
var has_key := false
var board_open := false
var photo_seen := false
const CLOTH_Y := 0.25
var sheet: MeshInstance3D      ## простыня на зеркале
var mirror_fx: Node            ## отражение (mirror.gd)
var sheet_down := false        ## простыня уже сползла
var mirror_look := 0.0         ## сколько секунд игрок смотрит на зеркало вблизи
var cloth: MeshInstance3D      ## скомканное платье в сундуке
var viewer: TextureRect
var origin := {}             ## где лежала вещь — туда она возвращается, если взять другую


func _ready() -> void:
	for n in L.get_node("Attic").get_children():
		if n.has_meta("fit_w") or n.has_meta("fit_h"):
			_fit(n)
	_setup_men()
	var h: Node3D = L.get_node("Attic/Hatch")
	_target("a_hatch", h.global_position + Vector3(0.45, 0.05, 0), 0.45, 2.6, "LVL_38")
	_target("a_trunk", L.get_node("Attic/Trunk1").global_position + Vector3(0, 0.35, 0), 0.45, 2.4, "LVL_42")
	# у модели платья белый материал по умолчанию — под фонарём он «светится». Приглушённая старая ткань:
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.3, 0.28, 0.25)
	dm.roughness = 0.95
	dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in range(1, 5):
		for mi in L.get_node("Attic/PForm%d/Dress" % i).find_children("*", "MeshInstance3D", true, false):
			mi.material_override = dm
	cloth = _make_cloth()
	sheet = MeshInstance3D.new()
	sheet.name = "Sheet"
	sheet.mesh = _sheet_mesh(0.0)
	sheet.material_override = _linen(Color(0.5, 0.48, 0.45), 0.45)
	L.get_node("Attic/CovMirror").add_child(sheet)
	mirror_fx = preload("res://scripts/mirror.gd").new()
	add_child(mirror_fx)
	mirror_fx.setup(L, L.get_node("Attic/CovMirror/Mirror"))
	L.get_node("Attic/Trunk1").add_child(cloth)
	for it in ["Scarf", "Bow", "Shoes"]:
		var n: Node3D = L.get_node("Attic/Item" + it)
		origin[it] = n
		_target("a_take_" + it, n.global_position + Vector3(0, 0.12, 0), 0.4, 2.5, "LVL_44")
	for i in range(1, 5):
		_target("a_form%d" % i, L.get_node("Attic/PForm%d" % i).global_position + Vector3(0, 1.1, 0), 0.4, 2.4, "LVL_48")
	_target("a_photo", L.get_node("Attic/Photo").global_position + Vector3(0, 0.05, 0), 0.45, 2.4, "LVL_62")
	_target("a_board", L.get_node("Attic/Board").global_position + Vector3(0, 0.05, 0), 0.45, 2.6, "LVL_55")
	# окно для фотографии
	viewer = TextureRect.new()
	viewer.texture = load("res://textures/attic_photo.png")
	viewer.set_anchors_preset(Control.PRESET_CENTER)
	viewer.custom_minimum_size = Vector2(700, 530)
	viewer.position = Vector2(-350, -300)
	viewer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	viewer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	viewer.visible = false
	L.hud.add_child(viewer)


## Старый лён (текстура сгенерирована gen_linen.py): tint — оттенок, tile — размер плитки в метрах.
func _linen(tint: Color, tile: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/linen_diff.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load("res://textures/linen_nor.jpg")
	m.normal_scale = 0.35
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness_texture = load("res://textures/linen_rough.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	m.roughness = 1.0
	m.uv1_scale = Vector3(1.0 / tile, 1.0 / tile, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Простыня, наброшенная на зеркало (0.7 × 1.72 м). Сетка оборачивает «скруглённый прямоугольник»:
## сверху натянута и скруглена, книзу расходится складками и ложится волной на пол.
## t = 0 — висит, t = 1 — сползла и лежит кучей перед зеркалом. UV — в метрах.
const SH_A := 0.39       # полуширина
const SH_B := 0.075      # полутолщина
const SH_H := 1.79       # высота
func _sheet_mesh(t: float) -> ArrayMesh:
	var NU := 112
	var NV := 64
	var VT := 0.1                      # доля сетки на верхнюю «крышку»
	var nz := FastNoiseLite.new()
	nz.seed = 21
	nz.frequency = 2.2
	var pts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var per := 0.0
	var prev := Vector2(SH_A, 0)
	var arc := []                      # длина по периметру для UV
	for i in NU + 1:
		var th := TAU * i / NU
		var c := cos(th)
		var sn := sin(th)
		var q := Vector2(SH_A * sign(c) * pow(abs(c), 0.3), SH_B * sign(sn) * pow(abs(sn), 0.3))
		per += q.distance_to(prev)
		prev = q
		arc.append(per)
	var drop := t * t * (3.0 - 2.0 * t)
	for j in NV + 1:
		var v := float(j) / NV
		for i in NU + 1:
			var th := TAU * i / NU
			var c := cos(th)
			var sn := sin(th)
			var q := Vector2(SH_A * sign(c) * pow(abs(c), 0.3), SH_B * sign(sn) * pow(abs(sn), 0.3))
			var n := Vector2(c / SH_A, sn / SH_B).normalized()
			var p: Vector3
			if v < VT:
				var s := v / VT
				var r := sin(s * PI * 0.5)
				p = Vector3(q.x * r, SH_H - 0.07 * (1.0 - cos(s * PI * 0.5)) + 0.012 * (1.0 - r), q.y * r)
			else:
				var s := (v - VT) / (1.0 - VT)
				var y := (SH_H - 0.07) * (1.0 - s)
				var flare := 0.06 * s * s + 0.16 * pow(max(s - 0.86, 0.0) / 0.14, 2.0)
				# складки: вертикальные волны, книзу глубже; немного «диагональных» натяжений сверху
				var amp := 0.01 + 0.07 * s * s
				var w := sin(arc[i] * 26.0 + nz.get_noise_2d(arc[i] * 3.0, y) * 4.0) * 0.6 + sin(arc[i] * 11.0 + 1.3) * 0.4
				var diag := 0.008 * sin((arc[i] * 9.0 - y * 7.0)) * (1.0 - s)
				var off := flare + amp * w + diag
				p = Vector3(q.x + n.x * off, max(y, 0.006 + 0.03 * max(s - 0.92, 0.0) * abs(w)), q.y + n.y * off)
			# сползание: ткань оседает вниз и вперёд, сминаясь
			if drop > 0.0:
				var h := p.y
				var k := 1.0 - drop * 0.93
				var crumple := drop * 0.07 * nz.get_noise_3d(p.x * 4.0, p.y * 4.0, p.z * 4.0)
				var fwd := drop * (0.32 + 0.15 * (1.0 - h / SH_H))
				var spread := 1.0 + drop * 0.5 * (1.0 - h / SH_H)
				p = Vector3(p.x * spread, h * k + 0.02 * drop + crumple, p.z * spread + fwd)
				p.y = max(p.y, 0.008)
			pts.append(p)
			uvs.append(Vector2(arc[i], (SH_H - p.y) if v >= VT else v / VT * 0.5))
	var idx := PackedInt32Array()
	for j in NV:
		for i in NU:
			var a := j * (NU + 1) + i
			idx.append_array([a, a + 1, a + NU + 1, a + 1, a + NU + 2, a + NU + 1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in pts.size():
		st.set_uv(uvs[k])
		st.add_vertex(pts[k])
	for k in idx:
		st.add_index(k)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Скомканное белое платье: сетка с шумом и складками, края заправлены под стенки сундука.
func _make_cloth() -> MeshInstance3D:
	var nz := FastNoiseLite.new()
	nz.seed = 7
	nz.frequency = 6.0
	var W := 0.76
	var D := 0.36
	var NX := 42
	var NZ := 20
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for j in NZ + 1:
		for i in NX + 1:
			var u := float(i) / NX
			var v := float(j) / NZ
			var x := (u - 0.5) * W
			var z := (v - 0.5) * D
			var edge: float = min(min(u, 1.0 - u) * W, min(v, 1.0 - v) * D) / 0.06
			var h := 0.05 + 0.03 * nz.get_noise_2d(x, z)
			h -= 0.022 * abs(nz.get_noise_2d(x * 2.3 + 40.0, z * 2.3))          # заломы ткани
			h += 0.012 * sin(x * 31.0 + z * 14.0 + nz.get_noise_2d(z, x) * 6.0)  # мелкие складки
			h += 0.045 * exp(-pow((x + 0.12) / 0.13, 2.0) - pow((z - 0.03) / 0.08, 2.0))   # ком посередине
			h += 0.03 * exp(-pow((x - 0.2) / 0.08, 2.0) - pow((z + 0.06) / 0.06, 2.0))      # рукав
			h *= clamp(edge, 0.35, 1.0)
			pts.append(Vector3(x, CLOTH_Y + h, z))
	for j in NZ:
		for i in NX:
			var a := j * (NX + 1) + i
			for k in [a, a + 1, a + NX + 1, a + 1, a + NX + 2, a + NX + 1]:
				st.set_uv(Vector2(float(k % (NX + 1)) / NX, float(k / (NX + 1)) / NZ))
				st.add_vertex(pts[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Cloth"
	mi.mesh = st.commit()
	mi.material_override = _linen(Color(0.5, 0.48, 0.45), 0.12)
	mi.position = Vector3(0, 0, 0.0)
	return mi


func _target(id: String, pos: Vector3, th: float, dist: float, hint: String) -> void:
	L.targets.append({"id": id, "pos": pos, "th": th, "dist": dist})
	L.extra_hints[id] = hint


func _unhandled_input(e: InputEvent) -> void:
	if not viewer.visible:
		return
	if (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_E, KEY_ESCAPE]) or (e is InputEventMouseButton and e.pressed):
		viewer.visible = false
		L.player.frozen = false
		get_viewport().set_input_as_handled()


func _show_photo() -> void:
	viewer.visible = true
	L.player.frozen = true
	L._sfx("page", -6.0)
	L._say("LVL_52", 6.0)
	L.inv.add_note("LVL_52")


func target_ok(id: String) -> bool:
	if L.phase != "attic" or L.busy or viewer.visible:
		return false
	if id.begins_with("a_take_"):
		var it := id.trim_prefix("a_take_")
		return (origin[it] as Node3D).visible
	if id.begins_with("a_form"):
		return not dressed.has(int(id.right(1))) and not solved
	if id == "a_board":
		return false                      # ключа больше нет — люк открывается сам
	if id == "a_trunk":
		return not trunk_open or cloth.visible
	return true


## Переход: темнота, звон в ушах, игрок лежит на полу и медленно поднимается.
func enter() -> void:
	var p = L.player
	L.phase = "attic"
	preload("res://scripts/settings.gd").reach(4)
	L.busy = true
	p.frozen = true
	L.fade.color.a = 1.0
	L.girl.visible = false
	L.red_flash.color.a = 0.0
	L.end_box.visible = false
	L.drone.stop()
	L._sfx("tinnitus", -6.0)
	# под крышей туман реже, иначе фонарь «засвечивает» воздух
	var env: Environment = L.get_node("WorldEnvironment").environment
	env.volumetric_fog_density = 0.018
	env.fog_density = 0.02
	var sp: Node3D = L.get_node("AtticSpawn")
	p.teleport(sp.global_position, 0.0)
	p.light_on = false
	await get_tree().create_timer(2.5).timeout
	# дождь барабанит прямо по крыше, жесть на крыше дребезжит от ветра
	if L.amb_layers.has("rain_window"):
		L.amb_layers["rain_window"].volume_db = -7.0
	roof = AudioStreamPlayer.new()
	roof.stream = L._loop_stream("attic_roof")
	roof.volume_db = -14.0
	add_child(roof)
	roof.play()
	L._sfx("heartbeat", -8.0)
	# глаза открываются: камера у самого пола, взгляд в балки
	var h0: float = p.head.position.y
	p.head.position.y = 0.22
	p.head.rotation.x = 0.9
	p.head.rotation.z = 0.5
	create_tween().tween_property(L.fade, "color:a", 0.35, 2.0)
	await get_tree().create_timer(2.2).timeout
	L.fade.color.a = 1.0                                    # моргнул
	await get_tree().create_timer(0.25).timeout
	create_tween().tween_property(L.fade, "color:a", 0.0, 1.5)
	L._say("LVL_37", 3.5)
	await get_tree().create_timer(1.6).timeout
	# поднимается
	var tw := create_tween().set_parallel()
	tw.tween_property(p.head, "position:y", h0, 1.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(p.head, "rotation:x", 0.0, 1.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(p.head, "rotation:z", 0.0, 1.4)
	L._sfx("creak", -10.0, 0.7)
	await tw.finished
	p.light_on = true
	L._sfx("click", -6.0)
	L.drone.play()
	L.drone.volume_db = -10.0
	L._set_objective("LVL_36")
	p.frozen = false
	L.busy = false


func interact(id: String) -> void:
	if not id.begins_with("a_"):
		return
	if id == "a_trunk":
		if not trunk_open:
			trunk_open = true
			var ap: AnimationPlayer = L.get_node("Attic/Trunk1/Model").find_children("*", "AnimationPlayer", true, false)[0]
			ap.play("Armature|A_Open")
			L._sfx3d("creak", cloth.global_position, -6.0, 0.7)
			L.busy = true
			await get_tree().create_timer(1.6).timeout
			L.busy = false
			L.extra_hints["a_trunk"] = "LVL_44"
			L._say("LVL_43", 4.0)
		else:
			_pick("Dress")
	elif id == "a_photo":
		if not photo_seen:
			photo_seen = true
			L.extra_hints["a_photo"] = "LVL_47"
			L._set_objective("LVL_51")
		_show_photo()
	elif id.begins_with("a_take_"):
		_pick(id.trim_prefix("a_take_"))
	elif id.begins_with("a_form"):
		_dress(int(id.right(1)))
	elif id == "a_board":
		_open_board()
	elif id == "a_hatch":
		_hatch()


## Взять вещь — она уходит в инвентарь и сразу становится «в руках» (выбранной).
func _pick(it: String) -> void:
	var tpl: Node3D = L.get_node("Attic/PForm1/Dress") if it == "Dress" else origin[it]
	if not L.inv.add("att_" + it.to_lower(), tpl):
		return
	if it == "Dress":
		cloth.visible = false
	if origin.has(it):
		(origin[it] as Node3D).visible = false
	L._sfx("sheet_rustle" if it != "Shoes" else "pickup", -6.0, 1.1)


func _update_carry() -> void:
	# в руках — вещь, выбранная в инвентаре; подсказка у манекена говорит, что наденем
	var sel: String = L.inv.selected()
	carry = sel.trim_prefix("att_").capitalize() if sel.begins_with("att_") else ""
	for i in range(1, 5):
		L.extra_hints["a_form%d" % i] = ["INV_WEAR", ITEM_KEY[carry]] if carry != "" else "LVL_48"


func _dress(i: int) -> void:
	var form: Node3D = L.get_node("Attic/PForm%d" % i)
	if carry == "":
		var any := false
		for k in ITEM_KEY:
			any = any or L.inv.has("att_" + k.to_lower())
		L._say("INV_PICK" if any else "LVL_50", 3.0)
		return
	if WEAR[i] != carry:
		L._sfx3d("creak", form.global_position + Vector3(0, 1.2, 0), -10.0, 1.4)
		L._say("LVL_49", 3.0)
		return
	var w: Node3D = form.get_node(carry)
	w.visible = true
	if carry == "Dress":
		for mi in form.get_node("Model").find_children("*", "MeshInstance3D", true, false):
			if mi.name.begins_with("Mannequin") or mi.name.begins_with("Text"):
				mi.visible = false
	L._sfx3d("sheet_rustle", form.global_position + Vector3(0, 1.0, 0), -4.0, 0.9)
	dressed[i] = true
	L.inv.remove("att_" + carry.to_lower())
	carry = ""
	if dressed.size() == WEAR.size():
		_finale()


## Все одеты: манекены поворачиваются к тайнику, свет гаснет — и они уже вокруг тебя.
func _finale() -> void:
	solved = true
	L.busy = true
	var p = L.player
	var board: Node3D = L.get_node("Attic/Board")
	await get_tree().create_timer(1.0).timeout
	for i in range(1, 5):
		var f: Node3D = L.get_node("Attic/PForm%d" % i)
		var d := board.global_position - f.global_position
		create_tween().tween_property(f, "rotation:y", atan2(d.x, d.z), 2.2).set_trans(Tween.TRANS_SINE)
		L._sfx3d("creak", f.global_position + Vector3(0, 1.0, 0), -6.0, randf_range(0.6, 0.8))
		await get_tree().create_timer(0.45).timeout
	await get_tree().create_timer(1.8).timeout
	# темнота
	p.frozen = true
	p.light_on = false
	L.drone.stop()
	L._sfx("heartbeat", -4.0)
	await get_tree().create_timer(1.8).timeout
	var pp: Vector3 = p.global_position
	var fw: Vector3 = p.forward()
	var base := atan2(fw.x, fw.z)
	var poses := ["reach", "point", "tilt"]
	var offs := [0.0, 0.85, -0.85]                         # прямо перед лицом и по бокам
	var dists := [0.75, 0.95, 0.95]
	for k in men.size():
		var m: Dictionary = men[k]
		var a: float = base + offs[k]
		var n: Node3D = m.q.node
		n.global_position = Vector3(pp.x + sin(a) * dists[k], 0, pp.z + cos(a) * dists[k])
		var dir := pp - n.global_position
		n.rotation.y = atan2(dir.x, dir.z)
		m.q.yaw = 0.0
		m.q.pitch = 0.0
		m.q.set_pose(poses[k])
		m.cool = 99999.0
		(m.body as StaticBody3D).process_mode = Node.PROCESS_MODE_DISABLED   # не запереть игрока
	# свет — они вплотную
	p.light_on = true
	p.flicker = 0.0
	p.shake = 1.0
	L._sfx("sting", 2.0)
	L._sfx("whisper_harsh", -2.0)
	await get_tree().create_timer(1.4).timeout
	p.flicker = 0.25
	L.drone.play()
	# скрип под полом… и крышка люка сама откидывается
	await get_tree().create_timer(1.2).timeout
	var h: Node3D = L.get_node("Attic/Hatch")
	L._sfx3d("click", h.global_position, -2.0, 0.6)
	await get_tree().create_timer(0.7).timeout
	L._sfx3d("door", h.global_position, -2.0, 0.7)
	create_tween().tween_property(h, "rotation:z", 1.75, 1.6).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(1.0).timeout
	L._sfx3d("whoosh", h.global_position, -8.0, 0.6)
	L._set_objective("LVL_64")
	L.extra_hints["a_hatch"] = "LVL_65"
	p.frozen = false
	L.busy = false


func _open_board() -> void:
	board_open = true
	var b: Node3D = L.get_node("Attic/Board")
	create_tween().tween_property(b.get_node("Plank"), "rotation:x", 1.0, 0.5)
	L._sfx3d("creak", b.global_position, -4.0, 1.3)
	await get_tree().create_timer(0.6).timeout
	has_key = true
	L.inv.add("attic_key")
	(b.get_node("KeyGlint") as OmniLight3D).light_energy = 0.0
	L._sfx("pickup", -6.0)
	L._set_objective("LVL_57")
	L.extra_hints["a_hatch"] = "LVL_58"


func _hatch() -> void:
	var h: Node3D = L.get_node("Attic/Hatch")
	if not solved:
		L._sfx3d("knock", h.global_position, -4.0, 0.9)
		L._say("LVL_39", 3.5)
		return
	if L.busy:
		return
	L.inv.remove("attic_key")
	L.floor2.descend()
