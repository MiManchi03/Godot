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
@export var camera_distance: float = 8.5
@export var camera_height: float = 26.0
@export var camera_mouse_follow_enabled: bool = true
@export var camera_mouse_follow_strength: float = 0.45

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
var _mouse_follow_world_offset: Vector3 = Vector3.ZERO

var _last_raycast_pos: Vector2 = Vector2.ZERO
var _raycast_timer: float = 0.0
const RAYCAST_INTERVAL: float = 0.1
const DESTROY_UI_FAST_TIME: float = 0.08
const DESTROY_UI_COMPLETE_HOLD: float = 0.12
const DESTROY_UI_WIDTH: float = 380.0
const DESTROY_UI_HEIGHT: float = 40.0
const DESTROY_UI_TOP_OFFSET_Y: float = 12.0
const CAMERA_MOUSE_FOLLOW_MAX_HORIZONTAL: float = 2.4
const CAMERA_MOUSE_FOLLOW_MAX_DEPTH_UP: float = 1.8
const CAMERA_MOUSE_FOLLOW_MAX_DEPTH_DOWN: float = 2.8
const CAMERA_MOUSE_FOLLOW_DEADZONE: float = 0.04
const CAMERA_MOUSE_FOLLOW_RESPONSE_EXP: float = 1.6
const CAMERA_MOUSE_FOLLOW_LERP_SPEED_MIN: float = 5.5
const CAMERA_MOUSE_FOLLOW_LERP_SPEED_MAX: float = 11.0
const CAMERA_MOUSE_FOLLOW_BOTTOM_COMPENSATION_PX: float = 90.0
const CAMERA_MOUSE_FOLLOW_MAX_OFFSET_LENGTH: float = 5.0
const CAMERA_MOUSE_FOLLOW_DOWN_NY_CAP: float = 0.8

var _destroy_ui_layer: CanvasLayer
var _destroy_ui_panel: PanelContainer
var _destroy_ui_label: Label
var _destroy_ui_bar: ProgressBar
var _destroy_ui_fast_timer: float = 0.0
var _destroy_ui_hold_timer: float = 0.0
var _destroy_ui_fast_mode: bool = false
var _destroy_ui_target_type: String = ""

func _ready() -> void:
	print("=== PLAYER SCRIPT LOADED ===")
	_settings_load()
	apply_camera_settings()
	_setup_destroy_ui()
	
	if camera:
		camera.top_level = true
		base_camera_fov = camera.fov
		_update_camera_follow(0.0)
	
	floor_snap_length = 0.35
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_viewport().gui_release_focus()
	get_viewport().grab_focus()
	print("Mouse mode set to VISIBLE, focus grabbed")


func _setup_destroy_ui() -> void:
	_destroy_ui_layer = CanvasLayer.new()
	_destroy_ui_layer.name = "DestructionUI"
	add_child(_destroy_ui_layer)

	_destroy_ui_panel = PanelContainer.new()
	_destroy_ui_panel.visible = false
	_destroy_ui_panel.modulate = Color(1, 1, 1, 1)
	_destroy_ui_panel.anchor_left = 0.5
	_destroy_ui_panel.anchor_top = 0.0
	_destroy_ui_panel.anchor_right = 0.5
	_destroy_ui_panel.anchor_bottom = 0.0
	_layout_destroy_ui()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.09, 0.88)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.58, 0.48, 0.24, 0.95)
	panel_style.corner_radius_top_left = 0
	panel_style.corner_radius_top_right = 0
	panel_style.corner_radius_bottom_left = 0
	panel_style.corner_radius_bottom_right = 0
	_destroy_ui_panel.add_theme_stylebox_override("panel", panel_style)
	_destroy_ui_layer.add_child(_destroy_ui_panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	_destroy_ui_panel.add_child(vbox)

	_destroy_ui_label = Label.new()
	_destroy_ui_label.text = ""
	_destroy_ui_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_destroy_ui_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_destroy_ui_label)

	_destroy_ui_bar = ProgressBar.new()
	_destroy_ui_bar.min_value = 0.0
	_destroy_ui_bar.max_value = 1.0
	_destroy_ui_bar.value = 0.0
	_destroy_ui_bar.show_percentage = false
	_destroy_ui_bar.custom_minimum_size = Vector2(340, 20)
	var bar_bg_style := StyleBoxFlat.new()
	bar_bg_style.bg_color = Color(0.12, 0.14, 0.13, 0.95)
	bar_bg_style.corner_radius_top_left = 0
	bar_bg_style.corner_radius_top_right = 0
	bar_bg_style.corner_radius_bottom_left = 0
	bar_bg_style.corner_radius_bottom_right = 0
	bar_bg_style.border_width_left = 1
	bar_bg_style.border_width_top = 1
	bar_bg_style.border_width_right = 1
	bar_bg_style.border_width_bottom = 1
	bar_bg_style.border_color = Color(0.42, 0.34, 0.16, 0.95)
	_destroy_ui_bar.add_theme_stylebox_override("background", bar_bg_style)
	var bar_fill_style := StyleBoxFlat.new()
	bar_fill_style.bg_color = Color(0.86, 0.66, 0.21, 0.98)
	bar_fill_style.corner_radius_top_left = 0
	bar_fill_style.corner_radius_top_right = 0
	bar_fill_style.corner_radius_bottom_left = 0
	bar_fill_style.corner_radius_bottom_right = 0
	_destroy_ui_bar.add_theme_stylebox_override("fill", bar_fill_style)
	vbox.add_child(_destroy_ui_bar)


