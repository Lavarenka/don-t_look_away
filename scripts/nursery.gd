extends Node
## Детская Ани (третья комната).
## Загадка: 5 рисунков Ани, на каждом цифра и цвет мелка. На музыкальной шкатулке
## 5 цветных клавиш — сыграть мелодию в порядке рисунков: жёлтый, красный, синий,
## зелёный, чёрный (белый мел на чёрной бумаге). Рисунок №5 лежит под кроватью — там скример.
## Ошибся — шкатулка фальшивит, а одна из игрушек, на которую ты не смотришь,
## поворачивается к тебе. Разгадал — финал демки.

var door_locked := false   ## дверь детской уже захлопнулась
var L: Node
var CODE := []           ## порядок клавиш (цвета) — по номерам на рисунках, номера каждый раз новые
var nums := [1, 2, 3, 4, 5]   ## номер в углу каждого рисунка
const NUM_COLORS := [Color8(235, 190, 20), Color8(205, 35, 30), Color8(40, 80, 200), Color8(40, 150, 50), Color8(240, 240, 235)]
const KEY_NAMES := ["NUR_01", "NUR_02", "NUR_03", "NUR_04", "NUR_05"]
const CAPTIONS := [
	"NUR_06",
	"NUR_07",
	"NUR_08",
	"NUR_09",
	"NUR_10",
]
const NOTE := "NUR_11"

var progress := 0
var solved := false
var seen := {}
var viewer: TextureRect
var bed_scare_done := false
## Под кроватью: true — катсцена «рука» (тянешься к рисунку, из темноты хватает детская рука,
## scripts/bed_grab.gd); false — прежние «глаза» в щели.
const BED_GRAB := true
var bed_grab: Node
var toys := ["NBear", "NDuck", "NHorse", "NElephant", "NRockChair"]
var wound := false            ## шкатулка заведена ключиком (ключик спрятан за портретом в коридоре)

# ---- прятки: после мелодии Аня прячется, Миша водит ----
## место → [точка, куда смотреть, подсказка «E — …»]
const SPOTS := {
	"bed": [Vector3(-0.6, 0.15, -22.55), "NUR_S_BED"],
	"curt_w": [Vector3(-2.2, 1.0, -21.0), "NUR_S_CURT"],
	"curt_e": [Vector3(2.2, 1.0, -21.6), "NUR_S_CURT"],
	"desk": [Vector3(1.95, 0.35, -18.95), "NUR_S_DESK"],
	"chair": [Vector3(1.95, 0.45, -23.5), "NUR_S_CHAIR"],
}
var hiding := false
var hide_spot := ""
var _checked := {}
var _giggle_t := 3.0
var _steps: Array[Node3D] = []

## Нашёл её — FOUND_V2: она больше не стоит внутри мебели, и находка страшнее.
##   кровать, стол: Миша присел и заглянул вниз — пусто, только скрип и смешок СВЕРХУ; выпрямляется —
##     а она стоит на кровати (на столе), согнувшись над ним, лицо прямо над его лицом, — резкий крик;
##   шторы, кресло: там пусто — и смешок прямо за спиной; Миша оборачивается — она вплотную, крик.
##   Потом фонарь гаснет; загорается — она уже стоит поодаль на полу (место подбирается по коллизиям),
##   «Нашёл... Теперь я вожу» — и счёт. В счёте она тоже не заходит в мебель и в стены.
## false — как было: она просто появлялась в самом тайнике
## (бэкап: backup/nursery_found_v1, метка в git: before-found-v2).
const FOUND_V2 := true
const FORCE_SPOT := ""    ## для проверки: "bed", "desk", "curt_w", "curt_e", "chair" — она всегда прячется там; "" — случайно
var _test_spot := ""      ## F8 (тест): прятки сразу, она — под кроватью
const BED_TOP := Vector3(-0.88, 0.42, -22.6)     ## где её ноги на кровати (верх матраса ~0.43 м)
const DESK_TOP := Vector3(1.92, 0.93, -19.08)    ## где её ноги на столе (лампу не задевает)
const ROOM := Rect2(-1.75, -23.6, 3.5, 5.0)      ## где ей можно стоять на полу (x, z): не у стен и не в шторах
var _bend: Node                                  ## spirit_bend.gd — пока она согнута над Мишей
var _eye_base := 1.6                             ## высота глаз Миши (до того как присел)
var _fill: OmniLight3D                           ## слабый холодный свет у лица Миши, пока она вплотную


func _ready() -> void:
	_number_drawings()
	# цели для «E»
	for i in 5:
		var d: Node3D = L.get_node("Drawing%d" % (i + 1))
		L.targets.append({"id": "n_d%d" % (i + 1), "pos": d.global_position, "th": 0.35 if i < 4 else 0.45, "dist": 2.2})
		L.extra_hints["n_d%d" % (i + 1)] = "NUR_12" if i < 4 else "NUR_13"
	var mb: Node3D = L.get_node("MusicBox")
	_rebuild_box(mb)
	L.targets.append({"id": "n_box", "pos": mb.global_position + Vector3(0, 0.05, -0.04), "th": 0.18, "dist": 1.8})
	L.extra_hints["n_box"] = "NUR_14"
	for sp in SPOTS:
		L.targets.append({"id": "n_s_" + sp, "pos": SPOTS[sp][0], "th": 0.4, "dist": 2.0})
		L.extra_hints["n_s_" + sp] = SPOTS[sp][1]
	for k in 5:
		var key: Node3D = L.get_node("MusicBox/Key%d" % k)
		L.targets.append({"id": "n_k%d" % k, "pos": key.global_position, "th": 0.08, "dist": 1.6})
		L.extra_hints["n_k%d" % k] = ["NUR_15", KEY_NAMES[k]]
	# окно для просмотра рисунков
	viewer = TextureRect.new()
	viewer.set_anchors_preset(Control.PRESET_CENTER)
	viewer.custom_minimum_size = Vector2(640, 480)
	viewer.position = Vector2(-320, -270)
	viewer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	viewer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	viewer.visible = false
	L.hud.add_child(viewer)
	var hint := Label.new()
	hint.text = tr("NUR_16")
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hint.add_theme_constant_override("outline_size", 6)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 490)
	hint.size = Vector2(640, 30)
	viewer.add_child(hint)
	L.get_node("NightLight").light_energy = 0.0


