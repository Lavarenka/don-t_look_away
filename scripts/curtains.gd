extends RefCounted
## Шторы в зале: свой карниз, две плотные портьеры в складку до пола и тюль за ними.
## Складки строятся тут (ткань собрана на карнизе туже, книзу расходится), колышет — shaders/curtain.gdshader.
## Встают на место штор из пака (узлы CurtainW / CurtainE), те прячутся.
## Откатить: ENABLED = false.

const ENABLED := true
const SHADER := preload("res://shaders/curtain.gdshader")
const TOP := 0.03           ## верх ткани от узла (узел — на высоте 2.25)
const FLOOR_GAP := 0.03     ## не до самого пола


static func setup(level: Node3D) -> void:
	if not ENABLED:
		return
	var drape := ShaderMaterial.new()
	drape.shader = SHADER
	drape.set_shader_parameter("tex", load("res://textures/fabric/drape_albedo.png"))
	drape.set_shader_parameter("nrm", load("res://textures/fabric/drape_normal.png"))
	drape.set_shader_parameter("has_nrm", true)
	drape.set_shader_parameter("tile", 0.5)
	var tul := ShaderMaterial.new()
	var tsh := Shader.new()
	tsh.code = SHADER.code.replace("render_mode cull_disabled, depth_draw_opaque;", "render_mode cull_disabled, depth_draw_never;\n#define TULLE")
	tul.shader = tsh
	tul.set_shader_parameter("tex", load("res://textures/fabric/tulle.png"))
	tul.set_shader_parameter("tulle", true)
	tul.set_shader_parameter("tile", 0.4)
	var rod := StandardMaterial3D.new()
	rod.albedo_color = Color(0.16, 0.12, 0.08)
	rod.metallic = 0.6
	rod.roughness = 0.45
	var i := 0
	for nm in ["CurtainW", "CurtainE"]:
		var old := level.get_node_or_null(nm) as Node3D
		if old == null:
			continue
		old.visible = false
		var h := Node3D.new()
		h.name = nm + "Soviet"
		level.add_child(h)
		h.global_transform = old.global_transform
		var L := old.global_position.y + TOP - FLOOR_GAP
		var d1 := drape.duplicate() as ShaderMaterial
		d1.set_shader_parameter("cloth_len", L)
		d1.set_shader_parameter("seed", i * 3.7)
		var t1 := tul.duplicate() as ShaderMaterial
		t1.set_shader_parameter("cloth_len", L)
		t1.set_shader_parameter("seed", i * 3.7 + 1.1)
		# тюль — на всю ширину, мелкие складки; портьеры — по бокам, крупные складки
		h.add_child(_panel(-0.8, 0.8, 0.19, L, 2.2, 22, 0.011, t1, i * 10 + 1))
		h.add_child(_panel(-0.86, -0.3, 0.245, L, 1.25, 8, 0.034, d1, i * 10 + 2))
		h.add_child(_panel(0.3, 0.86, 0.245, L, 1.25, 8, 0.034, d1, i * 10 + 3, true))
		h.add_child(_rod(rod))
		i += 1


## Полотно в складку. x0..x1 — где висит на карнизе; fabric — ширина ткани в развёрнутом виде;
## pleats — складок; amp — их глубина. Внизу ткань расходится шире (до 12%) и глубже.
static func _panel(x0: float, x1: float, z: float, L: float, fabric: float, pleats: int, amp: float, mat: Material, seed: int, mirror := false) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var nu := pleats * 8
	var nv := 60
	var ph := rng.randf() * TAU
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for j in nv + 1:
		var v := float(j) / nv
		var y := TOP - v * L
		var row := []
		for k in nu + 1:
			var u := float(k) / nu
			var fl := 1.0 + 0.12 * v * v
			var cx := (x0 + x1) * 0.5
			var x := cx + (lerpf(x0, x1, u) - cx) * fl
			if mirror:
				x = cx + (lerpf(x1, x0, u) - cx) * fl
			# складки: глубже книзу, чуть неровные; у карниза — собраны «гармошкой»
			var a := amp * (0.75 + 0.5 * v) * (0.85 + 0.3 * sin(u * 7.0 + seed))
			var s := sin(u * pleats * TAU + ph + sin(v * 3.0 + seed) * 0.25)
			var zz := z + a * s + 0.01 * sin(v * 2.0 + u * 3.0 + seed) * v
			# подол — чуть неровный
			var yy := y + (0.012 * sin(u * 23.0 + seed) * v * v if j == nv else 0.0)
			row.append([Vector3(x, yy, zz), Vector2(u * fabric, v * L)])
		pts.append(row)
	for j in nv:
		for k in nu:
			var a: Array = pts[j][k]
			var b: Array = pts[j][k + 1]
			var c: Array = pts[j + 1][k]
			var d: Array = pts[j + 1][k + 1]
			for vtx in [a, c, b, b, c, d]:
				st.set_uv(vtx[1])
				st.add_vertex(vtx[0])
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


static func _rod(m: Material) -> Node3D:
	var n := Node3D.new()
	var bar := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = 1.8
	bar.mesh = cm
	bar.material_override = m
	bar.rotation.z = PI / 2
	bar.position = Vector3(0, TOP + 0.03, 0.215)
	n.add_child(bar)
	for sx in [-1.0, 1.0]:
		var fin := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.026
		sm.height = 0.052
		fin.mesh = sm
		fin.material_override = m
		fin.position = Vector3(sx * 0.92, TOP + 0.03, 0.215)
		n.add_child(fin)
		var br := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.008
		bm.bottom_radius = 0.01
		bm.height = 0.215
		br.mesh = bm
		br.material_override = m
		br.rotation.x = PI / 2
		br.position = Vector3(sx * 0.8, TOP + 0.03, 0.107)
		n.add_child(br)
	# кольца на карнизе
	for k in 18:
		var r := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.014
		tm.outer_radius = 0.019
		r.mesh = tm
		r.material_override = m
		r.rotation.z = PI / 2
		var x := lerpf(-0.84, -0.32, float(k % 9) / 8.0) if k < 9 else lerpf(0.32, 0.84, float(k % 9) / 8.0)
		r.position = Vector3(x, TOP + 0.03, 0.215)
		n.add_child(r)
	return n
