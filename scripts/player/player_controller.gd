extends CharacterBody3D

@export var move_speed: float = 6.0
@export var sprint_speed_multiplier: float = 1.8
@export var sprint_double_tap_window: float = 0.3
@export var sprint_fov_boost: float = 8.0
@export var sprint_fov_lerp_speed: float = 8.0
@export var acceleration: float = 12.0
@export var air_acceleration: float = 20.0
@export var rotation_speed: float = 6.0
@export var air_rotation_speed: float = 32.0
@export var jump_velocity: float = 14.4
@export var gravity_strength: float = 40.0
@export var camera_distance: float = 10.0
@export var camera_height: float = 2.0

@onready var camera: Camera3D = $Camera3D

var is_sprinting: bool = false
var last_forward_tap_time: float = -10.0
var base_camera_fov: float = 75.0
var camera_angle_offset: float = 0.0
var camera_drag_enabled: bool = true
var is_dragging_camera: bool = false
var camera_drag_sensitivity: float = 0.3

var is_destroying: bool = false
var current_target: Destructible = null
var destroy_progress: float = 0.0

var _sin_angle: float = 0.0
var _cos_angle: float = 1.0
var _last_angle: float = 0.0
var _angle_cache_valid: bool = false
var _tilt_cached: float = 0.0
var _horizontal_radius_cached: float = 0.0
var _height_cached: float = 0.0
var _geometry_cache_valid: bool = false

var _last_raycast_pos: Vector2 = Vector2.ZERO
var _raycast_timer: float = 0.0
const RAYCAST_INTERVAL: float = 0.1

func _ready() -> void:
	print("=== PLAYER SCRIPT LOADED ===")
	_settings_load()
	apply_camera_settings()
	
	if camera:
		camera.top_level = true
		base_camera_fov = camera.fov
		_update_camera_follow()
	
	floor_snap_length = 0.35
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_viewport().gui_release_focus()
	get_viewport().grab_focus()
	print("Mouse mode set to VISIBLE, focus grabbed")

func apply_camera_settings() -> void:
	var sensitivity := _settings_get_float("right_drag_yaw_sensitivity", 0.0035)
	rotation_speed = sensitivity * 10000
	
	var old_camera_height: float = camera_height
	var old_camera_distance: float = camera_distance
	
	camera_height = _settings_get_float("camera_height", camera_height)
	camera_distance = _settings_get_float("camera_distance", camera_distance)
	camera_angle_offset = _settings_get_float("camera_angle_offset", camera_angle_offset)
	camera_drag_enabled = _settings_get_bool("camera_drag_enabled", camera_drag_enabled)
	camera_drag_sensitivity = _settings_get_float("camera_drag_sensitivity", camera_drag_sensitivity)
	
	if old_camera_height != camera_height or old_camera_distance != camera_distance:
		_geometry_cache_valid = false
		_angle_cache_valid = false

func refresh_camera_from_settings() -> void:
	apply_camera_settings()
	_angle_cache_valid = false
	_last_angle = camera_angle_offset
	_update_camera_follow()

func _settings_node() -> Node:
	return get_node_or_null("/root/GameSettings")

func _settings_load() -> void:
	var settings := _settings_node()
	if settings:
		settings.call("load_settings")

func _settings_get_float(property_name: String, fallback: float) -> float:
	var settings := _settings_node()
	if not settings:
		return fallback
	var value = settings.get(property_name)
	if value == null:
		return fallback
	if value is float:
		return value
	if value is int:
		return float(value)
	return fallback


func _settings_get_bool(property_name: String, fallback: bool) -> bool:
	var settings := _settings_node()
	if not settings:
		return fallback
	var value = settings.get(property_name)
	if value == null:
		return fallback
	if value is bool:
		return value
	return fallback

func _physics_process(delta: float) -> void:
	_raycast_timer += delta
	_update_sprint_state()
	_update_sprint_fov(delta)
	_update_camera_drag()
	_update_character_rotation_toward_mouse(delta)
	_handle_vertical_motion(delta)
	_handle_movement(delta)
	_update_camera_follow()
	_update_destruction(delta)
	move_and_slide()

