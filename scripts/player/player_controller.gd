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
const DESTROY_RAYCAST_LENGTH: float = 64.0
const DESTROY_INTERACT_RANGE: float = (2.0 / 3.0) * 0.75
const CAMERA_MOUSE_FOLLOW_MAX_HORIZONTAL: float = 2.4
const CAMERA_MOUSE_FOLLOW_SIDE_BOOST: float = 1.25
const CAMERA_MOUSE_FOLLOW_MAX_DEPTH_UP: float = 1.8
const CAMERA_MOUSE_FOLLOW_MAX_DEPTH_DOWN: float = 2.8
const CAMERA_MOUSE_FOLLOW_DEADZONE: float = 0.04
const CAMERA_MOUSE_FOLLOW_RESPONSE_EXP: float = 1.6
const CAMERA_MOUSE_FOLLOW_LERP_SPEED_MIN: float = 5.5
const CAMERA_MOUSE_FOLLOW_LERP_SPEED_MAX: float = 11.0
const CAMERA_MOUSE_FOLLOW_BOTTOM_COMPENSATION_PX: float = 90.0
const CAMERA_MOUSE_FOLLOW_MAX_OFFSET_LENGTH: float = 5.0
const CAMERA_MOUSE_FOLLOW_DOWN_NY_CAP: float = 0.8
const BUILD_TRANSITION_TIME: float = 0.5
const BUILD_CAMERA_HEIGHT_DEFAULT: float = 30.0
const BUILD_CAMERA_HEIGHT_MIN: float = 3.0
const BUILD_CAMERA_HEIGHT_MAX: float = 60.0
const BUILD_CAMERA_ZOOM_MIN: float = 12.0
const BUILD_CAMERA_ZOOM_MAX: float = 90.0
const BUILD_CAMERA_TOPDOWN_PITCH_RAD: float = -1.5608
const BUILD_ROTATE_STEP_DEGREES: float = 10.0
const BUILD_ZOOM_WHEEL_STEP: float = 1.2
const BUILD_ZOOM_BUTTON_STEP_SMALL: float = 1.0
const BUILD_ZOOM_BUTTON_STEP_LARGE: float = 10.0
const BUILD_DRAG_MAX_MOUSE_DELTA: float = 64.0
const BUILD_PICK_DOUBLE_CLICK_MS: int = 380
const BUILD_PICK_DOUBLE_CLICK_DIST: float = 22.0
const BUILD_PICK_DEBUG: bool = false

var _destroy_ui_layer: CanvasLayer
var _destroy_ui_panel: PanelContainer
var _destroy_ui_label: Label
var _destroy_ui_bar: ProgressBar
var _destroy_ui_fast_timer: float = 0.0
var _destroy_ui_hold_timer: float = 0.0
var _destroy_ui_fast_mode: bool = false
var _destroy_ui_target_type: String = ""
var _build_mode: bool = false
var _build_transition_tween: Tween
var _build_camera_height: float = BUILD_CAMERA_HEIGHT_DEFAULT
var _build_camera_zoom: float = 32.0
var _build_camera_pan: Vector3 = Vector3.ZERO
var _build_camera_target_position: Vector3 = Vector3.ZERO
var _build_camera_rotation: float = 0.0
var _build_drag_pan_factor: float = 0.035
var _build_drag_map: bool = false
var _build_last_mouse: Vector2 = Vector2.ZERO
var _build_last_left_click_ms: int = -100000
var _build_last_left_click_pos: Vector2 = Vector2.ZERO
var _build_ignore_place_until_ms: int = 0
var _camera_drag_delta_x: float = 0.0
var _build_ui_layer: CanvasLayer
var _build_ui_root: Control
var _build_list_scroll: ScrollContainer
var _build_zoom_slider: VSlider
var _build_zoom_value_label: Label
var _build_selected_id: String = ""
var _build_buttons_by_id: Dictionary = {}
var _build_preview_root: Node3D
var _build_preview_rotation_deg: float = 0.0
var _build_preview_valid: bool = false
var _build_preview_variant_seed: int = 0
var _build_forced_variant_seed: int = 0
var _build_village_generator: VillageGenerator
var _build_rng := RandomNumberGenerator.new()

