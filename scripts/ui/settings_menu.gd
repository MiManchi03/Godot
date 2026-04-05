extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var right_drag_yaw_slider: HSlider = $Panel/MarginContainer/VBoxContainer/RightDragYawRow/RightDragYawSlider
@onready var right_drag_yaw_value: Label = $Panel/MarginContainer/VBoxContainer/RightDragYawRow/RightDragYawValue
@onready var camera_drag_enabled_checkbox: CheckButton = $Panel/MarginContainer/VBoxContainer/CameraDragEnabledCheckBox
@onready var camera_drag_sensitivity_slider: HSlider = $Panel/MarginContainer/VBoxContainer/CameraDragSensitivityRow/CameraDragSensitivitySlider
@onready var camera_drag_sensitivity_value: Label = $Panel/MarginContainer/VBoxContainer/CameraDragSensitivityRow/CameraDragSensitivityValue
@onready var build_drag_sensitivity_slider: HSlider = $Panel/MarginContainer/VBoxContainer/BuildDragSensitivityRow/BuildDragSensitivitySlider
@onready var build_drag_sensitivity_value: Label = $Panel/MarginContainer/VBoxContainer/BuildDragSensitivityRow/BuildDragSensitivityValue
@onready var camera_tilt_slider: HSlider = $Panel/MarginContainer/VBoxContainer/CameraTiltRow/CameraTiltSlider
@onready var camera_tilt_value: Label = $Panel/MarginContainer/VBoxContainer/CameraTiltRow/CameraTiltValue
@onready var camera_distance_slider: HSlider = $Panel/MarginContainer/VBoxContainer/CameraDistanceRow/CameraDistanceSlider
@onready var camera_distance_value: Label = $Panel/MarginContainer/VBoxContainer/CameraDistanceRow/CameraDistanceValue
@onready var camera_mouse_follow_enabled_checkbox: CheckButton = $Panel/MarginContainer/VBoxContainer/CameraMouseFollowEnabledCheckBox
@onready var camera_mouse_follow_strength_slider: HSlider = $Panel/MarginContainer/VBoxContainer/CameraMouseFollowStrengthRow/CameraMouseFollowStrengthSlider
@onready var camera_mouse_follow_strength_value: Label = $Panel/MarginContainer/VBoxContainer/CameraMouseFollowStrengthRow/CameraMouseFollowStrengthValue

var player: CharacterBody3D
var _is_initializing_controls: bool = false


func _apply_player_settings(update_camera_view: bool) -> void:
	if not player:
		return
	if update_camera_view:
		if player.has_method("refresh_camera_from_settings"):
			player.call("refresh_camera_from_settings")
	else:
		if player.has_method("apply_camera_settings"):
			player.call("apply_camera_settings")


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_load()
	player = get_parent().get_node_or_null("Player")
	_is_initializing_controls = true

	right_drag_yaw_slider.min_value = 10.0
	right_drag_yaw_slider.max_value = 200.0
	right_drag_yaw_slider.step = 1.0
	right_drag_yaw_slider.value = 35.0
	_on_right_drag_yaw_slider_value_changed(right_drag_yaw_slider.value)

	var drag_enabled := _settings_get_bool("camera_drag_enabled", true)
	camera_drag_enabled_checkbox.button_pressed = drag_enabled
	_update_drag_sensitivity_enabled()

	camera_drag_sensitivity_slider.min_value = 0.1
	camera_drag_sensitivity_slider.max_value = 20.0
	camera_drag_sensitivity_slider.step = 0.1
	camera_drag_sensitivity_slider.value = _settings_get_float("camera_drag_sensitivity", 10.0)
	_on_camera_drag_sensitivity_slider_value_changed(camera_drag_sensitivity_slider.value)

	build_drag_sensitivity_slider.min_value = 0.1
	build_drag_sensitivity_slider.max_value = 20.0
	build_drag_sensitivity_slider.step = 0.1
	build_drag_sensitivity_slider.value = _settings_get_float("build_drag_pan_sensitivity", 10.0)
	_on_build_drag_sensitivity_slider_value_changed(build_drag_sensitivity_slider.value)

	camera_tilt_slider.min_value = 1.0
	camera_tilt_slider.max_value = 80.0
	camera_tilt_slider.step = 0.1
	camera_tilt_slider.value = _settings_get_float("camera_height", 26.0)
	_on_camera_tilt_slider_value_changed(camera_tilt_slider.value)

	camera_distance_slider.min_value = 3.0
	camera_distance_slider.max_value = 20.0
	camera_distance_slider.step = 0.1
	camera_distance_slider.value = _settings_get_float("camera_distance", 8.5)
	_on_camera_distance_slider_value_changed(camera_distance_slider.value)

	var mouse_follow_enabled := _settings_get_bool("camera_mouse_follow_enabled", true)
	camera_mouse_follow_enabled_checkbox.button_pressed = mouse_follow_enabled

	camera_mouse_follow_strength_slider.min_value = 0.0
	camera_mouse_follow_strength_slider.max_value = 2.0
	camera_mouse_follow_strength_slider.step = 0.01
	camera_mouse_follow_strength_slider.value = _settings_get_float("camera_mouse_follow_strength", 0.45)
	_update_mouse_follow_controls_enabled()

	_update_labels()
	_is_initializing_controls = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_settings"):
		get_viewport().set_input_as_handled()
		_toggle_menu()


