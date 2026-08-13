extends CharacterBody3D

@export_category("Movement")
@export var walk_speed := 5.0
@export var sprint_speed := 8.5
@export var crouch_speed := 2.8
@export var acceleration := 18.0
@export var air_acceleration := 5.0
@export var jump_velocity := 6.5
@export var gravity := 18.0

@export_category("Dash")
@export var dash_speed := 15.0
@export var dash_duration := 0.18
@export var dash_cooldown := 0.65

@export_category("Camera")
@export var mouse_sensitivity := 0.0025
@export var min_pitch := deg_to_rad(-65.0)
@export var max_pitch := deg_to_rad(70.0)
@export var lean_angle := deg_to_rad(12.0)
@export var lean_offset := 0.35
@export var camera_smoothing := 12.0

@export_category("Crouch")
@export var standing_height := 1.8
@export var crouching_height := 1.0
@export var standing_visual_y := 0.9
@export var crouching_visual_y := 0.5

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var camera_yaw: Node3D = $CameraYaw
@onready var camera_pitch: Node3D = $CameraYaw/CameraPitch
@onready var camera_lean: Node3D = $CameraYaw/CameraPitch/CameraLean

var _pitch := deg_to_rad(-12.0)
var _free_look_yaw := 0.0
var _dash_time := 0.0
var _dash_cooldown_time := 0.0
var _dash_direction := Vector3.ZERO
var _is_crouching := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_pitch.rotation.x = _pitch


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_handle_mouse_look(event.relative)


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_crouch(delta)
	_update_lean(delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump") and not _is_crouching:
		velocity.y = jump_velocity

	if Input.is_action_just_pressed("dash") and _dash_cooldown_time <= 0.0:
		_start_dash()

	if _dash_time > 0.0:
		velocity.x = _dash_direction.x * dash_speed
		velocity.z = _dash_direction.z * dash_speed
	else:
		_update_movement(delta)

	move_and_slide()


func _handle_mouse_look(relative: Vector2) -> void:
	_pitch = clamp(_pitch - relative.y * mouse_sensitivity, min_pitch, max_pitch)
	camera_pitch.rotation.x = _pitch

	if Input.is_action_pressed("free_look"):
		_free_look_yaw = clamp(
			_free_look_yaw - relative.x * mouse_sensitivity,
			deg_to_rad(-120.0),
			deg_to_rad(120.0)
		)
	else:
		rotation.y -= relative.x * mouse_sensitivity
		_free_look_yaw = 0.0

	camera_yaw.rotation.y = _free_look_yaw


func _update_movement(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis := Basis(Vector3.UP, rotation.y + _free_look_yaw)
	var direction := (basis * Vector3(input.x, 0.0, input.y)).normalized()

	var speed := walk_speed
	if _is_crouching:
		speed = crouch_speed
	elif Input.is_action_pressed("sprint"):
		speed = sprint_speed

	var accel := acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, direction.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, accel * delta)


func _start_dash() -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis := Basis(Vector3.UP, rotation.y + _free_look_yaw)
	_dash_direction = (basis * Vector3(input.x, 0.0, input.y)).normalized()
	if _dash_direction.is_zero_approx():
		_dash_direction = -transform.basis.z
		_dash_direction.y = 0.0
		_dash_direction = _dash_direction.normalized()
	_dash_time = dash_duration
	_dash_cooldown_time = dash_cooldown


func _update_timers(delta: float) -> void:
	_dash_time = maxf(_dash_time - delta, 0.0)
	_dash_cooldown_time = maxf(_dash_cooldown_time - delta, 0.0)


func _update_crouch(delta: float) -> void:
	_is_crouching = Input.is_action_pressed("crouch")
	var target_height := crouching_height if _is_crouching else standing_height
	var target_y := crouching_visual_y if _is_crouching else standing_visual_y

	var capsule := collision_shape.shape as CapsuleShape3D
	capsule.height = move_toward(capsule.height, target_height, 5.0 * delta)
	collision_shape.position.y = capsule.height * 0.5
	body_mesh.position.y = move_toward(body_mesh.position.y, target_y, 5.0 * delta)
	body_mesh.scale.y = move_toward(body_mesh.scale.y, target_height / standing_height, 5.0 * delta)


func _update_lean(delta: float) -> void:
	# Intentionally reversed from the common convention: Q = right, E = left.
	var lean_input := Input.get_axis("lean_left", "lean_right")
	var target_roll := -lean_input * lean_angle
	var target_x := lean_input * lean_offset
	camera_lean.rotation.z = lerp(camera_lean.rotation.z, target_roll, camera_smoothing * delta)
	camera_lean.position.x = lerp(camera_lean.position.x, target_x, camera_smoothing * delta)
