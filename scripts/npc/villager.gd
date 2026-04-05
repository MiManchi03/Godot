extends CharacterBody3D

const MOVE_SPEED: float = 2.3
const CELL_REACH_EPS: float = 0.08
const QUESTION_SHOW_TIME: float = 0.45
const WORK_TIME: float = 1.5
const UNLOAD_TIME: float = 0.8
const BUILDING_ROAD_SEARCH_RADIUS: int = 5

enum TaskState {
	UNBOUND = 0,
	WAITING = 1,
	TO_START = 2,
	AT_START = 3,
	TO_END = 4,
	AT_END = 5,
	RETURNING = 6,
}

@export var task_start_build_id: String = ""
@export var task_end_build_id: String = ""
@export var carrying_item: bool = false

var _question_timer: float = 0.0
var _task_state: TaskState = TaskState.UNBOUND
var _current_path: Array[Vector2i] = []
var _path_index: int = 0
var _work_timer: float = 0.0
var _last_cell: Vector2i = Vector2i.ZERO

var _hint_sprite: Sprite3D
var _item_sprite: Sprite3D

func _ready() -> void:
	_setup_hints()
	_last_cell = _current_cell()


func _setup_hints() -> void:
	# Question mark sprite
	_hint_sprite = Sprite3D.new()
	_hint_sprite.name = "RoadHint"
	var hint_material := StandardMaterial3D.new()
	hint_material.albedo_color = Color(1.0, 0.9, 0.2, 1.0)
	hint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hint_material.albedo_color.a = 0.9
	hint_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_hint_sprite.material_override = hint_material
	_hint_sprite.position = Vector3(0.0, 2.2, 0.0)
	_hint_sprite.scale = Vector3(0.8, 0.8, 0.8)
	_hint_sprite.visible = false
	add_child(_hint_sprite)
	
	# Item (wood) sprite
	_item_sprite = Sprite3D.new()
	_item_sprite.name = "CarryingItem"
	var item_material := StandardMaterial3D.new()
	item_material.albedo_color = Color(0.55, 0.35, 0.15, 1.0)
	item_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	item_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_item_sprite.material_override = item_material
	_item_sprite.position = Vector3(0.0, 1.5, 0.0)
	_item_sprite.scale = Vector3(0.5, 0.5, 0.5)
	_item_sprite.visible = false
	add_child(_item_sprite)


func set_task(start_id: String, end_id: String) -> void:
	task_start_build_id = start_id
	task_end_build_id = end_id
	if task_start_build_id.is_empty() or task_end_build_id.is_empty():
		_task_state = TaskState.UNBOUND
	else:
		_task_state = TaskState.WAITING
		carrying_item = false


func has_task() -> bool:
	return _task_state != TaskState.UNBOUND and not task_start_build_id.is_empty() and not task_end_build_id.is_empty()


func cancel_task() -> void:
	task_start_build_id = ""
	task_end_build_id = ""
	_task_state = TaskState.UNBOUND
	_current_path.clear()
	_path_index = 0


func get_task_state() -> int:
	return _task_state


func _current_cell() -> Vector2i:
	return Vector2i(roundi(global_position.x), roundi(global_position.z))


func _physics_process(delta: float) -> void:
	_update_hint_visibility(delta)
	
	var road_network: Node = null
	var world_manager: Node = null
	if get_tree() != null:
		road_network = get_tree().get_first_node_in_group("road_network")
		world_manager = get_tree().get_first_node_in_group("world_manager")
	
	match _task_state:
		TaskState.UNBOUND:
			_wander_on_roads(delta, road_network)
		TaskState.WAITING:
			_try_start_task(delta, road_network)
		TaskState.TO_START:
			_follow_path(delta, road_network, TaskState.AT_START)
		TaskState.AT_START:
			_do_work(delta)
		TaskState.TO_END:
			_follow_path(delta, road_network, TaskState.AT_END)
		TaskState.AT_END:
			_unload_item(delta)
		TaskState.RETURNING:
			_follow_path(delta, road_network, TaskState.WAITING)


