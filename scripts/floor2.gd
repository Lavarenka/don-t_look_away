extends Node
## 5-я часть: катсцена спуска с чердака по крутой лестнице и холл второго этажа.
## Все четыре комнаты пока заперты; в холле — тихие жуткие события.

const SETTINGS = preload("res://scripts/settings.gd")
const Y2 := -3.4
const ST_N := 16
const ST_RISE := 3.4 / 16.0
const ST_RUN := 0.17
const ST_X := 3.0
const ST_Z := -29.95
const LZ0 := -34.2
const HZ0 := -36.8
const HZ1 := -34.2
const HX1 := 4.6
## двери: id → [центр (на высоте ручки), реплика при первой попытке]
const DOORS := {
	"f_bed": [Vector3(-4.65, Y2 + 1.0, (HZ0 + HZ1) / 2), "LVL_69"],
	"f_bath": [Vector3(-0.8, Y2 + 1.0, HZ0 + 0.12), "LVL_70"],
	"f_study": [Vector3(1.6, Y2 + 1.0, HZ0 + 0.12), "LVL_71"],
	"f_anya": [Vector3(HX1 - 0.12, Y2 + 1.0, (HZ0 + HZ1) / 2), "LVL_72"],
}

var L: Node
var pivot: Node3D
var tried := {}
var next_ev := 14.0
var bed_glow: OmniLight3D
var bars: Array[ColorRect] = []


func setup(level: Node) -> void:
	L = level
	# дверь мини-холла: полотно из модуля стены → на петлю; второе полотно (с обратной стороны) не нужно
	pivot = L.get_node("F2LandPivot")
	var leaf: Node3D = L.get_node("F2DoorLanding/small_door")
	pivot.global_position = Vector3(leaf.global_position.x, Y2, leaf.global_position.z)
	leaf.reparent(pivot, true)
	(L.get_node("F2DoorLandingB/small_door") as Node3D).visible = false
	bed_glow = L.get_node("F2BedGlow")
	for id in DOORS:
		L.targets.append({"id": id, "pos": DOORS[id][0], "th": 0.5, "dist": 2.0})
		L.extra_hints[id] = "LVL_68"
	# таблички на дверях
	_sign("F2_SIGN_ANYA", Vector3(HX1 - 0.07, Y2 + 1.45, (HZ0 + HZ1) / 2), -PI / 2, Color(0.15, 0.1, 0.25), 0.0025, true)
	_sign("F2_SIGN_BATH", Vector3(-0.8, Y2 + 1.6, HZ0 + 0.07), 0.0, Color(0.75, 0.6, 0.3), 0.0018, false)


func _sign(key: String, pos: Vector3, yaw: float, col: Color, px: float, paper: bool) -> void:
	var holder := Node3D.new()
	L.add_child(holder)
	holder.global_position = pos
	holder.rotation.y = yaw
	if paper:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.28, 0.2)
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.78, 0.74, 0.62)
		m.roughness = 1.0
		q.material_override = m
		q.rotation.z = 0.06
		holder.add_child(q)
	var l := Label3D.new()
	l.text = tr(key)
	l.pixel_size = px
	l.font_size = 48
	l.modulate = col
	l.outline_size = 0
	l.position = Vector3(0, 0, 0.004)
	l.rotation.z = 0.06 if paper else 0.0
	l.shaded = true
	holder.add_child(l)


func target_ok(id: String) -> bool:
	if id == "f_bath" and L.bath.unlocked:
		return false
	if id == "f_bed" and L.bedroom.unlocked:
		return false
	return L.phase == "floor2" and not L.busy


func interact(id: String) -> void:
	if not DOORS.has(id):
		return
	if id == "f_bed" and await L.bedroom.try_open():
		return
	var pos: Vector3 = DOORS[id][0]
	L._sfx3d("click", pos, -6.0, 0.8)
	L._sfx3d("creak", pos, -12.0, 1.8)
	if tried.has(id):
		L._say("LVL_73", 2.0)
		return
	tried[id] = true
	L._say(DOORS[id][1], 3.5)
	# подёргал несколько дверей — и ванная, где капает вода, открывается сама
	if tried.size() >= 3 and not L.bath.unlocked:
		get_tree().create_timer(4.0).timeout.connect(L.bath.unlock)
	if id == "f_anya":                       # изнутри отвечают стуком
		await get_tree().create_timer(1.1).timeout
		for t in [0.0, 0.45, 0.45]:
			await get_tree().create_timer(t).timeout
			L._sfx3d("knock", pos, -2.0, 1.1)


