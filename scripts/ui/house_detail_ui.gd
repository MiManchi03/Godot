extends Control

signal request_assign_villager(villager_entity_id: String)
signal request_unassign()

var _house_entity_id: String = ""
var _house_display_name: String = ""
var _occupant_entity_id: String = ""
var _occupant_name: String = "无"
var _occupant_fatigue: float = 0.0
var _villager_items: Array[Dictionary] = []

var _title_label: Label
var _occupant_label: Label
var _fatigue_label: Label
var _occupant_card: PanelContainer
var _occupant_avatar_panel: PanelContainer
var _occupant_avatar_label: Label
var _occupant_card_name: Label
var _occupant_card_status: Label
var _occupant_card_fatigue: Label
var _assign_button: Button
var _unassign_button: Button
var _list_panel: PanelContainer
var _list_scroll: ScrollContainer
var _list_box: VBoxContainer


func _ready() -> void:
	visible = false
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_ui()


func open_panel(data: Dictionary) -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	_house_entity_id = str(data.get("house_entity_id", ""))
	_house_display_name = str(data.get("house_display_name", "房屋"))
	_occupant_entity_id = str(data.get("occupant_entity_id", ""))
	_occupant_name = str(data.get("occupant_name", "无"))
	_occupant_fatigue = float(data.get("occupant_fatigue", 0.0))
	_villager_items.clear()
	var villager_raw = data.get("villagers", [])
	if villager_raw is Array:
		for entry_variant in (villager_raw as Array):
			if entry_variant is Dictionary:
				_villager_items.append(entry_variant as Dictionary)
	_update_static_ui()
	_rebuild_villager_list()
	_list_panel.visible = false
	visible = true
	get_viewport().gui_release_focus()
	grab_focus()


func close_panel() -> void:
	visible = false
	_list_panel.visible = false


func _setup_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.52)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var root := PanelContainer.new()
	root.anchor_left = 0.5
	root.anchor_top = 0.5
	root.anchor_right = 0.5
	root.anchor_bottom = 0.5
	root.offset_left = -430.0
	root.offset_top = -260.0
	root.offset_right = 430.0
	root.offset_bottom = 260.0
	add_child(root)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.12, 0.11, 0.96)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.24, 0.86, 0.95, 0.9)
	panel_style.set_corner_radius_all(10)
	root.add_theme_stylebox_override("panel", panel_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	root.add_child(hbox)

	_list_panel = PanelContainer.new()
	_list_panel.custom_minimum_size = Vector2(300.0, 460.0)
	_list_panel.visible = false
	hbox.add_child(_list_panel)

	var list_style := StyleBoxFlat.new()
	list_style.bg_color = Color(0.14, 0.16, 0.15, 0.98)
	list_style.border_width_left = 1
	list_style.border_width_top = 1
	list_style.border_width_right = 1
	list_style.border_width_bottom = 1
	list_style.border_color = Color(0.30, 0.30, 0.30, 0.9)
	list_style.set_corner_radius_all(8)
	_list_panel.add_theme_stylebox_override("panel", list_style)

	var list_vbox := VBoxContainer.new()
	list_vbox.add_theme_constant_override("separation", 8)
	_list_panel.add_child(list_vbox)

	var list_title := Label.new()
	list_title.text = "选择入住村民"
	list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_title.add_theme_font_size_override("font_size", 16)
	list_vbox.add_child(list_title)

	_list_scroll = ScrollContainer.new()
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_vbox.add_child(_list_scroll)

	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 6)
	_list_scroll.add_child(_list_box)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	hbox.add_child(content)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	content.add_child(_title_label)

	var info_panel := PanelContainer.new()
	content.add_child(info_panel)
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0.16, 0.18, 0.17, 0.95)
	info_style.set_corner_radius_all(8)
	info_panel.add_theme_stylebox_override("panel", info_style)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 8)
	info_panel.add_child(info_vbox)

	_occupant_card = PanelContainer.new()
	info_vbox.add_child(_occupant_card)
	var occ_style := StyleBoxFlat.new()
	occ_style.bg_color = Color(0.20, 0.23, 0.22, 0.98)
	occ_style.set_corner_radius_all(6)
	_occupant_card.add_theme_stylebox_override("panel", occ_style)

	var occ_row := HBoxContainer.new()
	occ_row.add_theme_constant_override("separation", 10)
	_occupant_card.add_child(occ_row)

	_occupant_avatar_panel = PanelContainer.new()
	_occupant_avatar_panel.custom_minimum_size = Vector2(36.0, 36.0)
	occ_row.add_child(_occupant_avatar_panel)
	var occ_avatar_style := StyleBoxFlat.new()
	occ_avatar_style.bg_color = Color(0.35, 0.55, 0.85, 1.0)
	occ_avatar_style.set_corner_radius_all(18)
	_occupant_avatar_panel.add_theme_stylebox_override("panel", occ_avatar_style)

	_occupant_avatar_label = Label.new()
	_occupant_avatar_label.text = "?"
	_occupant_avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_occupant_avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_occupant_avatar_label.add_theme_font_size_override("font_size", 16)
	_occupant_avatar_panel.add_child(_occupant_avatar_label)

	var occ_meta := VBoxContainer.new()
	occ_meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	occ_meta.add_theme_constant_override("separation", 3)
	occ_row.add_child(occ_meta)

	_occupant_card_name = Label.new()
	_occupant_card_name.add_theme_font_size_override("font_size", 16)
	occ_meta.add_child(_occupant_card_name)

	_occupant_card_fatigue = Label.new()
	_occupant_card_fatigue.add_theme_font_size_override("font_size", 14)
	_occupant_card_fatigue.modulate = Color(0.87, 0.91, 0.95, 0.95)
	occ_meta.add_child(_occupant_card_fatigue)

	_occupant_card_status = Label.new()
	_occupant_card_status.add_theme_font_size_override("font_size", 13)
	occ_row.add_child(_occupant_card_status)

	_occupant_label = Label.new()
	_occupant_label.add_theme_font_size_override("font_size", 18)
	info_vbox.add_child(_occupant_label)

	_fatigue_label = Label.new()
	_fatigue_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(_fatigue_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 20)
	content.add_child(button_row)

	_assign_button = Button.new()
	_assign_button.text = "入住"
	_assign_button.custom_minimum_size = Vector2(180.0, 46.0)
	_assign_button.pressed.connect(_on_assign_pressed)
	button_row.add_child(_assign_button)
	_apply_button_color(_assign_button, Color(0.16, 0.72, 0.26, 1.0))

	_unassign_button = Button.new()
	_unassign_button.text = "搬离"
	_unassign_button.custom_minimum_size = Vector2(180.0, 46.0)
	_unassign_button.pressed.connect(_on_unassign_pressed)
	button_row.add_child(_unassign_button)
	_apply_button_color(_unassign_button, Color(0.78, 0.18, 0.18, 1.0))

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(96.0, 34.0)
	close_btn.pressed.connect(close_panel)
	content.add_child(close_btn)


