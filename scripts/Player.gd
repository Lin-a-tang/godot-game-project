extends CharacterBody3D
## 《墨渊》灰盒战斗原型 —— 玩家控制器 (GDScript 2.0 / Godot 4.3)
##
## 挂载到 CharacterBody3D 根节点（命名为 "Player"）。
## 需要手动创建的子节点：
##   - CollisionShape3D : 胶囊碰撞体（高 1.8 米，半径 0.5 米）
##   - MeshInstance3D   : CapsuleMesh（颜色 #444444）
##   - Camera3D         : 作为 Player 的兄弟节点（固定视角，不随角色转向），位置 (0, 6, 6)，绕 X 轴旋转 -45 度
## 脚本会自动创建：Hitbox(Area3D 攻击判定)、状态 Label3D、格挡闪光 ColorRect。
## 攻击视觉由 Hero 骨骼动画（hero_rigged.glb 的 qc_* 剪辑）驱动，旧的程序化摇晃已移除。
##
## 需要手动添加的输入动作（项目设置 -> 输入映射）：
##   move_forward=W  move_back=S  move_left=A  move_right=D
##   attack=鼠标左键  block=鼠标右键  dodge=空格  interact=E  style_panel=T


## ============ 状态机 ============
enum State { IDLE, MOVING, ATTACKING, CHARGING, BLOCKING, DODGING, HURT }
enum AttackPhase { WINDUP, ACTIVE, RECOVERY }
enum AttackKind { LIGHT, HEAVY }

const GRAVITY := 9.8

signal ink_changed(current: float, max: float)

## 被动技能效果映射（被动名 -> 加成字典）
const PASSIVE_BONUSES: Dictionary = {
	"墨盾·化甲": {"shield_regen_ink": 0.01},
	"墨盾·韧性": {"shield_damage_reduction": 0.03},
	"砚池·满溢": {"pool_damage_bonus": 0.30},
	"墨引·回响": {"mark_speed_bonus": 0.10},
	"藏锋·被动": {"backstab_crit": 0.40, "out_of_combat_speed": 0.20},
	"残影·蚀": {"enemy_attack_reduction": 0.15},
	"墨魂·积攒": {"mote_limit_up": 2},
	"墨魂·共鸣": {"summon_hit_ink_restore": 0.01},
	"泪痕·暴": {"crit_chance": 0.35, "crit_ink_restore": 0.10},
	"泪痕·愈": {"crit_extra_ink_restore": 0.02},
}

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
@export var combo_reset_time: float = 1.2

## 轻攻击三段：前摇 / 判定 / 后摇（总时长与 qc_atk1 动画 2.53s ÷ 2.5 倍速 = 1.01s 对齐）
@export var light_windup_time: float = 0.40
@export var light_active_time: float = 0.15
@export var light_recovery_time: float = 0.45

## 重攻击（蓄力）（总时长与 qc_atk1 动画 2.53s ÷ 2.0 倍速 = 1.27s 对齐）
@export var charge_threshold_time: float = 0.6
@export var charge_auto_release_time: float = 1.5
@export var heavy_windup_time: float = 0.50
@export var heavy_active_time: float = 0.20
@export var heavy_recovery_time: float = 0.60

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
@export var dodge_duration: float = 0.35
@export var dodge_cooldown_max: float = 0.5

## ============ 格挡 ============
@export var block_front_angle_deg: float = 120.0
@export var block_damage_reduction: float = 0.7
@export var perfect_block_window: float = 0.1
@export var hurt_duration: float = 0.2

## ============ 墨量 ============
@export var max_ink_base: float = 100.0
@export var ink_regen_rate: float = 0.02
@export var ink_regen_delay: float = 1.0
@export var ink_high_threshold: float = 0.8
@export var ink_low_threshold: float = 0.3
@export var ink_high_damage_bonus: float = 0.15
@export var ink_low_damage_penalty: float = 0.20
@export var death_ink_recovery: float = 0.5


## 玩家视觉节点树（换肤 Hero / 流派残影等特效挂点）
@onready var mesh: Node3D = $MeshInstance3D
@onready var camera: Camera3D = get_node_or_null("../Camera3D")
## 换装角色骨骼动画（Mixamo qc_* 剪辑，hero_rigged.glb 自带动画）
@onready var hero_anim: AnimationPlayer = get_node_or_null("MeshInstance3D/Hero/AnimationPlayer")

