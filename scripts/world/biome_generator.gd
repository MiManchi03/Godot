extends RefCounted
class_name BiomeGenerator

enum Biome {
	PLAINS,
	FOREST,
	HILLS,
}

var biome_noise: FastNoiseLite


func _init(seed: int = 1337) -> void:
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = seed
	biome_noise.frequency = 0.003
	biome_noise.fractal_octaves = 3


func get_biome(world_x: float, world_z: float) -> Biome:
	var n := biome_noise.get_noise_2d(world_x, world_z)
	if n < -0.2:
		return Biome.PLAINS
	if n < 0.35:
		return Biome.FOREST
	return Biome.HILLS


func biome_name(biome: Biome) -> String:
	match biome:
		Biome.PLAINS:
			return "plains"
		Biome.FOREST:
			return "forest"
		Biome.HILLS:
			return "hills"
		_:
			return "unknown"


func biome_color(biome: Biome) -> Color:
	match biome:
		Biome.PLAINS:
			return Color(0.37, 0.66, 0.30)
		Biome.FOREST:
			return Color(0.20, 0.48, 0.22)
		Biome.HILLS:
			return Color(0.45, 0.52, 0.40)
		_:
			return Color(0.5, 0.5, 0.5)