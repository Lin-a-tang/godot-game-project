extends CharacterBody3D
## 《墨渊》灰盒战斗原型 —— 玩家控制器 (GDScript 2.0 / Godot 4.3)
##
## 挂载到 CharacterBody3D 根节点（命名为 "Player"）。
## 需要手动创建的子节点：
##   - CollisionShape3D : 胶囊碰撞体（高 1.8 米，半径 0.5 米）
##   - MeshInstance3D   : CapsuleMesh（颜色 #444444）
##   - Camera3D         : 作为 Player 的兄弟节点（固定视角，不随角色转向），位置 (0, 6, 6)，绕 X 轴旋转 -45 度
##   - AnimationPlayer  : 可留空，脚本会自动创建 "attack" 动画
## 脚本会自动创建：Hitbox(Area3D 攻击判定)、状态 Label3D、格挡闪光 ColorRect。
##
## 需要手动添加的输入动作（项目设置 -> 输入映射）：
##   move_forward=W  move_back=S  move_left=A  move_right=D
##   attack=鼠标左键  block=鼠标右键  dodge=空格  interact=E  style_panel=T


## ============ 状态机 ============
enum State { IDLE, MOVING, ATTACKING, CHARGING, BLOCKING, DODGING, HURT }
enum AttackPhase { WINDUP, ACTIVE, RECOVERY }
enum AttackKind { LIGHT, HEAVY }

const GRAVITY := 9.8

## ============ 移动 ============
@export var move_speed: float = 5.0
@export var turn_speed: float = 12.0
@export var camera_offset: Vector3 = Vector3(0.0, 6.0, 6.0)
@export var block_speed_multiplier: float = 0.4
@export var charge_speed_multiplier: float = 0.4

## ============ 伤害 ============
@export var base_damage: float = 10.0
@export var combo_damage_multipliers: Array[float] = [1.0, 1.2, 1.4]
@export var heavy_damage_multiplier: float = 2.2
@export var combo_reset_time: float = 1.0

## 轻攻击三段：前摇 / 判定 / 后摇
@export var light_windup_time: float = 0.15
@export var light_active_time: float = 0.10
@export var light_recovery_time: float = 0.20

## 重攻击（蓄力）
@export var charge_threshold_time: float = 0.6
@export var charge_auto_release_time: float = 1.5
@export var heavy_windup_time: float = 0.20
@export var heavy_active_time: float = 0.10
@export var heavy_recovery_time: float = 0.30

## 攻击判定框（Hitbox）
@export var light_hitbox_size: Vector3 = Vector3(1.5, 1.5, 2.0)
@export var light_hitbox_offset: Vector3 = Vector3(0.0, 0.75, -1.0)
@export var heavy_hitbox_size: Vector3 = Vector3(3.0, 1.5, 3.0)
@export var heavy_hitbox_offset: Vector3 = Vector3(0.0, 0.75, -1.5)
@export var heavy_fan_angle_deg: float = 120.0

## 击退距离
@export var normal_knockback_distance: float = 0.5
@export var combo_finisher_knockback_distance: float = 1.0
@export var heavy_knockback_distance: float = 1.5

## ============ 闪避 ============
@export var dodge_distance: float = 3.5
@export var dodge_duration: float = 0.3
@export var dodge_cooldown: float = 0.5

## ============ 格挡 ============
@export var block_front_angle_deg: float = 120.0
@export var block_damage_reduction: float = 0.7
@export var perfect_block_window: float = 0.1
@export var player_max_health: float = 100.0
@export var hurt_duration: float = 0.2


## ============ 节点引用 ============
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var camera: Camera3D = get_node_or_null("../Camera3D")

var animation_player: AnimationPlayer
var hitbox: Area3D
var hitbox_shape: BoxShape3D
var label: Label3D
var block_flash: ColorRect


## ============ 运行时状态 ============
var state: State = State.IDLE
var attack_phase: AttackPhase = AttackPhase.WINDUP
var attack_kind: AttackKind = AttackKind.LIGHT
var phase_timer: float = 0.0
var combo_index: int = 0
var current_combo_index: int = 0
var combo_timer: float = 0.0
var attack_queued: bool = false

var left_pressed: bool = false
var left_hold_time: float = 0.0

var is_invincible: bool = false
var dodge_timer: float = 0.0
var dodge_cooldown_timer: float = 0.0
var dodge_tween: Tween
var dodge_fade_tween: Tween

var player_health: float = 100.0
var perfect_block_timer: float = 0.0
var block_flash_tween: Tween
var hurt_timer: float = 0.0


## ============ 流派 ============
var base_max_hp: int = 100
var base_speed: float = 5.0
var current_flow: BaseFlow


