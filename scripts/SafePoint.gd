class_name SafePoint
extends Area3D
## 安全点（画桌）：玩家进入范围自动回墨（恢复生命值），
## 怪物会自动远离画桌（庇护区域）；按 F 键打开安全点面板（流派/技能/词条）。

@export var heal_rate: float = 15.0       ## 每秒自动回墨量（生命值）
@export var flee_range: float = 12.0      ## 触发怪物逃离的桌周半径
@export var flee_refresh: float = 0.6     ## 单次逃离指令持续（每帧刷新可延长）

var _player_in_range: bool = false
var _player: Node = null
var _interact_label: Label3D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_label()


func _physics_process(delta: float) -> void:
	if not _player_in_range or _player == null or not is_instance_valid(_player):
		return
	# 自动补墨：恢复生命值（墨量）
	if _player.has_method("restore_ink"):
		_player.call("restore_ink", heal_rate * delta)
	_pulse_flee()


func _setup_label() -> void:
	_interact_label = Label3D.new()
	_interact_label.text = "画桌 · 自动回复墨量 · 按 F 打开面板"
	_interact_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_interact_label.font_size = 32
	_interact_label.outline_size = 6
	_interact_label.position = Vector3(0.0, 2.0, 0.0)
	_interact_label.visible = false
	add_child(_interact_label)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_player = body
		SafePointManager.set_active(self)
		if _interact_label != null:
			_interact_label.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_player = null
		if SafePointManager.current_safe_point == self:
			SafePointManager.set_active(null)
		if _interact_label != null:
			_interact_label.visible = false


## 让桌周怪物自动远离画桌
func _pulse_flee() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.has_method("start_flee"):
			continue
		var flat: Vector3 = enemy.global_position - global_position
		flat.y = 0.0
		if flat.length() <= flee_range:
			enemy.call("start_flee", global_position, flee_refresh)


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		SafePointManager.open_panel(self)