func set_player(target: CharacterBody3D) -> void:
	player = target


func _toggle_menu() -> void:
	if visible:
		_close_menu()
	else:
		_open_menu()


func _open_menu() -> void:
	visible = true
	get_tree().paused = true
	var cm := get_node_or_null("/root/CursorManager")
	if cm:
		cm.show()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _close_menu() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_viewport().set_input_as_handled()


func _on_close_button_pressed() -> void:
	_close_menu()


func _on_exit_game_button_pressed() -> void:
	var world_manager := get_node_or_null("/root/World/WorldManager")
	if world_manager and world_manager.has_method("save_all_player_changes"):
		world_manager.call("save_all_player_changes")
	get_tree().paused = false
	get_tree().quit()


func _on_right_drag_yaw_slider_value_changed(value: float) -> void:
	if _is_initializing_controls:
		return
	_settings_set("right_drag_yaw_sensitivity", value / 10000.0)
	_apply_player_settings(false)
	_settings_save()
	_update_labels()


func _on_camera_drag_enabled_toggled(toggled_on: bool) -> void:
	if _is_initializing_controls:
		return
	_settings_set("camera_drag_enabled", toggled_on)
	_update_drag_sensitivity_enabled()
	_apply_player_settings(false)
	_settings_save()


func _update_drag_sensitivity_enabled() -> void:
	var enabled := camera_drag_enabled_checkbox.button_pressed
	camera_drag_sensitivity_slider.editable = enabled
	camera_drag_sensitivity_value.modulate = Color(1, 1, 1, 0.5) if not enabled else Color.WHITE


func _on_camera_drag_sensitivity_slider_value_changed(value: float) -> void:
	if _is_initializing_controls:
		return
	_settings_set("camera_drag_sensitivity", value)
	_apply_player_settings(false)
	_settings_save()
	_update_labels()


func _on_build_drag_sensitivity_slider_value_changed(value: float) -> void:
	if _is_initializing_controls:
		return
	_settings_set("build_drag_pan_sensitivity", value)
	_apply_player_settings(false)
	_settings_save()
	_update_labels()


func _on_camera_tilt_slider_value_changed(value: float) -> void:
	if _is_initializing_controls:
		return
	_settings_set("camera_height", value)
	_apply_player_settings(true)
	_settings_save()
	_update_labels()


func _on_camera_distance_slider_value_changed(value: float) -> void:
	if _is_initializing_controls:
		return
	_settings_set("camera_distance", value)
	_apply_player_settings(true)
	_settings_save()
	_update_labels()


func _on_camera_mouse_follow_enabled_toggled(toggled_on: bool) -> void:
	if _is_initializing_controls:
		return
	_settings_set("camera_mouse_follow_enabled", toggled_on)
	_update_mouse_follow_controls_enabled()
	# Toggle state is persisted immediately, but do not force camera refresh while menu is open.
	_apply_player_settings(false)
	_settings_save()