func _ready() -> void:
	current_flow = FlowManager.get_current()
	player_max_health = int(base_max_hp * current_flow.hp_mult)
	player_health = player_max_health
	move_speed = base_speed * current_flow.speed_mult
	FlowManager.flow_changed.connect(_on_flow_changed)
	animation_player = get_node_or_null("AnimationPlayer")
	if animation_player == null:
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		add_child(animation_player)
	_setup_hitbox()
	_setup_label()
	_setup_block_flash()
	_ensure_attack_animation()
	_update_state_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_on_left_press()
	elif event.is_action_released("attack"):
		_on_left_release()
	elif event.is_action_pressed("dodge"):
		_try_dodge()
	elif event.is_action_pressed("interact"):
		pass  # TODO: 交互 / 拾取
	elif event.is_action_pressed("style_panel"):
		pass  # TODO: 流派切换面板


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	match state:
		State.IDLE, State.MOVING:
			_update_idle_moving(delta)
		State.ATTACKING:
			_update_attacking(delta)
		State.CHARGING:
			_update_charging(delta)
		State.BLOCKING:
			_update_blocking(delta)
		State.DODGING:
			_update_dodging(delta)
		State.HURT:
			_update_hurt(delta)
	_update_state_label()
	_update_camera()


## ============ 输入处理 ============

func _on_left_press() -> void:
	# 格挡 / 闪避 / 蓄力期间，左键无效
	if state in [State.BLOCKING, State.DODGING, State.CHARGING]:
		return
	left_pressed = true
	left_hold_time = 0.0


func _on_left_release() -> void:
	if not left_pressed:
		return
	left_pressed = false
	if state == State.CHARGING:
		# 松开释放重击
		_start_attack(AttackKind.HEAVY)
	elif left_hold_time < charge_threshold_time:
		# 快速点击（点按）-> 轻攻击
		if state == State.ATTACKING:
			attack_queued = true  # 连击缓冲
		elif state in [State.IDLE, State.MOVING]:
			_start_attack(AttackKind.LIGHT)
	left_hold_time = 0.0


## ============ 状态更新 ============

func _update_idle_moving(delta: float) -> void:
	if left_pressed and left_hold_time >= charge_threshold_time:
		_enter_charging()
		return
	if Input.is_action_pressed("block"):
		_enter_blocking()
		return
	var direction := _move_with_input(delta, 1.0)
	state = State.MOVING if direction != Vector3.ZERO else State.IDLE


func _update_attacking(delta: float) -> void:
	phase_timer -= delta
	match attack_phase:
		AttackPhase.WINDUP:
			velocity.x = 0.0
			velocity.z = 0.0
			_apply_gravity(delta)
			move_and_slide()
			if phase_timer <= 0.0:
				_enter_active_phase()
		AttackPhase.ACTIVE:
			velocity.x = 0.0
			velocity.z = 0.0
			_apply_gravity(delta)
			move_and_slide()
			if phase_timer <= 0.0:
				_enter_recovery_phase()
		AttackPhase.RECOVERY:
			_move_with_input(delta, 1.0)  # 后摇可移动
			if phase_timer <= 0.0:
				_end_attack()


func _update_charging(delta: float) -> void:
	if not left_pressed:
		_start_attack(AttackKind.HEAVY)
		return
	if left_hold_time >= charge_auto_release_time:
		_start_attack(AttackKind.HEAVY)  # 超过 1.5 秒自动释放
		return
	_move_with_input(delta, charge_speed_multiplier)


func _update_blocking(delta: float) -> void:
	if not Input.is_action_pressed("block"):
		_exit_blocking()
		return
	_move_with_input(delta, block_speed_multiplier)


func _update_dodging(delta: float) -> void:
	dodge_timer -= delta
	velocity = Vector3.ZERO
	if dodge_timer <= 0.0:
		state = State.IDLE
		is_invincible = false
		_set_transparency_enabled(false)
		if mesh != null:
			mesh.transparency = 0.0


func _update_hurt(delta: float) -> void:
	# HURT 状态暂不实现（本原型没有敌人攻击玩家）
	hurt_timer -= delta
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()
	if hurt_timer <= 0.0:
		state = State.IDLE


## ============ 状态切换 ============

func _enter_charging() -> void:
	state = State.CHARGING


func _enter_blocking() -> void:
	state = State.BLOCKING


func _exit_blocking() -> void:
	if state == State.BLOCKING:
		state = State.IDLE