## 骨骼动画按状态映射（剪辑名 -> [剪辑, 播放速度]），缺失动作先占位
## 注意：DODGING 不在此表，由 _start_dodge 按闪避方向选择 one-shot 动画
const HERO_LOOP_CLIPS: Dictionary = {
	State.IDLE: ["qc_idle", 1.0],
	State.MOVING: ["qc_walk", 3.0],   # 3 倍速匹配 5m/s 移速（动画基准约 1.6m/s）
	State.CHARGING: ["qc_atk1", 0.8], # 蓄力挥慢速攻击段
	State.BLOCKING: ["qc_hurt", 0.5], # TODO 待补充 guard 后改 qc_block
	State.HURT: ["qc_hurt", 2.0],
}
## 起步动画播放速度（Start Walking 2.93s ÷ 2.5 = 1.17s 过渡到循环走）
const WALK_START_SPEED := 2.5
var _prev_hero_state: int = -1

## 角色可视化根(下挂 glb 各部件的网格实例)，透明/材质覆盖等特效对全体下发
var _vis_geoms: Array[MeshInstance3D] = []
var _vis_mats: Array[BaseMaterial3D] = []
var _vis_cache_built := false

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
var dodge_cooldown_remaining: float = 0.0
var dodge_tween: Tween

var max_ink: float = 100.0
var current_ink: float = 100.0
var ink_regen_timer: float = 0.0
var is_ink_regen_paused: bool = false
var active_passive_effects: Dictionary = {}
var perfect_block_timer: float = 0.0
var block_flash_tween: Tween
var hurt_timer: float = 0.0


## ============ 流派 ============
var base_speed: float = 5.0
var current_flow: BaseFlow

## 技能资源（守拙/点墨/藏锋/归砚）
var current_shield: int = 0
var current_pool: float = 0.0
var current_shadow: int = 0
var current_motes: int = 0
var is_berserk: bool = false

var _q_prev := false
var _r_prev := false


func _ready() -> void:
	current_flow = FlowManager.get_current()
	max_ink = max_ink_base
	current_ink = max_ink
	base_damage = GlobalStats.base_atk
	move_speed = base_speed * current_flow.speed_mult
	FlowManager.flow_changed.connect(_on_flow_changed)
	FlowManager.skill_equipped.connect(_on_skill_equipped)
	TalentManager.talents_changed.connect(_refresh_talents)
	add_to_group("player")
	_refresh_passives()
	_build_visual_cache()
	_strip_root_motion()
	_setup_hitbox()
	_setup_label()
	_setup_block_flash()
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
	_update_hero_anim()


func _process(delta: float) -> void:
	if dodge_cooldown_remaining > 0.0:
		dodge_cooldown_remaining = maxf(dodge_cooldown_remaining - delta, 0.0)
	_update_ink_regen(delta)
	if is_berserk:
		current_ink -= max_ink * 0.01 * delta
		ink_changed.emit(current_ink, max_ink)
		if current_ink <= 0.0:
			current_ink = max_ink * death_ink_recovery
			is_berserk = false
			print("泣血·狂耗尽墨量")
	if current_flow == null:
		return
	var q := Input.is_physical_key_pressed(KEY_Q)
	if q and not _q_prev:
		_cast_equipped_skill("q")
	_q_prev = q
	var r := Input.is_physical_key_pressed(KEY_R)
	if r and not _r_prev:
		_cast_equipped_skill("r")
	_r_prev = r


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


## 播放换装角色骨骼动画（one-shot 用，自动打断当前段）
## 统一速度机制：只走 speed_scale，避免与 play 的 custom_speed 相乘
func hero_play(clip: String, speed: float = 1.0, blend: float = 0.12) -> void:
	if hero_anim == null or not hero_anim.has_animation(clip):
		return
	hero_anim.play(clip, blend)
	hero_anim.speed_scale = speed


