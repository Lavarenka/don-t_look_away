extends Node3D
## Вступительная заставка: ночь, дождь, лесная дорога, машина едет к бабушкиному дому.
## Вся сцена собирается кодом: дорога, лес, машина с фарами, дождь, камера.

const ROAD_START := 30.0      ## лес вдоль дороги: от z = ROAD_START ...
const ROAD_END := -246.0      ## ... до z = ROAD_END (машина едет в сторону −Z), дальше — двор и дом
const SPEED := 7.0            ## м/с
const HOUSE_Z := -270.0       ## дом в конце дороги
const ATTIC_WIN := Vector3(3.865, 9.0, 4.05)   ## чердачное окно во фронтоне: центр окна (относительно дома)
const GAME_MENU := "res://scenes/menu.tscn"
const SETTINGS = preload("res://scripts/settings.gd")
const FLICKER = preload("res://scripts/flicker.gd")

var car: Node3D
var car_model: Node3D
var wheels: Array[Node3D] = []
var cam: Camera3D
var t := 0.0
var rng := RandomNumberGenerator.new()
var _mat_cache := {}
var _last_rot := 0.0
var speed := SPEED
var shot := ""
var girl: Node3D
var spots: Array[SpotLight3D] = []
var head_glow: Array[StandardMaterial3D] = []
var lights_on := true
var radio: AudioStreamPlayer
var engine_snd: AudioStreamPlayer3D
var window_light: OmniLight3D
var black: ColorRect
var title: Label
var sub: Label
var bigtitle: Label
var events := {}
var moon: DirectionalLight3D
var flash_rect: ColorRect
var loops := {}              ## фоновые петли: имя → AudioStreamPlayer
var finished := false


func _voice(key: String) -> void:
	if key == "":
		return
	var st := SETTINGS.voice(key)
	if st:
		var a := AudioStreamPlayer.new()
		a.stream = st
		add_child(a)
		a.play()
		a.finished.connect(a.queue_free)


func _ready() -> void:
	SETTINGS.apply_lang()
	preload("res://scripts/fonts.gd").apply_default()
	rng.seed = 7
	_environment()
	_ground()
	_forest()
	_car()
	_rain()
	_house()
	_girl()
	_audio()
	cam = Camera3D.new()
	cam.fov = 58.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	_post()
	_ui()
	car.position.z = 12.0


# ---------------- окружение ----------------
func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.38, 0.5)
	env.ambient_light_energy = 0.08
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.35
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.11, 0.125, 0.16)
	env.fog_density = 0.032
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.022
	env.volumetric_fog_albedo = Color(0.75, 0.8, 0.85)
	env.volumetric_fog_anisotropy = 0.7
	env.volumetric_fog_length = 70.0
	env.ssao_enabled = true
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.7
	env.adjustment_contrast = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# луна сквозь облака
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 0.9
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-35, 30, 0)
	moon.light_volumetric_fog_energy = 1.2
	add_child(moon)


func _noise_tex(freq: float, seed_: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.seed = seed_
	n.fractal_octaves = 5
	var tx := NoiseTexture2D.new()
	tx.noise = n
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.35, 0.35, 0.35))
	ramp.set_color(1, Color(1, 1, 1))
	tx.color_ramp = ramp
	tx.seamless = true
	tx.width = 512
	tx.height = 512
	return tx


func _ground() -> void:
	var length := ROAD_START - ROAD_END + 60.0
	var cz := (ROAD_START + ROAD_END) / 2.0
	# лесная подстилка: тёмная хвоя и мох
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(90, length)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.42, 0.38, 0.3)
	gm.albedo_texture = _noise_tex(0.05, 3)
	gm.roughness = 0.9
	gm.uv1_scale = Vector3(18, 120, 1)
	g.material_override = gm
	g.position.z = cz
	add_child(g)
	# грунтовая дорога: мокрая грязь с лужами (низкая шероховатость — блестит в свете фар)
	var r := MeshInstance3D.new()
	var rm := PlaneMesh.new()
	rm.size = Vector2(4.6, length)
	r.mesh = rm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.55, 0.47, 0.38)
	mm.albedo_texture = _noise_tex(0.09, 11)
	mm.roughness_texture = _noise_tex(0.03, 21)
	mm.roughness = 0.55
	mm.metallic = 0.15
	mm.uv1_scale = Vector3(1, 60, 1)
	r.material_override = mm
	r.position = Vector3(0, 0.02, cz)
	add_child(r)


