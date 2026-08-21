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


@export var max_health: float = 50.0
@export var health: float = 50.0
@export var knockback_distance: float = 0.5
@export var knockback_duration: float = 0.15
@export var death_shrink_time: float = 0.3

var is_dead: bool = false
var knockback_tween: Tween


func _ready() -> void:
	add_to_group("enemies")
	health = max_health


## 受到攻击：减少血量、击退，血量归零时播放缩地动画并销毁。
## knockback_dist < 0 时使用默认击退距离 knockback_distance。
func take_damage(amount: float, knockback_direction: Vector3, knockback_dist: float = -1.0) -> void:
	if is_dead:
		return
	if knockback_dist < 0.0:
		knockback_dist = knockback_distance

	health -= amount
	print("%s 受击 -%.1f 伤害，剩余血量: %.1f" % [name, amount, maxf(health, 0.0)])

	var dir := knockback_direction
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	_apply_knockback(dir * knockback_dist)

	if health <= 0.0:
		_die()


func _apply_knockback(offset: Vector3) -> void:
	if knockback_tween and knockback_tween.is_valid():
		knockback_tween.kill()
	knockback_tween = create_tween()
	knockback_tween.tween_property(self, "global_position", global_position + offset, knockback_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _die() -> void:
	is_dead = true
	print("敌人被击败")

	var col := get_node_or_null("CollisionShape3D")
	if col:
		col.set_deferred("disabled", true)
	var hurtbox := get_node_or_null("Hurtbox")
	if hurtbox:
		hurtbox.monitoring = false
	if knockback_tween and knockback_tween.is_valid():
		knockback_tween.kill()

	# 缩地动画：缩小到 0 后销毁
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, death_shrink_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
