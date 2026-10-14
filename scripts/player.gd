extends CharacterBody3D
## Игрок от первого лица: WASD, мышь, Shift — бег, F — фонарь, E — действие (Esc — пауза, см. pause.gd).

signal step
signal action
signal toggled_light

@export var walk_speed := 1.9
@export var run_speed := 3.1
@export var mouse_sens := 0.0022
@export var flash_energy := 6.0       ## чуть тусклее для атмосферы (было 7)

var frozen := false
var light_on := true
var light_locked := false     ## фонарь не включается (спальня Веры)
var flicker := 0.0
var shake := 0.0
var _bob := 0.0
var _step_acc := 0.0

@onready var head: Node3D = $Head
@onready var cam: Camera3D = $Head/Camera3D
@onready var flash: SpotLight3D = $Head/Camera3D/Flashlight


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not frozen:
		rotate_y(-e.relative.x * mouse_sens)
		head.rotation.x = clamp(head.rotation.x - e.relative.y * mouse_sens, -1.3, 1.3)
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_F:
				if not frozen and not light_locked:
					light_on = not light_on
					toggled_light.emit()
			KEY_E:
				if not frozen:
					action.emit()


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if not frozen:
		if Input.is_physical_key_pressed(KEY_W): input.y -= 1
		if Input.is_physical_key_pressed(KEY_S): input.y += 1
		if Input.is_physical_key_pressed(KEY_A): input.x -= 1
		if Input.is_physical_key_pressed(KEY_D): input.x += 1
	if input.length() > 0.0:
		input = input.normalized()
	var running := Input.is_physical_key_pressed(KEY_SHIFT)
	var spd := run_speed if running else walk_speed
	var v := transform.basis * Vector3(input.x, 0, input.y) * spd
	velocity.x = v.x
	velocity.z = v.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 9.8 * delta
	move_and_slide()

	var hv := Vector2(velocity.x, velocity.z).length()
	_bob += hv * delta * 5.5
	_step_acc += hv * delta
	if _step_acc > 0.72:
		_step_acc = 0.0
		step.emit()


func _process(delta: float) -> void:
	if flicker > 0.0:
		flicker -= delta
	flash.light_energy = flash_energy * randf_range(0.95, 1.0) if is_light_lit() else 0.0
	cam.position = Vector3(0, sin(_bob) * 0.03, 0)
	if shake > 0.0:
		cam.h_offset = randf_range(-1, 1) * shake * 0.05
		cam.v_offset = randf_range(-1, 1) * shake * 0.05
		shake = max(0.0, shake - delta * 1.5)
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


func is_light_lit() -> bool:
	return light_on and flicker <= 0.0


func forward() -> Vector3:
	return -cam.global_transform.basis.z


func teleport(p: Vector3, yaw: float) -> void:
	global_position = p
	rotation.y = yaw
	head.rotation.x = 0.0
	velocity = Vector3.ZERO
