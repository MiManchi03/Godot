extends CharacterBody3D

@export var road_cells: Array[Vector2i] = []
@export var building_targets: Array[Vector3] = []

const MOVE_SPEED: float = 2.3
const CELL_REACH_EPS: float = 0.08
const QUESTION_SHOW_TIME: float = 0.45

var _road_lookup: Dictionary = {}
var _target_cell: Vector2i = Vector2i.ZERO
var _last_cell: Vector2i = Vector2i.ZERO
var _question_timer: float = 0.0


func _ready() -> void:
	for c in road_cells:
		_road_lookup[c] = true
	_last_cell = _current_cell()
	if _road_lookup.has(_last_cell):
		_target_cell = _pick_next_cell(_last_cell, _last_cell)
	else:
		_target_cell = _nearest_road_cell(_last_cell)


func _physics_process(delta: float) -> void:
	var hint := get_node_or_null("RoadHint") as Label3D
	if hint:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var dist := global_position.distance_to(cam.global_position)
			hint.pixel_size = clampf(0.022 + dist * 0.0016, 0.024, 0.065)
	if _question_timer > 0.0:
		_question_timer -= delta
		if hint:
			hint.visible = true
	else:
		if hint:
			hint.visible = false

	if _road_lookup.is_empty():
		velocity = Vector3.ZERO
		return

	var cell := _current_cell()
	if not _road_lookup.has(cell):
		_question_timer = QUESTION_SHOW_TIME
		var back := Vector3(float(_last_cell.x), global_position.y, float(_last_cell.y))
		_move_towards(back)
		return

	if cell == _target_cell:
		var next := _pick_next_cell(cell, _last_cell)
		if next == cell:
			if not _has_adjacent_building(cell):
				_question_timer = QUESTION_SHOW_TIME
			next = _last_cell
		_last_cell = cell
		_target_cell = next

	_move_towards(Vector3(float(_target_cell.x), global_position.y, float(_target_cell.y)))


func _move_towards(target: Vector3) -> void:
	var dir := target - global_position
	dir.y = 0.0
	if dir.length() <= CELL_REACH_EPS:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	dir = dir.normalized()
	velocity = dir * MOVE_SPEED
	if dir.length_squared() > 0.0001:
		var yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, yaw, 0.15)
	move_and_slide()


func _current_cell() -> Vector2i:
	return Vector2i(roundi(global_position.x), roundi(global_position.z))


func _pick_next_cell(current: Vector2i, previous: Vector2i) -> Vector2i:
	var options: Array[Vector2i] = []
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var n: Vector2i = current + d
		if _road_lookup.has(n):
			options.append(n)
	if options.is_empty():
		return current
	if options.size() == 1:
		return options[0]
	var forward_options: Array[Vector2i] = []
	for c in options:
		if c != previous:
			forward_options.append(c)
	if forward_options.is_empty():
		return options[randi() % options.size()]
	return forward_options[randi() % forward_options.size()]


func _nearest_road_cell(from_cell: Vector2i) -> Vector2i:
	if _road_lookup.is_empty():
		return from_cell
	var best := from_cell
	var best_d2 := INF
	for k in _road_lookup.keys():
		var c := k as Vector2i
		var d2 := float((c - from_cell).length_squared())
		if d2 < best_d2:
			best_d2 = d2
			best = c
	return best


func _has_adjacent_building(cell: Vector2i) -> bool:
	for p in building_targets:
		var bc := Vector2i(roundi(p.x), roundi(p.z))
		if absi(bc.x - cell.x) + absi(bc.y - cell.y) <= 1:
			return true
	return false
