extends Node
## 安全点管理器（AutoLoad）。管理当前/最近安全点与面板开关，提供死亡复活位置。

signal safe_point_activated(safe_point: Node)
signal panel_opened()
signal panel_closed()

var current_safe_point: Node = null
var is_panel_open: bool = false
var last_safe_point: Node = null

var _panel: Control = null


func _ready() -> void:
	_panel = SafePointPanel.new()
	add_child(_panel)


func set_active(safe_point: Node) -> void:
	current_safe_point = safe_point
	if safe_point != null:
		last_safe_point = safe_point
	safe_point_activated.emit(safe_point)


func open_panel(safe_point: Node) -> void:
	current_safe_point = safe_point
	if safe_point != null:
		last_safe_point = safe_point
	is_panel_open = true
	_panel.open()
	panel_opened.emit()


func close_panel() -> void:
	is_panel_open = false
	_panel.close()
	panel_closed.emit()


## 死亡复活位置：最近激活的安全点附近；无安全点时回到起点画桌
func get_respawn_position() -> Vector3:
	if last_safe_point != null and is_instance_valid(last_safe_point):
		return last_safe_point.global_position + Vector3(0.0, 0.5, 1.0)
	return Vector3(0.0, 0.5, 1.5)