## 每帧根据状态驱动换装角色循环动画（攻击/闪避/受击由 one-shot 处理）
func _update_hero_anim() -> void:
	if hero_anim == null:
		return
	if state in [State.ATTACKING, State.DODGING]:
		_prev_hero_state = state
		return  # 攻击/闪避动画由对应状态入口单次触发
	# 刚进入移动：先播起步动画（播完再切循环走路）
	if state == State.MOVING and _prev_hero_state != State.MOVING:
		hero_play("qc_walk_start", WALK_START_SPEED, 0.08)
		_prev_hero_state = state
		return
	# 起步动画播放期间不打断
	if state == State.MOVING and hero_anim.current_animation == "qc_walk_start" and hero_anim.is_playing():
		_prev_hero_state = state
		return
	var clip: Array = HERO_LOOP_CLIPS.get(state)
	if clip == null:
		_prev_hero_state = state
		return
	var cname: String = clip[0]
	var speed: float = clip[1]
	if hero_anim.current_animation != cname:
		hero_anim.play(cname, 0.15)
		hero_anim.speed_scale = speed
	elif not is_equal_approx(hero_anim.speed_scale, speed):
		hero_anim.speed_scale = speed
	_prev_hero_state = state


func _start_attack(kind: AttackKind) -> void:
	attack_kind = kind
	state = State.ATTACKING
	attack_phase = AttackPhase.WINDUP
	left_pressed = false
	left_hold_time = 0.0
	# 骨骼攻击动作（轻/重共用 qc_atk1；速度与三段总时长对齐：
	# 轻 1.0s ÷ 2.5 倍速、重 1.3s ÷ 2.0 倍速均≈动画 2.53s）
	hero_play("qc_atk1", 2.0 if kind == AttackKind.HEAVY else 2.5)

	if kind == AttackKind.HEAVY:
		consume_ink(3.0)
		phase_timer = heavy_windup_time
		hitbox_shape.size = heavy_hitbox_size
		hitbox.position = heavy_hitbox_offset
		combo_index = 0
		combo_timer = 0.0
	else:
		consume_ink(1.0)
		phase_timer = light_windup_time
		hitbox_shape.size = light_hitbox_size
		hitbox.position = light_hitbox_offset
		current_combo_index = combo_index
		combo_index = (combo_index + 1) % combo_damage_multipliers.size()
		combo_timer = combo_reset_time

	# 前摇时激活判定框（给物理系统时间注册重叠）
	hitbox.monitoring = true


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

	var ink_mult := get_ink_damage_multiplier()
	var bonus_mult := _get_bonus_damage_multiplier()

	# 背刺判定（藏锋·被动：背刺暴击加成）
	var is_backstab := false
	var backstab_crit_bonus: float = get_passive_bonus("backstab_crit")
	if backstab_crit_bonus > 0.0:
		for body in hitbox.get_overlapping_bodies():
			if body == self or not body.is_in_group("enemies"):
				continue
			if not (body is Node3D):
				continue
			var to_enemy: Vector3 = body.global_position - global_position
			to_enemy.y = 0.0
			if to_enemy.length_squared() < 0.0001:
				continue
			to_enemy = to_enemy.normalized()
			if body.has_method("get_facing_direction"):
				var enemy_facing: Vector3 = body.call("get_facing_direction")
				enemy_facing.y = 0.0
				enemy_facing = enemy_facing.normalized()
				if enemy_facing.dot(to_enemy) > 0.5:
					is_backstab = true
					break
			else:
				var player_facing := -global_transform.basis.z
				player_facing.y = 0.0
				player_facing = player_facing.normalized()
				if player_facing.dot(to_enemy) > 0.5:
					is_backstab = true
					break

	var damage := base_damage * multiplier * current_flow.damage_mult * ink_mult * bonus_mult
	if is_backstab and backstab_crit_bonus > 0.0:
		damage *= (1.0 + backstab_crit_bonus)
		print("背刺加成伤害: %.1f" % damage)
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
		_sync_resources_from_flow()
		FlowManager.skill_used.emit()


## ============ 闪避 ============

func _try_dodge() -> void:
	# 攻击 / 蓄力 / 闪避 / 受击期间，丢弃闪避输入
	if state in [State.ATTACKING, State.CHARGING, State.DODGING, State.HURT]:
		return
	if dodge_cooldown_remaining > 0.0:
		return
	_start_dodge()


