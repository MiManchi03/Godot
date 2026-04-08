extends Node3D

signal player_spawn_ready(safe_position: Vector3)

const CHUNK_SIZE := 32
const LOAD_RADIUS := 5
const UNLOAD_RADIUS := 7
const CHUNK_CREATES_PER_FRAME := 2
const VILLAGER_SNAPSHOT_INTERVAL := 5.0
const VILLAGER_SAVE_POS_EPS := 0.2
const VILLAGER_SAVE_ROT_EPS := 0.08
const PLAYER_SAFE_LIFT := 1.2
const PLAYER_SPAWN_RAY_UP := 8.0
const PLAYER_SPAWN_RAY_DOWN := 64.0
const PLAYER_MIN_SAFE_Y := -20.0
const PLAYER_FALLBACK_Y := 2.0

@export var world_seed: int = 91357

var biome_generator: BiomeGenerator
var resource_spawner: ResourceSpawner
var village_generator: VillageGenerator
var world_state: WorldState
var road_renderer: Node

var player: CharacterBody3D
var loaded_chunks: Dictionary = {}
var _villager_snapshot_timer: float = 0.0
var _villager_save_cache: Dictionary = {}
var _building_position_cache: Dictionary = {}
var _building_cache_dirty: bool = true
var _pending_chunk_coords: Array[Vector2i] = []
var _pending_chunk_set: Dictionary = {}
var _road_node_index: Dictionary = {} # Dictionary[Vector2i, Node3D]
var _road_state_dirty: bool = false


func _ready() -> void:
	add_to_group("world_manager")
	var road_network: Node = null
	if get_tree() != null:
		road_network = get_tree().get_first_node_in_group("road_network")
	if road_network and road_network.has_method("clear_all"):
		road_network.call("clear_all")
	biome_generator = BiomeGenerator.new(world_seed)
	resource_spawner = ResourceSpawner.new(world_seed + 1000)
	village_generator = VillageGenerator.new(world_seed + 2000)
	world_state = WorldState.new(world_seed, CHUNK_SIZE)
	road_renderer = _create_road_renderer()

	player = get_node_or_null("../Player")
	if player == null:
		push_error("WorldManager requires a sibling node named 'Player'.")
		return

	_load_saved_player_position()
	_building_cache_dirty = true
	_ensure_player_chunk_loaded_now()
	_emit_player_spawn_ready()

	_update_chunks_around_player()


func _process(_delta: float) -> void:
	if player == null:
		return
	if _is_build_mode_active():
		_villager_snapshot_timer += maxf(_delta, 0.0)
		if _villager_snapshot_timer >= VILLAGER_SNAPSHOT_INTERVAL:
			_snapshot_loaded_villagers(false)
			_villager_snapshot_timer = 0.0
	if world_state != null:
		world_state.tick(_delta)
	_update_chunks_around_player()
	if _road_state_dirty:
		_rebuild_road_state_from_loaded_chunks()
		_road_state_dirty = false


func _exit_tree() -> void:
	_snapshot_loaded_villagers(true)
	if world_state != null:
		world_state.save_dirty(true)


func _update_chunks_around_player() -> void:
	var player_chunk := _world_to_chunk(player.global_position)
	_ensure_chunk_loaded_now(player_chunk)
	var desired: Dictionary = {}

	for x in range(player_chunk.x - LOAD_RADIUS, player_chunk.x + LOAD_RADIUS + 1):
		for z in range(player_chunk.y - LOAD_RADIUS, player_chunk.y + LOAD_RADIUS + 1):
			var coord := Vector2i(x, z)
			desired[coord] = true
			if not loaded_chunks.has(coord) and not _pending_chunk_set.has(coord):
				_pending_chunk_coords.append(coord)
				_pending_chunk_set[coord] = true

	var to_remove: Array[Vector2i] = []
	for coord in loaded_chunks.keys():
		var chunk_coord: Vector2i = coord
		var dx: int = absi(chunk_coord.x - player_chunk.x)
		var dz: int = absi(chunk_coord.y - player_chunk.y)
		if dx > UNLOAD_RADIUS or dz > UNLOAD_RADIUS:
			to_remove.append(chunk_coord)

	for coord in to_remove:
		_remove_chunk(coord)

	if not _pending_chunk_coords.is_empty():
		var kept: Array[Vector2i] = []
		_pending_chunk_set.clear()
		for coord in _pending_chunk_coords:
			if desired.has(coord):
				kept.append(coord)
				_pending_chunk_set[coord] = true
		_pending_chunk_coords = kept

	_process_chunk_create_queue(player_chunk)


func _ensure_player_chunk_loaded_now() -> void:
	if player == null:
		return
	var player_chunk := _world_to_chunk(player.global_position)
	_ensure_chunk_loaded_now(player_chunk)


func _ensure_chunk_loaded_now(coord: Vector2i) -> void:
	if loaded_chunks.has(coord):
		return
	_pending_chunk_set.erase(coord)
	for i in range(_pending_chunk_coords.size() - 1, -1, -1):
		if _pending_chunk_coords[i] == coord:
			_pending_chunk_coords.remove_at(i)
	_create_chunk(coord)


