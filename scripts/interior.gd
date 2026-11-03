extends Node3D
## Прихожая и зал «как в заброшенной квартире»: советские обои 70–80-х (у каждой комнаты свои),
## старение стен в шейдере shaders/wallpaper.gdshader, грязь и детали декалями.
## Откатить: ENABLED = false — стены и комнаты снова как раньше (материалы пака Vintage).
## Бэкап прежних файлов: backup/rooms_before_wallpaper/, метка в git: rooms-before-wallpaper.

const ENABLED := true

const WALL_SHADER := preload("res://shaders/wallpaper.gdshader")

## Комнаты: какие куски стен, обои, границы (внутренние грани стен), снятые рамки.
const ROOMS := {
	"hall": {
		"walls": ["Wall1", "FrontDoorWall", "Wall2", "Wall3", "DwHall", "Wall4", "Wall5", "Wall6", "Wall7", "Wall8"],
		"paper": ["res://textures/wallpaper/wallpaper_hall_albedo.png", "res://textures/wallpaper/wallpaper_hall_normal.png", "res://textures/wallpaper/wallpaper_hall_rough.png"],
		"room": Vector4(-1.06, 1.06, 0.14, 5.86), "seed": 1.3, "seam": 0.11,
		"ceil": ["HallCeil00", "HallCeil01"],
		"ghosts": [[Vector3(-1.06, 1.55, 5.0), Vector2(0.34, 0.44)], [Vector3(1.06, 1.72, 1.55), Vector2(0.52, 0.38)]],
	},
	"living": {
		"walls": ["Wall9", "DwLiving", "Wall10", "Wall13", "Wall14", "WindowW", "WindowE", "Wall17", "Wall18"],
		"paper": ["res://textures/wallpaper/wallpaper_living_albedo.png", "res://textures/wallpaper/wallpaper_living_normal.png", "res://textures/wallpaper/wallpaper_living_rough.png"],
		"room": Vector4(-2.86, 2.86, -5.86, -0.14), "seed": 7.9, "seam": 0.37,
		"ceil": ["LivingCeil00", "LivingCeil01", "LivingCeil10", "LivingCeil11"],
		"ghosts": [[Vector3(0.55, 1.7, -5.86), Vector2(0.45, 0.56)], [Vector3(-2.86, 1.65, -1.85), Vector2(0.6, 0.45)]],
	},
	# коридор к детской: портреты на западной стене, бордовые обои в полоску
	"corridor": {
		"walls": ["Wall19", "DwCorr", "Wall20", "Wall21", "ExitWall", "Wall22", "Wall23", "Wall24", "Wall25", "Wall26", "Wall27",
			"Wall28", "Wall29", "Wall30", "Wall31", "Wall32"],
		"paper": ["res://textures/wallpaper/wallpaper_corridor_albedo.png", "res://textures/wallpaper/wallpaper_corridor_normal.png", "res://textures/wallpaper/wallpaper_corridor_rough.png"],
		"room": Vector4(-1.06, 1.06, -17.86, -6.14), "seed": 4.4, "seam": 0.2,
		"ceil": ["CorrCeil00", "CorrCeil01", "CorrCeil02", "CorrCeil03", "CorrCeil04"],
		"lamp": Vector3(0, 2.8, -11.0),
		"ghosts": [[Vector3(1.06, 1.6, -15.2), Vector2(0.5, 0.4)], [Vector3(1.06, 1.75, -8.9), Vector2(0.3, 0.42)]],
	},
}
## Вторая «комната» для шейдеров, где нужна одна — далеко, никогда не совпадает.
const NOWHERE := {"room": Vector4(100, 101, 100, 101), "seed": 0.0, "seam": 0.0, "ghosts": [], "paper": []}


