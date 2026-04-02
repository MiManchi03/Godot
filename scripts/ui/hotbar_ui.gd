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
		
		var content := Control.new()
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		var icon_label := Label.new()
		icon_label.name = "Icon"
		icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 28)
		var icon_tex := TextureRect.new()
		icon_tex.name = "IconTex"
		icon_tex.anchor_right = 1.0
		icon_tex.anchor_bottom = 1.0
		icon_tex.offset_left = 8.0
		icon_tex.offset_top = 8.0
		icon_tex.offset_right = -8.0
		icon_tex.offset_bottom = -8.0
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_tex.visible = false
		content.add_child(icon_tex)
		content.add_child(icon_label)
		
		var count_label := Label.new()
		count_label.name = "Count"
		count_label.anchor_left = 1.0
		count_label.anchor_top = 1.0
		count_label.anchor_right = 1.0
		count_label.anchor_bottom = 1.0
		count_label.offset_left = -22.0
		count_label.offset_top = -18.0
		count_label.offset_right = -4.0
		count_label.offset_bottom = -2.0
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.add_theme_font_size_override("font_size", 14)
		content.add_child(count_label)
		
		var select_indicator := PanelContainer.new()
		select_indicator.name = "Select"
		select_indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
		select_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var select_style := StyleBoxFlat.new()
		select_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		select_style.draw_center = false
		select_style.border_width_left = 2
		select_style.border_width_top = 2
		select_style.border_width_right = 2
		select_style.border_width_bottom = 2
		select_style.border_color = Color(1.0, 0.95, 0.65, 1.0)
		select_indicator.add_theme_stylebox_override("panel", select_style)
		select_indicator.visible = false
		content.add_child(select_indicator)
		
		slot_panel.add_child(content)
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
		var content: Control = slot.get_child(0) as Control
		var icon_label: Label = content.get_node("Icon") as Label
		var icon_tex: TextureRect = content.get_node("IconTex") as TextureRect
		var count_label: Label = content.get_node("Count") as Label
		
		if item.is_empty():
			icon_label.text = ""
			icon_tex.texture = null
			icon_tex.visible = false
			count_label.text = ""
		else:
			var item_def: Dictionary = inv_manager.get_item_def(item["id"])
			var icon_path := str(item_def.get("icon", ""))
			if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
				icon_tex.texture = load(icon_path)
				icon_tex.visible = true
				icon_label.text = ""
			else:
				icon_tex.texture = null
				icon_tex.visible = false
				icon_label.text = str(item_def.get("emoji", "❓"))
			count_label.text = str(item["count"])


func _update_selected_display() -> void:
	if not inv_manager:
		return
	
	for i in range(HOTBAR_SLOTS):
		var slot: PanelContainer = slots[i]
		var content: Control = slot.get_child(0) as Control
		var select_indicator: PanelContainer = content.get_node("Select") as PanelContainer
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
