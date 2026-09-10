extends Node3D

func _key(code: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)

func _mouse(pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = 1
	e.pressed = pressed
	Input.parse_input_event(e)

func _pwait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ready() -> void:
	var main: Node = load("res://Main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player: Node = main.get_node("Player")
	var ha: AnimationPlayer = player.get_node("MeshInstance3D/Hero/AnimationPlayer")

	for c in ["qc_walk", "qc_walk_start"]:
		assert(ha.has_animation(c), "缺动画 " + c)
	print("anims ok, count=", ha.get_animation_list().size())

	# 1) 走路：进入 MOVING 先播起步，再切循环走
	Input.action_press("move_forward")
	await _pwait(2)
	print("walk-start anim=", ha.current_animation, " state=", player.state)
	assert(ha.current_animation == "qc_walk_start")
	assert(player.state == 1)
	# 等起步播完（2.93s/2.5≈1.17s）→ 应切 qc_walk
	var guard := 0
	while ha.current_animation != "qc_walk" and guard < 300:
		await get_tree().physics_frame
		guard += 1
	print("walk-loop anim=", ha.current_animation, " speed=", ha.speed_scale, " frames=", guard)
	assert(ha.current_animation == "qc_walk")
	assert(is_equal_approx(ha.speed_scale, 3.0))
	# 松开 → 回 idle
	Input.action_release("move_forward")
	await _pwait(3)
	print("back-to-idle anim=", ha.current_animation)
	assert(ha.current_animation == "qc_idle")

	# 2) 走路根位移已剥离
	for clip in ["qc_walk", "qc_walk_start"]:
		var anim: Animation = ha.get_animation(clip)
		for i in anim.get_track_count():
			if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
				continue
			if not str(anim.track_get_path(i)).contains("Hips"):
				continue
			var n: int = anim.track_get_key_count(i)
			var lo: Vector3 = anim.track_get_key_value(i, 0)
			var hi: Vector3 = lo
			for k in n:
				var v: Vector3 = anim.track_get_key_value(i, k)
				lo = Vector3(minf(lo.x, v.x), minf(lo.y, v.y), minf(lo.z, v.z))
				hi = Vector3(maxf(hi.x, v.x), maxf(hi.y, v.y), maxf(hi.z, v.z))
			var rng := hi - lo
			print(clip, " Hips range x=%.4f y=%.4f z=%.4f" % [rng.x, rng.y, rng.z])
			assert(rng.x < 0.001 and rng.y < 0.001)

	# 3) 攻击：轻击总时长 1.0s，动画速度 2.5
	assert(is_equal_approx(player.light_windup_time + player.light_active_time + player.light_recovery_time, 1.0))
	_mouse(true)
	await get_tree().physics_frame
	_mouse(false)
	await _pwait(2)
	print("atk anim=", ha.current_animation, " speed=", ha.speed_scale, " state=", player.state)
	assert(ha.current_animation == "qc_atk1")
	assert(is_equal_approx(ha.speed_scale, 2.5))
	guard = 0
	while player.state != 0 and guard < 200:
		await get_tree().physics_frame
		guard += 1
	print("atk-end anim=", ha.current_animation, " physics-frames=", guard)
	assert(ha.current_animation == "qc_idle")

	# 4) 闪避回归
	_key(KEY_SPACE, true)
	await get_tree().physics_frame
	_key(KEY_SPACE, false)
	await _pwait(2)
	print("dodge anim=", ha.current_animation)
	assert(ha.current_animation == "qc_roll_f")

	print("WALK + ATTACK + DODGE TESTS PASSED")
	get_tree().quit()
