extends Node
## Режим трейлера: камера сама облетает дом по заготовленным планам, интерфейс скрыт.
## Запуск с записью видео (Godot Movie Maker, ровно 30 кадров/с, скорость ПК не важна):
##   Godot.exe --path . --write-movie trailer/raw.avi --fixed-fps 30 --resolution 1920x1080 -- trailer
## В конце игра закрывается сама; рядом пишется trailer/raw_shots.txt — где какой план (для монтажа).
## Каждый план: подготовка (0.8 с «на разгон», потом вырезается) и сам план — проезд камеры от A к B.

const SETTLE := 0.8
const Y2 := -3.4

var L: Node
var t := 0.0                 ## время записи (сумма delta; при --fixed-fps это ровно кадры/30)
var shots: Array = []
var cur := -1
var shot_t := 0.0
var state := "setup"
var log_lines: PackedStringArray = []
var fired := {}
var cam_from: Array
var cam_to: Array
var dur := 1.0
var ghost: Node3D
var out_dir := ""


func _ready() -> void:
	process_priority = 1000            # после всех остальных — камера ставится последней
	var p = L.player
	p.set_physics_process(false)
	p.frozen = true
	L.busy = true
	L.hud.visible = false
	if OS.get_environment("TRAILER_Q") != "":     # для пробной записи на слабой машине
		preload("res://scripts/settings.gd").set_quality(int(OS.get_environment("TRAILER_Q")))
	out_dir = OS.get_environment("TRAILER_OUT")
	_build_shots()
	for a in OS.get_cmdline_user_args():          # shot=N — записать только один план (проверка)
		if a.begins_with("shot="):
			var n := int(a.substr(5))
			shots = [shots[n]]
	_next()


func _say_hidden() -> void:
	L.hud.visible = false


func _cam(eye: Vector3, look: Vector3) -> void:
	var p = L.player
	var eye_h: float = p.head.global_position.y - p.global_position.y
	p.global_position = eye - Vector3(0, eye_h, 0)
	var d := look - eye
	p.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	p.head.rotation = Vector3(atan2(d.y, Vector2(d.x, d.z).length()), 0, 0)
	p.velocity = Vector3.ZERO


func _ghost(pos: Vector3, face: Vector3, anim := "idle", blood := 0.4) -> Node3D:
	if ghost:
		ghost.queue_free()
	ghost = preload("res://scripts/spirit.gd").new()
	L.add_child(ghost)
	ghost.global_position = pos
	var d := face - pos
	ghost.rotation.y = atan2(d.x, d.z)
	ghost.play(anim, 0.5, 0.0)
	ghost.set_blood(blood)
	return ghost


func _clear_ghost() -> void:
	if ghost:
		ghost.queue_free()
		ghost = null


## план: [имя, подготовка, [глаз A, взгляд A], [глаз B, взгляд B], длительность, фонарь, события [[время, функция]]]
func _build_shots() -> void:
	var Y := Y2
	shots = [
		# 1. прихожая: свет мигает и гаснет (это делает сам уровень на 2.5–3.4 с после старта)
		["hall", func(): L.player.light_on = false,
			[Vector3(0, 1.6, 5.6), Vector3(0, 1.45, 0.0)], [Vector3(0, 1.6, 4.2), Vector3(0, 1.4, 0.0)], 4.6, false,
			[[2.6, func(): L.player.light_on = true]]],
		# 2. гостиная: телевизор шипит в темноте
		["tv", func(): L._tv_power(true),
			[Vector3(0.9, 1.5, -0.4), Vector3(-1.9, 1.2, -3.0)], [Vector3(0.1, 1.45, -1.3), Vector3(-1.9, 1.2, -3.0)], 4.5, true, []],
		# 3. коридор с портретами и свечами
		["corridor", func(): _chapter(2),
			[Vector3(0.45, 1.6, -7.6), Vector3(-0.9, 1.35, -10.5)], [Vector3(0.35, 1.6, -9.6), Vector3(-0.9, 1.35, -13.5)], 4.5, true, []],
		# 4. в конце коридора стоит девочка; свет моргает — и её нет
		["girl_far", func(): _chapter(2); _ghost(Vector3(0, 0, -16.6), Vector3(0, 0, -9)),
			[Vector3(0, 1.6, -9.8), Vector3(0, 1.2, -16.6)], [Vector3(0, 1.6, -11.6), Vector3(0, 1.2, -16.6)], 5.0, true,
			[[3.4, func(): L.player.flicker = 0.5; L._sfx("whisper", -6.0, 0.8)], [3.6, func(): _clear_ghost()]]],
		# 5. чердак: проход между столбами, впереди манекены
		["attic", func(): _attic(),
			[Vector3(0.3, 1.6, -30.8), Vector3(-0.3, 1.1, -36.0)], [Vector3(0.0, 1.55, -32.6), Vector3(-0.5, 1.05, -36.0)], 4.5, true, []],
		# 6. ванная: чёрная вода
		["bath", func(): _chapter(6),
			[Vector3(-0.9, Y + 1.7, -39.6), Vector3(0.3, Y + 0.45, -40.95)], [Vector3(-0.5, Y + 1.55, -40.2), Vector3(0.3, Y + 0.4, -40.95)], 4.0, true, []],
		# 7. спальня бабушки: дверь медленно открывается сама
		["bed_door", func(): _chapter(6); L.bedroom.unlocked = true,
			[Vector3(-16.2, Y + 1.6, -31.2), Vector3(-14.1, Y + 1.1, -28.43)], [Vector3(-15.9, Y + 1.6, -30.4), Vector3(-14.1, Y + 1.1, -28.43)], 5.0, true,
			[[1.2, func(): _creep_open()]]],
		# 8. кровать с балдахином
		["bed", func(): _chapter(6),
			[Vector3(-12.6, Y + 1.6, -28.6), Vector3(-9.0, Y + 0.9, -32.5)], [Vector3(-12.0, Y + 1.6, -29.4), Vector3(-9.3, Y + 0.9, -32.8)], 4.5, true, []],
		# 9. она прямо перед тобой
		["scare", func(): _chapter(6); _clear_ghost(),
			[Vector3(-10.2, Y + 1.6, -30.0), Vector3(-7.0, Y + 1.2, -31.0)], [Vector3(-10.2, Y + 1.6, -30.0), Vector3(-7.4, Y + 1.25, -31.0)], 2.6, true,
			[[1.0, func(): L.player.flicker = 0.25], [1.25, func(): _ghost(Vector3(-9.4, Y, -30.25), Vector3(-10.2, Y, -30.0), "reach", 0.9); L._sfx("sting", 0.0, 0.9); L._sfx("scream", -4.0, 1.1); L.player.shake = 0.8]]],
	]