func _start_dodge() -> void:
	state = State.DODGING
	is_invincible = true
	dodge_timer = dodge_duration
	dodge_cooldown_remaining = dodge_cooldown_max
	velocity = Vector3.ZERO
	current_flow.on_dodge()
	_sync_resources_from_flow()
	FlowManager.skill_used.emit()

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera_relative_direction(input_dir)
	if direction == Vector3.ZERO:
		direction = -global_transform.basis.z
		direction.y = 0.0
		direction = direction.normalized()
	_face_direction(direction, 1.0)

	# 骨骼闪避动画：按输入方向选前/后/左/右（无输入=向前）
	var clip := "qc_roll_f"
	if input_dir != Vector2.ZERO:
		if absf(input_dir.y) >= absf(input_dir.x):
			clip = "qc_roll_f" if input_dir.y < 0.0 else "qc_roll_b"
		else:
			clip = "qc_roll_r" if input_dir.x > 0.0 else "qc_roll"
	hero_play(clip, 2.8, 0.08)

	var target := global_position + direction * dodge_distance

	if dodge_tween and dodge_tween.is_valid():
		dodge_tween.kill()
	dodge_tween = create_tween()
	dodge_tween.tween_property(self, "global_position", target, dodge_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## ============ 受击（预留，本原型敌人不会攻击玩家） ============

func take_damage(amount: float, from_position: Vector3) -> void:
	if is_invincible:
		return
	var final_damage := amount
	var blocked := false
	if state == State.BLOCKING:
		var to_source: Vector3 = from_position - global_position
		to_source.y = 0.0
		var facing := -global_transform.basis.z
		facing.y = 0.0
		facing = facing.normalized()
		if to_source.length_squared() > 0.0001:
			# 词条「游丝勾勒」：格挡窗口扩大（正面判定角加宽）
			var front_angle := block_front_angle_deg + TalentManager.get_bonus("block_window_bonus") * 100.0
			var front_cos := cos(deg_to_rad(front_angle) * 0.5)
			if facing.dot(to_source.normalized()) >= front_cos:
				final_damage = amount * (1.0 - block_damage_reduction)
				blocked = true
				_flash_block()
				perfect_block_timer = perfect_block_window
				current_flow.on_block()
				_sync_resources_from_flow()
				FlowManager.skill_used.emit()
	# 被动：墨盾·韧性（每层盾提供3%减伤）
	if has_passive_bonus("shield_damage_reduction"):
		final_damage *= 1.0 - current_shield * get_passive_bonus("shield_damage_reduction")
	current_ink = max(current_ink - final_damage, 0.0)
	ink_regen_timer = ink_regen_delay
	# 词条「游丝勾勒」：格挡回墨（伤害结算后补墨，越挡越赚）
	if blocked:
		var block_restore: float = TalentManager.get_bonus("block_restore_ink")
		if block_restore > 0.0:
			current_ink = min(current_ink + block_restore, max_ink)
	print("墨损 -%.1f，剩余墨量 %.1f" % [final_damage, current_ink])
	if current_ink <= 0.0:
		_on_death()
	ink_changed.emit(current_ink, max_ink)


func _on_death() -> void:
	print("散墨：角色化为墨渍消散")
	global_position = SafePointManager.get_respawn_position()
	current_ink = max_ink * death_ink_recovery
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("reset_health"):
			enemy.reset_health()
	ink_changed.emit(current_ink, max_ink)


func _update_ink_regen(delta: float) -> void:
	if ink_regen_timer > 0.0:
		ink_regen_timer -= delta
		is_ink_regen_paused = true
		return
	is_ink_regen_paused = false
	# 被动：墨盾·化甲（盾≥3时每秒回墨）
	if has_passive_bonus("shield_regen_ink") and current_shield >= 3:
		current_ink = min(current_ink + max_ink * get_passive_bonus("shield_regen_ink") * delta, max_ink)
		ink_changed.emit(current_ink, max_ink)
	if current_ink < max_ink:
		var regen_amount := max_ink * ink_regen_rate * delta
		current_ink = min(current_ink + regen_amount, max_ink)
		ink_changed.emit(current_ink, max_ink)


func get_ink_damage_multiplier() -> float:
	var ratio := current_ink / max_ink
	if ratio >= ink_high_threshold:
		return 1.0 + ink_high_damage_bonus
	elif ratio <= ink_low_threshold:
		return 1.0 - ink_low_damage_penalty
	return 1.0


func consume_ink(amount_percent: float) -> bool:
	var cost := max_ink * amount_percent / 100.0 * _get_ink_cost_multiplier()
	if current_ink >= cost:
		current_ink -= cost
		ink_regen_timer = ink_regen_delay
		ink_changed.emit(current_ink, max_ink)
		return true
	return false


## 直接回复墨量（画桌/技能回复调用，不重置回墨延迟）
func restore_ink(amount: float) -> void:
	if amount <= 0.0:
		return
	current_ink = min(current_ink + amount, max_ink)
	ink_changed.emit(current_ink, max_ink)


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


## 剥离闪避/走路动画的根骨水平位移：
## Mixamo 动画自带 Hips 水平位移（首尾不回起点），与代码移动双重叠加、
## 且播完切回 idle 时会"倒退"回混合位置。这里把 Hips 位置轨道的水平分量
## 固定为首帧值（保留 z 垂直起伏），位移完全交给代码控制。
func _strip_root_motion() -> void:
	if hero_anim == null:
		return
	var lib: AnimationLibrary = hero_anim.get_animation_library("")
	if lib == null:
		return
	for clip in ["qc_roll", "qc_roll_f", "qc_roll_b", "qc_roll_r", "qc_walk_start", "qc_walk"]:
		if not lib.has_animation(clip):
			continue
		var anim: Animation = lib.get_animation(clip).duplicate(true)
		for i in anim.get_track_count():
			if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
				continue
			if not str(anim.track_get_path(i)).contains("Hips"):
				continue
			var n: int = anim.track_get_key_count(i)
			if n == 0:
				continue
			var base: Vector3 = anim.track_get_key_value(i, 0)
			for k in n:
				var v: Vector3 = anim.track_get_key_value(i, k)
				anim.track_set_key_value(i, k, Vector3(base.x, base.y, v.z))
		lib.remove_animation(clip)
		lib.add_animation(clip, anim)


func _set_transparency_enabled(enabled: bool) -> void:
	if mesh == null:
		return
	if _vis_mats.is_empty():
		# 兼容旧的单体胶囊可视化
		var mat: Material = mesh.material_override if mesh is MeshInstance3D else null
		if mat == null and mesh is MeshInstance3D and (mesh as MeshInstance3D).mesh != null:
			mat = (mesh as MeshInstance3D).mesh.surface_get_material(0)
		if mat is BaseMaterial3D:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if enabled else BaseMaterial3D.TRANSPARENCY_DISABLED
		return
	for m: BaseMaterial3D in _vis_mats:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if enabled else BaseMaterial3D.TRANSPARENCY_DISABLED


## 收集 glb 多部件：把 MeshInstance3D 与其中用到的所有 BaseMaterial3D 归拢
func _build_visual_cache() -> void:
	if _vis_cache_built or mesh == null:
		return
	_vis_geoms.clear()
	_vis_mats.clear()
	_collect_mesh_children(mesh, _vis_geoms, _vis_mats, {})
	_vis_cache_built = true


func _collect_mesh_children(node: Node, geoms: Array[MeshInstance3D], mats: Array[BaseMaterial3D], seen: Dictionary) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			geoms.append(child)
			var mi: MeshInstance3D = child
			var n := mi.mesh.get_surface_count() if mi.mesh != null else 0
			for s in n:
				var m: Material = mi.mesh.surface_get_material(s)
				if m is BaseMaterial3D:
					var idv: int = m.get_instance_id()
					if not seen.has(idv):
						seen[idv] = true
						mats.append(m)
		_collect_mesh_children(child, geoms, mats, seen)


## 设置可视部件的透明度（用于闪避残影淡入/淡出）
func _set_visibility_transparency(value: float) -> void:
	if _vis_geoms.is_empty():
		if mesh is MeshInstance3D:
			(mesh as MeshInstance3D).transparency = value
		return
	for g: MeshInstance3D in _vis_geoms:
		g.transparency = value


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
	move_speed = base_speed * new_flow.speed_mult
	_sync_resources_from_flow()
	_refresh_passives()
	print("已应用流派: %s" % new_flow.flow_name)


## ============ 技能系统 ============

func _cast_equipped_skill(slot: String) -> void:
	if current_flow == null:
		return
	var skill_id: String = current_flow.equipped_skills.get(slot, "")
	if skill_id == "":
		print("槽位 %s 未装备技能" % slot)
		return
	if not current_flow.skill_data.has(skill_id):
		print("技能 %s 尚未解锁" % skill_id)
		return
	_try_cast_skill(skill_id)


func _try_cast_skill(skill_id: String) -> void:
	if current_flow == null:
		return
	var result: Dictionary = current_flow.cast_skill(skill_id, self)
	if not result.get("success", false):
		print("技能失败: ", result.get("reason", ""))
		return
	consume_ink(5.0)
	var flow_name := current_flow.flow_name
	if skill_id == "r" and flow_name == "守拙":
		_cast_shouzhuo_r()
	elif skill_id == "q" and flow_name == "归砚":
		_cast_guiyan_q()
	elif skill_id == "q" and flow_name == "点睛":
		_cast_dianjing_q()
	else:
		var radius := float(result.get("range", 0.0))
		var mult := float(result.get("damage_mult", 0.0))
		if radius > 0.0 and mult > 0.0:
			apply_damage_in_area(radius, GlobalStats.base_atk * current_flow.damage_mult * mult)
		if skill_id == "q" and flow_name == "点墨":
			print("墨引已放置")
		elif skill_id == "r" and flow_name == "藏锋":
			print("墨牢已释放")
		elif skill_id == "r" and flow_name == "归砚":
			print("共生：墨蝶附着，每秒回血2%，移速+10%")
		elif skill_id == "r" and flow_name == "点睛":
			is_berserk = true
			print("进入泣血·狂状态")
	FlowManager.skill_used.emit()


func _cast_shouzhuo_r() -> void:
	var flow := current_flow
	var mults: Array[float] = [2.0, 2.8, 3.6]
	for i in range(3):
		await get_tree().create_timer(0.2).timeout
		apply_damage_in_area(5.0, GlobalStats.base_atk * flow.damage_mult * mults[i])


func _cast_guiyan_q() -> void:
	var flow := current_flow
	print("蝶潮：召唤5只墨蝶")
	for i in range(5):
		apply_damage_in_area(5.0, GlobalStats.base_atk * flow.damage_mult * 0.4)
		# 被动：墨魂·共鸣（召唤物命中回墨）
		if has_passive_bonus("summon_hit_ink_restore"):
			current_ink = min(current_ink + max_ink * get_passive_bonus("summon_hit_ink_restore"), max_ink)
			ink_changed.emit(current_ink, max_ink)


func _cast_dianjing_q() -> void:
	var flow := current_flow
	print("藏泪：放置墨泪")
	await get_tree().create_timer(3.0).timeout
	print("墨泪爆炸！")
	apply_damage_in_area(6.0, GlobalStats.base_atk * flow.damage_mult * 2.5)


func apply_damage_in_area(radius: float, damage: float) -> void:
	damage *= _get_bonus_damage_multiplier()
	var facing := -global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node3D):
			continue
		var body := enemy as Node3D
		var to_enemy: Vector3 = body.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length() > radius:
			continue
		var dir := to_enemy.normalized() if to_enemy.length_squared() > 0.0001 else facing
		if body.has_method("take_damage"):
			body.call("take_damage", damage, dir)
		# 词条「破锋勾勒」：攻击附带破甲减速
		if body.has_method("apply_slow") and TalentManager.get_bonus("has_break") > 0.0:
			var slow: float = clampf(1.0 - TalentManager.get_bonus("break_slow"), 0.1, 1.0)
			body.call("apply_slow", slow, TalentManager.get_bonus("break_duration"))


