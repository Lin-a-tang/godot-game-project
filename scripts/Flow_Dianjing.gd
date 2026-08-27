class_name Flow_Dianjing
extends BaseFlow
## 点睛：以血为墨，濒死爆发。技能消耗生命值。


func _init() -> void:
	flow_name = "点睛"
	damage_mult = 1.3
	hp_mult = 0.8
	speed_mult = 1.0


func init_skills() -> void:
	skill_data["q"] = {"name": "藏泪", "desc": "放置墨泪，3秒后爆炸造成250%范围伤害", "damage_mult": 2.5, "cooldown_max": 10.0, "range": 6.0, "cost": {"hp_percent": 8}}
	skill_data["r"] = {"name": "泣血·狂", "desc": "生命<50%时进入狂状态：攻速+30%，伤害+40%，每秒耗1%HP", "damage_mult": 0.0, "cooldown_max": 20.0, "range": 0.0, "cost": {"hp_percent": 0}}
