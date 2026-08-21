extends Control
## 《墨渊》流派面板 UI（程序化生成，无场景文件）。
## 按 T 键切换显隐；打开时暂停游戏（Engine.time_scale = 0），关闭时恢复。

const FLOW_NAMES := ["守拙", "点墨", "藏锋"]

var panel: Panel
var level_label: Label
var skill_points_label: Label
var flow_name_label: Label
var damage_value: Label
var hp_value: Label
var speed_value: Label
var resource_value: Label
var desc_label: Label
var add_button: Button
var close_button: Button
var flow_buttons: Array[Button] = []


func _ready() -> void:
	# 根节点铺满全屏，用于拦截点击
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 默认字体
	var theme := Theme.new()
	theme.default_font = ThemeDB.fallback_font
	theme.default_font_size = 16
	self.theme = theme

	# 灰色遮罩（面板外区域，点击关闭）
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_overlay_gui_input)
	add_child(overlay)

	# 主面板
	panel = Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300.0
	panel.offset_top = -250.0
	panel.offset_right = 300.0
	panel.offset_bottom = 250.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	panel_style.border_color = Color(0.8, 0.7, 0.4, 1.0)
	panel_style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	_build_panel_content()
	refresh_ui()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("style_panel"):
		_toggle_panel()


func _toggle_panel() -> void:
	if visible:
		_close_panel()
	else:
		_open_panel()


func _open_panel() -> void:
	refresh_ui()
	visible = true
	Engine.time_scale = 0.0


func _close_panel() -> void:
	visible = false
	Engine.time_scale = 1.0


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_panel()


func _on_flow_button_pressed(index: int) -> void:
	FlowManager.switch_to(index)
	refresh_ui()


func _on_add_button_pressed() -> void:
	if GlobalStats.use_skill_point():
		print("消耗 1 技能点，剩余: ", GlobalStats.skill_points)
	else:
		print("技能点不足")
	refresh_ui()


func _on_close_button_pressed() -> void:
	_close_panel()


func refresh_ui() -> void:
	if level_label == null:
		return
	# 顶部统计
	level_label.text = "等级: %d" % GlobalStats.level
	skill_points_label.text = "技能点: %d" % GlobalStats.skill_points

	# 当前流派信息
	var flow: BaseFlow = FlowManager.get_current()
	flow_name_label.text = flow.flow_name
	damage_value.text = "%.2f" % flow.damage_mult
	hp_value.text = "%.2f" % flow.hp_mult
	speed_value.text = "%.2f" % flow.speed_mult
	resource_value.text = _resource_text(flow)
	desc_label.text = _flow_desc(flow)

	# 按钮高亮
	for i in range(flow_buttons.size()):
		var normal := flow_buttons[i].get_theme_stylebox("normal") as StyleBoxFlat
		if normal != null:
			if i == FlowManager.current_index:
				normal.border_color = Color("#c9a84c")
			else:
				normal.border_color = Color(0.0, 0.0, 0.0, 0.0)

	# 加点按钮可用状态
	add_button.disabled = GlobalStats.skill_points <= 0


func _resource_text(flow: BaseFlow) -> String:
	if flow is Flow_Shouzhuo:
		return "墨盾: %d/5" % (flow as Flow_Shouzhuo).shield
	elif flow is Flow_Dianmo:
		return "砚池: %.0f/100" % (flow as Flow_Dianmo).pool
	elif flow is Flow_Cangfeng:
		return "残影: %d/3" % (flow as Flow_Cangfeng).shadow
	return "--"


func _flow_desc(flow: BaseFlow) -> String:
	if flow is Flow_Shouzhuo:
		return "守拙如山，格挡时积累墨盾。"
	elif flow is Flow_Dianmo:
		return "点墨成兵，攻击命中积累砚池。"
	elif flow is Flow_Cangfeng:
		return "藏锋于身，闪避时积累残影。"
	return ""


func _build_panel_content() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 16)
	margin.add_child(root_vbox)

	# 顶部栏
	var top_bar := HBoxContainer.new()
	root_vbox.add_child(top_bar)
	top_bar.add_child(_make_label("流派系统", 24, Color("#d4c9a8")))

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_spacer)

	var stats_box := HBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 18)
	top_bar.add_child(stats_box)

	level_label = _make_label("等级: 1", 18, Color("#ffffff"))
	stats_box.add_child(level_label)
	skill_points_label = _make_label("技能点: 2", 18, Color("#ffffff"))
	stats_box.add_child(skill_points_label)

	# 中部
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 20)
	root_vbox.add_child(middle)

	# 左侧按钮列
	var left_col := VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(180.0, 0.0)
	left_col.add_theme_constant_override("separation", 10)
	middle.add_child(left_col)

	flow_buttons.clear()
	for i in range(FLOW_NAMES.size()):
		var btn := _create_flow_button(FLOW_NAMES[i], i)
		left_col.add_child(btn)
		flow_buttons.append(btn)

	# 右侧信息
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 15)
	middle.add_child(right_col)

	flow_name_label = _make_label("", 20, Color("#ffffff"))
	right_col.add_child(flow_name_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	right_col.add_child(grid)

	grid.add_child(_make_label("伤害倍率", 16, Color("#8a8a8a")))
	damage_value = _make_label("1.00", 16, Color("#ffffff"))
	grid.add_child(damage_value)
	grid.add_child(_make_label("血量倍率", 16, Color("#8a8a8a")))
	hp_value = _make_label("1.00", 16, Color("#ffffff"))
	grid.add_child(hp_value)
	grid.add_child(_make_label("速度倍率", 16, Color("#8a8a8a")))
	speed_value = _make_label("1.00", 16, Color("#ffffff"))
	grid.add_child(speed_value)
	grid.add_child(_make_label("核心资源", 16, Color("#8a8a8a")))
	resource_value = _make_label("", 16, Color("#ffffff"))
	grid.add_child(resource_value)

	right_col.add_child(HSeparator.new())

	desc_label = _make_label("", 15, Color("#aaaaaa"))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_col.add_child(desc_label)

	# 底部
	var bottom := HBoxContainer.new()
	root_vbox.add_child(bottom)

	add_button = Button.new()
	add_button.text = "+ 加点"
	add_button.custom_minimum_size = Vector2(120.0, 40.0)
	add_button.pressed.connect(_on_add_button_pressed)
	bottom.add_child(add_button)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(bottom_spacer)

	close_button = Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(100.0, 40.0)
	close_button.pressed.connect(_on_close_button_pressed)
	bottom.add_child(close_button)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _create_flow_button(text: String, index: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0.0, 50.0)
	btn.add_theme_font_override("font", ThemeDB.fallback_font)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#2a2a30")
	normal.set_border_width_all(2)
	normal.border_color = Color(0.0, 0.0, 0.0, 0.0)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("#3a3a48")
	hover.set_border_width_all(2)
	hover.border_color = Color(0.0, 0.0, 0.0, 0.0)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	btn.pressed.connect(_on_flow_button_pressed.bind(index))
	return btn
