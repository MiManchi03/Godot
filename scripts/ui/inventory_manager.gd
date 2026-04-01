extends Node

const INVENTORY_SIZE := 40
const HOTBAR_SIZE := 8
const MAX_STACK := 64

const ITEM_DEFS := {
	"wood": {"name": "木头", "emoji": "🪵"},
	"stick": {"name": "树枝", "emoji": "🌿"},
	"leaves": {"name": "树叶", "emoji": "🍃"},
	"stone": {"name": "石头", "emoji": "🪨"},
	"wheat_seed": {"name": "小麦种子", "emoji": "🌾"},
	"wheat": {"name": "小麦", "emoji": "🌾", "icon": "res://assets/icons/wheat.svg"}
}

var inventory: Array = []
var hotbar: Array = []
var selected_hotbar_slot: int = 0

signal inventory_changed()
signal hotbar_changed()
signal selected_slot_changed(slot_index: int)


func _ready() -> void:
	_inventory_init()


func _inventory_init() -> void:
	inventory.clear()
	hotbar.clear()
	for i in range(INVENTORY_SIZE):
		inventory.append(null)
	for i in range(HOTBAR_SIZE):
		hotbar.append(null)


func get_item_def(item_id: String) -> Dictionary:
	return ITEM_DEFS.get(item_id, {"name": "未知物品", "emoji": "❓"})


func add_item(item_id: String, count: int = 1) -> bool:
	if count <= 0:
		return false
	
	var item_def := get_item_def(item_id)
	if item_def.is_empty():
		return false
	
	count = _try_add_to_hotbar(item_id, count)
	if count > 0:
		count = _try_add_to_inventory(item_id, count)
	
	if count > 0:
		drop_item(item_id, count)
		return false
	
	inventory_changed.emit()
	hotbar_changed.emit()
	return true


func _try_add_to_hotbar(item_id: String, count: int) -> int:
	for i in range(HOTBAR_SIZE):
		if hotbar[i] != null and hotbar[i]["id"] == item_id:
			var space: int = MAX_STACK - hotbar[i]["count"]
			if space > 0:
				var add: int = mini(count, space)
				hotbar[i]["count"] += add
				count -= add
				hotbar_changed.emit()
				if count <= 0:
					return 0
	for i in range(HOTBAR_SIZE):
		if hotbar[i] == null:
			hotbar[i] = {"id": item_id, "count": count}
			count = 0
			hotbar_changed.emit()
			return 0
	return count


func _try_add_to_inventory(item_id: String, count: int) -> int:
	for i in range(INVENTORY_SIZE):
		if inventory[i] != null and inventory[i]["id"] == item_id:
			var space: int = MAX_STACK - inventory[i]["count"]
			if space > 0:
				var add: int = mini(count, space)
				inventory[i]["count"] += add
				count -= add
				inventory_changed.emit()
				if count <= 0:
					return 0
	for i in range(INVENTORY_SIZE):
		if inventory[i] == null:
			inventory[i] = {"id": item_id, "count": count}
			count = 0
			inventory_changed.emit()
			return 0
	return count


func remove_item_from_hotbar(slot: int, count: int = -1) -> bool:
	if slot < 0 or slot >= HOTBAR_SIZE:
		return false
	if hotbar[slot] == null:
		return false
	
	if count <= 0 or count >= hotbar[slot]["count"]:
		hotbar[slot] = null
	else:
		hotbar[slot]["count"] -= count
	
	hotbar_changed.emit()
	return true


func get_hotbar_item(slot: int) -> Dictionary:
	if slot < 0 or slot >= HOTBAR_SIZE:
		return {}
	return hotbar[slot] if hotbar[slot] else {}


func get_inventory_item(slot: int) -> Dictionary:
	if slot < 0 or slot >= INVENTORY_SIZE:
		return {}
	return inventory[slot] if inventory[slot] else {}


func set_selected_slot(index: int) -> void:
	if index >= 0 and index < HOTBAR_SIZE:
		selected_hotbar_slot = index
		selected_slot_changed.emit(selected_hotbar_slot)


func drop_item(item_id: String, count: int) -> void:
	print("掉落物品: ", get_item_def(item_id)["name"], " x", count)


func swap_hotbar_slots(from: int, to: int) -> void:
	if from < 0 or from >= HOTBAR_SIZE or to < 0 or to >= HOTBAR_SIZE:
		return
	var temp: Dictionary = hotbar[from]
	hotbar[from] = hotbar[to]
	hotbar[to] = temp
	hotbar_changed.emit()


func move_to_hotbar(inventory_slot: int, hotbar_slot: int) -> bool:
	if inventory_slot < 0 or inventory_slot >= INVENTORY_SIZE:
		return false
	if hotbar_slot < 0 or hotbar_slot >= HOTBAR_SIZE:
		return false
	
	var inv_item: Dictionary = inventory[inventory_slot]
	var hot_item: Dictionary = hotbar[hotbar_slot]
	
	hotbar[hotbar_slot] = inv_item
	inventory[inventory_slot] = hot_item
	
	inventory_changed.emit()
	hotbar_changed.emit()
	return true


func swap_slots(from_is_hotbar: bool, from_index: int, to_is_hotbar: bool, to_index: int) -> bool:
	if from_is_hotbar:
		if from_index < 0 or from_index >= HOTBAR_SIZE:
			return false
	else:
		if from_index < 0 or from_index >= INVENTORY_SIZE:
			return false

	if to_is_hotbar:
		if to_index < 0 or to_index >= HOTBAR_SIZE:
			return false
	else:
		if to_index < 0 or to_index >= INVENTORY_SIZE:
			return false

	if from_is_hotbar and to_is_hotbar:
		var tmp_hot: Variant = hotbar[from_index]
		hotbar[from_index] = hotbar[to_index]
		hotbar[to_index] = tmp_hot
		hotbar_changed.emit()
		return true

	if (not from_is_hotbar) and (not to_is_hotbar):
		var tmp_inv: Variant = inventory[from_index]
		inventory[from_index] = inventory[to_index]
		inventory[to_index] = tmp_inv
		inventory_changed.emit()
		return true

	if from_is_hotbar and (not to_is_hotbar):
		var tmp_cross: Variant = hotbar[from_index]
		hotbar[from_index] = inventory[to_index]
		inventory[to_index] = tmp_cross
		inventory_changed.emit()
		hotbar_changed.emit()
		return true

	var tmp_cross2: Variant = inventory[from_index]
	inventory[from_index] = hotbar[to_index]
	hotbar[to_index] = tmp_cross2
	inventory_changed.emit()
	hotbar_changed.emit()
	return true