const BUILDING_DEFS := [
	{"id": "house", "label": "房屋", "emoji": "🏠", "type": VillageGenerator.BuildingType.HOUSE},
	{"id": "workshop", "label": "工坊", "emoji": "🔨", "type": VillageGenerator.BuildingType.WORKSHOP},
	{"id": "warehouse", "label": "仓库", "emoji": "📦", "type": VillageGenerator.BuildingType.WAREHOUSE},
	{"id": "market", "label": "市场", "emoji": "🏪", "type": VillageGenerator.BuildingType.MARKET},
	{"id": "well", "label": "水井", "emoji": "🪣", "type": VillageGenerator.BuildingType.WELL},
	{"id": "campfire", "label": "篝火", "emoji": "🔥", "type": VillageGenerator.BuildingType.CAMPFIRE},
	{"id": "fencepost", "label": "围栏桩", "emoji": "🪵", "type": VillageGenerator.BuildingType.FENCE_POST},
	{"id": "farm", "label": "农场", "emoji": "🌾", "type": VillageGenerator.BuildingType.FARM},
	{"id": "tower", "label": "塔楼", "emoji": "🗼", "type": VillageGenerator.BuildingType.TOWER},
	{"id": "barrack", "label": "兵营", "emoji": "⚔️", "type": VillageGenerator.BuildingType.BARRACK},
]

func _ready() -> void:
	print("=== PLAYER SCRIPT LOADED ===")
	_settings_load()
	apply_camera_settings()
	_setup_destroy_ui()
	_setup_build_mode_ui()
	_build_village_generator = VillageGenerator.new(base_seed())
	_build_rng.seed = base_seed() ^ 0x88D1
	
	if camera:
		camera.top_level = true
		base_camera_fov = camera.fov
		_update_camera_follow(0.0)
	
	floor_snap_length = 0.35
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_viewport().gui_release_focus()
	get_viewport().grab_focus()
	print("Mouse mode set to VISIBLE, focus grabbed")


func base_seed() -> int:
	return 4531


func _setup_build_mode_ui() -> void:
	_build_ui_layer = CanvasLayer.new()
	_build_ui_layer.name = "BuildModeUI"
	add_child(_build_ui_layer)

	_build_ui_root = Control.new()
	_build_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui_root.visible = false
	_build_ui_layer.add_child(_build_ui_root)

	var bottom_panel := PanelContainer.new()
	bottom_panel.anchor_left = 0.0
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_top = -120.0
	bottom_panel.offset_bottom = 0.0
	_build_ui_root.add_child(bottom_panel)

	var bottom_vbox := VBoxContainer.new()
	bottom_vbox.add_theme_constant_override("separation", 4)
	bottom_panel.add_child(bottom_vbox)

	var title := Label.new()
	title.text = "建筑模式"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	bottom_vbox.add_child(title)

	_build_list_scroll = ScrollContainer.new()
	_build_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_build_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_build_list_scroll.custom_minimum_size = Vector2(0, 84)
	bottom_vbox.add_child(_build_list_scroll)

	var list_hbox := HBoxContainer.new()
	list_hbox.add_theme_constant_override("separation", 8)
	_build_list_scroll.add_child(list_hbox)

	for data in BUILDING_DEFS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(96, 74)
		btn.text = "%s\n%s" % [str(data["emoji"]), str(data["label"])]
		btn.set_meta("build_id", str(data["id"]))
		btn.gui_input.connect(_on_building_button_input.bind(str(data["id"])))
		_build_buttons_by_id[str(data["id"])] = btn
		list_hbox.add_child(btn)
	_refresh_build_button_highlight()

	var right_panel := PanelContainer.new()
	right_panel.anchor_left = 1.0
	right_panel.anchor_top = 0.25
	right_panel.anchor_right = 1.0
	right_panel.anchor_bottom = 0.85
	right_panel.offset_left = -110.0
	right_panel.offset_right = -10.0
	_build_ui_root.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_theme_constant_override("separation", 6)
	right_panel.add_child(right_vbox)

	var plus_plus := Button.new()
	plus_plus.text = "++"
	plus_plus.pressed.connect(_on_build_zoom_add_large)
	right_vbox.add_child(plus_plus)

	var plus := Button.new()
	plus.text = "+"
	plus.pressed.connect(_on_build_zoom_add_small)
	right_vbox.add_child(plus)

	_build_zoom_slider = VSlider.new()
	_build_zoom_slider.min_value = BUILD_CAMERA_ZOOM_MIN
	_build_zoom_slider.max_value = BUILD_CAMERA_ZOOM_MAX
	_build_zoom_slider.step = 0.1
	_build_zoom_slider.value = _build_camera_zoom
	_build_zoom_slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_zoom_slider.custom_minimum_size = Vector2(28, 190)
	_build_zoom_slider.value_changed.connect(_on_build_zoom_slider_changed)
	right_vbox.add_child(_build_zoom_slider)

	var minus := Button.new()
	minus.text = "-"
	minus.pressed.connect(_on_build_zoom_sub_small)
	right_vbox.add_child(minus)

	var minus_minus := Button.new()
	minus_minus.text = "--"
	minus_minus.pressed.connect(_on_build_zoom_sub_large)
	right_vbox.add_child(minus_minus)

	_build_zoom_value_label = Label.new()
	_build_zoom_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(_build_zoom_value_label)
	_update_build_zoom_label()


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
	var build_drag_sensitivity_ui := _settings_get_float("build_drag_pan_sensitivity", 10.0)
	_build_drag_pan_factor = _build_drag_factor_from_setting(build_drag_sensitivity_ui)
	
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
	if _build_mode:
		_update_build_mode(delta)
		return

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
		_camera_drag_delta_x = 0.0
		return
	if absf(_camera_drag_delta_x) < 0.001:
		return
	var drag_gain := _camera_drag_gain_from_setting(camera_drag_sensitivity)
	var angle_change := _camera_drag_delta_x * drag_gain
	_camera_drag_delta_x = 0.0
	camera_angle_offset -= angle_change
	if absf(angle_change) > 0.00001:
		_angle_cache_valid = false
	
	camera_angle_offset = fmod(camera_angle_offset, 360.0)
	if camera_angle_offset < 0:
		camera_angle_offset += 360.0


