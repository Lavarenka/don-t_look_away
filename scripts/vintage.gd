extends RefCounted
## Материалы для пака Vintage Living Room: по имени материала из FBX
## подбирает текстуры (цвет, нормали, шероховатость, металл).

static var _cache := {}

const MAP := [
	["Antique_Light", "antique_light"], ["Walls", "walls"], ["Windows_Doors", "windows_doors"],
	["Floors", "floors"], ["ceiling", "ceiling"], ["Decors_1", "decors_1"], ["Decors_2", "decors_2"],
	["Furnitures_1", "furnitures_1"], ["Furnitures_2", "furnitures_2"], ["Gramafon", "gramophone"],
]


static func _tex_set(n: String) -> StandardMaterial3D:
	if _cache.has(n):
		return _cache[n]
	var m := StandardMaterial3D.new()
	var p := "res://models/vintage/tex/%s_" % n
	m.albedo_texture = load(p + "basecolor.jpg")
	m.normal_enabled = true
	m.normal_texture = load(p + "normal.jpg")
	m.roughness_texture = load(p + "roughness.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	m.roughness = 1.0
	m.metallic_texture = load(p + "metallic.jpg")
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	m.metallic = 1.0
	_cache[n] = m
	return m


static func material_for(name: String) -> Material:
	for pair in MAP:
		if name.findn(pair[0]) >= 0:
			return _tex_set(pair[1])
	if name == "Light":
		if not _cache.has("_bulb"):
			var b := StandardMaterial3D.new()
			b.albedo_color = Color(1, 0.85, 0.6)
			b.emission_enabled = true
			b.emission = Color(1, 0.7, 0.4)
			b.emission_energy_multiplier = 0.12
			_cache["_bulb"] = b
		return _cache["_bulb"]
	if not _cache.has("_glass"):
		var g := StandardMaterial3D.new()
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.albedo_color = Color(0.08, 0.1, 0.12, 0.55)
		g.roughness = 0.05
		g.metallic = 0.6
		_cache["_glass"] = g
	return _cache["_glass"]


## Применить материалы ко всем мешам внутри узла.
static func apply(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.has_meta("door_kit"):          # двери из другого набора — свои материалы
			continue
		for s in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s)
			m.set_surface_override_material(s, material_for(src.resource_name if src else ""))
