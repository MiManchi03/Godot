extends Node
# 注意：本脚本注册为自动加载单例 VillageService，不可再声明同名 class_name

signal village_boundaries_changed
signal villager_assigned(villager_id: String, house_id: String)
signal villager_unassigned(villager_id: String, house_id: String)

# 依赖（_ready 绑定）
var _world_manager: Node
var _villager_system: Node
var _world_state: Node

func _ready() -> void:
	add_to_group("village_service")
	_world_manager = get_node_or_null("/root/World/WorldManager")
	_villager_system = get_tree().get_first_node_in_group("villager_system")
	if _world_manager != null:
		_world_state = _world_manager.get("world_state")
	print("[VILLAGE] VillageService initialized")

# ===== 核心查询 =====

func get_villagers_for_house(house_entity_id: String) -> Array[Node3D]:
	var village_id = _get_village_id_of_house(house_entity_id)
	if village_id.is_empty():
		print("[VILLAGE] get_villagers_for_house: no village_id for house ", house_entity_id)
		return []
	if _world_manager == null:
		return []
	var boundary = _world_manager._village_boundaries.get(village_id, [])
	if boundary.is_empty():
		print("[VILLAGE] get_villagers_for_house: empty boundary for village ", village_id)
		return []
	return _filter_villagers_in_boundary(boundary)

func get_house_occupant(house_entity_id: String) -> String:
	if _world_state == null:
		return ""
	return str(_world_state.get_house_occupant(house_entity_id))

func get_villager_house(villager_entity_id: String) -> String:
	if _world_state == null:
		return ""
	return str(_world_state.get_villager_house(villager_entity_id))

func get_villager_by_entity_id(entity_id: String) -> Node3D:
	if _villager_system == null:
		return null
	return _villager_system.get_villager_by_entity_id(entity_id) as Node3D

func get_village_of_house(house_entity_id: String) -> String:
	return _get_village_id_of_house(house_entity_id)

# ===== 业务操作 =====

func assign_villager_to_house(house_entity_id: String, villager_entity_id: String) -> bool:
	if not _can_assign(villager_entity_id, house_entity_id):
		print("[VILLAGE] assign_villager_to_house: can_assign check failed for ", villager_entity_id, " -> ", house_entity_id)
		return false
	var ok: bool = false
	if _world_state != null:
		ok = bool(_world_state.assign_villager_to_house(house_entity_id, villager_entity_id))
	if ok:
		villager_assigned.emit(villager_entity_id, house_entity_id)
		if _world_state != null:
			_world_state.save_dirty(true)
		print("[VILLAGE] Villager assigned: ", villager_entity_id, " -> ", house_entity_id)
	return ok

func remove_house_occupant(house_entity_id: String) -> bool:
	var villager_id := ""
	if _world_state != null:
		villager_id = str(_world_state.get_house_occupant(house_entity_id))
	var ok: bool = false
	if _world_state != null:
		ok = bool(_world_state.remove_house_occupant(house_entity_id))
	if ok and not villager_id.is_empty():
		villager_unassigned.emit(villager_id, house_entity_id)
		if _world_state != null:
			_world_state.save_dirty(true)
		print("[VILLAGE] Villager unassigned: ", villager_id, " from ", house_entity_id)
	return ok

# ===== 内部辅助 =====

func _get_village_id_of_house(house_entity_id: String) -> String:
	if not _world_manager:
		return ""
	return _world_manager._building_to_village.get(house_entity_id, "")

func _filter_villagers_in_boundary(boundary: Array[Vector3]) -> Array[Node3D]:
	var all_v: Array = []
	if _villager_system != null:
		all_v = _villager_system.get_all_villagers()
	var result: Array[Node3D] = []
	for v in all_v:
		if _point_in_polygon(v.global_position, boundary):
			result.append(v)
	print("[VILLAGE] _filter_villagers_in_boundary: total=%d, in_boundary=%d" % [all_v.size(), result.size()])
	return result

func _can_assign(villager_id: String, house_id: String) -> bool:
	# 规则：同村庄、该村民未入住他处
	var v_village = _get_village_id_of_villager(villager_id)
	var h_village = _get_village_id_of_house(house_id)
	if v_village != h_village:
		print("[VILLAGE] _can_assign: village mismatch v_village=", v_village, " h_village=", h_village)
		return false
	var current_house := ""
	if _world_state != null:
		current_house = str(_world_state.get_villager_house(villager_id))
	return current_house.is_empty() or current_house == house_id

func _get_village_id_of_villager(villager_id: String) -> String:
	# 通过已入住关系反推，或位置测试
	var house_id := ""
	if _world_state != null:
		house_id = str(_world_state.get_villager_house(villager_id))
	if not house_id.is_empty():
		return _get_village_id_of_house(house_id)
	# 兜底：位置测试
	var villager = null
	if _villager_system != null:
		villager = _villager_system.get_villager_by_entity_id(villager_id)
	if villager and _world_manager != null:
		for vid in _world_manager._village_boundaries.keys():
			if _point_in_polygon(villager.global_position, _world_manager._village_boundaries[vid]):
				return vid
	return ""

func _point_in_polygon(point: Vector3, polygon: Array[Vector3]) -> bool:
	# 射线法：XZ 平面投影
	var inside = false
	var j = polygon.size() - 1
	for i in range(polygon.size()):
		var pi = polygon[i]
		var pj = polygon[j]
		if ((pi.z > point.z) != (pj.z > point.z)) and (point.x < (pj.x - pi.x) * (point.z - pi.z) / (pj.z - pi.z) + pi.x):
			inside = not inside
		j = i
	return inside