## ============ 资源同步 ============

func get_current_resources() -> Dictionary:
	_sync_resources_from_flow()
	return {"shield": current_shield, "pool": current_pool, "shadow": current_shadow, "motes": current_motes}


func deduct_resource(cost: Dictionary) -> bool:
	if cost.has("shield"):
		if current_shield >= int(cost["shield"]):
			current_shield -= int(cost["shield"])
			_sync_resources_to_flow()
			return true
	if cost.has("pool"):
		if current_pool >= float(cost["pool"]):
			current_pool -= float(cost["pool"])
			_sync_resources_to_flow()
			return true
	if cost.has("shadow"):
		if current_shadow >= int(cost["shadow"]):
			current_shadow -= int(cost["shadow"])
			_sync_resources_to_flow()
			return true
	if cost.has("motes"):
		if current_motes >= int(cost["motes"]):
			current_motes -= int(cost["motes"])
			_sync_resources_to_flow()
			return true
	if cost.has("hp_percent"):
		current_ink -= max_ink * float(cost["hp_percent"]) / 100.0
		ink_changed.emit(current_ink, max_ink)
		return true
	return false


func _sync_resources_from_flow() -> void:
	current_shield = 0
	current_pool = 0.0
	current_shadow = 0
	current_motes = 0
	if current_flow == null:
		return
	if current_flow is Flow_Shouzhuo:
		current_shield = (current_flow as Flow_Shouzhuo).shield
	elif current_flow is Flow_Dianmo:
		current_pool = (current_flow as Flow_Dianmo).pool
	elif current_flow is Flow_Cangfeng:
		current_shadow = (current_flow as Flow_Cangfeng).shadow
	elif current_flow is Flow_Guiyan:
		current_motes = (current_flow as Flow_Guiyan).motes


