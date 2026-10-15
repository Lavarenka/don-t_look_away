extends Node
## Овальный портрет в торце коридора спальни. Сначала в раме — фотография Веры (как в холле).
## Посмотрел на неё, а когда отвернулся (уже со свечой) — в раме сама старуха, и время от времени,
## пока не смотришь, она в раме в другой позе: смотрит, склонила голову, прильнула к стеклу, тянет руку,
## отвернулась, раскрыла рот. Подошёл к портрету вплотную — она уже стоит у тебя за спиной и ждёт;
## обернёшься — закричит и исчезнет. Рама после этого пустая.
## Старуха в раме — живой рендер модели Веры в своём мире (SubViewport), перерисовывается раз на позу.

const C := Vector3(-15.16, -3.4 + 1.665, -27.585)   ## центр овала (между холстом и кромкой рамы)
const SIZE := Vector2(0.70, 0.97)                    ## проём рамы (край прячется под раму)
const BEHIND := 1.8                                 ## на каком расстоянии за спиной встаёт
const NEAR := 1.35                                   ## «вплотную» — по полу от портрета
const POSES := ["stare", "tilt", "close", "reach", "away", "mouth"]

var L: Node
var R: Node                     ## vera_room.gd
var plane: MeshInstance3D
var mat: ShaderMaterial
var vp: SubViewport
var pcam: Camera3D
var pvera: Node3D               ## Вера в раме (свой мир)
var vera: Node3D                ## Вера за спиной (в доме)
var stage := 0                  ## 0 — фото Веры, 1 — старуха в раме, 2 — ждёт за спиной, 3 — всё, рама пуста
var seen_t := 0.0               ## сколько смотрел на фото
var pose_t := 4.0
var look_t := 0.0
var near_t := 0.0
var last_pose := ""


func setup(level: Node, room: Node) -> void:
	L = level
	R = room
	plane = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = SIZE
	plane.mesh = q
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/portrait.gdshader")
	mat.set_shader_parameter("img", preload("res://textures/portrait_vera.png"))
	mat.set_shader_parameter("sepia", 0.3)
	plane.material_override = mat
	L.add_child(plane)
	plane.global_position = C
	plane.rotation.y = PI                            # лицом в коридор (на -Z)
	# мир портрета: Вера, камера, свет сбоку, тёмный фон
	vp = SubViewport.new()
	vp.size = Vector2i(360, 500)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	pcam = Camera3D.new()
	pcam.fov = 32.0
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.05, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.42, 0.34)
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	pcam.environment = env
	vp.add_child(pcam)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.86, 0.66)
	key.light_energy = 1.2
	key.rotation = Vector3(-0.5, -0.75, 0)            # сверху-сбоку: резкая тень на половине лица
	vp.add_child(key)
	pvera = preload("res://scripts/vera.gd").new()
	vp.add_child(pvera)
	# та, что встанет за спиной
	vera = preload("res://scripts/vera.gd").new()
	L.add_child(vera)
	vera.visible = false


func _looking(max_d: float, ang: float) -> bool:
	var p = L.player
	var to: Vector3 = C - p.cam.global_position
	return to.length() < max_d and p.forward().angle_to(to) < ang


func _process(delta: float) -> void:
	if not R.started or L.busy:
		return
	var p = L.player
	match stage:
		0:
			if _looking(4.5, 0.45):
				seen_t += delta
			elif seen_t > 1.0 and R.lit and not _looking(9.0, 0.9):
				# отвернулся со свечой — в раме уже не фотография
				stage = 1
				mat.set_shader_parameter("img", vp.get_texture())
				mat.set_shader_parameter("sepia", 0.85)
				_pose("stare")
		1:
			# позы меняются, пока не смотришь; если смотришь долго — меняется с «миганием»
			pose_t -= delta
			var looking := _looking(9.0, 0.7)
			look_t = look_t + delta if looking else 0.0
			if pose_t <= 0.0 and (not looking or look_t > 7.0):
				var opts: Array = POSES.duplicate()
				opts.erase(last_pose)
				if looking:
					_blink()
				_pose(opts.pick_random())
				pose_t = randf_range(5.0, 9.0)
				look_t = 0.0
			# подошёл вплотную и смотрит на портрет — она уже за спиной
			var d := Vector2(p.global_position.x - C.x, p.global_position.z - C.z).length()
			near_t = near_t + delta if d < NEAR and _looking(2.5, 0.6) else 0.0
			if near_t > 0.5:
				_behind()
		2:
			var to: Vector3 = vera.global_position - p.global_position
			to.y = 0.0
			var fw: Vector3 = p.forward()
			fw.y = 0.0
			# ждёт: стоит и смотрит в затылок; обернулся (или попятился в неё) — крик
			if fw.angle_to(to) < 0.75 or to.length() < 0.45:
				_scream()


