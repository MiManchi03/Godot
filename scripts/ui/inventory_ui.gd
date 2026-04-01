extends CanvasLayer

const SLOT_SIZE := 50
const SLOT_SPACING := 4
const INVENTORY_COLS := 8
const INVENTORY_ROWS := 5
const HOTBAR_SLOTS := 8

@onready var main_panel: PanelContainer
@onready var inventory_grid: GridContainer
@onready var hotbar_container: HBoxContainer
@onready var tooltip_panel: PanelContainer
@onready var tooltip_label: Label

var inventory_slots: Array = []
var hotbar_slots: Array = []

var dragging: bool = false
var drag_from_is_hotbar: bool = false
var drag_from_index: int = -1
var drag_preview: PanelContainer

var inv_manager: Node
var is_open: bool = false


const INV_SIZE := 40

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	inv_manager = get_node("/root/InventoryManager")
	if inv_manager:
		inv_manager.inventory_changed.connect(_on_inventory_changed)
		inv_manager.hotbar_changed.connect(_on_hotbar_changed)
	
	_setup_ui()


func _setup_ui() -> void:
	main_panel = PanelContainer.new()
	main_panel.anchors_preset = 8
	main_panel.anchor_left = 0.5
	main_panel.anchor_top = 0.5
	main_panel.anchor_right = 0.5
	main_panel.anchor_bottom = 0.5
	main_panel.offset_left = -280.0
	main_panel.offset_top = -220.0
	main_panel.offset_right = 280.0
	main_panel.offset_bottom = 280.0
	add_child(main_panel)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	main_panel.add_child(main_vbox)
	
	var title := Label.new()
	title.text = "背包"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	main_vbox.add_child(title)
	
	var grid_center := CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(grid_center)
	
	inventory_grid = GridContainer.new()
	inventory_grid.columns = INVENTORY_COLS
	inventory_grid.add_theme_constant_override("h_separation", SLOT_SPACING)
	inventory_grid.add_theme_constant_override("v_separation", SLOT_SPACING)
	grid_center.add_child(inventory_grid)
	
	for i in range(INV_SIZE):
		var slot := _create_slot(i, false)
		inventory_grid.add_child(slot)
		inventory_slots.append(slot)
	
	var separator := HSeparator.new()
	main_vbox.add_child(separator)
	
	var hotbar_label := Label.new()
	hotbar_label.text = "快捷物品栏"
	hotbar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(hotbar_label)
	
	hotbar_container = HBoxContainer.new()
	hotbar_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_container.add_theme_constant_override("separation", SLOT_SPACING)
	main_vbox.add_child(hotbar_container)
	
	for i in range(HOTBAR_SLOTS):
		var slot := _create_slot(i, true)
		hotbar_container.add_child(slot)
		hotbar_slots.append(slot)
	
	tooltip_panel = PanelContainer.new()
	tooltip_panel.visible = false
	tooltip_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tooltip_label = Label.new()
	tooltip_label.add_theme_font_size_override("font_size", 16)
	tooltip_panel.add_child(tooltip_label)
	add_child(tooltip_panel)

	drag_preview = PanelContainer.new()
	drag_preview.visible = false
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	var preview_content := Control.new()
	preview_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	var preview_icon_tex := TextureRect.new()
	preview_icon_tex.name = "IconTex"
	preview_icon_tex.anchor_right = 1.0
	preview_icon_tex.anchor_bottom = 1.0
	preview_icon_tex.offset_left = 8.0
	preview_icon_tex.offset_top = 8.0
	preview_icon_tex.offset_right = -8.0
	preview_icon_tex.offset_bottom = -8.0
	preview_icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_content.add_child(preview_icon_tex)
	var preview_icon := Label.new()
	preview_icon.name = "Icon"
	preview_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_icon.add_theme_font_size_override("font_size", 28)
	preview_content.add_child(preview_icon)
	var preview_count := Label.new()
	preview_count.name = "Count"
	preview_count.anchor_left = 1.0
	preview_count.anchor_top = 1.0
	preview_count.anchor_right = 1.0
	preview_count.anchor_bottom = 1.0
	preview_count.offset_left = -22.0
	preview_count.offset_top = -18.0
	preview_count.offset_right = -4.0
	preview_count.offset_bottom = -2.0
	preview_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	preview_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	preview_count.add_theme_font_size_override("font_size", 14)
	preview_content.add_child(preview_count)
	drag_preview.add_child(preview_content)
	add_child(drag_preview)
	
	_update_display()


func _create_slot(index: int, is_hotbar: bool) -> PanelContainer:
	var slot_panel := PanelContainer.new()
	slot_panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot_panel.set_meta("slot_index", index)
	slot_panel.set_meta("is_hotbar", is_hotbar)
	
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
	
	slot_panel.add_child(content)
	
	return slot_panel


func _process(_delta: float) -> void:
	_update_display()
	_update_tooltip()
	if dragging and drag_preview:
		drag_preview.visible = true
		drag_preview.position = get_viewport().get_mouse_position() - Vector2(SLOT_SIZE * 0.5, SLOT_SIZE * 0.5)


