# tests/bench/bench_core.gd
# Phase 7 performance baseline (pure logic, headless).
# Run via: python tools/benchmark.py
# Output lines: BENCH <name>=<value>   (value in milliseconds)
extends SceneTree

const BiomeGeneratorScript = preload("res://scripts/world/biome_generator.gd")
const ResourceSpawnerScript = preload("res://scripts/resources/resource_spawner.gd")

const ITERATIONS := 200000


func _bench_biome_sample() -> float:
	var g = BiomeGeneratorScript.new(1337)
	var start := Time.get_ticks_usec()
	var sink := 0
	for i in range(ITERATIONS):
		sink += g.get_biome(float(i % 1000), float((i * 7) % 1000))
	var elapsed := (Time.get_ticks_usec() - start) / 1000.0
	if sink < 0:
		print("unreachable ", sink)
	return elapsed


func _bench_resource_pick() -> float:
	var s = ResourceSpawnerScript.new(12345)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var start := Time.get_ticks_usec()
	var sink := 0
	for i in range(ITERATIONS):
		var t := String(s._pick_resource_type(rng, i % 3))
		sink += t.length()
	var elapsed := (Time.get_ticks_usec() - start) / 1000.0
	if sink < 0:
		print("unreachable ", sink)
	return elapsed


func _bench_biome_name() -> float:
	var g = BiomeGeneratorScript.new(1337)
	var start := Time.get_ticks_usec()
	var sink := 0
	for i in range(ITERATIONS):
		sink += g.biome_name(i % 3).length()
	var elapsed := (Time.get_ticks_usec() - start) / 1000.0
	if sink < 0:
		print("unreachable ", sink)
	return elapsed


func _initialize() -> void:
	print("BENCH biome_sample_ms=%.2f" % _bench_biome_sample())
	print("BENCH resource_pick_ms=%.2f" % _bench_resource_pick())
	print("BENCH biome_name_ms=%.2f" % _bench_biome_name())
	quit()
