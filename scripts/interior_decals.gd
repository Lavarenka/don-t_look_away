extends RefCounted
## Грязь и детали в прихожей и зале: протечки и копоть на потолке, плесень в углах,
## трещины над проёмами, паутина в верхних углах. Вызывается из interior.gd.

const T := {
	"scribble_family": "res://textures/wallpaper/scribble_family.png",
	"scribble_spiral": "res://textures/wallpaper/scribble_spiral.png",
	"stain_leak": "res://textures/wallpaper/stain_leak.png",
	"soot": "res://textures/wallpaper/soot.png",
	"mold_corner": "res://textures/wallpaper/mold_corner.png",
	"crack": "res://textures/wallpaper/crack.png",
	"cobweb_corner": "res://textures/wallpaper/cobweb_corner.png",
}
const CEIL := 2.8


static func place(level: Node3D) -> void:
	var root := Node3D.new()
	root.name = "InteriorDetails"
	level.add_child(root)
	# --- прихожая
	_ceil(root, "stain_leak", Vector3(0.35, CEIL, 4.7), Vector2(1.5, 1.1), 0.0, 0.85)
	_ceil(root, "stain_leak", Vector3(-0.7, CEIL, 0.9), Vector2(0.8, 0.7), 1.3, 0.6)
	_ceil(root, "soot", Vector3(0.0, CEIL, 3.0), Vector2(1.0, 1.0), 0.0, 0.7)          # над лампочкой
	_wall(root, "crack", Vector3(-0.2, 2.25, 0.14), Vector3(0, 0, -1), Vector2(0.45, 0.9), 0.9)   # над проёмом в зал
	_wall(root, "mold_corner", Vector3(1.0, 0.35, 5.86), Vector3(0, 0, 1), Vector2(0.9, 0.9), 0.9, true)
	_web(root, Vector3(-1.06, CEIL, 5.86), Vector3(1, 0, 0), Vector3(0, 0, -1), 0.55)
	_web(root, Vector3(1.06, CEIL, 0.14), Vector3(-1, 0, 0), Vector3(0, 0, 1), 0.42)
	# --- зал
	_ceil(root, "stain_leak", Vector3(-2.1, CEIL, -0.9), Vector2(1.8, 1.4), 0.7, 0.9)   # у окна — там течёт крыша
	_ceil(root, "stain_leak", Vector3(1.9, CEIL, -4.9), Vector2(1.1, 0.9), 2.2, 0.7)
	_ceil(root, "soot", Vector3(-0.4, CEIL, -3.0), Vector2(1.5, 1.5), 0.0, 0.75)        # над люстрой
	_wall(root, "crack", Vector3(-0.85, 2.3, -5.86), Vector3(0, 0, -1), Vector2(0.5, 1.0), 0.9)  # над дверью в коридор
	_wall(root, "crack", Vector3(2.86, 2.05, -2.6), Vector3(1, 0, 0), Vector2(0.4, 0.8), 0.8)
	_wall(root, "mold_corner", Vector3(-2.4, 0.4, -5.86), Vector3(0, 0, -1), Vector2(1.0, 1.0), 0.95, true)
	_wall(root, "mold_corner", Vector3(-2.86, 2.4, -0.5), Vector3(-1, 0, 0), Vector2(0.9, 0.9), 0.8, false, true)
	_web(root, Vector3(-2.86, CEIL, -5.86), Vector3(1, 0, 0), Vector3(0, 0, 1), 0.7)
	_web(root, Vector3(2.86, CEIL, -0.14), Vector3(-1, 0, 0), Vector3(0, 0, -1), 0.6)
	_web(root, Vector3(2.86, CEIL, -5.86), Vector3(-1, 0, 0), Vector3(0, 0, 1), 0.45)
	# --- коридор
	_ceil(root, "stain_leak", Vector3(0.3, CEIL, -8.2), Vector2(1.3, 1.0), 0.4, 0.8)
	_ceil(root, "stain_leak", Vector3(-0.4, CEIL, -15.6), Vector2(1.6, 1.2), 2.0, 0.9)
	_ceil(root, "soot", Vector3(0.0, CEIL, -11.0), Vector2(1.0, 1.0), 0.0, 0.75)
	_wall(root, "crack", Vector3(0.95, 2.2, -13.0), Vector3(1, 0, 0), Vector2(0.45, 0.9), 0.85)
	_wall(root, "crack", Vector3(0.2, 2.3, -17.86), Vector3(0, 0, -1), Vector2(0.45, 0.9), 0.9)
	_wall(root, "mold_corner", Vector3(-0.6, 0.4, -17.86), Vector3(0, 0, -1), Vector2(0.9, 0.9), 0.95, true)
	_wall(root, "mold_corner", Vector3(1.06, 0.4, -16.9), Vector3(1, 0, 0), Vector2(1.0, 1.0), 0.9, true)
	_web(root, Vector3(-1.06, CEIL, -17.86), Vector3(1, 0, 0), Vector3(0, 0, 1), 0.6)
	_web(root, Vector3(1.06, CEIL, -6.14), Vector3(-1, 0, 0), Vector3(0, 0, -1), 0.5)
	_web(root, Vector3(1.06, CEIL, -17.86), Vector3(-1, 0, 0), Vector3(0, 0, 1), 0.4)
	# --- детская: протечка над кроватью, копоть над лампой, плесень у окна, каракули мелками на обоях
	_ceil(root, "stain_leak", Vector3(-1.5, CEIL, -22.6), Vector2(1.4, 1.1), 1.1, 0.85)
	_ceil(root, "soot", Vector3(0.0, CEIL, -21.0), Vector2(0.9, 0.9), 0.0, 0.6)
	_wall(root, "mold_corner", Vector3(2.26, 0.4, -23.3), Vector3(1, 0, 0), Vector2(1.0, 1.0), 0.9, true)
	_wall(root, "mold_corner", Vector3(-2.26, 2.4, -20.1), Vector3(-1, 0, 0), Vector2(0.9, 0.9), 0.8, false, true)
	_wall(root, "crack", Vector3(1.6, 2.2, -23.86), Vector3(0, 0, -1), Vector2(0.45, 0.9), 0.85)
	_wall(root, "scribble_family", Vector3(1.25, 0.5, -23.86), Vector3(0, 0, -1), Vector2(0.75, 0.75), 0.9)
	_wall(root, "scribble_spiral", Vector3(2.26, 0.5, -19.8), Vector3(1, 0, 0), Vector2(0.55, 0.55), 0.85)
	_web(root, Vector3(-2.26, CEIL, -23.86), Vector3(1, 0, 0), Vector3(0, 0, 1), 0.55)
	_web(root, Vector3(2.26, CEIL, -18.14), Vector3(-1, 0, 0), Vector3(0, 0, -1), 0.45)


