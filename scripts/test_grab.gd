extends Node
## ПРОБНЫЙ скример (новая модель Ани, MakeHuman): в начале игры, посередине прихожей — она вплотную,
## лицо на весь экран, кричит и трясётся, руками держит тебя за голову. Выключить: level.TEST_GRAB = false.
const SPIRIT = preload("res://scripts/spirit.gd")
const TRIGGER_Z := 3.0          ## прошёл прихожую до этой отметки — срабатывает (один раз)
const DIST := 0.1               ## лицо (глаза) — в 20 см от камеры: на весь экран
const HOLD := 1.9               ## сколько держит

var L: Node
var done := false
var g: Node3D
var grab: SkeletonModifier3D
var _t := 0.0
var _hoff := Vector3(0, 1.45, 0.0)   ## центр головы в локальных осях призрака


func _process(delta: float) -> void:
	if done:
		if g and is_instance_valid(g):
			_t += delta
			_hold_frame()
		return
	var p = L.player
	if L.busy or p.frozen or p.global_position.z > TRIGGER_Z:
		return
	done = true
	_scare()


func _scare() -> void:
	var p = L.player
	L.busy = true
	p.frozen = true
	p.head.rotation.x = 0.0
	var fe = p.get("flash_energy")
	if fe != null:
		p.flash_energy = 1.0                  # вплотную фонарь выжигает лицо — приглушить
	g = SPIRIT.new()
	g.new_model = true
	L.add_child(g)
	g.visible = false
	await get_tree().process_frame
	g.play_from("reach", 1.6, 0.0)
	g.set_speed(0.0)
	g.set_blood(0.5)
	g.set_eyes(1.0)
	g.set_shiver(1.0)
	g.murmur = false
	await get_tree().process_frame
	var hb: int = g.sk.find_bone("mixamorig_Head")
	g.rotation = Vector3.ZERO
	_hoff = g.global_transform.affine_inverse() * (g.sk.global_transform * g.sk.get_bone_global_pose(hb).origin)
	grab = preload("res://scripts/grab_pose.gd").new()
	g.sk.add_child(grab)
	var face := OmniLight3D.new()
	face.light_color = Color(0.72, 0.8, 1.0)
	face.light_energy = 0.35
	face.omni_range = 1.2
	L.player.cam.add_child(face)
	face.position = Vector3(0, -0.12, 0.0)          # снизу — жутче
	g.set_meta("face_light", face)
	_hold_frame()
	g.visible = true
	g.scream(HOLD)
	L._sfx("sting", 4.0, 1.0, true)
	L._sfx("scream", 4.0, 1.05, true)
	L._sfx("scream", 0.0, 0.8, true)
	p.shake = 1.4
	L.red_flash.color.a = 0.2
	for k in 6:
		await get_tree().create_timer(HOLD / 6.0).timeout
		p.shake = 1.2
		L.red_flash.color.a = 0.16 if k % 2 else 0.05
	L.fade.color.a = 1.0
	L.red_flash.color.a = 0.0
	face.queue_free()
	g.queue_free()
	g = null
	await get_tree().create_timer(0.35).timeout
	L.fade.color.a = 0.0
	p.flicker = 0.4
	if fe != null:
		p.flash_energy = fe
	p.frozen = false
	L.busy = false


## Каждый кадр: лицо в DIST перед камерой, трясётся; руки держат за голову по бокам.
func _hold_frame() -> void:
	if g == null or not is_instance_valid(g):
		return
	var cam: Camera3D = L.player.cam
	var fwd: Vector3 = -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var jit := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.012
	g.rotation = Vector3(0.0, atan2(-fwd.x, -fwd.z), sin(_t * 31.0) * 0.03)
	# от кости головы до глаз: ~0.09 вверх и ~0.1 вперёд
	var want: Vector3 = cam.global_position + fwd * (DIST + 0.1) + Vector3(0, -0.1, 0) + jit
	g.global_position = want - g.global_basis * _hoff
	if grab:
		var c: Vector3 = cam.global_position + fwd * 0.12 + Vector3(0, -0.07, 0)
		grab.targets = {"Left": c + right * 0.15, "Right": c - right * 0.15}
