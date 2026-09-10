extends "res://scripts/Enemy.gd"
## 《墨渊》第 1 章 Boss —— 缚形者·嵯峨 (GDScript 2.0 / Godot 4.7)
##
## 继承 Enemy.gd（受击 / 击退 / 死亡 / 复活机制、取墨/背刺接口不变），
## 补全大体型山石巨兽的固定墨量 + 四招循环：
##   ①墨线囚笼   : 以玩家落点布一圈"笼柱"，持续挤压玩家（笼柱可被玩家攻击击碎，
##                  每段击碎都化作碎片反噬，额外扣 Boss 墨量 —— 呼应"击碎墨线反伤"）；
##   ②直线冲刺   : 面朝玩家化作墨线冲撞，命中造成重创；
##   ③墨线漩涡   : 绕自身大圆弧横扫贴身威胁（按设计称圆弧横扫）；
##   ④交叉网格   : 在玩家脚下划纵横网格持续墨损。
## 常规招式在冷却好后依距离选取；半血（墨量 ≤ 50%）进入二阶段提速且招式衔接更密。
## 墨量固定，与玩家属性隔离。

## ============ 体型 / 移动 ============
@export var boss_engage_range: float = 34.0
@export var pursue_speed: float = 2.4
@export var pursue_turn: float = 4.0

## ============ 招式冷却（秒） ============
@export var cage_cooldown: float = 13.0
@export var dash_cooldown: float = 8.0
@export var sweep_cooldown: float = 6.5
@export var grid_cooldown: float = 11.0

## ============ 招式数值 ============
@export var cage_units: int = 8            ## 笼柱根数
@export var cage_radius: float = 5.5       ## 落点半径
@export var cage_dot: float = 2.5          ## 笼内持续挤压
@export var cage_shard_damage: float = 3.0 ## 每根笼柱击碎时的反噬（乘碎片倍率）
@export var cage_shard_mult: float = 4.0   ## 击碎一次结算的墨损倍数
@export var dash_damage: float = 26.0
@export var sweep_damage: float = 18.0
@export var sweep_radius: float = 7.5
@export var grid_dot: float = 2.8

## ============ 阶段 ============
@export var fixed_max_ink: float = 300.0   ## 设计固定墨量
@export var phase_damage_values_scale := 1  # 保留可扩展位

## ============ 动作状态 ============
enum CuoeState { IDLE, PICK, CAGE, DASH, SWEEP, GRID, STUN }
var cuoe_state: CuoeState = CuoeState.IDLE

# 动作 / 冷却
var _state_timer := 0.0
var _cd_cage := 0.0
var _cd_dash := 0.0
var _cd_sweep := 0.0
var _cd_grid := 0.0
var _hit_gate := 0.0        # 命中结算节流（避免一帧内重复造成墨损）
var _frag_gate := 0.0       # 击碎节流（避免蓄力攻击在单段内多次重复）
var _phase2 := false
var _rush_dir := Vector3.FORWARD
var _rush_hit_done := false

# 场地装饰节点（无物理碰撞的视觉笼柱 / 网格）
var _cage_posts: Array[Node3D] = []
var _grid_rods: Array[Node3D] = []
var _grid_vertical := false
var _grid_anchor := Vector3.ZERO

var _player: Node3D = null


## ============ 生命周期 ============

func _ready() -> void:
	super._ready()
	max_ink = fixed_max_ink
	ink = max_ink


## Boss 不受画桌庇护影响（守护着自己的领域）
func start_flee(_center: Vector3, _duration: float) -> void:
	pass


