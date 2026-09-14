extends GutTest

# 追溯：红队演练 D3（空 / 负 / 超大输入无测试覆盖）

const ResourceSpawnerScript = preload("res://scripts/resources/resource_spawner.gd")
const BiomeGeneratorScript = preload("res://scripts/world/biome_generator.gd")
const WorldStateScript = preload("res://scripts/world/world_state.gd")
const Biome = BiomeGeneratorScript.Biome


func test_attempt_count_unknown_biome_default() -> void:
	var s = ResourceSpawnerScript.new()
	assert_eq(s._attempt_count(999999), 12, "未知群系应有兜底数量")
	assert_eq(s._attempt_count(-1), 12, "负群系值应有兜底数量")


func test_biome_name_out_of_range() -> void:
	var g = BiomeGeneratorScript.new()
	assert_eq(g.biome_name(-1), "unknown")
	assert_eq(g.biome_name(100000), "unknown")


func test_get_biome_extreme_coords_no_crash() -> void:
	var g = BiomeGeneratorScript.new()
	var huge := 1.0e12
	g.get_biome(huge, -huge)
	g.get_biome(-huge, huge)
	g.get_biome(0.0, 0.0)
	assert_true(true, "极端坐标不应崩溃")


func test_world_state_empty_ids_no_crash() -> void:
	var ws = WorldStateScript.new(880001, 32)
	assert_false(ws.assign_villager_to_house("", ""), "空 id 不得写入")
	assert_eq(ws.get_house_occupant(""), "", "空建筑查询应为空")
	assert_eq(ws.get_villager_house(""), "", "空村民查询应为空")


func test_pick_resource_type_always_returns_known() -> void:
	var s = ResourceSpawnerScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _i in range(500):
		var t := String(s._pick_resource_type(rng, Biome.PLAINS))
		assert_true(t in ["grass", "rock", "tree"], "资源类型必须在已知集合内，实际=%s" % t)
