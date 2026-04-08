extends Node

## 道路渲染器 - 使用GridMap统一管理道路视觉
## 性能优化：所有道路合并为1-2个draw call

var _grid_map: GridMap = null
var _mesh_library: MeshLibrary = null
var _highlight_cells: Dictionary = {}  # cell -> {type, timer}
var _highlight_timer: float = 0.0

const HIGHLIGHT_DURATION: float = 2.0


func _ready() -> void:
	_setup_grid_map()
	_create_mesh_library()


func _process(delta: float) -> void:
	_update_highlights(delta)


func _setup_grid_map() -> void:
	_grid_map = GridMap.new()
	_grid_map.name = "RoadGridMap"
	_grid_map.cell_size = Vector3(1.0, 1.0, 1.0)
	_grid_map.set("cell_center_x", false)
	_grid_map.set("cell_center_y", false)
	_grid_map.set("cell_center_z", false)
	add_child(_grid_map)


func _create_mesh_library() -> void:
	_mesh_library = MeshLibrary.new()
	
	# Item 0: 普通道路
	_create_road_mesh_item(0, Color(0.52, 0.50, 0.46), Color(0.76, 0.72, 0.58))
	
	# Item 1: 蓝色高亮道路
	_create_highlight_mesh_item(1, Color(0.3, 0.5, 1.0, 0.6))
	
	# Item 2: 蓝色路径高亮（更亮）
	_create_highlight_mesh_item(2, Color(0.4, 0.6, 1.0, 0.8))
	
	# Item 3: 红色删除预警
	_create_highlight_mesh_item(3, Color(1.0, 0.2, 0.2, 0.75))
	
	_grid_map.mesh_library = _mesh_library


func _create_road_mesh_item(item_id: int, base_color: Color, lane_color: Color) -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var colors: PackedColorArray = []
	var uvs: PackedVector2Array = []
	var indices: PackedInt32Array = []
	
	# 底座 (真正贴地)
	_add_box_face(vertices, normals, colors, uvs, indices,
		Vector3(-0.5, 0.001, -0.5), Vector3(0.5, 0.001, 0.5), base_color, Vector3.UP)
	
	# 车道 (轻微抬高避免z-fighting)
	var lane_half_w := 0.14
	var lane_half_d := 0.43
	_add_box_face(vertices, normals, colors, uvs, indices,
		Vector3(-lane_half_w, 0.003, -lane_half_d), Vector3(lane_half_w, 0.003, lane_half_d), lane_color, Vector3.UP)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.metallic = 0.0
	mesh.surface_set_material(0, mat)
	
	_mesh_library.create_item(item_id)
	_mesh_library.set_item_mesh(item_id, mesh)


func _create_highlight_mesh_item(item_id: int, highlight_color: Color) -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var colors: PackedColorArray = []
	var uvs: PackedVector2Array = []
	var indices: PackedInt32Array = []
	
	# 底座 (真正贴地)
	_add_box_face(vertices, normals, colors, uvs, indices,
		Vector3(-0.5, 0.001, -0.5), Vector3(0.5, 0.001, 0.5), Color(0.52, 0.50, 0.46), Vector3.UP)
	
	# 车道（高亮色）
	var lane_half_w := 0.14
	var lane_half_d := 0.43
	_add_box_face(vertices, normals, colors, uvs, indices,
		Vector3(-lane_half_w, 0.003, -lane_half_d), Vector3(lane_half_w, 0.003, lane_half_d), highlight_color, Vector3.UP)
	
	# 光晕层
	_add_box_face(vertices, normals, colors, uvs, indices,
		Vector3(-0.475, 0.005, -0.475), Vector3(0.475, 0.005, 0.475), 
		Color(highlight_color.r * 0.7, highlight_color.g * 0.7, highlight_color.b * 0.7, highlight_color.a * 0.4), Vector3.UP)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.5
	mat.metallic = 0.1
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, mat)
	
	_mesh_library.create_item(item_id)
	_mesh_library.set_item_mesh(item_id, mesh)


func _add_box_face(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	min_pos: Vector3,
	max_pos: Vector3,
	color: Color,
	normal: Vector3
) -> void:
	var start_idx := vertices.size()
	
	# 4个顶点
	vertices.append(Vector3(min_pos.x, min_pos.y, min_pos.z))
	vertices.append(Vector3(max_pos.x, min_pos.y, min_pos.z))
	vertices.append(Vector3(max_pos.x, min_pos.y, max_pos.z))
	vertices.append(Vector3(min_pos.x, min_pos.y, max_pos.z))
	
	for i in range(4):
		normals.append(normal)
		colors.append(color)
		uvs.append(Vector2(0, 0))
	
	# 2个三角形
	indices.append(start_idx)
	indices.append(start_idx + 1)
	indices.append(start_idx + 2)
	indices.append(start_idx)
	indices.append(start_idx + 2)
	indices.append(start_idx + 3)


func set_road_cell(cell: Vector2i, item_type: int = 0) -> void:
	if _grid_map == null:
		return
	var grid_pos := Vector3i(cell.x, 0, cell.y)
	_grid_map.set_cell_item(grid_pos, item_type)


func remove_road_cell(cell: Vector2i) -> void:
	if _grid_map == null:
		return
	var grid_pos := Vector3i(cell.x, 0, cell.y)
	_grid_map.set_cell_item(grid_pos, -1)
	_highlight_cells.erase(cell)


func highlight_cells(cells: Array, item_type: int = 1, duration: float = HIGHLIGHT_DURATION) -> void:
	for cell_variant in cells:
		if not (cell_variant is Vector2i):
			continue
		var cell := cell_variant as Vector2i
		_highlight_cells[cell] = {"type": item_type, "timer": duration}
		set_road_cell(cell, item_type)


func clear_highlights() -> void:
	var cells_to_reset: Array[Vector2i] = []
	for cell in _highlight_cells.keys():
		cells_to_reset.append(cell)
		set_road_cell(cell, 0)  # 重置为普通道路
	_highlight_cells.clear()


func clear_all_cells() -> void:
	if _grid_map == null:
		return
	for cell in _grid_map.get_used_cells():
		_grid_map.set_cell_item(cell, -1)
	_highlight_cells.clear()


func _update_highlights(delta: float) -> void:
	if _highlight_cells.is_empty():
		return
	
	_highlight_timer += delta
	
	var cells_to_remove: Array[Vector2i] = []
	for cell in _highlight_cells.keys():
		var data: Dictionary = _highlight_cells[cell]
		data["timer"] -= delta
		if data["timer"] <= 0.0:
			cells_to_remove.append(cell)
	
	for cell in cells_to_remove:
		_highlight_cells.erase(cell)
		set_road_cell(cell, 0)  # 重置为普通道路
