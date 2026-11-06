extends CanvasLayer
## Инвентарь в стиле «Тьма». Tab — открыть / закрыть (Esc тоже закрывает).
## Игра встаёт на паузу, мир позади размывается и темнеет. В центре крупно выбранный предмет
## (крутится мышью с зажатой кнопкой, сам медленно поворачивается), под ним название и описание,
## внизу ряд остальных вещей. Q / E — вкладки «Предметы» и «Записки», A / D или колесо — листать.
##
## Скрипты комнат пользуются только add() / remove() / has() / add_note().

const FONT_TITLE := preload("res://fonts/CormorantSC-Light.ttf")
const FONT_TEXT := preload("res://fonts/Lora-Italic-Variable.ttf")
const BONE := Color(0.93, 0.89, 0.81)
const DIM := Color(0.62, 0.58, 0.51)

## id → [ключ названия, ключ описания]
const ITEMS := {
	"key": ["INV_KEY", "INV_KEY_D"],
	"shard": ["INV_SHARD", "INV_SHARD_D"],
	"hook": ["INV_HOOK", "INV_HOOK_D"],
	"bedkey": ["INV_BEDKEY", "INV_BEDKEY_D"],
	"attic_key": ["INV_ATTICKEY", "INV_ATTICKEY_D"],
	"matches": ["INV_MATCHES", "INV_MATCHES_D"],
	"mb_key": ["INV_MBKEY", "INV_MBKEY_D"],
	"att_dress": ["INV_DRESS", "INV_DRESS_D"],
	"att_scarf": ["INV_SCARF", "INV_SCARF_D"],
	"att_bow": ["INV_BOW", "INV_BOW_D"],
	"att_shoes": ["INV_SHOES", "INV_SHOES_D"],
	"candle": ["INV_CANDLE", "INV_CANDLE_D"],
	"v_tooth1": ["INV_TOOTH", "INV_TOOTH_D"],
	"v_tooth2": ["INV_TOOTH", "INV_TOOTH_D"],
	"v_tooth3": ["INV_TOOTH", "INV_TOOTH_D"],
	"shawl": ["INV_SHAWL", "INV_SHAWL_D"],
	"smallkey": ["INV_SMALLKEY", "INV_SMALLKEY_D"],
	"dolleye": ["INV_DOLLEYE", "INV_DOLLEYE_D"],
	"v_photo": ["INV_VPHOTO", "INV_VPHOTO_D"],
}
const MAX_ITEMS := 8
const PROPS := {
	"key": "res://models/props/key_hall.glb",
	"bedkey": "res://models/props/key_vera.glb",
	"attic_key": "res://models/props/key_attic.glb",
	"matches": "res://models/props/matchbox.glb",
	"mb_key": "res://models/props/mb_key.glb",
}          ## больше не унести
## как повернуть предмет к камере (ключи и крюк лежат плашмя — поднимаем кольцом к игроку)
const POSE := {"key": Vector3(PI / 2, 0, 0.35), "bedkey": Vector3(PI / 2, 0, 0.35), "attic_key": Vector3(PI / 2, 0, 0.35), "hook": Vector3(PI / 2, 0, 0.55), "matches": Vector3(1.05, -0.5, 0), "mb_key": Vector3(0, 0, 0.4), "shard": Vector3(PI / 2 - 0.25, 0, 0.5)}
## текст записки → её заголовок в инвентаре
const NOTE_TITLES := {"LVL_01": "INV_N_GRANDMA", "LVL_02": "INV_N_CABINET", "NUR_11": "INV_N_ANYA",
	"LVL_13": "INV_N_PHOTO75", "LVL_14": "INV_N_PHOTO76", "LVL_15": "INV_N_PHOTO77", "LVL_52": "INV_N_PHOTO79", "VL_NOTE": "INV_N_VERA"}
