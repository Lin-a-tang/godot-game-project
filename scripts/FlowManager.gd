extends Node
## 《墨渊》流派管理器（AutoLoad 单例）。
## 由流派面板（FlowPanel）调用 switch_to 切换流派；技能冷却在此更新。

signal flow_changed(new_flow: BaseFlow)
signal skill_used()

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
