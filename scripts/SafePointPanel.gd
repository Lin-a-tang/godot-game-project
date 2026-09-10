class_name SafePointPanel
extends Control
## 安全点功能面板（700x550，含 ScrollContainer）。
## 功能：更换流派 / 更换技能 / 更换词条 / 分配技能点（墨量在画桌范围内自动回复，无需手动补墨）。

var _ink_label: Label
var _stats_label: Label
var _flow_name_label: Label
var _flow_stat_label: Label
var _equip_box: VBoxContainer
var _talent_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func open() -> void:
	_refresh()
	visible = true
	Engine.time_scale = 0.0


func close() -> void:
	SkillTooltip.hide_tip()
	visible = false
	Engine.time_scale = 1.0


func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -350.0
	panel.offset_top = -275.0
	panel.offset_right = 350.0
	panel.offset_bottom = 275.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(0.8, 0.7, 0.4)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# 标题栏
	var title_bar := HBoxContainer.new()
	vbox.add_child(title_bar)
	title_bar.add_child(_make_label("安全点（画桌）", 22, Color("#d4c9a8")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(spacer)
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_on_close_pressed)
	title_bar.add_child(close_btn)

	# 墨量（自动回复，无需手动补墨）
	var ink_row := HBoxContainer.new()
	vbox.add_child(ink_row)
	_ink_label = _make_label("墨量: 100/100（靠近画桌自动回复）", 16, Color("#ffffff"))
	ink_row.add_child(_ink_label)

	# 等级 + 技能点
	_stats_label = _make_label("等级: 1  技能点: 2", 16, Color("#CCCCCC"))
	vbox.add_child(_stats_label)

	vbox.add_child(HSeparator.new())

	# 更换流派
	vbox.add_child(_make_label("更换流派", 18, Color("#d4c9a8")))
	var flow_row := HBoxContainer.new()
	vbox.add_child(flow_row)
	var flow_list := VBoxContainer.new()
	flow_list.custom_minimum_size = Vector2(160.0, 0.0)
	flow_list.add_theme_constant_override("separation", 6)
	flow_row.add_child(flow_list)
	var flow_info := VBoxContainer.new()
	flow_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow_info.add_theme_constant_override("separation", 6)
	flow_row.add_child(flow_info)
	_flow_name_label = _make_label("当前流派: 守拙", 16, Color("#ffffff"))
	flow_info.add_child(_flow_name_label)
	_flow_stat_label = _make_label("伤害 1.00  血量 1.40  速度 0.90", 14, Color("#aaaaaa"))
	flow_info.add_child(_flow_stat_label)

	for i in range(FlowManager.flows.size()):
		var btn := Button.new()
		btn.text = FlowManager.flows[i].flow_name
		if not FlowManager.is_flow_unlocked(i):
			btn.text = "🔒 " + btn.text
			btn.disabled = true
		else:
			SkillTooltip.attach_button(self, btn)
		btn.pressed.connect(_on_flow_pressed.bind(i))
		flow_list.add_child(btn)

	vbox.add_child(HSeparator.new())

	# 技能装备
	vbox.add_child(_make_label("技能装备", 18, Color("#d4c9a8")))
	_equip_box = VBoxContainer.new()
	_equip_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_equip_box)

	vbox.add_child(HSeparator.new())

	# 词条系统
	vbox.add_child(_make_label("词条系统", 18, Color("#d4c9a8")))
	_talent_box = VBoxContainer.new()
	_talent_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_talent_box)

	vbox.add_child(HSeparator.new())

	# 分配技能点
	var point_btn := Button.new()
	point_btn.text = "分配技能点（消耗1技能点解锁）"
	point_btn.pressed.connect(_on_allocate_point_pressed)
	vbox.add_child(point_btn)


func _refresh() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		_ink_label.text = "墨量: %.0f/%.0f" % [player.current_ink, player.max_ink]
	_stats_label.text = "等级: %d  技能点: %d" % [GlobalStats.level, GlobalStats.skill_points]
	var flow: BaseFlow = FlowManager.get_current()
	_flow_name_label.text = "当前流派: %s" % flow.flow_name
	_flow_stat_label.text = "伤害 %.2f  血量 %.2f  速度 %.2f" % [flow.damage_mult, flow.hp_mult, flow.speed_mult]
	_refresh_equip()
	_refresh_talents()