## записки-фотографии: сам снимок показывается под текстом
const NOTE_IMAGES := {"LVL_52": "res://textures/attic_photo.png"}

var L: Node
var items: Array[String] = []
var notes: Array[String] = []       ## ключи записок (заголовок берётся из NOTE_TITLES)
var _note_txt := {}                 ## ключ → готовый текст (если в нём подставлены числа)
var is_open := false

var _models := {}            ## id → шаблон модели (Node3D вне дерева)
var _sel := 0
var _note_sel := 0
var _tab := 0                ## 0 — предметы, 1 — записки
var _told_tab := false

var _bg: ColorRect
var _bg_mat: ShaderMaterial
var _root: Control
var _tab_items: Label
var _tab_notes: Label
var _count: Label
var _big: TextureRect
var _name: Label
var _desc: Label
var _row: HBoxContainer
var _empty: Label
var _note_title: Label
var _note_text: Label
var _note_img: TextureRect
var _keys: Label
var _toast: Label

var _world: World3D
var _vp: SubViewport
var _cam: Camera3D
var _pivot: Node3D           ## выбранный предмет крупно
var _yaw := 0.0
var _pitch := 0.0
var _drag := false
var _row_vps: Array[SubViewport] = []
var _fade: Tween
# бирка на ключе Веры качается, как маятник, когда крутишь ключ
var _swing: Node3D
var _sw_dir := Vector3.DOWN
var _sw_vel := Vector3.ZERO
var _sw_prev_p := Vector3.ZERO
var _sw_prev_v := Vector3.ZERO
var _toast_tw: Tween
var _toast_lines: Array[String] = []


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_world()
	_build_ui()
	_set_open(false, true)


# ---------------------------------------------------------------- API для комнат

func has(id: String) -> bool:
	return id in items


## Предмет «в руках» — тот, что выбран в инвентаре (последний подобранный, пока не выберешь другой).
func selected() -> String:
	return items[_sel] if _sel < items.size() else ""


func is_full() -> bool:
	return items.size() >= MAX_ITEMS


## Положить предмет. template — узел, с которого снять внешний вид (иначе модель строится сама).
func add(id: String, template: Node3D = null, announce := true) -> bool:
	if id in items:
		return true
	if is_full():
		L._say("INV_FULL", 2.5)
		return false
	if template:
		var t := template.duplicate() as Node3D
		t.transform = Transform3D.IDENTITY
		_models[id] = t
	items.append(id)
	_sel = items.size() - 1
	if announce:
		_announce(tr(ITEMS[id][0]))
	return true


func remove(id: String) -> void:
	var i := items.find(id)
	if i < 0:
		return
	items.remove_at(i)
	_sel = clampi(_sel, 0, maxi(items.size() - 1, 0))


## Прочитанная записка попадает во вкладку «Записки», чтобы её можно было перечитать.
func add_note(text_key: String, text := "") -> void:
	if text != "":
		_note_txt[text_key] = text
	if text_key in notes:
		return
	notes.append(text_key)
	_note_sel = notes.size() - 1


# ---------------------------------------------------------------- открыть / закрыть

func can_open() -> bool:
	if L == null or get_tree().paused or L.busy or L.player.frozen:
		return false
	if L.phase == "end" or L.note_panel.visible:
		return false
	if L.hallp and L.hallp.holding:
		return false
	return true


