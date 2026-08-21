extends Node
## 《墨渊》流派管理器（AutoLoad 单例）。
## 由流派面板（FlowPanel）调用 switch_to 切换流派，并发出 flow_changed 信号。

signal flow_changed(new_flow: BaseFlow)

var flows: Array[BaseFlow] = []
var current_index: int = 0


func _ready() -> void:
	flows = [Flow_Shouzhuo.new(), Flow_Dianmo.new(), Flow_Cangfeng.new()]


func switch_next() -> void:
	current_index = (current_index + 1) % flows.size()
	var flow: BaseFlow = flows[current_index]
	print("切换至: %s" % flow.flow_name)
	flow_changed.emit(flow)


func switch_to(index: int) -> void:
	if index < 0 or index >= flows.size():
		return
	current_index = index
	var flow: BaseFlow = flows[current_index]
	print("手动切换至: %s" % flow.flow_name)
	flow_changed.emit(flow)


func get_current() -> BaseFlow:
	return flows[current_index]
