extends Node
## Спальня Веры: фотография повешена (vera_room._on_photo_hung) — скример и «зов».
##  1. Резко вспыхивают все лампы коридора и спальни — мерзко, неровно мигают; сами загораются свечи;
##     картины одна за другой падают со стен (кроме повешенной фотографии).
##  2. Вера на потолке у поворота коридора, как паук (vera_ceiling.gd), и зовёт: «Иди сюда… иди ко мне…».
##  3. Прошёл полпути — её на потолке уже нет: стоит в конце коридора, за углом, и выглядывает.
##  4. Подошёл — снова нет: стоит дальше, в проходе за углом. Подходишь — медленно протягивает руку,
##     в руке шпилька (ею откроется ящик — дальше придумаем). Взял — смеётся и пропадает. Свет — как был.
## Голос — потом (voice/en/VERA_CALL*.ogg подхватятся сами), пока субтитры.

const Y2 := -3.4
const CEIL_XZ := Vector2(-12.5, -35.5)      ## над этой точкой висит на потолке
const HALF_X := -8.9                         ## прошёл полпути до неё (идёшь на запад, к -X)
const PEEK := Vector3(-15.1, Y2, -34.3)      ## за углом в конце коридора — выглядывает
const STAND := Vector3(-15.2, Y2, -31.4)     ## дальше, в проходе за углом
const NEAR_PEEK := 3.0
const NEAR_STAND := 3.2
const CALLS := ["VERA_CALL1", "VERA_CALL2", "VERA_CALL3"]
## где поставить свечи: точки над мебелью (высота — лучом); что не попало на мебель — пропускается
const CANDLE_XZ := [Vector2(-10.4, -35.0), Vector2(-11.8, -35.0), Vector2(-8.0, -36.2), Vector2(-9.2, -33.0),
	Vector2(-11.6, -30.6), Vector2(-7.4, -33.4), Vector2(-15.5, -36.1)]

var L: Node
var R: Node                                  ## vera_room.gd
var stage := 0                               ## 0 потолок, 1 выглядывает, 2 стоит, 3 тянет руку, 4 всё
var spider: Node3D
var vera: Node3D
var pin: Node3D
var _pin_target: Dictionary
var _lights := false
var _saved_path := -1
var _call_t := 1.6
var _call_i := 0
var _lean := 0.0
var candles: Array[OmniLight3D] = []
var _ct := 0.0


func start(level: Node, room: Node) -> void:
	L = level
	R = room
	var p = L.player
	# 1) свет — разом и мерзко
	_saved_path = R.path_i
	R.path_i = -1                            # «свет ведёт» — выключено на время
	_lights = true
	L._sfx("sting", 0.0, 0.8, true)
	L._sfx("buzz", -6.0, 1.0, true)
	p.shake = 0.5
	_light_candles()
	_drop_pictures()
	# 2) Вера на потолке
	var sp: PhysicsDirectSpaceState3D = (L as Node3D).get_world_3d().direct_space_state
	var from := Vector3(CEIL_XZ.x, Y2 + 1.5, CEIL_XZ.y)
	var hit: Dictionary = sp.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 3.0))
	var cp: Vector3 = hit.get("position", Vector3(CEIL_XZ.x, Y2 + 2.5, CEIL_XZ.y))
	spider = preload("res://scripts/vera_ceiling.gd").new()
	L.add_child(spider)
	spider.visible = false
	spider.setup(cp, Vector3.RIGHT, p.cam)          # головой — ко входу, к игроку
	await get_tree().create_timer(0.7).timeout
	spider.visible = true
	p.flicker = 0.12