func _set_open(on: bool, instant := false) -> void:
	is_open = on
	if on:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_tab = 0 if not items.is_empty() or notes.is_empty() else 1
		_drag = false
		_yaw = 0.0
		_pitch = 0.0
		_refresh()
		if _toast_tw:
			_toast_tw.kill()
		_toast.modulate.a = 0.0
		_told_tab = true
		_play("page", -10.0, 0.9)
	else:
		_drag = false
		if not instant:
			_play("page", -14.0, 1.1)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	for v in _row_vps:
		v.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if _fade:
		_fade.kill()
	var to := 1.0 if on else 0.0
	if instant:
		_bg_mat.set_shader_parameter("amount", to)
		_root.modulate.a = to
		_bg.visible = on
		_root.visible = on
		return
	_bg.visible = true
	_root.visible = true
	_fade = create_tween().set_parallel()
	_fade.tween_method(func(v: float): _bg_mat.set_shader_parameter("amount", v), 1.0 - to, to, 0.22)
	_fade.tween_property(_root, "modulate:a", to, 0.18)
	if not on:
		_fade.chain().tween_callback(func():
			_bg.visible = false
			_root.visible = false
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(e: InputEvent) -> void:
	if is_open:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_TAB and can_open():
		_set_open(true)
		get_viewport().set_input_as_handled()


func _input(e: InputEvent) -> void:
	if not is_open:
		return
	if e is InputEventKey and e.pressed:
		match e.physical_keycode:
			KEY_TAB, KEY_ESCAPE:
				if not e.echo:
					_set_open(false)
			KEY_A, KEY_LEFT:
				_step(-1)
			KEY_D, KEY_RIGHT:
				_step(1)
			KEY_Q:
				_switch_tab(0)
			KEY_E:
				_switch_tab(1)
	elif e is InputEventMouseButton and e.pressed:
		match e.button_index:
			MOUSE_BUTTON_WHEEL_UP: _step(-1)
			MOUSE_BUTTON_WHEEL_DOWN: _step(1)
			MOUSE_BUTTON_LEFT: _drag = true
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_drag = false
	elif e is InputEventMouseMotion and _drag and _tab == 0:
		_yaw += e.relative.x * 0.01
		_pitch = clampf(_pitch + e.relative.y * 0.01, -1.2, 1.2)
	get_viewport().set_input_as_handled()


func _step(d: int) -> void:
	if _tab == 0 and items.size() > 1:
		_sel = wrapi(_sel + d, 0, items.size())
		_yaw = 0.0
		_pitch = 0.0
	elif _tab == 1 and notes.size() > 1:
		_note_sel = wrapi(_note_sel + d, 0, notes.size())
	else:
		return
	_play("click", -18.0, 1.4)
	_refresh()


func _switch_tab(t: int) -> void:
	if t == _tab:
		return
	_tab = t
	_play("page", -14.0, 1.0)
	_refresh()


func _process(delta: float) -> void:
	if not is_open or _pivot.get_child_count() == 0:
		return
	if not _drag:
		_yaw += delta * 0.35
		_pitch = lerpf(_pitch, 0.0, delta * 1.5)
	_pivot.rotation = Vector3(_pitch, _yaw, 0.0)
	_update_swing(delta)


## Ленточка с биркой (узлы Ribbon/Tag в модели) вешается на шарнир у головки ключа.
func _setup_swing(model: Node) -> void:
	_swing = null
	var rib := model.find_child("Ribbon", true, false) as Node3D
	var tag := model.find_child("Tag", true, false) as Node3D
	if rib == null or tag == null:
		return
	var sw := Node3D.new()
	sw.name = "Swing"
	rib.get_parent().add_child(sw)
	sw.position = rib.position            # петля ленточки — точка подвеса
	rib.reparent(sw)
	tag.reparent(sw)
	_swing = sw
	_sw_dir = Vector3.DOWN
	_sw_vel = Vector3.ZERO
	_sw_prev_p = sw.global_position
	_sw_prev_v = Vector3.ZERO


## Маятник: направление «ленточка → бирка» живёт в мире, его тянет вниз, а рывки ключа его раскачивают.
func _update_swing(dt: float) -> void:
	if _swing == null or not is_instance_valid(_swing) or dt <= 0.0:
		return
	var par := _swing.get_parent() as Node3D
	var p := _swing.global_position
	var pv := (p - _sw_prev_p) / dt
	var pa := (pv - _sw_prev_v) / dt
	_sw_prev_p = p
	_sw_prev_v = pv
	var acc := Vector3.DOWN * 9.0 - pa.limit_length(60.0) * 0.5
	acc -= _sw_dir * acc.dot(_sw_dir)
	_sw_vel += acc * dt
	_sw_vel -= _sw_dir * _sw_vel.dot(_sw_dir)
	_sw_vel *= exp(-1.6 * dt)
	_sw_dir = (_sw_dir + _sw_vel * dt).normalized()
	var local := (par.global_basis.inverse() * _sw_dir).normalized()
	_swing.quaternion = Quaternion(Vector3(0, 0, 1), local)


# ---------------------------------------------------------------- отрисовка

func _refresh() -> void:
	var on_items := _tab == 0
	_tab_items.modulate = BONE if on_items else Color(DIM, 0.55)
	_tab_notes.modulate = BONE if not on_items else Color(DIM, 0.55)
	_bg_mat.set_shader_parameter("glow", 1.0 if on_items and not items.is_empty() else 0.25)
	for n in [_big, _name, _desc, _row]:
		n.visible = on_items and not items.is_empty()
	_note_title.visible = not on_items and not notes.is_empty()
	_note_text.visible = _note_title.visible
	_note_img.visible = false
	_empty.visible = (on_items and items.is_empty()) or (not on_items and notes.is_empty())
	_empty.text = tr("INV_EMPTY") if on_items else tr("INV_NOTES_EMPTY")
	if on_items:
		_count.text = "%d / %d" % [_sel + 1, items.size()] if not items.is_empty() else ""
		_keys.text = tr("INV_KEYS")
		_show_items()
	else:
		_count.text = "%d / %d" % [_note_sel + 1, notes.size()] if not notes.is_empty() else ""
		_keys.text = tr("INV_KEYS_N")
		if not notes.is_empty():
			var k := notes[_note_sel]
			_note_title.text = tr(NOTE_TITLES.get(k, "INV_NOTE"))
			_note_text.text = _note_txt.get(k, tr(k))
			_note_text.add_theme_font_size_override("font_size", 15 if _note_text.text.length() > 380 else 18)
			if NOTE_IMAGES.has(k):
				_note_img.texture = load(NOTE_IMAGES[k])
				_note_img.visible = true


func _show_items() -> void:
	for c in _pivot.get_children():
		c.queue_free()
	for v in _row_vps:
		v.queue_free()
	_row_vps.clear()
	for c in _row.get_children():
		c.queue_free()
	if items.is_empty():
		return
	var id := items[_sel]
	_name.text = tr(ITEMS[id][0])
	_desc.text = tr(ITEMS[id][1])
	_pivot.add_child(_fitted(id))
	_setup_swing(_pivot.get_child(_pivot.get_child_count() - 1))
	# ряд остальных: у каждой иконки своя маленькая камера, предметы стоят далеко друг от друга
	for i in items.size():
		var spot := Vector3(100.0 + i * 10.0, 0, 0)
		var holder := Node3D.new()
		holder.position = spot
		holder.rotation = Vector3(0.2, -0.35, 0)
		holder.add_child(_fitted(items[i]))
		var v := SubViewport.new()
		v.world_3d = _world
		v.transparent_bg = true
		v.size = Vector2i(160, 160)
		v.msaa_3d = Viewport.MSAA_4X
		v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var c := Camera3D.new()
		c.fov = 30.0
		c.position = spot + Vector3(0, 0, 3.3)
		v.add_child(c)
		v.add_child(holder)
		add_child(v)
		_row_vps.append(v)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_END
		box.add_theme_constant_override("separation", 6)
		var tr_ := TextureRect.new()
		tr_.texture = v.get_texture()
		tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var s := 74.0 if i == _sel else 56.0
		tr_.custom_minimum_size = Vector2(s, s)
		tr_.modulate = Color.WHITE if i == _sel else Color(1, 1, 1, 0.45)
		box.add_child(tr_)
		var line := ColorRect.new()
		line.custom_minimum_size = Vector2(28, 1.5)
		line.color = Color(0.85, 0.77, 0.6) if i == _sel else Color(0, 0, 0, 0)
		line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(line)
		_row.add_child(box)


## Копия модели предмета, отцентрованная и подогнанная под шар радиуса 1.
func _fitted(id: String) -> Node3D:
	var m: Node3D = (_models[id] if _models.has(id) else _build_model(id)).duplicate()
	if not _models.has(id):
		_models[id] = m.duplicate()
	m.transform = Transform3D.IDENTITY
	_show_all(m)
	var pose := Node3D.new()
	pose.rotation = POSE.get(id, Vector3.ZERO)
	pose.add_child(m)
	var box := _aabb(pose, pose.transform)
	var r: float = maxf(box.size.length() * 0.5, 0.001)
	var wrap := Node3D.new()
	wrap.scale = Vector3.ONE / r
	pose.position = -box.get_center()
	wrap.add_child(pose)
	return wrap


func _show_all(n: Node) -> void:
	if n is Node3D:
		n.visible = true
	if n is Light3D:
		n.visible = false
	for c in n.get_children():
		_show_all(c)


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var boxes: Array[AABB] = []
	_collect(n, xf, boxes)
	if boxes.is_empty():
		return AABB(Vector3(-0.05, -0.05, -0.05), Vector3(0.1, 0.1, 0.1))
	var out: AABB = boxes[0]
	for b in boxes:
		out = out.merge(b)
	return out


func _collect(n: Node, xf: Transform3D, boxes: Array[AABB]) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		boxes.append(xf * (n as MeshInstance3D).mesh.get_aabb())
	for c in n.get_children():
		if c is Node3D:
			_collect(c, xf * (c as Node3D).transform, boxes)


## Модели предметов, которые не передали шаблоном: собираем из кусков уже существующего ключа.
func _build_model(id: String) -> Node3D:
	var root := Node3D.new()
	match id:
		"key", "bedkey", "attic_key", "matches", "mb_key":
			# модели из Blender (tools/blender/make_props.py, make_mbkey.py): геометрия + запечённые текстуры
			root.add_child(load(PROPS[id]).instantiate())
		"shard":
			root.add_child(glass_shard())
	return root


## Осколок стекла из Blender со своими материалами: прозрачные грани и зеленоватый торец.
static func glass_shard() -> Node3D:
	var n: Node3D = load("res://models/props/shard.glb").instantiate()
	var face := ShaderMaterial.new()
	face.shader = preload("res://shaders/glass.gdshader")
	var rim := ShaderMaterial.new()
	rim.shader = face.shader
	rim.set_shader_parameter("edge", 1.0)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for k in m.mesh.get_surface_count():
			m.set_surface_override_material(k, face if k == 0 else rim)
	return n


func _metal(c: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	return m


# ---------------------------------------------------------------- построение

func _build_world() -> void:
	_world = World3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.25, 0.27, 0.32)
	sm.sky_horizon_color = Color(0.55, 0.5, 0.42)
	sm.ground_bottom_color = Color(0.03, 0.03, 0.03)
	sm.ground_horizon_color = Color(0.3, 0.27, 0.22)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.42, 0.38)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_world.environment = env
	_vp = SubViewport.new()
	_vp.world_3d = _world
	_vp.transparent_bg = true
	_vp.size = Vector2i(900, 900)
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.7, -0.6, 0)
	key.light_energy = 1.7
	key.light_color = Color(1, 0.9, 0.76)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.2, 2.5, 0)
	rim.light_energy = 0.8
	rim.light_color = Color(0.6, 0.7, 1)
	_vp.add_child(rim)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_cam.position = Vector3(0, 0, 3.7)
	_vp.add_child(_cam)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)