func _update_hint_visibility(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var dist := global_position.distance_to(cam.global_position)
		var pixel_size := clampf(0.018 + dist * 0.0012, 0.02, 0.05)
		if _hint_sprite:
			_hint_sprite.pixel_size = pixel_size
		if _item_sprite:
			_item_sprite.pixel_size = pixel_size * 0.6
	
	if _question_timer > 0.0:
		_question_timer -= delta
		if _hint_sprite:
			_hint_sprite.visible = true
	else:
		if _hint_sprite and _task_state != TaskState.UNBOUND:
			_hint_sprite.visible = false
	
	if _item_sprite:
		_item_sprite.visible = carrying_item


func _wander_on_roads(delta: float, road_network: Node) -> void:
	var cell := _current_cell()
	
	if road_network and road_network.has_method("has_road_at"):
		if not road_network.call("has_road_at", cell):
			_question_timer = QUESTION_SHOW_TIME
			var back := Vector3(float(_last_cell.x), global_position.y, float(_last_cell.y))
			_move_towards(back, delta)
			return
	
	if _current_path.is_empty() or _path_index >= _current_path.size():
		_generate_wander_path(cell, road_network)
	
	if _current_path.is_empty():
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	_follow_wander_path(delta)


func _generate_wander_path(cell: Vector2i, road_network: Node) -> void:
	if not road_network or not road_network.has_method("get_all_road_cells"):
		_current_path.clear()
		_path_index = 0
		return
	
	var all_roads: Array = road_network.call("get_all_road_cells")
	if all_roads.is_empty():
		_current_path.clear()
		_path_index = 0
		return
	
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash("%d|%d" % [global_position.x, global_position.z]))
	
	var reachable: Array[Vector2i] = []
	for rc in all_roads:
		var rc_cell: Vector2i = rc as Vector2i
		if road_network.call("is_in_network", rc_cell):
			reachable.append(rc_cell)
	
	if reachable.is_empty():
		_current_path.clear()
		_path_index = 0
		return
	
	var target := reachable[rng.randi() % reachable.size()]
	
	if road_network.has_method("find_path"):
		var path_result = road_network.call("find_path", cell, target)
		if path_result is Array:
			_current_path = path_result
			_path_index = 0


func _follow_wander_path(delta: float) -> void:
	if _path_index >= _current_path.size():
		_current_path.clear()
		_path_index = 0
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	var target_cell := _current_path[_path_index]
	var target_pos := Vector3(float(target_cell.x), global_position.y, float(target_cell.y))
	
	_move_towards(target_pos, delta)
	
	var cell := _current_cell()
	if cell == target_cell:
		_path_index += 1


func _try_start_task(delta: float, road_network: Node) -> void:
	if not road_network or not road_network.has_method("is_in_network"):
		_question_timer = QUESTION_SHOW_TIME
		return
	
	var current_cell := _current_cell()
	
	if not road_network.call("is_in_network", current_cell):
		_question_timer = QUESTION_SHOW_TIME
		return
	
	# Find start and end building positions
	var start_pos := _find_building_position(task_start_build_id)
	var end_pos := _find_building_position(task_end_build_id)
	
	if start_pos == Vector3.ZERO or end_pos == Vector3.ZERO:
		_question_timer = QUESTION_SHOW_TIME
		return
	
	var start_pick := _find_nearest_road_cell(start_pos, road_network, BUILDING_ROAD_SEARCH_RADIUS)
	var end_pick := _find_nearest_road_cell(end_pos, road_network, BUILDING_ROAD_SEARCH_RADIUS)
	if not bool(start_pick.get("found", false)) or not bool(end_pick.get("found", false)):
		_question_timer = QUESTION_SHOW_TIME
		return
	
	var start_cell: Vector2i = start_pick.get("cell", Vector2i.ZERO) as Vector2i
	
	# Find path to start
	if road_network.has_method("find_path"):
		var path_result = road_network.call("find_path", current_cell, start_cell)
		if path_result is Array and not path_result.is_empty():
			_current_path = path_result
			_path_index = 0
			_task_state = TaskState.TO_START
		else:
			_question_timer = QUESTION_SHOW_TIME


func _follow_path(delta: float, road_network: Node, next_state: TaskState) -> void:
	if _current_path.is_empty() or _path_index >= _current_path.size():
		_task_state = next_state
		return
	
	var target_cell := _current_path[_path_index]
	var target_pos := Vector3(float(target_cell.x), global_position.y, float(target_cell.y))
	
	_move_towards(target_pos, delta)
	
	var cell := _current_cell()
	if cell == target_cell:
		_path_index += 1
		if _path_index >= _current_path.size():
			_task_state = next_state


func _do_work(delta: float) -> void:
	_work_timer += delta
	if _work_timer >= WORK_TIME:
		_work_timer = 0.0
		carrying_item = true
		# Now go to end
		_task_state = TaskState.TO_END
		_regenerate_path_to_end()


func _unload_item(delta: float) -> void:
	_work_timer += delta
	if _work_timer >= UNLOAD_TIME:
		_work_timer = 0.0
		carrying_item = false
		# Return to start
		_task_state = TaskState.RETURNING
		_regenerate_path_to_start()


func _regenerate_path_to_end() -> void:
	var road_network: Node = null
	if get_tree() != null:
		road_network = get_tree().get_first_node_in_group("road_network")
	if not road_network or not road_network.has_method("find_path"):
		_current_path.clear()
		_path_index = 0
		return
	
	var current_cell := _current_cell()
	var end_pos := _find_building_position(task_end_build_id)
	if end_pos == Vector3.ZERO:
		_current_path.clear()
		_path_index = 0
		return
	
	var end_pick := _find_nearest_road_cell(end_pos, road_network, BUILDING_ROAD_SEARCH_RADIUS)
	if not bool(end_pick.get("found", false)):
		_current_path.clear()
		_path_index = 0
		return
	var end_cell: Vector2i = end_pick.get("cell", Vector2i.ZERO) as Vector2i
	var path_result = road_network.call("find_path", current_cell, end_cell)
	if path_result is Array:
		_current_path = path_result
		_path_index = 0


