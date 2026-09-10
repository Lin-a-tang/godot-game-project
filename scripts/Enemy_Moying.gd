extends "res://scripts/Enemy.gd"
## 《墨渊》竹林杂怪 —— 墨影 (GDScript 2.0 / Godot 4.7)
##
## 继承 Enemy.gd（共享受击 / 击退 / 死亡缩地 / 复活），补全墨影专属 AI：
##   - 平时接近玩家并面向（其"朝向"可被背刺词条利用）；
##   - 近身蓄力挥爪（前摇小，命中玩家造成墨损，可被格挡/闪避逃生）;
##   - 血墨趋少或长期对峙时"雾隐"消失，瞬移绕到玩家背后再袭（对应偷袭词条）;
##   - 攻击被格挡后短暂被"断线"（减速），呼应守拙词条。
## 敌人墨量为独立固值，与玩家墨量系统解耦，复活恢复到满。


## ============ 墨影 AI 参数 ============
@export var approach_speed: float = 2.6          ## 追击速度（比玩家略慢，制造贴脸前的决策窗口）
@export var engage_range: float = 10.0           ## 进入该距离才会仇恨追击（分区线性关卡用）
@export var turn_speed: float = 6.0
@export var attack_range: float = 1.7            ## 触发挥爪的判定距离
@export var attack_damage: float = 16.0          ## 挥爪造成的墨量损失（玩家墨条承受）
@export var windup_time: float = 0.55            ## 前摇（给玩家反应时间）
@export var active_stab_time: float = 0.18
@export var recovery_time: float = 0.55
@export var attack_cooldown: float = 1.6
@export var windup_turn_rate: float = 0.4        ## 蓄力时修正朝向的速度
@export var vanish_cooldown: float = 6.0         ## 雾隐间隔
@export var vanish_distance: float = 4.2         ## 绕背落点与玩家的距离
@export var reworked_speed_mult: float = 0.6     ## 命中玩家墨条后可能的追击提速

## ============ AI 状态 ============
enum AiState { APPROACH, WINDUP, ACTIVE, RECOVERY, VANISH }

var ai_state: AiState = AiState.APPROACH
var _state_timer: float = 0.0
var _ai_attack_cd: float = 0.0
var _vanish_cd: float = 0.0
var _respawn_cache: Vector3 = Vector3.ZERO    # 雾隐前的站位，用于复活复位（写回初始并不需要常驻）
var _attacked_in_active := false
var _player: Node3D = null


func _ready() -> void:
	super._ready()
	_respawn_cache = global_position
	ai_state = AiState.APPROACH


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
	if _player == null:
		return
	if _ai_attack_cd > 0.0:
		_ai_attack_cd = maxf(_ai_attack_cd - delta, 0.0)
	if _vanish_cd > 0.0:
		_vanish_cd = maxf(_vanish_cd - delta, 0.0)

	# 画桌庇护：怪物自动远离画桌
	if is_fleeing():
		tick_flee(delta)
		var away := global_position - _flee_center
		away.y = 0.0
		if away.length_squared() < 0.0001:
			away = Vector3(0.0, 0.0, 1.0)
		away = away.normalized()
		velocity.x = away.x * approach_speed * 1.8
		velocity.z = away.z * approach_speed * 1.8
		move_on_floor(delta)
		return

	# 分区仇恨：玩家太远时原地等待，不越区追击
	if _dist_flat_to_player() > engage_range:
		velocity = Vector3.ZERO
		move_on_floor(delta)
		return

	match ai_state:
		AiState.APPROACH:
			_state_approach(delta)
		AiState.WINDUP:
			_state_windup(delta)
		AiState.ACTIVE:
			_state_active(delta)
		AiState.RECOVERY:
			_state_recovery(delta)
		AiState.VANISH:
			_state_vanish(delta)


func _find_player() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D:
			return p as Node3D
	return null


func _dist_flat_to_player() -> float:
	if _player == null or not is_instance_valid(_player):
		return 99999.0
	var flat := _player.global_position - global_position
	flat.y = 0.0
	return flat.length()


## ============ 动作逻辑 ============

func _state_approach(delta: float) -> void:
	var to_player: Vector3 = _player.global_position - global_position
	var flat := to_player
	flat.y = 0.0
	var dist := flat.length()

	# 距离足够近（且没有残留硬直/雾隐冷却）→ 蓄力
	if dist <= attack_range and _ai_attack_cd <= 0.0:
		_begin_stab()
		return

	# 每隔一段时间绕背骚扰；雾影贴合"藏锋 · 墨影"意象
	if _vanish_cd <= 0.0 and dist > attack_range * 1.2:
		_begin_vanish()
		return

	# 朝玩家水平移动（破甲减速乘子生效）
	_face_player(delta, turn_speed)
	if flat.length_squared() > 0.0001:
		velocity.x = flat.x / dist * approach_speed * get_speed_factor()
		velocity.z = flat.z / dist * approach_speed * get_speed_factor()
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_on_floor(delta)