func _camera_drag_gain_from_setting(value: float) -> float:
	var x := clampf((value - 0.1) / (20.0 - 0.1), 0.0, 1.0)
	var centered := x - 0.5
	var shaped := 0.5 + 0.5 * tanh(centered * 3.2) / tanh(1.6)
	var high_tail := clampf((x - 0.72) / 0.28, 0.0, 1.0)
	var boosted := clampf(shaped + pow(high_tail, 2.2) * 0.24, 0.0, 1.0)
	return lerpf(0.00018, 0.0095, boosted)


func _build_drag_factor_from_setting(value: float) -> float:
	var x := clampf((value - 0.1) / (20.0 - 0.1), 0.0, 1.0)
	var centered := x - 0.5
	var shaped := 0.5 + 0.5 * tanh(centered * 3.0) / tanh(1.5)
	return lerpf(0.0015, 0.16, shaped)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		_toggle_build_mode()
		get_viewport().set_input_as_handled()
		return

	if _build_mode:
		_handle_build_mode_input(event)
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_destroying = event.pressed
			if not event.pressed:
				cancel_destruction()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_dragging_camera = event.pressed
			if is_dragging_camera:
				_camera_drag_delta_x = 0.0
			if not is_dragging_camera:
				_save_camera_angle()

	if event is InputEventMouseMotion and is_dragging_camera and camera_drag_enabled:
		var motion := event as InputEventMouseMotion
		_camera_drag_delta_x += motion.relative.x
	
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


func _toggle_build_mode() -> void:
	if _build_mode:
		_exit_build_mode()
	else:
		_enter_build_mode()


func _enter_build_mode() -> void:
	_build_mode = true
	is_destroying = false
	cancel_destruction()
	velocity = Vector3.ZERO
	visible = false
	_build_camera_height = clampf(BUILD_CAMERA_HEIGHT_DEFAULT, BUILD_CAMERA_HEIGHT_MIN, BUILD_CAMERA_HEIGHT_MAX)
	_build_camera_target_position = global_position
	_build_camera_pan = Vector3.ZERO
	_build_camera_rotation = 0.0

	var hotbar_ui := get_node_or_null("/root/World/HotbarUI")
	if hotbar_ui:
		hotbar_ui.visible = false

	if _build_ui_root:
		_build_ui_root.visible = true

	if _build_zoom_slider:
		_build_zoom_slider.set_value_no_signal(_build_camera_zoom)
	_update_build_zoom_label()

	if _build_transition_tween:
		_build_transition_tween.kill()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_build_transition_tween = create_tween()
	_build_transition_tween.set_trans(Tween.TRANS_SINE)
	_build_transition_tween.set_ease(Tween.EASE_IN_OUT)
	var target_pos := _build_camera_target_position + Vector3(0.0, _build_camera_height, 0.01)
	_build_transition_tween.tween_property(camera, "global_position", target_pos, BUILD_TRANSITION_TIME)
	_build_transition_tween.parallel().tween_property(camera, "size", _build_camera_zoom, BUILD_TRANSITION_TIME)
	_build_transition_tween.parallel().tween_method(Callable(self, "_build_look_down_step"), 0.0, 1.0, BUILD_TRANSITION_TIME)