func _update_sprint_state() -> void:
	if Input.is_action_just_pressed("move_forward"):
		var now_sec: float = Time.get_ticks_msec() * 0.001
		if now_sec - last_forward_tap_time <= sprint_double_tap_window:
			is_sprinting = true
		last_forward_tap_time = now_sec

	if not Input.is_action_pressed("move_forward"):
		if is_sprinting:
			velocity.x = 0.0
			velocity.z = 0.0
		is_sprinting = false

func _update_sprint_fov(delta: float) -> void:
	if not camera:
		return

	var target_fov: float = base_camera_fov
	if is_sprinting and Input.is_action_pressed("move_forward"):
		target_fov += sprint_fov_boost

	var t: float = clampf(sprint_fov_lerp_speed * delta, 0.0, 1.0)
	camera.fov = lerpf(camera.fov, target_fov, t)


func _update_camera_drag() -> void:
	if not is_dragging_camera or not camera_drag_enabled:
		return
	
	var viewport := get_viewport()
	var mouse_pos := viewport.get_mouse_position()
	var screen_width := viewport.get_visible_rect().size.x
	
	var relative := Input.get_last_mouse_velocity()
	var angle_change := relative.x * camera_drag_sensitivity * camera_drag_sensitivity * 0.0000005
	camera_angle_offset -= angle_change
	
	if abs(angle_change) > 0.1:
		_angle_cache_valid = false
	
	camera_angle_offset = fmod(camera_angle_offset, 360.0)
	if camera_angle_offset < 0:
		camera_angle_offset += 360.0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_destroying = event.pressed
			if not event.pressed:
				cancel_destruction()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_dragging_camera = event.pressed
			if not is_dragging_camera:
				_save_camera_angle()
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB:
			_toggle_inventory()
		if event.keycode == KEY_F3:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if event.keycode == KEY_G:
			_toggle_debug_collision()


func _toggle_debug_collision() -> void:
	var world := get_node_or_null("/root/World/WorldManager")
	if not world:
		return
	
	var debug_areas: Array = world.get_children()
	for chunk in debug_areas:
		if chunk.name.begins_with("Chunk_"):
			for child in chunk.get_children():
				if child.name == "DebugCollision":
					child.queue_free()
				elif child.has_node("DestructibleArea"):
					var area: Area3D = child.get_node("DestructibleArea")
					if area.get_child_count() > 0:
						var debug_col: CollisionShape3D = CollisionShape3D.new()
						debug_col.name = "DebugCollision"
						debug_col.shape = area.get_child(0).shape
						debug_col.position = area.get_child(0).position
						debug_col.modulate = Color(1, 0, 0, 0.3)
						child.add_child(debug_col)
					elif child is Area3D and child.get_child_count() > 0:
						var debug_col: CollisionShape3D = CollisionShape3D.new()
						debug_col.name = "DebugCollision"
						debug_col.shape = child.get_child(0).shape
						debug_col.position = child.get_child(0).position
						debug_col.modulate = Color(1, 0, 0, 0.3)
						child.add_child(debug_col)
	print("Debug collision toggled")


func _toggle_inventory() -> void:
	var inv_ui := get_node_or_null("/root/World/InventoryUI")
	if inv_ui:
		inv_ui.toggle()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _save_camera_angle() -> void:
	var settings := _settings_node()
	if settings:
		settings.set("camera_angle_offset", camera_angle_offset)
		settings.call("save_settings")

func _update_character_rotation_toward_mouse(delta: float) -> void:
	if not camera:
		return
	
	var viewport := get_viewport()
	var mouse_pos := viewport.get_mouse_position()
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	
	if absf(direction.y) < 0.0001:
		return
	
	var t := -origin.y / direction.y
	if t <= 0.0:
		return
	
	var target := origin + direction * t
	var look_direction := target - global_position
	look_direction.y = 0.0
	
	if look_direction.length_squared() < 0.001:
		return
	
	var target_rotation := atan2(look_direction.x, look_direction.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

func _handle_movement(delta: float) -> void:
	var input_vector := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	)

	var desired := Vector3.ZERO
	if input_vector.length() > 0.0:
		input_vector = input_vector.normalized()
		
		var backward := Vector3(_sin_angle, 0, _cos_angle)
		var forward_dir := -backward
		
		var right_dir := -forward_dir.rotated(Vector3.UP, PI/2)
		
		var move_direction := (right_dir * input_vector.x) + (forward_dir * -input_vector.y)
		var target_speed: float = move_speed
		if is_sprinting and Input.is_action_pressed("move_forward"):
			target_speed *= sprint_speed_multiplier
		desired = move_direction.normalized() * target_speed

	var current_acceleration: float = acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, desired.x, current_acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, current_acceleration * delta)