func _process(delta: float) -> void:
	if L == null:
		return
	if _lights:
		_flicker_lights(delta)
	var p = L.player
	var pp: Vector3 = p.global_position
	match stage:
		0:
			_calls(delta, spider.global_position if spider else pp)
			if pp.x < HALF_X:
				_to_peek()
		1:
			_lean = move_toward(_lean, 1.0, delta * 0.5)
			_place_vera(PEEK, 0.33 * _smooth(_lean))
			_calls(delta, PEEK + Vector3.UP * 1.5)
			if _flat(pp, PEEK) < NEAR_PEEK:
				_to_stand()
		2:
			_calls(delta, STAND + Vector3.UP * 1.5)
			if _flat(pp, STAND) < NEAR_STAND:
				_to_reach()
		3:
			if pin and _pin_target:
				_pin_target["pos"] = pin.global_position
			_call_t -= delta
			if _call_t < 0.0:
				_call_t = 4.0
				L._say("VERA_TAKE", 2.5)
				L._sfx3d("whisper_old", STAND + Vector3.UP * 1.5, -6.0, 0.8, true)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _smooth(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


## Зовёт: каждые несколько секунд — новая фраза, шёпот оттуда, где она.
func _calls(delta: float, at: Vector3) -> void:
	_call_t -= delta
	if _call_t > 0.0:
		return
	_call_t = randf_range(3.2, 4.4)
	L._say(CALLS[_call_i % CALLS.size()], 2.6)
	_call_i += 1
	L._sfx3d("whisper_old", at, -4.0, randf_range(0.75, 0.85), true)


## Все лампы горят, но неровно: дрожат, проседают, иногда на миг гаснут разом.
func _flicker_lights(delta: float) -> void:
	_ct += delta
	var dark := fmod(_ct, 2.3) < 0.07 or randf() < 0.01
	for i in R.B.lamps.size():
		var o := R.B.lamps[i] as OmniLight3D
		var base: float = R._base.get(i, 0.6)
		var f := 0.0 if dark else (randf_range(0.0, 0.3) if randf() < 0.05 else randf_range(0.85, 1.35))
		o.light_energy = base * 1.3 * f
	for c in candles:
		c.light_energy = 0.5 * randf_range(0.8, 1.05) * (0.3 if dark else 1.0)


## Свечи на мебели загораются сами — одна за другой.
func _light_candles() -> void:
	var sp: PhysicsDirectSpaceState3D = (L as Node3D).get_world_3d().direct_space_state
	var k := 0
	for xz in CANDLE_XZ:
		var from := Vector3(xz.x, Y2 + 1.5, xz.y)
		var hit: Dictionary = sp.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.0))
		if hit.is_empty():
			continue
		var h: float = hit.position.y - Y2
		if h < 0.45 or h > 1.3:
			continue
		var c: Node3D = R._glb("res://models/bedroom/vera_candle.glb")
		L.add_child(c)
		c.global_position = hit.position
		c.rotation.y = randf() * TAU
		c.scale = Vector3.ONE * 0.8
		var fl := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.026, 0.06)
		fl.mesh = q
		var fm := ShaderMaterial.new()
		fm.shader = preload("res://shaders/candle_flame.gdshader")
		fl.material_override = fm
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.add_child(fl)
		fl.position = Vector3(0, 0.19, 0)
		fl.visible = false
		var ol := OmniLight3D.new()
		ol.light_color = Color(1.0, 0.66, 0.36)
		ol.omni_range = 2.6
		ol.omni_attenuation = 1.6
		ol.light_energy = 0.0
		c.add_child(ol)
		ol.position = Vector3(0, 0.24, 0)
		candles.append(ol)
		var d := 0.15 + k * 0.22
		get_tree().create_timer(d).timeout.connect(func():
			fl.visible = true
			L._sfx3d("click", c.global_position, -16.0, 1.6, true))
		k += 1