# ---------------- лес ----------------
func _twig_mat(kind: String) -> Material:
	# крона из карточек-веточек: текстура с прозрачностью (альфа-маска), видны с обеих сторон
	if _mat_cache.has(kind):
		return _mat_cache[kind]
	var m := StandardMaterial3D.new()
	var tex := "res://models/forest/fir/textures/fir_sapling_medium_twigs_rgba_1k.png"
	m.albedo_texture = load(tex)
	m.albedo_color = Color(0.7, 0.75, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	_mat_cache[kind] = m
	return m


func _plant(path: String, kind: String, pos: Vector3, s: float) -> void:
	# дерево = ствол с ветками (упрощённый) + крона из карточек-веточек
	for p in [path, path.replace(".glb", "_crown.glb")]:
		var tr: Node3D = (load(p) as PackedScene).instantiate()
		tr.position = pos
		tr.rotation.y = rng.randf() * TAU if p == path else _last_rot
		_last_rot = tr.rotation.y
		tr.scale = Vector3.ONE * s
		add_child(tr)
		for mi in tr.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi
			m.visibility_range_end = 75.0           # дальше — всё равно туман
			m.visibility_range_end_margin = 10.0
			m.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			if p != path:
				m.material_override = _twig_mat(kind)
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _forest() -> void:
	var pines := ["res://models/forest/pine/pine0.glb", "res://models/forest/pine/pine1.glb", "res://models/forest/pine/pine2.glb"]
	var firs := ["res://models/forest/fir/fir0.glb", "res://models/forest/fir/fir1.glb", "res://models/forest/fir/fir2.glb"]
	var z := ROAD_START
	while z > ROAD_END:
		for side in [-1, 1]:
			# первый ряд — ёлки у самой обочины, дальше — высокие сосны
			_plant(firs[rng.randi() % 3], "fir", Vector3(side * rng.randf_range(4.0, 7.0), 0, z + rng.randf_range(-2, 2)), rng.randf_range(0.6, 1.0))
			_plant(pines[rng.randi() % 3], "pine", Vector3(side * rng.randf_range(8.0, 13.0), 0, z + rng.randf_range(-3, 3)), rng.randf_range(0.8, 1.15))
			if rng.randf() < 0.6:
				_plant(pines[rng.randi() % 3], "pine", Vector3(side * rng.randf_range(15.0, 24.0), 0, z + rng.randf_range(-4, 4)), rng.randf_range(0.8, 1.2))
		z -= rng.randf_range(5.0, 8.0)


# ---------------- машина ----------------
func _car() -> void:
	car = Node3D.new()
	add_child(car)
	car_model = (load("res://models/forest/car/sedan.glb") as PackedScene).instantiate()
	car.add_child(car_model)
	# где у модели перёд: там, где стёкла фар
	var front_z := 0.0
	for mi in car_model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for k in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(k)
			if src and src.resource_name.findn("headlight") >= 0:
				front_z = (m.global_transform * m.get_aabb()).get_center().z
				var glow := StandardMaterial3D.new()
				glow.albedo_color = Color(1, 0.95, 0.8)
				glow.emission_enabled = true
				glow.emission = Color(1, 0.9, 0.7)
				glow.emission_energy_multiplier = 6.0
				m.set_surface_override_material(k, glow)
				head_glow.append(glow)
	if front_z > 0.0:
		car_model.rotation.y = PI          # разворачиваем передом в −Z
	for n in car_model.find_children("wheel_*", "Node3D", true, false):
		if not (n as Node3D) is MeshInstance3D:
			wheels.append(n)
	# фары
	for x in [-0.62, 0.62]:
		var sp := SpotLight3D.new()
		sp.light_color = Color(1, 0.92, 0.75)
		sp.light_energy = 22.0
		sp.spot_range = 40.0
		sp.spot_angle = 26.0
		sp.spot_attenuation = 0.8
		sp.shadow_enabled = x < 0
		sp.light_volumetric_fog_energy = 1.4
		sp.position = Vector3(x, 0.85, -2.8)
		sp.rotation_degrees = Vector3(-6, 0, 0)
		car.add_child(sp)
		spots.append(sp)
	var tail := OmniLight3D.new()
	tail.light_color = Color(1, 0.1, 0.05)
	tail.light_energy = 0.8
	tail.omni_range = 3.0
	tail.position = Vector3(0, 0.6, 3.6)
	car.add_child(tail)
	car.position = Vector3(0.4, 0, 0)


# ---------------- дождь ----------------
func _rain() -> void:
	var p := GPUParticles3D.new()
	p.amount = 6000
	p.lifetime = 1.2
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-20, -15, -20), Vector3(40, 30, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 1, 16)
	pm.direction = Vector3(0.08, -1, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 18.0
	pm.initial_velocity_max = 22.0
	pm.gravity = Vector3(0, -9.8, 0)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.006, 0.45)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(0.75, 0.8, 0.9, 0.12)
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	qm.billboard_keep_scale = true
	q.material = qm
	p.draw_pass_1 = q
	p.name = "Rain"
	add_child(p)


