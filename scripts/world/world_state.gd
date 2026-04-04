extends RefCounted
class_name WorldState

const DATA_VERSION := 2
const AUTOSAVE_INTERVAL := 3.0

var world_seed: int
var chunk_size: int
var world_dir: String
var chunks_dir: String
var meta_path: String

var _chunk_cache: Dictionary = {}
var _dirty_keys: Dictionary = {}
var _autosave_timer: float = 0.0


func _init(seed: int, chunk_span: int) -> void:
	world_seed = seed
	chunk_size = chunk_span
	world_dir = "user://worlds/%d" % world_seed
	chunks_dir = "%s/buildings" % world_dir
	meta_path = "%s/meta.json" % world_dir
	_ensure_world_dirs()
	_write_meta(false)


func tick(delta: float) -> void:
	_autosave_timer += maxf(delta, 0.0)
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		save_dirty(false)


func get_chunk_data(coord: Vector2i) -> Dictionary:
	var chunk_data := _load_chunk(coord)
	return {
		"added": (chunk_data.get("added", []) as Array).duplicate(true),
		"removed": (chunk_data.get("removed", []) as Array).duplicate(true),
		"destroyed": (chunk_data.get("destroyed", []) as Array).duplicate(true),
	}


func add_player_building(build_id: String, world_pos: Vector3, rotation_y: float, node_name: String = "", variant_seed: int = 0) -> void:
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
	_mark_chunk_dirty(chunk_data)


func remove_added_player(build_id: String, world_pos: Vector3, node_name: String = "") -> bool:
	var coord := _world_to_chunk(world_pos)
	var chunk_data := _load_chunk(coord)
	var added := chunk_data.get("added", []) as Array
	for i in range(added.size() - 1, -1, -1):
		var entry := added[i] as Dictionary
		if str(entry.get("build_id", "")) != build_id:
			continue
		if not node_name.is_empty() and str(entry.get("name", "")) == node_name:
			added.remove_at(i)
			_mark_chunk_dirty(chunk_data)
			return true

	var radius := 1.6
	if build_id == "road":
		radius = 0.45
	var r2 := radius * radius
	for i in range(added.size() - 1, -1, -1):
		var entry := added[i] as Dictionary
		if str(entry.get("build_id", "")) != build_id:
			continue
		var entry_pos := _entry_position(entry)
		if entry_pos.distance_squared_to(world_pos) <= r2:
			added.remove_at(i)
			_mark_chunk_dirty(chunk_data)
			return true
	return false


func add_removed_original(build_id: String, world_pos: Vector3, node_name: String = "", entity_id: String = "") -> void:
	var coord := _world_to_chunk(world_pos)
	var chunk_data := _load_chunk(coord)
	var removed := chunk_data.get("removed", []) as Array

	for entry_variant in removed:
		var entry := entry_variant as Dictionary
		if str(entry.get("build_id", "")) != build_id:
			continue
		if not entity_id.is_empty() and str(entry.get("entity_id", "")) == entity_id:
			return
		if not node_name.is_empty() and str(entry.get("name", "")) == node_name:
			return

	var dedupe_radius := 1.6
	if build_id == "road":
		dedupe_radius = 0.45
	var r2 := dedupe_radius * dedupe_radius
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
	if not entity_id.is_empty():
		rem["entity_id"] = entity_id
	removed.append(rem)
	_mark_chunk_dirty(chunk_data)


func add_destroyed_resource(destruct_type: String, world_pos: Vector3, entity_id: String = "") -> void:
	var coord := _world_to_chunk(world_pos)
	var chunk_data := _load_chunk(coord)
	var destroyed := chunk_data.get("destroyed", []) as Array

	for entry_variant in destroyed:
		var entry := entry_variant as Dictionary
		if not entity_id.is_empty() and str(entry.get("entity_id", "")) == entity_id:
			return

	var r2 := 0.24 * 0.24
	for entry_variant in destroyed:
		var entry := entry_variant as Dictionary
		if str(entry.get("destruct_type", "")) != destruct_type:
			continue
		var entry_pos := _entry_position(entry)
		if entry_pos.distance_squared_to(world_pos) <= r2:
			return

	var rec := {
		"destruct_type": destruct_type,
		"position": [world_pos.x, world_pos.y, world_pos.z],
	}
	if not entity_id.is_empty():
		rec["entity_id"] = entity_id
	destroyed.append(rec)
	_mark_chunk_dirty(chunk_data)