func _process_chunk_create_queue(player_chunk: Vector2i) -> void:
	if _pending_chunk_coords.is_empty():
		return
	if _pending_chunk_coords.size() > CHUNK_CREATES_PER_FRAME * 2:
		_pending_chunk_coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da := absi(a.x - player_chunk.x) + absi(a.y - player_chunk.y)
			var db := absi(b.x - player_chunk.x) + absi(b.y - player_chunk.y)
			return da < db
		)
	var budget := CHUNK_CREATES_PER_FRAME
	while budget > 0 and not _pending_chunk_coords.is_empty():
		var coord: Vector2i = _pending_chunk_coords.pop_front() as Vector2i
		_pending_chunk_set.erase(coord)
		if loaded_chunks.has(coord):
			continue
		_create_chunk(coord)
		budget -= 1


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
	_set_chunk_road_visual_mode(chunk_root, false)
	loaded_chunks[coord] = chunk_root
	_building_cache_dirty = true
	_apply_player_buildings_for_chunk(coord, chunk_root)
	_register_chunk_roads_with_renderer(chunk_root)
	_road_state_dirty = true


func _remove_chunk(coord: Vector2i) -> void:
	if not loaded_chunks.has(coord):
		return
	var chunk: Node3D = loaded_chunks[coord]
	_unregister_chunk_roads(chunk)
	_snapshot_chunk_villagers(chunk, false)
	if world_state != null:
		world_state.save_dirty(false)

	loaded_chunks.erase(coord)
	chunk.queue_free()
	_building_cache_dirty = true
	_pending_chunk_set.erase(coord)
	_road_state_dirty = true


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


func _is_build_mode_active() -> bool:
	if player == null:
		return false
	return player.get("_build_mode_active") == true


func add_player_building(build_id: String, world_pos: Vector3, rotation_y: float, node_name: String = "", variant_seed: int = 0) -> void:
	if world_state == null:
		return
	world_state.add_player_building(build_id, world_pos, rotation_y, node_name, variant_seed)
	_update_road_network_on_building_added(build_id, world_pos)


func spawn_player_building(build_id: String, world_pos: Vector3, rotation_y: float, variant_seed: int, node_name: String = "") -> Node3D:
	if build_id == "road":
		var road_cell_check := Vector2i(roundi(world_pos.x), roundi(world_pos.z))
		var existing_road := get_road_node_at_cell(road_cell_check)
		if existing_road != null:
			return null
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
	if build_id == "road":
		var cell := Vector2i(roundi(world_pos.x), roundi(world_pos.z))
		instance.set_meta("entity_id", "road|%d|%d" % [cell.x, cell.y])
	else:
		instance.set_meta("entity_id", "player|%s|%.3f|%.3f" % [build_id, world_pos.x, world_pos.z])
	if build_id == "road":
		instance.set_meta("destruct_type", "road")
	else:
		instance.set_meta("destruct_type", "building")
	if not node_name.is_empty():
		instance.name = node_name
	var coord := _world_to_chunk(world_pos)
	if loaded_chunks.has(coord):
		(loaded_chunks[coord] as Node3D).add_child(instance)
	else:
		add_child(instance)
	instance.global_position = world_pos
	instance.rotation.y = rotation_y
	if build_id == "road":
		_register_road_node(instance)
		_set_road_visual_mode(instance, false)
	_building_cache_dirty = true
	_update_road_network_on_building_added(build_id, world_pos)
	return instance


func on_pick_existing_building(build_id: String, world_pos: Vector3, node_name: String, was_player_placed: bool, entity_id: String = "") -> void:
	if world_state == null:
		return
	if was_player_placed:
		world_state.remove_added_player(build_id, world_pos, node_name)
		_building_cache_dirty = true
		_update_road_network_on_building_removed(build_id, world_pos)
		return
	world_state.add_removed_original(build_id, world_pos, node_name, entity_id)
	_building_cache_dirty = true
	_update_road_network_on_building_removed(build_id, world_pos)


func save_player_buildings() -> void:
	_snapshot_loaded_villagers(true)
	if world_state == null:
		return
	world_state.save_dirty(true)


func save_build_mode_changes() -> void:
	print("[SAVE] 保存建筑模式改动...")
	_snapshot_loaded_villagers(true)
	if world_state == null:
		return
	world_state.save_dirty(true)
	print("[SAVE] 建筑模式改动已保存")


func save_all_player_changes() -> void:
	print("[SAVE] 保存所有玩家改动...")
	# 保存村民状态
	_snapshot_loaded_villagers(true)
	# 保存玩家位置
	_save_player_position()
	if world_state == null:
		return
	world_state.save_dirty(true)
	print("[SAVE] 所有玩家改动已保存")


func _save_player_position() -> void:
	if player == null:
		return
	if player.global_position.y < PLAYER_MIN_SAFE_Y:
		return
	var player_pos = {
		"position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"rotation": player.rotation.y,
	}
	if world_state != null:
		world_state.save_player_position(player_pos)


