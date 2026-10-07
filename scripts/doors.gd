extends Node
## Двери, которые игрок открывает и закрывает сам (E).
## Дверь считается открытой, если её петля повёрнута от «закрытого» угла больше чем на 0.3 рад —
## так состояние само подхватывает сценки, которые двигают дверь (захлопнулась, открылась сама).
## Запертые двери и двери, закрытые по сюжету, сюда не попадают или помечаются locked.

var L: Node
var doors := {}        ## id → {pivot, closed, open, center, ok: Callable, locked}
var _busy := {}


func add(id: String, pivot: Node3D, closed_a: float, open_a: float, center: Vector3, ok: Callable) -> void:
	doors[id] = {"pivot": pivot, "closed": closed_a, "open": open_a, "center": center, "ok": ok, "locked": false}
	L.targets.append({"id": "d_" + id, "pos": center, "th": 0.55, "dist": 2.1})


func is_open(id: String) -> bool:
	var d: Dictionary = doors[id]
	return absf(angle_difference(d.pivot.rotation.y, d.closed)) > 0.3


## Заблокировать дверь в текущем положении (например, захлопнулась по сюжету).
func lock(id: String, on := true) -> void:
	if doors.has(id):
		doors[id].locked = on


func target_ok(tid: String) -> bool:
	var id := tid.substr(2)
	if not doors.has(id) or _busy.has(id) or L.busy:
		return false
	var d: Dictionary = doors[id]
	return not d.locked and d.ok.call()


func interact(tid: String) -> void:
	if not tid.begins_with("d_"):
		return
	var id := tid.substr(2)
	if not doors.has(id):
		return
	var d: Dictionary = doors[id]
	var to: float = d.closed if is_open(id) else d.open
	# не закрывать дверь, если игрок стоит прямо в проёме
	if to == d.closed:
		var p: Vector3 = L.player.global_position
		var c: Vector3 = d.center
		if Vector2(p.x - c.x, p.z - c.z).length() < 0.55:
			L._sfx3d("creak", c, -10.0, 1.4)
			return
	_busy[id] = true
	L._sfx3d("door", d.center, -10.0 if to == d.open else -6.0, randf_range(1.05, 1.25) if to == d.open else 1.35)
	L._sfx3d("creak", d.center, -14.0, randf_range(1.2, 1.6))
	var tw := create_tween()
	tw.tween_property(d.pivot, "rotation:y", to, 0.75 if to == d.open else 0.55).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_busy.erase(id)


func _process(_delta: float) -> void:
	# подсказка «открыть / закрыть» под текущее положение двери
	for id in doors:
		L.extra_hints["d_" + id] = "D_CLOSE" if is_open(id) else "LVL_68"