## 击败时先清空场地墨线再执行父类缩小销毁；
## 缩放完毕播放「竹林闪回」→ 解锁技能 → 进入勾勒词条 3选1
func _die() -> void:
	clear_arena_visuals()
	super._die()
	print("嵯峨崩解——第 1 章 Boss 击败触发点")
	await get_tree().create_timer(death_shrink_time + 0.25).timeout
	if not is_inside_tree():
		return
	ChapterFlow.boss_defeated("gougou")


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
	if _player == null:
		return

	if not _phase2 and ink <= max_ink * 0.5:
		_phase2 = true
		pursue_speed *= 1.4
		_cd_sweep = minf(_cd_sweep, 0.5)
		_wind_pulse_vfx()
		print("嵯峨进入二阶段：墨线崩张！")

	_face_player(delta)
	_tick_cool(delta)
	match cuoe_state:
		CuoeState.IDLE:
			_state_idle(delta)
		CuoeState.PICK:
			_state_pick(delta)
		CuoeState.DASH:
			_state_dash(delta)
		CuoeState.SWEEP:
			_state_sweep(delta)
		CuoeState.GRID:
			_state_grid(delta)
		CuoeState.CAGE:
			_state_cage(delta)
		CuoeState.STUN:
			_state_stun(delta)


func _tick_cool(dt: float) -> void:
	for key in ["_cd_cage", "_cd_dash", "_cd_sweep", "_cd_grid", "_hit_gate", "_frag_gate"]:
		var v: float = get(key)
		if v > 0.0:
			set(key, maxf(v - dt, 0.0))


func _find_player() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D:
			return p as Node3D
	return null


## ============ IDLE / 招式选择 ============

func _state_idle(delta: float) -> void:
	if _state_timer > 0.0:
		_state_timer -= delta
		if _state_timer <= 0.0:
			cuoe_state = CuoeState.PICK
		return
	# 超距：守在 Boss 房里不动（避免远程穿越/追出场）
	if _dist_xz() > boss_engage_range:
		return
	_state_timer = 0.7   # 短蓄势让玩家可读
	cuoe_state = CuoeState.IDLE


func _state_pick(delta: float) -> void:
	_state_timer -= delta
	if _state_timer > 0.0:
		return
	_select_move()


func _select_move() -> void:
	var d := _dist_xz()
	var near_boss := d < sweep_radius + 1.5
	var pool: Array[int] = []

	if _cd_dash <= 0.0:
		pool.append(CuoeState.DASH)
	if _cd_sweep <= 0.0 and near_boss:
		pool.append(CuoeState.SWEEP)
	if _cd_cage <= 0.0 and d > 2.5:
		pool.append(CuoeState.CAGE)
	if _cd_grid <= 0.0 and d > 6.0:
		pool.append(CuoeState.GRID)

	if pool.is_empty():
		cuoe_state = CuoeState.IDLE
		_state_timer = 0.6
		return

	# 拟人化的"贴脸横扫 / 远距拉回铺网"
	if near_boss and pool.has(CuoeState.SWEEP):
		_launch(CuoeState.SWEEP)
	elif d > 11.0 and pool.has(CuoeState.GRID):
		_launch(CuoeState.GRID)
	elif d > 5.0 and pool.has(CuoeState.CAGE):
		_launch(CuoeState.CAGE)
	else:
		# 无特殊偏好的复读窗口：挑一个现阶段冷却就绪的招式
		var fallback: CuoeState = CuoeState.DASH
		if pool.has(CuoeState.CAGE):
			fallback = CuoeState.CAGE
		elif pool.has(CuoeState.GRID):
			fallback = CuoeState.GRID
		elif pool.has(CuoeState.SWEEP):
			fallback = CuoeState.SWEEP
		elif pool.has(CuoeState.DASH):
			fallback = CuoeState.DASH
		_launch(fallback)


func _launch(kind: CuoeState) -> void:
	clear_arena_visuals()
	match kind:
		CuoeState.DASH:
			_begin_dash()
		CuoeState.SWEEP:
			_begin_sweep()
		CuoeState.CAGE:
			_begin_cage()
		CuoeState.GRID:
			_begin_grid()


## ============ 直线冲刺 ============

func _begin_dash() -> void:
	var dir := _player.global_position - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = - global_transform.basis.z
	_rush_dir = dir.normalized()
	cuoe_state = CuoeState.DASH
	_state_timer = 1.15             # 前摇（含读招窗口）
	_rush_hit_done = false
	print("嵯峨：直线冲刺！")


