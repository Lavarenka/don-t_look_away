extends RefCounted
## Свои модели для зала (Blender, tools: blend2/make_living.py): советский полированный сервант
## (дверцы те же — на узлах ServantDoor/ServantDoor2, открываются как раньше; ключ и записка — на нижней
## полке, книги — на открытой полке сверху) и тумба под телевизор на ножках. Телевизор — прежний.
## Откатить: ENABLED = false — снова мебель из пака Vintage.

const ENABLED := true
const VENEER := preload("res://shaders/veneer.gdshader")


static func setup(level: Node3D) -> void:
	if not ENABLED:
		return
	var mats := _materials()
	# --- сервант
	var sv := level.get_node_or_null("Servant") as Node3D
	if sv:
		var src: Node3D = load("res://models/living/servant_soviet.glb").instantiate()
		var holder := Node3D.new()
		holder.name = "ServantSoviet"
		level.add_child(holder)
		holder.global_position = sv.global_position
		_copy_meshes(src, holder, mats, 0.3)
		src.free()
		var old := sv.get_node_or_null("Model") as Node3D
		if old:
			old.visible = false
		for pair in [["ServantDoor", "res://models/living/servant_door_a.glb"], ["ServantDoor2", "res://models/living/servant_door_b.glb"]]:
			var piv := level.get_node_or_null(pair[0]) as Node3D
			if piv == null:
				continue
			for n in ["Leaf", "Panel", "Knob"]:
				var o := piv.get_node_or_null(n) as Node3D
				if o:
					o.visible = false
			var d: Node3D = load(pair[1]).instantiate()
			_copy_meshes(d, piv, mats, 1.7 if pair[0] == "ServantDoor" else 2.9, true)
			d.free()
	# --- тумба под телевизор
	var desk := level.get_node_or_null("TVDesk") as Node3D
	if desk:
		var st: Node3D = load("res://models/living/tv_stand_soviet.glb").instantiate()
		var h := Node3D.new()
		h.name = "TVStandSoviet"
		level.add_child(h)
		h.global_position = desk.global_position
		_copy_meshes(st, h, mats, 5.3)
		st.free()
		desk.visible = false
		var col := level.get_node_or_null("TVDeskCol/Shape") as CollisionShape3D
		if col and col.shape is BoxShape3D:
			var b := (col.shape as BoxShape3D).duplicate() as BoxShape3D
			b.size = Vector3(1.16, 0.92, 0.54)       # узел повёрнут: x — вдоль стены, z — глубина
			col.shape = b


## Меши из glb — в новый узел; положение объекта из Blender сохраняется относительно корня glb.
## at_origin: дверцы — начало меша уже в петлях, ставим без сдвига.
static func _copy_meshes(src: Node3D, dst: Node3D, mats: Dictionary, seed: float, at_origin := false) -> void:
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var n := MeshInstance3D.new()
		n.mesh = m.mesh
		n.name = m.name
		dst.add_child(n)
		n.transform = Transform3D.IDENTITY if at_origin else _rel(m, src)
		for s in m.mesh.get_surface_count():
			var sm := m.mesh.surface_get_material(s)
			var key := String(sm.resource_name) if sm else ""
			if key == "Veneer" or key == "Carcass":
				var vm := ShaderMaterial.new()
				vm.shader = VENEER
				vm.set_shader_parameter("carcass", 1.0 if key == "Carcass" else 0.0)
				vm.set_shader_parameter("seed", seed)
				n.set_surface_override_material(s, vm)
			elif mats.has(key):
				n.set_surface_override_material(s, mats[key])


static func _rel(n: Node3D, root: Node) -> Transform3D:
	var t := Transform3D()
	var p: Node = n
	while p != root and p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


static func _materials() -> Dictionary:
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.55, 0.6, 0.58, 0.16)
	glass.roughness = 0.04
	glass.metallic = 0.2
	glass.metallic_specular = 0.5
	var crystal := glass.duplicate() as StandardMaterial3D
	crystal.albedo_color = Color(0.75, 0.8, 0.85, 0.35)
	crystal.roughness = 0.18
	crystal.metallic_specular = 0.35
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.55, 0.42, 0.2)
	brass.metallic = 0.9
	brass.roughness = 0.42
	var porc := StandardMaterial3D.new()
	porc.albedo_color = Color(0.86, 0.84, 0.79)
	porc.roughness = 0.22
	porc.clearcoat_enabled = true
	porc.clearcoat = 0.6
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.42, 0.36, 0.3)
	paper.roughness = 0.95
	return {"Glass": glass, "Crystal": crystal, "Brass": brass, "Porcelain": porc, "Paper": paper}