# ---------------------------------------------------------------- картины падают
## Картины — часть цельной модели комнаты (один меш со своим атласом). Разбираем его на «островки»
## (каждая картина в раме — отдельный кусок), висящие на стенах вынимаем в свои узлы и роняем.
func _drop_pictures() -> void:
	var src: MeshInstance3D = null
	var surf := -1
	for mi in R.B.root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture \
					and (mat as BaseMaterial3D).albedo_texture.resource_path.ends_with("_Image_20.png"):
				src = m
				surf = i
	if src == null:
		return
	var mesh := src.mesh
	var arr := mesh.surface_get_arrays(surf)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var X := src.global_transform
	# островки: вершины, связанные треугольниками или совпадающие по месту
	var par := PackedInt32Array()
	par.resize(v.size())
	for i in v.size():
		par[i] = i
	var find := func(x: int) -> int:
		while par[x] != x:
			par[x] = par[par[x]]
			x = par[x]
		return x
	var pos := {}
	for i in v.size():
		var key := Vector3i(roundi(v[i].x * 2000), roundi(v[i].y * 2000), roundi(v[i].z * 2000))
		if pos.has(key):
			var a: int = find.call(i)
			var b: int = find.call(pos[key])
			if a != b:
				par[a] = b
		else:
			pos[key] = i
	for t in range(0, idx.size(), 3):
		for k in [1, 2]:
			var a: int = find.call(idx[t])
			var b: int = find.call(idx[t + k])
			if a != b:
				par[a] = b
	var groups := {}
	for t in range(0, idx.size(), 3):
		var r: int = find.call(idx[t])
		if not groups.has(r):
			groups[r] = PackedInt32Array()
		var g: PackedInt32Array = groups[r]
		g.append(idx[t]); g.append(idx[t + 1]); g.append(idx[t + 2])
		groups[r] = g
	var keep := PackedInt32Array()
	var mat_now := src.get_active_material(surf)
	var sp: PhysicsDirectSpaceState3D = (L as Node3D).get_world_3d().direct_space_state
	var n := 0
	for r in groups:
		var g: PackedInt32Array = groups[r]
		var ab := AABB(X * v[g[0]], Vector3.ZERO)
		for i in g:
			ab = ab.expand(X * v[i])
		var low := ab.position.y - Y2
		# висит на стене: низ рамы выше 0.9 м и тонкая по одной горизонтальной оси
		if low < 0.9 or minf(ab.size.x, ab.size.z) > 0.12 or ab.size.y > 1.6:
			keep.append_array(g)
			continue
		var piece := MeshInstance3D.new()
		var a2 := arr.duplicate()
		a2[Mesh.ARRAY_INDEX] = g
		var pm := ArrayMesh.new()
		pm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
		pm.surface_set_material(0, mat_now)
		piece.mesh = pm
		# ось падения — вдоль стены, низ рамы — точка опоры
		var along_x := ab.size.x >= ab.size.z
		var c := ab.get_center()
		var nrm := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
		var probe: Dictionary = sp.intersect_ray(PhysicsRayQueryParameters3D.create(c, c + nrm * 0.35))
		if not probe.is_empty():
			nrm = -nrm                          # там стена — падает в другую сторону
		var pivot := Node3D.new()
		L.add_child(pivot)
		pivot.global_position = Vector3(c.x, ab.position.y, c.z)
		pivot.add_child(piece)
		piece.global_transform = X
		_fall(pivot, nrm, along_x, ab.position.y - Y2, 0.25 + n * 0.17 + randf() * 0.1)
		n += 1
	var a3 := arr.duplicate()
	a3[Mesh.ARRAY_INDEX] = keep
	var rest := ArrayMesh.new()
	for i in mesh.get_surface_count():
		if i == surf:
			rest.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a3)
		else:
			rest.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(i))
	var overrides := []
	for i in mesh.get_surface_count():
		overrides.append(src.get_active_material(i))
	src.mesh = rest
	for i in rest.get_surface_count():
		src.set_surface_override_material(i, overrides[i])


