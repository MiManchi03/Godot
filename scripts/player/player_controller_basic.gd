extends CharacterBody3D

@export var move_speed: float = 5.0
@export var gravity_strength: float = 20.0

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	if camera:
		camera.top_level = true
		camera.position = Vector3(0, 2, -5)
		camera.look_at(global_position, Vector3.UP)
		camera.current = true
	
	floor_snap_length = 0.35

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_vertical_motion(delta)
	_update_camera_follow()
	move_and_slide()

func _handle_movement(delta: float) -> void:
	var input_vector := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	)

	if input_vector.length() > 0.0:
		input_vector = input_vector.normalized()
		
		var forward_dir := -transform.basis.z
		forward_dir.y = 0
		forward_dir = forward_dir.normalized()
		
		var right_dir := transform.basis.x
		right_dir.y = 0
		right_dir = right_dir.normalized()
		
		var move_direction := (right_dir * input_vector.x) + (forward_dir * -input_vector.y)
		velocity.x = move_direction.x * move_speed
		velocity.z = move_direction.z * move_speed
	else:
		velocity.x = 0
		velocity.z = 0

func _handle_vertical_motion(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity_strength * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

func _update_camera_follow() -> void:
	if not camera:
		return

	camera.global_position = global_position + Vector3(0, 2, -5)
	camera.look_at(global_position, Vector3.UP)