func _layout_destroy_ui() -> void:
	if not _destroy_ui_panel:
		return
	_destroy_ui_panel.offset_left = -DESTROY_UI_WIDTH * 0.5
	_destroy_ui_panel.offset_right = DESTROY_UI_WIDTH * 0.5
	_destroy_ui_panel.offset_top = DESTROY_UI_TOP_OFFSET_Y
	_destroy_ui_panel.offset_bottom = DESTROY_UI_TOP_OFFSET_Y + DESTROY_UI_HEIGHT


func _show_destroy_ui(target_type: String) -> void:
	if not _destroy_ui_panel:
		return
	_destroy_ui_target_type = target_type
	_destroy_ui_label.text = "正在破坏 %s  0%%" % _destruct_type_to_name(target_type)
	_destroy_ui_panel.visible = true


func _hide_destroy_ui() -> void:
	if not _destroy_ui_panel:
		return
	_destroy_ui_panel.visible = false
	_destroy_ui_bar.value = 0.0
	_destroy_ui_label.text = ""
	_destroy_ui_fast_mode = false
	_destroy_ui_fast_timer = 0.0
	_destroy_ui_hold_timer = 0.0
	_destroy_ui_target_type = ""


func _destruct_type_to_name(target_type: String) -> String:
	match target_type:
		"tree":
			return "树"
		"stone":
			return "石头"
		"grass":
			return "草"
		_:
			return target_type


func _start_fast_destroy_ui(target_type: String) -> void:
	_show_destroy_ui(target_type)
	_destroy_ui_bar.value = 0.0
	_destroy_ui_fast_timer = 0.0
	_destroy_ui_hold_timer = 0.0
	_destroy_ui_fast_mode = true


func _update_destroy_ui_timers(delta: float) -> void:
	if not _destroy_ui_panel or not _destroy_ui_panel.visible:
		return

	var pulse := 0.92 + 0.08 * sin(Time.get_ticks_msec() * 0.01)
	_destroy_ui_panel.modulate = Color(1.0, 1.0, 1.0, pulse)

	if _destroy_ui_fast_mode:
		_destroy_ui_fast_timer += delta
		var t := clampf(_destroy_ui_fast_timer / DESTROY_UI_FAST_TIME, 0.0, 1.0)
		_destroy_ui_bar.value = t
		_destroy_ui_label.text = "正在破坏 %s  %d%%" % [_destruct_type_to_name(_destroy_ui_target_type), int(round(t * 100.0))]
		if t >= 1.0:
			_destroy_ui_fast_mode = false
			_destroy_ui_hold_timer = DESTROY_UI_COMPLETE_HOLD
		return

	if _destroy_ui_hold_timer > 0.0:
		_destroy_ui_hold_timer -= delta
		if _destroy_ui_hold_timer <= 0.0:
			_hide_destroy_ui()

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
	camera_mouse_follow_enabled = _settings_get_bool("camera_mouse_follow_enabled", camera_mouse_follow_enabled)
	camera_mouse_follow_strength = _settings_get_float("camera_mouse_follow_strength", camera_mouse_follow_strength)
	
	if old_camera_height != camera_height or old_camera_distance != camera_distance:
		_geometry_cache_valid = false
		_angle_cache_valid = false

func refresh_camera_from_settings() -> void:
	apply_camera_settings()
	_angle_cache_valid = false
	_last_angle = camera_angle_offset
	# Settings menu pauses the tree; refresh once without interpolation to avoid drift while dragging sliders.
	_update_camera_follow(0.0)

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
	_update_camera_follow(delta)
	_update_destruction(delta)
	_update_destroy_ui_timers(delta)
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
	_layout_destroy_ui()

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
	
	var target_rotation := atan2(-look_direction.x, -look_direction.z)
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

func _shape_mouse_follow_axis(value: float) -> float:
	var abs_value := absf(value)
	if abs_value <= CAMERA_MOUSE_FOLLOW_DEADZONE:
		return 0.0
	var normalized := (abs_value - CAMERA_MOUSE_FOLLOW_DEADZONE) / (1.0 - CAMERA_MOUSE_FOLLOW_DEADZONE)
	normalized = pow(clampf(normalized, 0.0, 1.0), CAMERA_MOUSE_FOLLOW_RESPONSE_EXP)
	return signf(value) * normalized