func _start_attack(kind: AttackKind) -> void:
	attack_kind = kind
	state = State.ATTACKING
	attack_phase = AttackPhase.WINDUP
	left_pressed = false
	left_hold_time = 0.0

	if kind == AttackKind.HEAVY:
		phase_timer = heavy_windup_time
		hitbox_shape.size = heavy_hitbox_size
		hitbox.position = heavy_hitbox_offset
		combo_index = 0
		combo_timer = 0.0
	else:
		phase_timer = light_windup_time
		hitbox_shape.size = light_hitbox_size
		hitbox.position = light_hitbox_offset
		current_combo_index = combo_index
		combo_index = (combo_index + 1) % combo_damage_multipliers.size()
		combo_timer = combo_reset_time

	# 前摇时激活判定框（给物理系统时间注册重叠）
	hitbox.monitoring = true

	if animation_player.has_animation("attack"):
		animation_player.play("attack")


func _enter_active_phase() -> void:
	attack_phase = AttackPhase.ACTIVE
	phase_timer = heavy_active_time if attack_kind == AttackKind.HEAVY else light_active_time
	_apply_attack_detection()


func _enter_recovery_phase() -> void:
	attack_phase = AttackPhase.RECOVERY
	phase_timer = heavy_recovery_time if attack_kind == AttackKind.HEAVY else light_recovery_time
	hitbox.monitoring = false


func _end_attack() -> void:
	hitbox.monitoring = false
	if mesh != null:
		mesh.rotation = Vector3.ZERO  # 保证攻击结束后模型回正
	if attack_queued:
		attack_queued = false
		_start_attack(AttackKind.LIGHT)
	else:
		state = State.IDLE


## ============ 攻击判定 ============

func _apply_attack_detection() -> void:
	var multiplier: float
	var knockback_dist: float
	if attack_kind == AttackKind.HEAVY:
		multiplier = heavy_damage_multiplier
		knockback_dist = heavy_knockback_distance
	else:
		multiplier = combo_damage_multipliers[current_combo_index]
		var is_finisher: bool = current_combo_index == combo_damage_multipliers.size() - 1
		knockback_dist = combo_finisher_knockback_distance if is_finisher else normal_knockback_distance

	var damage := base_damage * multiplier * current_flow.damage_mult
	print("攻击伤害: %.1f" % damage)

	var facing := -global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized()

	var hit_any := false
	for body in hitbox.get_overlapping_bodies():
		if body == self or not body.is_in_group("enemies"):
			continue
		if not body.has_method("take_damage"):
			continue
		var to_enemy: Vector3 = body.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length_squared() < 0.0001:
			to_enemy = facing
		var dir := to_enemy.normalized()
		if attack_kind == AttackKind.HEAVY:
			# 扇形角度过滤
			if facing.dot(dir) < cos(deg_to_rad(heavy_fan_angle_deg) * 0.5):
				continue
		body.take_damage(damage, dir, knockback_dist)
		hit_any = true
	if hit_any:
		current_flow.on_attack_hit()


## ============ 闪避 ============

func _try_dodge() -> void:
	# 攻击 / 蓄力 / 闪避 / 受击期间，丢弃闪避输入
	if state in [State.ATTACKING, State.CHARGING, State.DODGING, State.HURT]:
		return
	if dodge_cooldown_timer > 0.0:
		return
	_start_dodge()