func _exit_build_mode() -> void:
	_build_mode = false
	visible = true
	_build_drag_map = false
	var world_manager := get_node_or_null("/root/World/WorldManager")
	if world_manager:
		world_manager.call("save_player_buildings")
	_cancel_build_selection()

	if _build_ui_root:
		_build_ui_root.visible = false

	var hotbar_ui := get_node_or_null("/root/World/HotbarUI")
	if hotbar_ui:
		hotbar_ui.visible = true

	if _build_transition_tween:
		_build_transition_tween.kill()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_build_transition_tween = create_tween()
	_build_transition_tween.set_trans(Tween.TRANS_SINE)
	_build_transition_tween.set_ease(Tween.EASE_IN_OUT)
	var x: float = _horizontal_radius_cached * _sin_angle
	var z: float = _horizontal_radius_cached * _cos_angle
	var target_pos := global_position + Vector3(x, _height_cached, z)
	_build_transition_tween.tween_property(camera, "global_position", target_pos, BUILD_TRANSITION_TIME)
	_build_transition_tween.parallel().tween_property(camera, "size", _build_camera_zoom, BUILD_TRANSITION_TIME)
	_build_transition_tween.parallel().tween_method(Callable(self, "_build_look_follow_step"), 0.0, 1.0, BUILD_TRANSITION_TIME)


func _build_look_down_step(weight: float) -> void:
	var look_target := _build_camera_target_position + _build_camera_pan
	var from_pos := global_position + Vector3(_horizontal_radius_cached * _sin_angle, _height_cached, _horizontal_radius_cached * _cos_angle)
	var to_pos := look_target + Vector3(0.0, _build_camera_height, 0.0)
	camera.global_position = from_pos.lerp(to_pos, weight)
	_apply_build_camera_rotation()


func _build_look_follow_step(_weight: float) -> void:
	_update_camera_follow(0.0)


func _update_build_mode(delta: float) -> void:
	if not camera:
		return

	var look_target := _build_camera_target_position + _build_camera_pan
	var desired_pos := look_target + Vector3(0.0, _build_camera_height, 0.0)
	if _build_transition_tween and _build_transition_tween.is_running():
		# Transition tween drives camera.
		pass
	else:
		camera.global_position = camera.global_position.lerp(desired_pos, clampf(delta * 10.0, 0.0, 1.0))
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = lerpf(camera.size, _build_camera_zoom, clampf(delta * 12.0, 0.0, 1.0))
		_apply_build_camera_rotation()

	_update_build_preview()


func _handle_build_mode_input(event: InputEvent) -> void:
	var over_build_ui := _is_mouse_over_build_ui()
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			return
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_build_drag_map = mouse_event.pressed and not over_build_ui
			_build_last_mouse = mouse_event.position
			return

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if Input.is_key_pressed(KEY_CTRL):
				_set_build_zoom(_build_camera_zoom - BUILD_ZOOM_WHEEL_STEP)
			else:
				_build_preview_rotation_deg += BUILD_ROTATE_STEP_DEGREES
			return

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if Input.is_key_pressed(KEY_CTRL):
				_set_build_zoom(_build_camera_zoom + BUILD_ZOOM_WHEEL_STEP)
			else:
				_build_preview_rotation_deg -= BUILD_ROTATE_STEP_DEGREES
			return

		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and not over_build_ui:
			var now_ms := Time.get_ticks_msec()
			if now_ms < _build_ignore_place_until_ms:
				if BUILD_PICK_DEBUG:
					print("[BUILD_PICK] ignore place due to cooldown")
				return
			var is_double_click := (
				now_ms - _build_last_left_click_ms <= BUILD_PICK_DOUBLE_CLICK_MS
				and mouse_event.position.distance_to(_build_last_left_click_pos) <= BUILD_PICK_DOUBLE_CLICK_DIST
			)
			if BUILD_PICK_DEBUG:
				print("[BUILD_PICK] left click pos=", mouse_event.position, " dt=", now_ms - _build_last_left_click_ms, " is_double=", is_double_click)
			_build_last_left_click_ms = now_ms
			_build_last_left_click_pos = mouse_event.position

			if is_double_click and _try_pick_existing_building_to_preview():
				_build_ignore_place_until_ms = now_ms + 140
				return
			_try_place_building()
			return

	if event is InputEventMouseMotion:
		if _build_drag_map:
			var motion := event as InputEventMouseMotion
			var drag_delta := motion.relative.limit_length(BUILD_DRAG_MAX_MOUSE_DELTA)
			_build_camera_pan.x -= drag_delta.x * _build_drag_pan_factor
			_build_camera_pan.z += drag_delta.y * _build_drag_pan_factor