func _handle_vertical_motion(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity_strength * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

func _update_camera_follow() -> void:
	if not camera:
		return

	if not _geometry_cache_valid:
		_tilt_cached = deg_to_rad(camera_height)
		_horizontal_radius_cached = camera_distance * sin(_tilt_cached)
		_height_cached = camera_distance * cos(_tilt_cached)
		_geometry_cache_valid = true
		_angle_cache_valid = false

	var current_angle: float = camera_angle_offset
	var angle_diff: float = current_angle - _last_angle
	
	if not _angle_cache_valid:
		_sin_angle = sin(current_angle)
		_cos_angle = cos(current_angle)
		_angle_cache_valid = true
	else:
		var angle_delta: float = fmod(angle_diff, TAU)
		if angle_delta > PI:
			angle_delta -= TAU
		elif angle_delta < -PI:
			angle_delta += TAU
		
		if abs(angle_delta) > 0.001:
			var sin_delta: float = sin(angle_delta)
			var cos_delta: float = cos(angle_delta)
			var new_sin: float = _sin_angle * cos_delta + _cos_angle * sin_delta
			var new_cos: float = _cos_angle * cos_delta - _sin_angle * sin_delta
			_sin_angle = new_sin
			_cos_angle = new_cos
	
	_last_angle = current_angle

	var x: float = _horizontal_radius_cached * _sin_angle
	var z: float = _horizontal_radius_cached * _cos_angle

	camera.global_position = global_position + Vector3(x, _height_cached, z)
	camera.look_at(global_position + Vector3(0, 1.5, 0), Vector3.UP)
	camera.current = true


func _update_destruction(delta: float) -> void:
	if not is_destroying:
		if current_target:
			current_target.cancel_destruction()
			current_target = null
		destroy_progress = 0.0
		return
	
	_check_destruction_target()
	
	if current_target:
		destroy_progress = current_target.update_destruction(delta)
		if destroy_progress >= 1.0:
			_complete_destruction()


func _check_destruction_target() -> void:
	if not camera:
		return
	
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var mouse_delta := mouse_pos.distance_to(_last_raycast_pos)
	
	if mouse_delta < 10.0 and _raycast_timer < RAYCAST_INTERVAL:
		return
	
	_last_raycast_pos = mouse_pos
	_raycast_timer = 0.0
	
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var dir: Vector3 = camera.project_ray_normal(mouse_pos)
	var to: Vector3 = from + dir * 10.0
	
	var space_state := get_world_3d().direct_space_state
	
	var area_query := PhysicsRayQueryParameters3D.create(from, to)
	area_query.collide_with_areas = true
	area_query.collide_with_bodies = false
	area_query.collision_mask = 2
	
	var result: Dictionary = space_state.intersect_ray(area_query)
	
	if result:
		var collider = result.collider
		
		if collider is Destructible:
			var target: Destructible = collider as Destructible
			var dist: float = global_position.distance_to(target.global_position)
			var destroy_range: float = 1.5
			
			if dist <= destroy_range:
				if current_target != target:
					current_target = target
					current_target.start_destruction()
				return
	
	if current_target:
		current_target.cancel_destruction()
		current_target = null


func _complete_destruction() -> void:
	if not current_target:
		return
	
	var drops: Dictionary = current_target.get_drops()
	
	if current_target.destruct_type == "grass":
		if randf() < 0.3:
			InventoryManager.add_item("wheat_seed", 1)
	else:
		for item_id in drops.keys():
			InventoryManager.add_item(item_id, drops[item_id])
	
	current_target.complete_destruction()
	current_target = null
	destroy_progress = 0.0
	is_destroying = false


func cancel_destruction() -> void:
	if current_target:
		current_target.cancel_destruction()
		current_target = null
	destroy_progress = 0.0
