class_name SkillTooltip
extends Control
## 技能悬停提示（全局单例层）：面板中任意技能名悬停即弹出墨色小窗，
## 显示《墨渊项目书》技能效果；移出即隐藏。用 attach() 一次接入。

const MAX_WIDTH := 300.0

static var _instance: Panel = null
static var _label: Label = null
static var _parent_requested := false


static func _ensure() -> void:
	if _instance != null:
		return
	_instance = Panel.new()
	_instance.name = "SkillTooltip"
	_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_instance.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.09, 1.0)
	style.border_color = Color(0.8, 0.7, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	_instance.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	_instance.add_child(margin)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", ThemeDB.fallback_font)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color("#e4e0cc"))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(MAX_WIDTH - 26.0, 0.0)
	margin.add_child(_label)


static func show_text(host: Control, at_global: Vector2, skill_name: String, effect: String) -> void:
	_ensure()
	if _instance.get_parent() == null and not _parent_requested:
		_parent_requested = true
		host.get_tree().root.add_child.call_deferred(_instance)
	_label.text = "[%s]\n%s" % [skill_name, effect]
	# 方框大小按文字长度自适应：宽度封顶自动换行，高度按换行估算
	var texts := _label.text.split("\n")
	var font: Font = _label.get_theme_font("font")
	var fsize: int = _label.get_theme_font_size("font_size")
	var max_w := 0.0
	for ln in texts:
		max_w = maxf(max_w, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x)
	var box_w := clampf(max_w + 28.0, 120.0, MAX_WIDTH)
	var inner_w := box_w - 28.0
	var line_h := font.get_height(fsize) + 5.0
	var total_h := 0.0
	for ln in texts:
		var w := font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		total_h += maxi(1, int(ceil(w / inner_w))) * line_h
	_instance.size = Vector2(box_w, maxf(total_h + 20.0, 34.0))
	var vp := host.get_viewport_rect().size
	var pos := at_global + Vector2(14.0, 18.0)
	if pos.x + _instance.size.x > vp.x - 8.0:
		pos.x = at_global.x - _instance.size.x - 14.0
	pos.y = clampf(pos.y, 6.0, maxf(6.0, vp.y - _instance.size.y - 6.0))
	_instance.global_position = pos
	_instance.visible = true


static func hide_tip() -> void:
	if _instance != null:
		_instance.visible = false


## 给技能名 Label 挂上悬停提示（供 T / F 面板调用）
static func attach(host: Control, label: Label) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_entered.connect(_on_hover.bind(host, label))
	label.mouse_exited.connect(_on_exit)


## 给流派按钮挂上悬停提示（供 T / F 面板调用）
static func attach_button(host: Control, button: Button) -> void:
	button.mouse_entered.connect(_on_button_hover.bind(host, button))
	button.mouse_exited.connect(_on_exit)


static func _on_button_hover(host: Control, button: Button) -> void:
	var flow_name: String = button.text.trim_prefix("🔒 ")
	var desc := SkillDescriptions.get_flow_desc(flow_name)
	if desc == "":
		return
	show_text(host, button.global_position, flow_name, desc)


static func _on_hover(host: Control, label: Label) -> void:
	var skill_name: String = label.text
	if skill_name == "" or skill_name in ["--", "未装备", "未解锁"]:
		return
	var effect := SkillDescriptions.get_effect(skill_name)
	if effect == "":
		return
	show_text(host, label.global_position, skill_name, effect)


static func _on_exit() -> void:
	hide_tip()
