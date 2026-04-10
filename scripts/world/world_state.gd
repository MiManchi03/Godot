extends RefCounted
class_name WorldState

const DATA_VERSION := 2
const AUTOSAVE_INTERVAL := 3.0
const INVALID_CHUNK_COORD := Vector2i(1 << 30, 1 << 30)

var world_seed: int
var chunk_size: int
var world_dir: String
var chunks_dir: String
var meta_path: String
var housing_path: String

var _chunk_cache: Dictionary = {}
var _dirty_keys: Dictionary = {}
var _autosave_timer: float = 0.0
var _player_position_cache: Dictionary = {}
var _villager_chunk_index: Dictionary = {}
var _house_occupancy: Dictionary = {}
var _villager_housing: Dictionary = {}


func _init(seed: int, chunk_span: int) -> void:
	world_seed = seed
	chunk_size = chunk_span
	world_dir = "user://worlds/%d" % world_seed
	chunks_dir = "%s/buildings" % world_dir
	meta_path = "%s/meta.json" % world_dir
	housing_path = "%s/housing.json" % world_dir
	_ensure_world_dirs()
	_write_meta(false)
	_load_player_position()
	_load_housing_data()


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
		"villagers": (chunk_data.get("villagers", []) as Array).duplicate(true),
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
	if build_id == "road":
		var target_cell := Vector2i(roundi(world_pos.x), roundi(world_pos.z))
		for i in range(added.size() - 1, -1, -1):
			var entry := added[i] as Dictionary
			if str(entry.get("build_id", "")) != "road":
				continue
			var entry_pos := _entry_position(entry)
			var entry_cell := Vector2i(roundi(entry_pos.x), roundi(entry_pos.z))
			if entry_cell == target_cell:
				added.remove_at(i)
				_mark_chunk_dirty(chunk_data)
				return true
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
	if build_id == "road":
		var road_cell := Vector2i(roundi(world_pos.x), roundi(world_pos.z))
		for entry_variant in removed:
			var entry := entry_variant as Dictionary
			if str(entry.get("build_id", "")) != "road":
				continue
			var entry_pos := _entry_position(entry)
			var entry_cell := Vector2i(roundi(entry_pos.x), roundi(entry_pos.z))
			if entry_cell == road_cell:
				return
		var rem_road := {
			"build_id": "road",
			"position": [float(road_cell.x), world_pos.y, float(road_cell.y)],
			"name": node_name,
			"entity_id": "road|%d|%d" % [road_cell.x, road_cell.y],
		}
		removed.append(rem_road)
		_mark_chunk_dirty(chunk_data)
		return

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


func upsert_villager_state(entity_id: String, world_pos: Vector3, rotation_y: float, task_start_id: String, task_end_id: String, carrying_item: bool, task_state: int, origin_chunk: Vector2i = INVALID_CHUNK_COORD) -> void:
	if entity_id.is_empty():
		return
	if world_pos == Vector3.ZERO:
		return
	
	# Use origin chunk if provided, otherwise calculate from position
	var target_chunk := origin_chunk
	if target_chunk == INVALID_CHUNK_COORD:
		# Use current position to determine chunk
		target_chunk = _world_to_chunk(world_pos)
	
	_remove_villager_entity_fast(entity_id)
	
	var new_entry := {
		"entity_id": entity_id,
		"position": [world_pos.x, world_pos.y, world_pos.z],
		"rotation_y": rotation_y,
		"task_start_build_id": task_start_id,
		"task_end_build_id": task_end_id,
		"carrying_item": carrying_item,
		"task_state": task_state,
	}
	new_entry["origin_chunk"] = [target_chunk.x, target_chunk.y]

	# Insert into target chunk
	var chunk_data := _load_chunk(target_chunk)
	var villagers := chunk_data.get("villagers", []) as Array
	villagers.append(new_entry)
	_villager_chunk_index[entity_id] = _chunk_key(target_chunk)
	_mark_chunk_dirty(chunk_data)


func _remove_villager_entity_fast(entity_id: String) -> void:
	if entity_id.is_empty():
		return
	var indexed_chunk_key := str(_villager_chunk_index.get(entity_id, ""))
	if not indexed_chunk_key.is_empty():
		var coord := _coord_from_chunk_key(indexed_chunk_key)
		if coord != INVALID_CHUNK_COORD:
			var chunk_data := _load_chunk(coord)
			if _remove_entity_from_chunk_data(chunk_data, entity_id):
				_villager_chunk_index.erase(entity_id)
				return
		_villager_chunk_index.erase(entity_id)
	# Fallback path for old data/index misses.
	for key in _chunk_cache.keys():
		var cached := _chunk_cache[key] as Dictionary
		if _remove_entity_from_chunk_data(cached, entity_id):
			_villager_chunk_index.erase(entity_id)
			return