func setup(level: Node3D) -> void:
	if not ENABLED:
		return
	# один материал на все стены обеих комнат: шейдер сам решает, какая сторона в какой комнате
	var mat := _wall_mat(ROOMS.hall, ROOMS.living)
	_paper_walls(level, ROOMS.hall.walls + ROOMS.living.walls, mat)
	# перегородки коридора: две стены-модуля стоят вплотную, и какая сторона видна — зависит от модуля;
	# поэтому у них один материал на коридор и зал (шейдер сам выбирает обои по стороне)
	_paper_walls(level, ROOMS.corridor.walls + ["Wall11", "Door1Wall", "Wall12", "Wall33", "DwNursery", "Wall34"], _wall_mat(ROOMS.corridor, ROOMS.living))
	_woodwork(level)
	_ceilings(level)
	preload("res://scripts/portrait_frames.gd").setup(level)      # рамки портретов в коридоре, табличка с именем
	preload("res://scripts/living_furniture.gd").setup(level)     # свой сервант и тумба под телевизор
	preload("res://scripts/curtains.gd").setup(level)             # шторы: портьеры в складку и тюль, колышутся
	preload("res://scripts/interior_decals.gd").place(level)


const WOOD_SHADER := preload("res://shaders/aged_wood.gdshader")
const CEIL_SHADER := preload("res://shaders/ceiling.gdshader")
## Двери, коробки и окна в прихожей и зале: на какой стене, крашеные или нет.
## Входная дверь — тёмные старые доски (лак), межкомнатные коробки и окна — эмаль цвета слоновой кости.
const WOODWORK := {
	"FrontDoorWall": 0.0, "Door1Wall": 1.0, "DwHall": 1.0, "DwLiving": 1.0, "WindowW": 1.0, "WindowE": 1.0,
	"DwCorr": 1.0, "ExitWall": 1.0, "DwNursery": 1.0,
}


static func _in_rooms(p: Vector3) -> bool:
	return p.x > -3.1 and p.x < 3.1 and p.z > -18.3 and p.z < 6.2 and p.y < 3.0


## Материал «старого дерева» на основе исходного (текстуры те же, сверху — время).
func _aged(src: Material, paint: float, handle_local := Vector3(0, -10, 0), seed := 0.0) -> Material:
	var b := src as BaseMaterial3D
	if b == null:
		return src
	var m := ShaderMaterial.new()
	m.shader = WOOD_SHADER
	m.set_shader_parameter("albedo_tex", b.albedo_texture)
	m.set_shader_parameter("albedo_col", b.albedo_color)
	if b.normal_enabled and b.normal_texture:
		m.set_shader_parameter("normal_tex", b.normal_texture)
		m.set_shader_parameter("has_normal", true)
	if b.roughness_texture:
		m.set_shader_parameter("rough_tex", b.roughness_texture)
		m.set_shader_parameter("has_rough", true)
		m.set_shader_parameter("rough_ch", 1 if b.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN else (2 if b.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_BLUE else 0))
	m.set_shader_parameter("rough_k", b.roughness)
	m.set_shader_parameter("uv_scale", b.uv1_scale)
	m.set_shader_parameter("uv_ofs", b.uv1_offset)
	m.set_shader_parameter("paint", paint)
	m.set_shader_parameter("handle", handle_local)
	m.set_shader_parameter("seed", seed)
	return m


func _retex(mi: MeshInstance3D, paint: float, handle_local := Vector3(0, -10, 0)) -> void:
	if mi.mesh == null:
		return
	for s in mi.mesh.get_surface_count():
		var src := mi.get_active_material(s)
		if src is ShaderMaterial:
			continue
		mi.set_surface_override_material(s, _aged(src, paint, handle_local, mi.global_position.x * 3.1 + mi.global_position.z))


func _woodwork(level: Node3D) -> void:
	for wn in WOODWORK:
		var w := level.get_node_or_null(wn) as Node3D
		if w == null:
			continue
		var paint: float = WOODWORK[wn]
		for nm in ["small_door_frame", "window_small", "window_small_frame"]:
			var f := w.get_node_or_null(nm) as MeshInstance3D
			if f and f.visible:
				_retex(f, paint)
		var leaf := w.get_node_or_null("small_door") as Node3D
		if leaf:
			# полотна из набора дверей висят на старом полотне: ручка — у свободного края на высоте ~0.95 м
			for d in leaf.find_children("*", "MeshInstance3D", true, false):
				var dm := d as MeshInstance3D
				if not dm.has_meta("door_kit"):
					continue
				var ab: AABB = dm.global_transform * dm.get_aabb()
				var c := ab.get_center()
				var away := c - leaf.global_position
				away.y = 0.0
				var hw := c + away * 0.85
				hw.y = 0.95
				_retex(dm, paint, dm.global_transform.affine_inverse() * hw)
	# коробки из набора дверей стоят прямо в уровне — берём те, что в этих комнатах
	for n in level.get_children():
		if n is MeshInstance3D and n.has_meta("door_kit") and _in_rooms((n as MeshInstance3D).global_position):
			var front: bool = (n as MeshInstance3D).global_position.z > 5.0
			_retex(n, 0.0 if front else 1.0)


