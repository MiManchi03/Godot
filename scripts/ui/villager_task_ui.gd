extends Control

const BUILDING_OPTIONS := [
	{"id": "house", "label": "房屋", "emoji": "🏠"},
	{"id": "workshop", "label": "工坊", "emoji": "🔨"},
	{"id": "warehouse", "label": "仓库", "emoji": "📦"},
	{"id": "market", "label": "市场", "emoji": "🏪"},
	{"id": "well", "label": "水井", "emoji": "🪣"},
	{"id": "farm", "label": "农场", "emoji": "🌾"},
	{"id": "tower", "label": "塔楼", "emoji": "🗼"},
	{"id": "barrack", "label": "兵营", "emoji": "⚔️"},
]

var _target_villager: Node = null
var _on_bind_callback: Callable = Callable()

func _ready() -> void:
	visible = false
	_setup_ui()


func _setup_ui() -> void:
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_CENTER)
	bg.custom_minimum_size = Vector2(320, 220)
	bg.position = Vector2(-160, -110)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.13, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.26, 0.88, 0.96, 0.85)
	style.set_corner_radius_all(8)
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	bg.add_child(vbox)
	
	var title := Label.new()
	title.text = "绑定村民任务"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title)
	
	var start_label := Label.new()
	start_label.text = "起点建筑（工作地点）:"
	start_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(start_label)
	
	var start_option := OptionButton.new()
	start_option.custom_minimum_size = Vector2(280, 36)
	for opt in BUILDING_OPTIONS:
		start_option.add_item("%s %s" % [str(opt["emoji"]), str(opt["label"])], 0)
	vbox.add_child(start_option)
	
	var end_label := Label.new()
	end_label.text = "终点建筑（交付地点）:"
	end_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(end_label)
	
	var end_option := OptionButton.new()
	end_option.custom_minimum_size = Vector2(280, 36)
	for opt in BUILDING_OPTIONS:
		end_option.add_item("%s %s" % [str(opt["emoji"]), str(opt["label"])], 0)
	vbox.add_child(end_option)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(100, 36)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	hbox.add_child(cancel_btn)
	
	var confirm_btn := Button.new()
	confirm_btn.text = "确认绑定"
	confirm_btn.custom_minimum_size = Vector2(120, 36)
	confirm_btn.pressed.connect(_on_confirm_pressed.bind(start_option, end_option))
	hbox.add_child(confirm_btn)
	
	set_meta("start_option", start_option)
	set_meta("end_option", end_option)


func open_for_villager(villager: Node, callback: Callable) -> void:
	_target_villager = villager
	_on_bind_callback = callback
	
	var start_opt: OptionButton = get_meta("start_option")
	var end_opt: OptionButton = get_meta("end_option")
	if start_opt:
		start_opt.selected = 0
	if end_opt:
		end_opt.selected = 0
	
	visible = true
	get_viewport().gui_release_focus()
	grab_focus()


func close_panel() -> void:
	visible = false
	_target_villager = null
	_on_bind_callback = Callable()


func _on_cancel_pressed() -> void:
	close_panel()


func _on_confirm_pressed(start_opt: OptionButton, end_opt: OptionButton) -> void:
	if _target_villager == null:
		close_panel()
		return
	
	var start_idx: int = start_opt.get_selected_id()
	var end_idx: int = end_opt.get_selected_id()
	
	var start_id: String = BUILDING_OPTIONS[start_idx]["id"]
	var end_id: String = BUILDING_OPTIONS[end_idx]["id"]
	
	if _on_bind_callback.is_valid():
		_on_bind_callback.call(start_id, end_id)
	
	close_panel()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_panel()