func _remove_entity_from_chunk_data(chunk_data: Dictionary, entity_id: String) -> bool:
	var villagers_old := chunk_data.get("villagers", []) as Array
	var removed := false
	for i in range(villagers_old.size() - 1, -1, -1):
		var old_entry := villagers_old[i] as Dictionary
		if str(old_entry.get("entity_id", "")) == entity_id:
			villagers_old.remove_at(i)
			removed = true
	if removed:
		_mark_chunk_dirty(chunk_data)
	return removed


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
	_save_player_position_to_disk()


func save_player_position(pos_data: Dictionary) -> void:
	var pos_arr := pos_data.get("position", []) as Array
	if pos_arr.size() >= 3:
		var y := float(pos_arr[1])
		if y < -20.0:
			return  # 防止保存无效的Y位置
	_player_position_cache = pos_data.duplicate(true)
	_save_player_position_to_disk()


func _load_player_position() -> void:
	var player_path = "%s/player.json" % world_dir
	if FileAccess.file_exists(player_path):
		var f = FileAccess.open(player_path, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_player_position_cache = parsed as Dictionary


func _save_player_position_to_disk() -> void:
	if _player_position_cache.is_empty():
		return
	var player_path = "%s/player.json" % world_dir
	var f = FileAccess.open(player_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_player_position_cache, "\t"))


func _load_housing_data() -> void:
	_house_occupancy.clear()
	_villager_housing.clear()
	if not FileAccess.file_exists(housing_path):
		return
	var f = FileAccess.open(housing_path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return
	var data := parsed as Dictionary
	var houses_raw = data.get("houses", {})
	if houses_raw is Dictionary:
		for house_key in (houses_raw as Dictionary).keys():
			var house_id := str(house_key)
			var villager_id := str((houses_raw as Dictionary).get(house_key, ""))
			if house_id.is_empty() or villager_id.is_empty():
				continue
			_house_occupancy[house_id] = villager_id
			_villager_housing[villager_id] = house_id


func _save_housing_data() -> void:
	var payload := {
		"version": DATA_VERSION,
		"houses": _house_occupancy,
	}
	var f = FileAccess.open(housing_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "\t"))


func get_player_position() -> Dictionary:
	return _player_position_cache.duplicate(true)


func assign_villager_to_house(house_entity_id: String, villager_entity_id: String) -> bool:
	if house_entity_id.is_empty() or villager_entity_id.is_empty():
		return false

	var old_house_for_villager := str(_villager_housing.get(villager_entity_id, ""))
	if not old_house_for_villager.is_empty() and old_house_for_villager != house_entity_id:
		_house_occupancy.erase(old_house_for_villager)

	var old_villager_in_house := str(_house_occupancy.get(house_entity_id, ""))
	if not old_villager_in_house.is_empty() and old_villager_in_house != villager_entity_id:
		_villager_housing.erase(old_villager_in_house)

	_house_occupancy[house_entity_id] = villager_entity_id
	_villager_housing[villager_entity_id] = house_entity_id
	_save_housing_data()
	return true


func remove_house_occupant(house_entity_id: String) -> bool:
	if house_entity_id.is_empty():
		return false
	if not _house_occupancy.has(house_entity_id):
		return false
	var villager_entity_id := str(_house_occupancy.get(house_entity_id, ""))
	_house_occupancy.erase(house_entity_id)
	if not villager_entity_id.is_empty():
		_villager_housing.erase(villager_entity_id)
	_save_housing_data()
	return true


func get_house_occupant(house_entity_id: String) -> String:
	if house_entity_id.is_empty():
		return ""
	return str(_house_occupancy.get(house_entity_id, ""))


func get_villager_house(villager_entity_id: String) -> String:
	if villager_entity_id.is_empty():
		return ""
	return str(_villager_housing.get(villager_entity_id, ""))


func get_house_occupancy_snapshot() -> Dictionary:
	return _house_occupancy.duplicate(true)


func _chunk_key(coord: Vector2i) -> String:
	return "%d_%d" % [coord.x, coord.y]


