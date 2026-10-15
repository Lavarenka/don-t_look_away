extends Node
## Спальня Веры — глава (тестовая версия загадок).
##
## 1. Свет: дверь захлопнулась — лампы гаснут одна за другой, остаётся ночник у кровати.
##    На тумбочке свеча и спички: взял оба — зажёг, дальше ходишь со свечой (маленький дрожащий свет).
## 2. Скример «кровать»: под одеялом кто-то лежит; подходишь со свечой и смотришь — одеяло опадает, пусто.
## 3. Шкатулка с балериной: мелодия обрывается — у гребёнки не хватает трёх зубцов. Зубцы разбросаны по
##    комнате. Открыл без всех зубцов — ошибка: мелодия ломается, свеча гаснет, шёпот за спиной.
## 4. Зеркало над комодом: в отражении комната другая — шкатулка открыта, шаль на изножье, фото стоит.
##    Сделай так же наяву — в зеркале за спиной встанет Вера, а под зеркалом появится маленький ключ.
## Все звуки здесь — с force = true (в спальне звуки дома выключены, см. level.hush).

const Y2 := -3.4
const MIRROR_LAYER := 1 << 10        ## видно только в зеркале (камера игрока этот слой не рисует)
const REAL_LAYER := 1 << 11          ## видно только наяву (камера зеркала не рисует)
const HELD_LAYER := 1 << 12          ## свеча в руке — в зеркале не отражается
const NIGHT_LAMP := 5                ## индекс ночника у кровати в bedroom.LAMPS — он не гаснет
const BED_C := Vector3(-9.04, Y2 + 0.70, -32.03)        ## верх матраса, центр
const BED_FOOT := Vector3(-9.04, 0.0, -30.6)            ## изножье (высота — лучом)
const CANDLE_XZ := Vector2(-11.45, -33.3)
const MATCH_XZ := Vector2(-10.85, -33.02)
const BOX_XZ := Vector2(-10.5, -28.03)                  ## шкатулка на комоде у южной стены
const FRAME_XZ := Vector2(-6.25, -32.95)                ## фото на комоде со стеклянными дверцами
const SHAWL_XZ := Vector2(-13.56, -30.62)               ## шаль на комоде под зеркалом
const KEY_XZ := Vector2(-13.55, -31.45)
const TEETH := [Vector3(-6.75, 1.0, -32.85), Vector3(-9.5, 1.0, -33.2), Vector3(-13.42, 0.7, -29.85)]   ## y — откуда пускать луч
const GLASS_C := Vector3(-13.762, Y2 + 1.7, -31.165)    ## стекло зеркала над комодом (смотрит на +X)
const GLASS_W := 0.76
const GLASS_H := 0.98

var L: Node
var B: Node                          ## bedroom.gd
var started := false                 ## дверь захлопнулась — глава идёт
var lit := false                     ## свеча горит
var candle: Node3D                   ## свеча на тумбочке
var matches: Node3D
var held: Node3D                     ## свеча в руке
var flame_light: OmniLight3D
var flame: MeshInstance3D
var gutter := 0.0                    ## > 0 — пламя почти гаснет
var _ft := 0.0
var blanket: MeshInstance3D
var bed_done := false
var bed_near_t := 0.0
var box: Node3D
var box_lid: Node3D
var box_twin_lid: Node3D
var ballerina_pivot: Node3D
var box_done := false
var box_busy := false
var teeth: Array[Node3D] = []
var shawl_pile: Node3D
var shawl_drape: Node3D
var shawl_twin: Node3D
var frame: Node3D
var frame_twin: Node3D
var frame_fixed := false
var shawl_fixed := false
var mirror_done := false
var vera_m: Node3D                   ## Вера — только в отражении
var portrait: Node                   ## овальный портрет в торце коридора (vera_portrait.gd)
var key_node: Node3D
var vp: SubViewport
var mcam: Camera3D
var glass: MeshInstance3D
var _mframe := 0


