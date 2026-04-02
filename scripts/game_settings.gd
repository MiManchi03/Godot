extends Node

const SETTINGS_PATH := "user://settings.cfg"

const SETTINGS_VERSION := 7

const DEFAULT_RIGHT_DRAG_YAW_SENSITIVITY := 0.0035
const DEFAULT_CAMERA_HEIGHT := 26.0
const DEFAULT_CAMERA_DISTANCE := 8.5
const DEFAULT_CAMERA_ANGLE_OFFSET := 0.0
const DEFAULT_CAMERA_DRAG_ENABLED := true
const DEFAULT_CAMERA_DRAG_SENSITIVITY := 10.0
const DEFAULT_CAMERA_MOUSE_FOLLOW_ENABLED := true
const DEFAULT_CAMERA_MOUSE_FOLLOW_STRENGTH := 0.45
const DEFAULT_BUILD_DRAG_PAN_SENSITIVITY := 10.0

const RIGHT_DRAG_MIN_SENSITIVITY := 0.001
const RIGHT_DRAG_MAX_SENSITIVITY := 0.02
const CAMERA_HEIGHT_MIN := 1.0
const CAMERA_HEIGHT_MAX := 80.0
const CAMERA_DISTANCE_MIN := 3.0
const CAMERA_DISTANCE_MAX := 20.0
const CAMERA_ANGLE_MIN := 0.0
const CAMERA_ANGLE_MAX := 360.0
const CAMERA_DRAG_SENSITIVITY_MIN := 0.1
const CAMERA_DRAG_SENSITIVITY_MAX := 20.0
const CAMERA_MOUSE_FOLLOW_STRENGTH_MIN := 0.0
const CAMERA_MOUSE_FOLLOW_STRENGTH_MAX := 2.0
const BUILD_DRAG_PAN_SENSITIVITY_MIN := 0.1
const BUILD_DRAG_PAN_SENSITIVITY_MAX := 20.0

var right_drag_yaw_sensitivity: float = DEFAULT_RIGHT_DRAG_YAW_SENSITIVITY
var camera_height: float = DEFAULT_CAMERA_HEIGHT
var camera_distance: float = DEFAULT_CAMERA_DISTANCE
var camera_angle_offset: float = DEFAULT_CAMERA_ANGLE_OFFSET
var camera_drag_enabled: bool = DEFAULT_CAMERA_DRAG_ENABLED
var camera_drag_sensitivity: float = DEFAULT_CAMERA_DRAG_SENSITIVITY
var camera_mouse_follow_enabled: bool = DEFAULT_CAMERA_MOUSE_FOLLOW_ENABLED
var camera_mouse_follow_strength: float = DEFAULT_CAMERA_MOUSE_FOLLOW_STRENGTH
var build_drag_pan_sensitivity: float = DEFAULT_BUILD_DRAG_PAN_SENSITIVITY