func _coord_from_chunk_key(key: String) -> Vector2i:
	var parts := key.split("_")
	if parts.size() != 2:
		return INVALID_CHUNK_COORD
	return Vector2i(int(parts[0]), int(parts[1]))


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
		"villagers": [],
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
				if dict.get("villagers", []) is Array:
					chunk_data["villagers"] = (dict.get("villagers", []) as Array).duplicate(true)

	var normalized_changed := _normalize_chunk_data(chunk_data)
	if normalized_changed:
		_mark_chunk_dirty(chunk_data)
	if _migrate_legacy_villager_ids(chunk_data):
		_mark_chunk_dirty(chunk_data)
	if _rebucket_villagers_to_origin_chunk(chunk_data):
		_mark_chunk_dirty(chunk_data)
	_index_chunk_villagers(chunk_data)

	_chunk_cache[key] = chunk_data
	return chunk_data


func _save_chunk(chunk_data: Dictionary) -> void:
	var coord := chunk_data.get("coord", Vector2i.ZERO) as Vector2i
	var added := chunk_data.get("added", []) as Array
	var removed := chunk_data.get("removed", []) as Array
	var destroyed := chunk_data.get("destroyed", []) as Array
	var villagers := chunk_data.get("villagers", []) as Array
	var path := _chunk_path(coord)
	
	if added.is_empty() and removed.is_empty() and destroyed.is_empty() and villagers.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return

	var payload := {
		"version": DATA_VERSION,
		"chunk": [coord.x, coord.y],
		"added": added,
		"removed": removed,
		"destroyed": destroyed,
		"villagers": villagers,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "\t"))


func _mark_chunk_dirty(chunk_data: Dictionary) -> void:
	chunk_data["dirty"] = true
	var coord := chunk_data.get("coord", Vector2i.ZERO) as Vector2i
	_dirty_keys[_chunk_key(coord)] = true


func _index_chunk_villagers(chunk_data: Dictionary) -> void:
	var coord := chunk_data.get("coord", Vector2i.ZERO) as Vector2i
	var key := _chunk_key(coord)
	var villagers := chunk_data.get("villagers", []) as Array
	for entry_variant in villagers:
		var entry := entry_variant as Dictionary
		var entity_id := str(entry.get("entity_id", ""))
		if entity_id.is_empty():
			continue
		_villager_chunk_index[entity_id] = key


func _normalize_chunk_data(chunk_data: Dictionary) -> bool:
	var changed := false
	var added_in := chunk_data.get("added", []) as Array
	var added_seen: Dictionary = {}
	var added_out: Array = []
	for entry_variant in added_in:
		var entry := entry_variant as Dictionary
		var build_id := str(entry.get("build_id", ""))
		var pos := _entry_position(entry)
		if build_id == "road":
			var road_cell := Vector2i(roundi(pos.x), roundi(pos.z))
			entry["position"] = [float(road_cell.x), pos.y, float(road_cell.y)]
			pos = _entry_position(entry)
		var key := "%s|%.3f|%.3f" % [build_id, pos.x, pos.z]
		if added_seen.has(key):
			continue
		added_seen[key] = true
		added_out.append(entry)
	if added_out.size() != added_in.size():
		changed = true
	chunk_data["added"] = added_out

	var removed_in := chunk_data.get("removed", []) as Array
	var removed_seen: Dictionary = {}
	var removed_out: Array = []
	for entry_variant in removed_in:
		var entry := entry_variant as Dictionary
		var rem_build_id := str(entry.get("build_id", ""))
		if rem_build_id == "road":
			var rem_pos := _entry_position(entry)
			var rem_cell := Vector2i(roundi(rem_pos.x), roundi(rem_pos.z))
			entry["position"] = [float(rem_cell.x), rem_pos.y, float(rem_cell.y)]
			entry["entity_id"] = "road|%d|%d" % [rem_cell.x, rem_cell.y]
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
	if removed_out.size() != removed_in.size():
		changed = true
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
	if destroyed_out.size() != destroyed_in.size():
		changed = true
	chunk_data["destroyed"] = destroyed_out

	var villagers_in := chunk_data.get("villagers", []) as Array
	var villagers_seen: Dictionary = {}
	var villagers_out: Array = []
	for entry_variant in villagers_in:
		var entry := entry_variant as Dictionary
		var entity_id := str(entry.get("entity_id", ""))
		if entity_id.is_empty():
			continue
		var pos := _entry_position(entry)
		if pos == Vector3.ZERO:
			changed = true
			continue
		# 防止保存无效Y位置（玩家/村民坠落问题）
		if pos.y < -20.0:
			changed = true
			continue
		var key := entity_id
		if villagers_seen.has(key):
			changed = true
			continue
		villagers_seen[key] = true
		villagers_out.append(entry)
	if villagers_out.size() != villagers_in.size():
		changed = true
	chunk_data["villagers"] = villagers_out
	return changed


