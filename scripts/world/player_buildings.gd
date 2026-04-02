extends RefCounted
class_name PlayerBuildings

const DATA_VERSION := 1

var world_seed: int
var chunk_size: int
var world_dir: String
var buildings_dir: String
var meta_path: String

var _chunk_cache: Dictionary = {}


func _init(seed: int, chunk_span: int) -> void:
	world_seed = seed
	chunk_size = chunk_span
	world_dir = "user://worlds/%d" % world_seed
	buildings_dir = "%s/buildings" % world_dir
	meta_path = "%s/meta.json" % world_dir
	_ensure_world_dirs()
	_write_meta(false)


func get_chunk_data(coord: Vector2i) -> Dictionary:
	var chunk_data := _load_chunk(coord)
	return {
		"added": (chunk_data.get("added", []) as Array).duplicate(true),
		"removed": (chunk_data.get("removed", []) as Array).duplicate(true),
	}


func add_building(build_id: String, world_pos: Vector3, rotation_y: float, node_name: String = "", variant_seed: int = 0) -> void:
	var coord := _world_to_chunk(world_pos)
	var chunk_data := _load_chunk(coord)
	var entry := {
		"build_id": build_id,
		"position": [world_pos.x, world_pos.y, world_pos.z],
		"rotation_y": rotation_y,
		"name": node_name,
		"variant_seed": variant_seed,
	}
	(chunk_data["added"] as Array).append(entry)
	chunk_data["dirty"] = true


func remove_added_near(build_id: String, world_pos: Vector3, radius: float = 1.6) -> bool:
	var coord := _world_to_chunk(world_pos)
	var chunk_data := _load_chunk(coord)
	var added := chunk_data.get("added", []) as Array
	var r2 := radius * radius
	for i in range(added.size() - 1, -1, -1):
		var entry := added[i] as Dictionary
		if str(entry.get("build_id", "")) != build_id:
			continue
		var entry_pos := _entry_position(entry)
		if entry_pos.distance_squared_to(world_pos) <= r2:
			added.remove_at(i)
			chunk_data["dirty"] = true
			return true
	return false


func add_removed_original(build_id: String, world_pos: Vector3, node_name: String = "") -> void:
	var coord := _world_to_chunk(world_pos)
	var chunk_data := _load_chunk(coord)
	var removed := chunk_data.get("removed", []) as Array
	var r2 := 1.6 * 1.6
	for entry_variant in removed:
		var entry := entry_variant as Dictionary
		if str(entry.get("build_id", "")) != build_id:
			continue
		var entry_pos := _entry_position(entry)
		if entry_pos.distance_squared_to(world_pos) <= r2:
			return
	var rem := {
		"build_id": build_id,
		"position": [world_pos.x, world_pos.y, world_pos.z],
		"name": node_name,
	}
	removed.append(rem)
	chunk_data["dirty"] = true


func save_dirty() -> void:
	var any_dirty := false
	for key in _chunk_cache.keys():
		var chunk_data := _chunk_cache[key] as Dictionary
		if not bool(chunk_data.get("dirty", false)):
			continue
		_save_chunk(chunk_data)
		chunk_data["dirty"] = false
		any_dirty = true
	if any_dirty:
		_write_meta(true)


func _chunk_key(coord: Vector2i) -> String:
	return "%d_%d" % [coord.x, coord.y]


func _chunk_path(coord: Vector2i) -> String:
	return "%s/%s.json" % [buildings_dir, _chunk_key(coord)]


func _world_to_chunk(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / float(chunk_size)),
		floori(world_pos.z / float(chunk_size))
	)


func _ensure_world_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(world_dir)
	DirAccess.make_dir_recursive_absolute(buildings_dir)


func _write_meta(update_last_played: bool) -> void:
	var existing: Dictionary = {}
	if FileAccess.file_exists(meta_path):
		var f_read := FileAccess.open(meta_path, FileAccess.READ)
		if f_read != null:
			var parsed = JSON.parse_string(f_read.get_as_text())
			if parsed is Dictionary:
				existing = parsed as Dictionary

	var now := Time.get_datetime_string_from_system(true, true)
	if not existing.has("created_at"):
		existing["created_at"] = now
	existing["version"] = DATA_VERSION
	existing["world_seed"] = world_seed
	if update_last_played or not existing.has("last_played"):
		existing["last_played"] = now

	var f_write := FileAccess.open(meta_path, FileAccess.WRITE)
	if f_write != null:
		f_write.store_string(JSON.stringify(existing, "\t"))


func _load_chunk(coord: Vector2i) -> Dictionary:
	var key := _chunk_key(coord)
	if _chunk_cache.has(key):
		return _chunk_cache[key] as Dictionary

	var chunk_data := {
		"coord": coord,
		"added": [],
		"removed": [],
		"dirty": false,
	}

	var path := _chunk_path(coord)
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				var dict := parsed as Dictionary
				if dict.get("added", []) is Array:
					chunk_data["added"] = (dict.get("added", []) as Array).duplicate(true)
				if dict.get("removed", []) is Array:
					chunk_data["removed"] = (dict.get("removed", []) as Array).duplicate(true)

	_chunk_cache[key] = chunk_data
	return chunk_data


func _save_chunk(chunk_data: Dictionary) -> void:
	var coord := chunk_data.get("coord", Vector2i.ZERO) as Vector2i
	var added := chunk_data.get("added", []) as Array
	var removed := chunk_data.get("removed", []) as Array
	var path := _chunk_path(coord)

	if added.is_empty() and removed.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return

	var payload := {
		"version": DATA_VERSION,
		"chunk": [coord.x, coord.y],
		"added": added,
		"removed": removed,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "\t"))


func _entry_position(entry: Dictionary) -> Vector3:
	var arr: Variant = entry.get("position", [])
	if not (arr is Array):
		return Vector3.ZERO
	var pos_array := arr as Array
	if pos_array.size() < 3:
		return Vector3.ZERO
	return Vector3(
		float(pos_array[0]),
		float(pos_array[1]),
		float(pos_array[2])
	)
