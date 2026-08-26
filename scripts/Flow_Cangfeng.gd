class_name Flow_Cangfeng
extends BaseFlow
## 藏锋：高机动、脆皮。触发闪避时积累「残影」层数。


var shadow: int = 0


func _init() -> void:
	flow_name = "藏锋"
	damage_mult = 1.2
	hp_mult = 0.8
	speed_mult = 1.25


func init_skills() -> void:
	skill_data["q"] = {"name": "残影·引爆", "desc": "消耗1层残影，引爆造成180%范围伤害", "damage_mult": 1.8, "cooldown_max": 0.0, "range": 3.0, "cost": {"shadow": 1}}
	skill_data["r"] = {"name": "墨牢", "desc": "消耗3层残影，困住敌人2秒", "damage_mult": 0.0, "cooldown_max": 15.0, "range": 4.0, "cost": {"shadow": 3}}


func on_dodge() -> void:
	shadow = min(shadow + 1, 3)
	print("藏锋·残影: %d" % shadow)