func _update_static_ui() -> void:
	_title_label.text = "%s 详情" % _house_display_name
	_occupant_label.text = "当前入住：%s" % _occupant_name
	_fatigue_label.text = "疲劳值：%.0f" % _occupant_fatigue

	var has_occupant := not _occupant_entity_id.is_empty()
	_assign_button.disabled = has_occupant
	_unassign_button.disabled = not has_occupant
	if not has_occupant:
		_fatigue_label.text = "疲劳值：--"
		_occupant_card_name.text = "暂无入住村民"
		_occupant_card_fatigue.text = "疲劳值：--"
		_occupant_card_status.text = "空房"
		_occupant_card_status.modulate = Color(0.48, 0.93, 0.52, 1.0)
		_set_avatar_style(_occupant_avatar_panel, _occupant_avatar_label, "?", Color(0.42, 0.42, 0.42, 1.0))
	else:
		_occupant_card_name.text = _occupant_name
		_occupant_card_fatigue.text = "疲劳值：%.0f" % _occupant_fatigue
		_occupant_card_status.text = "已入住"
		_occupant_card_status.modulate = Color(1.0, 0.86, 0.28, 1.0)
		_set_avatar_style(_occupant_avatar_panel, _occupant_avatar_label, _name_initial(_occupant_name), _color_from_text(_occupant_name))


func _rebuild_villager_list() -> void:
	for child in _list_box.get_children():
		child.queue_free()

	if _villager_items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "当前村庄暂无可入住村民"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.modulate = Color(0.86, 0.86, 0.86, 0.92)
		_list_box.add_child(empty_label)
		return

	for item in _villager_items:
		var card := _create_villager_card(item)
		_list_box.add_child(card)


func _create_villager_card(item: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280.0, 58.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.20, 0.19, 0.96)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var avatar_panel := PanelContainer.new()
	avatar_panel.custom_minimum_size = Vector2(30.0, 30.0)
	row.add_child(avatar_panel)
	var avatar_label := Label.new()
	avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar_label.add_theme_font_size_override("font_size", 14)
	avatar_panel.add_child(avatar_label)
	var villager_name := str(item.get("name", "Villager"))
	_set_avatar_style(avatar_panel, avatar_label, _name_initial(villager_name), _color_from_text(villager_name))

	var name_label := Label.new()
	name_label.text = villager_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var status_label := Label.new()
	var occupied := bool(item.get("occupied", false))
	var selectable := bool(item.get("selectable", true))
	status_label.text = "已入住" if occupied else "未入住"
	status_label.modulate = Color(1.0, 0.86, 0.28, 1.0) if occupied else Color(0.40, 0.95, 0.44, 1.0)
	if not selectable:
		status_label.text = "未就绪"
		status_label.modulate = Color(0.78, 0.78, 0.78, 1.0)
	row.add_child(status_label)

	var pick_btn := Button.new()
	pick_btn.text = "选择"
	pick_btn.disabled = occupied or not selectable
	pick_btn.pressed.connect(_on_pick_villager.bind(str(item.get("entity_id", ""))))
	row.add_child(pick_btn)

	return card


func _on_assign_pressed() -> void:
	if _assign_button.disabled:
		return
	_list_panel.visible = not _list_panel.visible


func _on_unassign_pressed() -> void:
	if _unassign_button.disabled:
		return
	request_unassign.emit()


func _on_pick_villager(villager_entity_id: String) -> void:
	if villager_entity_id.is_empty():
		return
	request_assign_villager.emit(villager_entity_id)


func _apply_button_color(btn: Button, color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.34, 0.34, 0.34, 0.9)
	btn.add_theme_stylebox_override("disabled", disabled)


func _name_initial(name_text: String) -> String:
	var t := name_text.strip_edges()
	if t.is_empty():
		return "?"
	return t.substr(0, 1).to_upper()


func _color_from_text(text: String) -> Color:
	var hash_val: int = text.hash()
	var h: int = abs(hash_val) % 360
	return Color.from_hsv(float(h) / 360.0, 0.55, 0.86, 1.0)


func _set_avatar_style(panel: PanelContainer, label: Label, initial: String, color: Color) -> void:
	if panel == null or label == null:
		return
	label.text = initial
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(999)
	panel.add_theme_stylebox_override("panel", style)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			close_panel()