func _start_dodge() -> void:
	state = State.DODGING
	is_invincible = true
	dodge_timer = dodge_duration
	dodge_cooldown_timer = dodge_cooldown
	velocity = Vector3.ZERO
	current_flow.on_dodge()

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera_relative_direction(input_dir)
	if direction == Vector3.ZERO:
		direction = -global_transform.basis.z
		direction.y = 0.0
		direction = direction.normalized()
	_face_direction(direction, 1.0)

	var target := global_position + direction * dodge_distance

	if dodge_tween and dodge_tween.is_valid():
		dodge_tween.kill()
	dodge_tween = create_tween()
	dodge_tween.tween_property(self, "global_position", target, dodge_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 轻微透明度变化（瞬移感）
	_set_transparency_enabled(true)
	if mesh != null:
		mesh.transparency = 0.0
	if dodge_fade_tween and dodge_fade_tween.is_valid():
		dodge_fade_tween.kill()
	dodge_fade_tween = create_tween()
	dodge_fade_tween.tween_property(mesh, "transparency", 0.6, dodge_duration * 0.3)
	dodge_fade_tween.tween_property(mesh, "transparency", 0.0, dodge_duration * 0.7)


## ============ 受击（预留，本原型敌人不会攻击玩家） ============

func take_damage(amount: float, from_position: Vector3) -> void:
	if is_invincible:
		return
	var final_damage := amount
	if state == State.BLOCKING:
		var to_source: Vector3 = from_position - global_position
		to_source.y = 0.0
		var facing := -global_transform.basis.z
		facing.y = 0.0
		facing = facing.normalized()
		if to_source.length_squared() > 0.0001:
			var front_cos := cos(deg_to_rad(block_front_angle_deg) * 0.5)
			if facing.dot(to_source.normalized()) >= front_cos:
				final_damage = amount * (1.0 - block_damage_reduction)
				_flash_block()
				perfect_block_timer = perfect_block_window
				current_flow.on_block()
	player_health -= final_damage
	print("玩家受击 -%.1f 伤害，剩余血量 %.1f" % [final_damage, player_health])
	if player_health <= 0.0:
		player_health = player_max_health  # 灰盒：自动复活
		print("玩家死亡（灰盒暂不处理）")


## ============ 移动 / 朝向 ============

func _move_with_input(delta: float, speed_multiplier: float) -> Vector3:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera_relative_direction(input_dir)
	var speed := move_speed * speed_multiplier
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		_face_direction(direction, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 10.0 * delta)
	_apply_gravity(delta)
	move_and_slide()
	return direction


func _camera_relative_direction(input_dir: Vector2) -> Vector3:
	if input_dir == Vector2.ZERO or camera == null:
		return Vector3.ZERO
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	return (forward * -input_dir.y + right * input_dir.x).normalized()


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction == Vector3.ZERO:
		return
	var target := global_position + direction
	target.y = global_position.y
	var look := global_transform.looking_at(target, Vector3.UP)
	global_transform = global_transform.interpolate_with(look, clampf(turn_speed * delta, 0.0, 1.0))


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.1


## ============ 计时器 ============

func _update_timers(delta: float) -> void:
	if left_pressed:
		left_hold_time += delta
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_index = 0
	if dodge_cooldown_timer > 0.0:
		dodge_cooldown_timer -= delta
	if perfect_block_timer > 0.0:
		perfect_block_timer -= delta


## ============ 初始化辅助 ============

func _setup_hitbox() -> void:
	hitbox = Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 1
	hitbox.monitoring = false
	hitbox.monitorable = false
	add_child(hitbox)

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	hitbox_shape = BoxShape3D.new()
	hitbox_shape.size = light_hitbox_size
	col.shape = hitbox_shape
	hitbox.add_child(col)
	hitbox.position = light_hitbox_offset


func _setup_label() -> void:
	var existing := get_node_or_null("Label3D")
	if existing is Label3D:
		label = existing
	else:
		label = Label3D.new()
		label.name = "Label3D"
		add_child(label)
	label.position = Vector3(0.0, 2.2, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.outline_size = 8
	label.modulate = Color(1, 1, 1)


func _setup_block_flash() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BlockFlashLayer"
	add_child(layer)
	block_flash = ColorRect.new()
	block_flash.name = "BlockFlash"
	block_flash.color = Color(1, 1, 1, 0.0)
	block_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(block_flash)
	block_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ensure_attack_animation() -> void:
	if animation_player.has_animation("attack"):
		return
	var anim := Animation.new()
	var total := light_windup_time + light_active_time + light_recovery_time
	anim.length = total
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, "MeshInstance3D:rotation:x")
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, light_windup_time, deg_to_rad(45.0))
	anim.track_insert_key(track, light_windup_time + light_active_time, deg_to_rad(-45.0))
	anim.track_insert_key(track, total, 0.0)
	var library: AnimationLibrary
	if animation_player.has_animation_library(""):
		library = animation_player.get_animation_library("")
	else:
		library = AnimationLibrary.new()
		animation_player.add_animation_library("", library)
	library.add_animation("attack", anim)


func _set_transparency_enabled(enabled: bool) -> void:
	if mesh == null:
		return
	var mat: Material = mesh.material_override
	if mat == null and mesh.mesh != null:
		mat = mesh.mesh.surface_get_material(0)
	if mat is BaseMaterial3D:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if enabled else BaseMaterial3D.TRANSPARENCY_DISABLED


func _flash_block() -> void:
	if block_flash == null:
		return
	if block_flash_tween and block_flash_tween.is_valid():
		block_flash_tween.kill()
	block_flash.color.a = 0.35
	block_flash_tween = create_tween()
	block_flash_tween.tween_property(block_flash, "color:a", 0.0, 0.1)


func _update_state_label() -> void:
	if label == null:
		return
	label.text = State.keys()[state]


func _update_camera() -> void:
	if camera == null:
		return
	camera.global_position = global_position + camera_offset


func _on_flow_changed(new_flow: BaseFlow) -> void:
	current_flow = new_flow
	player_max_health = int(base_max_hp * new_flow.hp_mult)
	if player_health > player_max_health:
		player_health = player_max_health
	move_speed = base_speed * new_flow.speed_mult
	print("已应用流派: %s" % new_flow.flow_name)
