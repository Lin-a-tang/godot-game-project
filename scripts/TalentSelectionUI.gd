class_name TalentSelectionUI
extends Control
## 3选1 词条选择界面（450x380，含 ScrollContainer）。

var _fragment_type: String = ""
var _talent_buttons: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func show_for_fragment(fragment_type: String) -> void:
	_fragment_type = fragment_type
	_refresh()
	visible = true
	Engine.time_scale = 0.0


func close() -> void:
	visible = false
	if not SafePointManager.is_panel_open:
		Engine.time_scale = 1.0
	TalentManager.finish_choice()


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
	panel.offset_left = -225.0
	panel.offset_top = -190.0
	panel.offset_right = 225.0
	panel.offset_bottom = 190.0
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

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "选择词条"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#d4c9a8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	for i in range(3):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0.0, 70.0)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_talent_button_pressed.bind(i))
		vbox.add_child(btn)
		_talent_buttons.append(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消选择（清空词条）"
	cancel_btn.pressed.connect(_on_cancel_pressed)
	vbox.add_child(cancel_btn)


func _refresh() -> void:
	var ids: Array = TalentData.get_fragment_talents(_fragment_type)
	var selected_id: String = TalentManager.get_selected_talent(_fragment_type)
	for i in range(3):
		if i < ids.size():
			var t: Dictionary = TalentData.get_talent(ids[i])
			_talent_buttons[i].text = "%s\n%s" % [t.get("name", ""), t.get("desc", "")]
			if ids[i] == selected_id:
				_talent_buttons[i].text = "[已装备] " + _talent_buttons[i].text
				_talent_buttons[i].modulate = Color(0.8, 0.9, 0.5)
			else:
				_talent_buttons[i].modulate = Color.WHITE
			_talent_buttons[i].visible = true
		else:
			_talent_buttons[i].visible = false


func _on_talent_button_pressed(index: int) -> void:
	var ids: Array = TalentData.get_fragment_talents(_fragment_type)
	if index >= ids.size():
		return
	TalentManager.select_talent(_fragment_type, ids[index])
	close()


func _on_cancel_pressed() -> void:
	# 清空该碎片的词条选择
	TalentManager.select_talent(_fragment_type, "")
	close()