func _entry_position(entry: Dictionary) -> Vector3:
	var arr = entry.get("position", [])
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


func _villager_entries_equal(a: Dictionary, b: Dictionary) -> bool:
	if str(a.get("entity_id", "")) != str(b.get("entity_id", "")):
		return false
	if str(a.get("task_start_build_id", "")) != str(b.get("task_start_build_id", "")):
		return false
	if str(a.get("task_end_build_id", "")) != str(b.get("task_end_build_id", "")):
		return false
	if bool(a.get("carrying_item", false)) != bool(b.get("carrying_item", false)):
		return false
	if int(a.get("task_state", 0)) != int(b.get("task_state", 0)):
		return false
	if absf(float(a.get("rotation_y", 0.0)) - float(b.get("rotation_y", 0.0))) > 0.01:
		return false
	var pa := _entry_position(a)
	var pb := _entry_position(b)
	if pa.distance_squared_to(pb) > 0.01 * 0.01:
		return false
	return true


func _villager_origin_chunk_from_id(entity_id: String, fallback_pos: Vector3) -> Vector2i:
	var parts := entity_id.split("|")
	if parts.size() >= 4:
		if parts[3] == "villager":
			var cx := int(parts[1])
			var cz := int(parts[2])
			return Vector2i(cx, cz)
	return _world_to_chunk(fallback_pos)


func _origin_chunk_from_entry(entry: Dictionary, fallback_pos: Vector3) -> Vector2i:
	var entity_id := str(entry.get("entity_id", ""))
	if not entity_id.is_empty():
		var parts := entity_id.split("|")
		if parts.size() >= 4 and parts[3] == "villager":
			return Vector2i(int(parts[1]), int(parts[2]))
	var arr = entry.get("origin_chunk", null)
	if arr is Array:
		var vec := arr as Array
		if vec.size() >= 2:
			return Vector2i(int(vec[0]), int(vec[1]))
	return _villager_origin_chunk_from_id(entity_id, fallback_pos)


func _rebucket_villagers_to_origin_chunk(chunk_data: Dictionary) -> bool:
	var coord := chunk_data.get("coord", Vector2i.ZERO) as Vector2i
	var villagers := chunk_data.get("villagers", []) as Array
	if villagers.is_empty():
		return false
	var keep: Array = []
	var moved := false
	for entry_variant in villagers:
		var entry := entry_variant as Dictionary
		var entity_id := str(entry.get("entity_id", ""))
		var pos := _entry_position(entry)
		var origin := _origin_chunk_from_entry(entry, pos)
		entry["origin_chunk"] = [origin.x, origin.y]
		if origin == coord:
			keep.append(entry)
			continue
		var target := _load_chunk(origin)
		var target_villagers := target.get("villagers", []) as Array
		target_villagers.append(entry.duplicate(true))
		_mark_chunk_dirty(target)
		moved = true
	if moved:
		chunk_data["villagers"] = keep
		_index_chunk_villagers(chunk_data)
	return moved


func _migrate_legacy_villager_ids(chunk_data: Dictionary) -> bool:
	var villagers := chunk_data.get("villagers", []) as Array
	if villagers.is_empty():
		return false
	var changed := false
	var coord := chunk_data.get("coord", Vector2i.ZERO) as Vector2i
	for entry_variant in villagers:
		var entry := entry_variant as Dictionary
		var entity_id := str(entry.get("entity_id", ""))
		if entity_id.find("|villager|Village|") != -1:
			var legacy_name := str(entry.get("legacy_name", ""))
			if legacy_name.is_empty():
				var parts := entity_id.split("|")
				if parts.size() >= 5:
					legacy_name = "Villager_%s" % parts[4]
			if not legacy_name.is_empty():
				entry["legacy_name"] = legacy_name
				var pos := _entry_position(entry)
				entry["entity_id"] = "%d|%d|%d|villager|%s|%.3f|%.3f" % [world_seed + 2000, coord.x, coord.y, legacy_name, pos.x, pos.z]
			changed = true
	return changed
