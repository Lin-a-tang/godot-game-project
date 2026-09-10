extends Node3D
## 画桌庇护测试：靠近自动回墨 + 怪物自动远离

var player: Node3D = null
var enemy: Node3D = null
var table: SafePoint = null

func _ready() -> void:
	# 画桌（SafePoint Area3D + 碰撞盒）
	table = SafePoint.new()
	table.name = "Table"
	var shape_node := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.0
	shape_node.shape = sphere
	table.add_child(shape_node)
	add_child(table)
	table.global_position = Vector3(0, 0.5, 0)
	# 玩家（CharacterBody3D + Player.gd，带碰撞体，位于画桌范围内）
	player = CharacterBody3D.new()
	player.name = "TestPlayer"
	player.set_script(load("res://scripts/Player.gd"))
	var mi := MeshInstance3D.new()
	mi.name = "MeshInstance3D"
	player.add_child(mi)
	var cap := CollisionShape3D.new()
	var cap_shape := CapsuleShape3D.new()
	cap_shape.radius = 0.4
	cap_shape.height = 1.6
	cap.shape = cap_shape
	player.add_child(cap)
	add_child(player)
	player.global_position = Vector3(0, 0.9, 0.5)
	player.current_ink = 40.0
	# 怪物（Enemy_Moying.gd，带逃逸逻辑）在桌旁 5 单位
	enemy = CharacterBody3D.new()
	enemy.name = "TestEnemy"
	enemy.set_script(load("res://scripts/Enemy_Moying.gd"))
	var ecol := CollisionShape3D.new()
	var eshape := CapsuleShape3D.new()
	eshape.radius = 0.35
	eshape.height = 1.1
	ecol.shape = eshape
	enemy.add_child(ecol)
	add_child(enemy)
	enemy.global_position = Vector3(0, 0.75, 5.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("玩家入桌: ", table._player_in_range, " enemy fleeing=", enemy.is_fleeing())
	assert(table._player_in_range)
	await get_tree().create_timer(1.0).timeout
	print("回墨: current=", player.current_ink, "（初始40，期望≈55）")
	assert(player.current_ink >= 52.0)
	assert(enemy.is_fleeing())
	var dist_now: float = enemy.global_position.distance_to(table.global_position)
	print("怪物距离桌面: ", round(dist_now * 100.0) / 100.0, "（初始5，应变大）")
	assert(dist_now > 5.2)
	print("SAFEPOINT TESTS PASSED")
	Engine.time_scale = 1.0
	get_tree().quit()