## Рисунок закрывается на E или кнопкой мыши. Ловим ввод сами: пока рисунок
## открыт, игрок «заморожен», и player.gd не передаёт нажатие E дальше.
## ТЕСТ (только в тестовой сборке, settings.gd: UNLOCK_ALL): F8 в детской — сразу прятки (см. _test_hide).
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_F8 \
			and preload("res://scripts/settings.gd").UNLOCK_ALL and L.phase == "nursery" and not solved and not L.busy:
		get_viewport().set_input_as_handled()
		_test_hide()
		return
	if not viewer.visible:
		return
	var close := false
	if e is InputEventKey and e.pressed and not e.echo and (e.physical_keycode == KEY_E or e.physical_keycode == KEY_ESCAPE):
		close = true
	elif e is InputEventMouseButton and e.pressed:
		close = true
	if close:
		_close_viewer()
		get_viewport().set_input_as_handled()


## ТЕСТ: загадку пропустить — мелодия будто сыграна, начинаются прятки, и Аня прячется под кроватью
## (сцена «она над тобой»: подойди к кровати, E — «заглянуть под кровать»). В обычной игре место — случайное.
func _test_hide() -> void:
	if viewer.visible:
		_close_viewer()
	if dancing:
		dancing = false
		L.girl.visible = false
	_test_spot = "bed"
	_solve()


func _close_viewer() -> void:
	viewer.visible = false
	L.player.frozen = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func target_ok(id: String) -> bool:
	if id.begins_with("n_s_"):
		return hiding and not L.busy and not _checked.has(id)
	if L.phase != "nursery" or solved or viewer.visible:
		return false
	if id.begins_with("n_k"):
		return seen.has("note") and wound
	return true


# ---------------- танцующий призрак посреди комнаты ----------------
var dancing := false
var dance_t := 0.0
var dance_seen := 0.0
var dance_note := 0.0
var dance_i := 0
const DANCE_TUNE := [0, 2, 4, 2, 0, 1, 3, 1]


## Вошёл в детскую: посреди комнаты под шкатулку танцует девочка.
func start_dance() -> void:
	var g: Node3D = L.girl
	g.global_position = Vector3(0.1, 0, -21.4)
	L._face(g, L.player.global_position)
	g.visible = true
	_gpose("idle", -1.0, 0.0)
	L.girl_sp.float_h = 0.3                  # парит над полом и медленно кружится
	L._sfx("girl_appear", -4.0)
	dancing = true
	dance_t = 0.0
	dance_seen = 0.0
	L.drone.volume_db = -30.0


func _update_dance(delta: float) -> void:
	if not dancing:
		return
	dance_t += delta
	var g: Node3D = L.girl
	# кружится на месте, медленно поворачиваясь
	g.rotation.y += delta * 0.9
	# шкатулка сама наигрывает мелодию
	dance_note -= delta
	if dance_note <= 0.0:
		dance_note = 0.55
		_note(DANCE_TUNE[dance_i % DANCE_TUNE.size()], 0.92, -6.0)
		dance_i += 1
	var head: Vector3 = g.global_position + Vector3(0, 1.2, 0)
	var looking: bool = L.haunts._looking(head, 0.35) and L.player.is_light_lit()
	if looking:
		dance_seen += delta
	var d: float = L.haunts._dist(g.global_position)
	if d < 1.8 or dance_seen > 4.0 or dance_t > 25.0:
		_end_dance(d < 1.8)


func _end_dance(close: bool) -> void:
	dancing = false
	var g: Node3D = L.girl
	# замирает, поворачивается к игроку — свет мигает — её нет
	L._girl_anim(0.4)                 # замедляется, но не замирает
	L._face(g, L.player.global_position)
	L._sfx("sting", -2.0 if close else -6.0)
	L.player.flicker = 0.45
	await get_tree().create_timer(0.25).timeout
	g.visible = false
	L.drone.volume_db = -8.0
	L._sfx("giggle", -4.0, 1.1)          # тихий детский смешок


func _process(delta: float) -> void:
	_update_dance(delta)
	if seen.has("note") and not wound:
		L.extra_hints["n_box"] = "NUR_BOX_WIND" if L.inv.has("mb_key") else "NUR_20"
	if hiding:
		_update_hide(delta)
	if L.phase == "nursery" and not solved:
		var nl: OmniLight3D = L.get_node("NightLight")
		nl.light_energy = 0.0 if randf() < 0.04 else 0.35 * randf_range(0.85, 1.0)