func _apply_build_camera_rotation() -> void:
	camera.rotation = Vector3(BUILD_CAMERA_TOPDOWN_PITCH_RAD, 0.0, 0.0)


func _is_mouse_over_build_ui() -> bool:
	if not _build_ui_root or not _build_ui_root.visible:
		return false
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	if not _build_ui_root.is_ancestor_of(hovered):
		return false
	var current: Control = hovered
	while current != null and current != _build_ui_root:
		if current is BaseButton or current is Slider or current is ScrollContainer or current is ScrollBar:
			return true
		current = current.get_parent() as Control
	return false


func _set_build_zoom(value: float) -> void:
	_build_camera_zoom = clampf(value, BUILD_CAMERA_ZOOM_MIN, BUILD_CAMERA_ZOOM_MAX)
	if _build_zoom_slider:
		_build_zoom_slider.set_value_no_signal(_build_camera_zoom)
	_update_build_zoom_label()


func _update_build_zoom_label() -> void:
	if _build_zoom_value_label:
		_build_zoom_value_label.text = "缩放 %.1f" % _build_camera_zoom


func _on_build_zoom_add_large() -> void:
	_set_build_zoom(_build_camera_zoom + BUILD_ZOOM_BUTTON_STEP_LARGE)


func _on_build_zoom_add_small() -> void:
	_set_build_zoom(_build_camera_zoom + BUILD_ZOOM_BUTTON_STEP_SMALL)


func _on_build_zoom_sub_small() -> void:
	_set_build_zoom(_build_camera_zoom - BUILD_ZOOM_BUTTON_STEP_SMALL)


func _on_build_zoom_sub_large() -> void:
	_set_build_zoom(_build_camera_zoom - BUILD_ZOOM_BUTTON_STEP_LARGE)


func _on_build_zoom_slider_changed(value: float) -> void:
	_build_camera_zoom = clampf(value, BUILD_CAMERA_ZOOM_MIN, BUILD_CAMERA_ZOOM_MAX)
	_update_build_zoom_label()


func _on_building_button_input(event: InputEvent, build_id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if mouse_event.double_click:
		_select_building(build_id)
		return
	if _build_selected_id == build_id and _build_preview_root != null:
		_cancel_build_selection()
	else:
		_select_building(build_id)


func _select_building(build_id: String) -> void:
	_build_selected_id = build_id
	_refresh_build_button_highlight()
	_spawn_build_preview()


func _cancel_build_selection() -> void:
	if _build_preview_root:
		_build_preview_root.queue_free()
		_build_preview_root = null
	_build_selected_id = ""
	_build_preview_variant_seed = 0
	_refresh_build_button_highlight()


func _refresh_build_button_highlight() -> void:
	for id_key in _build_buttons_by_id.keys():
		var btn: Button = _build_buttons_by_id[id_key] as Button
		if btn == null:
			continue
		var is_selected := str(id_key) == _build_selected_id
		_apply_build_button_style(btn, is_selected)


func _apply_build_button_style(btn: Button, is_selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8

	if is_selected:
		style.bg_color = Color(0.95, 0.74, 0.26, 1.0)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = Color(1.0, 0.95, 0.72, 1.0)
		btn.add_theme_color_override("font_color", Color(0.16, 0.11, 0.02, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.16, 0.11, 0.02, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(0.16, 0.11, 0.02, 1.0))
	else:
		style.bg_color = Color(0.17, 0.19, 0.23, 0.96)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.36, 0.39, 0.45, 1.0)
		btn.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.96, 0.97, 1.0, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(0.84, 0.86, 0.9, 1.0))

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)
	btn.add_theme_stylebox_override("disabled", style)


func _spawn_build_preview() -> void:
	if _build_preview_root:
		_build_preview_root.queue_free()
		_build_preview_root = null

	if _build_selected_id.is_empty():
		return

	var type := _building_type_from_id(_build_selected_id)
	if type == -1:
		return

	if _build_forced_variant_seed != 0:
		_build_preview_variant_seed = _build_forced_variant_seed
	else:
		_build_preview_variant_seed = int(_build_rng.randi())
	_build_forced_variant_seed = 0

	var preview_rng := RandomNumberGenerator.new()
	preview_rng.seed = _build_preview_variant_seed
	var preview := _build_village_generator._create_building_variant(preview_rng, type)
	if preview == null:
		return

	preview.name = "BuildPreview"
	preview.set_meta("build_id", _build_selected_id)
	preview.set_meta("variant_seed", _build_preview_variant_seed)
	get_parent().add_child(preview)
	_build_preview_root = preview
	_build_preview_rotation_deg = 0.0