func _update_camera_follow(delta: float = 0.0) -> void:
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
	var base_camera_position := global_position + Vector3(x, _height_cached, z)
	var base_look_target := global_position + Vector3(0, 1.5, 0)

	var desired_mouse_offset := Vector3.ZERO
	if camera_mouse_follow_enabled:
		var viewport := get_viewport()
		if viewport:
			var visible_size := viewport.get_visible_rect().size
			if visible_size.x > 1.0 and visible_size.y > 1.0:
				var mouse_pos := viewport.get_mouse_position()
				var nx_raw := clampf((mouse_pos.x / visible_size.x - 0.5) * 2.0, -1.0, 1.0)
				var effective_height := maxf(1.0, visible_size.y - CAMERA_MOUSE_FOLLOW_BOTTOM_COMPENSATION_PX)
				var ny_raw := clampf((mouse_pos.y / effective_height - 0.5) * 2.0, -1.0, 1.0)
				var nx := _shape_mouse_follow_axis(nx_raw)
				var ny := _shape_mouse_follow_axis(ny_raw)
				if ny > 0.0:
					ny = minf(ny, CAMERA_MOUSE_FOLLOW_DOWN_NY_CAP)
				var forward := Vector3(-_sin_angle, 0.0, -_cos_angle)
				if forward.length_squared() > 0.0001:
					forward = forward.normalized()
				var right := -forward.rotated(Vector3.UP, PI * 0.5)
				var depth_scale := CAMERA_MOUSE_FOLLOW_MAX_DEPTH_UP
				if ny > 0.0:
					depth_scale = CAMERA_MOUSE_FOLLOW_MAX_DEPTH_DOWN
				desired_mouse_offset = (
					right * (nx * CAMERA_MOUSE_FOLLOW_MAX_HORIZONTAL)
					+ forward * (-ny * depth_scale)
				) * clampf(camera_mouse_follow_strength, 0.0, 1.0)
				desired_mouse_offset.y = 0.0
				if desired_mouse_offset.length() > CAMERA_MOUSE_FOLLOW_MAX_OFFSET_LENGTH:
					desired_mouse_offset = desired_mouse_offset.normalized() * CAMERA_MOUSE_FOLLOW_MAX_OFFSET_LENGTH

	if delta > 0.0:
		var strength := clampf(camera_mouse_follow_strength, 0.0, 1.0)
		var lerp_speed := lerpf(CAMERA_MOUSE_FOLLOW_LERP_SPEED_MAX, CAMERA_MOUSE_FOLLOW_LERP_SPEED_MIN, strength)
		var t := clampf(lerp_speed * delta, 0.0, 1.0)
		_mouse_follow_world_offset = _mouse_follow_world_offset.lerp(desired_mouse_offset, t)
	else:
		_mouse_follow_world_offset = desired_mouse_offset

	camera.global_position = base_camera_position + _mouse_follow_world_offset
	camera.look_at(base_look_target + _mouse_follow_world_offset, Vector3.UP)
	camera.current = true


func _update_destruction(delta: float) -> void:
	if not is_destroying:
		if current_target:
			current_target.cancel_destruction()
			current_target = null
		destroy_progress = 0.0
		if not _destroy_ui_fast_mode and _destroy_ui_hold_timer <= 0.0:
			_hide_destroy_ui()
		return
	
	_check_destruction_target()
	
	if current_target:
		destroy_progress = current_target.update_destruction(delta)
		var target_type := current_target.destruct_type
		if current_target.get_destroy_time() <= 0.0:
			if not _destroy_ui_fast_mode and _destroy_ui_hold_timer <= 0.0:
				_start_fast_destroy_ui(target_type)
		else:
			_show_destroy_ui(target_type)
			_destroy_ui_bar.value = clampf(destroy_progress, 0.0, 1.0)
			_destroy_ui_label.text = "正在破坏 %s  %d%%" % [_destruct_type_to_name(target_type), int(round(_destroy_ui_bar.value * 100.0))]
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
	if not _destroy_ui_fast_mode and _destroy_ui_hold_timer <= 0.0:
		_hide_destroy_ui()


func _complete_destruction() -> void:
	if not current_target:
		return
	
	var drops: Dictionary = current_target.get_drops()
	var destroyed_time := current_target.get_destroy_time()
	for item_id in drops.keys():
		InventoryManager.add_item(item_id, drops[item_id])

	if destroyed_time > 0.0:
		_show_destroy_ui(current_target.destruct_type)
		_destroy_ui_bar.value = 1.0
		_destroy_ui_label.text = "正在破坏 %s  100%%" % _destruct_type_to_name(current_target.destruct_type)
		_destroy_ui_hold_timer = DESTROY_UI_COMPLETE_HOLD
	
	current_target.complete_destruction()
	current_target = null
	destroy_progress = 0.0
	is_destroying = false


func cancel_destruction() -> void:
	if current_target:
		current_target.cancel_destruction()
		current_target = null
	destroy_progress = 0.0
	if not _destroy_ui_fast_mode and _destroy_ui_hold_timer <= 0.0:
		_hide_destroy_ui()