func _state_dash(delta: float) -> void:
	_state_timer -= delta
	# 前摇 0.5s 后开始直冲
	if _state_timer <= 0.7 and _state_timer > -0.35:
		var spd := (12.0 if _phase2 else 9.0) * delta * get_speed_factor()
		global_position += _rush_dir * spd
		if not _rush_hit_done and _in_rush_corridor(2.6):
			_rush_hit_done = _stroke_player(dash_damage)
	if _state_timer <= -0.35:
		cd_reset_after(CuoeState.DASH)
		_enter_stun(0.4)


func _in_rush_corridor(margin: float) -> bool:
	var a := _player.global_position
	var l := global_position
	var d := (a - l)
	d.y = 0.0
	# 纵向走廊 + 头部宽度
	return d.length() <= margin and d.normalized().dot(_rush_dir) >= 0.8


## ============ 墨线漩涡（圆弧横扫） ============

func _begin_sweep() -> void:
	cuoe_state = CuoeState.SWEEP
	_state_timer = 1.0
	print("嵯峨：圆弧横扫！")


func _state_sweep(delta: float) -> void:
	_state_timer -= delta
	if _state_timer < 0.6 and _state_timer > -0.2:
		# 以自身为轴的宽环；外侧线到内侧近距离都会吃到
		if _dist_xz() <= sweep_radius + 1.2:
			if _hit_gate <= 0.0:
				_stroke_player(sweep_damage)
				_hit_gate = 0.35
	if _state_timer <= -0.2:
		cd_reset_after(CuoeState.SWEEP)
		_enter_stun(0.35)


## ============ 交叉网格 ============

func _begin_grid() -> void:
	cuoe_state = CuoeState.GRID
	_state_timer = 5.0
	_grid_vertical = (randi() % 2) == 0
	# 以玩家脚下为中心拉起五根横杆示意
	_grid_anchor = Vector3(_player.global_position.x, 0.0, _player.global_position.z)
	draw_grid_rods()
	print("嵯峨：交叉墨线网格！（持续 %ds）" % int(_state_timer))


func _state_grid(delta: float) -> void:
	_state_timer -= delta
	if _state_timer > 0.0 and _inside_grid_band():
		if _hit_gate <= 0.0:
			_stroke_player(grid_dot)
			_hit_gate = 0.45
	if _state_timer <= 0.0:
		clear_arena_visuals()
		cd_reset_after(CuoeState.GRID)
		_enter_stun(0.3)


func _inside_grid_band() -> bool:
	var rel := _player.global_position - _grid_anchor
	rel.y = 0.0
	if _grid_vertical:
		return absf(rel.x) < 5.5 and absf(rel.z) < 5.5
	return absf(rel.x) < 5.5 and absf(rel.z) < 5.5


## ============ 墨线囚笼（可破坏反伤） ============

func _begin_cage() -> void:
	cuoe_state = CuoeState.CAGE
	_state_timer = 8.0
	_cage_posts.clear()
	draw_cage_posts()
	print("嵯峨：墨线囚笼！（共 %d 柱，可击碎反噬）" % cage_units)


func _state_cage(delta: float) -> void:
	_state_timer -= delta
	# 笼内持续挤压
	if _dist_xz() <= cage_radius:
		if _hit_gate <= 0.0:
			_stroke_player(cage_dot)
			_hit_gate = 0.4
	# 玩家挥击笼柱 → 逐格击碎 + 碎片反噬
	if _player_is_attacking() and _frag_gate <= 0.0 and not _cage_posts.is_empty():
		_break_one_post()
	if _state_timer <= 0.0:
		clear_arena_visuals()
		cd_reset_after(CuoeState.CAGE)
		_enter_stun(0.3)


func _break_one_post() -> void:
	_frag_gate = 0.12
	var post: Node3D = _cage_posts.pop_back()
	if is_instance_valid(post):
		post.queue_free()
	# 碎片反噬：直接落到自身 ink（经 take_damage 兼容减伤/被动）
	var reflect := cage_shard_damage * cage_shard_mult
	take_damage(reflect, global_position - _player.global_position, 0.0)
	print("囚笼柱被击碎，碎片反噬嵯峨 -%.1f（剩余 %d 柱）" % [reflect, _cage_posts.size()])
	if _cage_posts.is_empty():
		clear_arena_visuals()
		cd_reset_after(CuoeState.CAGE)
		_enter_stun(0.25)


