extends RefCounted
class_name ResourceSpawner

const BiomeKind = BiomeGenerator.Biome
const DestructibleScript := preload("res://scripts/world/destructible.gd")

var base_seed: int


func _init(seed: int = 2337) -> void:
	base_seed = seed


func populate_chunk(parent: Node3D, chunk_coord: Vector2i, chunk_size: int, biome: BiomeGenerator.Biome) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(chunk_coord)
	var half_size := chunk_size * 0.5

	var attempts := _attempt_count(biome)
	for _i in range(attempts):
		var resource_type := _pick_resource_type(rng, biome)
		var local_x := rng.randf_range(-half_size + 1.5, half_size - 1.5)
		var local_z := rng.randf_range(-half_size + 1.5, half_size - 1.5)
		var resource := _create_resource(resource_type)
		if resource == null:
			continue

		resource.position = Vector3(local_x, 0.0, local_z)
		resource.rotate_y(rng.randf_range(0.0, TAU))
		parent.add_child(resource)


func _attempt_count(biome: BiomeGenerator.Biome) -> int:
	match biome:
		BiomeKind.PLAINS:
			return 20
		BiomeKind.FOREST:
			return 25
		BiomeKind.HILLS:
			return 18
		_:
			return 12


func _pick_resource_type(rng: RandomNumberGenerator, biome: BiomeGenerator.Biome) -> StringName:
	var roll := rng.randf()

	match biome:
		BiomeKind.PLAINS:
			if roll < 0.70:
				return &"grass"
			if roll < 0.90:
				return &"rock"
			return &"tree"
		BiomeKind.FOREST:
			if roll < 0.60:
				return &"tree"
			if roll < 0.90:
				return &"grass"
			return &"rock"
		BiomeKind.HILLS:
			if roll < 0.50:
				return &"rock"
			if roll < 0.80:
				return &"tree"
			return &"grass"
		_:
			return &"grass"


func _create_resource(resource_type: StringName) -> Node3D:
	match resource_type:
		&"tree":
			return _create_tree()
		&"rock":
			return _create_rock()
		&"grass":
			return _create_grass()
		_:
			return _create_grass()


func _create_tree() -> Node3D:
	var root := StaticBody3D.new()
	root.name = "Tree"
	root.collision_layer = 1
	root.collision_mask = 1

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.22
	trunk_mesh.height = 1.5
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(0.0, 0.75, 0.0)
	trunk.material_override = _material(Color(0.45, 0.28, 0.14))
	root.add_child(trunk)

	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.85
	crown_mesh.height = 1.5
	crown.mesh = crown_mesh
	crown.position = Vector3(0.0, 1.7, 0.0)
	crown.material_override = _material(Color(0.18, 0.47, 0.2))
	root.add_child(crown)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 2.0
	collision.shape = shape
	collision.position = Vector3(0.0, 1.0, 0.0)
	root.add_child(collision)

	var area := Area3D.new()
	area.name = "DestructibleArea"
	area.collision_layer = 2
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = true
	area.set_script(DestructibleScript)
	area.destruct_type = "tree"
	area.destroy_time = 4.0
	area.drops = {"wood": 4, "stick": 8, "leaves": 24}
	root.add_child(area)

	var area_collision := CollisionShape3D.new()
	var area_shape := CapsuleShape3D.new()
	area_shape.radius = 0.5
	area_shape.height = 2.0
	area_collision.shape = area_shape
	area_collision.position = Vector3(0.0, 1.0, 0.0)
	area.add_child(area_collision)

	return root


func _create_rock() -> Node3D:
	var root := StaticBody3D.new()
	root.name = "Rock"
	root.collision_layer = 1
	root.collision_mask = 1

	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.8
	mesh_instance.mesh = mesh
	mesh_instance.scale = Vector3(1.2, 0.7, 1.0)
	mesh_instance.position = Vector3(0.0, 0.3, 0.0)
	mesh_instance.material_override = _material(Color(0.54, 0.55, 0.56))
	root.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	collision.shape = shape
	collision.position = Vector3(0.0, 0.35, 0.0)
	root.add_child(collision)

	var area := Area3D.new()
	area.name = "DestructibleArea"
	area.collision_layer = 2
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = true
	area.set_script(DestructibleScript)
	area.destruct_type = "stone"
	area.destroy_time = 6.0
	area.drops = {"stone": 4}
	root.add_child(area)

	var area_collision := CollisionShape3D.new()
	var area_shape := SphereShape3D.new()
	area_shape.radius = 0.6
	area_collision.shape = area_shape
	area_collision.position = Vector3(0.0, 0.35, 0.0)
	area.add_child(area_collision)

	return root


func _create_grass() -> Area3D:
	var root := Area3D.new()
	root.name = "Grass"
	root.collision_layer = 2
	root.collision_mask = 1
	root.monitoring = true
	root.monitorable = true
	root.set_script(DestructibleScript)
	root.destruct_type = "grass"
	root.destroy_time = 0.0
	root.drops = {"wheat": 1}

	var area_collision := CollisionShape3D.new()
	var area_shape := BoxShape3D.new()
	area_shape.size = Vector3(0.2, 0.6, 0.2)
	area_collision.shape = area_shape
	area_collision.position = Vector3(0.0, 0.3, 0.0)
	root.add_child(area_collision)

	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.12, 0.6, 0.12)
	blade.mesh = blade_mesh
	blade.position = Vector3(0.0, 0.3, 0.0)
	blade.material_override = _material(Color(0.31, 0.68, 0.25))
	root.add_child(blade)

	var blade_2 := MeshInstance3D.new()
	blade_2.mesh = blade_mesh
	blade_2.position = Vector3(0.07, 0.28, -0.04)
	blade_2.rotation.y = deg_to_rad(20.0)
	blade_2.material_override = _material(Color(0.28, 0.6, 0.22))
	root.add_child(blade_2)

	return root


func _chunk_seed(chunk_coord: Vector2i) -> int:
	var x := int(chunk_coord.x) * 73856093
	var z := int(chunk_coord.y) * 19349663
	return int(base_seed) + x ^ z


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.metallic = 0.0
	return mat