# ---------------- звук ----------------
func _audio() -> void:
	# лимитер на общем выходе: громкие удары не «хрипят»
	SETTINGS.master_fx(false)
	# звуки — из бесплатного набора Sonniss GDC 2026 (см. CREDITS.txt), сведены скриптом gen_intro_audio.py
	_loop("storm", -6.0)
	_loop("wind", -12.0)
	_loop("drone", -60.0)
	radio = _loop("radio", -60.0, false)
	var eng := AudioStreamPlayer3D.new()
	engine_snd = eng
	var st: AudioStreamOggVorbis = load("res://audio/intro/i_engine.ogg")
	st.loop = true
	eng.stream = st
	eng.volume_db = 0.0
	eng.unit_size = 7.0
	car.add_child(eng)
	eng.play()


## Фоновая петля (дождь, ветер, гул).
func _loop(n: String, db: float, start := true) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	var st: AudioStreamOggVorbis = load("res://audio/intro/i_%s.ogg" % n)
	st.loop = true
	a.stream = st
	a.volume_db = db
	add_child(a)
	if start:
		a.play()
	loops[n] = a
	return a


## Плавно изменить громкость петли.
func _vol(n: String, db: float, sec: float) -> void:
	if loops.has(n):
		if not loops[n].playing:
			loops[n].play()
		create_tween().tween_property(loops[n], "volume_db", db, sec)


## Разовый звук заставки.
func _hit(n: String, db := 0.0, from := 0.0) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	a.stream = load("res://audio/intro/i_%s.ogg" % n)
	a.volume_db = db
	add_child(a)
	a.finished.connect(a.queue_free)
	a.play(from)
	loops["_" + n] = a
	return a


## Молния: вспышка неба и экрана.
func _flash(power := 1.0) -> void:
	if flash_rect == null:
		var layer := CanvasLayer.new()
		layer.layer = 9
		add_child(layer)
		flash_rect = ColorRect.new()
		flash_rect.color = Color(0.75, 0.82, 1.0, 0.0)
		flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(flash_rect)
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.55 * power, 0.04)
	tw.tween_property(flash_rect, "color:a", 0.08 * power, 0.08)
	tw.tween_property(flash_rect, "color:a", 0.4 * power, 0.05)
	tw.tween_property(flash_rect, "color:a", 0.0, 0.5)
	var tm := create_tween()
	tm.tween_property(moon, "light_energy", 9.0 * power, 0.05)
	tm.tween_property(moon, "light_energy", 0.9, 0.7)


# ---------------- «камера» поверх картинки ----------------
func _post() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/grain.gdshader")
	r.material = sm
	layer.add_child(r)