func _player_is_attacking() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	# Player 内 enum：ATTACKING=2, CHARGING=3
	var raw: Variant = _player.get("state")
	if raw == null:
		return false
	return int(raw) == 2 or int(raw) == 3


## ============ 落地辅助 ============

func _enter_stun(wait: float) -> void:
	cuoe_state = CuoeState.STUN
	_state_timer = wait


func _state_stun(delta: float) -> void:
	_state_timer -= delta
	velocity = Vector3.ZERO
	if _state_timer <= 0.0:
		cuoe_state = CuoeState.IDLE
		_state_timer = 0.35


func cd_reset_after(kind: CuoeState) -> void:
	var k := (0.62 if _phase2 else 1.0)
	match kind:
		CuoeState.DASH:
			_cd_dash = dash_cooldown * k
		CuoeState.SWEEP:
			_cd_sweep = sweep_cooldown * k
		CuoeState.CAGE:
			_cd_cage = cage_cooldown * k
		CuoeState.GRID:
			_cd_grid = grid_cooldown * k


## ============ 命中玩家 ============

func _stroke_player(amount: float) -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if _player.has_method("take_damage"):
		_player.call("take_damage", amount, global_position)
		return true
	return false


func _dist_xz() -> float:
	if _player == null:
		return 99999.0
	var p := _player.global_position
	p.y = global_position.y
	return global_position.distance_to(p)


## ============ 移动 / 转向 ============

func _face_player(delta: float) -> void:
	if _player == null:
		return
	var dir := _player.global_position - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var look := global_transform.looking_at(global_position + dir.normalized(), Vector3.UP)
	global_transform = global_transform.interpolate_with(look, clampf(pursue_turn * delta, 0.0, 1.0))


func _step_toward_player(rate: float) -> void:
	var dir := _player.global_position - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized() * pursue_speed * rate * get_speed_factor()
	global_position += dir * get_physics_process_delta_time()


func _wind_pulse_vfx() -> void:
	# 二阶段表现占位：可在后续接入关节抖动 / 描边
	pass


## ============ 场地装饰（表现，不参与物理碰撞） ============

func draw_cage_posts() -> void:
	var anchor := Vector3(_player.global_position.x, 0.0, _player.global_position.z)
	for i in cage_units:
		var rod := _make_rod(Vector3(0.14, 4.0, 0.14), Color(0.02, 0.04, 0.1, 0.85))
		var a := TAU * float(i) / float(maxi(cage_units, 1))
		rod.global_position = anchor + Vector3(cos(a) * cage_radius, 2.0, sin(a) * cage_radius)
		_cage_posts.append(rod)


func draw_grid_rods() -> void:
	var dim := 7.0
	var kstep := 2.0
	if _grid_vertical:
		for k in range(-2, 3):
			var rod := _make_rod(Vector3(0.1, 0.05, dim), Color(0.04, 0.03, 0.12, 0.45))
			rod.global_position = Vector3(_grid_anchor.x + k * kstep, 0.06, _grid_anchor.z)
			_grid_rods.append(rod)
	else:
		for k in range(-2, 3):
			var rod := _make_rod(Vector3(dim, 0.05, 0.1), Color(0.04, 0.03, 0.12, 0.45))
			rod.global_position = Vector3(_grid_anchor.x, 0.06, _grid_anchor.z + k * kstep)
			_grid_rods.append(rod)


func _make_rod(size: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	# 随场景而非 Boss 本体移动，挂在场地根节点下（坐标用 global）
	var host := get_tree().current_scene
	if host == null:
		host = self.get_parent()
	host.add_child(mi)
	# 让播放时也进入角色所属大场景层
	mi.visible = true
	return mi


func clear_arena_visuals() -> void:
	for n in _cage_posts + _grid_rods:
		if is_instance_valid(n):
			n.queue_free()
	_cage_posts.clear()
	_grid_rods.clear()