# ---------------- катсцена спуска ----------------
func _letterbox(show: bool) -> void:
	if bars.is_empty():
		for top in [true, false]:
			var r := ColorRect.new()
			r.color = Color.BLACK
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
			r.custom_minimum_size = Vector2(0, 0)
			r.size.y = 0
			L.hud.add_child(r)
			bars.append(r)
	var h := 0.12 * L.get_viewport().get_visible_rect().size.y if show else 0.0
	for i in bars.size():
		var r: ColorRect = bars[i]
		var tw := create_tween()
		tw.tween_property(r, "custom_minimum_size:y", h, 1.0).set_trans(Tween.TRANS_SINE)
		if i == 1:
			tw.parallel().tween_property(r, "position:y", L.get_viewport().get_visible_rect().size.y - h, 1.0).set_trans(Tween.TRANS_SINE)


## Плавно перенести игрока (ноги) и повернуть взгляд.
func _move(to: Vector3, yaw: float, pitch: float, t: float) -> void:
	var p = L.player
	var tw := create_tween().set_parallel()
	tw.tween_property(p, "global_position", to, t).set_trans(Tween.TRANS_SINE)
	tw.tween_property(p, "rotation:y", yaw, t).set_trans(Tween.TRANS_SINE)
	tw.tween_property(p.head, "rotation:x", pitch, t).set_trans(Tween.TRANS_SINE)
	await tw.finished