# ---------------- дом в конце дороги ----------------
func _mat(albedo: Color, tex: String = "", scale := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	if tex != "":
		m.albedo_texture = load(tex)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * scale
	m.roughness = 0.85
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _house() -> void:
	var h := Node3D.new()
	h.position = Vector3(0, 0, HOUSE_Z)
	add_child(h)
	var dark := _mat(Color(0.12, 0.1, 0.09), "res://textures/servant_wood_basecolor.jpg", 0.7)
	# двухэтажный заброшенный дом (Sketchfab «Abandoned House», Leon.com, CC BY 4.0)
	const HS := 1.25
	var model: Node3D = (load("res://models/forest/house/house.gltf") as PackedScene).instantiate()
	model.scale = Vector3.ONE * HS
	model.position = Vector3(-4.29 * HS, 0, -1.0 - 4.29 * HS)
	h.add_child(model)
	# темнее и грязнее: ночью облезлая белая краска не должна светиться
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		for si in mi.get_surface_override_material_count():
			var src: Material = mi.mesh.surface_get_material(si)
			if src is BaseMaterial3D:
				var m2: BaseMaterial3D = src.duplicate()
				m2.albedo_color = m2.albedo_color * Color(0.55, 0.52, 0.5)
				mi.set_surface_override_material(si, m2)
	# чердачное окошко во фронтоне: внутри горит свеча
	var lit := _mat(Color(1, 0.6, 0.3))
	lit.emission_enabled = true
	lit.emission = Color(1, 0.55, 0.25)
	lit.emission_energy_multiplier = 0.9
	# два стекла — каждое ровно в своей раме (верхнее стекло выступает сильнее нижнего)
	_box(Vector3(0.72, 0.82, 0.01), Vector3(ATTIC_WIN.x, 9.5, 4.072), lit, h)
	_box(Vector3(0.72, 0.82, 0.01), Vector3(ATTIC_WIN.x, 8.5, 4.015), lit, h)
	window_light = OmniLight3D.new()
	window_light.light_color = Color(1, 0.6, 0.3)
	window_light.light_energy = 0.6
	window_light.omni_range = 5.0
	window_light.position = ATTIC_WIN + Vector3(0, 0, 0.6)
	h.add_child(window_light)
	# покосившийся забор с калиткой
	var z := HOUSE_Z + 9.0
	var x := -14.0
	while x < 14.0:
		if abs(x) > 1.8:
			var pk := _box(Vector3(0.12, rng.randf_range(1.1, 1.4), 0.05), Vector3(x, 0.6, z), dark)
			pk.rotation.z = rng.randf_range(-0.08, 0.08)
		x += 0.28
	for xx in [-14.0, 14.0]:
		_box(Vector3(0.05, 0.08, 1), Vector3(0, 0, 0), dark).visible = false
	_box(Vector3(12.2, 0.08, 0.06), Vector3(-7.9, 0.9, z - 0.05), dark)
	_box(Vector3(12.2, 0.08, 0.06), Vector3(7.9, 0.9, z - 0.05), dark)
	_box(Vector3(12.2, 0.08, 0.06), Vector3(-7.9, 0.35, z - 0.05), dark)
	_box(Vector3(12.2, 0.08, 0.06), Vector3(7.9, 0.35, z - 0.05), dark)
	# деревья за домом и по бокам двора
	for i in 18:
		var side := -1 if i % 2 == 0 else 1
		_plant("res://models/forest/pine/pine%d.glb" % (i % 3), "pine",
			Vector3(side * rng.randf_range(9.0, 26.0), 0, HOUSE_Z - rng.randf_range(-8.0, 22.0)), rng.randf_range(0.9, 1.2))


# ---------------- девочка у обочины ----------------
func _girl() -> void:
	girl = Node3D.new()
	var sp: Node3D = preload("res://scripts/spirit.gd").new()     # девочка-призрак (CC BY)
	girl.add_child(sp)
	girl.visible = false
	add_child(girl)
	sp.play_from("idle", 1.0, 1.0)
	sp.set_blood(0.3)
	sp.float_h = 0.12


# ---------------- титры и субтитры ----------------
func _label(sz: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	black = ColorRect.new()
	black.color = Color(0, 0, 0, 1)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(black)
	title = _label(34, Color(0.85, 0.82, 0.76))
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(title)
	sub = _label(24, Color(0.92, 0.9, 0.85))
	sub.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sub.offset_top = -140
	sub.offset_bottom = -50
	sub.offset_left = 140
	sub.offset_right = -140
	layer.add_child(sub)
	bigtitle = _label(62, Color(0.92, 0.88, 0.8))
	bigtitle.set_anchors_preset(Control.PRESET_FULL_RECT)
	bigtitle.text = tr("MENU_05")
	bigtitle.modulate.a = 0.0
	FLICKER.style(bigtitle)
	layer.add_child(bigtitle)
	var skip := _label(16, Color(0.6, 0.58, 0.54))
	skip.text = tr("INTRO_01")
	skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.offset_left = -260
	skip.offset_top = -40
	skip.offset_right = -20
	skip.offset_bottom = -12
	layer.add_child(skip)


func _sfx(n: String, db := 0.0, pitch := 1.0) -> void:
	var a := AudioStreamPlayer.new()
	a.stream = load("res://audio/%s.wav" % n)
	a.volume_db = db
	a.pitch_scale = pitch
	add_child(a)
	a.finished.connect(a.queue_free)
	a.play()


func _set_lights(on: bool) -> void:
	lights_on = on
	for sp in spots:
		sp.visible = on
	for g in head_glow:
		g.emission_energy_multiplier = 6.0 if on else 0.0


## Событие по времени: срабатывает один раз.
func _at(sec: float, id: String) -> bool:
	if t >= sec and not events.has(id):
		events[id] = true
		return true
	return false


func _unhandled_input(e: InputEvent) -> void:
	if (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]) \
			or (e is InputEventMouseButton and e.pressed and t > 1.0):
		_finish()


func _finish() -> void:
	if finished:
		return
	finished = true
	Engine.set_meta("after_intro", true)      # меню сразу покажет загрузку уровня
	get_tree().change_scene_to_file(GAME_MENU)


# ---------------- сценарий заставки ----------------
func _process(delta: float) -> void:
	t += delta
	_timeline()
	# машина
	car.position.z -= speed * delta
	car_model.position.y = 0.02 * sin(t * 9.0) * clampf(speed / SPEED, 0.0, 1.0) + 0.012 * sin(t * 3.7)
	car_model.rotation.z = 0.01 * sin(t * 2.3)
	for w in wheels:
		w.rotate_object_local(Vector3.RIGHT, -speed / 0.35 * delta)
	engine_snd.pitch_scale = 0.75 + 0.35 * clampf(speed / SPEED, 0.0, 1.0)
	if not events.has("bigtitle"):
		engine_snd.volume_db = -10.0 + 10.0 * clampf(speed / SPEED, 0.0, 1.0)
	_camera(delta)
	($Rain as GPUParticles3D).global_position = cam.global_position + Vector3(0, 8, -12)
	if window_light:
		window_light.light_energy = (0.0 if randf() < 0.03 else 0.6 * randf_range(0.8, 1.0)) if not events.has("win_off") else 0.0


func _camera(delta: float) -> void:
	var c := car.global_position
	match shot:
		"chase":
			var target := c + Vector3(-1.2, 1.9, 7.5)
			cam.global_position = cam.global_position.lerp(target, 1.0 - exp(-delta * 3.0))
			cam.look_at(c + Vector3(0, 1.0, -8.0))
		"roadside":
			cam.look_at(c + Vector3(0, 0.9, 0))
		"close":
			var target := c + Vector3(0.9, 2.5, 6.8)
			cam.global_position = cam.global_position.lerp(target, 1.0 - exp(-delta * 5.0))
			cam.look_at(c + Vector3(0.6, 0.9, -16.0))
		"house":
			cam.look_at(Vector3(0, 4.6, HOUSE_Z + 2.0).lerp(c + Vector3(0, 1, 0), 0.22))
	cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.004


func _cut(name: String, pos: Vector3 = Vector3.ZERO) -> void:
	shot = name
	if name == "chase":
		cam.global_position = car.global_position + Vector3(-1.2, 1.9, 7.5)
	elif name == "close":
		cam.global_position = car.global_position + Vector3(0.9, 2.5, 6.8)
	else:
		cam.global_position = pos


func _timeline() -> void:
	# 0–5 с: чёрный экран, дождь, титр
	if _at(0.0, "start"):
		_cut("chase")
	if _at(0.8, "title"):
		_hit("boom_open", -3.0)
		title.text = tr("INTRO_02")
		title.modulate.a = 0.0
		create_tween().tween_property(title, "modulate:a", 1.0, 1.2)
	if _at(3.6, "fadein"):
		_vol("drone", -9.0, 6.0)
		create_tween().tween_property(title, "modulate:a", 0.0, 1.0)
		create_tween().tween_property(black, "color:a", 0.0, 2.2)
	# 5–23 с: автоответчик
	var lines := [
		[5.4, "INTRO_03"],
		[9.8, "INTRO_04"],
		[14.2, "INTRO_05"],
		[18.6, "INTRO_06"],
		[22.6, ""],
	]
	if _at(5.0, "beep1"):
		_sfx("beep", -10.0)
	for i in lines.size():
		if _at(lines[i][0], "line%d" % i):
			sub.text = tr(lines[i][1]) if lines[i][1] != "" else ""
			_voice(lines[i][1])
	if _at(12.2, "lightning1"):
		_flash(0.8)
	if _at(12.6, "thunder1"):
		_hit("thunder", -5.0)
	if _at(18.5, "tension"):
		_hit("tension", -4.0)       # нарастание: пик ровно к появлению девочки (30.5 с)
	if _at(22.8, "beep2"):
		_sfx("beep", -10.0, 0.9)
	# 23–28 с: машина проносится мимо камеры у обочины
	if _at(23.0, "roadside"):
		var zc := car.global_position.z - 26.0
		_cut("roadside", Vector3(6.0, 1.1, zc))
	if _at(25.6, "whoosh"):
		_sfx("whoosh", -5.0)
	# 28–37 с: помехи по радио, девочка у дороги, торможение
	if _at(28.0, "close"):
		_cut("close")
		_vol("radio", -10.0, 2.5)
	if _at(29.8, "whisper"):
		_sfx("whisper", -2.0, 1.25)
		sub.text = tr("INTRO_07")
		_voice("INTRO_07")
	if _at(30.4, "flick1"):
		_set_lights(false)
	if _at(30.55, "girl"):
		_set_lights(true)
		girl.global_position = car.global_position + Vector3(1.5, 0, -14.0)
		var d := car.global_position - girl.global_position
		girl.rotation.y = atan2(d.x, d.z)
		girl.visible = true
		_hit("ghost", -1.0)
	if _at(31.0, "brake"):
		_hit("skid", 0.0)
		# после визга тормозов — тишина, только дождь
		if loops.has("_tension") and is_instance_valid(loops["_tension"]):
			loops["_tension"].stop()
		_vol("drone", -40.0, 0.4)
		_vol("radio", -80.0, 0.1)
		create_tween().tween_property(self, "speed", 0.0, 1.1).set_ease(Tween.EASE_OUT)
		sub.text = ""
	if _at(31.3, "flick2"):
		_set_lights(false)
	if _at(31.55, "girl_gone"):
		girl.visible = false
		_set_lights(true)
	if _at(31.9, "breath"):
		_hit("breath", -2.0)
	if _at(33.0, "rumble"):
		_hit("rumble", -3.0)
	if _at(35.0, "go"):
		_vol("drone", -12.0, 3.0)
		create_tween().tween_property(self, "speed", SPEED * 0.8, 2.5).set_ease(Tween.EASE_IN)
	# 37–52 с: дом
	if _at(37.0, "house"):
		car.position.z = HOUSE_Z + 46.0
		speed = 6.0
		_cut("house", Vector3(-5.0, 1.5, HOUSE_Z + 19.5))
		_hit("house", -2.0)
		_flash(0.6)
	if _at(37.6, "bell"):
		_hit("bell", -4.0)
	if _at(38.5, "low"):
		_hit("low", -3.0)
	if _at(41.5, "title_sfx"):
		_hit("title", -2.0)          # 3 с нарастания, удар ровно на 44.5 с — вместе с названием
		_vol("drone", -30.0, 3.0)
		_vol("wind", -20.0, 3.0)
	if shot == "house":
		var rest := car.global_position.z - (HOUSE_Z + 14.5)
		speed = minf(speed, sqrt(maxf(rest, 0.0) * 2.0 * 2.2))
	if _at(42.0, "door"):
		_hit("door", -6.0)
	if _at(44.5, "bigtitle"):
		# удар: вспышка молнии, название влетает с «толчком»
		_flash(1.3)
		bigtitle.pivot_offset = bigtitle.size / 2.0
		bigtitle.scale = Vector2(1.25, 1.25)
		bigtitle.modulate.a = 1.0
		create_tween().tween_property(bigtitle, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		engine_snd.volume_db = -30.0
	if _at(47.0, "win_off"):
		pass
	if _at(49.0, "fadeout"):
		create_tween().tween_property(black, "color:a", 1.0, 2.0)
		for k in loops:
			if is_instance_valid(loops[k]) and not k.begins_with("_title"):
				create_tween().tween_property(loops[k], "volume_db", -60.0, 2.4)
	if _at(51.5, "end"):
		_finish()
