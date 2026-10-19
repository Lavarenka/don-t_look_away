extends Node
## Мебель вместо коробок-заглушек: на чердаке — комоды, тумбочки, ящики с крышками, сундук;
## в холле — резные полочки под портретами. Модели — из Blender (blend/make_attic3.py).
## Механика (E): ящики выдвигаются, дверцы и крышки открываются, тумбочки можно отодвинуть.

## узел-заглушка → модель; k — поворот модели (×90°), чтобы перед смотрел в середину чердака;
## push — можно отодвинуть (на ней ничего не стоит)
const PIECES := [
	{"node": "Attic/Crate0", "glb": "attic_commode_a", "k": 3, "push": false},
	{"node": "Attic/Crate1", "glb": "attic_crate_a", "k": 3, "push": false},
	{"node": "Attic/Crate2", "glb": "attic_commode_b", "k": 3, "push": false},
	{"node": "Attic/Crate4", "glb": "attic_crate_b", "k": 1, "push": false},
	{"node": "Attic/Crate5", "glb": "attic_smallbox", "k": 2, "push": false},
	{"node": "Attic/Crate6", "glb": "attic_nightstand_a", "k": 3, "push": true},
	{"node": "Attic/Crate7", "glb": "attic_nightstand_b", "k": 2, "push": true},
]
const PUSH_DIST := 0.5

var L: Node
var parts := {}          ## id → {node, kind, base, open, piece, target}
var pieces := {}         ## номер → {root, col, model, pushed, base, col_base, half, target}
var _busy := {}


func setup(level: Node) -> void:
	L = level
	for i in PIECES.size():
		var p: Dictionary = PIECES[i]
		var holder := L.get_node_or_null(p.node) as MeshInstance3D
		if holder == null:
			continue
		var half: float = (holder.mesh as BoxMesh).size.y / 2.0 if holder.mesh is BoxMesh else 0.25
		holder.mesh = null
		var model: Node3D = load("res://models/attic/%s.glb" % p.glb).instantiate()
		holder.add_child(model)
		model.position = Vector3(0, -half, 0)
		model.rotation.y = p.k * PI / 2.0
		var col := L.get_node_or_null(str(p.node) + "Col") as Node3D
		var pc := {"root": holder, "col": col, "model": model, "pushed": false, "base": holder.position,
			"col_base": col.position if col else Vector3.ZERO, "half": half, "target": {}}
		pieces[i] = pc
		_add_parts(i, model)
		if p.push:
			var t := {"id": "fn_push%d" % i, "pos": holder.global_position + Vector3(0, half, 0), "th": 0.35, "dist": 2.0}
			L.targets.append(t)
			L.extra_hints[t.id] = "FN_PUSH"
			pc.target = t
	# сундук на чердаке
	var tr := L.get_node_or_null("Attic/Trunk0") as Node3D
	if tr:
		for n in ["Box", "Lid", "Band0", "Band1"]:
			var c := tr.get_node_or_null(n) as Node3D
			if c:
				c.visible = false
		var tm: Node3D = load("res://models/attic/attic_trunk.glb").instantiate()
		tr.add_child(tm)
		pieces[100] = {"root": tr, "col": null, "model": tm, "pushed": false, "base": tr.position, "col_base": Vector3.ZERO, "half": 0.27, "target": {}}
		_add_parts(100, tm, "LVL_42")
	# полочки под портретами в холле
	for i in 3:
		var sh := L.get_node_or_null("Portrait%d/Shelf" % (i + 1)) as Node3D
		if sh == null:
			continue
		sh.visible = false
		var sm: Node3D = load("res://models/props/hall_shelf.glb").instantiate()
		sh.get_parent().add_child(sm)
		sm.transform = sh.transform
		sm.position.y += 0.0025


## Подвижные части модели: DrawerN, DoorN, Lid (ручки/петли — их дети, двигаются с ними).
func _add_parts(pi: int, model: Node3D, open_hint := "LVL_68") -> void:
	for n in model.find_children("*", "Node3D", true, false):
		var nm := str(n.name)
		var kind := ""
		if nm.begins_with("Drawer") and nm.trim_prefix("Drawer").is_valid_int():
			kind = "drawer"
		elif nm.begins_with("Door") and nm.trim_prefix("Door").is_valid_int():
			kind = "door"
		elif nm == "Lid":
			kind = "lid"
		if kind == "":
			continue
		var id := "fn_%d_%s" % [pi, nm]
		var node := n as Node3D
		var t := {"id": id, "pos": _part_center(node), "th": 0.3, "dist": 2.0}
		L.targets.append(t)
		L.extra_hints[id] = open_hint
		parts[id] = {"node": node, "kind": kind, "base": node.transform, "open": false, "piece": pi,
			"target": t, "hint": open_hint, "depth": _depth(node)}