func load_settings() -> void:
	var config := ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK:
		right_drag_yaw_sensitivity = DEFAULT_RIGHT_DRAG_YAW_SENSITIVITY
		camera_height = DEFAULT_CAMERA_HEIGHT
		camera_distance = DEFAULT_CAMERA_DISTANCE
		camera_angle_offset = DEFAULT_CAMERA_ANGLE_OFFSET
		camera_drag_enabled = DEFAULT_CAMERA_DRAG_ENABLED
		camera_drag_sensitivity = DEFAULT_CAMERA_DRAG_SENSITIVITY
		camera_mouse_follow_enabled = DEFAULT_CAMERA_MOUSE_FOLLOW_ENABLED
		camera_mouse_follow_strength = DEFAULT_CAMERA_MOUSE_FOLLOW_STRENGTH
		build_drag_pan_sensitivity = DEFAULT_BUILD_DRAG_PAN_SENSITIVITY
		var new_cfg := ConfigFile.new()
		new_cfg.set_value("camera", "right_drag_yaw_sensitivity", right_drag_yaw_sensitivity)
		new_cfg.set_value("camera", "camera_height", camera_height)
		new_cfg.set_value("camera", "camera_distance", camera_distance)
		new_cfg.set_value("camera", "camera_angle_offset", camera_angle_offset)
		new_cfg.set_value("camera", "camera_drag_enabled", camera_drag_enabled)
		new_cfg.set_value("camera", "camera_drag_sensitivity", camera_drag_sensitivity)
		new_cfg.set_value("camera", "camera_mouse_follow_enabled", camera_mouse_follow_enabled)
		new_cfg.set_value("camera", "camera_mouse_follow_strength", camera_mouse_follow_strength)
		new_cfg.set_value("camera", "build_drag_pan_sensitivity", build_drag_pan_sensitivity)
		new_cfg.set_value("meta", "settings_version", SETTINGS_VERSION)
		new_cfg.save(SETTINGS_PATH)
		return

	var legacy_right_drag: float = float(config.get_value("camera", "right_drag_sensitivity", DEFAULT_RIGHT_DRAG_YAW_SENSITIVITY))

	var cfg_right_drag: float = float(config.get_value("camera", "right_drag_yaw_sensitivity", legacy_right_drag))
	var cfg_height: float = float(config.get_value("camera", "camera_height", DEFAULT_CAMERA_HEIGHT))
	var cfg_distance: float = float(config.get_value("camera", "camera_distance", DEFAULT_CAMERA_DISTANCE))
	var cfg_angle: float = float(config.get_value("camera", "camera_angle_offset", DEFAULT_CAMERA_ANGLE_OFFSET))
	var cfg_drag_enabled: bool = bool(config.get_value("camera", "camera_drag_enabled", DEFAULT_CAMERA_DRAG_ENABLED))
	var cfg_drag_sensitivity: float = float(config.get_value("camera", "camera_drag_sensitivity", DEFAULT_CAMERA_DRAG_SENSITIVITY))
	var cfg_mouse_follow_enabled: bool = bool(config.get_value("camera", "camera_mouse_follow_enabled", DEFAULT_CAMERA_MOUSE_FOLLOW_ENABLED))
	var cfg_mouse_follow_strength: float = float(config.get_value("camera", "camera_mouse_follow_strength", DEFAULT_CAMERA_MOUSE_FOLLOW_STRENGTH))
	var cfg_build_drag_pan_sensitivity: float = float(config.get_value("camera", "build_drag_pan_sensitivity", DEFAULT_BUILD_DRAG_PAN_SENSITIVITY))

	var cfg_version: int = int(config.get_value("meta", "settings_version", 0))
	if cfg_version < SETTINGS_VERSION:
		config.set_value("camera", "right_drag_yaw_sensitivity", DEFAULT_RIGHT_DRAG_YAW_SENSITIVITY)
		config.set_value("camera", "camera_height", DEFAULT_CAMERA_HEIGHT)
		config.set_value("camera", "camera_distance", DEFAULT_CAMERA_DISTANCE)
		config.set_value("camera", "camera_angle_offset", DEFAULT_CAMERA_ANGLE_OFFSET)
		config.set_value("camera", "camera_drag_enabled", DEFAULT_CAMERA_DRAG_ENABLED)
		config.set_value("camera", "camera_drag_sensitivity", DEFAULT_CAMERA_DRAG_SENSITIVITY)
		config.set_value("camera", "camera_mouse_follow_enabled", DEFAULT_CAMERA_MOUSE_FOLLOW_ENABLED)
		config.set_value("camera", "camera_mouse_follow_strength", DEFAULT_CAMERA_MOUSE_FOLLOW_STRENGTH)
		config.set_value("camera", "build_drag_pan_sensitivity", DEFAULT_BUILD_DRAG_PAN_SENSITIVITY)
		config.set_value("meta", "settings_version", SETTINGS_VERSION)
		config.save(SETTINGS_PATH)

	right_drag_yaw_sensitivity = clampf(float(config.get_value("camera", "right_drag_yaw_sensitivity", DEFAULT_RIGHT_DRAG_YAW_SENSITIVITY)), RIGHT_DRAG_MIN_SENSITIVITY, RIGHT_DRAG_MAX_SENSITIVITY)
	camera_height = clampf(float(config.get_value("camera", "camera_height", DEFAULT_CAMERA_HEIGHT)), CAMERA_HEIGHT_MIN, CAMERA_HEIGHT_MAX)
	camera_distance = clampf(float(config.get_value("camera", "camera_distance", DEFAULT_CAMERA_DISTANCE)), CAMERA_DISTANCE_MIN, CAMERA_DISTANCE_MAX)
	camera_angle_offset = clampf(float(config.get_value("camera", "camera_angle_offset", DEFAULT_CAMERA_ANGLE_OFFSET)), CAMERA_ANGLE_MIN, CAMERA_ANGLE_MAX)
	camera_drag_enabled = bool(config.get_value("camera", "camera_drag_enabled", DEFAULT_CAMERA_DRAG_ENABLED))
	camera_drag_sensitivity = clampf(float(config.get_value("camera", "camera_drag_sensitivity", DEFAULT_CAMERA_DRAG_SENSITIVITY)), CAMERA_DRAG_SENSITIVITY_MIN, CAMERA_DRAG_SENSITIVITY_MAX)
	camera_mouse_follow_enabled = cfg_mouse_follow_enabled
	camera_mouse_follow_strength = clampf(cfg_mouse_follow_strength, CAMERA_MOUSE_FOLLOW_STRENGTH_MIN, CAMERA_MOUSE_FOLLOW_STRENGTH_MAX)
	build_drag_pan_sensitivity = clampf(cfg_build_drag_pan_sensitivity, BUILD_DRAG_PAN_SENSITIVITY_MIN, BUILD_DRAG_PAN_SENSITIVITY_MAX)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("camera", "right_drag_yaw_sensitivity", right_drag_yaw_sensitivity)
	config.set_value("camera", "camera_height", camera_height)
	config.set_value("camera", "camera_distance", camera_distance)
	config.set_value("camera", "camera_angle_offset", camera_angle_offset)
	config.set_value("camera", "camera_drag_enabled", camera_drag_enabled)
	config.set_value("camera", "camera_drag_sensitivity", camera_drag_sensitivity)
	config.set_value("camera", "camera_mouse_follow_enabled", camera_mouse_follow_enabled)
	config.set_value("camera", "camera_mouse_follow_strength", camera_mouse_follow_strength)
	config.set_value("camera", "build_drag_pan_sensitivity", build_drag_pan_sensitivity)
	config.set_value("meta", "settings_version", SETTINGS_VERSION)
	config.save(SETTINGS_PATH)


