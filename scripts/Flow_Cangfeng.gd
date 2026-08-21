class_name Flow_Cangfeng
extends BaseFlow
## 藏锋：高机动、脆皮。触发闪避时积累「残影」层数。


var shadow: int = 0


func _init() -> void:
	flow_name = "藏锋"
	damage_mult = 1.2
	hp_mult = 0.8
	speed_mult = 1.25


func on_dodge() -> void:
	shadow = min(shadow + 1, 3)
	print("藏锋·残影: %d" % shadow)
