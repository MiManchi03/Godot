extends Node

var _villagers: Array[Node] = []
var _villager_by_node: Dictionary = {}

signal villager_registered(villager: Node)
signal villager_unregistered(villager: Node)
signal task_bound(villager: Node, start_id: String, end_id: String)

const BUILDING_TYPES := [
	"house", "workshop", "warehouse", "market", "well", 
	"campfire", "fencepost", "road", "farm", "tower", "barrack"
]

func _ready() -> void:
	add_to_group("villager_system")
	print("=== VILLAGER SYSTEM INITIALIZED ===")


func register_villager(villager: Node) -> void:
	if not is_instance_valid(villager):
		return
	if _villager_by_node.has(villager.get_instance_id()):
		return
	
	# 基于 entity_id 的去重，防止多个 chunk 加载重复
	var entity_id := str(villager.get_meta("entity_id", ""))
	if not entity_id.is_empty():
		for existing in _villagers:
			if str(existing.get_meta("entity_id", "")) == entity_id:
				return
	
	_villagers.append(villager)
	_villager_by_node[villager.get_instance_id()] = villager
	villager_registered.emit(villager)


func unregister_villager(villager: Node) -> void:
	if not _villager_by_node.has(villager.get_instance_id()):
		return
	
	_villagers.erase(villager)
	_villager_by_node.erase(villager.get_instance_id())
	villager_unregistered.emit(villager)


func bind_task(villager: Node, start_id: String, end_id: String) -> bool:
	if not _villager_by_node.has(villager.get_instance_id()):
		return false
	
	if not _is_valid_building_id(start_id) or not _is_valid_building_id(end_id):
		push_warning("[VillagerSystem] Invalid building IDs: ", start_id, " -> ", end_id)
		return false
	
	if villager.has_method("set_task"):
		villager.call("set_task", start_id, end_id)
		task_bound.emit(villager, start_id, end_id)
		return true
	
	return false


func _is_valid_building_id(build_id: String) -> bool:
	return BUILDING_TYPES.has(build_id)


func get_all_villagers() -> Array[Node]:
	return _villagers.duplicate()


func get_villager_count() -> int:
	return _villagers.size()


func get_villagers_with_task() -> Array[Node]:
	var result: Array[Node] = []
	for v in _villagers:
		if v.has_method("has_task") and v.call("has_task"):
			result.append(v)
	return result


func get_villagers_without_task() -> Array[Node]:
	var result: Array[Node] = []
	for v in _villagers:
		if v.has_method("has_task") and not v.call("has_task"):
			result.append(v)
	return result
