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
const BUILD_ROAD_MAX_CELLS_PER_FRAME: int = 32

enum RoadBatchMode {
	NONE,
	PLACE_WAIT_END,
	DELETE_WAIT_END,
}

enum DeleteIntent {
	NONE,
	PICKED_BUILDING,
	ROAD_BATCH,
}

var _destroy_ui_layer: CanvasLayer
var _destroy_ui_panel: PanelContainer
var _destroy_ui_label: Label
var _destroy_ui_bar: ProgressBar
var _destroy_ui_fast_timer: float = 0.0
var _destroy_ui_hold_timer: float = 0.0
var _destroy_ui_fast_mode: bool = false
var _destroy_ui_target_type: String = ""
var _build_mode: bool = false
var _build_mode_has_changes: bool = false
var _build_transition_tween: Tween
var _build_camera_height: float = BUILD_CAMERA_HEIGHT_DEFAULT
var _build_camera_zoom: float = 32.0
var _build_camera_pan: Vector3 = Vector3.ZERO
var _build_camera_target_position: Vector3 = Vector3.ZERO
var _build_camera_rotation: float = 0.0
var _build_drag_pan_factor: float = 0.035
var _build_drag_map: bool = false
var _build_last_mouse: Vector2 = Vector2.ZERO
var _spawn_lock_timer: float = 0.0
var _spawn_ready: bool = false
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
var _build_preview: BuildPreviewController
var _build_forced_variant_seed: int = 0
var _build_village_generator: VillageGenerator
var _build_rng := RandomNumberGenerator.new()
var _build_road_painting: bool = false
var _build_road_painted_cells: Dictionary = {}
var _build_road_painted_any: bool = false
var _build_road_has_last_cell: bool = false
var _build_road_last_cell: Vector2i = Vector2i.ZERO
var _build_road_pending_cells: Array[Vector2i] = []
var _road_batch_mode: int = RoadBatchMode.NONE
var _road_batch_start_cell: Vector2i = Vector2i.ZERO
var _road_pending_delete_cells: Dictionary = {}
var _road_delete_confirm_pending: bool = false
var _build_delete_overlay: ColorRect
var _build_delete_trash_label: Label
var _road_preview_place_cells: Array[Vector2i] = []
var _road_preview_delete_cells: Array[Vector2i] = []
var _delete_intent: int = DeleteIntent.NONE
var _build_rotating_target: Node3D
var _build_rotating_original_y: float = 0.0
var _build_rotating_dragging: bool = false
var _build_rotate_gizmo: RotateGizmo
var _build_rotate_knob_rect: Rect2 = Rect2()
var _build_rotate_center_screen: Vector2 = Vector2.ZERO
var _build_rotate_local_center: Vector3 = Vector3.ZERO
var _build_rotate_local_half_x: float = 0.0
var _build_rotate_local_half_z: float = 0.0
var _build_rotate_bounds_valid: bool = false
var _build_picked_original: Node3D
var _build_picked_original_build_id: String = ""
var _build_picked_original_name: String = ""
var _build_picked_original_pos: Vector3 = Vector3.ZERO
var _build_picked_original_rot: float = 0.0
var _build_picked_original_was_player_placed: bool = false
var _build_picked_original_entity_id: String = ""
var _build_picked_original_collision: Array[Dictionary] = []
var _holding_villager: Node3D = null
var _holding_villager_original_pos: Vector3 = Vector3.ZERO
var _villager_preview: Node3D = null
var _villager_task_ui: Control = null

const BUILDING_DEFS := [
	{"id": "house", "label": "房屋", "emoji": "🏠", "type": VillageGenerator.BuildingType.HOUSE},
	{"id": "workshop", "label": "工坊", "emoji": "🔨", "type": VillageGenerator.BuildingType.WORKSHOP},
	{"id": "warehouse", "label": "仓库", "emoji": "📦", "type": VillageGenerator.BuildingType.WAREHOUSE},
	{"id": "market", "label": "市场", "emoji": "🏪", "type": VillageGenerator.BuildingType.MARKET},
	{"id": "well", "label": "水井", "emoji": "🪣", "type": VillageGenerator.BuildingType.WELL},
	{"id": "campfire", "label": "篝火", "emoji": "🔥", "type": VillageGenerator.BuildingType.CAMPFIRE},
	{"id": "fencepost", "label": "围栏桩", "emoji": "🪵", "type": VillageGenerator.BuildingType.FENCE_POST},
	{"id": "road", "label": "道路", "emoji": "🛣️", "type": VillageGenerator.BuildingType.ROAD},
	{"id": "farm", "label": "农场", "emoji": "🌾", "type": VillageGenerator.BuildingType.FARM},
	{"id": "tower", "label": "塔楼", "emoji": "🗼", "type": VillageGenerator.BuildingType.TOWER},
	{"id": "barrack", "label": "兵营", "emoji": "⚔️", "type": VillageGenerator.BuildingType.BARRACK},
]
const BUILD_ROTATE_KNOB_SIZE: Vector2 = Vector2(26.0, 26.0)
const BUILD_ROTATE_ORBIT_MIN_RADIUS_PX: float = 20.0
const BUILD_ROTATE_ORBIT_MAX_RADIUS_PX: float = 240.0
const BUILD_ROTATE_ORBIT_PADDING_MIN_PX: float = 2.0
const BUILD_ROTATE_ORBIT_PADDING_MAX_PX: float = 10.0
const BUILD_ROTATE_ORBIT_PADDING_REF_PX: float = 140.0

func _ready() -> void:
	print("=== PLAYER SCRIPT LOADED ===")
	_settings_load()
	apply_camera_settings()
	_setup_destroy_ui()
	_setup_build_mode_ui()
	_setup_villager_task_ui()
	_build_preview = BuildPreviewController.new()
	add_child(_build_preview)
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
	var world_manager: Node = get_node_or_null("/root/World/WorldManager")
	if world_manager and world_manager.has_signal("player_spawn_ready"):
		world_manager.connect("player_spawn_ready", Callable(self, "_on_world_player_spawn_ready"))
	_spawn_ready = false
	_spawn_lock_timer = 0.8


func base_seed() -> int:
	return 4531


