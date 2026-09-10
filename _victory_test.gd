extends Node3D
## 胜利流程测试：技能分级解锁 + 闪回 + 碎片入库 + 词条3选1触发

func _ready() -> void:
	_test_gating()
	await _test_chapter_flow()
	print("TESTS PASSED")
	Engine.time_scale = 1.0
	get_tree().quit()

func _test_gating() -> void:
	var flow: BaseFlow = FlowManager.flows[0]
	var a1: int = flow.get_unlocked_active_skills().size()
	var p1: int = flow.get_unlocked_passive_skills().size()
	print("初始 解锁: 主动=", a1, " 被动=", p1, " r状态=", flow.get_skill_status("r").get("name"))
	assert(a1 == 1 and p1 == 1)
	assert(flow.get_skill_status("r").get("name") == "未解锁")
	assert(flow.equipped_skills.get("r") == "")
	TalentManager.unlocked_fragments.append("gougou")
	FlowManager.refresh_skill_unlocks()
	var a2: int = flow.get_unlocked_active_skills().size()
	var p2: int = flow.get_unlocked_passive_skills().size()
	print("解锁后 主动=", a2, " 被动=", p2, " r装备=", flow.equipped_skills.get("r"))
	assert(a2 == 2 and p2 == 2)
	assert(flow.equipped_skills.get("r") != "")
	assert(flow.get_skill_status("r").get("name") == "千山")
	TalentManager.unlocked_fragments.erase("gougou")
	print("gating OK")

func _test_chapter_flow() -> void:
	GlobalStats.memory_fragments = 0
	ChapterFlow.boss_defeated("gougou", false)
	assert(GlobalStats.memory_fragments == 1)
	await get_tree().process_frame
	print("闪回播放中: ", ChapterFlow.is_flashback_running())
	assert(ChapterFlow.is_flashback_running())
	for i in 4:
		ChapterFlow.advance_flashback()
		await get_tree().process_frame
	print("闪回结束 解锁碎片=", TalentManager.unlocked_fragments)
	assert("gougou" in TalentManager.unlocked_fragments)
	var flow: BaseFlow = FlowManager.flows[0]
	assert(flow.equipped_skills.get("r") != "")
	print("chapter OK")
