extends GutTest

# 追溯：审计 A6/A14（纯逻辑层无单测）

const BiomeGeneratorScript = preload("res://scripts/world/biome_generator.gd")
const Biome = BiomeGeneratorScript.Biome


func test_biome_name_mapping() -> void:
	var g = BiomeGeneratorScript.new()
	assert_eq(g.biome_name(Biome.PLAINS), "plains")
	assert_eq(g.biome_name(Biome.FOREST), "forest")
	assert_eq(g.biome_name(Biome.HILLS), "hills")
	assert_eq(g.biome_name(9999), "unknown", "越界枚举应回落 unknown")


func test_get_biome_deterministic() -> void:
	var a = BiomeGeneratorScript.new(1337)
	var b = BiomeGeneratorScript.new(1337)
	assert_eq(a.get_biome(10.0, 20.0), b.get_biome(10.0, 20.0), "同种子同坐标应得同群系")


func test_get_biome_returns_valid_enum() -> void:
	var g = BiomeGeneratorScript.new()
	var valid := [Biome.PLAINS, Biome.FOREST, Biome.HILLS]
	for x in range(-400, 400, 50):
		var biome = g.get_biome(float(x), float(x) * 1.7)
		assert_true(biome in valid, "群系必须是合法枚举，实际=%s" % str(biome))
