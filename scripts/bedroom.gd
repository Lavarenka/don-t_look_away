extends Node
## Спальня бабушки Веры: вход из холла второго этажа через дверь в западной стене.
## Комната — цельная модель (Katydid, «Abandoned mansion bedroom»): Г-образный коридор и сама спальня.
## Здесь: столкновения, обычные двери на петлях, тусклый тёплый свет, отпирание ключом Веры.

const Y2 := -3.4
const DOOR_C := Vector3(-4.65, Y2 + 1.0, -35.5)        ## входная дверь (из холла)
const INNER_C := Vector3(-14.1, Y2 + 1.0, -28.43)      ## дверь из коридора в спальню
## свет: [позиция, энергия, радиус, тени]
const LAMPS := [
	[Vector3(-9.51, Y2 + 1.62, -34.95), 0.55, 4.0, false],   # бра в коридоре
	[Vector3(-6.12, Y2 + 1.62, -34.95), 0.45, 3.5, false],
	[Vector3(-15.85, Y2 + 1.62, -29.95), 0.45, 3.5, false],  # бра у двери в спальню
	[Vector3(-13.45, Y2 + 1.62, -29.83), 0.6, 4.5, false],
	[Vector3(-5.95, Y2 + 1.62, -31.47), 0.6, 4.5, false],    # бра на стене спальни
	[Vector3(-11.08, Y2 + 1.15, -33.25), 1.1, 5.5, true],    # настольная лампа у кровати
	[Vector3(-15.68, Y2 + 1.3, -35.9), 0.5, 3.5, false],     # торшер в углу коридора
]

var L: Node
var root: Node3D
var unlocked := false
var lamps: Array[OmniLight3D] = []


func setup(level: Node) -> void:
	L = level
	root = L.get_node("Bedroom")
	# стены, пол и мебель — твёрдые; створки дверей получают свои коробки
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if mi.name.begins_with("FrontSide"):
			mi.create_trimesh_collision()
	# двустворчатые двери из модели убраны — вместо них обычные двери, как во всём доме
	# (модуль стены с дверью из того же набора, что и холл)
	for nm in ["DoorEastL", "DoorEastR", "DoorRoomL", "DoorRoomR"]:
		(root.find_child(nm, true, false) as Node3D).visible = false
	_lights()
	var ea := _door("F2DoorBed", -1.0)            # из холла — внутрь, в коридор спальни (на запад)
	var ra := _vera_door()                        # из коридора — в спальню (дубовая дверь из Blender)
	_wallpaper()
	L.doors.add("bed", ea, 0.0, ea.get_meta("open"), DOOR_C, func(): return unlocked)
	L.doors.add("bed_in", ra, 0.0, ra.get_meta("open"), INNER_C, func(): return L.phase == "floor2")


## Полотно из модуля стены — на петлю; угол открытия выбирается так, чтобы дверь уходила
## в сторону dir по X. Плюс коробки-столкновения вокруг проёма (бока и верх модуля).
func _door(wall_name: String, dir: float) -> Node3D:
	var wall: Node3D = L.get_node(wall_name)
	var leaf: MeshInstance3D = wall.get_node("small_door")
	var hinge := Node3D.new()
	hinge.name = wall_name + "Hinge"
	L.add_child(hinge)
	hinge.global_position = leaf.global_position
	leaf.reparent(hinge, true)
	var c0: Vector3 = (leaf.global_transform * leaf.get_aabb()).get_center()
	hinge.rotation.y = 1.6
	var c1: Vector3 = (leaf.global_transform * leaf.get_aabb()).get_center()
	hinge.rotation.y = 0.0
	hinge.set_meta("open", 1.6 if (c1.x - c0.x) * dir > 0.0 else -1.6)
	_leaf_body(hinge, leaf)
	# проём модуля: x 0..1.2 (полотно 0.166..1.036), высота 2.82, полотно до 1.94
	var sx: float = wall.scale.x
	var gb := Basis(wall.global_transform.basis.get_rotation_quaternion())
	var body := StaticBody3D.new()
	L.add_child(body)
	for b in [[0.083, 1.41, 0.166, 2.82], [1.118, 1.41, 0.164, 2.82], [0.6, 2.38, 1.2, 0.88]]:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(b[2] * sx, b[3], 0.2)
		cs.shape = sh
		body.add_child(cs)
		cs.global_transform = Transform3D(gb, wall.global_transform * Vector3(b[0], b[1], 0.06))
	return hinge


