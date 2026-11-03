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
		"ghosts": [[Vector3(-1.06, 1.55, 5.0), Vector2(0.34, 0.44)], [Vector3(1.06, 1.72, 1.55), Vector2(0.52, 0.38)]],
	},
	"living": {
		"walls": ["Wall9", "DwLiving", "Wall10", "Wall11", "Door1Wall", "Wall12", "Wall13", "Wall14", "WindowW", "WindowE", "Wall17", "Wall18", "Wall19", "DwCorr", "Wall20", "Wall27"],
		"paper": ["res://textures/wallpaper/wallpaper_living_albedo.png", "res://textures/wallpaper/wallpaper_living_normal.png", "res://textures/wallpaper/wallpaper_living_rough.png"],
		"room": Vector4(-2.86, 2.86, -5.86, -0.14), "seed": 7.9, "seam": 0.37,
		"ghosts": [[Vector3(0.55, 1.7, -5.86), Vector2(0.45, 0.56)], [Vector3(-2.86, 1.65, -1.85), Vector2(0.6, 0.45)]],
	},
}


func setup(level: Node3D) -> void:
	if not ENABLED:
		return
	# один материал на все стены обеих комнат: шейдер сам решает, какая сторона в какой комнате
	var mat := _wall_mat(ROOMS.hall, ROOMS.living)
	var walls: Array = ROOMS.hall.walls + ROOMS.living.walls
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
	preload("res://scripts/interior_decals.gd").place(level)


func _wall_mat(a: Dictionary, b: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WALL_SHADER
	m.set_shader_parameter("atlas_albedo", load("res://models/vintage/tex/walls_basecolor.jpg"))
	m.set_shader_parameter("atlas_normal", load("res://models/vintage/tex/walls_normal.jpg"))
	m.set_shader_parameter("atlas_rough", load("res://models/vintage/tex/walls_roughness.jpg"))
	m.set_shader_parameter("paper_albedo", load(a.paper[0]))
	m.set_shader_parameter("paper_normal", load(a.paper[1]))
	m.set_shader_parameter("paper_rough", load(a.paper[2]))
	m.set_shader_parameter("paper2_albedo", load(b.paper[0]))
	m.set_shader_parameter("paper2_normal", load(b.paper[1]))
	m.set_shader_parameter("paper2_rough", load(b.paper[2]))
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