var _chap := 0
## Перейти в нужную главу один раз (при записи одного плана — тоже).
func _chapter(n: int) -> void:
	if _chap == n:
		return
	_chap = n
	L.jump_chapter(n)
	L.busy = true
	L.hud.visible = false


func _attic() -> void:
	_clear_ghost()
	L.phase = "attic"
	var env: Environment = L.get_node("WorldEnvironment").environment
	env.volumetric_fog_density = 0.018
	env.fog_density = 0.02
	L.player.light_on = true


func _creep_open() -> void:
	var d: Dictionary = L.doors.doors["bed_in"]
	L._sfx3d("creak", d.center, -4.0, 0.6)
	create_tween().tween_property(d.pivot, "rotation:y", d.open * 0.55, 3.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _next() -> void:
	cur += 1
	if cur >= shots.size():
		_finish()
		return
	var s: Array = shots[cur]
	printerr("TRAILER shot ", s[0], " t=", t)
	state = "setup"
	shot_t = 0.0
	fired = {}
	(s[1] as Callable).call()
	L.player.light_on = s[5] if s[0] != "hall" else false
	cam_from = s[2]
	cam_to = s[3]
	dur = s[4]
	_cam(cam_from[0], cam_from[1])


func _process(delta: float) -> void:
	t += delta
	shot_t += delta
	L.hud.visible = false
	L.busy = true
	if cur < 0 or cur >= shots.size():
		return
	var s: Array = shots[cur]
	if state == "setup":
		_cam(cam_from[0], cam_from[1])
		if shot_t >= SETTLE:
			state = "run"
			shot_t = 0.0
			log_lines.append("%s %.3f" % [s[0], t])
		return
	var k := clampf(shot_t / dur, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k) * 0.35 + k * 0.65      # почти равномерно, мягкий старт и финиш
	_cam(cam_from[0].lerp(cam_to[0], e), cam_from[1].lerp(cam_to[1], e))
	for i in (s[6] as Array).size():
		var ev: Array = s[6][i]
		if not fired.has(i) and shot_t >= ev[0]:
			fired[i] = true
			(ev[1] as Callable).call()
	if shot_t >= dur:
		log_lines[log_lines.size() - 1] += " %.3f" % t
		if out_dir != "":
			L.get_viewport().get_texture().get_image().save_png(out_dir.path_join("%02d_%s.png" % [cur, s[0]]))
		_next()


func _finish() -> void:
	var path := OS.get_environment("TRAILER_LOG")
	if path == "":
		path = "res://trailer/raw_shots.txt"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if not FileAccess.file_exists(path.get_base_dir().path_join(".gdignore")):      # Godot не трогает видео
		FileAccess.open(path.get_base_dir().path_join(".gdignore"), FileAccess.WRITE)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines) + "\n")
	printerr("TRAILER DONE ", log_lines)
	get_tree().quit()