## 固定的水平移动（保持 y 与初始一致，避免重叠地面时被压陷）
func move_on_floor(delta: float) -> void:
	velocity.y = 0.0
	move_and_slide()
	# y 归位：墨影悬于出生高度，不陷入地面
	global_position.y = lerpf(global_position.y, _respawn_cache.y, minf(delta * 8.0, 1.0))


func _begin_stab() -> void:
	ai_state = AiState.WINDUP
	_state_timer = windup_time
	_attacked_in_active = false


func _state_windup(delta: float) -> void:
	# 朝玩家缓慢修正朝向（前摇=危险时刻），保持攻击预期可读
	_face_player(delta, windup_turn_rate)
	velocity = Vector3.ZERO
	move_on_floor(delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		ai_state = AiState.ACTIVE
		_state_timer = active_stab_time
		if not _attacked_in_active:
			_try_attack_player()


func _state_active(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		ai_state = AiState.RECOVERY
		_state_timer = recovery_time
	_face_player(delta, windup_turn_rate)
	move_on_floor(delta)


func _state_recovery(delta: float) -> void:
	_state_timer -= delta
	velocity = Vector3.ZERO
	move_on_floor(delta)
	if _state_timer <= 0.0:
		ai_state = AiState.APPROACH
		_ai_attack_cd = attack_cooldown


## 对玩家造成墨损。命中返回 true。
func _try_attack_player() -> bool:
	_attacked_in_active = true
	if _player == null or not is_instance_valid(_player):
		return false
	# 近似攻击判别范围：只判断水平距离是否够得着
	var horizontal := Vector3(_player.global_position.x, 0.0, _player.global_position.z) - Vector3(global_position.x, 0.0, global_position.z)
	if horizontal.length() > attack_range:
		return false
	if _player.has_method("take_damage"):
		_player.call("take_damage", attack_damage, global_position)
		return true
	return false


## ============ 雾隐 · 绕背 ============

func _begin_vanish() -> void:
	ai_state = AiState.VANISH
	_state_timer = 0.45   # 消失过渡
	_set_move_body_visible(false)
	_set_colliders_enabled(false)
	_teleport_behind_player()


func _state_vanish(delta: float) -> void:
	# 消失期间停在地面，等待"绕后"过渡完成（此状态下无碰撞、不显示本体）
	velocity = Vector3.ZERO
	_state_timer -= delta
	if _state_timer <= 0.0:
		_set_colliders_enabled(true)
		_set_move_body_visible(true)
		ai_state = AiState.APPROACH
		_vanish_cd = vanish_cooldown
		# 落地后立刻小硬直再读条攻击，给与背刺判定的玩家一丝容错同理
		_brief_hold(0.35)


func _brief_hold(seconds: float) -> void:
	_ai_attack_cd = maxf(_ai_attack_cd, seconds)


## 把墨影放到玩家"身后夹角"的离散位置（左右偏移，避免垂直贴脸）
func _teleport_behind_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var to_me := global_position - _player.global_position
	to_me.y = 0.0
	if to_me.length_squared() < 0.0001:
		to_me = Vector3(-1.0, 0.0, 0.0)
	to_me = to_me.normalized()
	# 在玩家背后以扇形左右候选落脚点中，挑最近于当前距离的偏移
	var offsets: Array[Vector3] = [
		Vector3(-to_me.z, 0.0, to_me.x) * 1.4,
		Vector3(to_me.z, 0.0, -to_me.x) * 1.4,
		to_me * 1.4,
	]
	var target: Vector3 = global_position
	for o in offsets:
		var candidate := _player.global_position + to_me * vanish_distance + o
		if _candidate_clear(candidate):
			target = candidate
			break
	global_position = Vector3(target.x, _respawn_cache.y, target.z)
	_face_player(1.0, 12.0)


func _candidate_clear(pos: Vector3) -> bool:
	var floor_y := _respawn_cache.y
	if (pos - global_position).length() < 1.5:
		return false
	# 粗测落点不越出或掉进地表以下太多（地面=初始高度）
	if absf(pos.y - floor_y) > 0.0:
		pos.y = floor_y
	return true


## ============ 表现辅助 ============

func _set_move_body_visible(visible: bool) -> void:
	for n in ["MeshInstance3D", "Shadow"]:
		var node := get_node_or_null(n)
		if node:
			node.visible = visible


func _set_colliders_enabled(true_state: bool) -> void:
	for node in get_children():
		if node is CollisionShape3D:
			node.set_deferred("disabled", not true_state)
	var hurtbox := get_node_or_null("Hurtbox")
	if hurtbox:
		hurtbox.set_deferred("monitoring", true_state)


func _face_player(delta: float, rate: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var dir := _player.global_position - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var target := global_transform.looking_at(global_position + dir.normalized(), Vector3.UP)
	global_transform = global_transform.interpolate_with(target, clampf(rate * delta, 0.0, 1.0))


## ============ 击退 ============
## 墨影被击退/击飞后仍保持地面逻辑时，沿用 Enemy 的 knockback tween（不做额外处理）。背刺相对墨影朝向判定由 Player 侧调用 get_facing_direction。
