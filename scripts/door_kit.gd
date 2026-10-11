extends RefCounted
## Двери из набора «Door Pack Asset» (Daniil Evseev / T_i_a_D, CC BY 4.0) вместо фанерных полотен
## модулей стен. Логика дверей (петли, столкновения, сценки) не меняется: старое полотно small_door
## остаётся «невидимым носителем», новое полотно — его дочерний узел и двигается вместе с ним.
## Коробка из набора встаёт на место коробки модуля и подгоняется под его проём.

const KIT := "res://models/doors/door_kit.glb"
## стена с дверью → вариант из набора (у каждой комнаты своя дверь)
const MAP := {
	"FrontDoorWall": "OLD_D",     # входная: тёмные старые доски
	"Door1Wall": "T_W",           # прихожая → коридор
	"ExitWall": "W",              # коридор → детская
	"F2DoorLanding": "OLD_W",     # лестница с чердака → холл
	"F2DoorBath": "G",            # ванная
	"F2DoorStudy": "B",           # кабинет дедушки
	"F2DoorAnya": "P_W",          # комната Ани (табличка остаётся)
	"F2DoorBed": "T_G",           # вход в крыло бабушки
}


static func apply_all(L: Node) -> void:
	var kit: Node3D = load(KIT).instantiate()
	for wall_name in MAP:
		var wall := L.get_node_or_null(wall_name) as Node3D
		if wall:
			_apply(L, wall, kit, MAP[wall_name])
	kit.free()


## Перенос узла набора из его собственного пространства (корень набора) — цепочка transform'ов.
static func _rel(n: Node3D, root: Node) -> Transform3D:
	var t := Transform3D()
	var p: Node = n
	while p != root and p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


static func _meshes(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.find_children("*", "MeshInstance3D", true, false):
		out.append(c)
	return out


static func _apply(L: Node, wall: Node3D, kit: Node3D, v: String) -> void:
	var leaf := wall.get_node("small_door") as MeshInstance3D
	var old_frame := wall.get_node("small_door_frame") as MeshInstance3D
	var wall_mesh := wall.get_node("wall") as MeshInstance3D
	var fr_node := kit.find_child("wood_frame_" + v, true, false)
	var door_node := kit.find_child("wood_door_" + v, true, false)
	if fr_node == null or door_node == null:
		push_warning("door_kit: нет варианта " + v)
		return
	var frames := _meshes(fr_node)
	var doors := _meshes(door_node)
	# коробка набора в его пространстве: X — глубина, Y — высота, Z — ширина
	var fb := AABB()
	for i in frames.size():
		var b: AABB = _rel(frames[i], kit) * (frames[i] as MeshInstance3D).get_aabb()
		fb = b if i == 0 else fb.merge(b)
	# куда ставить: проём коробки модуля (ширина, высота) и толщина стены
	var fa: AABB = old_frame.global_transform * old_frame.get_aabb()
	var wa: AABB = wall_mesh.global_transform * wall_mesh.get_aabb()
	var ex := wall.global_transform.basis.x.normalized()
	var ez := wall.global_transform.basis.z.normalized()
	var ey := Vector3.UP
	var w_t := absf(fa.size.x * ex.x) + absf(fa.size.z * ex.z)
	var d_t := (absf(wa.size.x * ez.x) + absf(wa.size.z * ez.z)) * 1.1
	var h_t := fa.size.y
	var c := fa.get_center()
	c += ez * ez.dot(wa.get_center() - c)
	c.y = fa.position.y + h_t * 0.5
	# сторона ручки у полотна набора — по выступающим вершинам; ручка должна оказаться у свободного края
	var s := 1.0
	var dm := doors[0] as MeshInstance3D
	var dt := _rel(dm, kit)
	var db: AABB = dt * dm.get_aabb()
	var verts: PackedVector3Array = dm.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var acc := 0.0
	var cnt := 0
	for p in verts:
		var g := dt * p
		if absf(g.x - db.get_center().x) > db.size.x * 0.32:
			acc += g.z - db.get_center().z
			cnt += 1
	if cnt > 0 and acc < 0.0:
		s = -1.0
	# у модуля петля — у «левого» края (x = 0 его полотна), свободный край — дальше по ex
	var hinge_side := ex.dot(leaf.global_position - c)
	if hinge_side > 0.0:
		s = -s
	var sx := w_t / fb.size.z
	var sy := h_t / fb.size.y
	var sz := d_t / fb.size.x
	var dsign := -s
	var m := Basis(ez * (dsign * sz), ey * sy, ex * (s * sx))
	var g_xf := Transform3D(m, c - m * fb.get_center())
	for f in frames:
		var mi := MeshInstance3D.new()
		mi.mesh = (f as MeshInstance3D).mesh
		mi.set_meta("door_kit", true)
		L.add_child(mi)
		mi.global_transform = g_xf * _rel(f, kit)
	for d in doors:
		var mi := MeshInstance3D.new()
		mi.mesh = (d as MeshInstance3D).mesh
		mi.set_meta("door_kit", true)
		leaf.add_child(mi)
		mi.global_transform = g_xf * _rel(d, kit)
	leaf.layers = 0              # старое фанерное полотно больше не рисуется, но двигает новое
	old_frame.visible = false
