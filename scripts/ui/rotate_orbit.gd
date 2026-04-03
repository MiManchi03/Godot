extends Control
class_name RotateOrbit

@export var radius_px: float = 40.0:
	set(value):
		radius_px = maxf(value, 1.0)
		var new_size := Vector2(radius_px * 2.0, radius_px * 2.0)
		if custom_minimum_size != new_size:
			custom_minimum_size = new_size
		if size != new_size:
			size = new_size
		queue_redraw()

@export var border_width: float = 3.0:
	set(value):
		border_width = maxf(value, 1.0)
		queue_redraw()

@export var border_color: Color = Color(0.26, 0.88, 0.96, 0.78):
	set(value):
		border_color = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center := size * 0.5
	var max_radius := minf(center.x, center.y)
	var draw_radius := maxf(1.0, radius_px - border_width * 0.5)
	if draw_radius > max_radius:
		draw_radius = max_radius
	var points := int(clampf(draw_radius * 0.6, 24.0, 180.0))
	draw_arc(center, draw_radius, 0.0, TAU, points, border_color, border_width, true)
