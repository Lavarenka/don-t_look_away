extends Node
## Катсцена «Письмо Веры» (спальня бабушки). Под ключиком у зеркала — сложенный лист.
## Миша поднимает его к свече и читает вслух; камера смотрит в зеркало над письмом.
## С каждой строкой в отражении за его спиной ближе стоит Вера (только в зеркале). Фокус уходит
## с письма на зеркало. На «свободна» — тишина, её шёпот у самого уха, Миша оборачивается —
## она прямо перед лицом и кричит. Темнота. Свет возвращается — никого, письмо на полу.
## Субтитры — строки письма; озвучка подхватится сама из voice/<язык>/VL_xx.ogg, когда будет.

const LINES := ["VL_01", "VL_02", "VL_03", "VL_04", "VL_05", "VL_06", "VL_07"]
const MIN_SEC := [2.6, 3.4, 4.6, 4.4, 3.0, 4.0, 4.2]
## где стоит Вера в отражении после каждой строки (м за спиной; 0 — ещё нет)
const VERA_AT := [0.0, 3.2, 2.4, 1.7, 1.15, 0.7, 0.42]

var L: Node
var R: Node
var letter: MeshInstance3D
var vera: Node3D                  ## настоящая — для разворота
var bars: Array[ColorRect] = []
var black: ColorRect
var heart: AudioStreamPlayer
var _tremble := 0.0
var _t := 0.0
var _base := Vector3(-0.11, -0.225, -0.44)
var _playing := false
var note_small: MeshInstance3D    ## сложенный лист под ключиком (виден вместе с ключом)


func setup(level: Node, room: Node) -> void:
	L = level
	R = room
	vera = preload("res://scripts/vera.gd").new()
	L.add_child(vera)
	vera.visible = false
	# сложенное втрое письмо — под ключом на комоде
	note_small = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 0.004, 0.145)
	note_small.mesh = bm
	var nm := StandardMaterial3D.new()
	nm.albedo_color = Color(0.78, 0.71, 0.57)
	nm.roughness = 0.95
	note_small.material_override = nm
	L.add_child(note_small)
	var kp: Vector3 = R.key_node.global_position
	note_small.global_position = kp + Vector3(0, -0.002, 0)
	note_small.rotation.y = 0.9
	note_small.visible = false


func _tex() -> Texture2D:
	var l := TranslationServer.get_locale().substr(0, 2)
	var p := "res://textures/letter/letter_%s.png" % ("ru" if l == "ru" else "en")
	return load(p)


