extends Node

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

var _road_cells: Dictionary = {}       # Dictionary[Vector2i, bool]
var _adjacency: Dictionary = {}         # Dictionary[Vector2i, Array[Vector2i]]

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
	
	road_network_changed.emit()


func is_in_network(cell: Vector2i) -> bool:
	if not _road_cells.has(cell):
		return false
	return _has_path_to_any_connected(cell)


func _has_path_to_any_connected(start: Vector2i) -> bool:
	if _adjacency.is_empty() or _adjacency.get(start, []).is_empty():
		return false
	
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var neighbors: Array[Vector2i] = _adjacency.get(current, [])
		
		for n in neighbors:
			if not visited.has(n):
				visited[n] = true
				queue.append(n)
	
	return visited.size() > 1


func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not _road_cells.has(from) or not _road_cells.has(to):
		return []
	
	if from == to:
		return [from]
	
	var open_set: Array[Vector2i] = [from]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {from: 0.0}
	var f_score: Dictionary = {from: _heuristic(from, to)}
	
	while not open_set.is_empty():
		open_set.sort_custom(func(a, b): return f_score.get(a, INF) < f_score.get(b, INF))
		var current: Vector2i = open_set.pop_front()
		
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
				
				if not open_set.has(neighbor):
					open_set.append(neighbor)
	
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
	road_network_changed.emit()


func get_road_count() -> int:
	return _road_cells.size()
