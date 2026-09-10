extends CharacterBody3D
## 《墨渊》灰盒战斗原型 —— 测试敌人 (GDScript 2.0 / Godot 4.3)
##
## 挂载到 CharacterBody3D 根节点（命名为 "Enemy"）。
## 需要手动创建的子节点：
##   - CollisionShape3D : 胶囊碰撞体（高 1.5 米，半径 0.5 米）
##   - MeshInstance3D   : 红色 CapsuleMesh
##   - Area3D "Hurtbox" : 覆盖整个胶囊（用于将来敌人的攻击检测）
##
## 无 AI 逻辑，仅作为攻击目标。


@export var max_ink: float = 50.0
@export var ink: float = 50.0
@export var exp_reward: float = 10.0
@export var knockback_distance: float = 0.5
@export var knockback_duration: float = 0.15
@export var death_shrink_time: float = 0.3

var is_dead: bool = false
var knockback_tween: Tween
var death_tween: Tween

## 破甲减速（词条「破锋勾勒」）：移动/冲刺速率乘子，超时恢复
var _slow_factor: float = 1.0
var _slow_timer: Timer = null

## 画桌庇护逃逸：远离指定中心点，计时结束恢复
var _flee_center: Vector3 = Vector3.ZERO
var _flee_timer: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	ink = max_ink


## 受到攻击：减少血量、击退，血量归零时播放缩地动画并销毁。
## knockback_dist < 0 时使用默认击退距离 knockback_distance。
func take_damage(amount: float, knockback_direction: Vector3, knockback_dist: float = -1.0) -> void:
	if is_dead:
		return
	if knockback_dist < 0.0:
		knockback_dist = knockback_distance

	ink -= amount
	print("%s 墨损 -%.1f，剩余墨量: %.1f" % [name, amount, maxf(ink, 0.0)])

	var dir := knockback_direction
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	_apply_knockback(dir * knockback_dist)

	if ink <= 0.0:
		_die()


func _apply_knockback(offset: Vector3) -> void:
	if knockback_tween and knockback_tween.is_valid():
		knockback_tween.kill()
	knockback_tween = create_tween()
	knockback_tween.tween_property(self, "global_position", global_position + offset, knockback_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _die() -> void:
	is_dead = true
	print("敌人被击败，获得经验 +%d" % int(exp_reward))
	GlobalStats.add_exp(int(exp_reward))

	var col := get_node_or_null("CollisionShape3D")
	if col:
		col.set_deferred("disabled", true)
	var hurtbox := get_node_or_null("Hurtbox")
	if hurtbox:
		hurtbox.monitoring = false
	if knockback_tween and knockback_tween.is_valid():
		knockback_tween.kill()

	# 缩地动画：缩小到 0（不销毁，等待 reset_health 复活）
	death_tween = create_tween()
	death_tween.tween_property(self, "scale", Vector3.ZERO, death_shrink_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## 敌人朝向（默认面向 -Z 方向），供背刺判定使用
func get_facing_direction() -> Vector3:
	return -global_transform.basis.z


## 破甲减速：factor < 1 为减速比例（0.7 = 移动减为70%），duration 秒后恢复。
## 可叠加刷新，取最慢值。
func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = clampf(minf(_slow_factor, factor), 0.1, 1.0)
	if _slow_timer == null:
		_slow_timer = Timer.new()
		_slow_timer.one_shot = true
		_slow_timer.timeout.connect(_on_slow_timeout)
		add_child(_slow_timer)
	_slow_timer.start(maxf(duration, 0.05))


func _on_slow_timeout() -> void:
	_slow_factor = 1.0


## 各 AI 移动/冲刺时取用的速率乘子
func get_speed_factor() -> float:
	return _slow_factor


## 画桌庇护：远离 center，duration 秒后恢复（SafePoint 每帧刷新可延长）
func start_flee(center: Vector3, duration: float) -> void:
	_flee_center = center
	_flee_timer = maxf(_flee_timer, duration)


func is_fleeing() -> bool:
	return _flee_timer > 0.0


func tick_flee(delta: float) -> void:
	_flee_timer = maxf(_flee_timer - delta, 0.0)


func reset_health() -> void:
	ink = max_ink
	is_dead = false
	if death_tween and death_tween.is_valid():
		death_tween.kill()
	var col := get_node_or_null("CollisionShape3D")
	if col:
		col.set_deferred("disabled", false)
	var hurtbox := get_node_or_null("Hurtbox")
	if hurtbox:
		hurtbox.monitoring = true
	scale = Vector3.ONE
