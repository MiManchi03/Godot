extends Node

var visible: bool = false

func _ready() -> void:
	# Default: hide/capture cursor on ready
	hide()

func show() -> void:
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func hide() -> void:
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func toggle() -> void:
	if visible:
		hide()
	else:
		show()

func is_visible() -> bool:
	return visible