## Дверь в спальню бабушки: своя модель из Blender (обрамление под проём модели + филёнчатое
## полотно с латунными ручками и петлями). Полотно уже лежит на оси петель; открывается в спальню (+X).
func _vera_door() -> Node3D:
	var unit: Node3D = L.get_node("BedDoorVera")
	var surround: MeshInstance3D = unit.find_child("Surround", true, false)
	surround.create_trimesh_collision()
	var leaf: MeshInstance3D = unit.find_child("Leaf", true, false)
	var c0: Vector3 = (leaf.global_transform * leaf.get_aabb()).get_center()
	leaf.rotation.y = 1.6
	var c1: Vector3 = (leaf.global_transform * leaf.get_aabb()).get_center()
	leaf.rotation.y = 0.0
	leaf.set_meta("open", 1.6 if c1.x > c0.x else -1.6)
	_leaf_body(leaf, leaf)
	return leaf


## С обратной стороны модулей стен (видно из спальни) — обои и деревянные панели, как на стенах комнаты.
const WALL_SPLIT := 0.79          ## высота, где панели переходят в обои
const WALL_TOP := 2.46            ## верх полосы обоев
func _wallpaper() -> void:
	var paper: Material = _mat("FrontSide_12")
	var wood_c: Material = _mat("FrontSide_19")        # нижние панели в коридоре
	# вход: сторона коридора спальни (смотрит на запад), дыра под дверную коробку
	for r in [[-34.55, -35.0, 0.0, 2.6], [-36.0, -36.45, 0.0, 2.6], [-35.0, -36.0, 1.94, 2.6]]:
		_rect(-4.71, -1.0, r, paper, wood_c)


func _mat(mesh_name: String) -> Material:
	var m: Material = (root.find_child(mesh_name, true, false) as MeshInstance3D).mesh.surface_get_material(0).duplicate()
	if m is BaseMaterial3D:
		(m as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Прямоугольник на плоскости x = px (нормаль по X со знаком nx): r = [z0, z1, y0, y1] от пола (Y2).
## Ниже WALL_SPLIT — дерево, выше — обои; развёртка такая же, как у стен модели.
func _rect(px: float, nx: float, r: Array, paper: Material, wood: Material) -> void:
	for part in [[r[2], minf(r[3], WALL_SPLIT), wood], [maxf(r[2], WALL_SPLIT), r[3], paper]]:
		var y0: float = part[0]
		var y1: float = part[1]
		if y1 - y0 < 0.01:
			continue
		var is_paper: bool = part[2] == paper
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3(nx, 0, 0))
		var pts := [Vector2(r[0], y0), Vector2(r[1], y0), Vector2(r[1], y1), Vector2(r[0], y1)]
		for i in [0, 1, 2, 0, 2, 3]:
			var q: Vector2 = pts[i]
			var uv: Vector2
			if is_paper:
				uv = Vector2(-q.x * 0.21, (q.y - WALL_TOP) * 0.598)
			else:
				uv = Vector2(-q.x * 0.69, (q.y - 0.74) * 0.561 - 0.552)
			st.set_uv(uv)
			st.add_vertex(Vector3(px, Y2 + q.y, q.x))
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = part[2]
		L.add_child(mi)


## Коробка-столкновение по габаритам створки (в её собственных координатах, чтобы крутилась вместе с ней).
func _leaf_body(hinge: Node3D, leaf: MeshInstance3D) -> void:
	var box: AABB = (hinge.global_transform.affine_inverse() * leaf.global_transform) * leaf.get_aabb()
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(maxf(box.size.x, 0.06), box.size.y, maxf(box.size.z, 0.06))
	cs.shape = sh
	cs.position = box.get_center()
	body.add_child(cs)
	hinge.add_child(body)


func _lights() -> void:
	for l in LAMPS:
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.68, 0.4)
		o.light_energy = l[1]
		o.omni_range = l[2]
		o.omni_attenuation = 1.4
		o.shadow_enabled = l[3]
		root.get_parent().add_child(o)
		o.global_position = l[0]
		lamps.append(o)
	# еле заметный холодный свет, чтобы углы не проваливались в сплошную черноту
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.45, 0.5, 0.7)
	fill.light_energy = 0.18
	fill.omni_range = 9.0
	root.get_parent().add_child(fill)
	fill.global_position = Vector3(-10.5, Y2 + 2.4, -31.5)


## Холл: E на запертой двери спальни. С ключом Веры — отпирается и открывается.
func try_open() -> bool:
	if unlocked or not L.inv.has("bedkey"):
		return false
	L.busy = true
	L._sfx3d("click", DOOR_C, -2.0, 0.9)
	await get_tree().create_timer(0.45).timeout
	L._sfx3d("click", DOOR_C, -4.0, 0.6)
	await get_tree().create_timer(0.35).timeout
	unlocked = true
	preload("res://scripts/settings.gd").reach(6)
	L.inv.remove("bedkey")
	L.busy = false
	L.doors.interact("d_bed")
	L._set_objective("BR_OBJ1")
	return true
