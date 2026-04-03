extends Node
class_name BuildPreviewController

var preview_root: Node3D
var preview_valid: bool = false
var preview_rotation_deg: float = 0.0
var preview_variant_seed: int = 0


func clear_preview() -> void:
	if preview_root:
		preview_root.queue_free()
		preview_root = null
	preview_valid = false
	preview_rotation_deg = 0.0
	preview_variant_seed = 0


func spawn_preview(parent: Node, build_id: String, build_type: int, generator: VillageGenerator, rng_seed: int) -> bool:
	clear_preview()
	if build_id.is_empty() or build_type == -1:
		return false
	var rng = RandomNumberGenerator.new()
	rng.seed = rng_seed
	var preview = generator._create_building_variant(rng, build_type)
	if preview == null:
		return false
	preview.name = "BuildPreview"
	preview.set_meta("build_id", build_id)
	preview.set_meta("variant_seed", rng_seed)
	parent.add_child(preview)
	preview_root = preview
	preview_rotation_deg = 0.0
	preview_variant_seed = rng_seed
	return true


func update_preview(camera: Camera3D, build_id: String) -> void:
	if preview_root == null or camera == null:
		preview_valid = false
		return
	var pos = _mouse_ground_position(camera)
	if pos == Vector3.ZERO:
		preview_valid = false
		_set_preview_tint(preview_root, Color(0.9, 0.2, 0.2, 0.7))
		return
	if build_id == "road":
		preview_root.global_position = _grid_pos_from_cell(_grid_cell_from_world(pos))
	else:
		preview_root.global_position = pos
	preview_root.rotation.y = deg_to_rad(preview_rotation_deg)
	var invalid = _preview_overlaps(build_id)
	preview_valid = not invalid
	_set_preview_tint(preview_root, Color(0.9, 0.2, 0.2, 0.7) if invalid else Color(0.5, 1.0, 0.5, 0.8))


func try_place(world_manager: Node, build_id: String) -> Node3D:
	if preview_root == null or not preview_valid:
		return null
	if world_manager == null:
		return null
	var placed_variant = world_manager.call(
		"spawn_player_building",
		build_id,
		preview_root.global_position,
		preview_root.rotation.y,
		preview_variant_seed
	)
	if placed_variant == null:
		return null
	var placed := placed_variant as Node3D
	if placed == null:
		return null
	world_manager.call("add_player_building", build_id, placed.global_position, placed.rotation.y, placed.name, preview_variant_seed)
	return placed


func _mouse_ground_position(camera: Camera3D) -> Vector3:
	var viewport = get_viewport()
	if viewport == null:
		return Vector3.ZERO
	var mouse_pos = viewport.get_mouse_position()
	var origin = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	if absf(dir.y) < 0.0001:
		return Vector3.ZERO
	var t: float = -origin.y / dir.y
	if t <= 0.0:
		return Vector3.ZERO
	return origin + dir * t


func _set_preview_tint(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var overlay := StandardMaterial3D.new()
		overlay.albedo_color = color
		overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance.material_overlay = overlay
	for child in node.get_children():
		_set_preview_tint(child, color)


func _preview_overlaps(build_id: String) -> bool:
	if preview_root == null:
		return true
	if build_id == "road":
		return false
	var world := preview_root.get_world_3d()
	if world == null:
		return true
	var state = world.direct_space_state
	var q = PhysicsShapeQueryParameters3D.new()
	for child in preview_root.get_children():
		if child is StaticBody3D:
			var body := child as StaticBody3D
			for shape_child in body.get_children():
				if shape_child is CollisionShape3D:
					var col := shape_child as CollisionShape3D
					if col.shape == null:
						continue
					q.shape = col.shape
					q.transform = body.global_transform * Transform3D(Basis.IDENTITY, col.position)
					q.collide_with_areas = false
					q.collide_with_bodies = true
					var hits := state.intersect_shape(q, 4)
					for hit_variant in hits:
						var hit := hit_variant as Dictionary
						var collider = hit.get("collider")
						if collider == null:
							continue
						if preview_root.is_ancestor_of(collider):
							continue
						if collider is Node and (collider as Node).name == "Ground":
							continue
						return true
	return false


func _grid_cell_from_world(world_pos: Vector3) -> Vector2i:
	return Vector2i(roundi(world_pos.x), roundi(world_pos.z))


func _grid_pos_from_cell(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x), 0.0, float(cell.y))