func _sync_resources_to_flow() -> void:
	if current_flow is Flow_Shouzhuo:
		(current_flow as Flow_Shouzhuo).shield = current_shield
	elif current_flow is Flow_Dianmo:
		(current_flow as Flow_Dianmo).pool = current_pool
	elif current_flow is Flow_Cangfeng:
		(current_flow as Flow_Cangfeng).shadow = current_shadow
	elif current_flow is Flow_Guiyan:
		(current_flow as Flow_Guiyan).motes = current_motes


## ============ 被动技能 ============

func _refresh_passives() -> void:
	active_passive_effects.clear()
	if current_flow == null:
		return
	var passive_id: String = current_flow.equipped_skills.get("passive", "")
	if passive_id != "":
		apply_passive(passive_id)


func _refresh_talents() -> void:
	# 重新计算基于词条的加成：max_ink_penalty 影响最大墨量
	_refresh_passives()
	var penalty: float = TalentManager.get_bonus("max_ink_penalty")
	max_ink = max_ink_base * (1.0 - penalty)
	current_ink = min(current_ink, max_ink)
	ink_changed.emit(current_ink, max_ink)
	print("词条加成已刷新")


func apply_passive(passive_id: String) -> void:
	if current_flow == null:
		return
	var skill: Dictionary = current_flow.skill_data.get(passive_id, {})
	var passive_name: String = skill.get("name", "")
	var bonuses: Dictionary = PASSIVE_BONUSES.get(passive_name, {})
	active_passive_effects[passive_id] = bonuses
	if passive_name == "墨魂·积攒" and current_flow is Flow_Guiyan:
		(current_flow as Flow_Guiyan).upgrade_motes()
	print("被动生效: %s" % passive_name)


func remove_passive(passive_id: String) -> void:
	active_passive_effects.erase(passive_id)


func has_passive_bonus(key: String) -> bool:
	for pid in active_passive_effects:
		if active_passive_effects[pid].has(key):
			return true
	return false


func get_passive_bonus(key: String) -> float:
	var total := 0.0
	for pid in active_passive_effects:
		total += float(active_passive_effects[pid].get(key, 0.0))
	return total


func _get_bonus_damage_multiplier() -> float:
	var mult: float = 1.0 + TalentManager.get_bonus("damage_mult")
	var all_mult: float = TalentManager.get_bonus("all_damage_mult")
	if all_mult > 0.0:
		mult *= all_mult
	if has_passive_bonus("pool_damage_bonus") and current_pool >= 80.0:
		mult += get_passive_bonus("pool_damage_bonus")
	return mult


func _get_ink_cost_multiplier() -> float:
	var mult: float = 1.0 + TalentManager.get_bonus("ink_cost_mult")
	mult -= TalentManager.get_bonus("all_ink_cost_reduction")
	return maxf(mult, 0.0)


func _on_skill_equipped(flow_index: int, slot: String, _skill_id: String) -> void:
	if flow_index == FlowManager.current_index and slot == "passive":
		_refresh_passives()