func _setup_villager_task_ui() -> void:
	if _villager_task_ui:
		return
	var VillagerTaskUI := load("res://scripts/ui/villager_task_ui.gd")
	_villager_task_ui = VillagerTaskUI.new()
	_villager_task_ui.name = "VillagerTaskUI"
	add_child(_villager_task_ui)


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

	_build_delete_overlay = ColorRect.new()
	_build_delete_overlay.name = "DeleteOverlay"
	_build_delete_overlay.anchor_left = 0.0
	_build_delete_overlay.anchor_top = 0.0
	_build_delete_overlay.anchor_right = 1.0
	_build_delete_overlay.anchor_bottom = 1.0
	_build_delete_overlay.offset_left = 0.0
	_build_delete_overlay.offset_top = 0.0
	_build_delete_overlay.offset_right = 0.0
	_build_delete_overlay.offset_bottom = 0.0
	_build_delete_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_delete_overlay.color = Color(0.85, 0.08, 0.08, 0.72)
	_build_delete_overlay.visible = false
	_build_delete_overlay.gui_input.connect(_on_delete_overlay_input)
	bottom_panel.add_child(_build_delete_overlay)

	_build_delete_trash_label = Label.new()
	_build_delete_trash_label.anchor_left = 0.5
	_build_delete_trash_label.anchor_top = 0.5
	_build_delete_trash_label.anchor_right = 0.5
	_build_delete_trash_label.anchor_bottom = 0.5
	_build_delete_trash_label.offset_left = -140
	_build_delete_trash_label.offset_top = -24
	_build_delete_trash_label.offset_right = 140
	_build_delete_trash_label.offset_bottom = 24
	_build_delete_trash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_delete_trash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_build_delete_trash_label.add_theme_font_size_override("font_size", 22)
	_build_delete_trash_label.text = "🗑 删除确认"
	_build_delete_trash_label.modulate = Color(1.0, 0.9, 0.9, 0.96)
	_build_delete_trash_label.visible = false
	bottom_panel.add_child(_build_delete_trash_label)

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

	var gizmo_script := preload("res://scripts/ui/rotate_gizmo.gd")
	_build_rotate_gizmo = gizmo_script.new()
	_build_rotate_gizmo.configure(
		BUILD_ROTATE_KNOB_SIZE,
		3.0,
		Color(0.26, 0.88, 0.96, 0.78),
		Color(0.45, 0.95, 1.0, 0.98),
		Color(0.08, 0.26, 0.3, 0.92)
	)
	_build_ui_root.add_child(_build_rotate_gizmo)


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
	if not _spawn_ready:
		_spawn_lock_timer -= delta
		if _spawn_lock_timer <= 0.0:
			_spawn_ready = true
		else:
			velocity = Vector3.ZERO
			move_and_slide()
			return
	if global_position.y < -80.0:
		global_position.y = 2.0
		velocity = Vector3.ZERO
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


func _on_world_player_spawn_ready(_safe_position: Vector3) -> void:
	_spawn_ready = true
	_spawn_lock_timer = 0.0

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
	# 保存建筑模式期间的改动
	if _build_mode_has_changes:
		var world_manager := get_node_or_null("/root/World/WorldManager")
		if world_manager and world_manager.has_method("save_build_mode_changes"):
			world_manager.call("save_build_mode_changes")
	_build_mode_has_changes = false
	_build_mode = false
	visible = true
	_build_drag_map = false
	_build_road_painting = false
	_build_road_painted_cells.clear()
	_build_road_painted_any = false
	_build_road_has_last_cell = false
	_build_road_pending_cells.clear()
	_cancel_rotate_selection(false)
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
	if _road_delete_confirm_pending:
		_refresh_pending_delete_visual()
	if _road_batch_mode == RoadBatchMode.PLACE_WAIT_END or _road_batch_mode == RoadBatchMode.DELETE_WAIT_END:
		var ground := _mouse_ground_position()
		if ground != Vector3.ZERO:
			_update_road_point_preview(_grid_cell_from_world(ground))
	_update_rotate_handles()
	
	if _holding_villager != null:
		_update_villager_preview()


func _handle_build_mode_input(event: InputEvent) -> void:
	var over_build_ui := _is_mouse_over_build_ui()
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			_cancel_delete_confirmation_state()
			return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and _delete_intent != DeleteIntent.NONE and _is_point_in_build_list_area(mouse_event.position):
			_confirm_delete_intent()
			get_viewport().set_input_as_handled()
			return
		if mouse_event.pressed and not over_build_ui and (mouse_event.button_index == MOUSE_BUTTON_LEFT or mouse_event.button_index == MOUSE_BUTTON_RIGHT):
			if _delete_intent != DeleteIntent.NONE:
				_cancel_delete_confirmation_state()
				return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_build_rotating_dragging = false
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and not mouse_event.pressed:
			_build_drag_map = false
			if _holding_villager != null:
				_cancel_holding_villager()
				return
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			if _build_selected_id == "road" and _build_road_painted_any:
				_cancel_build_selection()
				_build_road_painted_any = false
			return
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_build_drag_map = mouse_event.pressed and not over_build_ui and Input.is_key_pressed(KEY_CTRL)
			_build_last_mouse = mouse_event.position
			if _build_drag_map:
				return
			if mouse_event.pressed and not over_build_ui:
				_handle_road_right_click()
			return

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if Input.is_key_pressed(KEY_CTRL):
				_set_build_zoom(_build_camera_zoom - BUILD_ZOOM_WHEEL_STEP)
			else:
				if _build_preview:
					_build_preview.preview_rotation_deg += BUILD_ROTATE_STEP_DEGREES
			return

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if Input.is_key_pressed(KEY_CTRL):
				_set_build_zoom(_build_camera_zoom + BUILD_ZOOM_WHEEL_STEP)
			else:
				if _build_preview:
					_build_preview.preview_rotation_deg -= BUILD_ROTATE_STEP_DEGREES
			return

		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and not over_build_ui:
			var now_ms := Time.get_ticks_msec()
			var is_double_click := (
				now_ms - _build_last_left_click_ms <= BUILD_PICK_DOUBLE_CLICK_MS
				and mouse_event.position.distance_to(_build_last_left_click_pos) <= BUILD_PICK_DOUBLE_CLICK_DIST
			)
			if BUILD_PICK_DEBUG:
				print("[BUILD_PICK] left click pos=", mouse_event.position, " dt=", now_ms - _build_last_left_click_ms, " is_double=", is_double_click)
			_build_last_left_click_ms = now_ms
			_build_last_left_click_pos = mouse_event.position

			if _holding_villager != null:
				_place_held_villager()
				return
			
			if is_double_click:
				if _try_pick_villager():
					_build_ignore_place_until_ms = now_ms + 140
					return
				if _try_pick_existing_building_to_preview():
					_build_ignore_place_until_ms = now_ms + 140
					return
			if now_ms < _build_ignore_place_until_ms:
				if BUILD_PICK_DEBUG:
					print("[BUILD_PICK] ignore place due to cooldown")
				return
			if _build_selected_id.is_empty():
				if _handle_rotate_click(mouse_event.position):
					return
			_try_place_building()
			return

	if event is InputEventMouseMotion:
		if _build_rotating_dragging and _build_rotating_target != null:
			var world_pos := _mouse_ground_position()
			var delta := world_pos - _build_rotating_target.global_position
			delta.y = 0.0
			if delta.length_squared() > 0.0001:
				_build_rotating_target.rotation.y = atan2(delta.x, delta.z)
			return
		if _build_drag_map:
			var motion := event as InputEventMouseMotion
			var drag_delta := motion.relative.limit_length(BUILD_DRAG_MAX_MOUSE_DELTA)
			_build_camera_pan.x -= drag_delta.x * _build_drag_pan_factor
			_build_camera_pan.z += drag_delta.y * _build_drag_pan_factor
		if not _build_drag_map and (_road_batch_mode == RoadBatchMode.PLACE_WAIT_END or _road_batch_mode == RoadBatchMode.DELETE_WAIT_END):
			var ground := _mouse_ground_position()
			if ground != Vector3.ZERO:
				_update_road_point_preview(_grid_cell_from_world(ground))


func _update_road_painting_step() -> void:
	if not _build_road_painting or _build_selected_id != "road":
		return
	var mouse_world := _mouse_ground_position()
	if mouse_world == Vector3.ZERO:
		return
	var current_cell := _grid_cell_from_world(mouse_world)
	if not _build_road_has_last_cell:
		_build_road_last_cell = current_cell
		_build_road_has_last_cell = true
	
	if _build_road_pending_cells.is_empty():
		_build_road_pending_cells = _cells_between_4_connected(_build_road_last_cell, current_cell)
		_build_road_last_cell = current_cell
	
	var world_manager := get_node_or_null("/root/World/WorldManager")
	var budget := BUILD_ROAD_MAX_CELLS_PER_FRAME
	while budget > 0 and not _build_road_pending_cells.is_empty():
		var cell := _build_road_pending_cells.pop_front() as Vector2i
		budget -= 1
		if _build_road_painted_cells.has(cell):
			continue
		if world_manager and world_manager.has_method("has_road_cell"):
			if bool(world_manager.call("has_road_cell", cell)):
				_build_road_painted_cells[cell] = true
				continue
		if _try_place_building_at(_grid_pos_from_cell(cell)):
			_build_road_painted_cells[cell] = true