func setup(level: Node, bedroom: Node) -> void:
	L = level
	B = bedroom
	L.player.cam.cull_mask &= ~MIRROR_LAYER          # «отражённое» видно только в зеркале
	await get_tree().physics_frame          # столкновения комнаты уже в мире — можно мерить лучами
	await get_tree().physics_frame
	_place_props()
	_make_mirror()
	portrait = preload("res://scripts/vera_portrait.gd").new()
	add_child(portrait)
	portrait.setup(L, self)


# ---------------------------------------------------------------- расстановка
func _top(x: float, z: float, from_h := 1.05) -> float:
	var sp: PhysicsDirectSpaceState3D = L.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, Y2 + from_h, z), Vector3(x, Y2 - 0.3, z))
	var h := sp.intersect_ray(q)
	return h.position.y if not h.is_empty() else Y2


func _glb(path: String) -> Node3D:
	return load(path).instantiate()


func _set_layers(n: Node, mask: int) -> void:
	for v in n.find_children("*", "VisualInstance3D", true, false):
		(v as VisualInstance3D).layers = mask
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = mask


func _target(id: String, pos: Vector3, hint: String, th := 0.4, dist := 2.2) -> void:
	L.targets.append({"id": id, "pos": pos, "th": th, "dist": dist})
	L.extra_hints[id] = hint


