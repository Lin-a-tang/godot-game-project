class_name FlashbackUI
extends Control
## 《墨渊》闪回演出（占位实现）：全屏墨色 + 逐行字幕 + 点击/空格推进。
## 只负责文本演出（竹林闪回先做可读版），后续可替换成真实过场。

var _lines: Array = []
var _line_index: int = 0
var _on_finished: Callable = Callable()

var _title_label: Label = null
var _line_label: Label = null
var _hint_label: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


## 开始闪回：lines 至少一行；点完最后一行后回调 on_finished
func start(lines: Array, on_finished: Callable) -> void:
	_lines = lines
	_line_index = 0
	_on_finished = on_finished
	_refresh()
	visible = true


## 推进一行；超出则关闭并回调
func advance() -> void:
	if not visible:
		return
	_line_index += 1
	if _line_index >= _lines.size():
		close()
	else:
		_refresh()


func close() -> void:
	visible = false
	var cb := _on_finished
	_on_finished = Callable()
	if cb.is_valid():
		cb.call()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		advance()


func _refresh() -> void:
	if _line_label == null:
		return
	if _line_index < _lines.size():
		var text: String = str(_lines[_line_index])
		_line_label.text = text
		_hint_label.text = "点击继续（%d / %d）" % [_line_index + 1, _lines.size()]


## ============ 界面 ============

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.02, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 30)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "记忆碎片「勾勒」"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", Color("#d4c9a8"))
	_title_label.name = "Title"
	vbox.add_child(_title_label)

	_line_label = Label.new()
	_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.add_theme_font_size_override("font_size", 20)
	_line_label.add_theme_color_override("font_color", Color("#e8e4d8"))
	_line_label.add_theme_constant_override("line_spacing", 10)
	_line_label.name = "Line"
	vbox.add_child(_line_label)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
	_hint_label.name = "Hint"
	vbox.add_child(_hint_label)
