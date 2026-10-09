extends Node
## Спальня бабушки Веры: вход из холла второго этажа через двустворчатую дверь в западной стене.
## Комната — цельная модель (Katydid, «Abandoned mansion bedroom»): Г-образный коридор и сама спальня.
## Здесь: столкновения, створки дверей на петлях, тусклый тёплый свет, отпирание ключом Веры.

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
var leaves := {}
var lamps: Array[OmniLight3D] = []


func setup(level: Node) -> void:
	L = level
	root = L.get_node("Bedroom")
	# стены, пол и мебель — твёрдые; створки дверей получают свои коробки
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if mi.name.begins_with("FrontSide"):
			mi.create_trimesh_collision()
	# створки внутри модели лежат в повёрнутых (Z-вверх, сантиметры) узлах — вешаем каждую на свою петлю
	# с обычными осями, чтобы поворот по Y был поворотом вокруг вертикали
	for nm in ["DoorEastL", "DoorEastR", "DoorRoomL", "DoorRoomR"]:
		var leaf: Node3D = root.find_child(nm, true, false)
		var hinge := Node3D.new()
		hinge.name = nm + "Hinge"
		root.add_child(hinge)
		hinge.global_position = leaf.global_position
		leaf.reparent(hinge, true)
		leaves[nm] = hinge
		_leaf_body(hinge, leaf)
	_lights()
	var ea: Node3D = leaves.DoorEastL
	var eb: Node3D = leaves.DoorEastR
	var ra: Node3D = leaves.DoorRoomL
	var rb: Node3D = leaves.DoorRoomR
	# вход открывается внутрь, в коридор спальни (на запад); внутренняя дверь — в спальню (на восток)
	L.doors.add("bed", ea, ea.rotation.y, ea.rotation.y + 1.5, DOOR_C,
		func(): return unlocked, [eb, eb.rotation.y, eb.rotation.y - 1.5])
	L.doors.add("bed_in", ra, ra.rotation.y, ra.rotation.y - 1.5, INNER_C,
		func(): return L.phase == "floor2", [rb, rb.rotation.y, rb.rotation.y + 1.5])


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
	L.inv.remove("bedkey")
	L.busy = false
	L.doors.interact("d_bed")
	L._set_objective("BR_OBJ1")
	return true
