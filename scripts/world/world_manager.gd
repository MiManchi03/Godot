extends Node3D

const CHUNK_SIZE := 32
const LOAD_RADIUS := 5
const UNLOAD_RADIUS := 7

@export var world_seed: int = 91357

var biome_generator: BiomeGenerator
var resource_spawner: ResourceSpawner
var village_generator: VillageGenerator
var player_buildings: PlayerBuildings

var player: CharacterBody3D
var loaded_chunks: Dictionary = {}


func _ready() -> void:
	biome_generator = BiomeGenerator.new(world_seed)
	resource_spawner = ResourceSpawner.new(world_seed + 1000)
	village_generator = VillageGenerator.new(world_seed + 2000)
	player_buildings = PlayerBuildings.new(world_seed, CHUNK_SIZE)

	player = get_node_or_null("../Player")
	if player == null:
		push_error("WorldManager requires a sibling node named 'Player'.")
		return

	_update_chunks_around_player()


func _process(_delta: float) -> void:
	if player == null:
		return
	_update_chunks_around_player()


func _update_chunks_around_player() -> void:
	var player_chunk := _world_to_chunk(player.global_position)

	for x in range(player_chunk.x - LOAD_RADIUS, player_chunk.x + LOAD_RADIUS + 1):
		for z in range(player_chunk.y - LOAD_RADIUS, player_chunk.y + LOAD_RADIUS + 1):
			var coord := Vector2i(x, z)
			if not loaded_chunks.has(coord):
				_create_chunk(coord)

	var to_remove: Array[Vector2i] = []
	for coord in loaded_chunks.keys():
		var chunk_coord: Vector2i = coord
		var dx: int = absi(chunk_coord.x - player_chunk.x)
		var dz: int = absi(chunk_coord.y - player_chunk.y)
		if dx > UNLOAD_RADIUS or dz > UNLOAD_RADIUS:
			to_remove.append(chunk_coord)

	for coord in to_remove:
		_remove_chunk(coord)


func _create_chunk(coord: Vector2i) -> void:
	var chunk_root := Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk_root.position = Vector3(coord.x * CHUNK_SIZE, 0.0, coord.y * CHUNK_SIZE)
	add_child(chunk_root)

	var biome := biome_generator.get_biome(chunk_root.position.x, chunk_root.position.z)

	var ground := _build_ground_mesh(biome)
	chunk_root.add_child(ground)

	resource_spawner.populate_chunk(chunk_root, coord, CHUNK_SIZE, biome)
	village_generator.try_spawn_village(chunk_root, coord, CHUNK_SIZE, biome)
	loaded_chunks[coord] = chunk_root
	_apply_player_buildings_for_chunk(coord, chunk_root)


func _remove_chunk(coord: Vector2i) -> void:
	if not loaded_chunks.has(coord):
		return

	var chunk: Node3D = loaded_chunks[coord]
	loaded_chunks.erase(coord)
	chunk.queue_free()


func _build_ground_mesh(biome: BiomeGenerator.Biome) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 1

	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(CHUNK_SIZE, CHUNK_SIZE)
	plane.subdivide_depth = 1
	plane.subdivide_width = 1
	mesh_instance.mesh = plane
	mesh_instance.material_override = _ground_material(biome_generator.biome_color(biome))
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(CHUNK_SIZE, 0.2, CHUNK_SIZE)
	collision.shape = shape
	collision.position = Vector3(0.0, -0.1, 0.0)
	body.add_child(collision)

	return body


func _ground_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = 0.0
	return material


func _world_to_chunk(pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(pos.x / float(CHUNK_SIZE)),
		floori(pos.z / float(CHUNK_SIZE))
	)


func add_player_building(build_id: String, world_pos: Vector3, rotation_y: float, node_name: String = "", variant_seed: int = 0) -> void:
	if player_buildings == null:
		return
	player_buildings.add_building(build_id, world_pos, rotation_y, node_name, variant_seed)


func spawn_player_building(build_id: String, world_pos: Vector3, rotation_y: float, variant_seed: int, node_name: String = "") -> Node3D:
	var building_type := _building_type_from_id(build_id)
	if building_type == -1:
		return null
	var seed := variant_seed
	if seed == 0:
		seed = int(hash("%s|%.3f|%.3f|%.3f" % [build_id, world_pos.x, world_pos.y, world_pos.z]))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var instance := village_generator._create_building_variant(rng, building_type)
	if instance == null:
		return null
	instance.set_meta("build_id", build_id)
	instance.set_meta("player_placed", true)
	instance.set_meta("variant_seed", seed)
	if not node_name.is_empty():
		instance.name = node_name
	var coord := _world_to_chunk(world_pos)
	if loaded_chunks.has(coord):
		(loaded_chunks[coord] as Node3D).add_child(instance)
	else:
		add_child(instance)
	instance.global_position = world_pos
	instance.rotation.y = rotation_y
	return instance