func _place_props() -> void:
	var room: Node3D = L
	# свеча и спички на тумбочке у ночника
	candle = _glb("res://models/bedroom/vera_candle.glb")
	room.add_child(candle)
	candle.global_position = Vector3(CANDLE_XZ.x, _top(CANDLE_XZ.x, CANDLE_XZ.y), CANDLE_XZ.y)
	candle.rotation.y = 0.6
	_target("v_candle", candle.global_position + Vector3(0, 0.1, 0), "BR_CANDLE")
	matches = _glb("res://models/props/matchbox.glb")
	room.add_child(matches)
	matches.global_position = Vector3(MATCH_XZ.x, _top(MATCH_XZ.x, MATCH_XZ.y) + 0.005, MATCH_XZ.y)
	matches.rotation.y = -0.4
	_target("v_matches", matches.global_position + Vector3(0, 0.03, 0), "BR_MATCHES")
	# одеяло, под которым кто-то лежит
	var bl := _glb("res://models/bedroom/vera_blanket.glb")
	room.add_child(bl)
	bl.global_position = BED_C
	blanket = bl.find_child("Blanket", true, false) as MeshInstance3D
	blanket.material_override = _cloth_mat(Color(0.6, 0.58, 0.54), 0.5)
	blanket.set_blend_shape_value(blanket.find_blend_shape_by_name("Flat"), 0.0)
	# шкатулка (передом в комнату, на север)
	box = _glb("res://models/bedroom/vera_musicbox.glb")
	room.add_child(box)
	box.global_position = Vector3(BOX_XZ.x, _top(BOX_XZ.x, BOX_XZ.y), BOX_XZ.y)
	box.rotation.y = PI
	box_lid = box.find_child("Lid", true, false)
	box_twin_lid = box_lid.duplicate() as Node3D
	box_lid.get_parent().add_child(box_twin_lid)
	box_twin_lid.rotation.x = -1.75                     # в зеркале шкатулка открыта
	_set_layers(box_lid, REAL_LAYER)
	_set_layers(box_twin_lid, MIRROR_LAYER)
	var bal: Node3D = box.find_child("Ballerina", true, false)
	ballerina_pivot = Node3D.new()
	bal.get_parent().add_child(ballerina_pivot)
	ballerina_pivot.position = Vector3(0.05, 0, 0.02)
	bal.reparent(ballerina_pivot, true)
	_target("v_box", box.global_position + Vector3(0, 0.1, 0), "BR_MB")
	# три обломка гребёнки
	for i in TEETH.size():
		var p: Vector3 = TEETH[i]
		var t := _glb("res://models/bedroom/vera_tooth.glb")
		room.add_child(t)
		t.global_position = Vector3(p.x, _top(p.x, p.z, p.y) + 0.002, p.z)
		t.rotation.y = randf() * TAU
		t.scale = Vector3.ONE * 1.4
		var gl := OmniLight3D.new()                     # еле заметный блик — иначе в темноте не найти
		gl.light_color = Color(1.0, 0.85, 0.6)
		gl.light_energy = 0.06
		gl.omni_range = 0.25
		gl.position = Vector3(0, 0.05, 0)
		t.add_child(gl)
		teeth.append(t)
		_target("v_tooth%d" % (i + 1), t.global_position + Vector3(0, 0.03, 0), "LVL_44", 0.35, 1.8)
	# шаль кучкой на комоде под зеркалом; в зеркале она перекинута через изножье кровати
	var sh := _glb("res://models/bedroom/vera_shawl.glb")
	room.add_child(sh)
	shawl_pile = sh.find_child("Pile", true, false)
	shawl_drape = sh.find_child("Draped", true, false)
	var wool := _wool_mat()
	for n in [shawl_pile, shawl_drape]:
		(n as MeshInstance3D).material_override = wool
	shawl_pile.reparent(room)
	shawl_pile.global_position = Vector3(SHAWL_XZ.x, _top(SHAWL_XZ.x, SHAWL_XZ.y), SHAWL_XZ.y)
	shawl_pile.rotation.y = 0.3
	_set_layers(shawl_pile, REAL_LAYER)
	var foot_y := _foot_top()
	shawl_drape.reparent(room)
	shawl_drape.global_position = Vector3(BED_FOOT.x + 0.15, foot_y, BED_FOOT.z)
	shawl_drape.rotation.y = 0.0
	shawl_twin = shawl_drape.duplicate() as Node3D
	room.add_child(shawl_twin)
	shawl_twin.global_transform = shawl_drape.global_transform
	_set_layers(shawl_twin, MIRROR_LAYER)
	shawl_drape.visible = false
	sh.queue_free()
	_target("v_shawl", shawl_pile.global_position + Vector3(0, 0.08, 0), "LVL_44")
	_target("v_shawlput", Vector3(BED_FOOT.x, foot_y + 0.1, BED_FOOT.z), "BR_SHAWL_PUT", 0.45, 2.0)
	# фото Веры: наяву лежит лицом вниз, в зеркале — стоит
	frame = _glb("res://models/bedroom/vera_frame.glb")
	room.add_child(frame)
	var fy := _top(FRAME_XZ.x, FRAME_XZ.y)
	var ph := frame.find_child("Photo", true, false) as MeshInstance3D
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = load("res://textures/photo_vera_small.png")
	pm.roughness = 0.6
	ph.material_override = pm
	frame_twin = frame.duplicate() as Node3D
	room.add_child(frame_twin)
	frame_twin.global_position = Vector3(FRAME_XZ.x, fy, FRAME_XZ.y)
	frame_twin.rotation.y = -0.25
	_set_layers(frame_twin, MIRROR_LAYER)
	frame.global_position = Vector3(FRAME_XZ.x, fy + 0.007, FRAME_XZ.y - 0.03)
	frame.rotation = Vector3(PI / 2, -0.25, 0)
	_set_layers(frame, REAL_LAYER)
	_target("v_frame", Vector3(FRAME_XZ.x, fy + 0.05, FRAME_XZ.y), "BR_FRAME")
	# Вера в зеркале (появится в конце) — грузим заранее, чтобы не подвисало
	vera_m = preload("res://scripts/vera.gd").new()
	room.add_child(vera_m)
	vera_m.visible = false
	vera_m.set_layer(MIRROR_LAYER)
	# маленький ключ — награда
	key_node = _glb("res://models/props/key_vera.glb")
	room.add_child(key_node)
	key_node.global_position = Vector3(KEY_XZ.x, _top(KEY_XZ.x, KEY_XZ.y) + 0.004, KEY_XZ.y)
	key_node.rotation.y = 1.2
	key_node.scale = Vector3.ONE * 0.7
	key_node.visible = false
	_target("v_key", key_node.global_position + Vector3(0, 0.03, 0), "LVL_44")


## Верх изножья кровати — самая высокая точка в полосе у ног.
func _foot_top() -> float:
	var best := Y2 + 0.7
	for dz in [-0.12, -0.06, 0.0, 0.06]:
		for dx in [-0.3, 0.0, 0.3]:
			best = maxf(best, _top(BED_FOOT.x + dx, BED_FOOT.z + dz, 1.4))
	return best


