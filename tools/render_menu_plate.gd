extends Node
## Инструмент: перерисовать фон главного меню (textures/menu_plate.png) из настоящего уровня.
## Открой scenes/tools/render_menu_plate.tscn и нажми F6 — через ~6 секунд сохранит картинку и закроется.
## Ракурс и фонарь — те же, что у меню (scripts/menu.gd: CAM_XF, FLASH_XF): призрак ложится ровно в кадр.

const W := 2560
const H := 1440
var CAM_XF: Transform3D = str_to_var("Transform3D(0.99782705, -0.0063137123, 0.06558462, 0, 0.9953982, 0.095825166, -0.06588782, -0.09561695, 0.99323523, -0.3, 1.65, 2.5)")
var FLASH_XF: Transform3D = str_to_var("Transform3D(0.9942423, 0.013865624, -0.10625452, 0, 0.9915928, 0.12939733, 0.10715539, -0.1286523, 0.98588353, -0.07921533, 1.4509205, 2.5046284)")
var lvl: Node3D
var vp: SubViewport


func _ready() -> void:
	lvl = load("res://scenes/main.tscn").instantiate()
	add_child(lvl)
	await get_tree().create_timer(4.0).timeout          # вступление: свет в холле уже выбит
	var p = lvl.get("player")
	if p:
		p.light_on = false
		p.process_mode = Node.PROCESS_MODE_DISABLED
	lvl.set_process(false)
	vp = SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.world_3d = lvl.get_world_3d()
	vp.msaa_3d = Viewport.MSAA_4X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	vp.positional_shadow_atlas_size = 8192
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 68.0
	cam.transform = CAM_XF
	cam.cull_mask = 0xFFFFF & ~(1 << 1) & ~(1 << 2) & ~(1 << 10)
	var we := lvl.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var env: Environment = we.environment.duplicate()
		env.ssao_enabled = true
		env.ssao_intensity = 2.2
		env.ssil_enabled = true
		env.ssil_intensity = 1.2
		env.sdfgi_enabled = true
		env.sdfgi_use_occlusion = true
		env.volumetric_fog_enabled = true
		cam.environment = env
	vp.add_child(cam)
	cam.make_current()
	var fl := SpotLight3D.new()
	fl.transform = FLASH_XF
	fl.light_color = Color(1, 0.94, 0.82)
	fl.light_energy = 7.0
	fl.light_volumetric_fog_energy = 1.5
	fl.shadow_enabled = true
	fl.shadow_bias = 0.08
	fl.spot_range = 18.0
	fl.spot_attenuation = 1.2
	fl.spot_angle = 24.0
	fl.spot_angle_attenuation = 1.5
	lvl.add_child(fl)
	await get_tree().create_timer(3.0).timeout          # SDFGI и туман успевают «сойтись»
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://textures/menu_plate.png"))
	print("menu_plate.png saved ", img.get_size())
	get_tree().quit()