func _load_saved_player_position() -> void:
	if player == null:
		return
	if world_state == null:
		return
	var saved_pos = world_state.get_player_position()
	var pos_arr = saved_pos.get("position", null)
	if not (pos_arr is Array) or (pos_arr as Array).size() < 3:
		return
	var new_pos = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
	if new_pos == Vector3.ZERO:
		return
	player.global_position = _resolve_safe_player_spawn(new_pos)
	var rot = saved_pos.get("rotation", 0.0)
	player.rotation.y = float(rot)
	print("[LOAD] 玩家位置已恢复: ", player.global_position, " 旋转: ", rot)


func _resolve_safe_player_spawn(target_pos: Vector3) -> Vector3:
	var coord := _world_to_chunk(target_pos)
	_ensure_chunk_loaded_now(coord)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			_ensure_chunk_loaded_now(coord + Vector2i(dx, dz))
	var safe := _find_ground_safe_position(target_pos)
	if safe != Vector3.ZERO:
		return safe
	return Vector3(target_pos.x, PLAYER_FALLBACK_Y, target_pos.z)


func _find_ground_safe_position(target_pos: Vector3) -> Vector3:
	var world3d := get_world_3d()
	if world3d == null:
		return Vector3.ZERO
	var from := target_pos + Vector3(0.0, PLAYER_SPAWN_RAY_UP, 0.0)
	var to := target_pos - Vector3(0.0, PLAYER_SPAWN_RAY_DOWN, 0.0)
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = 1
	var hit: Dictionary = world3d.direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return Vector3.ZERO
	var p_val = hit.get("position", null)
	if p_val is Vector3:
		var p := p_val as Vector3
		return p + Vector3(0.0, PLAYER_SAFE_LIFT, 0.0)
	return Vector3.ZERO


func _emit_player_spawn_ready() -> void:
	if player == null:
		return
	emit_signal("player_spawn_ready", player.global_position)


func _snapshot_loaded_villagers(force_save: bool = false) -> void:
	if get_tree() == null:
		return
	var villagers := get_tree().get_nodes_in_group("villager")
	for node in villagers:
		if not (node is Node3D):
			continue
		var node3d := node as Node3D
		var entity_id := str(node3d.get_meta("entity_id", ""))
		if entity_id.is_empty():
			continue
		if force_save or _villager_needs_save(node3d):
			save_villager_state(node3d, force_save)


func _snapshot_chunk_villagers(chunk_root: Node3D, force_save: bool = false) -> void:
	if chunk_root == null:
		return
	var queue: Array[Node] = [chunk_root]
	while not queue.is_empty():
		var node := queue.pop_front() as Node
		if node is Node3D:
			var node3d := node as Node3D
			if node3d.name.begins_with("Villager") and not str(node3d.get_meta("entity_id", "")).is_empty():
				if force_save or _villager_needs_save(node3d):
					save_villager_state(node3d, force_save)
		for child in node.get_children():
			queue.append(child)


func _villager_needs_save(villager: Node3D) -> bool:
	var entity_id := str(villager.get_meta("entity_id", ""))
	if entity_id.is_empty():
		return false
	var pos := villager.global_position
	if pos == Vector3.ZERO:
		return false
	var rot := villager.rotation.y
	var rec = _villager_save_cache.get(entity_id, null)
	if not (rec is Dictionary):
		return true
	var prev := rec as Dictionary
	var prev_pos_val = prev.get("position", null)
	if not (prev_pos_val is Vector3):
		return true
	var prev_pos := prev_pos_val as Vector3
	var prev_rot := float(prev.get("rotation", 0.0))
	if prev_pos.distance_to(pos) > VILLAGER_SAVE_POS_EPS:
		return true
	if absf(prev_rot - rot) > VILLAGER_SAVE_ROT_EPS:
		return true
	return false


func _apply_player_buildings_for_chunk(coord: Vector2i, chunk_root: Node3D) -> void:
	if world_state == null:
		return
	var chunk_data := world_state.get_chunk_data(coord)
	var removed := chunk_data.get("removed", []) as Array
	if not removed.is_empty():
		_apply_removed_originals(chunk_root, removed)
	var nearby_removed := _collect_neighbor_removed_entries(coord, 1)
	if not nearby_removed.is_empty():
		_apply_removed_originals(chunk_root, nearby_removed)

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

	var destroyed := chunk_data.get("destroyed", []) as Array
	if not destroyed.is_empty():
		_apply_destroyed_resources(chunk_root, destroyed)
	var nearby_destroyed := _collect_neighbor_destroyed_entries(coord, 1)
	if not nearby_destroyed.is_empty():
		_apply_destroyed_resources(chunk_root, nearby_destroyed)

	var villagers := chunk_data.get("villagers", []) as Array
	if not villagers.is_empty():
		_apply_saved_villagers(chunk_root, villagers)


func _collect_neighbor_removed_entries(center: Vector2i, radius: int) -> Array:
	if world_state == null or radius <= 0:
		return []
	var out: Array = []
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			if dx == 0 and dz == 0:
				continue
			var c := center + Vector2i(dx, dz)
			var data := world_state.get_chunk_data(c)
			var removed := data.get("removed", []) as Array
			if not removed.is_empty():
				out.append_array(removed)
	return out