func _cloth_mat(tint: Color, tile: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/linen_diff.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load("res://textures/linen_nor.jpg")
	m.normal_scale = 0.4
	m.roughness = 0.95
	m.uv1_scale = Vector3(1.0 / tile, 1.0 / tile, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _wool_mat() -> StandardMaterial3D:
	var m := _cloth_mat(Color(0.36, 0.07, 0.08), 0.08)
	m.normal_scale = 1.2
	return m


# ---------------------------------------------------------------- зеркало над комодом
func _make_mirror() -> void:
	glass = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(GLASS_W, GLASS_H)
	glass.mesh = q
	L.add_child(glass)
	glass.global_position = GLASS_C
	glass.rotation.y = PI / 2
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp = SubViewport.new()
	vp.size = Vector2i(int(420 * GLASS_W / GLASS_H), 420)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.positional_shadow_atlas_size = 1024
	add_child(vp)
	mcam = Camera3D.new()
	mcam.projection = Camera3D.PROJECTION_FRUSTUM
	mcam.keep_aspect = Camera3D.KEEP_HEIGHT
	mcam.size = GLASS_H
	mcam.far = 20.0
	mcam.current = true
	mcam.cull_mask = (0xFFFFF | MIRROR_LAYER) & ~REAL_LAYER & ~HELD_LAYER & ~(1 << 1) & ~(1 << 2)
	vp.add_child(mcam)
	var we := L.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var env: Environment = we.environment.duplicate()
		env.volumetric_fog_enabled = false
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.ssr_enabled = false
		env.glow_enabled = false
		mcam.environment = env
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D refl : source_color, filter_linear;
uniform sampler2D spots : filter_linear, repeat_enable;
void fragment() {
	vec3 c = texture(refl, vec2(1.0 - UV.x, UV.y)).rgb * vec3(0.72, 0.72, 0.68);
	float n = texture(spots, UV * vec2(0.7, 1.0)).r;
	float e = min(min(UV.x, 1.0 - UV.x) * 2.2, min(UV.y, 1.0 - UV.y) * 1.6);
	float desil = smoothstep(0.8, 0.92, n) + (1.0 - smoothstep(0.0, 0.3, e)) * 0.6 * smoothstep(0.45, 0.7, n);
	c = mix(c, vec3(0.03, 0.028, 0.024), clamp(desil, 0.0, 0.9));
	c *= mix(0.5, 1.0, smoothstep(0.0, 0.45, e));
	ALBEDO = c;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("refl", vp.get_texture())
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.seed = 23
	fn.frequency = 0.025
	fn.fractal_octaves = 4
	nt.noise = fn
	m.set_shader_parameter("spots", nt)
	glass.material_override = m


func _mirror_active() -> bool:
	if not started:
		return false
	var cam: Camera3D = L.player.cam
	var to: Vector3 = glass.global_position - cam.global_position
	if to.length() > 8.0 or to.dot(glass.global_basis.z) > -0.02:
		return false
	return cam.is_position_in_frustum(glass.global_position) or to.length() < 1.5


func _place_mcam() -> void:
	var G := glass.global_transform.orthonormalized()
	var el: Vector3 = G.affine_inverse() * L.player.cam.global_position
	var d := el.z
	if d < 0.03:
		return
	mcam.global_transform = Transform3D(Basis(-G.basis.x, G.basis.y, -G.basis.z), G * Vector3(el.x, el.y, -d))
	mcam.near = d
	mcam.frustum_offset = Vector2(el.x, -el.y)


# ---------------------------------------------------------------- свет
## Дверь захлопнулась: гаснет всё, кроме первого светильника — он моргает. Дойдёшь до него — загорается
## следующий по пути, а позади гаснет. Из темноты (только оттуда) — звуки, будто там кто-то есть:
## шаги, дыхание, скрежет, шёпот; свет ушёл вперёд — звуки перебираются в темноту за спиной.
const PATH := [1, 0, 6, 2, 3, NIGHT_LAMP]    ## светильники по пути: коридор → угол → дверь спальни → ночник
const DARK_SFX := [["step0", -4.0, 0.7], ["step2", -4.0, 0.65], ["breath_dark", -6.0, 1.0], ["scratch", -6.0, 0.75],
	["whisper", -8.0, 0.8], ["drag", -6.0, 0.7], ["knock", -8.0, 0.6], ["creak", -6.0, 0.6]]
var path_i := -1                     ## какой светильник сейчас горит (индекс в PATH)
var _base := {}                      ## исходная яркость светильников
var _dark_t := 3.0
var _lamp_t := 0.0


func lights_out() -> void:
	started = true
	for i in B.lamps.size():
		_base[i] = (B.lamps[i] as OmniLight3D).light_energy
	await get_tree().create_timer(0.8).timeout
	# всё гаснет разом с хлопком, первый светильник остаётся и моргает
	for i in B.lamps.size():
		if i != PATH[0] and i != NIGHT_LAMP:            # ночник у кровати горит всегда
			(B.lamps[i] as OmniLight3D).light_energy = 0.0
	L._sfx3d("click", L.player.global_position + Vector3(0, 2.0, 0), -2.0, 0.6, true)
	path_i = 0
	_dark_t = 2.5
	L._set_objective("BR_OBJ2")


func _lamp(i: int) -> OmniLight3D:
	return B.lamps[PATH[i]]


## Свет идёт за игроком: горит тот светильник пути, у которого он сейчас стоит (ближайший), остальные
## погашены. Пошёл дальше — загорается следующий, позади гаснет; вернулся назад — так же назад.
## В погасшей темноте сразу кто-то есть. Как только зажжена свеча — свет больше не водит (остаётся
## только ночник); звуки из темноты — всегда.
const LEAD := 1.8                    ## на сколько вперёд по ходу «смотрит» свет
var _want := 0
var _want_t := 0.0


func _update_path(delta: float) -> void:
	if path_i < 0:
		return
	_lamp_t += delta
	var cur := _lamp(path_i)
	var night: bool = PATH[path_i] == NIGHT_LAMP
	# горящий светильник неровно моргает (ночник — спокойнее)
	var e: float = _base[PATH[path_i]]
	var f := 1.0
	if not night:
		f = 0.0 if randf() < 0.06 else randf_range(0.65, 1.05)
		if fmod(_lamp_t, 3.7) < 0.25:
			f *= randf_range(0.0, 0.4)
	cur.light_energy = e * f
	if lit:
		return
	# ближайший светильник пути — к точке чуть впереди по ходу движения (не взгляда):
	# идёшь к светильнику — он загорается заранее, а не когда упёрся в него
	var p: Vector3 = L.player.global_position
	var v: Vector3 = L.player.velocity
	v.y = 0.0
	if v.length() > 0.3:
		p += v.normalized() * LEAD
	var best := path_i
	var best_d := INF
	var cur_d := INF
	for k in PATH.size():
		var lp := _lamp(k).global_position
		var d := Vector2(p.x - lp.x, p.z - lp.z).length()
		if k == path_i:
			cur_d = d
		if d < best_d:
			best_d = d
			best = k
	# переключаем, только если другой заметно ближе и игрок задержался — без дребезга на границе
	var want := best if best_d < cur_d - 0.3 else path_i
	if want != _want:
		_want = want
		_want_t = 0.0
	_want_t += delta
	if want != path_i and _want_t > 0.2:
		_switch_to(want)


## Переключить свет на светильник пути i: он загорается с треском, прежний через миг гаснет,
## и в его темноте сразу кто-то есть.
func _switch_to(i: int) -> void:
	if i == path_i:
		return
	var old := _lamp(path_i)
	path_i = i
	_lamp_t = 0.0
	var nxt := _lamp(i)
	var target: float = _base[PATH[i]]
	if PATH[i] == NIGHT_LAMP:
		nxt.light_energy = target                       # ночник и так горит — без треска
	else:
		L._sfx3d("click", nxt.global_position, -8.0, 1.2, true)
		var tw := create_tween()
		nxt.light_energy = 0.0
		for k in 3:
			tw.tween_property(nxt, "light_energy", target * 0.8, 0.05)
			tw.tween_property(nxt, "light_energy", 0.0, 0.07)
		tw.tween_property(nxt, "light_energy", target, 0.3)
	get_tree().create_timer(0.7).timeout.connect(func():
		if _lamp(path_i) == old or old == B.lamps[NIGHT_LAMP]:   # вернулся / ночник не гаснет
			return                                      # уже снова горит (вернулся)
		old.light_energy = 0.0
		L._sfx3d("click", old.global_position, -10.0, 0.7, true)
		get_tree().create_timer(1.2).timeout.connect(func():
			if lit:
				return
			var s: Array = DARK_SFX.pick_random()
			L._sfx3d(s[0], old.global_position + Vector3(randf_range(-0.8, 0.8), -0.6, randf_range(-0.8, 0.8)), s[1], s[2], true)))


## Свеча зажжена: свет больше не водит — гаснет всё, кроме ночника.
func _path_stop() -> void:
	for i in PATH.size():
		if PATH[i] != NIGHT_LAMP:
			_lamp(i).light_energy = 0.0
	path_i = PATH.size() - 1


## Где темно — там и звуки: точка подальше от горящего света, лучше за спиной у игрока.
func _dark_sounds(delta: float) -> void:
	if path_i < 0:
		return
	_dark_t -= delta
	if _dark_t > 0.0:
		return
	_dark_t = randf_range(2.5, 5.5) if not lit else randf_range(3.5, 7.0)   # и со свечой не стихают
	var p: Vector3 = L.player.global_position
	var lit_pos := _lamp(path_i).global_position
	var back: Vector3 = -L.player.forward()
	back.y = 0.0
	var best := Vector3.ZERO
	var best_s := -INF
	for k in 12:
		var a := randf() * TAU
		var r := randf_range(2.5, 6.0)
		var c := p + Vector3(cos(a), 0, sin(a)) * r
		c.x = clampf(c.x, -16.2, -5.7)                    # внутри спальни и её коридора
		c.z = clampf(c.z, -36.2, -27.8)
		c.y = Y2 + randf_range(0.2, 1.6)
		var dl := Vector2(c.x - lit_pos.x, c.z - lit_pos.z).length()
		if dl < 2.4 or (lit and Vector2(c.x - p.x, c.z - p.z).length() < 4.0):
			continue                                      # на свету (и рядом со свечой) никого нет
		var score := dl + (c - p).normalized().dot(back.normalized()) * 2.0 + randf()
		if score > best_s:
			best_s = score
			best = c
	if best_s == -INF:
		return
	var s: Array = DARK_SFX.pick_random()
	L._sfx3d(s[0], best, s[1], s[2] * randf_range(0.9, 1.1), true)
	if s[0].begins_with("step"):                         # шаги — несколько подряд, кто-то ходит
		for k in randi_range(2, 4):
			var q := best + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4)) * (k + 1)
			get_tree().create_timer(0.7 * (k + 1)).timeout.connect(func(): L._sfx3d("step%d" % (randi() % 4), q, -5.0, 0.7, true))


func _light_candle() -> void:
	L.busy = true
	L._sfx("match_strike", -4.0, 1.0, true)
	await get_tree().create_timer(0.35).timeout
	L.inv.remove("candle")
	L.inv.remove("matches")
	_make_held()
	lit = true
	_path_stop()
	gutter = 0.6
	await get_tree().create_timer(0.6).timeout
	L.busy = false
	L._set_objective("BR_OBJ3")


## Свеча в руке: справа внизу кадра, маленький тёплый дрожащий свет с тенями.
func _make_held() -> void:
	held = _glb("res://models/bedroom/vera_candle.glb")
	L.player.cam.add_child(held)
	held.position = Vector3(0.26, -0.3, -0.5)
	held.rotation = Vector3(0.15, 0.4, 0)
	held.scale = Vector3.ONE * 0.75
	for v in held.find_children("*", "GeometryInstance3D", true, false):
		(v as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_set_layers(held, HELD_LAYER)
	flame = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.022, 0.05)
	flame.mesh = q
	var fm := ShaderMaterial.new()
	fm.shader = preload("res://shaders/candle_flame.gdshader")
	flame.material_override = fm
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.layers = HELD_LAYER
	held.add_child(flame)
	flame.position = Vector3(0, 0.19, 0)
	flame_light = OmniLight3D.new()
	flame_light.light_color = Color(1.0, 0.68, 0.38)
	flame_light.omni_range = 5.5
	flame_light.omni_attenuation = 1.6
	flame_light.shadow_enabled = true
	flame_light.shadow_bias = 0.05
	held.add_child(flame_light)
	flame_light.position = Vector3(0, 0.22, 0.02)


func _update_flame(delta: float) -> void:
	if held == null:
		return
	_ft += delta
	gutter = maxf(gutter - delta, 0.0)
	var f := 0.82 + 0.1 * sin(_ft * 11.0) * sin(_ft * 7.3 + 1.0) + randf() * 0.08
	var g := 1.0 - smoothstep(0.0, 0.35, gutter) * 0.85
	flame_light.light_energy = 1.5 * f * g
	flame.scale = Vector3(1.0, (0.85 + 0.2 * f) * maxf(g, 0.2), 1.0)
	flame.visible = g > 0.1


## Пламя на миг почти гаснет (испуг, сквозняк).
func gutter_out(sec: float) -> void:
	gutter = maxf(gutter, sec)


# ---------------------------------------------------------------- взаимодействие
func target_ok(id: String) -> bool:
	if not started or L.busy:
		return false
	match id:
		"v_candle": return candle.visible
		"v_matches": return matches.visible
		"v_box": return not box_done and not box_busy
		"v_shawl": return shawl_pile.visible
		"v_shawlput": return L.inv.has("shawl")
		"v_frame": return not frame_fixed
		"v_key": return key_node.visible
	if id.begins_with("v_tooth"):
		return teeth[int(id.right(1)) - 1].visible
	return false


func interact(id: String) -> void:
	if not id.begins_with("v_"):
		return
	match id:
		"v_candle":
			if L.inv.add("candle", candle):
				candle.visible = false
				L._sfx("pickup", -6.0, 1.0, true)
				if L.inv.has("matches"):
					_light_candle()
		"v_matches":
			if L.inv.add("matches", matches):
				matches.visible = false
				L._sfx("pickup", -6.0, 1.1, true)
				if L.inv.has("candle"):
					_light_candle()
		"v_box":
			_open_box()
		"v_shawl":
			if L.inv.add("shawl", shawl_pile):
				shawl_pile.visible = false
				L._sfx("sheet_rustle", -8.0, 1.2, true)
		"v_shawlput":
			L.inv.remove("shawl")
			shawl_drape.visible = true
			_set_layers(shawl_drape, 1)
			shawl_twin.queue_free()
			shawl_fixed = true
			L._sfx3d("sheet_rustle", shawl_drape.global_position, -6.0, 0.9, true)
		"v_frame":
			frame_fixed = true
			frame.global_transform = frame_twin.global_transform
			_set_layers(frame, 1)
			frame_twin.queue_free()
			L._sfx3d("clink", frame.global_position, -10.0, 1.3, true)
		"v_key":
			key_node.visible = false
			L.inv.add("smallkey", key_node)
			L._sfx("pickup", -6.0, 1.0, true)
			L._set_objective("BR_DONE")
	if id.begins_with("v_tooth"):
		var t: Node3D = teeth[int(id.right(1)) - 1]
		if L.inv.add(id, t):
			t.visible = false
			L._sfx("pickup", -8.0, 1.3, true)


func _teeth_count() -> int:
	var n := 0
	for i in 3:
		if L.inv.has("v_tooth%d" % (i + 1)):
			n += 1
	return n


## Шкатулка: со всеми зубцами — играет до конца; без них — ошибка и испуг.
func _open_box() -> void:
	box_busy = true
	var full := _teeth_count() == 3
	if full:
		for i in 3:
			L.inv.remove("v_tooth%d" % (i + 1))
		L._sfx3d("click", box.global_position, -6.0, 1.4, true)
		await get_tree().create_timer(0.5).timeout
	create_tween().tween_property(box_lid, "rotation:x", -1.75, 0.7).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.5).timeout
	if full:
		L._sfx3d("vera_mb_full", box.global_position, -2.0, 1.0, true)
		var tw := create_tween()
		tw.tween_property(ballerina_pivot, "rotation:y", TAU * 9.0, 21.0)
		await get_tree().create_timer(21.0).timeout
		box_done = true
		_set_layers(box_lid, 1)                     # теперь и наяву открыта — как в зеркале
		box_twin_lid.queue_free()
		box_busy = false
		return
	# ошибка: мелодия ломается на пустом зубце, свеча гаснет, шёпот за спиной
	L._sfx3d("vera_mb_broken", box.global_position, -2.0, 1.0, true)
	create_tween().tween_property(ballerina_pivot, "rotation:y", ballerina_pivot.rotation.y + 2.2, 2.2)
	await get_tree().create_timer(2.5).timeout
	gutter_out(1.6)
	var p = L.player
	L._sfx3d("whisper_harsh", p.cam.global_position - p.forward() * 0.6, -2.0, 0.8, true)
	p.shake = 0.5
	await get_tree().create_timer(0.8).timeout
	create_tween().tween_property(box_lid, "rotation:x", 0.0, 0.25).set_trans(Tween.TRANS_QUAD)
	L._sfx3d("click", box.global_position, -2.0, 0.6, true)
	L._say("BR_MB_MISS", 3.5)
	box_busy = false