func _cells_between_4_connected(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if from_cell == to_cell:
		out.append(to_cell)
		return out
	var x := from_cell.x
	var z := from_cell.y
	var dx := to_cell.x - from_cell.x
	var dz := to_cell.y - from_cell.y
	var sx := 1 if dx >= 0 else -1
	var sz := 1 if dz >= 0 else -1
	var adx := absi(dx)
	var adz := absi(dz)
	out.append(Vector2i(x, z))
	if adx >= adz:
		var err := adx / 2
		while x != to_cell.x:
			x += sx
			err -= adz
			if err < 0:
				z += sz
				err += adx
				out.append(Vector2i(x, z - sz))
			out.append(Vector2i(x, z))
	else:
		var err2 := adz / 2
		while z != to_cell.y:
			z += sz
			err2 -= adx
			if err2 < 0:
				x += sx
				err2 += adz
				out.append(Vector2i(x - sx, z))
			out.append(Vector2i(x, z))
	return out


func _handle_road_right_click() -> void:
	# 右键两点操作：起点在道路上=>删路；否则若道路可用=>铺路
	if _road_delete_confirm_pending:
		_cancel_road_delete_confirm_state()
		return
	var ground_pos := _mouse_ground_position()
	if ground_pos == Vector3.ZERO:
		return
	var cell := _grid_cell_from_world(ground_pos)
	var has_road := _cell_has_deletable_road(cell)
	var world_manager := get_node_or_null("/root/World/WorldManager")
	if not has_road and world_manager != null and world_manager.has_method("has_road_cell"):
		has_road = bool(world_manager.call("has_road_cell", cell))

	if _road_batch_mode == RoadBatchMode.NONE:
		_clear_road_point_preview()
		if has_road:
			_road_batch_start_cell = cell
			_road_batch_mode = RoadBatchMode.DELETE_WAIT_END
			return
		var can_place := (_build_selected_id == "road") or (_build_picked_original != null and _build_picked_original_build_id == "road")
		if not can_place:
			return
		_road_batch_start_cell = cell
		_road_batch_mode = RoadBatchMode.PLACE_WAIT_END
		return

	if _road_batch_mode == RoadBatchMode.PLACE_WAIT_END:
		var path_cells := _compute_quick_place_path(_road_batch_start_cell, cell)
		if not path_cells.is_empty():
			_apply_quick_place_path(path_cells)
		_road_batch_mode = RoadBatchMode.NONE
		_clear_road_point_preview()
		return

	if _road_batch_mode == RoadBatchMode.DELETE_WAIT_END:
		if not has_road:
			_road_batch_mode = RoadBatchMode.NONE
			_clear_road_point_preview()
			return
		var delete_cells := _compute_quick_delete_cells(_road_batch_start_cell, cell)
		_road_pending_delete_cells.clear()
		for c in delete_cells:
			_road_pending_delete_cells[c] = true
		_road_delete_confirm_pending = not _road_pending_delete_cells.is_empty()
		_delete_intent = DeleteIntent.ROAD_BATCH if _road_delete_confirm_pending else DeleteIntent.NONE
		_refresh_pending_delete_visual()
		_road_batch_mode = RoadBatchMode.NONE
		_update_delete_hint_visibility()


func _compute_quick_place_path(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	if start_cell == end_cell:
		return [start_cell]
	if start_cell.x == end_cell.x or start_cell.y == end_cell.y:
		return _cells_between_4_connected(start_cell, end_cell)
	return _a_star_road_preferred(start_cell, end_cell)


func _a_star_road_preferred(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	var world_manager := get_node_or_null("/root/World/WorldManager")
	if world_manager == null or not world_manager.has_method("has_road_cell"):
		return _cells_between_4_connected(start_cell, end_cell)
	var margin := 16
	var min_x := mini(start_cell.x, end_cell.x) - margin
	var max_x := maxi(start_cell.x, end_cell.x) + margin
	var min_z := mini(start_cell.y, end_cell.y) - margin
	var max_z := maxi(start_cell.y, end_cell.y) + margin

	var open: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start_cell: 0.0}
	var f_score: Dictionary = {start_cell: float(_manhattan(start_cell, end_cell))}

	while not open.is_empty():
		var best_idx := 0
		var best_f := float(f_score.get(open[0], 1e20))
		for i in range(1, open.size()):
			var f := float(f_score.get(open[i], 1e20))
			if f < best_f:
				best_f = f
				best_idx = i
		var current: Vector2i = open[best_idx]
		open.remove_at(best_idx)
		if current == end_cell:
			return _reconstruct_path(came_from, current)

		var neighbors: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for dir in neighbors:
			var nb: Vector2i = current + dir
			if nb.x < min_x or nb.x > max_x or nb.y < min_z or nb.y > max_z:
				continue
			var move_cost := 1.0
			if bool(world_manager.call("has_road_cell", nb)):
				move_cost = 0.7
			var tentative_g := float(g_score.get(current, 1e20)) + move_cost
			if tentative_g < float(g_score.get(nb, 1e20)):
				came_from[nb] = current
				g_score[nb] = tentative_g
				f_score[nb] = tentative_g + float(_manhattan(nb, end_cell))
				if not open.has(nb):
					open.append(nb)

	return _cells_between_4_connected(start_cell, end_cell)


func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [current]
	var c := current
	while came_from.has(c):
		c = came_from[c] as Vector2i
		out.append(c)
	out.reverse()
	return out


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _apply_quick_place_path(path_cells: Array[Vector2i]) -> void:
	for c in path_cells:
		var wm := get_node_or_null("/root/World/WorldManager")
		if wm and wm.has_method("has_road_cell") and bool(wm.call("has_road_cell", c)):
			continue
		if _try_place_building_at(_grid_pos_from_cell(c)):
			_build_mode_has_changes = true


func _compute_quick_delete_cells(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	# 删路预览按几何区域计算：共线=线段；非共线=矩形区域
	if start_cell.x == end_cell.x or start_cell.y == end_cell.y:
		var line_cells := _cells_between_4_connected(start_cell, end_cell)
		for c in line_cells:
			if _cell_has_deletable_road(c):
				out.append(c)
		return out

	var min_x := mini(start_cell.x, end_cell.x)
	var max_x := maxi(start_cell.x, end_cell.x)
	var min_z := mini(start_cell.y, end_cell.y)
	var max_z := maxi(start_cell.y, end_cell.y)
	for x in range(min_x, max_x + 1):
		for z in range(min_z, max_z + 1):
			var c := Vector2i(x, z)
			if _cell_has_deletable_road(c):
				out.append(c)
	return out


func _cell_has_deletable_road(cell: Vector2i) -> bool:
	var wm := get_node_or_null("/root/World/WorldManager")
	if wm == null:
		return false
	# 优先用节点索引判断（最可靠）
	if wm.has_method("get_road_node_at_cell"):
		var node_variant = wm.call("get_road_node_at_cell", cell)
		var road_node := node_variant as Node3D
		if road_node != null and is_instance_valid(road_node):
			return true
	# 其次用路网判断
	if wm.has_method("has_road_cell"):
		var has_network_road := bool(wm.call("has_road_cell", cell))
		if has_network_road:
			# 路网有但索引无，尝试一次自愈再判定
			if wm.has_method("reconcile_road_state"):
				wm.call("reconcile_road_state")
			if wm.has_method("get_road_node_at_cell"):
				var node_variant2 = wm.call("get_road_node_at_cell", cell)
				var road_node2: Node3D = node_variant2 as Node3D
				if road_node2 != null and is_instance_valid(road_node2):
					return true
	return false


func _confirm_pending_road_delete() -> void:
	if not _road_delete_confirm_pending:
		return
	var wm := get_node_or_null("/root/World/WorldManager")
	if wm == null or not wm.has_method("get_road_node_at_cell"):
		_cancel_road_delete_confirm_state()
		return
	for cell in _road_pending_delete_cells.keys():
		var c := cell as Vector2i
		var node_variant = wm.call("get_road_node_at_cell", c)
		var road_node := node_variant as Node3D
		if road_node == null or not is_instance_valid(road_node):
			continue
		road_node.set_meta("pending_delete", true)
		wm.call(
			"on_pick_existing_building",
			"road",
			road_node.global_position,
			road_node.name,
			bool(road_node.get_meta("player_placed", false)),
			str(road_node.get_meta("entity_id", ""))
		)
		road_node.queue_free()
	_build_mode_has_changes = true
	_cancel_road_delete_confirm_state()


func _apply_build_camera_rotation() -> void:
	camera.rotation = Vector3(BUILD_CAMERA_TOPDOWN_PITCH_RAD, 0.0, 0.0)


func _update_rotate_handles() -> void:
	if _build_rotate_gizmo == null:
		return
	if _build_rotating_target == null or not is_instance_valid(_build_rotating_target):
		_build_rotate_gizmo.visible = false
		return
	if not camera:
		_build_rotate_gizmo.visible = false
		return
	var world_center := _build_rotate_world_center(_build_rotating_target)
	_build_rotate_center_screen = camera.unproject_position(world_center)
	var orbit_radius := _build_rotate_orbit_radius_px(_build_rotating_target, _build_rotate_center_screen)
	var angle := _build_rotating_target.rotation.y
	_build_rotate_gizmo.update_gizmo(_build_rotate_center_screen, orbit_radius, angle)
	_build_rotate_knob_rect = _build_rotate_gizmo.get_knob_rect()


func _build_rotate_world_center(node: Node3D) -> Vector3:
	if _build_rotate_bounds_valid and node == _build_rotating_target:
		return node.global_transform * _build_rotate_local_center
	return _build_visual_center_world(node)


func _build_rotate_padding_from_distance(distance: float) -> float:
	var t := clampf(distance / BUILD_ROTATE_ORBIT_PADDING_REF_PX, 0.0, 1.0)
	return lerpf(BUILD_ROTATE_ORBIT_PADDING_MIN_PX, BUILD_ROTATE_ORBIT_PADDING_MAX_PX, t)


func _stash_picked_original(target: Node3D, build_id: String, pos: Vector3, rot_y: float, was_player_placed: bool) -> void:
	_restore_picked_original()
	_build_picked_original = target
	_build_picked_original_build_id = build_id
	_build_picked_original_name = target.name
	_build_picked_original_pos = pos
	_build_picked_original_rot = rot_y
	_build_picked_original_was_player_placed = was_player_placed
	_build_picked_original_entity_id = str(target.get_meta("entity_id", ""))
	_build_picked_original_collision.clear()
	_set_building_collision_enabled(target, false)
	target.visible = false
	if build_id == "road":
		target.set_meta("picked_hidden", true)
		target.set_meta("pending_delete", false)
		var world_manager := get_node_or_null("/root/World/WorldManager")
		if world_manager and world_manager.has_method("begin_pickup_road"):
			var cell := Vector2i(roundi(pos.x), roundi(pos.z))
			world_manager.call("begin_pickup_road", cell)
	_delete_intent = DeleteIntent.PICKED_BUILDING
	_update_delete_hint_visibility()


func _finalize_picked_original() -> void:
	if _build_picked_original == null or not is_instance_valid(_build_picked_original):
		_clear_picked_original()
		return
	var world_manager := get_node_or_null("/root/World/WorldManager")
	if world_manager:
		if _build_picked_original_build_id == "road":
			_build_picked_original.set_meta("pending_delete", true)
		world_manager.call(
			"on_pick_existing_building",
			_build_picked_original_build_id,
			_build_picked_original_pos,
			_build_picked_original_name,
			_build_picked_original_was_player_placed,
			_build_picked_original_entity_id
		)
	_build_mode_has_changes = true
	if _build_picked_original_build_id == "road" and is_instance_valid(_build_picked_original):
		_build_picked_original.set_meta("picked_hidden", false)
	_build_picked_original.queue_free()
	_clear_picked_original()
	_update_delete_hint_visibility()


func _restore_picked_original() -> void:
	if _build_picked_original == null:
		_clear_picked_original()
		return
	if not is_instance_valid(_build_picked_original):
		_clear_picked_original()
		return
	_set_building_collision_enabled(_build_picked_original, true)
	if _build_picked_original_build_id == "road":
		_build_picked_original.set_meta("picked_hidden", false)
		_build_picked_original.set_meta("pending_delete", false)
		var world_manager := get_node_or_null("/root/World/WorldManager")
		if world_manager and world_manager.has_method("cancel_pickup_road"):
			world_manager.call("cancel_pickup_road", _build_picked_original)
	_build_picked_original.visible = true
	_clear_picked_original()
	_update_delete_hint_visibility()


func _clear_picked_original() -> void:
	_build_picked_original = null
	_build_picked_original_build_id = ""
	_build_picked_original_name = ""
	_build_picked_original_pos = Vector3.ZERO
	_build_picked_original_rot = 0.0
	_build_picked_original_was_player_placed = false
	_build_picked_original_entity_id = ""
	_build_picked_original_collision.clear()
	if _delete_intent == DeleteIntent.PICKED_BUILDING:
		_delete_intent = DeleteIntent.NONE
	_update_delete_hint_visibility()


func _set_building_collision_enabled(node: Node, enabled: bool) -> void:
	if node is CollisionObject3D:
		var body := node as CollisionObject3D
		if not enabled:
			_build_picked_original_collision.append({
				"node": body,
				"layer": body.collision_layer,
				"mask": body.collision_mask,
			})
			body.collision_layer = 0
			body.collision_mask = 0
		else:
			for entry_variant in _build_picked_original_collision:
				var entry := entry_variant as Dictionary
				var entry_node := entry.get("node") as CollisionObject3D
				if entry_node == body:
					body.collision_layer = int(entry.get("layer", 1))
					body.collision_mask = int(entry.get("mask", 1))
					break
	for child in node.get_children():
		_set_building_collision_enabled(child, enabled)


func _cache_build_rotate_bounds(target: Node3D) -> void:
	_build_rotate_bounds_valid = false
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(target, meshes)
	if meshes.is_empty():
		return
	var inv := target.global_transform.affine_inverse()
	var has_bounds := false
	var min_v := Vector3.ZERO
	var max_v := Vector3.ZERO
	for m in meshes:
		if m.mesh == null:
			continue
		var aabb := m.get_aabb()
		var corners: Array[Vector3] = [
			aabb.position,
			aabb.position + Vector3(aabb.size.x, 0.0, 0.0),
			aabb.position + Vector3(0.0, aabb.size.y, 0.0),
			aabb.position + Vector3(0.0, 0.0, aabb.size.z),
			aabb.position + Vector3(aabb.size.x, aabb.size.y, 0.0),
			aabb.position + Vector3(aabb.size.x, 0.0, aabb.size.z),
			aabb.position + Vector3(0.0, aabb.size.y, aabb.size.z),
			aabb.position + aabb.size,
		]
		for c in corners:
			var local_corner: Vector3 = inv * (m.global_transform * c)
			if not has_bounds:
				min_v = local_corner
				max_v = local_corner
				has_bounds = true
			else:
				min_v = min_v.min(local_corner)
				max_v = max_v.max(local_corner)

	if not has_bounds:
		return

	_build_rotate_local_center = (min_v + max_v) * 0.5
	_build_rotate_local_half_x = maxf((max_v.x - min_v.x) * 0.5, 0.02)
	_build_rotate_local_half_z = maxf((max_v.z - min_v.z) * 0.5, 0.02)
	_build_rotate_bounds_valid = true


func _build_rotate_orbit_radius_px(node: Node3D, screen_center: Vector2) -> float:
	if _build_rotate_bounds_valid and node == _build_rotating_target:
		var edge_points: Array[Vector3] = [
			node.global_transform * (_build_rotate_local_center + Vector3(_build_rotate_local_half_x, 0.0, 0.0)),
			node.global_transform * (_build_rotate_local_center - Vector3(_build_rotate_local_half_x, 0.0, 0.0)),
			node.global_transform * (_build_rotate_local_center + Vector3(0.0, 0.0, _build_rotate_local_half_z)),
			node.global_transform * (_build_rotate_local_center - Vector3(0.0, 0.0, _build_rotate_local_half_z)),
		]

		var max_distance := 0.0
		for p in edge_points:
			var screen_p := camera.unproject_position(p)
			var distance := screen_p.distance_to(screen_center)
			if distance > max_distance:
				max_distance = distance

		var radius := max_distance + _build_rotate_padding_from_distance(max_distance)
		return clampf(radius, BUILD_ROTATE_ORBIT_MIN_RADIUS_PX, BUILD_ROTATE_ORBIT_MAX_RADIUS_PX)

	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(node, meshes)
	if meshes.is_empty():
		return BUILD_ROTATE_ORBIT_MIN_RADIUS_PX

	var has_bounds := false
	var min_v := Vector3.ZERO
	var max_v := Vector3.ZERO
	for m in meshes:
		if m.mesh == null:
			continue
		var aabb := m.get_aabb()
		var corners: Array[Vector3] = [
			aabb.position,
			aabb.position + Vector3(aabb.size.x, 0.0, 0.0),
			aabb.position + Vector3(0.0, aabb.size.y, 0.0),
			aabb.position + Vector3(0.0, 0.0, aabb.size.z),
			aabb.position + Vector3(aabb.size.x, aabb.size.y, 0.0),
			aabb.position + Vector3(aabb.size.x, 0.0, aabb.size.z),
			aabb.position + Vector3(0.0, aabb.size.y, aabb.size.z),
			aabb.position + aabb.size,
		]
		for c in corners:
			var world_corner: Vector3 = m.global_transform * c
			if not has_bounds:
				min_v = world_corner
				max_v = world_corner
				has_bounds = true
			else:
				min_v = min_v.min(world_corner)
				max_v = max_v.max(world_corner)

	if not has_bounds:
		return BUILD_ROTATE_ORBIT_MIN_RADIUS_PX

	var center_world := (min_v + max_v) * 0.5
	var half_x := maxf((max_v.x - min_v.x) * 0.5, 0.02)
	var half_z := maxf((max_v.z - min_v.z) * 0.5, 0.02)
	var edge_points: Array[Vector3] = [
		center_world + Vector3(half_x, 0.0, 0.0),
		center_world - Vector3(half_x, 0.0, 0.0),
		center_world + Vector3(0.0, 0.0, half_z),
		center_world - Vector3(0.0, 0.0, half_z),
	]

	var max_distance := 0.0
	for p in edge_points:
		var screen_p := camera.unproject_position(p)
		var distance := screen_p.distance_to(screen_center)
		if distance > max_distance:
			max_distance = distance

	var radius := max_distance + _build_rotate_padding_from_distance(max_distance)
	return clampf(radius, BUILD_ROTATE_ORBIT_MIN_RADIUS_PX, BUILD_ROTATE_ORBIT_MAX_RADIUS_PX)


func _build_visual_center_world(node: Node3D) -> Vector3:
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(node, meshes)
	if meshes.is_empty():
		return node.global_position + Vector3(0.0, 1.0, 0.0)

	var has_bounds := false
	var min_v := Vector3.ZERO
	var max_v := Vector3.ZERO
	for m in meshes:
		if m.mesh == null:
			continue
		var aabb := m.get_aabb()
		var corners: Array[Vector3] = [
			aabb.position,
			aabb.position + Vector3(aabb.size.x, 0.0, 0.0),
			aabb.position + Vector3(0.0, aabb.size.y, 0.0),
			aabb.position + Vector3(0.0, 0.0, aabb.size.z),
			aabb.position + Vector3(aabb.size.x, aabb.size.y, 0.0),
			aabb.position + Vector3(aabb.size.x, 0.0, aabb.size.z),
			aabb.position + Vector3(0.0, aabb.size.y, aabb.size.z),
			aabb.position + aabb.size,
		]
		for c in corners:
			var w: Vector3 = m.global_transform * c
			if not has_bounds:
				min_v = w
				max_v = w
				has_bounds = true
			else:
				min_v = min_v.min(w)
				max_v = max_v.max(w)

	if not has_bounds:
		return node.global_position + Vector3(0.0, 1.0, 0.0)
	return (min_v + max_v) * 0.5


func _collect_mesh_instances(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_mesh_instances(child, out)


func _handle_rotate_click(mouse_pos: Vector2) -> bool:
	if _build_rotating_target != null and is_instance_valid(_build_rotating_target):
		if _build_rotate_knob_rect.has_point(mouse_pos):
			_build_rotating_dragging = true
			return true

	var clicked := _pick_building_by_mouse(mouse_pos)
	if clicked != null:
		if _build_rotating_target == clicked:
			_confirm_rotate_selection()
			return true
		_begin_rotate_selection(clicked)
		return true

	if _build_rotating_target != null:
		_cancel_rotate_selection(true)
		return true

	return false


func _pick_building_by_mouse(mouse_pos: Vector2) -> Node3D:
	if not camera:
		return null
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + direction * 500.0)
	ray.collide_with_areas = false
	ray.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return null
	return _find_building_root_from_collider(hit.get("collider"))


func _begin_rotate_selection(target: Node3D) -> void:
	_cancel_build_selection()
	_build_rotating_target = target
	_build_rotating_original_y = target.rotation.y
	_build_rotating_dragging = false
	_cache_build_rotate_bounds(target)


func _confirm_rotate_selection() -> void:
	if _build_rotating_target == null or not is_instance_valid(_build_rotating_target):
		_cancel_rotate_selection(false)
		return
	var world_manager := get_node_or_null("/root/World/WorldManager")
	if world_manager:
		var build_id := _resolve_build_id(_build_rotating_target)
		if build_id.is_empty():
			_cancel_rotate_selection(false)
			return
		world_manager.call(
			"on_pick_existing_building",
			build_id,
			_build_rotating_target.global_position,
			_build_rotating_target.name,
			bool(_build_rotating_target.get_meta("player_placed", false)),
			str(_build_rotating_target.get_meta("entity_id", ""))
		)
		world_manager.call("add_player_building", build_id, _build_rotating_target.global_position, _build_rotating_target.rotation.y, _build_rotating_target.name, int(_build_rotating_target.get_meta("variant_seed", 0)))
	_cancel_rotate_selection(false)


func _cancel_rotate_selection(restore_rotation: bool) -> void:
	if restore_rotation and _build_rotating_target != null and is_instance_valid(_build_rotating_target):
		_build_rotating_target.rotation.y = _build_rotating_original_y
	_build_rotating_target = null
	_build_rotating_dragging = false
	_build_rotate_bounds_valid = false
	if _build_rotate_gizmo:
		_build_rotate_gizmo.visible = false


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
	# 先检查道路删除确认状态，再检查其他删除意图
	if build_id == "road" and _road_delete_confirm_pending:
		_confirm_pending_road_delete()
		return
	if _road_delete_confirm_pending:
		_cancel_road_delete_confirm_state()
	if _delete_intent != DeleteIntent.NONE:
		return
	if mouse_event.double_click:
		_select_building(build_id)
		return
	if _build_selected_id == build_id and _build_picked_original != null:
		_finalize_picked_original()
		_cancel_build_selection()
		return
	if _build_selected_id == build_id and (_build_preview and _build_preview.preview_root != null):
		_cancel_build_selection()
	else:
		_select_building(build_id)


func _select_building(build_id: String) -> void:
	_cancel_rotate_selection(false)
	_build_selected_id = build_id
	_refresh_build_button_highlight()
	_spawn_build_preview()


func _cancel_build_selection() -> void:
	if _build_preview:
		_build_preview.clear_preview()
	_build_selected_id = ""
	_build_road_painting = false
	_build_road_painted_cells.clear()
	_build_road_painted_any = false
	_build_road_has_last_cell = false
	_build_road_pending_cells.clear()
	_road_batch_mode = RoadBatchMode.NONE
	_road_pending_delete_cells.clear()
	_road_delete_confirm_pending = false
	_delete_intent = DeleteIntent.NONE
	_clear_road_point_preview()
	_restore_picked_original()
	_cancel_rotate_selection(false)
	_update_delete_hint_visibility()
	_refresh_build_button_highlight()


func _update_delete_hint_visibility() -> void:
	var active := _delete_intent != DeleteIntent.NONE
	if _build_delete_overlay:
		_build_delete_overlay.visible = active
	if _build_delete_trash_label:
		_build_delete_trash_label.visible = active
	if active:
		for id_key in _build_buttons_by_id.keys():
			var btn: Button = _build_buttons_by_id[id_key] as Button
			if btn:
				btn.modulate = Color(1, 0.3, 0.3, 0.8)  # 设置为红色，提示删除操作
	else:
		for id_key in _build_buttons_by_id.keys():
			var btn2: Button = _build_buttons_by_id[id_key] as Button
			if btn2:
				btn2.modulate = Color(1, 1, 1, 1)
	_refresh_build_button_highlight()


func _is_point_in_build_list_area(screen_pos: Vector2) -> bool:
	if _build_ui_root == null or not _build_ui_root.visible:
		return false
	if _build_list_scroll == null:
		return false
	var rect := _build_list_scroll.get_global_rect()
	return rect.has_point(screen_pos)


func _clear_road_point_preview() -> void:
	var wm := get_node_or_null("/root/World/WorldManager")
	if wm and wm.has_method("highlight_road_cells"):
		if not _road_preview_place_cells.is_empty():
			wm.call("highlight_road_cells", _road_preview_place_cells, 0, 0.01)
		if not _road_preview_delete_cells.is_empty():
			wm.call("highlight_road_cells", _road_preview_delete_cells, 0, 0.01)
	_road_preview_place_cells.clear()
	_road_preview_delete_cells.clear()


func _refresh_pending_delete_visual() -> void:
	if not _road_delete_confirm_pending:
		return
	if _road_pending_delete_cells.is_empty():
		return
	var wm := get_node_or_null("/root/World/WorldManager")
	if wm == null or not wm.has_method("highlight_road_cells"):
		return
	var cells: Array[Vector2i] = []
	for key in _road_pending_delete_cells.keys():
		cells.append(key as Vector2i)
	if not cells.is_empty():
		# 用短时长循环刷新，保持持续红色预警
		wm.call("highlight_road_cells", cells, 3, 0.35)


func _update_road_point_preview(current_cell: Vector2i) -> void:
	var wm := get_node_or_null("/root/World/WorldManager")
	if wm == null or not wm.has_method("highlight_road_cells"):
		return
	# 先清旧预览，避免短时高亮叠加导致视觉不稳定
	if wm.has_method("highlight_road_cells"):
		if not _road_preview_place_cells.is_empty():
			wm.call("highlight_road_cells", _road_preview_place_cells, 0, 0.01)
		if not _road_preview_delete_cells.is_empty():
			wm.call("highlight_road_cells", _road_preview_delete_cells, 0, 0.01)
	if _road_batch_mode == RoadBatchMode.PLACE_WAIT_END:
		_road_preview_place_cells = _compute_quick_place_path(_road_batch_start_cell, current_cell)
		if not _road_preview_place_cells.is_empty():
			wm.call("highlight_road_cells", _road_preview_place_cells, 2, 0.6)
		_road_preview_delete_cells.clear()
	elif _road_batch_mode == RoadBatchMode.DELETE_WAIT_END:
		_road_preview_delete_cells = _compute_quick_delete_cells(_road_batch_start_cell, current_cell)
		if not _road_preview_delete_cells.is_empty():
			wm.call("highlight_road_cells", _road_preview_delete_cells, 3, 0.6)
		_road_preview_place_cells.clear()


func _cancel_road_delete_confirm_state() -> void:
	var wm := get_node_or_null("/root/World/WorldManager")
	if wm and wm.has_method("highlight_road_cells") and not _road_pending_delete_cells.is_empty():
		var cells: Array[Vector2i] = []
		for key in _road_pending_delete_cells.keys():
			cells.append(key as Vector2i)
		if not cells.is_empty():
			wm.call("highlight_road_cells", cells, 0, 0.01)
	_road_pending_delete_cells.clear()
	_road_delete_confirm_pending = false
	_road_batch_mode = RoadBatchMode.NONE
	_delete_intent = DeleteIntent.NONE
	_clear_road_point_preview()
	_update_delete_hint_visibility()


func _cancel_delete_confirmation_state() -> void:
	if _build_picked_original != null:
		_restore_picked_original()
	_cancel_road_delete_confirm_state()


func _confirm_delete_intent() -> void:
	if _delete_intent == DeleteIntent.PICKED_BUILDING:
		_finalize_picked_original()
		_cancel_build_selection()
		return
	if _delete_intent == DeleteIntent.ROAD_BATCH:
		_confirm_pending_road_delete()


func _on_delete_overlay_input(event: InputEvent) -> void:
	if not (_delete_intent != DeleteIntent.NONE):
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_confirm_delete_intent()
		get_viewport().set_input_as_handled()


func _refresh_build_button_highlight() -> void:
	var suppress_selection := (_build_picked_original != null) or _road_delete_confirm_pending
	for id_key in _build_buttons_by_id.keys():
		var btn: Button = _build_buttons_by_id[id_key] as Button
		if btn == null:
			continue
		var is_selected := (not suppress_selection) and str(id_key) == _build_selected_id
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
	if _build_preview == null:
		return
	_build_preview.clear_preview()

	if _build_selected_id.is_empty():
		return

	var type := _building_type_from_id(_build_selected_id)
	if type == -1:
		return

	var variant_seed := 0
	if _build_forced_variant_seed != 0:
		variant_seed = _build_forced_variant_seed
	else:
		variant_seed = int(_build_rng.randi())
	_build_forced_variant_seed = 0
	_build_preview.spawn_preview(get_parent(), _build_selected_id, type, _build_village_generator, variant_seed)


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
	# 仅接受严格命名，避免把系统节点（如 RoadGridMap）识别为可拾取道路。
	var base := node_name
	var us_idx := base.find("_")
	if us_idx > 0:
		base = base.substr(0, us_idx)

	match base:
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
		"Road":
			return "road"
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
		if _build_preview and _build_preview.preview_root:
			var preview_root := _build_preview.preview_root
			if current == preview_root or preview_root.is_ancestor_of(current):
				return null
		if current is Node3D:
			var build_id := _resolve_build_id(current as Node3D)
			if not build_id.is_empty():
				return current as Node3D
		current = current.get_parent()
	return null


func _collect_building_roots(node: Node, out: Array[Node3D]) -> void:
	if node is Node3D:
		var node3d := node as Node3D
		if _build_preview == null or node3d != _build_preview.preview_root:
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


func _find_nearest_road_at_position(world_pos: Vector3, max_dist: float) -> Node3D:
	var world_root := get_node_or_null("/root/World")
	if world_root == null:
		return null
	var candidates: Array[Node3D] = []
	_collect_building_roots(world_root, candidates)
	var best: Node3D = null
	var best_d2 := max_dist * max_dist
	for b in candidates:
		var build_id := _resolve_build_id(b)
		if build_id != "road":
			continue
		var d2 := b.global_position.distance_squared_to(world_pos)
		if d2 <= best_d2:
			best_d2 = d2
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
	var world_manager_node := get_node_or_null("/root/World/WorldManager")
	if absf(direction.y) > 0.0001 and world_manager_node and world_manager_node.has_method("get_road_node_at_cell"):
		var t_ground := -origin.y / direction.y
		if t_ground > 0.0:
			var ground_pos := origin + direction * t_ground
			var road_cell := Vector2i(roundi(ground_pos.x), roundi(ground_pos.z))
			var road_node_variant = world_manager_node.call("get_road_node_at_cell", road_cell)
			var road_node := road_node_variant as Node3D
			if road_node != null and is_instance_valid(road_node):
				var build_id := _resolve_build_id(road_node)
				if build_id == "road":
					var picked_pos := road_node.global_position
					var picked_rot := road_node.rotation.y
					var picked_variant_seed := int(road_node.get_meta("variant_seed", 0))
					var was_player_placed := bool(road_node.get_meta("player_placed", false))
					_cancel_rotate_selection(false)
					_stash_picked_original(road_node, build_id, picked_pos, picked_rot, was_player_placed)
					_build_forced_variant_seed = picked_variant_seed
					_select_building(build_id)
					if _build_preview and _build_preview.preview_root:
						_build_preview.preview_root.global_position = picked_pos
						_build_preview.preview_rotation_deg = rad_to_deg(picked_rot)
						_build_preview.preview_root.rotation.y = picked_rot
						return true
			# 该格标记为道路但没有有效节点：先自愈，避免误删到别的道路
			if world_manager_node.has_method("has_road_cell") and bool(world_manager_node.call("has_road_cell", road_cell)):
				if world_manager_node.has_method("reconcile_road_state"):
					world_manager_node.call("reconcile_road_state")
				return false
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + direction * 500.0)
	ray.collide_with_areas = false
	ray.collide_with_bodies = true
	ray.hit_back_faces = true
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
		# 如果拾取到道路，检查附近是否有更近的道路（防止射线穿过道路边缘击中建筑）
		if building_root != null:
			var build_id := _resolve_build_id(building_root)
			if build_id != "road":
				# 检查是否有道路在射线附近
				var hit_pos: Vector3 = hit.get("position", Vector3.ZERO)
				var nearby_road := _find_nearest_road_at_position(hit_pos, 1.2)
				if nearby_road != null:
					building_root = nearby_road
					if BUILD_PICK_DEBUG:
						print("[BUILD_PICK] overridden to nearby road: ", nearby_road.name)
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
	if build_id == "road":
		var wm := get_node_or_null("/root/World/WorldManager")
		if wm and wm.has_method("get_road_node_at_cell"):
			var exact_cell := Vector2i(roundi(building_root.global_position.x), roundi(building_root.global_position.z))
			var exact_variant = wm.call("get_road_node_at_cell", exact_cell)
			var exact_node := exact_variant as Node3D
			if exact_node != null and is_instance_valid(exact_node):
				building_root = exact_node

	var picked_pos := building_root.global_position
	var picked_rot := building_root.rotation.y
	var picked_variant_seed := int(building_root.get_meta("variant_seed", 0))
	var was_player_placed := bool(building_root.get_meta("player_placed", false))
	_cancel_rotate_selection(false)
	_stash_picked_original(building_root, build_id, picked_pos, picked_rot, was_player_placed)
	_build_forced_variant_seed = picked_variant_seed
	_select_building(build_id)
	
	if _build_preview and _build_preview.preview_root:
		_build_preview.preview_root.global_position = picked_pos
		_build_preview.preview_rotation_deg = rad_to_deg(picked_rot)
		_build_preview.preview_root.rotation.y = picked_rot
		if BUILD_PICK_DEBUG:
			print("[BUILD_PICK] success: picked and converted to preview")
		return true
	if BUILD_PICK_DEBUG:
		print("[BUILD_PICK] fail: preview root missing after select")
	return false


func _highlight_picked_road(road_node: Node3D) -> void:
	if road_node == null:
		return
	var cell := Vector2i(roundi(road_node.global_position.x), roundi(road_node.global_position.z))
	var world_manager_node := get_node_or_null("/root/World/WorldManager")
	if world_manager_node and world_manager_node.has_method("highlight_road_cells"):
		world_manager_node.call("highlight_road_cells", [cell], 1)


func _try_pick_villager() -> bool:
	if not camera:
		print("[VILLAGER] _try_pick_villager failed: no camera")
		return false
	
	var viewport := get_viewport()
	var mouse_pos := viewport.get_mouse_position()
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + direction * 500.0)
	ray.collide_with_areas = false
	ray.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	
	if hit.is_empty():
		print("[VILLAGER] _try_pick_villager: ray hit nothing at mouse=", mouse_pos)
		return false
	
	var collider = hit.get("collider")
	if collider == null:
		print("[VILLAGER] _try_pick_villager: collider is null")
		return false
	
	var villager_root: Node3D = _find_villager_root_from_collider(collider)
	if villager_root == null:
		return false
	
	print("[VILLAGER] _try_pick_villager SUCCESS: picked villager=", villager_root.name)
	_holding_villager_original_pos = villager_root.global_position

	if villager_root.has_method("_on_pickup"):
		villager_root.call("_on_pickup")
	_set_villager_hold_active(villager_root, false)
	
	_holding_villager = villager_root
	_create_villager_preview()
	# 村民直接拾取，不显示任务绑定UI
	# 放置后会自动在道路网络上查找路径
	
	return true


func _find_villager_root_from_collider(collider: Variant) -> Node3D:
	if collider is Node:
		var node := collider as Node
		if node.script and "Villager" in node.script.get_path():
			return node as Node3D
		if node.name.begins_with("Villager"):
			return node as Node3D
		var parent := node.get_parent()
		if parent != null and parent.name.begins_with("Villager"):
			return parent as Node3D
		for child in node.get_children():
			if child.name.begins_with("Villager"):
				return child as Node3D
	return null


func _set_villager_hold_active(villager: Node3D, active: bool) -> void:
	if villager == null:
		return
	villager.set_physics_process(active)
	villager.set_process(active)


func _create_villager_preview() -> void:
	_clear_villager_preview()
	
	_villager_preview = Node3D.new()
	_villager_preview.name = "VillagerPreview"
	var world_root := get_node_or_null("/root/World")
	if world_root:
		world_root.add_child(_villager_preview)
	else:
		get_tree().current_scene.add_child(_villager_preview)
	
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Mesh"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.5
	mesh_inst.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 0.9, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mat
	_villager_preview.add_child(mesh_inst)
	
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.5
	collision.shape = shape
	_villager_preview.add_child(collision)


func _clear_villager_preview() -> void:
	if _villager_preview:
		_villager_preview.queue_free()
		_villager_preview = null


func _update_villager_preview() -> void:
	if _villager_preview == null or _holding_villager == null:
		return
	
	var ground_pos := _mouse_ground_position()
	if ground_pos != Vector3.ZERO:
		_holding_villager.global_position = ground_pos
		_villager_preview.global_position = ground_pos


func _show_villager_task_ui() -> void:
	print("[VILLAGER] _show_villager_task_ui called, _villager_task_ui=", _villager_task_ui, " _holding_villager=", _holding_villager)
	if _villager_task_ui == null or _holding_villager == null:
		print("[VILLAGER] _show_villager_task_ui: early return because null")
		return
	
	var callback := Callable(self, "_on_villager_task_bound")
	print("[VILLAGER] calling open_for_villager")
	_villager_task_ui.open_for_villager(_holding_villager, callback)


func _on_villager_task_bound(start_id: String, end_id: String) -> void:
	if _holding_villager == null:
		return
	
	if _holding_villager.has_method("set_task"):
		_holding_villager.call("set_task", start_id, end_id)
	
	var villager_system: Node = null
	if get_tree() != null:
		villager_system = get_tree().get_first_node_in_group("villager_system")
	if villager_system and villager_system.has_method("bind_task"):
		villager_system.call("bind_task", _holding_villager, start_id, end_id)


func _place_held_villager() -> void:
	if _holding_villager == null:
		_cancel_holding_villager()
		return
	
	var ground_pos := _mouse_ground_position()
	if ground_pos == Vector3.ZERO:
		_cancel_holding_villager()
		return
	
	ground_pos.y = 0.0
	_holding_villager.global_position = ground_pos
	
	if _holding_villager.has_method("_on_placed"):
		_holding_villager.call("_on_placed")
	_set_villager_hold_active(_holding_villager, true)
	_build_mode_has_changes = true
	var world_manager := get_node_or_null("/root/World/WorldManager")
	if world_manager and world_manager.has_method("save_villager_state"):
		world_manager.call("save_villager_state", _holding_villager, false)
	
	var villager_system: Node = null
	if get_tree() != null:
		villager_system = get_tree().get_first_node_in_group("villager_system")
	if villager_system and villager_system.has_method("register_villager"):
		villager_system.call("register_villager", _holding_villager)
	
	_holding_villager = null
	_holding_villager_original_pos = Vector3.ZERO
	_clear_villager_preview()


func _cancel_holding_villager() -> void:
	if _holding_villager != null:
		_holding_villager.global_position = _holding_villager_original_pos
		_holding_villager_original_pos = Vector3.ZERO
		_set_villager_hold_active(_holding_villager, true)
		if _holding_villager.has_method("_on_placed"):
			_holding_villager.call("_on_placed")
		var world_manager := get_node_or_null("/root/World/WorldManager")
		if world_manager and world_manager.has_method("save_villager_state"):
			world_manager.call("save_villager_state", _holding_villager, false)
		_holding_villager = null
	
	_clear_villager_preview()
	
	if _villager_task_ui and _villager_task_ui.visible:
		_villager_task_ui.visible = false


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


func _update_build_preview() -> void:
	if _build_preview == null:
		return
	_build_preview.update_preview(camera, _build_selected_id)


func _try_place_building() -> void:
	if _build_preview == null or _build_preview.preview_root == null:
		return
	_try_place_building_at(_build_preview.preview_root.global_position)


func _try_place_building_at(place_pos: Vector3) -> bool:
	if _build_preview == null or _build_preview.preview_root == null:
		return false
	var type := _building_type_from_id(_build_selected_id)
	if type == -1:
		return false
	var world_manager := get_node_or_null("/root/World/WorldManager")
	if world_manager == null:
		return false
	_build_preview.preview_root.global_position = place_pos
	var placed := _build_preview.try_place(world_manager, _build_selected_id)
	if placed == null:
		return false
	_finalize_picked_original()
	if _build_selected_id == "road":
		_build_road_painted_any = true
		# 检查道路连接并显示指示器
		_check_road_connection_and_highlight(placed.global_position)

	if _build_selected_id == "road":
		if _build_preview and _build_preview.preview_root:
			_build_preview.preview_root.global_position = placed.global_position
		return true

	_cancel_build_selection()
	return true


func _check_road_connection_and_highlight(road_pos: Vector3) -> void:
	var cell := Vector2i(roundi(road_pos.x), roundi(road_pos.z))
	
	var road_network: Node = null
	if get_tree() != null:
		road_network = get_tree().get_first_node_in_group("road_network")
	
	var world_manager_node := get_node_or_null("/root/World/WorldManager")
	if road_network == null or world_manager_node == null:
		return
	
	if not road_network.has_method("get_connected_buildings"):
		return
	
	var connected_raw = road_network.call("get_connected_buildings", cell, world_manager_node)
	if not (connected_raw is Array):
		return
	var connected: Array = connected_raw as Array
	if connected is Array and not connected.is_empty():
		var highlight_cells: Array[Vector2i] = []
		highlight_cells.append(cell)
		
		for conn in connected:
			var conn_dict := conn as Dictionary
			var path := conn_dict.get("path", []) as Array
			for p in path:
				var p_cell := p as Vector2i
				if not highlight_cells.has(p_cell):
					highlight_cells.append(p_cell)
			
			var building := conn_dict.get("building", null) as Node3D
			if building != null:
				_add_building_highlight_to(building)
		
		if world_manager_node.has_method("highlight_road_cells"):
			world_manager_node.call("highlight_road_cells", highlight_cells)


func _add_building_highlight_to(building: Node3D) -> void:
	if building == null:
		return
	var existing := building.get_node_or_null("ConnectionHighlight")
	if existing != null:
		existing.queue_free()
	
	var highlight_script := load("res://scripts/effects/building_highlight.gd")
	if highlight_script == null:
		return
	
	var highlight := Node3D.new()
	highlight.name = "ConnectionHighlight"
	highlight.set_script(highlight_script)
	building.add_child(highlight)


func _grid_cell_from_world(world_pos: Vector3) -> Vector2i:
	return Vector2i(roundi(world_pos.x), roundi(world_pos.z))


func _grid_pos_from_cell(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x), 0.0, float(cell.y))


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

	var destroyed_node: Node = current_target
	if destroyed_node.name == "DestructibleArea" and destroyed_node.get_parent() != null:
		destroyed_node = destroyed_node.get_parent()
	var world_manager := get_node_or_null("/root/World/WorldManager")
	if world_manager and world_manager.has_method("report_destroyed_resource"):
		world_manager.call(
			"report_destroyed_resource",
			current_target.destruct_type,
			destroyed_node.global_position,
			str(destroyed_node.get_meta("entity_id", ""))
		)
	
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