func _collect_neighbor_destroyed_entries(center: Vector2i, radius: int) -> Array:
	if world_state == null or radius <= 0:
		return []
	var out: Array = []
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			if dx == 0 and dz == 0:
				continue
			var c := center + Vector2i(dx, dz)
			var data := world_state.get_chunk_data(c)
			var destroyed := data.get("destroyed", []) as Array
			if not destroyed.is_empty():
				out.append_array(destroyed)
	return out




func report_destroyed_resource(destruct_type: String, world_pos: Vector3, entity_id: String = "") -> void:
	if world_state == null:
		return
	world_state.add_destroyed_resource(destruct_type, world_pos, entity_id)


func save_villager_state(villager: Node3D, flush_to_disk: bool = false) -> void:
	if world_state == null or villager == null:
		return
	var save_pos := villager.global_position
	if save_pos == Vector3.ZERO:
		return
	var entity_id := str(villager.get_meta("entity_id", ""))
	var origin_chunk := _origin_chunk_from_meta(villager.get_meta("origin_chunk", null))
	if origin_chunk == Vector2i(1 << 30, 1 << 30):
		origin_chunk = _world_to_chunk(save_pos)
	if entity_id.is_empty():
		# Use the SAME seed as village_generator.base_seed to ensure consistency
		entity_id = "%d|%d|%d|villager|%s" % [village_generator.base_seed, origin_chunk.x, origin_chunk.y, villager.name]
		villager.set_meta("entity_id", entity_id)
		villager.set_meta("origin_chunk", origin_chunk)
	if entity_id.is_empty():
		return
	
	# Calculate origin chunk from meta, entity_id, or position fallback
	origin_chunk = _origin_chunk_from_meta(villager.get_meta("origin_chunk", null))
	if origin_chunk == Vector2i(1 << 30, 1 << 30):
		origin_chunk = _chunk_from_entity_id(entity_id)
	if origin_chunk == Vector2i(1 << 30, 1 << 30):
		origin_chunk = _world_to_chunk(save_pos)
	
	var task_start_val = villager.get("task_start_build_id")
	var task_end_val = villager.get("task_end_build_id")
	var carrying_item_val = villager.get("carrying_item")
	var task_start_id := "" if task_start_val == null else str(task_start_val)
	var task_end_id := "" if task_end_val == null else str(task_end_val)
	var carrying_item := false if carrying_item_val == null else bool(carrying_item_val)
	var task_state := 0
	if villager.has_method("get_task_state"):
		task_state = int(villager.call("get_task_state"))
	_villager_save_cache[entity_id] = {
		"position": save_pos,
		"rotation": villager.rotation.y,
	}
	
	# Save in memory first; flush only on explicit save points
	world_state.upsert_villager_state(entity_id, save_pos, villager.rotation.y, task_start_id, task_end_id, carrying_item, task_state, origin_chunk)
	if flush_to_disk:
		world_state.save_dirty(true)


func _apply_saved_villagers(chunk_root: Node3D, villagers: Array) -> void:
	var applied: Dictionary = {}
	var matched_count := 0
	var skipped_no_entity := 0
	var skipped_no_match := 0

	for v_variant in villagers:
		var entry := v_variant as Dictionary
		var entity_id := str(entry.get("entity_id", ""))
		
		# Skip if already applied this entity_id
		if not entity_id.is_empty() and applied.has(entity_id):
			continue
		
		var pos := _entry_position(entry)
		
		# Skip if position is missing or invalid
		var pos_arr = entry.get("position", null)
		if not (pos_arr is Array) or (pos_arr as Array).size() < 3:
			skipped_no_entity += 1
			continue
		
		# Multi-level matching:
		# Level 1: Try exact entity_id match
		var villager := _find_villager_by_entity_id(chunk_root, entity_id)
		
		# Level 2: If no entity_id match, try name match (no position restriction)
		if villager == null:
			var villager_name := _villager_name_from_entity_id(entity_id)
			if not villager_name.is_empty():
				villager = _find_villager_by_name_simple(chunk_root, villager_name)
		
		# If still no match, skip (don't overwrite any villager)
		if villager == null:
			skipped_no_match += 1
			continue
		
		# Apply the saved state
		if pos == Vector3.ZERO:
			skipped_no_entity += 1
			continue
		matched_count += 1
		if not entity_id.is_empty():
			applied[entity_id] = true

		villager.global_position = pos
		villager.rotation.y = float(entry.get("rotation_y", 0.0))
		
		var task_start := str(entry.get("task_start_build_id", ""))
		var task_end := str(entry.get("task_end_build_id", ""))
		var task_state := int(entry.get("task_state", 0))
		
		if villager.has_method("apply_saved_state"):
			villager.call("apply_saved_state", task_start, task_end, bool(entry.get("carrying_item", false)), task_state)
		elif villager.has_method("set_task") and (not task_start.is_empty() or not task_end.is_empty()):
			villager.call("set_task", task_start, task_end)
		
		if villager.has_method("set"):
			villager.set("carrying_item", bool(entry.get("carrying_item", false)))
		
		if villager.has_method("on_loaded_from_save"):
			villager.call("on_loaded_from_save")
	
	# Debug output (can be removed in production)
	if matched_count > 0 or skipped_no_match > 0:
		print("[VILLAGER] Applied %d villagers, skipped %d (no position), %d (no match)" % [matched_count, skipped_no_entity, skipped_no_match])


