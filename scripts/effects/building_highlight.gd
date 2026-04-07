extends Node3D

## 建筑蓝色连接指示器
## 在建筑顶部显示半透明蓝色光环，2秒后自动淡出销毁

const FADE_DURATION: float = 2.0

var _timer: float = 0.0
var _ring: MeshInstance3D = null


func _ready() -> void:
	_create_highlight_ring()


func _process(delta: float) -> void:
	_timer += delta
	var progress := _timer / FADE_DURATION
	
	if progress >= 1.0:
		queue_free()
		return
	
	# 淡出效果
	var alpha := 1.0 - progress
	if _ring and _ring.material_override:
		var mat := _ring.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = Color(0.3, 0.6, 1.0, alpha * 0.6)


func _create_highlight_ring() -> void:
	_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.6
	ring_mesh.outer_radius = 0.8
	ring_mesh.rings = 32
	_ring.mesh = ring_mesh
	_ring.position = Vector3(0.0, 1.8, 0.0)
	_ring.rotation.x = PI / 2.0
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.6, 1.0, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.4, 1.0)
	mat.emission_energy_multiplier = 0.5
	_ring.material_override = mat
	
	add_child(_ring)
