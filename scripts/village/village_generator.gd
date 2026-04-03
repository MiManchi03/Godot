extends RefCounted
class_name VillageGenerator

const VILLAGER_SCRIPT := preload("res://scripts/npc/villager.gd")

enum VillageScale {
	SMALL,
	MEDIUM,
	LARGE,
}

enum BuildingType {
	HOUSE,
	WORKSHOP,
	WAREHOUSE,
	MARKET,
	WELL,
	FARM,
	TOWER,
	BARRACK,
	CAMPFIRE,
	FENCE_POST,
	ROAD,
}

const KENNEY_BUILDING_SCENE_PATHS := {
	BuildingType.HOUSE: [
		"res://assets/buildings/kenney_building_kit/house_a.glb",
		"res://assets/buildings/kenney_building_kit/house_b.glb",
		"res://assets/buildings/kenney_building_kit/house_c.glb",
	],
	BuildingType.WORKSHOP: [
		"res://assets/buildings/kenney_building_kit/workshop_a.glb",
		"res://assets/buildings/kenney_building_kit/workshop_b.glb",
	],
	BuildingType.WAREHOUSE: [
		"res://assets/buildings/kenney_building_kit/warehouse_a.glb",
		"res://assets/buildings/kenney_building_kit/warehouse_b.glb",
	],
	BuildingType.MARKET: [
		"res://assets/buildings/kenney_building_kit/market_a.glb",
		"res://assets/buildings/kenney_building_kit/market_b.glb",
	],
	BuildingType.WELL: [
		"res://assets/buildings/kenney_building_kit/well_a.glb",
	],
	BuildingType.FARM: [
		"res://assets/buildings/kenney_building_kit/farm_a.glb",
		"res://assets/buildings/kenney_building_kit/farm_b.glb",
	],
	BuildingType.TOWER: [
		"res://assets/buildings/kenney_building_kit/tower_a.glb",
	],
	BuildingType.BARRACK: [
		"res://assets/buildings/kenney_building_kit/barrack_a.glb",
		"res://assets/buildings/kenney_building_kit/barrack_b.glb",
	],
}

var base_seed: int
var placed_villages: Array[Vector3] = []
var starter_village_spawned: bool = false


func _init(seed: int = 4531) -> void:
	base_seed = seed


func try_spawn_village(parent: Node3D, chunk_coord: Vector2i, chunk_size: int, biome: BiomeGenerator.Biome) -> void:
	if not starter_village_spawned and chunk_coord == Vector2i.ZERO:
		_spawn_starter_village(parent, chunk_coord)

	if biome != BiomeGenerator.Biome.PLAINS:
		return

	if not _is_village_anchor(chunk_coord):
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_from_anchor(chunk_coord)

	if rng.randf() > 0.38:
		return

	var half_size := chunk_size * 0.5
	var village_local_origin := Vector3(
		rng.randf_range(-half_size + 6.0, half_size - 6.0),
		0.0,
		rng.randf_range(-half_size + 6.0, half_size - 6.0)
	)
	var village_world_origin := parent.global_position + village_local_origin

	if not _is_far_enough(village_world_origin, 95.0):
		return

	var scale := _pick_village_scale(rng)
	var village := _create_scale_village(rng, scale)
	village.position = village_local_origin
	parent.add_child(village)
	placed_villages.append(village_world_origin)