func _find_villager_by_entity_id(root: Node, entity_id: String) -> Node3D:
	if entity_id.is_empty():
		return null
	var queue: Array[Node] = [root]
	while not queue.is_empty():
		var node := queue.pop_front() as Node
		if node is Node3D:
			var node3d := node as Node3D
			if node3d.name.begins_with("Villager") and str(node3d.get_meta("entity_id", "")) == entity_id:
				return node3d
		for child in node.get_children():
			queue.append(child)
	return null


func _find_villager_by_name(root: Node, villager_name: String, required_chunk: Vector2i) -> Node3D:
	if villager_name.is_empty():
		return null
	var queue: Array[Node] = [root]
	while not queue.is_empty():
		var node := queue.pop_front() as Node
		if node is Node3D:
			var node3d := node as Node3D
			if node3d.name == villager_name:
				if required_chunk != Vector2i(1 << 30, 1 << 30):
					var c := _chunk_from_entity_id(str(node3d.get_meta("entity_id", "")))
					if c != required_chunk:
						for child in node.get_children():
							queue.append(child)
						continue
				return node3d
		for child in node.get_children():
			queue.append(child)
	return null


func _find_villager_for_saved_entry(root: Node, entity_id: String, legacy_name: String, required_chunk: Vector2i) -> Node3D:
	var by_id := _find_villager_by_entity_id(root, entity_id)
	if by_id != null:
		return by_id
	return _find_villager_by_name(root, legacy_name, required_chunk)


func _find_villager_by_name_approximate(root: Node, villager_name: String, target_pos: Vector3, max_distance: float) -> Node3D:
	if villager_name.is_empty():
		return null
	
	var best_match: Node3D = null
	var best_distance_sq := max_distance * max_distance
	var queue: Array[Node] = [root]
	
	while not queue.is_empty():
		var node := queue.pop_front() as Node
		if node is Node3D:
			var node3d := node as Node3D
			if node3d.name == villager_name:
				var dist_sq := node3d.global_position.distance_squared_to(target_pos)
				if dist_sq < best_distance_sq:
					best_distance_sq = dist_sq
					best_match = node3d
		for child in node.get_children():
			queue.append(child)
	
	return best_match


func _find_villager_by_name_simple(root: Node, villager_name: String) -> Node3D:
	if villager_name.is_empty():
		return null
	var queue: Array[Node] = [root]
	while not queue.is_empty():
		var node := queue.pop_front() as Node
		if node is Node3D:
			var node3d := node as Node3D
			if node3d.name == villager_name:
				return node3d
		for child in node.get_children():
			queue.append(child)
	return null


func _chunk_from_entity_id(entity_id: String) -> Vector2i:
	var invalid := Vector2i(1 << 30, 1 << 30)
	if entity_id.is_empty():
		return invalid
	var parts := entity_id.split("|")
	# New format: seed|villager|name (3 parts)
	if parts.size() == 3 and parts[1] == "villager":
		return invalid
	# Old format: seed|cx|cz|villager|...
	if parts.size() >= 4 and parts[3] == "villager":
		return Vector2i(int(parts[1]), int(parts[2]))
	return invalid


func _villager_name_from_entity_id(entity_id: String) -> String:
	if entity_id.is_empty():
		return ""
	var parts := entity_id.split("|")
	if parts.size() >= 3 and parts[1] == "villager":
		return parts[2]
	if parts.size() >= 5 and parts[3] == "villager":
		return parts[4]
	return ""


func _origin_chunk_from_meta(meta_val) -> Vector2i:
	var invalid := Vector2i(1 << 30, 1 << 30)
	if meta_val is Vector2i:
		return meta_val as Vector2i
	if meta_val is Array:
		var arr := meta_val as Array
		if arr.size() >= 2:
			return Vector2i(int(arr[0]), int(arr[1]))
	return invalid


func _apply_destroyed_resources(chunk_root: Node3D, destroyed: Array) -> void:
	for rec_variant in destroyed:
		var rec := rec_variant as Dictionary
		var entity_id := str(rec.get("entity_id", ""))
		var destruct_type := str(rec.get("destruct_type", ""))
		var pos := _entry_position(rec)
		var target := _find_matching_destructible(chunk_root, destruct_type, pos, entity_id)
		if target != null:
			target.queue_free()