func on_pick_existing_building(build_id: String, world_pos: Vector3, node_name: String, was_player_placed: bool) -> void:
	if player_buildings == null:
		return
	if was_player_placed:
		player_buildings.remove_added_near(build_id, world_pos, 1.8)
		return
	player_buildings.add_removed_original(build_id, world_pos, node_name)


func save_player_buildings() -> void:
	if player_buildings == null:
		return
	player_buildings.save_dirty()


func _apply_player_buildings_for_chunk(coord: Vector2i, chunk_root: Node3D) -> void:
	if player_buildings == null:
		return
	var chunk_data := player_buildings.get_chunk_data(coord)
	var removed := chunk_data.get("removed", []) as Array
	if not removed.is_empty():
		_apply_removed_originals(chunk_root, removed)

	var added := chunk_data.get("added", []) as Array
	for entry_variant in added:
		var entry := entry_variant as Dictionary
		var build_id := str(entry.get("build_id", ""))
		if build_id.is_empty():
			continue
		var pos := _entry_position(entry)
		var variant_seed := int(entry.get("variant_seed", 0))
		if variant_seed == 0:
			variant_seed = _stable_variant_seed(entry)
		var saved_name := str(entry.get("name", ""))
		var instance := spawn_player_building(build_id, pos, float(entry.get("rotation_y", 0.0)), variant_seed, saved_name)
		if instance == null:
			continue


func _apply_removed_originals(chunk_root: Node3D, removed: Array) -> void:
	for rem_variant in removed:
		var rem := rem_variant as Dictionary
		var rem_id := str(rem.get("build_id", ""))
		if rem_id.is_empty():
			continue
		var rem_pos := _entry_position(rem)
		var target := _find_matching_original(chunk_root, rem_id, rem_pos, 1.8)
		if target != null:
			target.queue_free()


func _find_matching_original(root: Node, build_id: String, world_pos: Vector3, radius: float) -> Node3D:
	var candidates: Array[Node3D] = []
	_collect_building_candidates(root, candidates)
	var best: Node3D = null
	var best_d2 := radius * radius
	for c in candidates:
		if bool(c.get_meta("player_placed", false)):
			continue
		if _resolve_build_id(c) != build_id:
			continue
		var d2 := c.global_position.distance_squared_to(world_pos)
		if d2 <= best_d2:
			best_d2 = d2
			best = c
	return best


func _collect_building_candidates(node: Node, out: Array[Node3D]) -> void:
	if node is Node3D:
		var n3d := node as Node3D
		var build_id := _resolve_build_id(n3d)
		if not build_id.is_empty():
			out.append(n3d)
	for child in node.get_children():
		_collect_building_candidates(child, out)


func _resolve_build_id(node3d: Node3D) -> String:
	if node3d.has_meta("build_id"):
		return str(node3d.get_meta("build_id"))
	return _build_id_from_node_name(node3d.name)


func _build_id_from_node_name(node_name: String) -> String:
	var lower := node_name.to_lower()
	if lower.find("warehouse") != -1:
		return "warehouse"
	if lower.find("house") != -1:
		return "house"
	if lower.find("workshop") != -1:
		return "workshop"
	if lower.find("market") != -1:
		return "market"
	if lower.find("well") != -1:
		return "well"
	if lower.find("campfire") != -1:
		return "campfire"
	if lower.find("fencepost") != -1 or lower.find("fence_post") != -1 or lower.find("fence") != -1:
		return "fencepost"
	if lower.find("farm") != -1:
		return "farm"
	if lower.find("tower") != -1:
		return "tower"
	if lower.find("barrack") != -1:
		return "barrack"
	return ""


func _building_type_from_id(build_id: String) -> int:
	match build_id:
		"house":
			return VillageGenerator.BuildingType.HOUSE
		"workshop":
			return VillageGenerator.BuildingType.WORKSHOP
		"warehouse":
			return VillageGenerator.BuildingType.WAREHOUSE
		"market":
			return VillageGenerator.BuildingType.MARKET
		"well":
			return VillageGenerator.BuildingType.WELL
		"campfire":
			return VillageGenerator.BuildingType.CAMPFIRE
		"fencepost":
			return VillageGenerator.BuildingType.FENCE_POST
		"farm":
			return VillageGenerator.BuildingType.FARM
		"tower":
			return VillageGenerator.BuildingType.TOWER
		"barrack":
			return VillageGenerator.BuildingType.BARRACK
		_:
			return -1


func _entry_position(entry: Dictionary) -> Vector3:
	var arr: Variant = entry.get("position", [])
	if not (arr is Array):
		return Vector3.ZERO
	var pos_array := arr as Array
	if pos_array.size() < 3:
		return Vector3.ZERO
	return Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))


func _stable_variant_seed(entry: Dictionary) -> int:
	var build_id := str(entry.get("build_id", ""))
	var pos := _entry_position(entry)
	return int(hash("%s|%.3f|%.3f|%.3f" % [build_id, pos.x, pos.y, pos.z]))
