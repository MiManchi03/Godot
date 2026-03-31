extends CharacterBody3D

@export var move_speed: float = 9.0
@export var acceleration: float = 22.0
@export var gravity_strength: float = 40.0
@export var camera_distance: float = 5.0
@export var camera_height: float = 2.0

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	if camera:
		camera.top_level = true
		_update_camera_follow()
	
	floor_snap_length = 0.35
	
	await get_tree().process_frame
	
	if not Engine.is_editor_hint():
		DisplayServer.window_set_mode(DisplayServer.WindowMode.WINDOW_MODE_FULLSCREEN)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	_update_character_rotation_from_mouse()
	_handle_vertical_motion(delta)
	_handle_movement(delta)
	_update_camera_follow()
	move_and_slide()
	_update_camera_follow()

func _update_character_rotation_from_mouse() -> void:
	if not camera:
		return
	
	var viewport := get_viewport()
	var mouse_pos := viewport.get_mouse_position()
	var mouse_ray = camera.project_ray_origin(mouse_pos)
	var mouse_dir = camera.project_ray_normal(mouse_pos)
	
	var plane = Plane(Vector3.UP, global_position.y)
	var intersection = plane.intersects_ray(mouse_ray, mouse_dir)
	
	if intersection:
		var target_position = mouse_ray + mouse_dir * intersection
		target_position.y = global_position.y
		
		var direction = target_position - global_position
		if direction.length() > 0.1:
			direction = direction.normalized()
			var target_rotation = atan2(direction.x, direction.z)
			rotation.y = target_rotation

func _handle_movement(delta: float) -> void:
	var input_vector := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	)

	var desired := Vector3.ZERO
	if input_vector.length() > 0.0:
		input_vector = input_vector.normalized()
		
		var forward_dir := -camera.transform.basis.z
		forward_dir.y = 0
		forward_dir = forward_dir.normalized()
		
		var right_dir := camera.transform.basis.x
		right_dir.y = 0
		right_dir = right_dir.normalized()
		
		var move_direction := (right_dir * input_vector.x) + (forward_dir * -input_vector.y)
		desired = move_direction.normalized() * move_speed

	var current_acceleration: float = acceleration if is_on_floor() else acceleration * 0.5
	velocity.x = move_toward(velocity.x, desired.x, current_acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, current_acceleration * delta)

func _handle_vertical_motion(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity_strength * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = 14.0

func _update_camera_follow() -> void:
	if not camera:
		return

	var backward := -transform.basis.z
	backward.y = 0
	backward = backward.normalized()
	
	camera.global_position = global_position + backward * camera_distance + Vector3(0, camera_height, 0)
	camera.look_at(global_position + Vector3(0, 1.5, 0), Vector3.UP)
	camera.current = true