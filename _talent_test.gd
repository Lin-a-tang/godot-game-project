extends Node3D
## 勾动词条落地测试：破锋减速 / 游丝格挡回墨+窗口 / 重墨数值

var player: Node3D = null
var enemy: Node3D = null

func _ready() -> void:
	_spawn()
	await get_tree().process_frame
	_test_gougou_heavy()
	_test_gougou_break()
	_test_gougou_youling()
	print("TALENT TESTS PASSED")
	get_tree().quit()

func _spawn() -> void:
	player = CharacterBody3D.new()
	player.name = "TestPlayer"
	player.set_script(load("res://scripts/Player.gd"))
	var mi := MeshInstance3D.new()
	mi.name = "MeshInstance3D"
	player.add_child(mi)
	add_child(player)
	player.global_position = Vector3(0, 0.9, 0)
	enemy = CharacterBody3D.new()
	enemy.name = "TestEnemy"
	enemy.set_script(load("res://scripts/Enemy.gd"))
	add_child(enemy)
	enemy.global_position = Vector3(0, 0.9, -2.5)

func _test_gougou_heavy() -> void:
	TalentManager.selected_talents["gougou"] = "gougou_heavy"
	player._refresh_talents()
	print("重墨: damage_mult=", player._get_bonus_damage_multiplier(), " cost_mult=", player._get_ink_cost_multiplier())
	assert(is_equal_approx(player._get_bonus_damage_multiplier(), 1.3))
	assert(is_equal_approx(player._get_ink_cost_multiplier(), 1.5))
	print("heavy OK")

func _test_gougou_break() -> void:
	TalentManager.selected_talents["gougou"] = "gougou_break"
	var ink_before: float = enemy.ink
	player.apply_damage_in_area(3.0, 10.0)
	print("破锋: enemy ink ", ink_before, " -> ", enemy.ink, " speed_factor=", enemy.get_speed_factor())
	assert(enemy.ink < ink_before)
	assert(enemy.get_speed_factor() < 0.75)
	enemy.apply_slow(0.7, 0.3)
	assert(enemy.get_speed_factor() < 0.75)
	await get_tree().create_timer(0.5).timeout
	print("破锋: 减速到期 speed_factor=", enemy.get_speed_factor())
	assert(is_equal_approx(enemy.get_speed_factor(), 1.0))
	print("break OK")

func _test_gougou_youling() -> void:
	TalentManager.selected_talents["gougou"] = "gougou_youling"
	player._refresh_talents()
	player.current_ink = 50.0
	player.state = player.State.BLOCKING
	var ink_before: float = player.current_ink
	# 正面攻击（敌人位于玩家正前方 -Z）
	player.take_damage(10.0, Vector3(0, 0, -2.0))
	var expect: float = ink_before - 10.0 * (1.0 - player.block_damage_reduction) + 5.0
	print("游丝: ink ", ink_before, " -> ", player.current_ink, " (期望 ", expect, ")")
	assert(is_equal_approx(player.current_ink, expect))
	# 格挡窗口加宽验证：63° 侧面，默认120°窗口挡不下（cos63<cos60），130°加宽后挡下
	player.current_ink = 50.0
	var at := Vector3(-sin(deg_to_rad(63.0)), 0.0, -cos(deg_to_rad(63.0))) * 2.0
	player.take_damage(10.0, at)
	print("游丝: 63°侧面 block后 ink=", player.current_ink, "（未减伤则=40）")
	assert(player.current_ink == 50.0 - 10.0 * (1.0 - player.block_damage_reduction) + 5.0)
	# 无词条时（120°默认窗口）同角度攻击应减伤失败
	TalentManager.selected_talents.clear()
	player._refresh_talents()
	player.current_ink = 50.0
	player.take_damage(10.0, at)
	print("游丝: 无词条 63°侧面 block后 ink=", player.current_ink, "（未格挡则=40）")
	assert(is_equal_approx(player.current_ink, 40.0))
	player.state = player.State.IDLE
	print("youling OK")