func _part_center(n: Node3D) -> Vector3:
	var mi := n as MeshInstance3D
	if mi and mi.mesh:
		return (mi.global_transform * mi.get_aabb()).get_center()
	return n.global_position


func _depth(n: Node3D) -> float:
	var mi := n as MeshInstance3D
	return mi.get_aabb().size.z if mi and mi.mesh else 0.4


func target_ok(id: String) -> bool:
	if L.busy or _busy.has(id):
		return false
	return parts.has(id) or id.begins_with("fn_push")


func interact(id: String) -> void:
	if not id.begins_with("fn_") or _busy.has(id):
		return
	if id.begins_with("fn_push"):
		_push(int(id.trim_prefix("fn_push")), id)
		return
	if not parts.has(id):
		return
	var p: Dictionary = parts[id]
	var n: Node3D = p.node
	var open: bool = not p.open
	p.open = open
	_busy[id] = true
	var tw := create_tween()
	var base: Transform3D = p.base
	match p.kind:
		"drawer":
			var to: Vector3 = base.origin + base.basis.z.normalized() * (float(p.depth) * 0.6 if open else 0.0)
			tw.tween_property(n, "position", to, 0.45 if open else 0.35).set_trans(Tween.TRANS_SINE)
			L._sfx3d("drawer", n.global_position, -6.0, randf_range(0.95, 1.1) if open else randf_range(1.15, 1.3), true)
		"door":
			tw.tween_property(n, "rotation:y", -1.75 if open else 0.0, 0.7 if open else 0.5).set_trans(Tween.TRANS_SINE)
			L._sfx3d("creak", n.global_position, -10.0, randf_range(1.2, 1.5), true)
		"lid":
			tw.tween_property(n, "rotation:x", -1.45 if open else 0.0, 0.9 if open else 0.6).set_trans(Tween.TRANS_SINE)
			L._sfx3d("creak", n.global_position, -8.0, randf_range(0.8, 1.0), true)
			if not open:
				get_tree().create_timer(0.55).timeout.connect(func(): L._sfx3d("thump", n.global_position, -10.0, 1.1, true))
	L.extra_hints[id] = "D_CLOSE" if open else p.hint
	await tw.finished
	p.target.pos = _part_center(n)
	_busy.erase(id)


## Отодвинуть тумбочку вбок вдоль стены (или вернуть на место). Если сбоку тесно — в другую сторону.
func _push(i: int, id: String) -> void:
	var pc: Dictionary = pieces[i]
	var root: Node3D = pc.root
	var col: Node3D = pc.col
	var off := Vector3.ZERO
	if not pc.pushed:
		var side: Vector3 = (pc.model as Node3D).global_basis.x
		side.y = 0.0
		side = side.normalized()
		var chosen := Vector3.ZERO
		for s in [side, -side]:
			if _free(col, s * PUSH_DIST):
				chosen = s * PUSH_DIST
				break
		if chosen == Vector3.ZERO:
			L._sfx3d("thump", root.global_position, -10.0, 0.8, true)
			return
		off = chosen
	# закрыть открытые ящики/дверцы этой тумбочки — иначе едут «на весу»
	for pid in parts.keys():
		if parts[pid].piece == i and parts[pid].open:
			interact(pid)
	_busy[id] = true
	pc.pushed = not pc.pushed
	var to_root: Vector3 = pc.base + off
	var to_col: Vector3 = pc.col_base + off
	var tw := create_tween().set_parallel()
	tw.tween_property(root, "position", to_root, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if col:
		tw.tween_property(col, "position", to_col, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	L._sfx3d("drag", root.global_position, -6.0, randf_range(1.0, 1.15), true)
	L.extra_hints[id] = "FN_PUSH_BACK" if pc.pushed else "FN_PUSH"
	await tw.finished
	# цели переезжают вместе с тумбочкой
	(pc.target as Dictionary).pos = root.global_position + Vector3(0, pc.half, 0)
	for pid in parts.keys():
		if parts[pid].piece == i:
			parts[pid].target.pos = _part_center(parts[pid].node)
	_busy.erase(id)


## Свободно ли место, куда сдвигается тумбочка (её коробка-столкновение, сдвинутая на off).
func _free(col: Node3D, off: Vector3) -> bool:
	if col == null:
		return true
	var cs := col.get_node_or_null("Shape") as CollisionShape3D
	if cs == null or cs.shape == null:
		return true
	var q := PhysicsShapeQueryParameters3D.new()
	var bs := (cs.shape as BoxShape3D).duplicate() as BoxShape3D
	bs.size *= Vector3(0.95, 0.8, 0.95)
	q.shape = bs
	var xf := cs.global_transform
	xf.origin += off + Vector3(0, 0.05, 0)
	q.transform = xf
	q.exclude = [(col as CollisionObject3D).get_rid()] if col is CollisionObject3D else []
	return L.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()
