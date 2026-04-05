extends Node

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

var _road_cells: Dictionary = {}       # Dictionary[Vector2i, bool]
var _adjacency: Dictionary = {}         # Dictionary[Vector2i, Array[Vector2i]]
var _component_id_by_cell: Dictionary = {} # Dictionary[Vector2i, int]
var _component_size: Dictionary = {}    # Dictionary[int, int]
var _components_dirty: bool = true

signal road_network_changed()

func _ready() -> void:
	add_to_group("road_network")
	print("=== ROAD NETWORK INITIALIZED ===")


func add_road(cell: Vector2i) -> void:
	if _road_cells.has(cell):
		return
	
	_road_cells[cell] = true
	_update_adjacency_for_cell(cell)
	
	for d in DIRECTIONS:
		var neighbor: Vector2i = cell + d
		if _road_cells.has(neighbor):
			_update_adjacency_for_cell(neighbor)
	_components_dirty = true
	
	road_network_changed.emit()


func remove_road(cell: Vector2i) -> void:
	if not _road_cells.has(cell):
		return
	
	_road_cells.erase(cell)
	_adjacency.erase(cell)
	
	for d in DIRECTIONS:
		var neighbor: Vector2i = cell + d
		if _road_cells.has(neighbor):
			_update_adjacency_for_cell(neighbor)
	_components_dirty = true
	
	road_network_changed.emit()


func is_in_network(cell: Vector2i) -> bool:
	if not _road_cells.has(cell):
		return false
	_ensure_components()
	var cid := int(_component_id_by_cell.get(cell, -1))
	if cid == -1:
		return false
	return int(_component_size.get(cid, 0)) > 1


func _has_path_to_any_connected(start: Vector2i) -> bool:
	_ensure_components()
	var cid := int(_component_id_by_cell.get(start, -1))
	if cid == -1:
		return false
	return int(_component_size.get(cid, 0)) > 1


func _ensure_components() -> void:
	if not _components_dirty:
		return
	_component_id_by_cell.clear()
	_component_size.clear()
	var next_component_id := 1
	for key in _road_cells.keys():
		var start := key as Vector2i
		if _component_id_by_cell.has(start):
			continue
		var queue: Array[Vector2i] = [start]
		_component_id_by_cell[start] = next_component_id
		while not queue.is_empty():
			var current: Vector2i = queue.pop_front()
			_component_size[next_component_id] = int(_component_size.get(next_component_id, 0)) + 1
			var neighbors: Array[Vector2i] = _adjacency.get(current, [])
			for n in neighbors:
				if not _component_id_by_cell.has(n):
					_component_id_by_cell[n] = next_component_id
					queue.append(n)
		next_component_id += 1
	_components_dirty = false


func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not _road_cells.has(from) or not _road_cells.has(to):
		return []
	
	if from == to:
		return [from]

	_ensure_components()
	var from_cid := int(_component_id_by_cell.get(from, -1))
	if from_cid == -1 or from_cid != int(_component_id_by_cell.get(to, -2)):
		return []
	
	var open_set: Array[Vector2i] = [from]
	var in_open: Dictionary = {from: true}
	var came_from: Dictionary = {}
	var g_score: Dictionary = {from: 0.0}
	var f_score: Dictionary = {from: _heuristic(from, to)}
	
	while not open_set.is_empty():
		var best_index := 0
		var best_cell := open_set[0]
		var best_f := float(f_score.get(best_cell, INF))
		for i in range(1, open_set.size()):
			var c := open_set[i]
			var f := float(f_score.get(c, INF))
			if f < best_f:
				best_f = f
				best_cell = c
				best_index = i
		var current: Vector2i = open_set[best_index]
		open_set.remove_at(best_index)
		in_open.erase(current)
		
		if current == to:
			return _reconstruct_path(came_from, current)
		
		var neighbors: Array[Vector2i] = _adjacency.get(current, [])
		for neighbor in neighbors:
			var current_g: float = float(g_score.get(current, INF))
			var tentative_g: float = current_g + 1.0
			var neighbor_g: float = float(g_score.get(neighbor, INF))
			
			if tentative_g < neighbor_g:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic(neighbor, to)
				
				if not in_open.has(neighbor):
					open_set.append(neighbor)
					in_open[neighbor] = true
	
	return []


func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return float((a - b).length())


func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path


func _update_adjacency_for_cell(cell: Vector2i) -> void:
	var neighbors: Array[Vector2i] = []
	for d in DIRECTIONS:
		var neighbor: Vector2i = cell + d
		if _road_cells.has(neighbor):
			neighbors.append(neighbor)
	_adjacency[cell] = neighbors


func get_all_road_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _road_cells.keys():
		result.append(cell as Vector2i)
	return result


func has_road_at(cell: Vector2i) -> bool:
	return _road_cells.has(cell)


func clear_all() -> void:
	_road_cells.clear()
	_adjacency.clear()
	_component_id_by_cell.clear()
	_component_size.clear()
	_components_dirty = true
	road_network_changed.emit()


func get_road_count() -> int:
	return _road_cells.size()