func _on_camera_mouse_follow_strength_slider_value_changed(value: float) -> void:
	if _is_initializing_controls:
		return
	_settings_set("camera_mouse_follow_strength", value)
	# Strength changes are persisted immediately, but do not force camera refresh while dragging.
	_apply_player_settings(false)
	_settings_save()
	_update_labels()


func _update_mouse_follow_controls_enabled() -> void:
	var enabled := camera_mouse_follow_enabled_checkbox.button_pressed
	camera_mouse_follow_strength_slider.editable = enabled
	camera_mouse_follow_strength_value.modulate = Color(1, 1, 1, 0.5) if not enabled else Color.WHITE


func _on_tilt_minus_pressed() -> void:
	camera_tilt_slider.value = maxf(camera_tilt_slider.min_value, camera_tilt_slider.value - 0.1)


func _on_tilt_plus_pressed() -> void:
	camera_tilt_slider.value = minf(camera_tilt_slider.max_value, camera_tilt_slider.value + 0.1)


func _on_yaw_minus_pressed() -> void:
	right_drag_yaw_slider.value = maxf(right_drag_yaw_slider.min_value, right_drag_yaw_slider.value - 1.0)


func _on_yaw_plus_pressed() -> void:
	right_drag_yaw_slider.value = minf(right_drag_yaw_slider.max_value, right_drag_yaw_slider.value + 1.0)


func _on_drag_sensitivity_minus_pressed() -> void:
	camera_drag_sensitivity_slider.value = maxf(camera_drag_sensitivity_slider.min_value, camera_drag_sensitivity_slider.value - 0.1)


func _on_drag_sensitivity_plus_pressed() -> void:
	camera_drag_sensitivity_slider.value = minf(camera_drag_sensitivity_slider.max_value, camera_drag_sensitivity_slider.value + 0.1)


func _on_build_drag_sensitivity_minus_pressed() -> void:
	build_drag_sensitivity_slider.value = maxf(build_drag_sensitivity_slider.min_value, build_drag_sensitivity_slider.value - 0.1)


func _on_build_drag_sensitivity_plus_pressed() -> void:
	build_drag_sensitivity_slider.value = minf(build_drag_sensitivity_slider.max_value, build_drag_sensitivity_slider.value + 0.1)


func _on_distance_minus_pressed() -> void:
	camera_distance_slider.value = maxf(camera_distance_slider.min_value, camera_distance_slider.value - 0.1)


func _on_distance_plus_pressed() -> void:
	camera_distance_slider.value = minf(camera_distance_slider.max_value, camera_distance_slider.value + 0.1)


func _on_mouse_follow_strength_minus_pressed() -> void:
	camera_mouse_follow_strength_slider.value = maxf(camera_mouse_follow_strength_slider.min_value, camera_mouse_follow_strength_slider.value - 0.01)


func _on_mouse_follow_strength_plus_pressed() -> void:
	camera_mouse_follow_strength_slider.value = minf(camera_mouse_follow_strength_slider.max_value, camera_mouse_follow_strength_slider.value + 0.01)


func _update_labels() -> void:
	right_drag_yaw_value.text = "%d" % int(round(right_drag_yaw_slider.value))
	camera_drag_sensitivity_value.text = "%.1f" % camera_drag_sensitivity_slider.value
	build_drag_sensitivity_value.text = "%.1f" % build_drag_sensitivity_slider.value
	camera_tilt_value.text = "%.1f" % camera_tilt_slider.value
	camera_distance_value.text = "%.1f" % camera_distance_slider.value
	camera_mouse_follow_strength_value.text = "%.2f" % camera_mouse_follow_strength_slider.value


func _settings_node() -> Node:
	return get_node_or_null("/root/GameSettings")


func _settings_load() -> void:
	var settings := _settings_node()
	if settings:
		settings.call("load_settings")


func _settings_save() -> void:
	var settings := _settings_node()
	if settings:
		settings.call("save_settings")


func _settings_set(property_name: String, value: Variant) -> void:
	var settings := _settings_node()
	if settings:
		settings.set(property_name, value)


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