func _make_letter() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.2, 0.283)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	pm.orientation = PlaneMesh.FACE_Z
	m.mesh = pm
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
void vertex() {
	// лист чуть выгнут и не до конца расправлен по сгибам
	VERTEX.z += 0.012 * sin(UV.x * 3.14159) - 0.004 * abs(sin(UV.y * 3.14159 * 3.0));
}
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	ALBEDO = (FRONT_FACING ? c : c * vec3(0.9, 0.86, 0.78)) * 0.62;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	BACKLIGHT = vec3(0.08, 0.06, 0.04);  // свеча чуть просвечивает бумагу
}
"""
	sm.shader = sh
	sm.set_shader_parameter("tex", _tex())
	m.material_override = sm
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.layers = R.HELD_LAYER
	return m


## Сколько держать строку: не меньше заданного, а если есть озвучка — по её длине.
func _dur(key: String, i: int) -> float:
	return _vdur(key, MIN_SEC[i])


func _vdur(key: String, min_sec: float) -> float:
	var st: AudioStream = preload("res://scripts/settings.gd").voice(key)
	var d := min_sec
	if st:
		d = maxf(d, st.get_length() + 0.5)
	return d


func _bars(on: bool) -> void:
	if bars.is_empty():
		var layer := CanvasLayer.new()
		layer.layer = 1                       # под субтитрами (они на слое HUD)
		add_child(layer)
		for top in [true, false]:
			var r := ColorRect.new()
			r.color = Color.BLACK
			r.anchor_left = 0.0
			r.anchor_right = 1.0
			r.anchor_top = 0.0 if top else 1.0
			r.anchor_bottom = 0.0 if top else 1.0
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(r)
			bars.append(r)
		var l2 := CanvasLayer.new()
		l2.layer = 5                          # затемнение — поверх всего
		add_child(l2)
		black = ColorRect.new()
		black.color = Color(0, 0, 0, 0)
		black.set_anchors_preset(Control.PRESET_FULL_RECT)
		black.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l2.add_child(black)
	var h: float = get_viewport().get_visible_rect().size.y * (0.11 if on else 0.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(bars[0], "offset_bottom", h, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bars[1], "offset_top", -h, 1.2).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	if letter == null or not _playing:
		return
	_t += delta
	# руки дрожат — к концу сильнее
	var a := 0.0015 + _tremble * 0.006
	letter.position = _base + Vector3(sin(_t * 23.0) * a + sin(_t * 7.1) * a * 0.6, sin(_t * 19.0 + 1.0) * a, 0.0)
	letter.rotation.z = sin(_t * 11.0) * a * 2.0


## Повернуть взгляд игрока к точке за sec секунд (плавно, «камерой оператора»).
func _look(p: Vector3, sec: float, trans := Tween.TRANS_SINE) -> Tween:
	var pl = L.player
	var d: Vector3 = p - pl.cam.global_position
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	var tw := create_tween().set_parallel()
	tw.tween_property(pl, "rotation:y", pl.rotation.y + angle_difference(pl.rotation.y, yaw), sec).set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(pl.head, "rotation:x", pitch, sec).set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	return tw


func _behind(dist: float, side := 0.0) -> Vector3:
	var pl = L.player
	var back: Vector3 = -pl.forward()
	back.y = 0.0
	back = back.normalized()
	var right := Vector3.UP.cross(back) * -1.0      # правое плечо игрока
	return Vector3(pl.global_position.x, R.Y2, pl.global_position.z) + back * dist + right * side


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func play() -> void:
	if _playing:
		return
	_playing = true
	note_small.visible = false
	var pl = L.player
	L.busy = true
	pl.frozen = true
	_bars(true)
	# взгляд — в зеркало, чуть ниже центра: письмо внизу кадра, отражение над ним
	await _look(R.glass.global_position + Vector3(0, 0.1, 0), 1.6).finished
	# лист поднимается к свече
	letter = _make_letter()
	pl.cam.add_child(letter)
	letter.position = _base + Vector3(0, -0.25, 0.05)
	letter.rotation = Vector3(-0.32, 0.05, 0)
	L._sfx("page", -6.0, 0.9, true)
	var tw := create_tween()
	tw.tween_property(letter, "position", _base, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# фокус — на письме, зеркало мягко размыто
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_far_enabled = true
	attr.dof_blur_far_distance = 0.9
	attr.dof_blur_far_transition = 0.6
	attr.dof_blur_near_enabled = false
	attr.dof_blur_amount = 0.03
	var old_attr: CameraAttributes = pl.cam.attributes
	pl.cam.attributes = attr
	# сердце: медленно, потом чаще
	heart = AudioStreamPlayer.new()
	heart.stream = load("res://audio/heartbeat.wav")
	heart.volume_db = -30.0
	heart.pitch_scale = 0.8
	add_child(heart)
	heart.finished.connect(func(): if _playing: heart.play())
	await _wait(1.3)
	var lamp: OmniLight3D = R.B.lamps[R.NIGHT_LAMP]
	var lamp_e := lamp.light_energy
	for i in LINES.size():
		var key: String = LINES[i]
		var d := _dur(key, i)
		L._say(key, d)
		_tremble = float(i) / LINES.size()
		match i:
			1:
				heart.play()
				create_tween().tween_property(heart, "volume_db", -18.0, 4.0)
				_vera_mirror(VERA_AT[1], false)
			2:
				_vera_mirror(VERA_AT[2], false)
				R.gutter_out(0.5)
			3:
				_vera_mirror(VERA_AT[3], false)
				L._sfx3d("far_whisper", _behind(2.0) + Vector3(0, 1.5, 0), -16.0, 0.8, true)
				create_tween().tween_property(lamp, "light_energy", lamp_e * 0.35, 3.0)
			4:
				_vera_mirror(VERA_AT[4], true)
				heart.pitch_scale = 0.95
				create_tween().tween_property(heart, "volume_db", -12.0, 3.0)
			5:
				_vera_mirror(VERA_AT[5], true)
				heart.pitch_scale = 1.15
				L._sfx("tinnitus", -24.0, 1.0, true)
				# переводим фокус: письмо уходит в размытие, в зеркале — резко она
				var ft := create_tween().set_parallel()
				ft.tween_property(attr, "dof_blur_far_distance", 6.0, 1.6)
				attr.dof_blur_near_enabled = true
				attr.dof_blur_near_distance = 0.02
				attr.dof_blur_near_transition = 0.25
				ft.tween_property(attr, "dof_blur_near_distance", 0.6, 1.6)
				ft.tween_property(attr, "dof_blur_amount", 0.06, 1.6)
			6:
				_vera_mirror(VERA_AT[6], true)
				R.vera_m.set_mouth(0.35, 2.5)
				create_tween().tween_property(heart, "volume_db", -60.0, d * 0.8)
				create_tween().tween_property(lamp, "light_energy", lamp_e * 0.1, d)
		await _wait(d)
	# тишина. её дыхание у самого уха, шёпот
	heart.stop()
	_tremble = 1.4
	await _wait(1.2)
	L._sfx3d("breath_dark", _behind(0.35) + Vector3(0, 1.55, 0), -6.0, 0.85, true)
	await _wait(0.9)
	var d9 := _vdur("VL_09", 2.6)
	L._say("VL_09", d9)
	L._sfx3d("whisper_harsh", _behind(0.3) + Vector3(0, 1.6, 0), -4.0, 0.8, true)
	await _wait(d9)
	var d8 := _vdur("VL_08", 1.8)
	L._say("VL_08", d8)
	await _wait(d8 * 0.6)
	# письмо падает — разворот
	var drop := create_tween()
	drop.tween_property(letter, "position", _base + Vector3(0.05, -0.5, 0.1), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	L._sfx("page", -4.0, 1.2, true)
	R.vera_m.visible = false
	attr.dof_blur_near_enabled = false
	attr.dof_blur_far_enabled = false
	var back := _behind(0.85, 0.12)
	vera.global_position = back
	var dv: Vector3 = pl.global_position - back
	vera.rotation.y = atan2(dv.x, dv.z)
	vera.freeze("idle", 0.4)
	vera.visible = true
	await get_tree().process_frame
	var face: Vector3 = back + Vector3(0, 1.5, 0)
	var hb: int = vera.sk.find_bone("mixamorig_Head")
	if hb >= 0:
		face = vera.sk.global_transform * vera.sk.get_bone_global_pose(hb).origin + Vector3(0, 0.12, 0)
	await _look(face, 0.32, Tween.TRANS_QUAD).finished
	# крик в лицо
	vera.scream(0.9)
	L._sfx("scream", 0.0, 0.8, true)
	L._sfx("sting", -2.0, 1.0, true)
	pl.shake = 0.8
	R.gutter_out(1.5)
	await _wait(0.75)
	# резкая темнота
	black.color.a = 1.0
	vera.visible = false
	lamp.light_energy = 0.0
	letter.queue_free()
	letter = null
	L._say("", 0.1)
	await _wait(1.4)
	L._sfx("breath_dark", -10.0, 0.7, true)
	await _wait(1.8)
	# свет возвращается: никого, взгляд опущен — письмо лежит на полу у ног
	pl.head.rotation.x = -0.75
	_floor_letter()
	lamp.light_energy = lamp_e
	pl.cam.attributes = old_attr
	R.gutter_out(1.0)
	create_tween().tween_property(black, "color:a", 0.0, 2.2)
	_bars(false)
	await _wait(1.6)
	_playing = false
	pl.frozen = false
	L.busy = false
	L.inv.add_note("VL_NOTE")
	L._set_objective("BR_DONE")


## Вера в зеркале (слой «только в отражении»), стоит за спиной на расстоянии dist.
func _vera_mirror(dist: float, reach: bool) -> void:
	var vm: Node3D = R.vera_m
	var p := _behind(dist, 0.3 * clampf(dist, 0.0, 1.0) + 0.3)     # за правым плечом — в зеркале справа от письма
	vm.global_position = p
	var d: Vector3 = L.player.global_position - p
	vm.rotation.y = atan2(d.x, d.z)
	vm.play("idle", 0.4, 0.0)
	vm.reach(reach)
	vm.visible = true


func _floor_letter() -> void:
	var m := _make_letter()
	m.layers = 1
	L.add_child(m)
	var p: Vector3 = L.player.global_position
	var fw: Vector3 = L.player.forward()
	fw.y = 0.0
	m.global_position = Vector3(p.x, R.Y2 + 0.004, p.z) + fw.normalized() * 0.75
	m.rotation = Vector3(-PI / 2, randf_range(0, TAU), 0)