func _building_type_from_id(build_id: String) -> int:
	for data in BUILDING_DEFS:
		if str(data["id"]) == build_id:
			return int(data["type"])
	return -1


func _resolve_build_id(node3d: Node3D) -> String:
	if node3d.has_meta("build_id"):
		return str(node3d.get_meta("build_id"))
	return _build_id_from_node_name(node3d.name)


func _build_id_from_node_name(node_name: String) -> String:
	var lower := node_name.to_lower()
	if lower.find("warehouse") != -1:
		return "warehouse"
	if lower.find("house") != -1:
		return "house"
	if lower.find("workshop") != -1:
		return "workshop"
	if lower.find("market") != -1:
		return "market"
	if lower.find("well") != -1:
		return "well"
	if lower.find("campfire") != -1:
		return "campfire"
	if lower.find("fencepost") != -1 or lower.find("fence_post") != -1 or lower.find("fence") != -1:
		return "fencepost"
	if lower.find("farm") != -1:
		return "farm"
	if lower.find("tower") != -1:
		return "tower"
	if lower.find("barrack") != -1:
		return "barrack"

	match node_name:
		"House":
			return "house"
		"Workshop":
			return "workshop"
		"Warehouse":
			return "warehouse"
		"Market":
			return "market"
		"Well":
			return "well"
		"Campfire":
			return "campfire"
		"FencePost", "Fence_Post":
			return "fencepost"
		"Farm", "FarmPlot":
			return "farm"
		"Tower":
			return "tower"
		"Barrack", "Barracks":
			return "barrack"
		_:
			return ""


func _find_building_root_from_collider(collider: Object) -> Node3D:
	if not (collider is Node):
		return null
	var current: Node = collider as Node
	while current != null:
		if current is Node3D:
			var build_id := _resolve_build_id(current as Node3D)
			if not build_id.is_empty():
				return current as Node3D
		current = current.get_parent()
	return null


func _collect_building_roots(node: Node, out: Array[Node3D]) -> void:
	if node is Node3D:
		var node3d := node as Node3D
		if node3d != _build_preview_root:
			var build_id := _resolve_build_id(node3d)
			if not build_id.is_empty():
				out.append(node3d)
	for child in node.get_children():
		_collect_building_roots(child, out)


func _find_building_root_by_screen_proximity(mouse_pos: Vector2, max_px: float) -> Node3D:
	if not camera:
		return null
	var world_root := get_node_or_null("/root/World")
	if world_root == null:
		return null
	var candidates: Array[Node3D] = []
	_collect_building_roots(world_root, candidates)
	var best: Node3D = null
	var best_d2 := max_px * max_px
	for b in candidates:
		var screen_pos := camera.unproject_position(b.global_position)
		var d2 := screen_pos.distance_squared_to(mouse_pos)
		if d2 <= best_d2:
			best_d2 = d2
			best = b
	return best


func _find_nearest_building_root(world_pos: Vector3, radius: float) -> Node3D:
	var world_root := get_node_or_null("/root/World")
	if world_root == null:
		return null
	var candidates: Array[Node3D] = []
	_collect_building_roots(world_root, candidates)
	var best: Node3D = null
	var best_dist := radius * radius
	for b in candidates:
		var d2 := b.global_position.distance_squared_to(world_pos)
		if d2 <= best_dist:
			best_dist = d2
			best = b
	return best