func save_dirty(force: bool) -> void:
	if _dirty_keys.is_empty():
		if force:
			_autosave_timer = 0.0
		return

	if not force and _autosave_timer < AUTOSAVE_INTERVAL:
		return

	var any_dirty := false
	for key in _dirty_keys.keys():
		if not _chunk_cache.has(key):
			continue
		var chunk_data := _chunk_cache[key] as Dictionary
		_save_chunk(chunk_data)
		chunk_data["dirty"] = false
		any_dirty = true

	_dirty_keys.clear()
	_autosave_timer = 0.0
	if any_dirty:
		_write_meta(true)


func _chunk_key(coord: Vector2i) -> String:
	return "%d_%d" % [coord.x, coord.y]


func _chunk_path(coord: Vector2i) -> String:
	return "%s/%s.json" % [chunks_dir, _chunk_key(coord)]


func _world_to_chunk(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / float(chunk_size)),
		floori(world_pos.z / float(chunk_size))
	)


func _ensure_world_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(world_dir)
	DirAccess.make_dir_recursive_absolute(chunks_dir)


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
		"destroyed": [],
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
				if dict.get("destroyed", []) is Array:
					chunk_data["destroyed"] = (dict.get("destroyed", []) as Array).duplicate(true)

	_normalize_chunk_data(chunk_data)

	_chunk_cache[key] = chunk_data
	return chunk_data


func _save_chunk(chunk_data: Dictionary) -> void:
	var coord := chunk_data.get("coord", Vector2i.ZERO) as Vector2i
	var added := chunk_data.get("added", []) as Array
	var removed := chunk_data.get("removed", []) as Array
	var destroyed := chunk_data.get("destroyed", []) as Array
	var path := _chunk_path(coord)

	if added.is_empty() and removed.is_empty() and destroyed.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return

	var payload := {
		"version": DATA_VERSION,
		"chunk": [coord.x, coord.y],
		"added": added,
		"removed": removed,
		"destroyed": destroyed,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "\t"))


func _mark_chunk_dirty(chunk_data: Dictionary) -> void:
	chunk_data["dirty"] = true
	var coord := chunk_data.get("coord", Vector2i.ZERO) as Vector2i
	_dirty_keys[_chunk_key(coord)] = true


func _normalize_chunk_data(chunk_data: Dictionary) -> void:
	var added_in := chunk_data.get("added", []) as Array
	var added_seen: Dictionary = {}
	var added_out: Array = []
	for entry_variant in added_in:
		var entry := entry_variant as Dictionary
		var build_id := str(entry.get("build_id", ""))
		var pos := _entry_position(entry)
		var key := "%s|%.3f|%.3f" % [build_id, pos.x, pos.z]
		if added_seen.has(key):
			continue
		added_seen[key] = true
		added_out.append(entry)
	chunk_data["added"] = added_out

	var removed_in := chunk_data.get("removed", []) as Array
	var removed_seen: Dictionary = {}
	var removed_out: Array = []
	for entry_variant in removed_in:
		var entry := entry_variant as Dictionary
		var entity_id := str(entry.get("entity_id", ""))
		var key := entity_id
		if key.is_empty():
			var build_id := str(entry.get("build_id", ""))
			var pos := _entry_position(entry)
			key = "%s|%.3f|%.3f|%s" % [build_id, pos.x, pos.z, str(entry.get("name", ""))]
		if removed_seen.has(key):
			continue
		removed_seen[key] = true
		removed_out.append(entry)
	chunk_data["removed"] = removed_out

	var destroyed_in := chunk_data.get("destroyed", []) as Array
	var destroyed_seen: Dictionary = {}
	var destroyed_out: Array = []
	for entry_variant in destroyed_in:
		var entry := entry_variant as Dictionary
		var entity_id := str(entry.get("entity_id", ""))
		var key := entity_id
		if key.is_empty():
			var destruct_type := str(entry.get("destruct_type", ""))
			var pos := _entry_position(entry)
			key = "%s|%.3f|%.3f" % [destruct_type, pos.x, pos.z]
		if destroyed_seen.has(key):
			continue
		destroyed_seen[key] = true
		destroyed_out.append(entry)
	chunk_data["destroyed"] = destroyed_out


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