func _update_display() -> void:
	if not inv_manager:
		return
	
	for i in range(INV_SIZE):
		var item: Dictionary = inv_manager.get_inventory_item(i)
		_update_slot(inventory_slots[i], item)
	
	for i in range(HOTBAR_SLOTS):
		var item: Dictionary = inv_manager.get_hotbar_item(i)
		_update_slot(hotbar_slots[i], item, i == inv_manager.selected_hotbar_slot)


func _update_slot(slot: PanelContainer, item: Dictionary, is_selected: bool = false) -> void:
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

	if is_selected:
		slot.self_modulate = Color(1.0, 1.0, 0.85, 1.0)
	else:
		slot.self_modulate = Color(1, 1, 1, 1)


func _slot_at_mouse(mouse_pos: Vector2) -> Dictionary:
	for slot in hotbar_slots:
		if slot.get_global_rect().has_point(mouse_pos):
			return {"found": true, "is_hotbar": true, "index": int(slot.get_meta("slot_index"))}
	for slot in inventory_slots:
		if slot.get_global_rect().has_point(mouse_pos):
			return {"found": true, "is_hotbar": false, "index": int(slot.get_meta("slot_index"))}
	return {"found": false}


func _get_item_by_slot(is_hotbar: bool, index: int) -> Dictionary:
	if not inv_manager:
		return {}
	if is_hotbar:
		return inv_manager.get_hotbar_item(index)
	return inv_manager.get_inventory_item(index)


func _start_drag(is_hotbar: bool, index: int) -> void:
	var item := _get_item_by_slot(is_hotbar, index)
	if item.is_empty():
		return
	dragging = true
	drag_from_is_hotbar = is_hotbar
	drag_from_index = index
	var preview_content: Control = drag_preview.get_child(0) as Control
	var icon_label: Label = preview_content.get_node("Icon") as Label
	var icon_tex: TextureRect = preview_content.get_node("IconTex") as TextureRect
	var count_label: Label = preview_content.get_node("Count") as Label
	var item_def: Dictionary = inv_manager.get_item_def(item["id"])
	var icon_path := str(item_def.get("icon", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon_tex.texture = load(icon_path)
		icon_label.text = ""
	else:
		icon_tex.texture = null
		icon_label.text = str(item_def.get("emoji", "❓"))
	count_label.text = str(item["count"])
	drag_preview.visible = true


func _stop_drag() -> void:
	dragging = false
	drag_from_is_hotbar = false
	drag_from_index = -1
	drag_preview.visible = false


func _try_drop_to_slot(is_hotbar: bool, index: int) -> void:
	if not dragging or not inv_manager:
		return
	if drag_from_is_hotbar == is_hotbar and drag_from_index == index:
		_stop_drag()
		return
	inv_manager.swap_slots(drag_from_is_hotbar, drag_from_index, is_hotbar, index)
	_stop_drag()


func _update_tooltip() -> void:
	if not is_open or not inv_manager or dragging:
		tooltip_panel.visible = false
		return
	
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var found_item := false
	
	for slot in inventory_slots:
		var rect: Rect2 = slot.get_global_rect()
		if rect.has_point(mouse_pos):
			var index: int = slot.get_meta("slot_index")
			var item: Dictionary = inv_manager.get_inventory_item(index)
			if not item.is_empty():
				var item_def: Dictionary = inv_manager.get_item_def(item["id"])
				tooltip_label.text = item_def["name"]
				tooltip_panel.position = mouse_pos + Vector2(15, 15)
				tooltip_panel.visible = true
				found_item = true
				break
	
	if not found_item:
		for slot in hotbar_slots:
			var rect: Rect2 = slot.get_global_rect()
			if rect.has_point(mouse_pos):
				var index: int = slot.get_meta("slot_index")
				var item: Dictionary = inv_manager.get_hotbar_item(index)
				if not item.is_empty():
					var item_def: Dictionary = inv_manager.get_item_def(item["id"])
					tooltip_label.text = item_def["name"]
					tooltip_panel.position = mouse_pos + Vector2(15, 15)
					tooltip_panel.visible = true
					found_item = true
					break
	
	if not found_item:
		tooltip_panel.visible = false


func _on_inventory_changed() -> void:
	_update_display()


func _on_hotbar_changed() -> void:
	_update_display()


func open() -> void:
	is_open = true
	visible = true


func close() -> void:
	is_open = false
	visible = false
	tooltip_panel.visible = false


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_event := event as InputEventMouseButton
		var hit := _slot_at_mouse(mouse_event.position)
		if mouse_event.pressed:
			if bool(hit.get("found", false)):
				_start_drag(bool(hit["is_hotbar"]), int(hit["index"]))
		else:
			if dragging and bool(hit.get("found", false)):
				_try_drop_to_slot(bool(hit["is_hotbar"]), int(hit["index"]))
			elif dragging:
				_stop_drag()