## Пятно на потолке (проецируется вверх).
static func _ceil(root: Node3D, tex: String, pos: Vector3, size: Vector2, rot: float, k: float) -> void:
	var d := Decal.new()
	d.texture_albedo = load(T[tex])
	d.size = Vector3(size.x, 0.3, size.y)
	d.modulate = Color(1, 1, 1, k)
	d.cull_mask = 1
	root.add_child(d)
	d.global_position = pos - Vector3(0, 0.05, 0)
	d.basis = Basis(Vector3.RIGHT, PI) * Basis(Vector3.UP, rot)


## Пятно на стене: into — направление в стену; top — текстура перевёрнута (плесень растёт из-под потолка).
static func _wall(root: Node3D, tex: String, pos: Vector3, into: Vector3, size: Vector2, k: float, _unused := false, top := false) -> void:
	var d := Decal.new()
	d.texture_albedo = load(T[tex])
	d.size = Vector3(size.x, 0.25, size.y)
	d.modulate = Color(1, 1, 1, k)
	d.cull_mask = 1
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	root.add_child(d)
	var y := -into.normalized()
	var z := Vector3.UP if top else Vector3.DOWN
	var x := y.cross(z).normalized()
	d.basis = Basis(x, y, z)
	d.global_position = pos


## Паутина в верхнем углу: провисшее полотно между двумя стенами и потолком.
static func _web(root: Node3D, corner: Vector3, w1: Vector3, w2: Vector3, size: float) -> void:
	var c := corner + (w1 + w2) * 0.01 + Vector3.DOWN * 0.01
	var a := c + w1 * size
	var b := c + w2 * size
	var m := c + (w1 + w2) * size * 0.55 + Vector3.DOWN * size * 0.45
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [[c, Vector2(0, 0)], [a, Vector2(1, 0)], [m, Vector2(1, 1)], [c, Vector2(0, 0)], [m, Vector2(1, 1)], [b, Vector2(0, 1)]]:
		st.set_uv(v[1])
		st.add_vertex(v[0])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(T["cobweb_corner"])
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mat.albedo_color = Color(0.8, 0.8, 0.78, 0.9)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