func _label(sz: int, col: Color, title := false) -> Label:
	var l := Label.new()
	var fv := FontVariation.new()
	fv.base_font = FONT_TITLE if title else FONT_TEXT
	if title:
		fv.spacing_glyph = int(sz * 0.22)
	l.add_theme_font_override("font", fv)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = preload("res://shaders/inv_bg.gdshader")
	_bg.material = _bg_mat
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# вкладки вверху: «ПРЕДМЕТЫ · 2 / 6 · ЗАПИСКИ»
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-400, 34)
	top.size = Vector2(800, 40)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 26)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	_tab_items = _label(22, Color.WHITE, true)
	_tab_items.text = tr("INV_ITEMS")
	_count = _label(18, DIM, true)
	_tab_notes = _label(22, Color.WHITE, true)
	_tab_notes.text = tr("INV_NOTES")
	for n in [_tab_items, _count, _tab_notes]:
		top.add_child(n)

	_big = TextureRect.new()
	_big.texture = _vp.get_texture()
	_big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_big.set_anchors_preset(Control.PRESET_CENTER)
	_big.size = Vector2(380, 380)
	_big.position = Vector2(-190, -300)
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_big)

	_name = _label(38, BONE, true)
	_name.set_anchors_preset(Control.PRESET_CENTER)
	_name.position = Vector2(-500, 92)
	_name.size = Vector2(1000, 50)
	_root.add_child(_name)

	_desc = _label(17, Color(0.68, 0.64, 0.57))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.set_anchors_preset(Control.PRESET_CENTER)
	_desc.position = Vector2(-330, 148)
	_desc.size = Vector2(660, 70)
	_root.add_child(_desc)

	_row = HBoxContainer.new()
	_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_row.position = Vector2(-500, -150)
	_row.size = Vector2(1000, 90)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 30)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_row)

	_empty = _label(22, DIM)
	_empty.set_anchors_preset(Control.PRESET_CENTER)
	_empty.position = Vector2(-300, -20)
	_empty.size = Vector2(600, 40)
	_root.add_child(_empty)

	_note_title = _label(32, BONE, true)
	_note_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_note_title.position = Vector2(-500, 96)
	_note_title.size = Vector2(1000, 50)
	_root.add_child(_note_title)
	_note_text = _label(18, Color(0.8, 0.76, 0.68))
	_note_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_text.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_note_text.position = Vector2(-360, 156)
	_note_text.size = Vector2(720, 440)
	_root.add_child(_note_text)
	_note_img = TextureRect.new()
	_note_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_note_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_note_img.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_note_img.position = Vector2(-280, 238)
	_note_img.size = Vector2(560, 424)
	_note_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_img.visible = false
	_root.add_child(_note_img)

	_keys = _label(15, Color(0.55, 0.52, 0.47))
	_keys.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_keys.position = Vector2(-600, -44)
	_keys.size = Vector2(1200, 24)
	_root.add_child(_keys)

	# всплывашка «… — в инвентаре» внизу слева, видна и при закрытом инвентаре
	_toast = _label(22, BONE, true)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_toast.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_toast.position = Vector2(40, -170)
	_toast.size = Vector2(800, 110)
	_toast.modulate.a = 0.0
	add_child(_toast)


func _announce(name_: String) -> void:
	# несколько предметов подряд (ключ + осколок) — одной всплывашкой
	if _toast_tw == null or not _toast_tw.is_running():
		_toast_lines.clear()
	_toast_lines.append("+  " + name_)
	var txt := "\n".join(_toast_lines)
	if not _told_tab:
		txt += "\n" + tr("INV_GOT_HINT")
	_toast.text = txt
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.4)
	_toast_tw.tween_interval(3.4)
	_toast_tw.tween_callback(func(): _told_tab = true)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 1.0)


func _play(n: String, db: float, pitch: float) -> void:
	if L == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = L._stream(n)
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
