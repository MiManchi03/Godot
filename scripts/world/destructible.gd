extends Area3D
class_name Destructible

@export var destruct_type: String = "tree"
@export var destroy_time: float = 4.0
@export var drops: Dictionary = {}

var current_progress: float = 0.0
var is_being_destroyed: bool = false

signal destroyed(drops_dict: Dictionary)


func get_destroy_time() -> float:
	return destroy_time


func get_drops() -> Dictionary:
	return drops.duplicate(true)


func start_destruction() -> void:
	is_being_destroyed = true
	current_progress = 0.0


func update_destruction(delta: float) -> float:
	if not is_being_destroyed:
		return 0.0
	
	if destroy_time <= 0.0:
		return 1.0
	
	current_progress += delta
	return current_progress / destroy_time


func complete_destruction() -> void:
	is_being_destroyed = false
	destroyed.emit(get_drops())
	if name == "DestructibleArea" and get_parent() != null:
		get_parent().queue_free()
	else:
		queue_free()


func cancel_destruction() -> void:
	is_being_destroyed = false
	current_progress = 0.0


func get_progress() -> float:
	if destroy_time <= 0.0:
		return 1.0
	return current_progress / destroy_time