## Случайные номера на рисунках: дорисовываем цифру мелком в кружок в углу.
## Шкатулка из Blender (models/nursery/music_box.glb): узлы те же, меняются только меши.
## Клавиши: жёлтая, красная, синяя, зелёная, чёрная.
func _rebuild_box(mb: Node3D) -> void:
	var src: Node3D = load("res://models/nursery/music_box.glb").instantiate()
	for nm in ["Body", "Inner", "LidHinge/Lid", "Key0", "Key1", "Key2", "Key3", "Key4"]:
		var dst := mb.get_node_or_null(nm) as MeshInstance3D
		var from := src.find_child(nm.get_file(), true, false) as MeshInstance3D
		if dst == null or from == null:
			continue
		dst.mesh = from.mesh
		for i in dst.get_surface_override_material_count():
			dst.set_surface_override_material(i, null)
		if nm.begins_with("Key") and nm != "Key4":
			# цветные клавиши чуть светятся — видны в полутьме, как раньше
			var m := (from.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
			m.emission_enabled = true
			m.emission = m.albedo_color
			m.emission_energy_multiplier = 0.25
			dst.set_surface_override_material(0, m)
	src.free()


func _number_drawings() -> void:
	nums.shuffle()
	CODE.clear()
	for n in range(1, 6):
		CODE.append(nums.find(n))
	for i in 5:
		var spr := L.get_node("Drawing%d" % (i + 1)) as Sprite3D
		var img: Image = spr.texture.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var g: Image = load("res://textures/drawings/num_%d.png" % nums[i]).get_image()
		if g.is_compressed():
			g.decompress()
		g.convert(Image.FORMAT_RGBA8)
		var col: Color = NUM_COLORS[i]
		for y in g.get_height():
			for x in g.get_width():
				var a := g.get_pixel(x, y).a
				if a > 0.0:
					g.set_pixel(x, y, Color(col.r * randf_range(0.85, 1.0), col.g * randf_range(0.85, 1.0), col.b * randf_range(0.85, 1.0), a))
		var k := img.get_width() / 512.0
		if k != 1.0:
			g.resize(int(g.get_width() * k), int(g.get_height() * k))
		img.blend_rect(g, Rect2i(Vector2i.ZERO, g.get_size()), Vector2i(int((512 - 66) * k), int(16 * k)))
		spr.texture = ImageTexture.create_from_image(img)


## Вызывается из level.gd на любое нажатие E, которое не забрали другие.
func interact(id: String) -> void:
	if viewer.visible:
		_close_viewer()
		return
	if not id.begins_with("n_"):
		return
	if id.begins_with("n_d"):
		var i := int(id.right(1)) - 1
		if i == 4 and not bed_scare_done:
			_under_bed()
		else:
			_show(i)
	elif id == "n_box":
		if not seen.has("note"):
			seen["note"] = true
			L._show_note(NOTE)
			L._set_objective("NUR_19" if wound or L.inv.has("mb_key") else "NUR_OBJ_KEY")
		elif not wound and L.inv.has("mb_key"):
			_wind()
		elif not wound:
			L._sfx3d("click", L.get_node("MusicBox").global_position, -12.0, 1.4)
			L._say("NUR_BOX_NOKEY", 3.5)
		else:
			L._show_note(NOTE)
	elif id.begins_with("n_s_"):
		_check_spot(id)
	elif id.begins_with("n_k"):
		_press(int(id.right(1)))


func _show(i: int) -> void:
	seen["d%d" % i] = true
	viewer.texture = L.get_node("Drawing%d" % (i + 1)).texture
	viewer.visible = true
	L.player.frozen = true
	L._sfx("creak", -20.0, 1.8)
	L._say(tr(CAPTIONS[i]) % nums[i], 4.0)


# ---------------- шкатулка ----------------
func _press(k: int) -> void:
	var key: Node3D = L.get_node("MusicBox/Key%d" % k)
	var tw := create_tween()
	tw.tween_property(key, "position:y", 0.1, 0.06)
	tw.tween_property(key, "position:y", 0.107, 0.12)
	_note(k)
	if k == CODE[progress]:
		progress += 1
		if progress == CODE.size():
			_solve()
	else:
		progress = 0
		L.busy = true
		await get_tree().create_timer(0.35).timeout
		for n in 5:                                       # фальшивый аккорд
			_note(n, randf_range(0.82, 0.9), -6.0)
		L.player.flicker = 0.5
		_turn_hidden_toy()
		await get_tree().create_timer(1.0).timeout
		L.busy = false


## Завести шкатулку ключиком из коридора: ключик вставляется в гнездо сбоку и проворачивается.
func _wind() -> void:
	wound = true
	L.inv.remove("mb_key")
	L.busy = true
	var piv := _insert_key()
	var tw := create_tween()
	tw.tween_property(mb_key, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	L._sfx3d("click", L.get_node("MusicBox").global_position, -10.0, 1.3)
	L._sfx3d("mb_windup", L.get_node("MusicBox").global_position, -4.0)
	await _turn_key(piv, 3)
	L.busy = false
	L._set_objective("NUR_19")
	L.extra_hints["n_box"] = "NUR_20"


var mb_key: Node3D            ## ключик в гнезде шкатулки (после завода так и торчит)
const KEY_SCALE := 1.6        ## ключик чуть крупнее «карманного» — под размер шкатулки
const STEM_END := 0.1428      ## конец штырька-гнезда (по X шкатулки)


## Ключик на оси гнезда (pivot крутится вокруг X шкатулки). Возвращает pivot; ключик пока снаружи.
func _insert_key() -> Node3D:
	var box: Node3D = L.get_node("MusicBox")
	var stem: MeshInstance3D = box.get_node("Crank")
	# штырёк короче и тоньше — на него надевается трубка ключика
	stem.scale = Vector3(0.6, 0.38, 0.6)
	stem.position = Vector3(0.12 + 0.0114, 0.05, 0.0)
	var piv := Node3D.new()
	piv.position = Vector3(STEM_END, 0.05, 0.0)
	box.add_child(piv)
	mb_key = Node3D.new()
	piv.add_child(mb_key)
	var m: Node3D = load("res://models/props/mb_key.glb").instantiate()
	mb_key.add_child(m)
	# у модели трубка вниз (-Y), «бабочка» в плоскости XY: трубку — к шкатулке (-X), крылья — вертикально
	m.basis = Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)).scaled(Vector3.ONE * KEY_SCALE)
	var lo := INF
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (mi as MeshInstance3D).get_aabb()
		lo = minf(lo, a.position.y)
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(-lo * KEY_SCALE - 0.012, 0.0, 0.0)     # трубка заходит на штырёк на 12 мм
	mb_key.position.x = 0.07                                     # пока снаружи — въезжает твином
	return piv