func _find_matching_destructible(root: Node, destruct_type: String, world_pos: Vector3, entity_id: String) -> Node3D:
	var queue: Array[Node] = [root]
	var best: Node3D = null
	var best_d2 := 0.9 * 0.9
	while not queue.is_empty():
		var node := queue.pop_front() as Node
		if node is Node3D:
			var node3d := node as Node3D
			if bool(node3d.get_meta("player_placed", false)):
				for child in node.get_children():
					queue.append(child)
				continue
			if not entity_id.is_empty() and str(node3d.get_meta("entity_id", "")) == entity_id:
				return node3d
			if str(node3d.get_meta("destruct_type", "")) == destruct_type:
				var d2 := node3d.global_position.distance_squared_to(world_pos)
				if d2 <= best_d2:
					best_d2 = d2
					best = node3d
		for child in node.get_children():
			queue.append(child)
	return best


func _apply_removed_originals(chunk_root: Node3D, removed: Array) -> void:
	for rem_variant in removed:
		var rem := rem_variant as Dictionary
		var rem_id := str(rem.get("build_id", ""))
		if rem_id.is_empty():
			continue
		var rem_name := str(rem.get("name", ""))
		var rem_entity_id := str(rem.get("entity_id", ""))
		var rem_pos := _entry_position(rem)
		var radius := 1.8
		if rem_id == "road":
			radius = 0.2
		var target := _find_matching_original(chunk_root, rem_id, rem_pos, radius, rem_name, rem_entity_id)
		if target != null:
			_update_road_network_on_building_removed(rem_id, target.global_position)
			target.queue_free()


func _find_matching_original(root: Node, build_id: String, world_pos: Vector3, radius: float, node_name: String, entity_id: String) -> Node3D:
	var candidates: Array[Node3D] = []
	_collect_building_candidates(root, candidates)
	if build_id == "road":
		var target_cell := Vector2i(roundi(world_pos.x), roundi(world_pos.z))
		for c in candidates:
			if bool(c.get_meta("player_placed", false)):
				continue
			if _resolve_build_id(c) != "road":
				continue
			var c_cell := Vector2i(roundi(c.global_position.x), roundi(c.global_position.z))
			if c_cell == target_cell:
				return c
	if not entity_id.is_empty():
		for c in candidates:
			if bool(c.get_meta("player_placed", false)):
				continue
			if _resolve_build_id(c) != build_id:
				continue
			if str(c.get_meta("entity_id", "")) == entity_id:
				return c
	if not node_name.is_empty():
		var name_best: Node3D = null
		var name_best_d2 := (radius * 3.0) * (radius * 3.0)
		for c in candidates:
			if bool(c.get_meta("player_placed", false)):
				continue
			if _resolve_build_id(c) != build_id:
				continue
			if c.name != node_name:
				continue
			var d2 := c.global_position.distance_squared_to(world_pos)
			if d2 <= name_best_d2:
				name_best_d2 = d2
				name_best = c
		if name_best != null:
			return name_best
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
	var base := node_name
	var us_idx := base.find("_")
	if us_idx > 0:
		base = base.substr(0, us_idx)
	match base:
		"House":
			return "house"
		"Workshop":
			return "workshop"
		"Warehouse":
			return "warehouse"
		"Market":
			return "market"
		"Well":
			return "well"
		"Campfire":
			return "campfire"
		"FencePost", "Fence_Post":
			return "fencepost"
		"Road":
			return "road"
		"Farm", "FarmPlot":
			return "farm"
		"Tower":
			return "tower"
		"Barrack", "Barracks":
			return "barrack"
		_:
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
		"road":
			return VillageGenerator.BuildingType.ROAD
		"farm":
			return VillageGenerator.BuildingType.FARM
		"tower":
			return VillageGenerator.BuildingType.TOWER
		"barrack":
			return VillageGenerator.BuildingType.BARRACK
		_:
			return -1


func _entry_position(entry: Dictionary) -> Vector3:
	var arr = entry.get("position", [])
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


func find_building_by_id(build_id: String) -> Vector3:
	if build_id.is_empty():
		return Vector3.ZERO
	if _building_cache_dirty:
		_rebuild_building_position_cache()
		_building_cache_dirty = false
	if _building_position_cache.has(build_id):
		var cached = _building_position_cache[build_id]
		if cached is Vector3:
			return cached as Vector3
	return Vector3.ZERO


func _rebuild_building_position_cache() -> void:
	_building_position_cache.clear()
	for chunk_root in loaded_chunks.values():
		if chunk_root == null:
			continue
		var queue: Array[Node] = [chunk_root]
		while not queue.is_empty():
			var node: Node = queue.pop_front()
			if node is Node3D:
				var build_id := _resolve_build_id(node as Node3D)
				if not build_id.is_empty() and not _building_position_cache.has(build_id):
					_building_position_cache[build_id] = (node as Node3D).global_position
			for child in node.get_children():
				queue.append(child)


func notify_building_cache_dirty() -> void:
	_building_cache_dirty = true


func _update_road_network_on_building_added(build_id: String, world_pos: Vector3) -> void:
	if build_id != "road":
		return
	
	var cell := Vector2i(roundi(world_pos.x), roundi(world_pos.z))
	var road_network: Node = null
	if get_tree() != null:
		road_network = get_tree().get_first_node_in_group("road_network")
	if road_network and road_network.has_method("add_road"):
		road_network.call("add_road", cell)
	
	if road_renderer and road_renderer.has_method("set_road_cell"):
		road_renderer.call("set_road_cell", cell, 0)
	_road_state_dirty = true