func _paper_walls(level: Node3D, walls: Array, mat: Material) -> void:
	for wn in walls:
		var w := level.get_node_or_null(wn) as Node3D
		if w == null:
			continue
		for mi in w.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for s in m.mesh.get_surface_count():
				var src := m.mesh.surface_get_material(s)
				if src and String(src.resource_name).findn("Walls") >= 0:
					m.set_surface_override_material(s, mat)


func _ceilings(level: Node3D) -> void:
	var base: Texture2D = load("res://models/vintage/tex/ceiling_basecolor.jpg")
	var nrm: Texture2D = load("res://models/vintage/tex/ceiling_normal.jpg")
	for rn in ["hall", "living", "corridor"]:
		var r: Dictionary = ROOMS[rn]
		var m := ShaderMaterial.new()
		m.shader = CEIL_SHADER
		m.set_shader_parameter("base_tex", base)
		m.set_shader_parameter("base_normal", nrm)
		m.set_shader_parameter("room", ROOMS.hall.room if rn != "corridor" else ROOMS.corridor.room)
		m.set_shader_parameter("room2", ROOMS.living.room if rn != "corridor" else NOWHERE.room)
		if r.has("lamp"):
			m.set_shader_parameter("lamp", r.lamp)
		m.set_shader_parameter("slab_along_x", rn == "hall")
		m.set_shader_parameter("seed", r.seed)
		for cn in r.ceil:
			var c := level.get_node_or_null(cn) as Node3D
			if c == null:
				continue
			for mi in c.find_children("*", "MeshInstance3D", true, false):
				for s in (mi as MeshInstance3D).mesh.get_surface_count():
					(mi as MeshInstance3D).set_surface_override_material(s, m)


func _wall_mat(a: Dictionary, b: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WALL_SHADER
	m.set_shader_parameter("atlas_albedo", load("res://models/vintage/tex/walls_basecolor.jpg"))
	m.set_shader_parameter("atlas_normal", load("res://models/vintage/tex/walls_normal.jpg"))
	m.set_shader_parameter("atlas_rough", load("res://models/vintage/tex/walls_roughness.jpg"))
	m.set_shader_parameter("paper_albedo", load(a.paper[0]))
	m.set_shader_parameter("paper_normal", load(a.paper[1]))
	m.set_shader_parameter("paper_rough", load(a.paper[2]))
	var pb: Array = b.paper if not b.paper.is_empty() else a.paper
	m.set_shader_parameter("paper2_albedo", load(pb[0]))
	m.set_shader_parameter("paper2_normal", load(pb[1]))
	m.set_shader_parameter("paper2_rough", load(pb[2]))
	m.set_shader_parameter("room", a.room)
	m.set_shader_parameter("room2", b.room)
	m.set_shader_parameter("seed", a.seed)
	m.set_shader_parameter("seed2", b.seed)
	m.set_shader_parameter("seam_ofs", a.seam)
	m.set_shader_parameter("seam_ofs2", b.seam)
	var gs: Array = a.ghosts + b.ghosts
	var ga := PackedVector4Array()
	var gh := PackedFloat32Array()
	for i in 4:
		if i < gs.size():
			var g: Array = gs[i]
			ga.append(Vector4(g[0].x, g[0].y, g[0].z, g[1].x))
			gh.append(g[1].y)
		else:
			ga.append(Vector4.ZERO)
			gh.append(0.0)
	m.set_shader_parameter("ghost_a", ga)
	m.set_shader_parameter("ghost_h", gh)
	return m