func _refresh_equip() -> void:
	for child in _equip_box.get_children():
		_equip_box.remove_child(child)
		child.queue_free()
	var flow: BaseFlow = FlowManager.get_current()
	for slot in ["q", "r", "passive"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_equip_box.add_child(row)
		row.add_child(_make_label("%s: " % slot, 14, Color("#8a8a8a")))
		var skill_id: String = flow.equipped_skills.get(slot, "")
		var skill_name: String = flow.skill_data.get(skill_id, {}).get("name", "未装备")
		var name_label := _make_label(skill_name, 14, Color("#ffffff"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		SkillTooltip.attach(self, name_label)
		row.add_child(name_label)
		var btn := Button.new()
		btn.text = "更换"
		btn.pressed.connect(_on_equip_pressed.bind(slot))
		row.add_child(btn)


func _refresh_talents() -> void:
	for child in _talent_box.get_children():
		_talent_box.remove_child(child)
		child.queue_free()
	for fragment in TalentData.FRAGMENT_TYPES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_talent_box.add_child(row)
		var fname: String = TalentData.FRAGMENT_NAMES.get(fragment, fragment)
		row.add_child(_make_label("%s: " % fname, 14, Color("#8a8a8a")))
		var talent_id: String = TalentManager.get_selected_talent(fragment)
		var tname: String = "未解锁"
		if talent_id != "":
			tname = TalentData.get_talent(talent_id).get("name", "")
		var name_label := _make_label(tname, 14, Color("#ffffff"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		if fragment in TalentManager.unlocked_fragments:
			var btn := Button.new()
			btn.text = "更换"
			btn.pressed.connect(_on_talent_change_pressed.bind(fragment))
			row.add_child(btn)


func _on_close_pressed() -> void:
	SafePointManager.close_panel()


func _on_flow_pressed(index: int) -> void:
	FlowManager.switch_to(index)
	_refresh()


func _on_equip_pressed(slot: String) -> void:
	_show_skill_selector(slot)


func _show_skill_selector(slot: String) -> void:
	var flow: BaseFlow = FlowManager.get_current()
	var skill_list: Array = flow.get_unlocked_active_skills() if slot != "passive" else flow.get_unlocked_passive_skills()
	if skill_list.is_empty():
		print("没有可用的技能")
		return
	# 弹出技能选择列表
	var popup := Panel.new()
	popup.anchor_left = 0.5
	popup.anchor_top = 0.5
	popup.anchor_right = 0.5
	popup.anchor_bottom = 0.5
	popup.offset_left = -150.0
	popup.offset_top = -130.0
	popup.offset_right = 150.0
	popup.offset_bottom = 130.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.8, 0.7, 0.4)
	style.set_border_width_all(1)
	popup.add_theme_stylebox_override("panel", style)
	add_child(popup)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	popup.add_child(vbox)

	vbox.add_child(_make_label("选择技能", 18, Color("#d4c9a8")))
	for skill_id in skill_list:
		var btn := Button.new()
		var sdata: Dictionary = flow.skill_data[skill_id]
		btn.text = sdata.get("name", skill_id)
		btn.pressed.connect(_on_skill_selected.bind(slot, skill_id, popup))
		vbox.add_child(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(popup.queue_free)
	vbox.add_child(cancel_btn)


func _on_skill_selected(slot: String, skill_id: String, popup: Panel) -> void:
	var flow: BaseFlow = FlowManager.get_current()
	flow.equip_skill(slot, skill_id)
	popup.queue_free()
	_refresh()


func _on_talent_change_pressed(fragment: String) -> void:
	TalentManager.request_choice(fragment)


func _on_allocate_point_pressed() -> void:
	if GlobalStats.use_skill_point():
		print("分配技能点成功，剩余: %d" % GlobalStats.skill_points)
	else:
		print("技能点不足")
	_refresh()


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
