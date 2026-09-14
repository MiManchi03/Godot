extends GutTest

# 追溯：红队演练 D2（平原资源概率被改成 0.10，无测试发现）
# 对照：SPEC.md 3.3 群系资源分布

const ResourceSpawnerScript = preload("res://scripts/resources/resource_spawner.gd")
const BiomeGeneratorScript = preload("res://scripts/world/biome_generator.gd")
const Biome = BiomeGeneratorScript.Biome

const SAMPLES := 4000


func _distribution(biome: int) -> Dictionary:
	var spawner = ResourceSpawnerScript.new(12345)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var counts := {}
	for _i in range(SAMPLES):
		var t := String(spawner._pick_resource_type(rng, biome))
		counts[t] = counts.get(t, 0) + 1
	return counts


func _ratio(counts: Dictionary, key: String) -> float:
	return float(counts.get(key, 0)) / float(SAMPLES)


func test_attempt_count_per_biome() -> void:
	var spawner = ResourceSpawnerScript.new()
	assert_eq(spawner._attempt_count(Biome.PLAINS), 20, "平原")
	assert_eq(spawner._attempt_count(Biome.FOREST), 25, "森林")
	assert_eq(spawner._attempt_count(Biome.HILLS), 18, "山地")


func test_plains_distribution_matches_spec() -> void:
	var d := _distribution(Biome.PLAINS)
	assert_almost_eq(_ratio(d, "grass"), 0.70, 0.05, "平原草丛应约 70%")
	assert_almost_eq(_ratio(d, "rock"), 0.20, 0.05, "平原石头应约 20%")
	assert_almost_eq(_ratio(d, "tree"), 0.10, 0.05, "平原树木应约 10%")


func test_forest_distribution_matches_spec() -> void:
	var d := _distribution(Biome.FOREST)
	assert_almost_eq(_ratio(d, "tree"), 0.60, 0.05, "森林树木应约 60%")
	assert_almost_eq(_ratio(d, "grass"), 0.30, 0.05, "森林草丛应约 30%")
	assert_almost_eq(_ratio(d, "rock"), 0.10, 0.05, "森林石头应约 10%")


func test_hills_distribution_matches_spec() -> void:
	var d := _distribution(Biome.HILLS)
	assert_almost_eq(_ratio(d, "rock"), 0.50, 0.05, "山地石头应约 50%")
	assert_almost_eq(_ratio(d, "tree"), 0.30, 0.05, "山地树木应约 30%")
	assert_almost_eq(_ratio(d, "grass"), 0.20, 0.05, "山地草丛应约 20%")