## Провернуть ключик n раз по пол-оборота — рывками, как заводят пружину.
func _turn_key(piv: Node3D, n: int, t := 0.36) -> void:
	for i in n:
		var tw := create_tween()
		tw.tween_property(piv, "rotation:x", piv.rotation.x - PI, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
		await get_tree().create_timer(0.12).timeout


func _note(k: int, pitch := 1.0, db := -2.0) -> void:
	var a := AudioStreamPlayer3D.new()
	a.stream = L._stream("mb_note%d" % k)
	a.pitch_scale = pitch
	a.volume_db = db
	L.add_child(a)
	a.global_position = L.get_node("MusicBox").global_position
	a.finished.connect(a.queue_free)
	a.play()


## Игрушка, на которую игрок не смотрит, поворачивается к нему.
func _turn_hidden_toy() -> void:
	var order := toys.duplicate()
	order.shuffle()
	for n in order:
		var toy: Node3D = L.get_node(n)
		if L.haunts._looking(toy.global_position + Vector3(0, 0.3, 0), 0.9):
			continue
		_face(toy)
		L.haunts._once3d("creak", toy.global_position, -10.0, 1.4)
		return


func _face(toy: Node3D) -> void:
	var d: Vector3 = L.player.global_position - toy.global_position
	var yaw := atan2(d.x, d.z)
	if toy.name == "NHorse":
		yaw += PI / 2      # у лошадки «перёд» смотрит вдоль оси X
	toy.rotation.y = yaw


# ---------------- под кроватью ----------------
func _under_bed() -> void:
	bed_scare_done = true
	L.busy = true
	var p = L.player
	p.frozen = true
	var head: Node3D = p.head
	var base_y := head.position.y
	# присел у кровати и заглянул в щель под ней
	var eyes: Node3D = L.get_node("BedEyes")
	var drawing: Node3D = L.get_node("Drawing5")
	var into: Vector3 = L.get_node("NBedCol").global_position - drawing.global_position
	into.y = 0.0
	into = into.normalized()
	if BED_GRAB:
		ResourceLoader.load_threaded_request(preload("res://scripts/fp_arm.gd").BODY)
	var spot := Vector3(0.25, p.global_position.y, -22.55)
	var look_at_: Vector3 = drawing.global_position + into * 0.1 if BED_GRAB else eyes.global_position
	var to := look_at_ - (spot + Vector3(0, 0.45, 0))
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var tw := create_tween().set_parallel()
	tw.tween_property(p, "global_position", spot, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(p, "rotation:y", p.rotation.y + wrapf(yaw - p.rotation.y, -PI, PI), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(head, "position:y", 0.45, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(head, "rotation:x", pitch, 0.6)
	await tw.finished
	L._sfx("creak", -16.0, 1.6)
	if BED_GRAB:
		await get_tree().create_timer(0.4).timeout
		bed_grab = preload("res://scripts/bed_grab.gd").new()
		add_child(bed_grab)
		await bed_grab.run(L, drawing, into, base_y)
	else:
		await get_tree().create_timer(1.0).timeout
		eyes.visible = true
		L._sfx("whisper", 0.0, 1.3)
		L._say("NUR_22", 2.5)
		await get_tree().create_timer(1.3).timeout
		eyes.visible = false
	p.flicker = 0.4
	# встаёт — а она уже стоит прямо перед ним
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(head, "position:y", base_y, 0.45).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(head, "rotation:x", 0.0, 0.45)
	await tw2.finished
	var girl: Node3D = L.girl
	var f: Vector3 = p.forward()
	f.y = 0.0
	girl.global_position = p.global_position + f.normalized() * 0.6
	L._face(girl, p.global_position)
	_gpose("reach", 2.2, 0.6, 0.7)
	girl.visible = true
	L._sfx("sting", 2.0)
	L._sfx("scream", 0.0, 1.25)
	L.girl_sp.scream(0.7)
	p.shake = 0.9
	L.red_flash.color.a = 0.5
	create_tween().tween_property(L.red_flash, "color:a", 0.0, 0.8)
	await get_tree().create_timer(0.55).timeout
	girl.visible = false
	_gpose("idle", -1.0, 0.0)
	await get_tree().create_timer(0.6).timeout
	L.busy = false
	p.frozen = false
	_show(4)


# ---------------- разгадано: финал демки ----------------
func _solve() -> void:
	solved = true
	L.busy = true
	var p = L.player
	# мелодия сыграна — дверь детской тут же захлопывается: убежать уже не выйдет
	if not door_locked:
		_lock_door()
	L._sfx3d("mb_windup", L.get_node("MusicBox").global_position, -2.0)   # шкатулка заводится сама
	if mb_key:
		_turn_key(mb_key.get_parent(), 3, 0.3)                            # ключик крутится сам
	await get_tree().create_timer(1.6).timeout
	# шкатулка играет мелодию сама, все игрушки разом поворачиваются к игроку
	for rep in 2:
		for k in CODE:
			_note(k, 1.0 - rep * 0.06, -2.0)
			await get_tree().create_timer(0.5 + rep * 0.15).timeout
		if rep == 0:
			for n in toys:
				_face(L.get_node(n))
			p.flicker = 0.3
			L._sfx("creak", -6.0, 0.8)
	await get_tree().create_timer(1.0).timeout
	# свет уходит
	for n in ["MoonNW", "MoonNE", "NursFill"]:
		create_tween().tween_property(L.get_node(n), "light_energy", 0.0, 2.0)
	L.get_node("NightLight").light_energy = 0.0
	L.drone.stop()
	await get_tree().create_timer(1.5).timeout
	L._sfx("whisper", 0.0, 1.2)
	L._say("NUR_24", 3.0)
	await get_tree().create_timer(1.2).timeout
	_start_hide()


# ---------------- прятки ----------------
## Аня прячется в одном из мест комнаты. Её смешок слышен оттуда, а в осколке видны её следы мелом.
func _start_hide() -> void:
	var keys := SPOTS.keys()
	hide_spot = _test_spot if SPOTS.has(_test_spot) else (FORCE_SPOT if SPOTS.has(FORCE_SPOT) else keys.pick_random())
	hiding = true
	_checked.clear()
	_giggle_t = 2.5
	L._set_objective("NUR_HIDE_OBJ")
	L.busy = false
	# детские следы мелом от середины комнаты к тайнику — только в стекле
	var from := Vector3(0.1, 0.035, -21.0)
	var to: Vector3 = SPOTS[hide_spot][0]
	to.y = 0.035
	var n := int(from.distance_to(to) / 0.28)
	var dir := (to - from).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _foot_tex()
	mat.albedo_color = Color(0.75, 0.9, 1.0, 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in n:
		var f := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.08, 0.18)
		q.orientation = PlaneMesh.FACE_Y
		f.mesh = q
		f.material_override = mat
		f.layers = L.hallp.MIRROR_LAYER
		f.position = from + dir * (0.28 * (i + 0.5)) + side * (0.06 if i % 2 == 0 else -0.06)
		f.rotation.y = atan2(dir.x, dir.z) + PI          # пальчики — по ходу движения
		L.add_child(f)
		_steps.append(f)


## Детский след: стопа и пять пальчиков, мягкие края.
func _foot_tex() -> ImageTexture:
	var w := 64
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var blobs := [[32.0, 80.0, 17.0, 34.0], [30.0, 40.0, 19.0, 16.0]]
	for tx in [[18.0, 18.0, 6.0], [27.0, 13.0, 5.5], [36.0, 12.0, 5.0], [44.0, 15.0, 4.5], [50.0, 21.0, 4.0]]:
		blobs.append([tx[0], tx[1], tx[2], tx[2]])
	for y in h:
		for x in w:
			var a := 0.0
			for b in blobs:
				var d := Vector2((x - b[0]) / b[2], (y - b[1]) / b[3]).length()
				a = maxf(a, clampf((1.0 - d) * 3.0, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _update_hide(delta: float) -> void:
	_giggle_t -= delta
	if _giggle_t <= 0.0 and not L.busy:
		_giggle_t = randf_range(6.0, 9.5)
		L._sfx3d("giggle", SPOTS[hide_spot][0], -12.0, randf_range(1.0, 1.15))


func _check_spot(id: String) -> void:
	var sp := id.trim_prefix("n_s_")
	_checked[id] = true
	L.busy = true
	await _search_anim(sp)
	if sp == hide_spot:
		_found()
		return
	# не там: шёпот у уха, игрушка за спиной поворачивается, свет дёргается — а смешок уже с другой стороны
	L._sfx("whisper_harsh", -4.0)
	L._sfx("sting", -10.0, 0.75)
	L.player.flicker = 0.6
	L.player.shake = 0.25
	_turn_hidden_toy()
	await get_tree().create_timer(0.9).timeout
	L._sfx3d("giggle", SPOTS[hide_spot][0], -8.0, 1.2)
	_giggle_t = randf_range(5.0, 7.0)
	L.busy = false


## Заглянуть / отдёрнуть: штора качается, под кроватью и столом — скрип.
func _search_anim(sp: String) -> void:
	var pos: Vector3 = SPOTS[sp][0]
	if sp.begins_with("curt"):
		var c: Node3D = L.get_node("NCurtainW" if sp == "curt_w" else "NCurtainE")
		var x0 := c.position.x
		L._sfx3d("sheet_rustle", pos, -6.0, 1.0)
		var tw := create_tween()
		tw.tween_property(c, "position:x", x0 - signf(x0) * 0.12, 0.25)
		tw.tween_property(c, "position:x", x0, 0.6).set_trans(Tween.TRANS_SINE)
		await get_tree().create_timer(0.35).timeout
	else:
		L._sfx3d("creak", pos, -10.0, 1.3)
		await get_tree().create_timer(0.5).timeout


## Нашёл: она там — и теперь водит она.
func _found() -> void:
	if FOUND_V2:
		_found_v2()
	else:
		_found_v1()


## Как было до FOUND_V2: она просто стоит в самом тайнике — и счёт.
func _found_v1() -> void:
	hiding = false
	for f in _steps:
		f.queue_free()
	_steps.clear()
	var p = L.player
	var girl: Node3D = L.girl
	var at: Vector3 = SPOTS[hide_spot][0]
	at.y = p.global_position.y
	girl.global_position = at
	L._face(girl, p.global_position)
	_gpose("zidle", 2.0, 0.4)
	girl.visible = true
	L._sfx("sting", -2.0)
	L._sfx("girl_appear", -2.0)
	p.shake = 0.5
	await get_tree().create_timer(0.8).timeout
	L._sfx("whisper", -2.0, 1.3)
	L._say("NUR_FOUND", 2.8)
	await get_tree().create_timer(2.0).timeout
	_finale_count()


## FOUND_V2: под кроватью и столом — пусто, она над тобой; за шторой и креслом — пусто, она за спиной.
func _found_v2() -> void:
	hiding = false
	for f in _steps:
		f.queue_free()
	_steps.clear()
	match hide_spot:
		"bed":
			await _above(Vector3(0.12, 0.0, -22.6), Vector3(-1.35, 0.12, -22.7), BED_TOP, 0.9, 0.2, 1.3)
		"desk":
			await _above(Vector3(0.88, 0.0, -19.08), Vector3(1.95, 0.2, -19.0), DESK_TOP, 1.05, 0.22, 1.6)
		_:
			await _behind()
	await _regroup()
	_finale_count()


## «Она над тобой». Миша присел у кровати (стола) и заглянул вниз — там пусто и темно. Скрип сверху,
## смешок прямо над головой. Начинает выпрямляться — а она стоит наверху, согнувшись над ним: лицо над его лицом,
## длинные волосы свисают отвесно, ему в лицо (spirit.gdshader: hang). Резкий крик.
## crouch — где он приседает, under — куда смотрит внизу, stand — где её ноги наверху,
## bend — наклон спины, lean — наклон всей фигуры от ступней (рад), eye — до какой высоты он успевает подняться.
func _above(crouch: Vector3, under: Vector3, stand: Vector3, bend: float, lean: float, eye: float) -> void:
	var p = L.player
	var head: Node3D = p.head
	_eye_base = head.position.y
	var girl: Node3D = L.girl
	var g = L.girl_sp
	p.frozen = true
	crouch.y = p.global_position.y
	var to := under - (crouch + Vector3(0, 0.45, 0))
	var yaw := atan2(-to.x, -to.z)
	var tw := create_tween().set_parallel()
	tw.tween_property(p, "global_position", crouch, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(p, "rotation:y", p.rotation.y + wrapf(yaw - p.rotation.y, -PI, PI), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(head, "position:y", 0.45, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(head, "rotation:x", atan2(to.y, Vector2(to.x, to.z).length()), 0.6)
	await tw.finished
	# пусто. Тишина... над головой скрипнула кровать
	await get_tree().create_timer(1.1).timeout
	L._sfx3d("creak", stand + Vector3(0, 0.15, 0), -5.0, 0.7)
	await get_tree().create_timer(0.7).timeout
	# она уже наверху: стоит на краю и нависает над ним — спина согнута, руки и волосы висят отвесно
	girl.global_position = stand
	girl.rotation = Vector3(lean, atan2(crouch.x - stand.x, crouch.z - stand.z), 0.0)
	_gpose("idle", 1.0, 0.55)
	_bend_on(bend)
	if not g.v3:                     # у Ани v3 волосы висят сами (физика) — голову «замораживать» не нужно
		g.life.life = 0.0            # голова — одним целым со спиной (иначе висящие пряди рвутся); живость вернём потом
		g._p("hang", 1.0)
	g._p("near_cut", 0.1)            # пряди у самого объектива не рисовать
	girl.visible = true
	var face: Vector3 = await _girl_face()
	L._sfx3d("giggle", face, -2.0, 1.05)
	await get_tree().create_timer(1.0).timeout
	# выпрямляется — и упирается взглядом в её лицо
	var d := face - (crouch + Vector3(0, eye, 0))
	var yaw2 := atan2(-d.x, -d.z)
	var pitch2 := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.2, 1.2)
	_fill_on()
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(head, "position:y", eye, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw2.tween_property(head, "rotation:x", pitch2, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw2.tween_property(p, "rotation:y", p.rotation.y + wrapf(yaw2 - p.rotation.y, -PI, PI), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.35).timeout
	_scream_in_face(0.5)
	await tw2.finished
	await get_tree().create_timer(0.8).timeout


## Тайник пуст (штора, кресло) — и смешок прямо за спиной. Миша оборачивается — она стоит вплотную.
func _behind() -> void:
	var p = L.player
	var girl: Node3D = L.girl
	var g = L.girl_sp
	p.frozen = true
	await get_tree().create_timer(0.7).timeout
	var back: Vector3 = -p.forward()
	back.y = 0.0
	back = back.normalized()
	var at := _free_spot(p.global_position + back * 0.62, 0.45)
	girl.global_position = at
	L._face(girl, p.global_position)
	_gpose("reach", 1.3, 0.6)
	g.life.look_w = 1.0
	girl.visible = true
	var face: Vector3 = await _girl_face()
	L._sfx3d("giggle", face, -2.0, 1.1)
	await get_tree().create_timer(0.9).timeout
	# оборачивается
	_fill_on()
	var d: Vector3 = face - p.cam.global_position
	var yaw := atan2(-d.x, -d.z)
	var tw := create_tween().set_parallel()
	tw.tween_property(p, "rotation:y", p.rotation.y + wrapf(yaw - p.rotation.y, -PI, PI), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(p.head, "rotation:x", clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.0, 1.0), 0.45)
	await get_tree().create_timer(0.25).timeout
	_scream_in_face()
	await tw.finished
	await get_tree().create_timer(0.8).timeout


## Крик в лицо: рот распахнут, волосы дыбом, вспышка.
func _scream_in_face(lift := 0.7) -> void:
	var p = L.player
	L._sfx("sting", 2.0)
	L._sfx("scream", 0.0, 1.25)
	L.girl_sp.scream(0.8)
	L.girl_sp.set_lift(lift)
	L.girl_sp.set_blood(0.75)
	p.shake = 1.0
	L.red_flash.color.a = 0.45
	create_tween().tween_property(L.red_flash, "color:a", 0.0, 0.8)


## После крика: фонарь гаснет, она пропадает; загорается — она уже стоит поодаль на полу, перед Мишей.
## «Нашёл... Теперь я вожу» — дальше счёт.
func _regroup() -> void:
	var p = L.player
	var girl: Node3D = L.girl
	var g = L.girl_sp
	p.light_on = false
	await get_tree().create_timer(0.1).timeout
	girl.visible = false
	_bend_off()
	_fill_off()
	g.set_lift(0.0)
	g._p("hang", 0.0)
	g._p("near_cut", 0.0)
	g.life.life = 1.0
	girl.rotation.x = 0.0
	# в темноте Миша поднимается во весь рост и опускает взгляд
	var tw := create_tween().set_parallel()
	tw.tween_property(p.head, "position:y", _eye_base, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(p.head, "rotation:x", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(1.0).timeout
	girl.global_position = _spot_in_view()
	var dg: Vector3 = girl.global_position - p.global_position
	p.rotation.y = atan2(-dg.x, -dg.z)          # в темноте повернулся к ней: фонарь загорится — она в луче
	L._face(girl, p.global_position)
	_gpose("zidle", 2.0, 0.45)
	girl.visible = true
	p.light_on = true
	p.flicker = 0.25
	p.frozen = false
	L._sfx("whisper", -2.0, 1.3)
	L._say("NUR_FOUND", 2.8)
	await get_tree().create_timer(2.0).timeout


## Вплотную фонарь бьёт мимо (он сбоку от глаз) — слабый холодный «отсвет», чтобы её было видно.
func _fill_on() -> void:
	_fill_off()
	_fill = OmniLight3D.new()
	_fill.light_color = Color(0.55, 0.62, 0.8)
	_fill.light_energy = 0.45
	_fill.omni_range = 1.3
	_fill.omni_attenuation = 1.6
	_fill.shadow_enabled = false
	L.player.cam.add_child(_fill)
	_fill.position = Vector3(0.0, -0.12, -0.05)


func _fill_off() -> void:
	if _fill and is_instance_valid(_fill):
		_fill.queue_free()
	_fill = null


## Согнуть её вперёд (поверх анимации). Модификатор — до «живости»: взгляд считается по согнутой спине.
func _bend_on(angle: float) -> void:
	_bend_off()
	var g = L.girl_sp
	_bend = preload("res://scripts/spirit_bend.gd").new()
	_bend.angle = angle
	if g.v3:                         # кости Ани v3: спина гнётся плавно по четырём позвонкам
		_bend.chain = [["spine05", 0.3], ["spine04", 0.3], ["spine03", 0.25], ["spine02", 0.15]]
		_bend.arm_names = [["upperarm01_L", "lowerarm01_L", "wrist_L"], ["upperarm01_R", "lowerarm01_R", "wrist_R"]]
	g.sk.add_child(_bend)
	g.sk.move_child(_bend, g.life.get_index())


func _bend_off() -> void:
	if _bend and is_instance_valid(_bend):
		_bend.queue_free()
	_bend = null


## Где сейчас её лицо (мир): глаза — от кости головы, как в spirit.gd. Поза с наклоном и взглядом
## есть в скелете только во время его обновления (потом он возвращает позу анимации) — ловим её там.
func _girl_face() -> Vector3:
	return await L.girl_sp.face_point()


## Можно ли ей стоять в точке c (на полу): внутри комнаты, не в мебели и не в стене.
func _spot_free(c: Vector3, r := 0.24) -> bool:
	if not ROOM.has_point(Vector2(c.x, c.z)):
		return false
	var p = L.player
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(r * 2.0, 1.3, r * 2.0)
	q.shape = box
	q.exclude = [p.get_rid()]
	q.transform = Transform3D(Basis.IDENTITY, Vector3(c.x, p.global_position.y + 0.8, c.z))
	return (L as Node3D).get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Ближайшее к want свободное место на полу — не ближе near к Мише: сначала сама точка и круги вокруг неё
## (первым — направление к Мише); не нашлось — ближайшее свободное по всей комнате (сеткой).
func _free_spot(want: Vector3, near := 0.5) -> Vector3:
	var p = L.player
	var pp: Vector3 = p.global_position
	want.y = pp.y
	var to_p := Vector3(pp.x - want.x, 0.0, pp.z - want.z)
	var a0 := atan2(to_p.x, to_p.z) if to_p.length() > 0.01 else 0.0
	for r in [0.0, 0.12, 0.25, 0.4, 0.55, 0.75, 1.0]:
		for k in (1 if r == 0.0 else 12):
			var a: float = a0 + float((k + 1) / 2) * (TAU / 12.0) * (1.0 if k % 2 == 1 else -1.0)
			var c: Vector3 = want + Vector3(sin(a), 0.0, cos(a)) * r
			if Vector2(c.x - pp.x, c.z - pp.z).length() >= near and _spot_free(c):
				return c
	var cand := []
	var x := ROOM.position.x
	while x <= ROOM.end.x + 0.001:
		var z := ROOM.position.y
		while z <= ROOM.end.y + 0.001:
			var c := Vector3(x, pp.y, z)
			if Vector2(c.x - pp.x, c.z - pp.z).length() >= near:
				cand.append([Vector2(c.x - want.x, c.z - want.z).length(), c])
			z += 0.25
		x += 0.25
	cand.sort_custom(func(u, v): return u[0] < v[0])
	for c in cand:
		if _spot_free(c[1]):
			return c[1]
	return want


## Свободное место перед Мишей (в поле зрения), метрах в двух: сначала прямо, потом всё дальше в стороны;
## нигде — просто свободное подальше от него (в темноте он к ней повернётся).
func _spot_in_view() -> Vector3:
	var p = L.player
	var f: Vector3 = p.forward()
	f.y = 0.0
	f = f.normalized()
	for a in [0.0, 0.3, -0.3, 0.6, -0.6, 0.85, -0.85, 1.1, -1.1]:
		for d in [2.2, 1.9, 1.6, 1.35]:
			var c: Vector3 = p.global_position + f.rotated(Vector3.UP, a) * d
			if _spot_free(c):
				return c
	return _free_spot(p.global_position + f * 2.0, 1.3)


## Вплотную перед Мишей (в темноте, перед касанием): прямо перед ним, если там не стена и не мебель;
## иначе — чуть в сторону, и Миша (во тьме, незаметно) поворачивается к ней.
func _touch_spot() -> Vector3:
	var p = L.player
	var f: Vector3 = p.forward()
	f.y = 0.0
	f = f.normalized()
	for a in [0.0, 0.35, -0.35, 0.7, -0.7, 1.05, -1.05, 1.4, -1.4, 1.75, -1.75, 2.1, -2.1, 2.5, -2.5, PI]:
		for d in [0.55, 0.45]:
			var c: Vector3 = p.global_position + f.rotated(Vector3.UP, a) * d
			if _spot_free(c, 0.17):
				p.rotation.y += a
				return c
	var c2 := _free_spot(p.global_position + f * 0.55, 0.3)     # совсем зажат — ближайшее свободное
	var dg: Vector3 = c2 - p.global_position
	p.rotation.y = atan2(-dg.x, -dg.z)
	return c2


## Финал: она считает, с каждым счётом ближе, — и касается.
func _finale_count() -> void:
	L.busy = true
	var p = L.player
	var girl: Node3D = L.girl
	var f: Vector3
	if not door_locked:
		_lock_door()
	# на каждый счёт пропадает в мигании света и появляется ближе — каждый раз в новой жуткой позе и всё кровавее
	var poses := [["zidle", 2.7, 0.45, 0.0], ["reach", 1.3, 0.7, 0.0], ["idle", 3.2, 0.9, 0.0]]
	for k in 3:
		var word: String = ["NUR_25", "NUR_26", "NUR_27"][k]
		L._sfx("whisper", -4.0, 1.4)
		L._say(word, 1.2)
		p.flicker = 0.35
		await get_tree().create_timer(1.3).timeout
		girl.global_position = girl.global_position.lerp(p.global_position, 0.35)
		if FOUND_V2:                           # не в кровати, не в кресле, не в стене
			girl.global_position = _free_spot(girl.global_position, 0.7)
		L._face(girl, p.global_position)
		_gpose(poses[k][0], poses[k][1], poses[k][2], poses[k][3])
	p.light_on = false
	girl.visible = false
	await get_tree().create_timer(1.2).timeout
	# она касается: свет вспыхивает — девочка вплотную, крик (без маски — маска была один раз в коридоре)
	p.frozen = true
	f = p.forward()
	f.y = 0.0
	girl.global_position = p.global_position + f.normalized() * 0.55
	if FOUND_V2:
		girl.global_position = _touch_spot()
	L._face(girl, p.global_position)
	_gpose("reach", 1.7, 1.0, 1.0)            # тянет к тебе руку, вся в крови, волосы дыбом
	girl.visible = true
	p.light_on = true
	p.flicker = 0.0               # фонарь вспыхивает — она прямо перед лицом
	p.shake = 1.0
	L._sfx("sting", 2.0)
	L._sfx("scream", 0.0, 1.15)
	L.girl_sp.scream(0.9)
	L.red_flash.color.a = 0.3
	create_tween().tween_property(L.red_flash, "color:a", 0.0, 0.9)
	await get_tree().create_timer(0.9).timeout
	girl.visible = false
	L.fade.color.a = 1.0
	L._say("", 0.1)
	if L.drone:
		L.drone.stop()
	# Миша проваливается в забытьё — и вспоминает 1986-й (ролик), потом очнётся на чердаке
	await get_tree().create_timer(1.6).timeout
	var mem := preload("res://scripts/memory_video.gd").new()
	add_child(mem)
	await mem.play(L)
	mem.queue_free()
	await get_tree().create_timer(0.6).timeout
	# она забрала тебя к себе — 4-й уровень, чердак
	L.attic.enter()


## Поза девочки: анимация n на секунде t (t < 0 — играть), кровь, «волосы дыбом».
func _gpose(n: String, t: float, blood: float, lift := 0.0) -> void:
	var g = L.girl_sp
	if t < 0.0:
		g.play(n, 1.0, 0.0)
	else:
		g.play_from(n, t, 0.7)                 # не замирает: продолжает двигаться с этой позы
	g.set_blood(blood)
	g.set_lift(lift)
	g.float_h = 0.0
	g._float = 0.0


## Дверь в детскую захлопывается — бежать некуда.
func _lock_door() -> void:
	door_locked = true
	L.doors.lock("exit")
	var p = L.player
	var pos: Vector3 = p.global_position
	if pos.z > -18.05:                       # игрок успел выйти — затянуть обратно в комнату
		p.teleport(Vector3(0.0, 0.05, -19.4), p.rotation.y)
	elif pos.z > -19.0 and pos.x < 0.6:      # стоит там, где проходит полотно двери — шаг вглубь
		p.teleport(Vector3(pos.x, pos.y, -19.2), p.rotation.y)
	var tw := create_tween()
	tw.tween_property(L.exit_door, "rotation:y", 0.0, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	L._sfx3d("knock", L.exit_door.global_position + Vector3(0.43, 1.0, 0), 4.0, 0.8)
	L._sfx3d("door", L.exit_door.global_position, -4.0, 1.3)
	p.shake = 0.4