func _update_road_network_on_building_removed(build_id: String, world_pos: Vector3) -> void:
	if build_id != "road":
		return
	
	var cell := Vector2i(roundi(world_pos.x), roundi(world_pos.z))
	_unregister_road_cell(cell)
	var road_network: Node = null
	if get_tree() != null:
		road_network = get_tree().get_first_node_in_group("road_network")
	if road_network and road_network.has_method("remove_road"):
		road_network.call("remove_road", cell)
	
	if road_renderer and road_renderer.has_method("remove_road_cell"):
		road_renderer.call("remove_road_cell", cell)
	_road_state_dirty = true


func _create_road_renderer() -> Node:
	var renderer := Node.new()
	renderer.name = "RoadRenderer"
	var script := load("res://scripts/world/road_renderer.gd")
	if script:
		renderer.set_script(script)
	add_child(renderer)
	return renderer


func _register_chunk_roads_with_renderer(chunk_root: Node3D) -> void:
	if road_renderer == null or not road_renderer.has_method("set_road_cell"):
		return
	var stack: Array[Node] = [chunk_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Node3D:
			var node3d := node as Node3D
			if bool(node3d.get_meta("road", false)) or str(node3d.get_meta("build_id", "")) == "road":
				if bool(node3d.get_meta("pending_delete", false)) or bool(node3d.get_meta("picked_hidden", false)):
					for child in node.get_children():
						stack.append(child)
					continue
				_register_road_node(node3d)
				_set_road_visual_mode(node3d, false)
				var cell := Vector2i(roundi(node3d.global_position.x), roundi(node3d.global_position.z))
				road_renderer.call("set_road_cell", cell, 0)
		for child in node.get_children():
			stack.append(child)


func _rebuild_road_state_from_loaded_chunks() -> void:
	_road_node_index.clear()
	var road_network: Node = null
	if get_tree() != null:
		road_network = get_tree().get_first_node_in_group("road_network")
	if road_network and road_network.has_method("clear_all"):
		road_network.call("clear_all")
	if road_renderer and road_renderer.has_method("clear_all_cells"):
		road_renderer.call("clear_all_cells")

	var seen_cells: Dictionary = {}
	for chunk_coord in loaded_chunks.keys():
		var chunk: Node3D = loaded_chunks[chunk_coord]
		if chunk == null:
			continue
		var stack: Array[Node] = [chunk]
		while not stack.is_empty():
			var node := stack.pop_back() as Node
			if node is Node3D:
				var n3d := node as Node3D
				if bool(n3d.get_meta("road", false)) or str(n3d.get_meta("build_id", "")) == "road":
					if bool(n3d.get_meta("pending_delete", false)) or bool(n3d.get_meta("picked_hidden", false)):
						for child in node.get_children():
							stack.append(child)
						continue
					var cell := Vector2i(roundi(n3d.global_position.x), roundi(n3d.global_position.z))
					if seen_cells.has(cell):
						n3d.set_meta("pending_delete", true)
						n3d.queue_free()
						for child in node.get_children():
							stack.append(child)
						continue
					seen_cells[cell] = true
					_register_road_node(n3d)
					_set_road_visual_mode(n3d, false)
					if road_network and road_network.has_method("add_road"):
						road_network.call("add_road", cell)
					if road_renderer and road_renderer.has_method("set_road_cell"):
						road_renderer.call("set_road_cell", cell, 0)
			for child in node.get_children():
				stack.append(child)


func _register_road_node(road_node: Node3D) -> void:
	if road_node == null:
		return
	var cell := Vector2i(roundi(road_node.global_position.x), roundi(road_node.global_position.z))
	# 强制道路节点对齐到整数格，确保渲染/拾取/删除同一坐标系
	road_node.global_position = Vector3(float(cell.x), 0.0, float(cell.y))
	if str(road_node.get_meta("build_id", "")) == "road" or bool(road_node.get_meta("road", false)):
		road_node.set_meta("entity_id", "road|%d|%d" % [cell.x, cell.y])
	_road_node_index[cell] = road_node


func _unregister_road_cell(cell: Vector2i) -> void:
	_road_node_index.erase(cell)


func _unregister_chunk_roads(chunk_root: Node3D) -> void:
	var stack: Array[Node] = [chunk_root]
	while not stack.is_empty():
		var node := stack.pop_back() as Node
		if node is Node3D:
			var n3d := node as Node3D
			if bool(n3d.get_meta("road", false)) or str(n3d.get_meta("build_id", "")) == "road":
				var cell := Vector2i(roundi(n3d.global_position.x), roundi(n3d.global_position.z))
				var road_network: Node = null
				if get_tree() != null:
					road_network = get_tree().get_first_node_in_group("road_network")
				if road_network and road_network.has_method("remove_road"):
					road_network.call("remove_road", cell)
				if road_renderer and road_renderer.has_method("remove_road_cell"):
					road_renderer.call("remove_road_cell", cell)
				_unregister_road_cell(cell)
		for child in node.get_children():
			stack.append(child)


func _set_chunk_road_visual_mode(chunk_root: Node3D, visible: bool) -> void:
	var stack: Array[Node] = [chunk_root]
	while not stack.is_empty():
		var node := stack.pop_back() as Node
		if node is Node3D:
			var n3d := node as Node3D
			if bool(n3d.get_meta("road", false)) or str(n3d.get_meta("build_id", "")) == "road":
				_set_road_visual_mode(n3d, visible)
		for child in node.get_children():
			stack.append(child)


func _set_road_visual_mode(road_node: Node3D, visible: bool) -> void:
	if road_node == null:
		return
	for child in road_node.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = visible


func highlight_road_cells(cells: Array, item_type: int = 1, duration: float = 2.0) -> void:
	if road_renderer and road_renderer.has_method("highlight_cells"):
		var typed_cells: Array[Vector2i] = []
		for c in cells:
			typed_cells.append(c as Vector2i)
		road_renderer.call("highlight_cells", typed_cells, item_type, duration)


func get_road_node_at_cell(cell: Vector2i) -> Node3D:
	var raw = _road_node_index.get(cell, null)
	if raw == null:
		_road_node_index.erase(cell)
		return null
	if not is_instance_valid(raw):
		_road_node_index.erase(cell)
		return null
	if raw is Node3D:
		var n := raw as Node3D
		if bool(n.get_meta("pending_delete", false)) or bool(n.get_meta("picked_hidden", false)):
			_road_node_index.erase(cell)
			return null
		return n
	# 索引丢失时回退扫描并自愈
	for chunk_coord in loaded_chunks.keys():
		var chunk: Node3D = loaded_chunks[chunk_coord]
		if chunk == null:
			continue
		var stack: Array[Node] = [chunk]
		while not stack.is_empty():
			var node := stack.pop_back() as Node
			if node is Node3D:
				var n3d := node as Node3D
				if bool(n3d.get_meta("road", false)) or str(n3d.get_meta("build_id", "")) == "road":
					if bool(n3d.get_meta("pending_delete", false)) or bool(n3d.get_meta("picked_hidden", false)):
						for child in node.get_children():
							stack.append(child)
						continue
					var ncell := Vector2i(roundi(n3d.global_position.x), roundi(n3d.global_position.z))
					if ncell == cell:
						_register_road_node(n3d)
						return n3d
			for child in node.get_children():
				stack.append(child)
	_road_node_index.erase(cell)
	return null


func begin_pickup_road(cell: Vector2i) -> void:
	_unregister_road_cell(cell)
	var road_network: Node = null
	if get_tree() != null:
		road_network = get_tree().get_first_node_in_group("road_network")
	if road_network and road_network.has_method("remove_road"):
		road_network.call("remove_road", cell)
	if road_renderer and road_renderer.has_method("remove_road_cell"):
		road_renderer.call("remove_road_cell", cell)


func cancel_pickup_road(road_node: Node3D) -> void:
	if road_node == null or not is_instance_valid(road_node):
		return
	_register_road_node(road_node)
	var cell := Vector2i(roundi(road_node.global_position.x), roundi(road_node.global_position.z))
	var road_network: Node = null
	if get_tree() != null:
		road_network = get_tree().get_first_node_in_group("road_network")
	if road_network and road_network.has_method("add_road"):
		road_network.call("add_road", cell)
	if road_renderer and road_renderer.has_method("set_road_cell"):
		road_renderer.call("set_road_cell", cell, 0)


func set_road_cell_visible(cell: Vector2i, visible: bool) -> void:
	if road_renderer == null:
		return
	if visible:
		if road_renderer.has_method("set_road_cell"):
			road_renderer.call("set_road_cell", cell, 0)
	else:
		if road_renderer.has_method("remove_road_cell"):
			road_renderer.call("remove_road_cell", cell)


func has_road_cell(cell: Vector2i) -> bool:
	var road_network: Node = null
	if get_tree() != null:
		road_network = get_tree().get_first_node_in_group("road_network")
	if road_network and road_network.has_method("has_road_at"):
		return bool(road_network.call("has_road_at", cell))
	return false


func reconcile_road_state() -> void:
	_rebuild_road_state_from_loaded_chunks()


func get_buildings_at_cell(cell: Vector2i) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for chunk_coord in loaded_chunks.keys():
		var chunk: Node3D = loaded_chunks[chunk_coord]
		if chunk == null:
			continue
		var stack: Array[Node] = [chunk]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if node is Node3D and node != chunk:
				var node3d := node as Node3D
				var build_id := str(node3d.get_meta("build_id", ""))
				if not build_id.is_empty() and build_id != "road":
					var node_cell := Vector2i(roundi(node3d.global_position.x), roundi(node3d.global_position.z))
					if node_cell == cell:
						result.append(node3d)
			for child in node.get_children():
				stack.append(child)
	return result
