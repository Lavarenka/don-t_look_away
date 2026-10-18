extends Node
## Грязь на стенах и полу: подтёки сырости, высохшие пятна, плесень по углам.
## Расставляются сами: по сетке над всем домом лучами ищутся полы под потолком (значит, внутри),
## от них — стены рядом. Сид постоянный — у всех игроков одинаково, и от запуска к запуску тоже.

const STEP := 1.4              ## шаг сетки, м
const MAX := 150               ## всего декалей на дом
const MIN_GAP := 1.6           ## не ближе друг к другу
const P_WALL := 0.22
const P_FLOOR := 0.12
const DRIPS := ["drip_1", "drip_2", "drip_3"]
const STAINS := ["stain_1", "stain_2", "stain_3"]
const MOULD := ["mould_1", "mould_2"]

var L: Node3D
var _tex := {}
var _placed: Array[Vector3] = []


func setup(level: Node3D) -> void:
	L = level
	for n in DRIPS + STAINS + MOULD:
		_tex[n] = load("res://textures/decals/%s.png" % n)
	# все столкновения уже в мире (часть комнат создаёт их в своих setup)
	for i in 4:
		await get_tree().physics_frame
	_scatter()


func _space() -> PhysicsDirectSpaceState3D:
	return L.get_world_3d().direct_space_state


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.collide_with_areas = false
	return _space().intersect_ray(q)


func _bounds() -> AABB:
	var box := AABB()
	var first := true
	for mi in L.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var b := m.global_transform * m.get_aabb()
		if b.size.length() > 200.0:
			continue
		box = b if first else box.merge(b)
		first = false
	return box


func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1977
	var box := _bounds()
	var x := box.position.x
	while x < box.end.x:
		var z := box.position.z
		while z < box.end.z:
			var px := x + rng.randf_range(-0.4, 0.4)
			var pz := z + rng.randf_range(-0.4, 0.4)
			# все полы в этой точке — сверху вниз
			var y := box.end.y + 1.0
			var guard := 0
			var hits: Array = []
			while y > box.position.y and guard < 12:
				guard += 1
				var h := _ray(Vector3(px, y, pz), Vector3(px, box.position.y - 1.0, pz))
				if h.is_empty():
					break
				hits.append(h)
				y = (h["position"] as Vector3).y - 0.05
			for i in hits.size():
				var fp: Vector3 = hits[i]["position"]
				var fn: Vector3 = hits[i]["normal"]
				if fn.y < 0.8:
					continue
				# настоящий пол, а не верх мебели: под мебелью ниже есть ещё пол (поверхность лицом вверх)
				if i + 1 < hits.size() and fp.y - (hits[i + 1]["position"] as Vector3).y < 1.6 \
						and (hits[i + 1]["normal"] as Vector3).y > 0.8:
					continue
				# внутри дома: над полом есть потолок (не выше 4 м)
				if _ray(fp + Vector3(0, 0.2, 0), fp + Vector3(0, 4.0, 0)).is_empty():
					continue
				_try_floor(fp, rng)
				_try_wall(fp, rng)
				if _placed.size() >= MAX:
					return
			z += STEP
		x += STEP


func _free_spot(p: Vector3) -> bool:
	for q in _placed:
		if q.distance_to(p) < MIN_GAP:
			return false
	return true


func _try_floor(fp: Vector3, rng: RandomNumberGenerator) -> void:
	if rng.randf() > P_FLOOR or not _free_spot(fp):
		return
	var d := Decal.new()
	var s := rng.randf_range(0.7, 1.5)
	d.size = Vector3(s, 0.3, s * rng.randf_range(0.8, 1.2))
	d.texture_albedo = _tex[STAINS[rng.randi() % STAINS.size()]]
	_common(d, rng)
	L.add_child(d)
	d.global_position = fp + Vector3(0, 0.05, 0)
	d.rotation.y = rng.randf_range(0, TAU)
	_placed.append(fp)


func _try_wall(fp: Vector3, rng: RandomNumberGenerator) -> void:
	if rng.randf() > P_WALL:
		return
	var a := rng.randf_range(0, TAU)
	var dir := Vector3(cos(a), 0, sin(a))
	var from := fp + Vector3(0, rng.randf_range(1.2, 1.9), 0)
	var h := _ray(from, from + dir * 2.2)
	if h.is_empty():
		return
	var n: Vector3 = h["normal"]
	if absf(n.y) > 0.2:
		return
	var wp: Vector3 = h["position"]
	if not _free_spot(wp):
		return
	# стена, а не шкаф/комод: на 0.7 м выше луч упирается туда же
	var h2 := _ray(from + Vector3(0, 0.7, 0), from + Vector3(0, 0.7, 0) + dir * 2.2)
	if h2.is_empty() or absf(from.distance_to(wp) - (from + Vector3(0, 0.7, 0)).distance_to(h2["position"])) > 0.15:
		return
	var d := Decal.new()
	var mould := rng.randf() < 0.3
	if mould:
		var s := rng.randf_range(0.6, 1.2)
		d.size = Vector3(s, 0.3, s)
		d.texture_albedo = _tex[MOULD[rng.randi() % MOULD.size()]]
	else:
		d.size = Vector3(rng.randf_range(0.7, 1.2), 0.3, rng.randf_range(1.2, 1.9))
		d.texture_albedo = _tex[DRIPS[rng.randi() % DRIPS.size()]]
	_common(d, rng)
	L.add_child(d)
	# локальная Y декали — нормаль стены (проецирует на стену), верх текстуры (−Z) — вверх
	n = Vector3(n.x, 0, n.z).normalized()
	var bx := Vector3.UP.cross(n).normalized()
	var bz := bx.cross(n)
	d.global_transform = Transform3D(Basis(bx, n, bz), wp + n * 0.05)
	if mould:
		# плесень — повыше, ближе к потолку/углу
		d.global_position.y = minf(wp.y + rng.randf_range(0.3, 0.7), fp.y + 2.3)
	else:
		# подтёк начинается выше точки попадания и тянется вниз
		d.global_position.y = wp.y + d.size.z * 0.25
	_placed.append(wp)


func _common(d: Decal, rng: RandomNumberGenerator) -> void:
	d.modulate = Color(1, 1, 1, rng.randf_range(0.75, 1.0))
	d.normal_fade = 0.5                 # не ложится на поверхности под углом (мебель, косяки)
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.distance_fade_enabled = true
	d.distance_fade_begin = 14.0
	d.distance_fade_length = 4.0
	d.cull_mask = 1                     # только обычный слой: не на призраков в зеркале, не на свечу в руке