# ---------------------------------------------------------------- кадр
func _process(delta: float) -> void:
	if not started:
		return
	_update_flame(delta)
	_update_path(delta)
	_dark_sounds(delta)
	# подсказка у шкатулки: со всеми зубцами — «вставить»
	L.extra_hints["v_box"] = "BR_MB_FIX" if _teeth_count() == 3 else "BR_MB"
	# зеркало: отражение через кадр, только когда на него смотрят
	if _mirror_active():
		_mframe += 1
		if _mframe % 2 == 0:
			_place_mcam()
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	else:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_check_bed(delta)
	_check_mirror_done()


## Под одеялом кто-то лежит. Подошёл со свечой и смотришь — одеяло опадает: пусто.
func _check_bed(delta: float) -> void:
	if bed_done or not lit or L.busy:
		return
	var p = L.player
	var head := BED_C + Vector3(0, 0.15, -0.6)
	var to: Vector3 = head - p.cam.global_position
	if to.length() < 2.3 and p.forward().angle_to(to) < 0.5:
		bed_near_t += delta
	else:
		bed_near_t = 0.0
	if bed_near_t < 0.6:
		return
	bed_done = true
	var k := blanket.find_blend_shape_by_name("Flat")
	create_tween().tween_method(func(v: float): blanket.set_blend_shape_value(k, v), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	L._sfx3d("sheet_rustle", BED_C, 0.0, 0.7, true)
	L._sfx3d("whoosh", BED_C + Vector3(0, 0.4, 0), -6.0, 0.6, true)
	gutter_out(0.5)
	p.shake = 0.35
	await get_tree().create_timer(0.45).timeout
	L._sfx3d("thump", BED_C, -6.0, 0.5, true)


## Всё как в отражении: в зеркале за спиной встаёт Вера; потом под зеркалом — маленький ключ.
func _check_mirror_done() -> void:
	if mirror_done or not (box_done and shawl_fixed and frame_fixed) or L.busy:
		return
	var p = L.player
	var to: Vector3 = glass.global_position - p.cam.global_position
	if to.length() > 3.8 or p.forward().angle_to(to) > 0.4:
		return
	mirror_done = true
	var back: Vector3 = -p.forward()
	back.y = 0.0
	back = back.normalized()
	vera_m.global_position = Vector3(p.global_position.x, Y2, p.global_position.z) + back * 0.75
	var d: Vector3 = p.global_position - vera_m.global_position
	vera_m.rotation.y = atan2(d.x, d.z)
	vera_m.play("idle")
	vera_m.visible = true
	L._sfx3d("whisper", p.cam.global_position + back * 0.5, -6.0, 0.75, true)
	await get_tree().create_timer(1.6).timeout
	gutter_out(0.7)
	vera_m.visible = false
	L._sfx3d("click", glass.global_position + Vector3(0.2, -0.7, -0.3), -6.0, 1.2, true)
	key_node.visible = true
