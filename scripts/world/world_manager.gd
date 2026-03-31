extends Node3D

const CHUNK_SIZE := 32
const LOAD_RADIUS := 5
const UNLOAD_RADIUS := 7

@export var world_seed: int = 91357

var biome_generator: BiomeGenerator
var resource_spawner: ResourceSpawner
var village_generator: VillageGenerator

var player: CharacterBody3D
var loaded_chunks: Dictionary = {}


func _ready() -> void:
	biome_generator = BiomeGenerator.new(world_seed)
	resource_spawner = ResourceSpawner.new(world_seed + 1000)
	village_generator = VillageGenerator.new(world_seed + 2000)

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
