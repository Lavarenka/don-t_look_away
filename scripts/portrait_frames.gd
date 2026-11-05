extends RefCounted
## Портреты в коридоре: рамка из Blender (tools/blender/make_frame.py) — тёмный багет с золочёным
## кантом, паспарту, стекло, латунная табличка, на табличке — имя (а «в стекле» — имя и годы).
## Рамка прижата к стене. Узлы Portrait1..3/Frame, Picture, Plaque остаются (их двигает hall_puzzle.gd),
## поменяны только меш рамки и место надписи: она теперь на табличке и наклоняется вместе с рамкой.
## Откатить: ENABLED = false.

const ENABLED := true
const VENEER := preload("res://shaders/veneer.gdshader")


static func setup(level: Node3D) -> void:
	if not ENABLED:
		return
	var src: Node3D = load("res://models/living/portrait_frame.glb").instantiate()
	var mats := _mats()
	for i in 3:
		var p := level.get_node_or_null("Portrait%d" % (i + 1)) as Node3D
		if p == null:
			continue
		var fr := p.get_node_or_null("Frame") as MeshInstance3D
		if fr == null:
			continue
		fr.layers = 0                         # старый брусок не рисуем; узел остаётся (его наклоняют)
		fr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for mi in src.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var n := MeshInstance3D.new()
			n.mesh = m.mesh
			n.name = "New" + String(m.name)
			fr.add_child(n)
			for s in m.mesh.get_surface_count():
				var sm := m.mesh.surface_get_material(s)
				var key := String(sm.resource_name) if sm else ""
				if key == "Veneer":
					var vm := ShaderMaterial.new()
					vm.shader = VENEER
					vm.set_shader_parameter("wood_a", Color(0.17, 0.09, 0.05))
					vm.set_shader_parameter("wood_b", Color(0.07, 0.035, 0.02))
					vm.set_shader_parameter("seed", 11.0 + i * 3.0)
					n.set_surface_override_material(s, vm)
				elif mats.has(key):
					n.set_surface_override_material(s, mats[key])
		# фото — между паспарту и стеклом
		var pic := p.get_node_or_null("Picture") as Sprite3D
		if pic:
			pic.position.x = 0.037
		# надпись — на латунной табличке, гравировкой; теперь часть рамки
		var pl := p.get_node_or_null("Plaque") as Label3D
		if pl:
			pl.reparent(fr, false)
			pl.position = Vector3(0.0412, -0.351, 0.0)
			pl.rotation = Vector3(0, PI / 2, 0)
			pl.font_size = 40
			pl.pixel_size = 0.0009
			pl.outline_size = 0
			pl.modulate = Color(0.04, 0.03, 0.015, 1.0)
			pl.shaded = true
			pl.line_spacing = -6.0
			preload("res://scripts/fonts.gd").label3d(pl, preload("res://scripts/fonts.gd").ENGRAVE)
	src.free()


static func _mats() -> Dictionary:
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.6, 0.45, 0.2)
	brass.metallic = 0.85
	brass.roughness = 0.38
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.62, 0.57, 0.46)
	paper.roughness = 0.95
	var back := StandardMaterial3D.new()
	back.albedo_color = Color(0.12, 0.1, 0.08)
	back.roughness = 0.95
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.7, 0.75, 0.72, 0.07)
	glass.roughness = 0.08
	glass.metallic_specular = 0.6
	return {"Brass": brass, "Paper": paper, "Carcass": back, "Glass": glass}