func descend() -> void:
	var p = L.player
	L.busy = true
	p.frozen = true
	p.set_physics_process(false)
	p.velocity = Vector3.ZERO
	L.hint_label.text = ""
	_letterbox(true)
	(L.get_node("Attic/HatchBlock/Shape") as CollisionShape3D).disabled = true
	var hatch: Node3D = L.get_node("Attic/Hatch")
	# 1) встал у края проёма и смотрит вниз, в темноту
	var yaw0: float = wrapf(p.rotation.y, -PI, PI)
	p.rotation.y = yaw0
	await _move(Vector3(ST_X, 0.0, -29.55), 0.0, -0.8, 1.6)
	L._sfx("heartbeat", -8.0)
	await get_tree().create_timer(1.2).timeout
	# 2) медленно спускается; ступени скрипят
	for i in range(1, ST_N + 1):
		var pos := Vector3(ST_X + sin(i * 1.7) * 0.03, -i * ST_RISE, ST_Z - (i - 0.5) * ST_RUN)
		var pitch := lerpf(-0.75, -0.35, float(i) / ST_N)
		if i == 10:
			# сверху — грохот: крышка люка захлопнулась сама
			await _move(pos, PI * 0.92, 0.7, 0.7)          # оборачивается и смотрит вверх, на проём
			create_tween().tween_property(hatch, "rotation:z", 0.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			await get_tree().create_timer(0.24).timeout
			L._sfx("bang", 0.0, 0.8)
			L._sfx("door", -4.0, 0.6)
			p.shake = 0.8
			if L.attic.roof:
				L.attic.roof.stop()
			if L.amb_layers.has("rain_window"):
				L.amb_layers["rain_window"].volume_db = -16.0
			p.flicker = 0.3
			await get_tree().create_timer(0.9).timeout
			p.flicker = 0.0
			L.drone.play()
			await _move(pos, 0.0, pitch, 0.8)
			continue
		L._sfx("step%d" % (i % 4), -9.0, randf_range(0.8, 0.9))
		if i % 3 == 0:
			L._sfx3d("creak", pos, -10.0, randf_range(0.9, 1.3))
		if i == 12:
			L._sfx3d("whisper", Vector3(ST_X, Y2 + 1.2, LZ0 - 1.0), -6.0, 0.8)
		await _move(pos, 0.0, pitch, 0.5)
	# 3) площадка. Дверь впереди… ручка дёргается — и дверь сама открывается
	await _move(Vector3(ST_X, Y2, -33.45), 0.0, -0.05, 1.4)
	await get_tree().create_timer(0.8).timeout
	L._sfx3d("click", Vector3(ST_X, Y2 + 1.0, LZ0), -4.0, 0.7)
	await get_tree().create_timer(0.6).timeout
	L._sfx3d("door", Vector3(ST_X, Y2 + 1.0, LZ0), -4.0, 0.65)
	create_tween().tween_property(pivot, "rotation:y", 1.6, 3.2).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(2.4).timeout
	# 4) шаг в холл и взгляд вдоль него — к окну с луной
	await _move(Vector3(ST_X, Y2, -35.3), 0.0, 0.0, 2.2)
	await _move(Vector3(ST_X - 0.3, Y2, -35.45), PI / 2, 0.02, 1.8)
	L._say("LVL_66", 3.5)
	_letterbox(false)
	await get_tree().create_timer(1.0).timeout
	_start_floor()


func _start_floor() -> void:
	var p = L.player
	L.phase = "floor2"
	SETTINGS.reach(5)
	p.velocity = Vector3.ZERO
	p.set_physics_process(true)
	p.frozen = false
	L.busy = false
	L._set_objective("LVL_67")


## Меню «Главы» → 5: сразу в холл второго этажа.
func enter_direct() -> void:
	var p = L.player
	var env: Environment = L.get_node("WorldEnvironment").environment
	env.volumetric_fog_density = 0.018
	env.fog_density = 0.02
	L.girl.visible = false
	L.end_box.visible = false
	pivot.rotation.y = 1.6
	(L.get_node("Attic/HatchBlock/Shape") as CollisionShape3D).disabled = true
	if L.amb_layers.has("rain_window"):
		L.amb_layers["rain_window"].volume_db = -16.0
	var sp: Node3D = L.get_node("F2Spawn")
	p.teleport(sp.global_position, PI / 2)
	L._say("LVL_66", 3.0)
	_start_floor()


# ---------------- жуть в холле ----------------
func _process(delta: float) -> void:
	if L == null or L.phase != "floor2" or L.busy:
		return
	var pp: Vector3 = L.player.global_position
	# тёплый свет под дверью спальни горит, только пока ты далеко
	var bd := Vector2(pp.x + 4.65, pp.z - (HZ0 + HZ1) / 2).length()
	if bd > 5.0 and bed_glow.light_energy == 0.0 and not L.bedroom.unlocked and randf() < delta * 0.05:
		bed_glow.light_energy = 0.7
	elif bd < 2.8 and bed_glow.light_energy > 0.0:
		bed_glow.light_energy = 0.0
		L._sfx3d("click", Vector3(-5.1, Y2 + 0.5, (HZ0 + HZ1) / 2), -12.0, 0.9)
	next_ev -= delta
	if next_ev > 0.0:
		return
	next_ev = randf_range(15.0, 28.0)
	match randi() % 5:
		0:      # шаги над головой — кто-то ходит по чердаку
			var x := randf_range(-3.0, 2.0)
			for i in 6:
				L._sfx3d("step%d" % (i % 4), Vector3(x + i * 0.6, -0.1, pp.z + randf_range(-0.5, 0.5)), -4.0, 0.75)
				await get_tree().create_timer(0.7).timeout
		1:      # кто-то дёргает ручку запертой двери изнутри
			var ids := DOORS.keys()
			var pos: Vector3 = DOORS[ids[randi() % ids.size()]][0]
			for i in 3:
				L._sfx3d("click", pos, -4.0, randf_range(0.7, 0.9))
				await get_tree().create_timer(0.18).timeout
			L._sfx3d("creak", pos, -10.0, 1.6)
		2:      # стук изнутри комнаты
			var pos2: Vector3 = DOORS[DOORS.keys()[randi() % DOORS.size()]][0]
			for t in [0.0, 0.6, 0.6]:
				await get_tree().create_timer(t).timeout
				L._sfx3d("knock", pos2, -6.0, 0.85)
		3:      # половица скрипнула за спиной
			var back: Vector3 = -L.player.forward()
			back.y = 0.0
			L._sfx3d("beam_creak", pp + back.normalized() * 2.0 + Vector3(0, 0.05, 0), -6.0, 1.2)
		4:      # шёпот
			L._sfx("whisper", -14.0, 0.8)
