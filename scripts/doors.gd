extends Node
## Двери, которые игрок открывает и закрывает сам (E).
## Дверь считается открытой, если её петля повёрнута от «закрытого» угла больше чем на 0.3 рад —
## так состояние само подхватывает сценки, которые двигают дверь (захлопнулась, открылась сама).
## Запертые двери и двери, закрытые по сюжету, сюда не попадают или помечаются locked.

var L: Node
var doors := {}        ## id → {pivot, closed, open, center, ok: Callable, locked}
var _busy := {}
## «Дом дышит»: в комнате, где игрок, иногда одна дверь сама чуть приоткрывается или призакрывается.
var _creep_t := 4.0          ## первый раз — почти сразу, как только рядом есть подходящая дверь


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
	if to == d.open:
		L._sfx3d("creak", d.center, -6.0, randf_range(0.95, 1.2))     # открывается — скрип петель
	else:
		L._sfx3d("creak", d.center, -12.0, randf_range(1.3, 1.6))
		get_tree().create_timer(0.45).timeout.connect(func(): L._sfx3d("door", d.center, -8.0, randf_range(1.0, 1.15)))   # закрылась — хлопок
	var tw := create_tween()
	tw.tween_property(d.pivot, "rotation:y", to, 0.75 if to == d.open else 0.55).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_busy.erase(id)


func _process(delta: float) -> void:
	# подсказка «открыть / закрыть» под текущее положение двери
	for id in doors:
		L.extra_hints["d_" + id] = "D_CLOSE" if is_open(id) else "LVL_68"
	_creep_t -= delta
	if _creep_t <= 0.0:
		_creep_t = 3.0 if not _creep() else randf_range(35.0, 75.0)


## Одна дверь рядом с игроком медленно, со слабым скрипом сдвигается сама.
## Только по одной за раз, не во время сценок и громких звуков, не запертые и не закрытые по сюжету.
func _creep() -> bool:
	if L.busy or L.phase == "end" or not L.quiet_for(6.0) or not _busy.is_empty():
		return false
	var p: Vector3 = L.player.global_position
	var pool := []
	for id in doors:
		var d: Dictionary = doors[id]
		if d.locked or not d.ok.call():
			continue
		var c: Vector3 = d.center
		if absf(c.y - 1.1 - p.y) > 1.5:             # другой этаж
			continue
		var dist := Vector2(p.x - c.x, p.z - c.z).length()
		if dist > 1.3 and dist < 6.5:               # в этой комнате, но не в самом проёме
			pool.append(id)
	if pool.is_empty():
		return false
	var id: String = pool.pick_random()
	var d: Dictionary = doors[id]
	var a: float = d.pivot.rotation.y
	var span: float = d.open - d.closed
	var k: float = (a - d.closed) / span                      # 0 — закрыта, 1 — распахнута
	var to_k: float
	if k > 0.45:
		to_k = k - randf_range(0.12, 0.22)              # открытая — призакрывается
	elif k < 0.08:
		to_k = randf_range(0.07, 0.15)                  # закрытая — чуть приоткрывается (щель)
	else:
		to_k = clampf(k + randf_range(-0.15, 0.15), 0.03, 0.4)
	var sec := randf_range(2.6, 4.2)
	_busy[id] = true
	L._sfx3d("creak", d.center, randf_range(-20.0, -15.0), randf_range(0.5, 0.65))
	var tw := create_tween()
	tw.tween_property(d.pivot, "rotation:y", d.closed + span * to_k, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): _busy.erase(id))
	return true