func set_right_drag_yaw_sensitivity(value: float) -> void:
	right_drag_yaw_sensitivity = clampf(value, RIGHT_DRAG_MIN_SENSITIVITY, RIGHT_DRAG_MAX_SENSITIVITY)


func set_camera_height(value: float) -> void:
	camera_height = clampf(value, CAMERA_HEIGHT_MIN, CAMERA_HEIGHT_MAX)


func set_camera_distance(value: float) -> void:
	camera_distance = clampf(value, CAMERA_DISTANCE_MIN, CAMERA_DISTANCE_MAX)


func set_camera_angle_offset(value: float) -> void:
	camera_angle_offset = clampf(value, CAMERA_ANGLE_MIN, CAMERA_ANGLE_MAX)


func set_camera_drag_sensitivity(value: float) -> void:
	camera_drag_sensitivity = clampf(value, CAMERA_DRAG_SENSITIVITY_MIN, CAMERA_DRAG_SENSITIVITY_MAX)


func set_camera_mouse_follow_strength(value: float) -> void:
	camera_mouse_follow_strength = clampf(value, CAMERA_MOUSE_FOLLOW_STRENGTH_MIN, CAMERA_MOUSE_FOLLOW_STRENGTH_MAX)


func set_build_drag_pan_sensitivity(value: float) -> void:
	build_drag_pan_sensitivity = clampf(value, BUILD_DRAG_PAN_SENSITIVITY_MIN, BUILD_DRAG_PAN_SENSITIVITY_MAX)


func force_apply_defaults(save: bool = true) -> void:
	right_drag_yaw_sensitivity = DEFAULT_RIGHT_DRAG_YAW_SENSITIVITY
	camera_height = DEFAULT_CAMERA_HEIGHT
	camera_distance = DEFAULT_CAMERA_DISTANCE
	camera_angle_offset = DEFAULT_CAMERA_ANGLE_OFFSET
	camera_drag_sensitivity = DEFAULT_CAMERA_DRAG_SENSITIVITY
	camera_mouse_follow_enabled = DEFAULT_CAMERA_MOUSE_FOLLOW_ENABLED
	camera_mouse_follow_strength = DEFAULT_CAMERA_MOUSE_FOLLOW_STRENGTH
	build_drag_pan_sensitivity = DEFAULT_BUILD_DRAG_PAN_SENSITIVITY
	if save:
		save_settings()


func _ready() -> void:
	load_settings()