## Поза старухи в раме; кадр рисуется один раз, когда поза встала.
func _pose(n: String) -> void:
	last_pose = n
	pvera.visible = true
	pvera.rotation.y = 0.0
	pvera.reach(false)
	pvera.pose.target = {}
	pvera.set_mouth(0.0)
	var dist := 1.25
	var off := Vector3(0, 0.06, 0)
	match n:
		"stare":
			pvera.freeze("idle", randf_range(0.0, 2.0))
		"tilt":
			pvera.freeze("idle", randf_range(0.0, 2.0))
			pvera.pose.target = {"Neck": Vector3(0, 0, 0.2), "Head": Vector3(0, 0, 0.4)}
		"close":
			pvera.freeze("idle", 0.5)
			pvera.pose.target = {"Head": Vector3(0.25, 0, 0)}
			pvera.set_mouth(0.2)
			dist = 0.72
			off = Vector3(0, 0.09, 0)
		"reach":
			pvera.freeze("idle", 1.0)
			pvera.reach(true)
			dist = 1.75
			off = Vector3(0, -0.15, 0)
		"away":
			pvera.freeze("idle", 1.5)
			pvera.rotation.y = PI
		"mouth":
			pvera.freeze("idle", 1.2)
			pvera.set_mouth(0.75)
			pvera.pose.target = {"Head": Vector3(-0.15, 0, 0.0)}
		"empty":
			pvera.visible = false
	pvera.pose.snap()
	# скелет должен встать в позу, потом — один кадр
	await get_tree().process_frame
	await get_tree().process_frame
	var head := Vector3(0, 1.55, 0)
	var hb: int = pvera.sk.find_bone("mixamorig_Head")
	if hb >= 0:
		head = pvera.sk.global_transform * pvera.sk.get_bone_global_pose(hb).origin
	var aim := head + off
	pcam.global_position = aim + Vector3(0, 0.02, dist)
	pcam.look_at(aim)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Холст на миг темнеет (свет дрогнул), и в этот миг она уже по-другому.
func _blink() -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("dark", v), 1.0, 0.05, 0.08)
	tw.tween_interval(0.25)
	tw.tween_method(func(v: float): mat.set_shader_parameter("dark", v), 0.05, 1.0, 0.3)
	R.gutter_out(0.4)
	L._sfx3d("creak", C, -12.0, 1.3, true)


## Она встаёт за спиной — близко, лицом к игроку. Рама в этот миг уже пустая.
func _behind() -> void:
	stage = 2
	var p = L.player
	var back: Vector3 = -p.forward()
	back.y = 0.0
	back = back.normalized()
	# за спиной, на расстоянии ~1.8 м; если сзади стена/мебель — чуть ближе, но не вплотную
	var dist := BEHIND
	var from: Vector3 = p.global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + back * (BEHIND + 0.4))
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		dist = clampf(from.distance_to(hit.position) - 0.4, 0.9, BEHIND)
	var at: Vector3 = Vector3(p.global_position.x, -3.4, p.global_position.z) + back * dist
	vera.global_position = at
	var d: Vector3 = p.global_position - at
	vera.rotation.y = atan2(d.x, d.z)
	vera.freeze("idle", 0.3)
	vera.set_speed(0.25)
	vera.visible = true
	_pose("empty")
	# едва слышно — дыхание прямо за спиной
	L._sfx3d("breath_dark", at + Vector3(0, 1.5, 0), -14.0, 0.9, true)


func _scream() -> void:
	stage = 3
	var p = L.player
	vera.set_speed(1.0)
	vera.scream(0.5)
	L._sfx("scream", -2.0, 0.85, true)
	L._sfx3d("whoosh", vera.global_position + Vector3(0, 1.4, 0), -4.0, 0.7, true)
	p.shake = 0.5
	R.gutter_out(0.9)
	await get_tree().create_timer(0.55).timeout
	vera.visible = false
	vera.set_mouth(0.0)