## Рама срывается: чуть отходит от стены, падает и плашмя хлопается на пол лицом вниз.
func _fall(pv: Node3D, nrm: Vector3, along_x: bool, h: float, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	var axis := Vector3.RIGHT if along_x else Vector3.BACK
	# в какую сторону крутить, чтобы верх рамы ушёл от стены (по nrm)
	var test := Basis(axis, 0.5) * Vector3.UP
	var sgn := 1.0 if test.dot(nrm) > 0.0 else -1.0
	var t := sqrt(2.0 * h / 9.8) * 1.1
	var y0 := pv.global_position.y
	var tw := create_tween().set_parallel()
	tw.tween_property(pv, "global_position", pv.global_position + nrm * 0.12 + Vector3.DOWN * (h - 0.02), t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(pv, "basis", Basis(axis, sgn * (PI / 2 - 0.06)), t * 1.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	L._sfx3d("attic_thud", Vector3(pv.global_position.x, y0 - h, pv.global_position.z), -4.0, randf_range(0.9, 1.25), true)


# ---------------------------------------------------------------- Вера
func _vanish(n: Node3D) -> void:
	if is_instance_valid(n):
		n.queue_free()
	L.player.flicker = 0.15
	L._sfx("whoosh", -10.0, 0.7, true)


func _make_vera() -> void:
	if vera == null:
		vera = preload("res://scripts/vera.gd").new()
		L.add_child(vera)
		vera.play("idle", 0.7)


## Поставить её в точку лицом к игроку и наклонить вбок на lean (рад) — «выглядывает из-за угла».
func _place_vera(at: Vector3, lean: float) -> void:
	var to: Vector3 = L.player.global_position - at
	var yaw := atan2(to.x, to.z)
	var b := Basis(Vector3.UP, yaw)
	# наклон к коридору (на юг, к -Z): ось наклона — «вперёд» Веры
	var fwd := b.z
	var test := Basis(fwd, 0.3) * Vector3.UP
	var sgn := 1.0 if test.z < 0.0 else -1.0
	vera.global_transform = Transform3D(Basis(fwd, sgn * lean) * b, at)


func _to_peek() -> void:
	stage = 1
	_vanish(spider)
	spider = null
	_make_vera()
	_place_vera(PEEK, 0.0)
	_call_t = 0.8


func _to_stand() -> void:
	stage = 2
	vera.visible = false
	L.player.flicker = 0.15
	L._sfx("whoosh", -10.0, 0.7, true)
	await get_tree().create_timer(0.25).timeout
	_place_vera(STAND, 0.0)
	vera.visible = true
	_call_t = 0.6


## Медленно протягивает руку — в руке шпилька.
func _to_reach() -> void:
	stage = 3
	_place_vera(STAND, 0.0)
	vera.pose.speed = 0.6
	vera.reach(true)
	pin = _make_pin()
	var ba := BoneAttachment3D.new()
	ba.bone_name = "mixamorig_LeftHand"
	vera.sk.add_child(ba)
	ba.add_child(pin)
	pin.position = Vector3(0, 0.09, 0.03)
	var glint := OmniLight3D.new()                   # еле заметный блик — чтобы в её руке было что-то видно
	glint.light_color = Color(0.8, 0.85, 1.0)
	glint.light_energy = 0.3
	glint.omni_range = 0.5
	pin.add_child(glint)
	_call_t = 1.2
	await get_tree().create_timer(1.5).timeout
	R._target("v_pin", pin.global_position, "BR_PIN", 0.4, 2.2)
	for t in L.targets:
		if t.get("id") == "v_pin":
			_pin_target = t


## Шпилька Веры: тонкая тёмная проволока, согнутая пополам (будет отмычкой).
func _make_pin() -> Node3D:
	var n := Node3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.11, 0.1)
	m.metallic = 0.85
	m.roughness = 0.35
	for s in [-1.0, 1.0]:
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0018
		cm.bottom_radius = 0.0018
		cm.height = 0.09
		cm.radial_segments = 6
		c.mesh = cm
		c.material_override = m
		n.add_child(c)
		c.position = Vector3(s * 0.003, 0.0, 0)
		c.rotation.z = s * 0.06
	var tip := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.002
	tm.outer_radius = 0.0045
	tip.mesh = tm
	tip.material_override = m
	n.add_child(tip)
	tip.position = Vector3(0, 0.045, 0)
	tip.rotation.x = PI / 2
	return n


## Взял шпильку — смеётся и пропадает, свет — как был.
func take_pin() -> void:
	if stage != 3:
		return
	stage = 4
	L.inv.add("v_hairpin", pin)
	pin.visible = false
	L.targets.erase(_pin_target)
	L._sfx("pickup", -6.0, 1.2, true)
	L._sfx3d("phone_laugh", STAND + Vector3.UP * 1.5, 0.0, 0.8, true)
	await get_tree().create_timer(0.6).timeout
	_vanish(vera)
	vera = null
	_lights = false
	R.path_i = _saved_path
	for i in R.B.lamps.size():
		var o := R.B.lamps[i] as OmniLight3D
		o.light_energy = R._base.get(i, 0.6) if i == R.NIGHT_LAMP else 0.0
	L._set_objective("BR_OBJ_PIN")
