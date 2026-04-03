extends Control
class_name RotateGizmo

var orbit: RotateOrbit
var knob: PanelContainer
var knob_style: StyleBoxFlat
var knob_size: Vector2 = Vector2(26.0, 26.0)
var knob_rect: Rect2 = Rect2()
var border_width: float = 3.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_setup_nodes()


func configure(size: Vector2, orbit_border_width: float, orbit_color: Color, knob_color: Color, knob_border_color: Color) -> void:
	knob_size = size
	border_width = maxf(orbit_border_width, 1.0)
	if orbit:
		orbit.border_width = border_width
		orbit.border_color = orbit_color
	if knob_style:
		knob_style.bg_color = knob_color
		knob_style.border_color = knob_border_color


func update_gizmo(screen_center: Vector2, orbit_radius: float, angle: float) -> void:
	visible = true
	var orbit_size := Vector2(orbit_radius * 2.0, orbit_radius * 2.0)
	var orbit_pos := screen_center - orbit_size * 0.5
	if orbit:
		orbit.radius_px = orbit_radius
		orbit.global_position = orbit_pos
	var knob_radius := maxf(1.0, orbit_radius - border_width * 0.5)
	var knob_center := screen_center + Vector2(sin(angle), cos(angle)) * knob_radius
	var knob_pos := knob_center - knob_size * 0.5
	knob.global_position = knob_pos
	knob_rect = Rect2(knob_pos, knob_size)


func get_knob_rect() -> Rect2:
	return knob_rect


func _setup_nodes() -> void:
	if orbit == null:
		orbit = RotateOrbit.new()
		add_child(orbit)
	if knob == null:
		knob = PanelContainer.new()
		knob_style = StyleBoxFlat.new()
		knob_style.bg_color = Color(0.45, 0.95, 1.0, 0.98)
		knob_style.border_width_left = 2
		knob_style.border_width_top = 2
		knob_style.border_width_right = 2
		knob_style.border_width_bottom = 2
		knob_style.border_color = Color(0.08, 0.26, 0.3, 0.92)
		knob_style.set_corner_radius_all(int(round(knob_size.x * 0.5)))
		knob.add_theme_stylebox_override("panel", knob_style)
		knob.custom_minimum_size = knob_size
		add_child(knob)