func _try_pick_existing_building_to_preview() -> bool:
	if not camera:
		if BUILD_PICK_DEBUG:
			print("[BUILD_PICK] fail: camera missing")
		return false
	var viewport := get_viewport()
	var mouse_pos := viewport.get_mouse_position()
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	if BUILD_PICK_DEBUG:
		print("[BUILD_PICK] try pick at mouse=", mouse_pos, " origin=", origin, " dir=", direction)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + direction * 500.0)
	ray.collide_with_areas = false
	ray.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var building_root: Node3D = null
	if not hit.is_empty():
		var collider = hit.get("collider")
		if BUILD_PICK_DEBUG:
			if collider is Node:
				var collider_node := collider as Node
				print("[BUILD_PICK] ray hit collider=", collider_node.name, " path=", collider_node.get_path())
			else:
				print("[BUILD_PICK] ray hit non-node collider=", collider)
		building_root = _find_building_root_from_collider(collider)
		if building_root == null:
			var hit_pos: Vector3 = hit.get("position", Vector3.ZERO)
			if BUILD_PICK_DEBUG:
				print("[BUILD_PICK] no root from collider, nearest by hit pos=", hit_pos)
			building_root = _find_nearest_building_root(hit_pos, 5.0)
	else:
		if BUILD_PICK_DEBUG:
			print("[BUILD_PICK] ray miss")
		if absf(direction.y) > 0.0001:
			var t := -origin.y / direction.y
			if t > 0.0:
				var ground_pos := origin + direction * t
				if BUILD_PICK_DEBUG:
					print("[BUILD_PICK] nearest by ground pos=", ground_pos)
				building_root = _find_nearest_building_root(ground_pos, 5.0)

	if building_root == null:
		if BUILD_PICK_DEBUG:
			print("[BUILD_PICK] no root from ray/nearest, trying screen proximity")
		building_root = _find_building_root_by_screen_proximity(mouse_pos, 90.0)
	if building_root == null:
		if BUILD_PICK_DEBUG:
			print("[BUILD_PICK] fail: no building root found")
		return false
	if BUILD_PICK_DEBUG:
		print("[BUILD_PICK] building root=", building_root.name, " path=", building_root.get_path())
	var build_id := _resolve_build_id(building_root)
	if build_id.is_empty():
		if BUILD_PICK_DEBUG:
			print("[BUILD_PICK] fail: unresolved build id for root=", building_root.name)
		return false
	if BUILD_PICK_DEBUG:
		print("[BUILD_PICK] resolved build_id=", build_id)

	var picked_pos := building_root.global_position
	var picked_rot := building_root.rotation.y
	var picked_variant_seed := int(building_root.get_meta("variant_seed", 0))
	var was_player_placed := bool(building_root.get_meta("player_placed", false))
	var world_manager := get_node_or_null("/root/World/WorldManager")
	if world_manager:
		world_manager.call("on_pick_existing_building", build_id, picked_pos, building_root.name, was_player_placed)
	building_root.queue_free()
	_build_forced_variant_seed = picked_variant_seed
	_select_building(build_id)
	if _build_preview_root:
		_build_preview_root.global_position = picked_pos
		_build_preview_rotation_deg = rad_to_deg(picked_rot)
		_build_preview_root.rotation.y = picked_rot
		if BUILD_PICK_DEBUG:
			print("[BUILD_PICK] success: picked and converted to preview")
		return true
	if BUILD_PICK_DEBUG:
		print("[BUILD_PICK] fail: preview root missing after select")
	return false


func _mouse_ground_position() -> Vector3:
	var viewport := get_viewport()
	var mouse_pos := viewport.get_mouse_position()
	var origin := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	if absf(dir.y) < 0.0001:
		return Vector3.ZERO
	var t := -origin.y / dir.y
	if t <= 0.0:
		return Vector3.ZERO
	return origin + dir * t


