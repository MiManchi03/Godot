extends GutTest

# 追溯：审计 A6/A14（世界状态纯逻辑无单测）

const WorldStateScript = preload("res://scripts/world/world_state.gd")

var _seed_counter := 700000


func _new_state():
	_seed_counter += 1
	return WorldStateScript.new(_seed_counter, 32)


func test_assign_and_query_occupancy() -> void:
	var ws = _new_state()
	assert_true(ws.assign_villager_to_house("house|1", "villager|1"), "入住应成功")
	assert_eq(ws.get_house_occupant("house|1"), "villager|1", "建筑应记录入住者")
	assert_eq(ws.get_villager_house("villager|1"), "house|1", "村民应记录所在建筑")


func test_remove_occupancy() -> void:
	var ws = _new_state()
	ws.assign_villager_to_house("house|2", "villager|2")
	assert_true(ws.remove_house_occupant("house|2"), "搬离应成功")
	assert_eq(ws.get_house_occupant("house|2"), "", "搬离后建筑应为空")


func test_assign_rejects_empty_ids() -> void:
	var ws = _new_state()
	assert_false(ws.assign_villager_to_house("", "villager|3"), "空建筑 id 应拒绝")
	assert_false(ws.assign_villager_to_house("house|3", ""), "空村民 id 应拒绝")


func test_remove_absent_house_returns_false() -> void:
	var ws = _new_state()
	assert_false(ws.remove_house_occupant("house|never"), "移除不存在的建筑应失败")


func test_reassign_moves_villager() -> void:
	var ws = _new_state()
	ws.assign_villager_to_house("house|A", "villager|X")
	ws.assign_villager_to_house("house|B", "villager|X")
	assert_eq(ws.get_house_occupant("house|A"), "", "换房后旧建筑应清空")
	assert_eq(ws.get_villager_house("villager|X"), "house|B", "村民应指向换后的建筑")