func _spawn_starter_village(parent: Node3D, chunk_coord: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_from_anchor(chunk_coord) ^ 0x71A9

	var starter_local_origin := Vector3(9.5, 0.0, 7.5)
	var starter_world_origin := parent.global_position + starter_local_origin

	if not _is_far_enough(starter_world_origin, 40.0):
		return

	var starter_village := _create_scale_village(rng, VillageScale.MEDIUM)
	starter_village.name = "StarterVillage"
	starter_village.position = starter_local_origin
	parent.add_child(starter_village)

	placed_villages.append(starter_world_origin)
	starter_village_spawned = true


func _is_village_anchor(chunk_coord: Vector2i) -> bool:
	var anchor_size := 4
	return chunk_coord.x % anchor_size == 0 and chunk_coord.y % anchor_size == 0


func _is_far_enough(candidate: Vector3, min_distance: float) -> bool:
	for v in placed_villages:
		if v.distance_to(candidate) < min_distance:
			return false
	return true


func _pick_village_scale(rng: RandomNumberGenerator) -> VillageScale:
	var roll := rng.randf()
	if roll < 0.55:
		return VillageScale.SMALL
	if roll < 0.88:
		return VillageScale.MEDIUM
	return VillageScale.LARGE


func _create_scale_village(rng: RandomNumberGenerator, scale: VillageScale) -> Node3D:
	var village := Node3D.new()
	village.name = "Village"
	var type_counts := {}

	var footprint_radius := 10.0
	var building_count := 6

	match scale:
		VillageScale.SMALL:
			footprint_radius = rng.randf_range(8.0, 10.5)
			building_count = rng.randi_range(5, 7)
		VillageScale.MEDIUM:
			footprint_radius = rng.randf_range(12.0, 15.0)
			building_count = rng.randi_range(8, 11)
		VillageScale.LARGE:
			footprint_radius = rng.randf_range(16.0, 21.0)
			building_count = rng.randi_range(12, 17)

	var layout_positions := _radial_positions(rng, building_count, footprint_radius)
	var village_center_offset := Vector3.ZERO

	for local_pos in layout_positions:
		var building_type := _pick_building_type(rng, scale)
		var building := _create_building_variant(rng, building_type)
		if building == null:
			continue
		_tag_building_identity(building, building_type, type_counts)

		building.position = local_pos
		building.rotate_y(rng.randf_range(0.0, TAU))
		village.add_child(building)

	var road_cells: Dictionary = {}
	_generate_village_roads(village, layout_positions, footprint_radius, road_cells, type_counts)

	var campfire := _create_campfire()
	_tag_building_identity(campfire, BuildingType.CAMPFIRE, type_counts)
	campfire.position = village_center_offset
	village.add_child(campfire)

	var post_count := int(clampf(footprint_radius * 0.8, 8.0, 18.0))
	for i in range(post_count):
		var angle := (TAU * float(i) / float(post_count)) + rng.randf_range(-0.12, 0.12)
		var radius := footprint_radius + rng.randf_range(-0.7, 1.2)
		var post := _create_fence_post()
		_tag_building_identity(post, BuildingType.FENCE_POST, type_counts)
		post.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		post.rotate_y(rng.randf_range(0.0, TAU))
		village.add_child(post)

	_spawn_villagers(village, rng, building_count, road_cells, layout_positions)

	return village


func _radial_positions(rng: RandomNumberGenerator, count: int, radius: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if count <= 0:
		return points

	for i in range(count):
		var angle := TAU * float(i) / float(count)
		angle += rng.randf_range(-0.28, 0.28)
		var ring_radius := rng.randf_range(radius * 0.45, radius)
		points.append(Vector3(cos(angle) * ring_radius, 0.0, sin(angle) * ring_radius))

	return points


func _pick_building_type(rng: RandomNumberGenerator, scale: VillageScale) -> BuildingType:
	var roll := rng.randf()
	if scale == VillageScale.SMALL:
		if roll < 0.40:
			return BuildingType.HOUSE
		if roll < 0.56:
			return BuildingType.WORKSHOP
		if roll < 0.70:
			return BuildingType.WAREHOUSE
		if roll < 0.80:
			return BuildingType.WELL
		if roll < 0.90:
			return BuildingType.FARM
		return BuildingType.MARKET

	if scale == VillageScale.MEDIUM:
		if roll < 0.30:
			return BuildingType.HOUSE
		if roll < 0.47:
			return BuildingType.WORKSHOP
		if roll < 0.60:
			return BuildingType.WAREHOUSE
		if roll < 0.72:
			return BuildingType.MARKET
		if roll < 0.82:
			return BuildingType.WELL
		if roll < 0.92:
			return BuildingType.FARM
		return BuildingType.BARRACK

	if roll < 0.25:
		return BuildingType.HOUSE
	if roll < 0.39:
		return BuildingType.WORKSHOP
	if roll < 0.53:
		return BuildingType.WAREHOUSE
	if roll < 0.66:
		return BuildingType.MARKET
	if roll < 0.76:
		return BuildingType.BARRACK
	if roll < 0.86:
		return BuildingType.TOWER
	if roll < 0.93:
		return BuildingType.WELL
	return BuildingType.FARM


func _create_building_variant(rng: RandomNumberGenerator, building_type: BuildingType) -> Node3D:
	var kenney_building := _try_create_kenney_building(rng, building_type)
	if kenney_building != null:
		return kenney_building

	match building_type:
		BuildingType.HOUSE:
			return _create_house_variant(rng)
		BuildingType.WORKSHOP:
			return _create_workshop_variant(rng)
		BuildingType.WAREHOUSE:
			return _create_warehouse_variant(rng)
		BuildingType.MARKET:
			return _create_market_variant(rng)
		BuildingType.WELL:
			return _create_well_variant(rng)
		BuildingType.FARM:
			return _create_farm_plot_variant(rng)
		BuildingType.TOWER:
			return _create_tower_variant(rng)
		BuildingType.BARRACK:
			return _create_barrack_variant(rng)
		BuildingType.CAMPFIRE:
			return _create_campfire()
		BuildingType.FENCE_POST:
			return _create_fence_post()
		BuildingType.ROAD:
			return _create_road_tile_variant(rng)
		_:
			return _create_house_variant(rng)


func _try_create_kenney_building(rng: RandomNumberGenerator, building_type: BuildingType) -> Node3D:
	if not KENNEY_BUILDING_SCENE_PATHS.has(building_type):
		return null

	var path_list: Array = KENNEY_BUILDING_SCENE_PATHS[building_type]
	if path_list.is_empty():
		return null

	var start_index := rng.randi_range(0, path_list.size() - 1)
	for offset in range(path_list.size()):
		var index := (start_index + offset) % path_list.size()
		var scene_path: String = path_list[index]
		if not ResourceLoader.exists(scene_path):
			continue
		var resource := load(scene_path)
		if resource is PackedScene:
			var instance := (resource as PackedScene).instantiate()
			if instance is Node3D:
				instance.name = _building_type_name(building_type)
				return instance

	return null


func _building_type_name(building_type: BuildingType) -> String:
	match building_type:
		BuildingType.HOUSE:
			return "House"
		BuildingType.WORKSHOP:
			return "Workshop"
		BuildingType.WAREHOUSE:
			return "Warehouse"
		BuildingType.MARKET:
			return "Market"
		BuildingType.WELL:
			return "Well"
		BuildingType.FARM:
			return "Farm"
		BuildingType.TOWER:
			return "Tower"
		BuildingType.BARRACK:
			return "Barrack"
		BuildingType.CAMPFIRE:
			return "Campfire"
		BuildingType.FENCE_POST:
			return "FencePost"
		BuildingType.ROAD:
			return "Road"
		_:
			return "Building"


func _building_type_id(building_type: BuildingType) -> String:
	match building_type:
		BuildingType.HOUSE:
			return "house"
		BuildingType.WORKSHOP:
			return "workshop"
		BuildingType.WAREHOUSE:
			return "warehouse"
		BuildingType.MARKET:
			return "market"
		BuildingType.WELL:
			return "well"
		BuildingType.FARM:
			return "farm"
		BuildingType.TOWER:
			return "tower"
		BuildingType.BARRACK:
			return "barrack"
		BuildingType.CAMPFIRE:
			return "campfire"
		BuildingType.FENCE_POST:
			return "fencepost"
		BuildingType.ROAD:
			return "road"
		_:
			return ""


func _tag_building_identity(building: Node3D, building_type: BuildingType, type_counts: Dictionary) -> void:
	var type_name := _building_type_name(building_type)
	var type_id := _building_type_id(building_type)
	if type_id.is_empty():
		return

	var count := int(type_counts.get(type_id, 0)) + 1
	type_counts[type_id] = count

	building.name = "%s_%02d" % [type_name, count]
	building.set_meta("build_id", type_id)
	building.set_meta("build_type_name", type_name)


func _create_house_variant(rng: RandomNumberGenerator) -> Node3D:
	var width := rng.randf_range(4.0, 6.2)
	var height := rng.randf_range(2.4, 3.2)
	var depth := rng.randf_range(3.5, 5.4)
	var wall_color := Color(0.78, 0.72, 0.60).lerp(Color(0.58, 0.56, 0.52), rng.randf_range(0.0, 0.5))
	var roof_color := Color(0.57, 0.23, 0.16).lerp(Color(0.37, 0.24, 0.18), rng.randf_range(0.0, 0.5))
	return _make_building_box_prism("House", width, height, depth, wall_color, roof_color)


func _create_workshop_variant(rng: RandomNumberGenerator) -> Node3D:
	var width := rng.randf_range(4.2, 5.8)
	var height := rng.randf_range(2.3, 3.0)
	var depth := rng.randf_range(3.7, 4.8)
	var wall_color := Color(0.60, 0.53, 0.42).lerp(Color(0.52, 0.47, 0.39), rng.randf_range(0.0, 0.4))
	var roof_color := Color(0.38, 0.22, 0.12).lerp(Color(0.45, 0.27, 0.15), rng.randf_range(0.0, 0.4))
	var root := _make_building_box_flat("Workshop", width, height, depth, wall_color, roof_color)
	var chimney := MeshInstance3D.new()
	var chimney_mesh := BoxMesh.new()
	chimney_mesh.size = Vector3(0.5, 1.2, 0.5)
	chimney.mesh = chimney_mesh
	chimney.position = Vector3(width * 0.3, height + 0.75, -depth * 0.15)
	chimney.material_override = _material(Color(0.34, 0.34, 0.34))
	root.add_child(chimney)
	return root


func _create_warehouse_variant(rng: RandomNumberGenerator) -> Node3D:
	var width := rng.randf_range(5.4, 7.8)
	var height := rng.randf_range(2.9, 3.8)
	var depth := rng.randf_range(4.6, 6.8)
	var wall_color := Color(0.54, 0.52, 0.50).lerp(Color(0.64, 0.60, 0.53), rng.randf_range(0.0, 0.4))
	var roof_color := Color(0.40, 0.24, 0.17).lerp(Color(0.30, 0.19, 0.15), rng.randf_range(0.0, 0.5))
	return _make_building_box_prism("Warehouse", width, height, depth, wall_color, roof_color)


func _create_market_variant(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "Market"

	var pad := MeshInstance3D.new()
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(rng.randf_range(5.2, 7.0), 0.25, rng.randf_range(4.4, 6.8))
	pad.mesh = pad_mesh
	pad.position = Vector3(0.0, 0.125, 0.0)
	pad.material_override = _material(Color(0.60, 0.55, 0.46))
	root.add_child(pad)

	var stall_count := rng.randi_range(2, 4)
	for i in range(stall_count):
		var stall := _create_market_stall(rng)
		var angle := TAU * float(i) / float(stall_count) + rng.randf_range(-0.2, 0.2)
		stall.position = Vector3(cos(angle) * 1.7, 0.0, sin(angle) * 1.7)
		stall.rotate_y(angle + PI * 0.5)
		root.add_child(stall)

	_add_box_collision(root, Vector3(pad_mesh.size.x, 0.25, pad_mesh.size.z), Vector3(0.0, 0.125, 0.0))
	return root


func _create_well_variant(rng: RandomNumberGenerator) -> Node3D:
	var root := _create_well()
	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(2.6, 0.9, 2.2)
	roof.mesh = roof_mesh
	roof.position = Vector3(0.0, 2.0, 0.0)
	roof.rotation = Vector3(0.0, deg_to_rad(90.0), 0.0)
	roof.material_override = _material(Color(0.43, 0.20, 0.14).lerp(Color(0.35, 0.16, 0.12), rng.randf_range(0.0, 0.4)))
	root.add_child(roof)
	return root


func _create_farm_plot_variant(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "FarmPlot"

	var width := rng.randf_range(4.0, 7.0)
	var depth := rng.randf_range(3.8, 6.5)
	var soil := MeshInstance3D.new()
	var soil_mesh := BoxMesh.new()
	soil_mesh.size = Vector3(width, 0.2, depth)
	soil.mesh = soil_mesh
	soil.position = Vector3(0.0, 0.1, 0.0)
	soil.material_override = _material(Color(0.39, 0.25, 0.16))
	root.add_child(soil)

	var crop_count := rng.randi_range(8, 18)
	for _i in range(crop_count):
		var crop := MeshInstance3D.new()
		var crop_mesh := BoxMesh.new()
		crop_mesh.size = Vector3(0.14, rng.randf_range(0.35, 0.7), 0.14)
		crop.mesh = crop_mesh
		crop.position = Vector3(
			rng.randf_range(-width * 0.43, width * 0.43),
			crop_mesh.size.y * 0.5 + 0.2,
			rng.randf_range(-depth * 0.43, depth * 0.43)
		)
		crop.material_override = _material(Color(0.31, 0.66, 0.24).lerp(Color(0.50, 0.72, 0.30), rng.randf_range(0.0, 0.5)))
		root.add_child(crop)

	_add_box_collision(root, Vector3(width, 0.2, depth), Vector3(0.0, 0.1, 0.0))
	return root


func _create_tower_variant(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "Tower"

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = rng.randf_range(1.2, 1.8)
	base_mesh.bottom_radius = base_mesh.top_radius
	base_mesh.height = rng.randf_range(5.0, 7.2)
	base.mesh = base_mesh
	base.position = Vector3(0.0, base_mesh.height * 0.5, 0.0)
	base.material_override = _material(Color(0.54, 0.54, 0.56))
	root.add_child(base)

	var cap := MeshInstance3D.new()
	var cap_mesh := PrismMesh.new()
	cap_mesh.size = Vector3(base_mesh.top_radius * 2.3, 1.2, base_mesh.top_radius * 2.3)
	cap.mesh = cap_mesh
	cap.position = Vector3(0.0, base_mesh.height + 0.8, 0.0)
	cap.rotation = Vector3(0.0, deg_to_rad(90.0), 0.0)
	cap.material_override = _material(Color(0.38, 0.20, 0.13))
	root.add_child(cap)

	_add_cylinder_collision(root, base_mesh.top_radius, base_mesh.height, Vector3(0.0, base_mesh.height * 0.5, 0.0))
	return root


func _create_barrack_variant(rng: RandomNumberGenerator) -> Node3D:
	var width := rng.randf_range(6.2, 8.8)
	var height := rng.randf_range(2.8, 3.6)
	var depth := rng.randf_range(4.8, 6.2)
	var wall_color := Color(0.48, 0.52, 0.58).lerp(Color(0.62, 0.63, 0.64), rng.randf_range(0.0, 0.4))
	var roof_color := Color(0.29, 0.22, 0.18).lerp(Color(0.23, 0.23, 0.25), rng.randf_range(0.0, 0.4))
	var root := _make_building_box_prism("Barrack", width, height, depth, wall_color, roof_color)

	for i in range(2):
		var banner := MeshInstance3D.new()
		var banner_mesh := BoxMesh.new()
		banner_mesh.size = Vector3(0.2, 1.0, 0.08)
		banner.mesh = banner_mesh
		banner.position = Vector3((i * 2 - 1) * width * 0.32, 1.2, depth * 0.52)
		banner.material_override = _material(Color(0.74, 0.17, 0.16).lerp(Color(0.22, 0.38, 0.78), rng.randf_range(0.0, 0.3)))
		root.add_child(banner)

	return root


func _create_market_stall(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "Stall"

	var table := MeshInstance3D.new()
	var table_mesh := BoxMesh.new()
	table_mesh.size = Vector3(1.6, 0.25, 1.0)
	table.mesh = table_mesh
	table.position = Vector3(0.0, 0.75, 0.0)
	table.material_override = _material(Color(0.58, 0.36, 0.21))
	root.add_child(table)

	var canopy := MeshInstance3D.new()
	var canopy_mesh := BoxMesh.new()
	canopy_mesh.size = Vector3(1.9, 0.12, 1.2)
	canopy.mesh = canopy_mesh
	canopy.position = Vector3(0.0, 1.6, 0.0)
	canopy.material_override = _material(Color(0.93, 0.62, 0.18).lerp(Color(0.27, 0.56, 0.86), rng.randf_range(0.0, 0.6)))
	root.add_child(canopy)

	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			var leg_mesh := CylinderMesh.new()
			leg_mesh.top_radius = 0.05
			leg_mesh.bottom_radius = 0.05
			leg_mesh.height = 1.2
			leg.mesh = leg_mesh
			leg.position = Vector3(x_sign * 0.72, 1.0, z_sign * 0.42)
			leg.material_override = _material(Color(0.40, 0.25, 0.15))
			root.add_child(leg)

	return root


func _make_building_box_prism(name: String, width: float, height: float, depth: float, wall_color: Color, roof_color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = name

	var walls := MeshInstance3D.new()
	var walls_mesh := BoxMesh.new()
	walls_mesh.size = Vector3(width, height, depth)
	walls.mesh = walls_mesh
	walls.position = Vector3(0.0, height * 0.5, 0.0)
	walls.material_override = _material(wall_color)
	root.add_child(walls)

	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(width + 0.7, maxf(height * 0.6, 1.1), depth + 0.7)
	roof.mesh = roof_mesh
	roof.position = Vector3(0.0, height + roof_mesh.size.y * 0.45, 0.0)
	roof.rotation = Vector3(0.0, deg_to_rad(90.0), 0.0)
	roof.material_override = _material(roof_color)
	root.add_child(roof)

	_add_box_collision(root, Vector3(width * 0.97, height, depth * 0.97), Vector3(0.0, height * 0.5, 0.0))
	return root


func _make_building_box_flat(name: String, width: float, height: float, depth: float, wall_color: Color, roof_color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = name

	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(width, height, depth)
	base.mesh = base_mesh
	base.position = Vector3(0.0, height * 0.5, 0.0)
	base.material_override = _material(wall_color)
	root.add_child(base)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(width + 0.4, 0.35, depth + 0.4)
	roof.mesh = roof_mesh
	roof.position = Vector3(0.0, height + 0.2, 0.0)
	roof.material_override = _material(roof_color)
	root.add_child(roof)

	_add_box_collision(root, Vector3(width * 0.97, height, depth * 0.97), Vector3(0.0, height * 0.5, 0.0))
	return root


func _add_box_collision(root: Node3D, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = position
	body.add_child(collision)


func _add_cylinder_collision(root: Node3D, radius: float, height: float, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	collision.position = position
	body.add_child(collision)


func _create_campfire() -> Node3D:
	var root := Node3D.new()
	root.name = "Campfire"

	var stone_ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.9
	ring_mesh.bottom_radius = 0.9
	ring_mesh.height = 0.18
	stone_ring.mesh = ring_mesh
	stone_ring.position = Vector3(0.0, 0.09, 0.0)
	stone_ring.material_override = _material(Color(0.42, 0.42, 0.44))
	root.add_child(stone_ring)

	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.28
	flame_mesh.height = 0.55
	flame.mesh = flame_mesh
	flame.position = Vector3(0.0, 0.45, 0.0)
	flame.material_override = _material(Color(0.96, 0.47, 0.14), true)
	root.add_child(flame)

	_add_cylinder_collision(root, 0.95, 0.9, Vector3(0.0, 0.45, 0.0))

	return root


func _create_fence_post() -> Node3D:
	var post := Node3D.new()
	post.name = "FencePost"

	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.12
	mesh.bottom_radius = 0.14
	mesh.height = 1.1
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0.0, 0.55, 0.0)
	mesh_instance.material_override = _material(Color(0.48, 0.28, 0.15))
	post.add_child(mesh_instance)

	_add_cylinder_collision(post, 0.14, 1.1, Vector3(0.0, 0.55, 0.0))

	return post


func _create_road_tile_variant(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "Road"

	var base := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.08, 1.0)
	base.mesh = mesh
	base.position = Vector3(0.0, 0.04, 0.0)
	var tint := 0.52 + rng.randf_range(-0.04, 0.06)
	base.material_override = _material(Color(tint, tint * 0.96, tint * 0.88))
	root.add_child(base)

	var edge := MeshInstance3D.new()
	var edge_mesh := BoxMesh.new()
	edge_mesh.size = Vector3(0.94, 0.02, 0.94)
	edge.mesh = edge_mesh
	edge.position = Vector3(0.0, 0.09, 0.0)
	edge.material_override = _material(Color(0.65, 0.63, 0.56))
	root.add_child(edge)

	var lane := MeshInstance3D.new()
	var lane_mesh := BoxMesh.new()
	lane_mesh.size = Vector3(0.28, 0.015, 0.86)
	lane.mesh = lane_mesh
	lane.position = Vector3(0.0, 0.1, 0.0)
	lane.material_override = _material(Color(0.76, 0.72, 0.58))
	root.add_child(lane)

	_add_box_collision(root, Vector3(1.0, 0.12, 1.0), Vector3(0.0, 0.06, 0.0))
	root.set_meta("road", true)
	return root


func _v3_to_cell(v: Vector3) -> Vector2i:
	return Vector2i(roundi(v.x), roundi(v.z))


func _cell_to_v3(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x), 0.0, float(cell.y))


func _add_road_cell(village: Node3D, cell: Vector2i, road_cells: Dictionary, type_counts: Dictionary) -> void:
	if road_cells.has(cell):
		return
	var road_rng := RandomNumberGenerator.new()
	road_rng.seed = int(hash("road|%d|%d" % [cell.x, cell.y]))
	var road := _create_road_tile_variant(road_rng)
	_tag_building_identity(road, BuildingType.ROAD, type_counts)
	road.position = _cell_to_v3(cell)
	village.add_child(road)
	road_cells[cell] = true


func _add_road_line(village: Node3D, from_cell: Vector2i, to_cell: Vector2i, road_cells: Dictionary, type_counts: Dictionary) -> void:
	var x := from_cell.x
	var y := from_cell.y
	while x != to_cell.x:
		_add_road_cell(village, Vector2i(x, y), road_cells, type_counts)
		x += 1 if to_cell.x > x else -1
	while y != to_cell.y:
		_add_road_cell(village, Vector2i(x, y), road_cells, type_counts)
		y += 1 if to_cell.y > y else -1
	_add_road_cell(village, Vector2i(x, y), road_cells, type_counts)


func _generate_village_roads(village: Node3D, layout_positions: Array[Vector3], footprint_radius: float, road_cells: Dictionary, type_counts: Dictionary) -> void:
	var center := Vector2i.ZERO
	_add_road_cell(village, center, road_cells, type_counts)

	var ordered_cells: Array[Vector2i] = []
	for p in layout_positions:
		ordered_cells.append(_v3_to_cell(p))

	ordered_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.length_squared() < b.length_squared()
	)

	var connect_count := mini(ordered_cells.size(), maxi(3, int(footprint_radius * 0.45)))
	for i in range(connect_count):
		var target := ordered_cells[i]
		_add_road_line(village, center, target, road_cells, type_counts)

	for i in range(1, connect_count, 2):
		_add_road_line(village, ordered_cells[i - 1], ordered_cells[i], road_cells, type_counts)


func _spawn_villagers(village: Node3D, rng: RandomNumberGenerator, building_count: int, road_cells: Dictionary, layout_positions: Array[Vector3]) -> void:
	var villager_count := mini(7, maxi(2, 2 + int(building_count / 3)))
	for i in range(villager_count):
		var villager := CharacterBody3D.new()
		villager.name = "Villager_%02d" % [i + 1]
		var body := MeshInstance3D.new()
		var body_mesh := CapsuleMesh.new()
		body_mesh.radius = 0.32
		body_mesh.height = 1.15
		body.mesh = body_mesh
		body.position = Vector3(0.0, 0.95, 0.0)
		body.material_override = _material(Color(0.82, 0.74, 0.62).lerp(Color(0.45, 0.62, 0.78), rng.randf()))
		villager.add_child(body)

		var mark := Label3D.new()
		mark.name = "RoadHint"
		mark.text = "?"
		mark.position = Vector3(0.0, 2.2, 0.0)
		mark.visible = false
		mark.pixel_size = 0.03
		mark.outline_size = 12
		mark.modulate = Color(1.0, 0.92, 0.18, 1.0)
		mark.no_depth_test = true
		mark.render_priority = 5
		villager.add_child(mark)

		var road_keys: Array[Vector2i] = []
		for k in road_cells.keys():
			road_keys.append(k as Vector2i)
		var start_cell := Vector2i.ZERO
		if not road_cells.is_empty():
			start_cell = road_keys[rng.randi_range(0, road_keys.size() - 1)]
		villager.position = _cell_to_v3(start_cell) + Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))
		villager.set_script(VILLAGER_SCRIPT)
		villager.set("road_cells", road_keys)
		villager.set("building_targets", layout_positions)
		village.add_child(villager)


func _create_well() -> Node3D:
	var root := Node3D.new()
	root.name = "Well"

	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 1.0
	ring_mesh.bottom_radius = 1.0
	ring_mesh.height = 0.9
	ring.mesh = ring_mesh
	ring.position = Vector3(0.0, 0.45, 0.0)
	ring.material_override = _material(Color(0.58, 0.58, 0.59))
	root.add_child(ring)

	var water := MeshInstance3D.new()
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 0.83
	water_mesh.bottom_radius = 0.83
	water_mesh.height = 0.15
	water.mesh = water_mesh
	water.position = Vector3(0.0, 0.25, 0.0)
	water.material_override = _material(Color(0.14, 0.38, 0.62), true)
	root.add_child(water)

	_add_cylinder_collision(root, 1.0, 0.9, Vector3(0.0, 0.45, 0.0))
	return root


func _seed_from_anchor(chunk_coord: Vector2i) -> int:
	return base_seed + chunk_coord.x * 1376312589 + chunk_coord.y * 1013904223


func _material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.metallic = 0.0
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.3
	return mat