func _set_preview_tint(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var overlay := StandardMaterial3D.new()
		overlay.albedo_color = color
		overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance.material_overlay = overlay
	for child in node.get_children():
		_set_preview_tint(child, color)


func _preview_overlaps() -> bool:
	if not _build_preview_root:
		return true
	var state := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	for child in _build_preview_root.get_children():
		if child is StaticBody3D:
			var body := child as StaticBody3D
			for shape_child in body.get_children():
				if shape_child is CollisionShape3D:
					var col := shape_child as CollisionShape3D
					if col.shape == null:
						continue
					q.shape = col.shape
					q.transform = body.global_transform * Transform3D(Basis.IDENTITY, col.position)
					q.collide_with_areas = false
					q.collide_with_bodies = true
					var hits := state.intersect_shape(q, 4)
					for hit in hits:
						var collider = hit.get("collider")
						if collider == null:
							continue
						if _build_preview_root.is_ancestor_of(collider):
							continue
						if collider is Node and (collider as Node).name == "Ground":
							continue
						return true
	return false


func _update_build_preview() -> void:
	if not _build_preview_root:
		return
	var pos := _mouse_ground_position()
	if pos == Vector3.ZERO:
		_build_preview_valid = false
		_set_preview_tint(_build_preview_root, Color(0.9, 0.2, 0.2, 0.7))
		return
	_build_preview_root.global_position = pos
	_build_preview_root.rotation.y = deg_to_rad(_build_preview_rotation_deg)
	var invalid := _preview_overlaps()
	_build_preview_valid = not invalid
	_set_preview_tint(_build_preview_root, Color(0.9, 0.2, 0.2, 0.7) if invalid else Color(0.5, 1.0, 0.5, 0.8))


func _try_place_building() -> void:
	if not _build_preview_root or not _build_preview_valid:
		return
	var type := _building_type_from_id(_build_selected_id)
	if type == -1:
		return
	var world_manager := get_node_or_null("/root/World/WorldManager")
	if world_manager == null:
		return
	var placed_variant = world_manager.call(
		"spawn_player_building",
		_build_selected_id,
		_build_preview_root.global_position,
		_build_preview_root.rotation.y,
		_build_preview_variant_seed
	)
	if placed_variant == null:
		return
	var placed := placed_variant as Node3D
	if placed == null:
		return
	world_manager.call("add_player_building", _build_selected_id, placed.global_position, placed.rotation.y, placed.name, _build_preview_variant_seed)

	# Place once, then clear current selection/preview.
	_cancel_build_selection()


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

	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

func _shape_mouse_follow_axis(value: float) -> float:
	var abs_value := absf(value)
	if abs_value <= CAMERA_MOUSE_FOLLOW_DEADZONE:
		return 0.0
	var normalized := (abs_value - CAMERA_MOUSE_FOLLOW_DEADZONE) / (1.0 - CAMERA_MOUSE_FOLLOW_DEADZONE)
	normalized = pow(clampf(normalized, 0.0, 1.0), CAMERA_MOUSE_FOLLOW_RESPONSE_EXP)
	return signf(value) * normalized


func _effective_mouse_follow_strength(value: float) -> float:
	var x := clampf(value / 2.0, 0.0, 1.0)
	var shaped := 0.5 + 0.5 * tanh((x - 0.5) * 2.6) / tanh(1.3)
	return lerpf(0.0, 1.55, shaped)


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
	var raw_follow_strength := clampf(camera_mouse_follow_strength, 0.0, 2.0)
	var effective_follow_strength := _effective_mouse_follow_strength(raw_follow_strength)
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
					right * (nx * CAMERA_MOUSE_FOLLOW_MAX_HORIZONTAL * CAMERA_MOUSE_FOLLOW_SIDE_BOOST)
					+ forward * (-ny * depth_scale)
				) * effective_follow_strength
				desired_mouse_offset.y = 0.0
				if desired_mouse_offset.length() > CAMERA_MOUSE_FOLLOW_MAX_OFFSET_LENGTH:
					desired_mouse_offset = desired_mouse_offset.normalized() * CAMERA_MOUSE_FOLLOW_MAX_OFFSET_LENGTH

	if delta > 0.0:
		var response_t := clampf(raw_follow_strength / 2.0, 0.0, 1.0)
		var lerp_speed := lerpf(CAMERA_MOUSE_FOLLOW_LERP_SPEED_MAX, CAMERA_MOUSE_FOLLOW_LERP_SPEED_MIN, response_t)
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
	var to: Vector3 = from + dir * DESTROY_RAYCAST_LENGTH
	
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
			if _is_target_within_destroy_range(target) and _has_clear_destruction_line(target):
				if current_target != target:
					current_target = target
					current_target.start_destruction()
				return
	
	if current_target:
		current_target.cancel_destruction()
		current_target = null
	if not _destroy_ui_fast_mode and _destroy_ui_hold_timer <= 0.0:
		_hide_destroy_ui()


func _is_target_within_destroy_range(target: Destructible) -> bool:
	if target == null:
		return false
	var range_shape := SphereShape3D.new()
	range_shape.radius = DESTROY_INTERACT_RANGE
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = range_shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, 1.0, 0.0))
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 2
	query.exclude = [get_rid()]
	var hits := get_world_3d().direct_space_state.intersect_shape(query, 64)
	for hit_variant in hits:
		var hit := hit_variant as Dictionary
		var collider = hit.get("collider")
		if collider == target:
			return true
		if collider is Node:
			var node := collider as Node
			if node.is_ancestor_of(target):
				return true
			if target.is_ancestor_of(node):
				return true
	return false


func _has_clear_destruction_line(target: Destructible) -> bool:
	if target == null:
		return false
	var from := global_position + Vector3(0.0, 1.1, 0.0)
	var to := target.global_position + Vector3(0.0, 0.6, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider = result.get("collider")
	if collider is Node:
		var node := collider as Node
		if node.name == "Ground":
			return true
		if node == target:
			return true
		if node.is_ancestor_of(target):
			return true
		if target.is_ancestor_of(node):
			return true
	return false


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
