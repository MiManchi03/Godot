extends CanvasLayer

const SLOT_SIZE := 50
const SLOT_SPACING := 4
const HOTBAR_SLOTS := 8

@onready var slots_container: HBoxContainer
@onready var slots: Array = []

var inv_manager: Node


func _ready() -> void:
	inv_manager = get_node("/root/InventoryManager")
	if inv_manager:
		inv_manager.hotbar_changed.connect(_on_inventory_changed)
		inv_manager.selected_slot_changed.connect(_on_selected_slot_changed)
	
	_setup_ui()
	
	get_tree().root.size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()


func _setup_ui() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var total_width: float = HOTBAR_SLOTS * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING
	var start_x: float = (viewport_size.x - total_width) / 2.0
	var start_y: float = viewport_size.y - SLOT_SIZE - 20
	
	slots_container = HBoxContainer.new()
	slots_container.name = "SlotsContainer"
	slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_container.add_theme_constant_override("separation", SLOT_SPACING)
	slots_container.position = Vector2(start_x, start_y)
	add_child(slots_container)
	
	for i in range(HOTBAR_SLOTS):
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot_panel.set_meta("slot_index", i)
		
		var vbox := VBoxContainer.new()
		
		var icon_label := Label.new()
		icon_label.name = "Icon"
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 28)
		vbox.add_child(icon_label)
		
		var count_label := Label.new()
		count_label.name = "Count"
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.add_theme_font_size_override("font_size", 14)
		count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.add_child(count_label)
		
		var select_indicator := PanelContainer.new()
		select_indicator.name = "Select"
		select_indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
		select_indicator.visible = false
		vbox.add_child(select_indicator)
		
		slot_panel.add_child(vbox)
		slots_container.add_child(slot_panel)
		slots.append(slot_panel)
	
	_update_hotbar_display()
	
	get_tree().root.size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()


func _on_viewport_size_changed() -> void:
	if not slots_container:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var total_width: float = HOTBAR_SLOTS * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING
	var start_x: float = (viewport_size.x - total_width) / 2.0
	var start_y: float = viewport_size.y - SLOT_SIZE - 20
	slots_container.position = Vector2(start_x, start_y)


func _process(_delta: float) -> void:
	if inv_manager:
		_update_hotbar_display()
		_update_selected_display()


func _update_hotbar_display() -> void:
	if not inv_manager or slots.is_empty():
		return
	
	for i in range(HOTBAR_SLOTS):
		var item: Dictionary = inv_manager.get_hotbar_item(i)
		var slot: PanelContainer = slots[i]
		var vbox: VBoxContainer = slot.get_child(0) as VBoxContainer
		var icon_label: Label = vbox.get_node("Icon") as Label
		var count_label: Label = vbox.get_node("Count") as Label
		
		if item.is_empty():
			icon_label.text = ""
			count_label.text = ""
		else:
			var item_def: Dictionary = inv_manager.get_item_def(item["id"])
			icon_label.text = item_def["emoji"]
			if item["count"] > 1:
				count_label.text = str(item["count"])
			else:
				count_label.text = ""


func _update_selected_display() -> void:
	if not inv_manager:
		return
	
	for i in range(HOTBAR_SLOTS):
		var slot: PanelContainer = slots[i]
		var vbox: VBoxContainer = slot.get_child(0) as VBoxContainer
		var select_indicator: PanelContainer = vbox.get_node("Select") as PanelContainer
		select_indicator.visible = (i == inv_manager.selected_hotbar_slot)


func _on_inventory_changed() -> void:
	_update_hotbar_display()


func _on_selected_slot_changed(_slot_index: int) -> void:
	_update_selected_display()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			inv_manager.set_selected_slot(0)
		elif event.keycode == KEY_2:
			inv_manager.set_selected_slot(1)
		elif event.keycode == KEY_3:
			inv_manager.set_selected_slot(2)
		elif event.keycode == KEY_4:
			inv_manager.set_selected_slot(3)
		elif event.keycode == KEY_5:
			inv_manager.set_selected_slot(4)
		elif event.keycode == KEY_6:
			inv_manager.set_selected_slot(5)
		elif event.keycode == KEY_7:
			inv_manager.set_selected_slot(6)
		elif event.keycode == KEY_8:
			inv_manager.set_selected_slot(7)
