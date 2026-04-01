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
	
	_update_display()


func _create_slot(index: int, is_hotbar: bool) -> PanelContainer:
	var slot_panel := PanelContainer.new()
	slot_panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot_panel.set_meta("slot_index", index)
	slot_panel.set_meta("is_hotbar", is_hotbar)
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	
	var icon_label := Label.new()
	icon_label.name = "Icon"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 28)
	var icon_tex := TextureRect.new()
	icon_tex.name = "IconTex"
	icon_tex.custom_minimum_size = Vector2(28, 28)
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_tex.visible = false
	vbox.add_child(icon_tex)
	vbox.add_child(icon_label)
	
	var count_label := Label.new()
	count_label.name = "Count"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.position = Vector2(SLOT_SIZE - 20, SLOT_SIZE - 20)
	vbox.add_child(count_label)
	
	slot_panel.add_child(vbox)
	
	return slot_panel


func _process(_delta: float) -> void:
	_update_display()
	_update_tooltip()


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
	var vbox: VBoxContainer = slot.get_child(0) as VBoxContainer
	var icon_label: Label = vbox.get_node("Icon") as Label
	var icon_tex: TextureRect = vbox.get_node("IconTex") as TextureRect
	var count_label: Label = vbox.get_node("Count") as Label
	
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
		if item["count"] > 1:
			count_label.text = str(item["count"])
		else:
			count_label.text = ""


func _update_tooltip() -> void:
	if not is_open or not inv_manager:
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