func _regenerate_path_to_start() -> void:
	var road_network: Node = null
	if get_tree() != null:
		road_network = get_tree().get_first_node_in_group("road_network")
	if not road_network or not road_network.has_method("find_path"):
		_current_path.clear()
		_path_index = 0
		return
	
	var current_cell := _current_cell()
	var start_pos := _find_building_position(task_start_build_id)
	if start_pos == Vector3.ZERO:
		_current_path.clear()
		_path_index = 0
		return
	
	var start_pick := _find_nearest_road_cell(start_pos, road_network, BUILDING_ROAD_SEARCH_RADIUS)
	if not bool(start_pick.get("found", false)):
		_current_path.clear()
		_path_index = 0
		return
	var start_cell: Vector2i = start_pick.get("cell", Vector2i.ZERO) as Vector2i
	var path_result = road_network.call("find_path", current_cell, start_cell)
	if path_result is Array:
		_current_path = path_result
		_path_index = 0


func _find_nearest_road_cell(world_pos: Vector3, road_network: Node, max_radius: int) -> Dictionary:
	if not road_network or not road_network.has_method("has_road_at"):
		return {"found": false, "cell": Vector2i.ZERO}
	var origin := Vector2i(roundi(world_pos.x), roundi(world_pos.z))
	if road_network.call("has_road_at", origin):
		return {"found": true, "cell": origin}
	var best := Vector2i.ZERO
	var best_d2 := 1 << 30
	for dx in range(-max_radius, max_radius + 1):
		for dz in range(-max_radius, max_radius + 1):
			var cell := origin + Vector2i(dx, dz)
			if not road_network.call("has_road_at", cell):
				continue
			var d2 := dx * dx + dz * dz
			if d2 < best_d2:
				best_d2 = d2
				best = cell
	if best_d2 == (1 << 30):
		return {"found": false, "cell": Vector2i.ZERO}
	return {"found": true, "cell": best}


func _find_building_position(build_id: String) -> Vector3:
	if build_id.is_empty():
		return Vector3.ZERO
	
	var world_manager: Node = null
	if get_tree() != null:
		world_manager = get_tree().get_first_node_in_group("world_manager")
	if not world_manager or not world_manager.has_method("find_building_by_id"):
		return Vector3.ZERO
	
	var result = world_manager.call("find_building_by_id", build_id)
	if result is Vector3:
		return result as Vector3
	return Vector3.ZERO


func _move_towards(target: Vector3, delta: float) -> void:
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


func _on_pickup() -> void:
	# Called when picked up by player
	if has_task():
		_task_state = TaskState.WAITING
	else:
		_task_state = TaskState.UNBOUND
	_current_path.clear()
	_path_index = 0
	carrying_item = false
	_work_timer = 0.0


func _on_placed() -> void:
	# Called when placed on ground by player
	_last_cell = _current_cell()
	var road_network: Node = null
	if get_tree() != null:
		road_network = get_tree().get_first_node_in_group("road_network")
	
	# Auto-bind default task if not bound
	if _task_state == TaskState.UNBOUND:
		_try_auto_bind_task()
	
	if has_task():
		_try_start_task(0.0, road_network)
	else:
		_task_state = TaskState.UNBOUND

	var world_manager: Node = null
	if get_tree() != null:
		world_manager = get_tree().get_first_node_in_group("world_manager")
	if world_manager and world_manager.has_method("save_villager_state"):
		world_manager.call("save_villager_state", self)


func on_loaded_from_save() -> void:
	_last_cell = _current_cell()
	_current_path.clear()
	_path_index = 0
	if has_task():
		_task_state = TaskState.WAITING
	else:
		_task_state = TaskState.UNBOUND


func _try_auto_bind_task() -> void:
	# Auto-bind: workshop -> warehouse
	var world_manager: Node = null
	if get_tree() != null:
		world_manager = get_tree().get_first_node_in_group("world_manager")
	
	if not world_manager or not world_manager.has_method("find_building_by_id"):
		return
	
	var workshop_pos: Vector3 = world_manager.call("find_building_by_id", "workshop")
	var warehouse_pos: Vector3 = world_manager.call("find_building_by_id", "warehouse")
	
	if workshop_pos != Vector3.ZERO and warehouse_pos != Vector3.ZERO:
		task_start_build_id = "workshop"
		task_end_build_id = "warehouse"
		_task_state = TaskState.WAITING
		carrying_item = false
		print("[VILLAGER] Auto-bound task: workshop -> warehouse")


func apply_saved_state(task_start_id: String, task_end_id: String, saved_carrying_item: bool, saved_task_state: int) -> void:
	task_start_build_id = task_start_id
	task_end_build_id = task_end_id
	carrying_item = saved_carrying_item
	_task_state = TaskState.UNBOUND
	if saved_task_state >= int(TaskState.UNBOUND) and saved_task_state <= int(TaskState.RETURNING):
		_task_state = saved_task_state
	if task_start_build_id.is_empty() or task_end_build_id.is_empty():
		if _task_state != TaskState.UNBOUND:
			_task_state = TaskState.UNBOUND
	_current_path.clear()
	_path_index = 0
	_work_timer = 0.0
