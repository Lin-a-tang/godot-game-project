extends Node
## 《墨渊》流派管理器（AutoLoad 单例）。
## 由流派面板（FlowPanel）调用 switch_to 切换流派；技能冷却在此更新。

signal flow_changed(new_flow: BaseFlow)
signal skill_used()
signal skill_equipped(flow_index: int, slot: String, skill_id: String)

var flows: Array[BaseFlow] = []
var current_index: int = 0


func _ready() -> void:
	flows = [Flow_Shouzhuo.new(), Flow_Dianmo.new(), Flow_Cangfeng.new(), Flow_Guiyan.new(), Flow_Dianjing.new()]
	for flow in flows:
		add_child(flow)


func _process(delta: float) -> void:
	if flows.is_empty():
		return
	get_current().update_cooldowns(delta)


func switch_next() -> void:
	current_index = (current_index + 1) % flows.size()
	var flow: BaseFlow = flows[current_index]
	print("切换至: %s" % flow.flow_name)
	flow_changed.emit(flow)


func switch_to(index: int) -> void:
	if index < 0 or index >= flows.size():
		return
	if not is_flow_unlocked(index):
		print("该流派尚未解锁")
		return
	current_index = index
	var flow: BaseFlow = flows[current_index]
	print("手动切换至: %s" % flow.flow_name)
	flow_changed.emit(flow)


func is_flow_unlocked(index: int) -> bool:
	match index:
		0, 1, 2:
			return true
		3:
			return GlobalStats.memory_fragments >= 20
		4:
			return GlobalStats.memory_fragments >= 35 and GlobalStats.met_yan_count >= 3
	return false


func get_current() -> BaseFlow:
	return flows[current_index]


func equip_skill(flow_index: int, slot: String, skill_id: String) -> bool:
	if flow_index < 0 or flow_index >= flows.size():
		return false
	var flow: BaseFlow = flows[flow_index]
	if flow.equip_skill(slot, skill_id):
		skill_equipped.emit(flow_index, slot, skill_id)
		return true
	return false


func get_equipped_skills(flow_index: int) -> Dictionary:
	if flow_index < 0 or flow_index >= flows.size():
		return {}
	return flows[flow_index].equipped_skills


func get_unlocked_active_skills(flow_index: int) -> Array:
	if flow_index < 0 or flow_index >= flows.size():
		return []
	return flows[flow_index].get_unlocked_active_skills()


func get_unlocked_passive_skills(flow_index: int) -> Array:
	if flow_index < 0 or flow_index >= flows.size():
		return []
	return flows[flow_index].get_unlocked_passive_skills()


func upgrade_guiyan_motes() -> void:
	for flow in flows:
		if flow is Flow_Guiyan:
			(flow as Flow_Guiyan).upgrade_motes()


## 记忆碎片解锁后刷新各流派技能解锁（补默认装备）并广播给 HUD
func refresh_skill_unlocks() -> void:
	for flow in flows:
		flow.reevaluate_unlocks()
	flow_changed.emit(get_current())
